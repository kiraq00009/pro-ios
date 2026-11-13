import Foundation

// محرّك لعبة النرد (الطاولة) — منطق خالص ينفحص آليًّا
//
// اللوحة ٢٤ خانة (0…23). اللاعب 0 يمشي من 23 نزولًا لـ0 (بيته 0…5). اللاعب 1 يمشي من 0 صعودًا لـ23 (بيته 18…23).

struct Move: Codable, Hashable {
    var from: Int        // رقم الخانة، أو ‎-1 = من البار
    var to: Int          // رقم الخانة، أو 99 = إخراج
    var die: Int
    var hit = false
}

struct Board: Codable, Hashable {
    var pts: [Int]                 // موجب = أحجار اللاعب 0 · سالب = أحجار اللاعب 1
    var bar: [Int] = [0, 0]
    var off: [Int] = [0, 0]

    static let start: Board = {
        var p = [Int](repeating: 0, count: 24)
        p[23] = 2; p[12] = 5; p[7] = 3; p[5] = 5
        p[0] = -2; p[11] = -5; p[16] = -3; p[18] = -5
        return Board(pts: p)
    }()

    func count(_ player: Int, at i: Int) -> Int { player == 0 ? max(0, pts[i]) : max(0, -pts[i]) }
    func total(_ player: Int) -> Int { (0..<24).reduce(0) { $0 + count(player, at: $1) } + bar[player] + off[player] }

    /// مجموع المسافة الباقية لكلّ الأحجار (كلّ ما قلّ أحسن)
    func pips(_ player: Int) -> Int {
        var s = bar[player] * 25
        for i in 0..<24 { s += count(player, at: i) * (player == 0 ? i + 1 : 24 - i) }
        return s
    }
    func allHome(_ player: Int) -> Bool {
        if bar[player] > 0 { return false }
        for i in 0..<24 where count(player, at: i) > 0 { if (player == 0 ? i > 5 : i < 18) { return false } }
        return true
    }
    private func open(_ player: Int, _ i: Int) -> Bool { count(1 - player, at: i) <= 1 }

    /// الحركات الممكنة بزار واحد
    func moves(_ player: Int, die d: Int) -> [Move] {
        var out: [Move] = []
        if bar[player] > 0 {
            let to = player == 0 ? 24 - d : d - 1
            if open(player, to) { out.append(Move(from: -1, to: to, die: d, hit: count(1 - player, at: to) == 1)) }
            return out
        }
        let home = allHome(player)
        for i in 0..<24 where count(player, at: i) > 0 {
            let to = player == 0 ? i - d : i + d
            if to >= 0 && to <= 23 {
                if open(player, to) { out.append(Move(from: i, to: to, die: d, hit: count(1 - player, at: to) == 1)) }
            } else if home {
                // إخراج: بالضبط، أو بزار أكبر إذا ما أكو حجر أبعد
                let dist = player == 0 ? i + 1 : 24 - i
                if dist == d { out.append(Move(from: i, to: 99, die: d)) }
                else if d > dist {
                    var farther = false
                    for j in 0..<24 where count(player, at: j) > 0 { if (player == 0 ? j + 1 : 24 - j) > dist { farther = true; break } }
                    if !farther { out.append(Move(from: i, to: 99, die: d)) }
                }
            }
        }
        return out
    }

    func applying(_ m: Move, _ player: Int) -> Board {
        var b = self
        let s = player == 0 ? 1 : -1
        if m.from == -1 { b.bar[player] -= 1 } else { b.pts[m.from] -= s }
        if m.to == 99 { b.off[player] += 1 }
        else {
            if b.count(1 - player, at: m.to) == 1 { b.pts[m.to] = 0; b.bar[1 - player] += 1 }
            b.pts[m.to] += s
        }
        return b
    }

    var winner: Int? { off[0] == 15 ? 0 : (off[1] == 15 ? 1 : nil) }
    /// قيمة الفوز: 1 عاديّ · 2 مارس (الخاسر ما طلّع ولا حجر) · 3 مارس مضاعف (وإله حجر بالبار أو ببيت الفائز)
    func winValue(_ w: Int) -> Int {
        let l = 1 - w
        if off[l] > 0 { return 1 }
        if bar[l] > 0 { return 3 }
        for i in 0..<24 where count(l, at: i) > 0 { if (w == 0 ? i <= 5 : i >= 18) { return 3 } }
        return 2
    }
}

enum BG {
    /// الزارات اللي تنلعب من رمية: الدبل ينلعب أربع مرّات
    static func dice(_ a: Int, _ b: Int) -> [Int] { a == b ? [a, a, a, a] : [a, b] }

    /// كلّ التسلسلات القانونيّة لدور كامل: لازم تلعب أكثر عدد زارات ممكن، وإذا ينلعب واحد بس فالأكبر
    static func turns(_ b: Board, _ player: Int, dice: [Int]) -> [[Move]] {
        var best: [[Move]] = []
        var maxLen = 0
        var seen = Set<String>()
        func go(_ cur: Board, _ left: [Int], _ path: [Move]) {
            var any = false
            var tried = Set<Int>()
            for (k, d) in left.enumerated() where tried.insert(d).inserted {
                var rest = left; rest.remove(at: k)
                for m in cur.moves(player, die: d) {
                    any = true
                    go(cur.applying(m, player), rest, path + [m])
                }
            }
            if !any {
                if path.count > maxLen { maxLen = path.count; best = []; seen = [] }
                if path.count == maxLen {
                    // نفس التسلسل ممكن يوصل بطريقين — نحتفظ بوحدة
                    let key = path.map { "\($0.from)>\($0.to)/\($0.die)" }.joined(separator: ",")
                    if seen.insert(key).inserted { best.append(path) }
                }
            }
        }
        go(b, dice, [])
        if maxLen == 0 { return [] }
        if maxLen == 1 && dice.count == 2 && dice[0] != dice[1] {
            let big = max(dice[0], dice[1])
            let withBig = best.filter { $0[0].die == big }
            if !withBig.isEmpty { return withBig }
        }
        return best
    }

