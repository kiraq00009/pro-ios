import Foundation

// MARK: الهدف والتقييم

enum Goal: Equatable {
    /// اقطع بحيث الجهة الأصغر = هالنسبة
    case percent(Int)
    /// n قطع متساوية بقطعتين
    case equal(Int)

    var cuts: Int {
        switch self {
        case .percent: return 1
        case .equal: return 2
        }
    }
    var title: String {
        switch self {
        case .percent(let p): return "اقطع \(p)%"
        case .equal(let n): return "\(n) قطع متساوية"
        }
    }
}

enum Grade: Int, CaseIterable {
    case miss = 0, ok, good, great, perfect

    static func of(_ e: Double) -> Grade {
        if e <= 1 { return .perfect }
        if e <= 3 { return .great }
        if e <= 6 { return .good }
        if e <= 10 { return .ok }
        return .miss
    }
    var title: String {
        switch self {
        case .perfect: return "مثالي!"
        case .great: return "دقيق!"
        case .good: return "حلو"
        case .ok: return "قريب"
        case .miss: return "فاتتك"
        }
    }
}

enum Judge {
    /// نسبة الجهة الأصغر من القطعة الأولى (٠–٥٠)
    static func smallerPercent(_ r: CutResult) -> Double {
        let tot = r.plusArea + r.minusArea
        guard tot > 0 else { return 0 }
        return min(r.plusArea, r.minusArea) / tot * 100
    }
    /// نسب كلّ القطع من المجموع
    static func percents(_ pieces: [Shape]) -> [Double] {
        let tot = pieces.reduce(0.0) { $0 + $1.area }
        guard tot > 0 else { return pieces.map { _ in 0 } }
        return pieces.map { $0.area / tot * 100 }
    }
    /// أكبر ابتعاد عن الحصّة المتساوية؛ إذا عدد القطع غلط = ٢٠ (فاتتك أكيد)
    static func equalError(_ pieces: [Shape], n: Int) -> Double {
        guard n > 0, pieces.count == n else { return 20 }
        let target = 100 / Double(n)
        return percents(pieces).map { abs($0 - target) }.max() ?? 20
    }
    static func error(percent achieved: Double, target: Int) -> Double { abs(achieved - Double(target)) }

    static func hitsNail(_ L: Line, _ nails: [Nail]) -> Int? {
        for (i, n) in nails.enumerated() where L.dist(n.p) < n.r { return i }
        return nil
    }
}

enum Scoring {
    static func points(_ e: Double, combo: Int) -> Int {
        let base = max(0, 10 - e) * 10
        let bonus: Double = e <= 1 ? 50 : 0
        let mult = 1 + 0.25 * Double(min(combo, 8))
        return Int(((base + bonus) * mult).rounded())
    }
    static func nextCombo(_ c: Int, _ g: Grade) -> Int { g.rawValue >= Grade.great.rawValue ? c + 1 : 0 }
    static func comboLabel(_ c: Int) -> String? {
        if c == 3 { return "جرّاح!" }
        if c == 5 { return "يد من ذهب!" }
        if c >= 8 && c % 4 == 0 { return "أسطورة الشقّ!" }
        return nil
    }
    /// النجوم من معدّل الخطأ
    static func stars(_ errors: [Double]) -> Int {
        guard !errors.isEmpty else { return 0 }
        let avg = errors.reduce(0, +) / Double(errors.count)
        if avg <= 1.5 { return 3 }
        if avg <= 4 { return 2 }
        if avg <= 8 { return 1 }
        return 0
    }
    static func coins(stars: Int, perfects: Int, improved: Int) -> Int { improved * 10 + stars * 3 + perfects * 2 }
}

// MARK: الحركة والمراحل

struct Motion: Equatable {
    var spin = 0.0
    var driftX = 0.0, driftY = 0.0, driftW = 0.0
    var pulse = 0.0, pulseW = 0.0
    static let still = Motion()

    var moving: Bool { spin != 0 || driftX != 0 || driftY != 0 || pulse != 0 }

    func scale(_ t: Double) -> Double { 1 + pulse * sin(pulseW * t) }
    func angle(_ t: Double) -> Double { spin * t }
    func offset(_ t: Double) -> P { P(driftX * sin(driftW * t), driftY * sin(driftW * 0.73 * t + 1.3)) }
}

