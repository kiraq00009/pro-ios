import Foundation

// محرّك البطولات — منطق خالص (Foundation فقط) حتى ينفحص باختبارات آليّة

struct Member: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var color: Int = 0          // رقم لون من لوحة الألوان
}

enum Format: String, Codable, CaseIterable { case league, cup, groups }

/// وين تقع المباراة بالبطولة
struct Stage: Codable, Hashable {
    var kind: Int               // 0 دوري · 1 مجموعة · 2 إقصاء
    var group: Int = 0          // رقم المجموعة (للنوع 1)
    var round: Int              // رقم الجولة (من 0) — بالإقصاء: 0 أوّل دور
    var slot: Int = 0           // ترتيب المباراة داخل دور الإقصاء
}

struct Game: Codable, Identifiable, Hashable {
    var id = UUID()
    var stage: Stage
    var home: UUID? = nil
    var away: UUID? = nil
    var hg: Int? = nil
    var ag: Int? = nil
    var hp: Int? = nil          // ركلات الترجيح (للإقصاء إذا تعادلوا)
    var ap: Int? = nil
    var at: Date? = nil
    var feedHome: UUID? = nil   // الفائز بهالمباراة يصير صاحب الأرض
    var feedAway: UUID? = nil
    var seedHome: String? = nil // «A1» = أوّل المجموعة أ (يتعبّى بعد المجموعات)
    var seedAway: String? = nil
    var bye = false             // تأهّل مباشر بلا مباراة

    var played: Bool { hg != nil && ag != nil }
    var ready: Bool { home != nil && away != nil && !bye }

    /// الفائز (بالأهداف، وإذا تعادلوا بالإقصاء فبالترجيح)
    var winner: UUID? {
        if bye { return home ?? away }
        guard let h = hg, let a = ag, let hm = home, let aw = away else { return nil }
        if h != a { return h > a ? hm : aw }
        guard stage.kind == 2, let p = hp, let q = ap, p != q else { return nil }
        return p > q ? hm : aw
    }
    var loser: UUID? {
        guard let w = winner, let hm = home, let aw = away else { return nil }
        return w == hm ? aw : hm
    }
    /// بالإقصاء: النتيجة تعادل وتحتاج ترجيح
    var needsPens: Bool { stage.kind == 2 && played && hg == ag && (hp == nil || ap == nil || hp == ap) }
    var decided: Bool { bye || (stage.kind == 2 ? winner != nil : played) }
}

struct Row: Identifiable, Hashable {
    var id: UUID
    var p = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0
    var form: [Int] = []        // آخر النتائج: 1 فوز · 0 تعادل · ‎-1 خسارة
    var gd: Int { gf - ga }
    var pts: Int { w * 3 + d }
}

struct Tournament: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var format: Format
    var legs = 1
    var members: [UUID]
    var clubs: [String: String] = [:]      // معرّف اللاعب ⇒ الفريق اللي طلعله بالقرعة
    var groups: [[UUID]] = []
    var games: [Game] = []
    var created = Date()
    var champion: UUID? = nil
    var friendly = false

    var playable: [Game] { games.filter { !$0.bye } }
    var playedCount: Int { playable.filter { $0.decided }.count }
    var progress: Double { playable.isEmpty ? 0 : Double(playedCount) / Double(playable.count) }
    var finished: Bool { champion != nil }
    func club(_ id: UUID) -> String { clubs[id.uuidString] ?? "" }
}

enum Engine {
    // MARK: توليد المباريات

    /// دوري كامل بطريقة الدائرة: كلّ لاعب يلاقي الكلّ مرّة (أو مرّتين ذهاب وإياب)
    static func roundRobin(_ ids: [UUID], legs: Int) -> [(round: Int, home: UUID, away: UUID)] {
        guard ids.count >= 2 else { return [] }
        var arr: [UUID?] = ids
        if arr.count % 2 == 1 { arr.append(nil) }
        let n = arr.count, rounds = n - 1
        var out: [(round: Int, home: UUID, away: UUID)] = []
        for r in 0..<rounds {
            for i in 0..<(n / 2) {
                guard let a = arr[i], let b = arr[n - 1 - i] else { continue }
                // نبدّل الأرض بين الجولات حتى ما يبقى واحد دائمًا صاحب الأرض
                let flip = (r + i) % 2 == 1
                out.append((r, flip ? b : a, flip ? a : b))
            }
            let last = arr.removeLast(); arr.insert(last, at: 1)     // ندوّر الكلّ إلّا الأوّل
        }
        if legs >= 2 { out += out.map { (round: $0.round + rounds, home: $0.away, away: $0.home) } }
        return out
    }