    // MARK: الذكاء

    /// تقييم وضع اللوحة من وجهة نظر `p` (أكبر = أحسن)
    static func evaluate(_ b: Board, _ p: Int) -> Double {
        let o = 1 - p
        if b.off[p] == 15 { return 10_000 }
        var s = Double(b.pips(o) - b.pips(p))                      // السباق
        s += Double(b.bar[o]) * 22 - Double(b.bar[p]) * 26
        s += Double(b.off[p]) * 9 - Double(b.off[o]) * 9
        // هل بعدهم متواجهين؟ (إذا خلص التماسّ فالحجر المنفرد ما يضرّ)
        var pBack = -1, oBack = -1
        for i in 0..<24 {
            if b.count(p, at: i) > 0 { let d = p == 0 ? i : 23 - i; pBack = max(pBack, d) }
            if b.count(o, at: i) > 0 { let d = o == 0 ? i : 23 - i; oBack = max(oBack, d) }
        }
        if b.bar[p] > 0 { pBack = 24 }; if b.bar[o] > 0 { oBack = 24 }
        let contact = pBack + oBack >= 23
        var run = 0, bestRun = 0
        let order = p == 0 ? Array(0..<24) : Array((0..<24).reversed())      // من بيتي لبرّا
        for (k, i) in order.enumerated() {
            let c = b.count(p, at: i)
            if c >= 2 {
                run += 1; bestRun = max(bestRun, run)
                s += k < 6 ? 7 : (k < 12 ? 5 : 2)                            // خانة مقفولة (ببيتي أغلى)
                if c > 3 { s -= Double(c - 3) * 2.5 }                        // تكديس زايد
            } else {
                run = 0
                if c == 1 && contact {
                    // حجر منفرد: خطره حسب كم حجر للخصم يگدر يوصله
                    var shooters = 0
                    for j in 0..<24 where b.count(o, at: j) > 0 {
                        let dist = o == 0 ? j - i : i - j
                        if dist > 0 && dist <= 12 { shooters += dist <= 6 ? 2 : 1 }
                    }
                    if b.bar[o] > 0 { shooters += 2 }
                    let lost = Double(p == 0 ? 24 - i : i + 1)               // شگد يخسر إذا انضرب
                    s -= Double(min(shooters, 6)) * (2.2 + lost * 0.28)
                }
            }
        }
        s += Double(bestRun * bestRun) * 1.6                                 // حاجز متواصل
        return s
    }

    /// يختار دور الجهاز: level 0 سهل (عشوائيّ مايل للزين) · 1 وسط (أحسن تقييم) · 2 صعب (يحسب ردّ الخصم على كلّ الرميات)
    static func choose(_ b: Board, _ player: Int, dice: [Int], level: Int, using rng: inout some RandomNumberGenerator) -> [Move] {
        let all = turns(b, player, dice: dice)
        guard !all.isEmpty else { return [] }
        var scored: [([Move], Board, Double)] = []
        var seen = Set<Board>()
        for t in all {
            var c = b; for m in t { c = c.applying(m, player) }
            if seen.insert(c).inserted { scored.append((t, c, evaluate(c, player))) }
        }
        scored.sort { $0.2 > $1.2 }
        if level == 0 {
            let top = scored.prefix(max(1, scored.count / 2 + 1))
            return (Int.random(in: 0..<100, using: &rng) < 45 ? top.randomElement(using: &rng)! : scored[0]).0
        }
        if level == 1 || scored.count == 1 { return scored[0].0 }
        // صعب: لأحسن المرشّحين نحسب كلّ ردود الخصم على الـ٢١ رمية — الخصم يختار الأسوأ إلنا
        func leaf(_ c: Board) -> Double { evaluate(c, player) - evaluate(c, 1 - player) }
        var bestT = scored[0].0, bestV = -Double.infinity
        for cand in scored.prefix(8) {
            if cand.1.winner == player { return cand.0 }
            var sum = 0.0
            for a in 1...6 { for d in a...6 {
                let w = a == d ? 1.0 : 2.0
                var worst = Double.infinity
                let replies = turns(cand.1, 1 - player, dice: BG.dice(a, d))
                if replies.isEmpty { worst = leaf(cand.1) }
                else {
                    var seenR = Set<Board>()
                    for r in replies {
                        var c = cand.1; for m in r { c = c.applying(m, 1 - player) }
                        if seenR.insert(c).inserted { worst = min(worst, c.winner == nil ? leaf(c) : -5_000) }
                    }
                }
                sum += worst * w
            } }
            let v = sum / 36
            if v > bestV { bestV = v; bestT = cand.0 }
        }
        return bestT
    }
}