struct Nail: Equatable {
    var p: P
    var r: Double
}

struct Round: Equatable {
    var kind: ShapeKind
    var seed: UInt64
    var vary: Bool
    var goal: Goal
    var motion: Motion
    var nails: [Nail]
    var time: Double?

    var shape: Shape { ShapeLib.make(kind, seed: seed, vary: vary) }
    func placed(_ t: Double) -> Shape {
        shape.placed(scale: motion.scale(t), angle: motion.angle(t), offset: motion.offset(t))
    }
}

struct Level: Equatable {
    var world: Int
    var index: Int
    var rounds: [Round]
    var id: Int { world * Levels.perWorld + index }
}

struct WorldInfo {
    let name: String
    let note: String
    let icon: String
}

enum Levels {
    static let worldCount = 6
    static let perWorld = 10
    static let total = 60

    static let worlds: [WorldInfo] = [
        WorldInfo(name: "أوّل شقّ", note: "أشكال ثابتة ونِسَب سهلة", icon: "scissors"),
        WorldInfo(name: "دوّامة", note: "الأشكال تدور — اختر لحظتك", icon: "arrow.triangle.2.circlepath"),
        WorldInfo(name: "رقصة", note: "تتحرّك وتنبض وتلفّ", icon: "waveform.path"),
        WorldInfo(name: "فراغات", note: "حروف مقعّرة وأشكال مثقوبة", icon: "circle.dashed"),
        WorldInfo(name: "توأم", note: "قطعتان لكلّ دور — قطع متساوية", icon: "square.split.2x2"),
        WorldInfo(name: "الخبير", note: "وقت ضيّق ومسامير وكلّ شي", icon: "bolt.fill"),
    ]

    static func level(_ id: Int) -> Level {
        let w = max(0, min(worldCount - 1, id / perWorld)), i = max(0, min(perWorld - 1, id % perWorld))
        if i == 0 { return Level(world: w, index: 0, rounds: handmade(w)) }
        var g = SRng(UInt64(1000 + id) &* 7919)
        let n = i == perWorld - 1 ? 5 : (w >= 3 ? 4 : 3)
        let d = Double(i) / Double(perWorld - 1)
        var rs: [Round] = []
        for r in 0..<n { rs.append(campaignRound(w, d, r, &g)) }
        return Level(world: w, index: i, rounds: rs)
    }

    private static func campaignRound(_ w: Int, _ d: Double, _ r: Int, _ g: inout SRng) -> Round {
        let seed = g.next()
        switch w {
        case 0:
            let extra: [ShapeKind] = d > 0.5 ? [.star, .blob] : []
            let kind = g.pick(ShapeLib.convex + extra, .square)
            let pool: [Int] = d < 0.4 ? [50, 25, 50, 33, 40] : [20, 25, 30, 33, 40, 45, 15]
            return Round(kind: kind, seed: seed, vary: d > 0.3, goal: .percent(g.pick(pool, 50)), motion: .still, nails: [], time: nil)
        case 1:
            let kind = g.pick(ShapeLib.convex + ShapeLib.curvy, .hexagon)
            let m = Motion(spin: g.sign() * g.range(0.35, 0.6 + d * 0.7))
            return Round(kind: kind, seed: seed, vary: true, goal: .percent(g.int(10, 50)), motion: m, nails: [], time: nil)
        case 2:
            let kind = g.pick(ShapeLib.curvy + ShapeLib.convex, .heart)
            return Round(kind: kind, seed: seed, vary: true, goal: .percent(g.int(10, 50)), motion: dance(&g, 0.5 + d * 0.5), nails: [], time: d > 0.7 ? 9 : nil)
        case 3:
            let kind = g.pick(ShapeLib.letters + ShapeLib.holed, .lShape)
            let m = Motion(spin: g.sign() * g.range(0.1, 0.25 + d * 0.35))
            return Round(kind: kind, seed: seed, vary: true, goal: .percent(g.int(10, 50)), motion: d < 0.2 ? .still : m, nails: [], time: nil)
        case 4:
            if r % 2 == 0 || g.chance(0.5) {
                let n = g.chance(0.3 + d * 0.3) ? 4 : 3
                let kind = n == 4 ? g.pick(ShapeLib.quad, .square) : g.pick(ShapeLib.convex, .square)
                let m = d > 0.5 ? Motion(spin: g.sign() * g.range(0.2, 0.4)) : Motion.still
                return Round(kind: kind, seed: seed, vary: false, goal: .equal(n), motion: m, nails: [], time: nil)
            }
            let kind = g.pick(ShapeLib.curvy + ShapeLib.letters, .star)
            return Round(kind: kind, seed: seed, vary: true, goal: .percent(g.int(10, 50)), motion: dance(&g, 0.5), nails: [], time: nil)
        default:
            let t = 8.0 - d * 3.5
            if r == 1 || (r == 3 && d > 0.5) { return nailRound(&g, seed: seed, time: t + 2) }
            if g.chance(0.25) {
                return Round(kind: g.pick(ShapeLib.convex, .square), seed: seed, vary: false, goal: .equal(3), motion: Motion(spin: g.sign() * 0.3), nails: [], time: t + 3)
            }
            let all = ShapeLib.curvy + ShapeLib.letters + ShapeLib.holed
            return Round(kind: g.pick(all, .gear), seed: seed, vary: true, goal: .percent(g.int(10, 50)), motion: dance(&g, 0.7 + d * 0.4), nails: [], time: t)
        }
    }

