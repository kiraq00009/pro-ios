import Foundation

/// مولّد عشوائيّ ببذرة (SplitMix64) — نفس البذرة = نفس المرحلة دائمًا
struct SRng {
    var s: UInt64
    init(_ seed: UInt64) { s = seed ^ 0x5DEECE66D2B7E151 }
    mutating func next() -> UInt64 {
        s = s &+ 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / 9007199254740992.0 }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
    mutating func int(_ n: Int) -> Int { n <= 1 ? 0 : Int(next() % UInt64(n)) }
    mutating func int(_ a: Int, _ b: Int) -> Int { a + int(b - a + 1) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
    mutating func sign() -> Double { chance(0.5) ? 1 : -1 }
    mutating func pick<T>(_ a: [T], _ fallback: T) -> T { a.isEmpty ? fallback : a[int(a.count)] }
}

enum ShapeKind: String, CaseIterable, Codable {
    case square, triangle, pentagon, hexagon, disc
    case star, blob, gear, heart, moon, arrow
    case lShape, tShape, uShape, plus, hLetter, eLetter, sLetter
    case ring, frame, cheese
}

enum ShapeLib {
    static let convex: [ShapeKind] = [.square, .triangle, .pentagon, .hexagon, .disc]
    static let curvy: [ShapeKind] = [.star, .blob, .gear, .heart, .moon, .arrow]
    static let letters: [ShapeKind] = [.lShape, .tShape, .uShape, .plus, .hLetter, .eLetter, .sLetter]
    static let holed: [ShapeKind] = [.ring, .frame, .cheese]
    /// أشكال متناظرة ٩٠° (تنفع لأربع قطع متساوية بخطّين متعامدين من المركز)
    static let quad: [ShapeKind] = [.square, .disc]

    static func name(_ k: ShapeKind) -> String {
        switch k {
        case .square: return "مربّع"
        case .triangle: return "مثلّث"
        case .pentagon: return "خماسيّ"
        case .hexagon: return "سداسيّ"
        case .disc: return "قرص"
        case .star: return "نجمة"
        case .blob: return "فقاعة"
        case .gear: return "ترس"
        case .heart: return "قلب"
        case .moon: return "هلال"
        case .arrow: return "سهم"
        case .lShape: return "حرف L"
        case .tShape: return "حرف T"
        case .uShape: return "حرف U"
        case .plus: return "زائد"
        case .hLetter: return "حرف H"
        case .eLetter: return "حرف E"
        case .sLetter: return "حرف S"
        case .ring: return "حلقة"
        case .frame: return "إطار"
        case .cheese: return "جبنة"
        }
    }

    static func regular(_ n: Int, phase: Double = 0, r: Double = 1, c: P = .zero) -> Ring {
        (0..<n).map { i in
            let a = phase + Double(i) / Double(n) * 2 * Double.pi
            return P(c.x + r * cos(a), c.y + r * sin(a))
        }
    }

    static func rect(_ pts: [(Double, Double)]) -> Ring { pts.map { P($0.0, $0.1) } }