    static func make(name: String, format: Format, legs: Int, members: [UUID], clubs: [String: String] = [:], shuffle: Bool = true) -> Tournament {
        var t = Tournament(name: name, format: format, legs: max(1, min(2, legs)), members: members, clubs: clubs)
        let ids = shuffle ? members.shuffled() : members
        switch format {
        case .league:
            t.games = roundRobin(ids, legs: t.legs).map { Game(stage: Stage(kind: 0, round: $0.round), home: $0.home, away: $0.away) }
        case .cup:
            t.legs = 1
            t.games = bracket(seeds: ids.map { Optional($0) })
        case .groups:
            let gc = ids.count >= 12 ? 4 : 2
            var gs = [[UUID]](repeating: [], count: gc)
            for (i, m) in ids.enumerated() { gs[i % gc].append(m) }
            t.groups = gs
            for (g, list) in gs.enumerated() {
                t.games += roundRobin(list, legs: t.legs).map { Game(stage: Stage(kind: 1, group: g, round: $0.round), home: $0.home, away: $0.away) }
            }
            // الإقصاء: الأوّل يلاقي ثاني المجموعة الثانية
            let pairs: [(String, String)] = gc == 2 ? [("A1", "B2"), ("B1", "A2")] : [("A1", "B2"), ("C1", "D2"), ("B1", "A2"), ("D1", "C2")]
            var round = pairs.enumerated().map { i, p in Game(stage: Stage(kind: 2, round: 0, slot: i), seedHome: p.0, seedAway: p.1) }
            t.games += round
            var r = 1
            while round.count > 1 {
                var next: [Game] = []
                for i in stride(from: 0, to: round.count, by: 2) {
                    next.append(Game(stage: Stage(kind: 2, round: r, slot: i / 2), feedHome: round[i].id, feedAway: round[i + 1].id))
                }
                t.games += next; round = next; r += 1
            }
        }
        advance(&t)
        return t
    }

    /// شجرة إقصاء: نكمّل العدد لأقرب قوّة ٢ بتأهّل مباشر (bye)
    static func bracket(seeds: [UUID?]) -> [Game] {
        let n = seeds.count
        guard n >= 2 else { return [] }
        var size = 2; while size < n { size *= 2 }
        // التأهّل المباشر يروح لآخر الأزواج حتى ما يتقابل فراغين
        let byes = size - n, pairsCount = size / 2
        var real = seeds
        var order: [UUID?] = []
        for i in 0..<pairsCount {
            let first: UUID? = real.isEmpty ? nil : real.removeFirst()
            let second: UUID? = (i >= pairsCount - byes || real.isEmpty) ? nil : real.removeFirst()
            order.append(first); order.append(second)
        }
        var all: [Game] = []
        var round: [Game] = []
        for i in 0..<pairsCount {
            var g = Game(stage: Stage(kind: 2, round: 0, slot: i), home: order[i * 2], away: order[i * 2 + 1])
            if g.home == nil || g.away == nil { g.bye = true }
            round.append(g)
        }
        all += round
        var r = 1
        while round.count > 1 {
            var next: [Game] = []
            for i in stride(from: 0, to: round.count, by: 2) {
                next.append(Game(stage: Stage(kind: 2, round: r, slot: i / 2), feedHome: round[i].id, feedAway: round[i + 1].id))
            }
            all += next; round = next; r += 1
        }
        return all
    }

    // MARK: الترتيب