    static func dance(_ g: inout SRng, _ k: Double) -> Motion {
        Motion(spin: g.sign() * g.range(0.2, 0.6) * k,
               driftX: g.range(0.12, 0.32) * k, driftY: g.range(0.08, 0.25) * k, driftW: g.range(0.8, 1.5),
               pulse: g.chance(0.6) ? g.range(0.05, 0.12) * k : 0, pulseW: g.range(1.5, 3))
    }

    /// مرحلة «اقطع من الفتحة»: مسماران عند طرفي خطّ الحلّ، والفتحة بينهم ضيّقة
    static func nailRound(_ g: inout SRng, seed: UInt64, time: Double?) -> Round {
        let kind = g.pick(ShapeLib.convex + ShapeLib.curvy, .hexagon)
        let target = g.int(15, 50)
        var r = Round(kind: kind, seed: seed, vary: true, goal: .percent(target), motion: .still, nails: [], time: time)
        r.nails = gapNails(r.shape, target: target, angle: g.range(0, Double.pi), gap: g.range(0.09, 0.13))
        return r
    }

    static func gapNails(_ s: Shape, target: Int, angle: Double, gap: Double, nailR: Double = 0.06) -> [Nail] {
        let L = Cutter.solve(s, angle: angle, fraction: Double(target) / 100)
        let ts: [Double] = s.outer.map { L.param($0) }
        let lo = (ts.min() ?? -1) - 0.18, hi = (ts.max() ?? 1) + 0.18
        var out: [Nail] = []
        for t in [lo, hi] {
            let c = L.at(t)
            out.append(Nail(p: c + L.normal * (gap + nailR), r: nailR))
            out.append(Nail(p: c - L.normal * (gap + nailR), r: nailR))
        }
        return out
    }

