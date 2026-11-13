import SwiftUI

struct Setup: Codable, Equatable { var level: Int; var target: Int }       // level ‎-1 = لاعبين على نفس الجهاز
struct SavedGame: Codable { var board: Board; var turn: Int; var score: [Int]; var setup: Setup }
struct Outcome: Equatable { var winner: Int; var value: Int; var matchOver: Bool }
enum Phase { case roll, move, wait, over }

struct Seeded: RandomNumberGenerator {
    var s: UInt64
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

struct Stats: Codable {
    var games = 0, wins = 0, gammons = 0, streak = 0, best = 0
    var levelWins = [0, 0, 0]
}

@MainActor
final class Rec: ObservableObject {
    @Published var stats = Stats()
    @Published var saved: SavedGame? = nil
    private let ud = UserDefaults.standard
    init() {
        if Shot.on {
            stats = Stats(games: 41, wins: 26, gammons: 5, streak: 3, best: 7, levelWins: [9, 11, 6])
            saved = SavedGame(board: .start, turn: 0, score: [2, 1], setup: Setup(level: 2, target: 5))
            return
        }
        if let d = ud.data(forKey: "nd_stats"), let v = try? JSONDecoder().decode(Stats.self, from: d) { stats = v }
        if let d = ud.data(forKey: "nd_saved"), let v = try? JSONDecoder().decode(SavedGame.self, from: d) { saved = v }
    }
    func keep(_ g: SavedGame?) {
        guard !Shot.on else { return }
        saved = g
        if let g = g, let d = try? JSONEncoder().encode(g) { ud.set(d, forKey: "nd_saved") } else { ud.removeObject(forKey: "nd_saved") }
    }
    func record(level: Int, won: Bool, value: Int) {
        guard !Shot.on, level >= 0, level < 3 else { return }
        stats.games += 1
        if won {
            stats.wins += 1; stats.streak += 1; stats.best = max(stats.best, stats.streak); stats.levelWins[level] += 1
            if value >= 2 { stats.gammons += 1 }
        } else { stats.streak = 0 }
        if let d = try? JSONEncoder().encode(stats) { ud.set(d, forKey: "nd_stats") }
    }
}

@MainActor
final class Match: ObservableObject {
    @Published var board = Board.start
    @Published var stacks: [Int: [Int]] = [:]          // مفتاح المكان ← أرقام الأحجار بالترتيب (0…14 أبيض، 15…29 أسود)
    @Published var turn = 0
    @Published var faces: [Int] = []
    @Published var left: [Int] = []
    @Published var played: [Move] = []
    @Published var options: [Move] = []
    @Published var sel: Int? = nil
    @Published var phase = Phase.roll
    @Published var score = [0, 0]
    @Published var note = ""
    @Published var hint: Move? = nil
    @Published var outcome: Outcome? = nil
    @Published var rolling = false
    let setup: Setup
    let rec: Rec
    private var startBoard = Board.start
    private var legal: [[Move]] = []
    private var gen = 0

    init(setup: Setup, saved: SavedGame?, rec: Rec) {
        self.setup = setup
        self.rec = rec
        if Shot.isAny("game", "bear", "win", "hint") { stage(Shot.name); return }
        if let s = saved {
            board = s.board; score = s.score; turn = s.turn
            rebuild()
            if !humanTurn { autoRoll() }
        } else {
            start(Shot.on ? 0 : Int.random(in: 0...1))
        }
    }

    var humanTurn: Bool { setup.level < 0 || turn == 0 }
    var sources: Set<Int> { Set(options.map { $0.from }) }
    var targets: [Int] {
        guard let s = sel else { return [] }
        return options.filter { $0.from == s }.map { $0.to }
    }
    var canFinish: Bool { phase == .move && options.isEmpty }
    /// تقدير حظّ الأبيض بالفوز (0…1)
    var chance: Double { 1 / (1 + exp(-BG.evaluate(board, 0) / 30)) }

    // MARK: اللعب

    func roll() {
        guard phase == .roll, !rolling else { return }
        let g = gen
        rolling = true; note = ""
        Haptic.thud()
        Task {
            for _ in 0..<7 {
                faces = [Int.random(in: 1...6), Int.random(in: 1...6)]
                try? await Task.sleep(nanoseconds: 55_000_000)
                if g != gen { return }
            }
            settle(Int.random(in: 1...6), Int.random(in: 1...6))
        }
    }