    static func table(_ ids: [UUID], _ games: [Game]) -> [Row] {
        var rows: [UUID: Row] = [:]
        for id in ids { rows[id] = Row(id: id) }
        let done = games.filter { $0.played && !$0.bye }.sorted { ($0.at ?? .distantPast) < ($1.at ?? .distantPast) }
        for g in done {
            guard let h = g.home, let a = g.away, let hg = g.hg, let ag = g.ag, rows[h] != nil, rows[a] != nil else { continue }
            rows[h]!.p += 1; rows[a]!.p += 1
            rows[h]!.gf += hg; rows[h]!.ga += ag; rows[a]!.gf += ag; rows[a]!.ga += hg
            if hg > ag { rows[h]!.w += 1; rows[a]!.l += 1; rows[h]!.form.append(1); rows[a]!.form.append(-1) }
            else if hg < ag { rows[a]!.w += 1; rows[h]!.l += 1; rows[a]!.form.append(1); rows[h]!.form.append(-1) }
            else { rows[h]!.d += 1; rows[a]!.d += 1; rows[h]!.form.append(0); rows[a]!.form.append(0) }
        }
        let order = ids
        var list = ids.compactMap { rows[$0] }
        list.sort { x, y in
            if x.pts != y.pts { return x.pts > y.pts }
            if x.gd != y.gd { return x.gd > y.gd }
            if x.gf != y.gf { return x.gf > y.gf }
            // المواجهات المباشرة
            let hx = h2hPoints(x.id, y.id, done), hy = h2hPoints(y.id, x.id, done)
            if hx != hy { return hx > hy }
            return (order.firstIndex(of: x.id) ?? 0) < (order.firstIndex(of: y.id) ?? 0)
        }
        for i in list.indices { list[i].form = Array(list[i].form.suffix(5)) }
        return list
    }
    private static func h2hPoints(_ a: UUID, _ b: UUID, _ games: [Game]) -> Int {
        var pts = 0
        for g in games {
            guard let h = g.home, let w = g.away, let hg = g.hg, let ag = g.ag else { continue }
            if h == a && w == b { pts += hg > ag ? 3 : (hg == ag ? 1 : 0) }
            else if h == b && w == a { pts += ag > hg ? 3 : (hg == ag ? 1 : 0) }
        }
        return pts
    }

    static func standings(_ t: Tournament, group: Int? = nil) -> [Row] {
        switch t.format {
        case .league: return table(t.members, t.games.filter { $0.stage.kind == 0 })
        case .groups:
            let g = group ?? 0
            guard t.groups.indices.contains(g) else { return [] }
            return table(t.groups[g], t.games.filter { $0.stage.kind == 1 && $0.stage.group == g })
        case .cup: return []
        }
    }

    // MARK: التقدّم (تأهّل، تعبئة الإقصاء، البطل)

    /// تنادى بعد كلّ نتيجة: تعبّي مباريات الإقصاء من المجموعات ومن الفائزين، وتعلن البطل
    static func advance(_ t: inout Tournament) {
        // ١) المجموعات خلصت ⇒ نعبّي أوّل دور إقصاء
        if t.format == .groups {
            let groupGames = t.games.filter { $0.stage.kind == 1 }
            let allDone = !groupGames.isEmpty && groupGames.allSatisfy { $0.played }
            let letters = ["A", "B", "C", "D"]
            for i in t.games.indices where t.games[i].stage.kind == 2 && t.games[i].stage.round == 0 {
                func pick(_ s: String?) -> UUID? {
                    guard allDone, let s, s.count == 2, let gi = letters.firstIndex(of: String(s.prefix(1))), let rank = Int(String(s.suffix(1))) else { return nil }
                    let rows = standings(t, group: gi)
                    return rows.indices.contains(rank - 1) ? rows[rank - 1].id : nil
                }
                let h = pick(t.games[i].seedHome), a = pick(t.games[i].seedAway)
                if !t.games[i].played { t.games[i].home = h; t.games[i].away = a }
            }
        }
        // ٢) الفائزون يتقدّمون للدور اللي بعده
        var changed = true
        while changed {
            changed = false
            for i in t.games.indices where t.games[i].stage.kind == 2 && (t.games[i].feedHome != nil || t.games[i].feedAway != nil) {
                let fh = t.games[i].feedHome.flatMap { id in t.games.first { $0.id == id } }
                let fa = t.games[i].feedAway.flatMap { id in t.games.first { $0.id == id } }
                let nh = fh?.winner, na = fa?.winner
                if t.games[i].home != nh || t.games[i].away != na {
                    // تغيّر أحد الطرفين ⇒ النتيجة القديمة (إن وُجدت) ما تصحّ بعد
                    if t.games[i].played { t.games[i].hg = nil; t.games[i].ag = nil; t.games[i].hp = nil; t.games[i].ap = nil; t.games[i].at = nil }
                    t.games[i].home = nh; t.games[i].away = na; changed = true
                }
            }
        }
        // ٣) البطل
        switch t.format {
        case .league:
            let all = t.games
            t.champion = (!all.isEmpty && all.allSatisfy { $0.played }) ? standings(t).first?.id : nil
        case .cup, .groups:
            let ko = t.games.filter { $0.stage.kind == 2 }
            let final = ko.max { $0.stage.round < $1.stage.round }
            t.champion = final?.winner
        }
    }