    /// يبني الشكل (مطبَّع: مركزه الأصل، نصف قطره ١). vary = تمطيط وتدوير عشوائيّ بالبذرة
    static func make(_ k: ShapeKind, seed: UInt64, vary: Bool = true) -> Shape {
        var g = SRng(seed &* 31 &+ UInt64(k.rawValue.count))
        var holes: [Ring] = []
        var outer: Ring
        switch k {
        case .square: outer = regular(4, phase: Double.pi / 4)
        case .triangle: outer = regular(3, phase: -Double.pi / 2)
        case .pentagon: outer = regular(5, phase: -Double.pi / 2)
        case .hexagon: outer = regular(6)
        case .disc: outer = regular(48)
        case .star:
            let n = g.int(5, 7), inner = g.range(0.44, 0.56)
            outer = (0..<(2 * n)).map { i in
                let a = -Double.pi / 2 + Double(i) / Double(2 * n) * 2 * Double.pi
                let r = i % 2 == 0 ? 1.0 : inner
                return P(r * cos(a), r * sin(a))
            }
        case .blob:
            outer = blob(&g, n: 36, amp: 0.16)
        case .gear:
            let teeth = g.int(7, 10)
            var pts: Ring = []
            for i in 0..<teeth {
                let a0 = Double(i) / Double(teeth) * 2 * Double.pi
                let w = 2 * Double.pi / Double(teeth)
                for (f, r) in [(0.0, 0.74), (0.18, 1.0), (0.5, 1.0), (0.68, 0.74)] {
                    let a = a0 + f * w
                    pts.append(P(r * cos(a), r * sin(a)))
                }
            }
            outer = pts
        case .heart:
            outer = (0..<56).map { i in
                let t = Double(i) / 56 * 2 * Double.pi
                let x = 16 * pow(sin(t), 3)
                let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
                return P(x, -y)
            }
        case .moon:
            // دائرة كبيرة ناقص دائرة مزاحة: نقاط التقاطع (0.6، ±0.8)
            var pts: Ring = []
            let a0 = atan2(0.8, 0.6)
            for i in 0...30 {
                let a = a0 + (2 * Double.pi - 2 * a0) * Double(i) / 30
                pts.append(P(cos(a), sin(a)))
            }
            for i in 1..<20 {
                let a = 1.5 * Double.pi - Double.pi * Double(i) / 20
                pts.append(P(0.6 + 0.8 * cos(a), 0.8 * sin(a)))
            }
            outer = pts
        case .arrow:
            outer = rect([(0, 1), (2, 1), (2, 0), (3.6, 1.5), (2, 3), (2, 2), (0, 2)])
        case .lShape:
            outer = rect([(0, 0), (3, 0), (3, 1), (1, 1), (1, 3), (0, 3)])
        case .tShape:
            outer = rect([(0, 3), (0, 2), (1, 2), (1, 0), (2, 0), (2, 2), (3, 2), (3, 3)])
        case .uShape:
            outer = rect([(0, 0), (3, 0), (3, 3), (2, 3), (2, 1), (1, 1), (1, 3), (0, 3)])
        case .plus:
            outer = rect([(1, 0), (2, 0), (2, 1), (3, 1), (3, 2), (2, 2), (2, 3), (1, 3), (1, 2), (0, 2), (0, 1), (1, 1)])
        case .hLetter:
            outer = rect([(0, 0), (1, 0), (1, 1), (2, 1), (2, 0), (3, 0), (3, 3), (2, 3), (2, 2), (1, 2), (1, 3), (0, 3)])
        case .eLetter:
            outer = rect([(0, 0), (3, 0), (3, 1), (1, 1), (1, 2), (2.5, 2), (2.5, 3), (1, 3), (1, 4), (3, 4), (3, 5), (0, 5)])
        case .sLetter:
            outer = rect([(0, 0), (3, 0), (3, 3), (1, 3), (1, 4), (3, 4), (3, 5), (0, 5), (0, 2), (2, 2), (2, 1), (0, 1)])
        case .ring:
            outer = regular(44)
            let off = P(g.range(-0.12, 0.12), g.range(-0.12, 0.12))
            holes = [regular(32, r: g.range(0.42, 0.52), c: off)]
        case .frame:
            outer = regular(4, phase: Double.pi / 4)
            let hr = g.range(0.5, 0.62)
            let off = P(g.range(-0.08, 0.08), g.range(-0.08, 0.08))
            holes = [regular(4, phase: Double.pi / 4 + g.range(-0.3, 0.3), r: hr, c: off)]
        case .cheese:
            outer = blob(&g, n: 36, amp: 0.07)
            let base = g.range(0, 2 * Double.pi)
            let cnt = g.int(2, 3)
            for i in 0..<cnt {
                let a = base + Double(i) / Double(cnt) * 2 * Double.pi + g.range(-0.2, 0.2)
                let rr = g.range(0.40, 0.48)
                holes.append(regular(20, r: g.range(0.13, 0.19), c: P(rr * cos(a), rr * sin(a))))
            }
        }
        var s = Shape(outer, holes: holes).normalized()
        if vary {
            let sx = g.range(0.82, 1.18), rot = g.range(0, 2 * Double.pi)
            s = s.mapped { P($0.x * sx, $0.y / sx).rotated(rot) }.normalized()
        }
        return s
    }

    /// فقاعة: نصف قطر يتغيّر بنعومة مع الزاوية (دائمًا مضلّع بسيط)
    static func blob(_ g: inout SRng, n: Int, amp: Double) -> Ring {
        var hs: [(k: Double, a: Double, ph: Double)] = []
        for k in 2...4 { hs.append((k: Double(k), a: g.range(amp * 0.4, amp), ph: g.range(0, 2 * Double.pi))) }
        return (0..<n).map { i in
            let t = Double(i) / Double(n) * 2 * Double.pi
            var r = 1.0
            for h in hs { r += h.a * sin(h.k * t + h.ph) }
            return P(r * cos(t), r * sin(t))
        }
    }
}