    private func settle(_ a: Int, _ b: Int) {
        rolling = false
        faces = BG.dice(a, b); left = faces; played = []; startBoard = board
        legal = BG.turns(board, turn, dice: faces)
        if legal.isEmpty {
            options = []; phase = .wait
            note = "ما أكو حركة ممكنة — يروح الدور"
            let g = gen
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if g == gen { endTurn() }
            }
            return
        }
        if humanTurn { phase = .move; refresh() } else { phase = .wait; options = []; aiPlay() }
    }

    func tap(_ loc: Int) {
        guard phase == .move, humanTurn else { return }
        if let s = sel {
            let cands = options.filter { $0.from == s && $0.to == loc }
            if let m = cands.min(by: { $0.die < $1.die }) { play(m); return }
        }
        if sources.contains(loc) {
            sel = (sel == loc) ? nil : loc
            Haptic.tap()
        } else { sel = nil }
    }

    private func play(_ m: Move) {
        let p = turn
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            board = board.applying(m, p)
            shift(m, p)
        }
        played.append(m)
        if let k = left.firstIndex(of: m.die) { left.remove(at: k) }
        sel = nil; hint = nil
        if m.hit { Haptic.thud() } else { Haptic.tap() }
        refresh()
        if board.winner != nil { finish() }
    }

    func undo() {
        guard phase == .move, humanTurn, let m = played.popLast() else { return }
        let p = turn
        var b = startBoard
        for x in played { b = b.applying(x, p) }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
            board = b
            unshift(m, p)
        }
        left.append(m.die)
        sel = nil; hint = nil
        Haptic.tap()
        refresh()
    }

    func done() {
        guard canFinish else { return }
        Haptic.tap()
        endTurn()
    }

    private func endTurn() {
        turn = 1 - turn
        faces = []; left = []; played = []; options = []; sel = nil; hint = nil; note = ""
        phase = .roll
        save()
        if !humanTurn { autoRoll() }
    }

    private func autoRoll() {
        let g = gen
        Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            if g == gen { roll() }
        }
    }

    private func aiPlay() {
        let g = gen, b = board, d = faces, lvl = max(0, setup.level), p = turn
        Task {
            let t = await Task.detached(priority: .userInitiated) { () -> [Move] in
                var r = SystemRandomNumberGenerator()
                return BG.choose(b, p, dice: d, level: lvl, using: &r)
            }.value
            try? await Task.sleep(nanoseconds: 500_000_000)
            for m in t {
                if g != gen { return }
                play(m)
                if phase == .over { return }
                try? await Task.sleep(nanoseconds: 640_000_000)
            }
            if g == gen { endTurn() }
        }
    }

    func askHint() {
        guard phase == .move, humanTurn, !options.isEmpty else { return }
        let g = gen, b = board, d = left, p = turn
        Task {
            let t = await Task.detached(priority: .userInitiated) { () -> [Move] in
                var r = SystemRandomNumberGenerator()
                return BG.choose(b, p, dice: d, level: 2, using: &r)
            }.value
            guard g == gen, phase == .move else { return }
            let m = t.first.flatMap { options.contains($0) ? $0 : nil } ?? options.first
            if let m = m {
                hint = m; sel = m.from
                Haptic.tap()
            }
        }
    }

    private func finish() {
        guard let w = board.winner else { return }
        let v = board.winValue(w)
        score[w] += v
        let over = score[w] >= setup.target
        phase = .over; options = []; sel = nil
        rec.record(level: setup.level, won: w == 0, value: v)
        if over { rec.keep(nil) }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { outcome = Outcome(winner: w, value: v, matchOver: over) }
        if setup.level < 0 || w == 0 { Haptic.ok() } else { Haptic.bad() }
    }

    func nextGame() {
        gen += 1
        let who = outcome?.winner ?? Int.random(in: 0...1)
        if outcome?.matchOver == true { score = [0, 0] }
        withAnimation(.easeOut(duration: 0.2)) { outcome = nil }
        start(who)
    }

    func stop() { gen += 1 }

    private func start(_ who: Int) {
        board = .start
        rebuild()
        turn = who
        faces = []; left = []; played = []; options = []; sel = nil; hint = nil; note = ""
        phase = .roll
        save()
        if !humanTurn { autoRoll() }
    }

    private func save() { rec.keep(SavedGame(board: board, turn: turn, score: score, setup: setup)) }

    // MARK: الحركات المتاحة

    private func refresh() {
        let n = played.count
        var seen = Set<Move>()
        var out: [Move] = []
        for t in legal where t.count > n {
            var ok = true
            for k in 0..<n where t[k] != played[k] { ok = false; break }
            if ok && seen.insert(t[n]).inserted { out.append(t[n]) }
        }
        options = out
        if phase == .move && humanTurn && board.bar[turn] > 0 && out.contains(where: { $0.from == -1 }) { sel = -1 }
    }

    // MARK: الأحجار (حتى الحركة تبيّن بالأنيميشن)

    static func key(_ loc: Int, _ p: Int) -> Int { loc == -1 ? 100 + p : (loc == 99 ? 200 + p : loc) }

    private func rebuild() {
        var s: [Int: [Int]] = [:]
        var next = [0, 15]
        for i in 0..<24 {
            for p in 0...1 {
                let n = board.count(p, at: i)
                if n > 0 { s[i] = Array(next[p]..<(next[p] + n)); next[p] += n }
            }
        }
        for p in 0...1 {
            if board.bar[p] > 0 { s[100 + p] = Array(next[p]..<(next[p] + board.bar[p])); next[p] += board.bar[p] }
            if board.off[p] > 0 { s[200 + p] = Array(next[p]..<(next[p] + board.off[p])); next[p] += board.off[p] }
        }
        stacks = s
    }

    private func shift(_ m: Move, _ p: Int) {
        let fk = Match.key(m.from, p), tk = Match.key(m.to, p)
        guard var from = stacks[fk], let id = from.popLast() else { rebuild(); return }
        stacks[fk] = from.isEmpty ? nil : from
        if m.hit, var there = stacks[tk], let h = there.popLast() {
            stacks[tk] = there.isEmpty ? nil : there
            stacks[100 + (1 - p), default: []].append(h)
        }
        stacks[tk, default: []].append(id)
    }

    private func unshift(_ m: Move, _ p: Int) {
        let fk = Match.key(m.from, p), tk = Match.key(m.to, p)
        guard var to = stacks[tk], let id = to.popLast() else { rebuild(); return }
        stacks[tk] = to.isEmpty ? nil : to
        if m.hit, var bar = stacks[100 + (1 - p)], let h = bar.popLast() {
            stacks[100 + (1 - p)] = bar.isEmpty ? nil : bar
            stacks[tk, default: []].append(h)
        }
        stacks[fk, default: []].append(id)
    }

    // MARK: أوضاع التصوير

    private func stage(_ name: String) {
        var seed: UInt64 = 5
        var found = Board.start
        while seed < 80 {
            var r = Seeded(s: seed)
            var b = Board.start
            var p = 0, n = 0
            while b.winner == nil && n < 400 {
                if (name == "game" || name == "hint") && n == 18 { break }
                if name == "bear" && p == 0 && b.off[0] >= 4 && b.off[1] >= 2 { break }
                let d = BG.dice(Int.random(in: 1...6, using: &r), Int.random(in: 1...6, using: &r))
                let t = BG.choose(b, p, dice: d, level: 1, using: &r)
                for m in t { b = b.applying(m, p) }
                p = 1 - p; n += 1
            }
            let ok = name == "win" ? (b.winner == 0) : (b.winner == nil)
            if ok { found = b; break }
            seed += 1
        }
        board = found
        rebuild()
        turn = 0
        if name == "win" {
            score = [3, 1]; phase = .over
            outcome = Outcome(winner: 0, value: found.winValue(0), matchOver: true)
            return
        }
        score = [1, 2]
        let tries = [[4, 2], [5, 3], [6, 1], [3, 1], [6, 5], [2, 1]]
        for pair in tries {
            let t = BG.turns(board, 0, dice: BG.dice(pair[0], pair[1]))
            if !t.isEmpty {
                faces = pair; left = pair; legal = t; startBoard = board; played = []
                phase = .move
                refresh()
                break
            }
        }
        if name == "hint", let m = options.last { hint = m; sel = m.from; return }
        if sel == nil {
            var best = -99, count = 0
            for s in sources {
                let c = options.filter { $0.from == s }.count
                if c > count { count = c; best = s }
            }
            if best != -99 { sel = best }
        }
    }
}
