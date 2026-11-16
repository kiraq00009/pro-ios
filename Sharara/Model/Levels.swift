import Foundation

enum Mode: String, Codable, CaseIterable {
    case campaign, endless, daily, perfect
}

/// وصفة مرحلة — تتحوّل لعالم بالمولّد
struct LevelSpec {
    var mode: Mode
    var index: Int
    var seed: UInt64
    var counts: [Int]          // عدد كلّ نوع بترتيب OrbKind.allCases
    var speed: Double
    var baseR: Double
    var sparkR: Double
    var designFrac: Double

    var total: Int { counts.reduce(0, +) }
    func count(_ k: OrbKind) -> Int { k.rawValue < counts.count ? counts[k.rawValue] : 0 }
}

/// مرحلة جاهزة: العالم الابتدائيّ + الهدف + عتبات النجوم
struct Level {
    let spec: LevelSpec
    let world: World
    let target: Int
    let best: Int
    let bestTap: P
    let goodTotal: Int
    let t2: Int
    let t3: Int

    func stars(_ net: Int) -> Int {
        if net >= t3 { return 3 }
        if net >= t2 { return 2 }
        if net >= target { return 1 }
        return 0
    }
    func passed(_ net: Int) -> Bool { net >= target }
}

enum Gen {
    static let galaxyCount = 8
    static let perGalaxy = 10
    static var campaignCount: Int { galaxyCount * perGalaxy }
    static let perfectCount = 24

    static let galaxyNames = ["فجر النجوم", "سديم الورد", "حقل الجليد", "دوّامة الزمرّد",
                              "شمس الكهرمان", "بحر الأرجوان", "الثقب الأسود", "قلب الشرارة"]
    /// النوع الجديد اللي تعرّفه كلّ مجرّة
    static let galaxyIntro: [OrbKind] = [.big, .bouncer, .shield, .splitter, .timer, .magnet, .bad, .normal]

    /// الأنواع الخاصّة المتاحة بمجرّة g
    static func specials(upTo g: Int) -> [OrbKind] {
        var out: [OrbKind] = []
        let n = min(max(g, 0), 6)
        for i in 0...n where galaxyIntro[i] != .bad && galaxyIntro[i] != .normal { out.append(galaxyIntro[i]) }
        return out
    }

    // MARK: الحملة

    static func campaign(_ i: Int) -> LevelSpec {
        let ii = min(max(i, 0), campaignCount - 1)
        let g = ii / perGalaxy, k = ii % perGalaxy
        var rng = SRNG(UInt64(1000 + ii * 7919))
        let total = 24 + g * 3 + k
        var counts = [Int](repeating: 0, count: OrbKind.allCases.count)
        let pool = specials(upTo: g)
        // النوع الجديد ياخذ حصّة واضحة
        let intro = galaxyIntro[g]
        var left = total
        if intro != .normal && intro != .bad && !(g == 0 && k < 4) {
            let n = 2 + k / 3
            counts[intro.rawValue] += n
            left -= n
        }
        // أنواع خاصّة إضافيّة عشوائيّة
        let extra = g == 0 ? (k < 4 ? 0 : 1) : min(left / 3, 1 + k / 3 + g / 2)
        if !pool.isEmpty {
            for _ in 0..<extra {
                let kind = pool[rng.int(pool.count)]
                counts[kind.rawValue] += 1
                left -= 1
            }
        }
        if g >= 6 {
            let nb = 2 + k / 3 + (g - 6) * 2
            counts[OrbKind.bad.rawValue] += nb
            left -= nb
        }
        counts[OrbKind.normal.rawValue] += max(4, left)
        let speed = 18 + Double(g) * 5 + Double(k) * 1.2
        let baseR = 70 - Double(g) * 1.4 - Double(k) * 0.4
        let frac = min(0.85, 0.30 + Double(g) * 0.06 + Double(k) * 0.012)
        return LevelSpec(mode: .campaign, index: ii, seed: UInt64(77 + ii * 104729), counts: counts,
                         speed: speed, baseR: baseR, sparkR: baseR * 1.15, designFrac: frac)
    }