    /// المراحل الأولى بكلّ عالم مصمَّمة باليد
    static func handmade(_ w: Int) -> [Round] {
        func R(_ k: ShapeKind, _ goal: Goal, _ m: Motion = .still, seed: UInt64 = 7, vary: Bool = false, time: Double? = nil) -> Round {
            Round(kind: k, seed: seed, vary: vary, goal: goal, motion: m, nails: [], time: time)
        }
        switch w {
        case 0: return [R(.square, .percent(50)), R(.triangle, .percent(50)), R(.hexagon, .percent(25))]
        case 1: return [R(.square, .percent(50), Motion(spin: 0.5)), R(.star, .percent(30), Motion(spin: -0.45), seed: 3), R(.blob, .percent(40), Motion(spin: 0.6), seed: 11, vary: true)]
        case 2: return [R(.heart, .percent(50), Motion(spin: 0, driftX: 0.25, driftY: 0, driftW: 1.1)),
                        R(.disc, .percent(25), Motion(spin: 0, driftX: 0, driftY: 0, driftW: 1, pulse: 0.12, pulseW: 2.2)),
                        R(.moon, .percent(35), Motion(spin: 0.35, driftX: 0.2, driftY: 0.15, driftW: 1.2))]
        case 3: return [R(.lShape, .percent(40)), R(.frame, .percent(50), seed: 5), R(.ring, .percent(30), Motion(spin: 0.2), seed: 9), R(.uShape, .percent(25))]
        case 4: return [R(.square, .equal(3)), R(.disc, .equal(4)), R(.hexagon, .percent(50), Motion(spin: 0.3)), R(.square, .equal(4), Motion(spin: 0.25))]
        default:
            var g = SRng(4242)
            return [R(.star, .percent(33), Motion(spin: 0.5), seed: 21, vary: true, time: 7),
                    nailRound(&g, seed: 77, time: 10),
                    R(.cheese, .percent(40), Motion(spin: -0.3, driftX: 0.2, driftY: 0.1, driftW: 1), seed: 13, vary: true, time: 7),
                    R(.triangle, .equal(3), Motion(spin: 0.3), time: 10)]
        }
    }

    /// تحدّي اليوم: نفس التاريخ = نفس الخمس جولات للكلّ
    static func daily(_ y: Int, _ m: Int, _ d: Int) -> Level {
        let key = UInt64(max(0, y * 10000 + m * 100 + d))
        var g = SRng(key &* 2654435761)
        var rs: [Round] = []
        for i in 0..<5 {
            let seed = g.next()
            if i == 3 { rs.append(nailRound(&g, seed: seed, time: 12)); continue }
            if i == 4 && g.chance(0.5) {
                rs.append(Round(kind: g.pick(ShapeLib.convex, .square), seed: seed, vary: false, goal: .equal(3), motion: Motion(spin: 0.25), nails: [], time: 12)); continue
            }
            let all = ShapeLib.convex + ShapeLib.curvy + ShapeLib.letters + ShapeLib.holed
            rs.append(Round(kind: g.pick(all, .star), seed: seed, vary: true, goal: .percent(g.int(10, 50)), motion: dance(&g, 0.4 + Double(i) * 0.15), nails: [], time: 10))
        }
        return Level(world: -1, index: 0, rounds: rs)
    }

    /// بلا نهاية: تصعب تدريجيًّا مع رقم الجولة
    static func endless(_ i: Int, seed: UInt64) -> Round {
        var g = SRng(seed &+ UInt64(max(0, i)) &* 104729)
        let d = min(1, Double(i) / 24)
        var pool = ShapeLib.convex
        if i >= 3 { pool += ShapeLib.curvy }
        if i >= 8 { pool += ShapeLib.letters }
        if i >= 12 { pool += ShapeLib.holed }
        let time: Double? = i < 2 ? nil : max(3.5, 9 - Double(i) * 0.25)
        let s = g.next()
        if i >= 10 && i % 7 == 3 { return nailRound(&g, seed: s, time: time.map { $0 + 2 }) }
        if i >= 6 && i % 5 == 0 {
            return Round(kind: g.pick(ShapeLib.convex, .square), seed: s, vary: false, goal: .equal(3), motion: Motion(spin: g.sign() * 0.25), nails: [], time: time.map { $0 + 3 })
        }
        let m: Motion = i < 2 ? .still : dance(&g, 0.25 + d * 0.8)
        return Round(kind: g.pick(pool, .square), seed: s, vary: i >= 1, goal: .percent(g.int(10, 50)), motion: m, nails: [], time: time)
    }

    /// زِن: هادئ، بلا وقت
    static func zen(_ i: Int, seed: UInt64) -> Round {
        var g = SRng(seed &+ UInt64(max(0, i)) &* 15485863)
        let all = ShapeLib.convex + ShapeLib.curvy + ShapeLib.letters + ShapeLib.holed
        let m = Motion(spin: g.sign() * g.range(0.08, 0.2), driftX: 0, driftY: 0.05, driftW: 0.6, pulse: 0.03, pulseW: 1)
        return Round(kind: g.pick(all, .blob), seed: g.next(), vary: true, goal: .percent(g.int(10, 50)), motion: m, nails: [], time: nil)
    }
}