    /// يسجّل نتيجة (أو يمسحها إذا nil) ويحدّث كلّ اللي يترتّب عليها
    static func setScore(_ t: inout Tournament, game id: UUID, hg: Int?, ag: Int?, hp: Int? = nil, ap: Int? = nil, at: Date = Date()) {
        guard let i = t.games.firstIndex(where: { $0.id == id }) else { return }
        t.games[i].hg = hg; t.games[i].ag = ag
        t.games[i].hp = (hg != nil && hg == ag) ? hp : nil
        t.games[i].ap = (hg != nil && hg == ag) ? ap : nil
        t.games[i].at = hg == nil ? nil : at
        advance(&t)
    }

    /// اسم دور الإقصاء حسب عدد المباريات بيه
    static func koName(_ t: Tournament, round: Int) -> String {
        let n = t.games.filter { $0.stage.kind == 2 && $0.stage.round == round }.count
        switch n { case 1: return "النهائيّ"; case 2: return "نصف النهائيّ"; case 4: return "ربع النهائيّ"; case 8: return "دور الـ16"; default: return "الدور \(round + 1)" }
    }
    static func koRounds(_ t: Tournament) -> [Int] { Array(Set(t.games.filter { $0.stage.kind == 2 }.map { $0.stage.round })).sorted() }

    // MARK: إحصائيّات كلّ الأوقات

    struct Career: Identifiable, Hashable {
        var id: UUID
        var p = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0
        var titles = 0, finals = 0
        var bestWin = 0             // أكبر فارق فوز
        var streak = 0              // سلسلة الانتصارات الحاليّة
        var bestStreak = 0
        var winRate: Double { p == 0 ? 0 : Double(w) / Double(p) }
        var gpg: Double { p == 0 ? 0 : Double(gf) / Double(p) }
    }

    static func careers(_ members: [Member], _ ts: [Tournament]) -> [Career] {
        var c: [UUID: Career] = [:]
        for m in members { c[m.id] = Career(id: m.id) }
        var all: [Game] = []
        for t in ts {
            all += t.games.filter { $0.played && !$0.bye }
            if let ch = t.champion, !t.friendly { c[ch]?.titles += 1 }
            if !t.friendly, t.format != .league, let f = t.games.filter({ $0.stage.kind == 2 }).max(by: { $0.stage.round < $1.stage.round }), f.winner != nil {
                if let h = f.home { c[h]?.finals += 1 }; if let a = f.away { c[a]?.finals += 1 }
            }
        }
        all.sort { ($0.at ?? .distantPast) < ($1.at ?? .distantPast) }
        for g in all {
            guard let h = g.home, let a = g.away, let hg = g.hg, let ag = g.ag else { continue }
            let win = g.winner
            for (me, mine, theirs) in [(h, hg, ag), (a, ag, hg)] {
                guard var x = c[me] else { continue }
                x.p += 1; x.gf += mine; x.ga += theirs
                if mine > theirs || (mine == theirs && win == me) {
                    x.w += 1; x.streak += 1; x.bestStreak = max(x.bestStreak, x.streak); x.bestWin = max(x.bestWin, mine - theirs)
                } else if mine == theirs && win == nil { x.d += 1; x.streak = 0 }
                else { x.l += 1; x.streak = 0 }
                c[me] = x
            }
        }
        return members.compactMap { c[$0.id] }.sorted {
            if $0.titles != $1.titles { return $0.titles > $1.titles }
            if $0.w != $1.w { return $0.w > $1.w }
            return $0.gf - $0.ga > $1.gf - $1.ga
        }
    }

    /// المواجهات المباشرة بين لاعبين: (فوز أ، تعادل، فوز ب، أهداف أ، أهداف ب)
    static func h2h(_ a: UUID, _ b: UUID, _ ts: [Tournament]) -> (aw: Int, d: Int, bw: Int, ag: Int, bg: Int, games: [Game]) {
        var aw = 0, d = 0, bw = 0, ag = 0, bg = 0
        var list: [Game] = []
        for t in ts {
            for g in t.games where g.played && !g.bye {
                guard let h = g.home, let w = g.away, let hg = g.hg, let wg = g.ag else { continue }
                guard (h == a && w == b) || (h == b && w == a) else { continue }
                list.append(g)
                let mine = h == a ? hg : wg, theirs = h == a ? wg : hg
                ag += mine; bg += theirs
                if let win = g.winner { if win == a { aw += 1 } else { bw += 1 } } else { d += 1 }
            }
        }
        list.sort { ($0.at ?? .distantPast) > ($1.at ?? .distantPast) }
        return (aw, d, bw, ag, bg, list)
    }
}