    // MARK: بلا نهاية — الحصّة تكبر كلّ جولة

    static func endless(round r: Int, runSeed: UInt64) -> LevelSpec {
        let rr = max(0, r)
        var rng = SRNG(runSeed &+ UInt64(rr) &* 31337)
        let total = 24 + min(rr * 2, 26)
        var counts = [Int](repeating: 0, count: OrbKind.allCases.count)
        let pool = specials(upTo: min(6, rr / 2))
        var left = total
        let nSpecial = min(total / 2, 2 + rr)
        if !pool.isEmpty {
            for _ in 0..<nSpecial {
                let kind = pool[rng.int(pool.count)]
                counts[kind.rawValue] += 1
                left -= 1
            }
        }
        if rr >= 4 {
            let nb = min(6, 1 + (rr - 4) / 2)
            counts[OrbKind.bad.rawValue] = nb
            left -= nb
        }
        counts[OrbKind.normal.rawValue] = max(4, left)
        let baseR = 68 - Double(min(rr, 12)) * 1.2
        return LevelSpec(mode: .endless, index: rr, seed: runSeed &+ UInt64(rr) &* 104729, counts: counts,
                         speed: 22 + Double(min(rr, 16)) * 2.5, baseR: baseR, sparkR: baseR * 1.15,
                         designFrac: endlessQuota(rr))
    }

    /// النسبة المطلوبة بجولة r — تصعد وتوقف عند ٨٥٪
    static func endlessQuota(_ r: Int) -> Double { min(0.85, 0.35 + Double(max(0, r)) * 0.04) }

    // MARK: تحدّي اليوم

    static func daily(day: Int) -> LevelSpec {
        let seed = UInt64(max(0, day)) &* 2654435761 &+ 12345
        var rng = SRNG(seed)
        var counts = [Int](repeating: 0, count: OrbKind.allCases.count)
        let pool = specials(upTo: 6)
        var left = 40
        for _ in 0..<12 {
            let kind = pool[rng.int(pool.count)]
            counts[kind.rawValue] += 1
            left -= 1
        }
        counts[OrbKind.bad.rawValue] = 3 + rng.int(3)
        left -= counts[OrbKind.bad.rawValue]
        counts[OrbKind.normal.rawValue] = left
        let baseR = rng.range(58, 64)
        return LevelSpec(mode: .daily, index: day, seed: seed, counts: counts, speed: rng.range(26, 40),
                         baseR: baseR, sparkR: baseR * 1.15, designFrac: 0.6)
    }

    // MARK: الضربة الكاملة — لازم توصل أعلى رقم ممكن

    static func perfect(_ i: Int) -> LevelSpec {
        let ii = min(max(i, 0), perfectCount - 1)
        var rng = SRNG(UInt64(555 + ii * 6007))
        var counts = [Int](repeating: 0, count: OrbKind.allCases.count)
        let total = 14 + ii
        let pool = specials(upTo: min(6, 1 + ii / 3))
        var left = total
        for _ in 0..<(2 + ii / 2) {
            let kind = pool[rng.int(pool.count)]
            counts[kind.rawValue] += 1
            left -= 1
        }
        if ii >= 8 {
            counts[OrbKind.bad.rawValue] = 1 + (ii - 8) / 5
            left -= counts[OrbKind.bad.rawValue]
        }
        counts[OrbKind.normal.rawValue] = max(4, left)
        let baseR = 70 - Double(ii) * 0.6
        return LevelSpec(mode: .perfect, index: ii, seed: UInt64(9001 + ii * 7727), counts: counts,
                         speed: 10 + Double(ii) * 0.5, baseR: baseR, sparkR: baseR * 1.1, designFrac: 1.0)
    }

    // MARK: المولّد

    static func world(_ spec: LevelSpec) -> World {
        var rng = SRNG(spec.seed)
        var kinds: [OrbKind] = []
        for k in OrbKind.allCases {
            let n = spec.count(k)
            if n > 0 { for _ in 0..<n { kinds.append(k) } }
        }
        rng.shuffle(&kinds)
        var orbs: [Orb] = []
        for (idx, k) in kinds.enumerated() {
            let r = k.radius
            var best = P(Tune.W / 2, Tune.H / 2)
            var bestGap = -1.0
            for _ in 0..<28 {
                let c = P(rng.range(r + 8, Tune.W - r - 8), rng.range(r + 8, Tune.H - r - 8))
                var gap = 1e9
                for o in orbs { gap = min(gap, c.dist(o.pos) - o.r - r) }
                if gap >= 8 { best = c; bestGap = gap; break }
                if gap > bestGap { bestGap = gap; best = c }
            }
            let a = rng.range(0, 2 * Double.pi)
            let sp = spec.speed * k.speedMul * rng.range(0.6, 1.2)
            let ph = rng.range(0, 2 * Double.pi)
            orbs.append(Orb(id: idx, kind: k, pos: best, vel: P(cos(a), sin(a)) * sp, phase: ph))
        }
        return World(orbs: orbs, baseR: spec.baseR, sparkR: spec.sparkR)
    }

    /// الحلّال: يجرّب الضرب على كلّ كرة وعلى شبكة نقاط، ويرجع أحسن صافي
    static func probe(_ w: World) -> (best: Int, tap: P) {
        var cands: [P] = w.orbs.map { $0.pos }
        for gy in 0..<6 {
            for gx in 0..<4 {
                cands.append(P(Tune.W * (Double(gx) + 0.5) / 4, Tune.H * (Double(gy) + 0.5) / 6))
            }
        }
        var best = Int.min
        var tap = P(Tune.W / 2, Tune.H / 2)
        for c in cands {
            let o = w.simulate(tapAt: c)
            if o.net > best { best = o.net; tap = c }
        }
        return (best, tap)
    }

    static func make(_ spec0: LevelSpec) -> Level {
        var spec = spec0
        var w = world(spec)
        var pr = probe(w)
        // نضمن الحلّ: إذا ماكو ضربة تفيد نغيّر البذرة
        var tries = 0
        while pr.best < 1 && tries < 6 {
            spec.seed = spec.seed &+ 97
            w = world(spec)
            pr = probe(w)
            tries += 1
        }
        if spec.mode == .perfect {
            // ندوّر على ترتيب تنحصد بيه كلّ الكرات الطيّبة بضربة وحدة
            var tries2 = 0
            while pr.best < w.goodTotal && tries2 < 6 {
                var s2 = spec
                s2.seed = spec.seed &+ UInt64(1 + tries2) &* 1009
                let w2 = world(s2)
                let p2 = probe(w2)
                if Double(p2.best) / Double(max(1, w2.goodTotal)) > Double(pr.best) / Double(max(1, w.goodTotal)) {
                    spec = s2; w = w2; pr = p2
                }
                tries2 += 1
            }
        }
        let good = w.goodTotal
        let best = max(1, pr.best)
        let design = max(1, Int((Double(good) * spec.designFrac).rounded()))
        let target = max(1, min(design, best))
        let t3 = max(target, best)
        let t2 = (target + t3 + 1) / 2
        return Level(spec: spec, world: w, target: target, best: best, bestTap: pr.tap,
                     goodTotal: good, t2: t2, t3: t3)
    }
}

/// أيّام: رقم اليوم منذ ١٩٧٠ (للتحدّي اليوميّ والسلسلة)
enum Days {
    static func index(_ secondsSince1970: Double, tzOffset: Int) -> Int {
        Int(((secondsSince1970 + Double(tzOffset)) / 86400).rounded(.down))
    }
    /// كم يوم ورا بعض لحدّ اليوم (أو البارحة إذا اليوم بعده ما انلعب)
    static func streak(_ done: [Int], today: Int) -> Int {
        let s = Set(done)
        var d = s.contains(today) ? today : today - 1
        var n = 0
        while s.contains(d) { n += 1; d -= 1 }
        return n
    }
}
