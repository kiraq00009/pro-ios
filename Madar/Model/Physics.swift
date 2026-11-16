import Foundation

/// متّجه ثنائيّ بسيط — العالم عرضه 360 وحدة والارتفاع يزيد للأعلى
struct V2: Equatable, Codable {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    static let zero = V2(0, 0)
    static func + (a: V2, b: V2) -> V2 { V2(a.x + b.x, a.y + b.y) }
    static func - (a: V2, b: V2) -> V2 { V2(a.x - b.x, a.y - b.y) }
    static func * (a: V2, k: Double) -> V2 { V2(a.x * k, a.y * k) }
    static func / (a: V2, k: Double) -> V2 { V2(a.x / k, a.y / k) }
    static func += (a: inout V2, b: V2) { a = a + b }
    var len: Double { (x * x + y * y).squareRoot() }
    var norm: V2 { let l = len; return l > 1e-12 ? V2(x / l, y / l) : V2(0, 0) }
    func dot(_ o: V2) -> Double { x * o.x + y * o.y }
    func cross(_ o: V2) -> Double { x * o.y - y * o.x }
    func dist(_ o: V2) -> Double { (self - o).len }
    var angle: Double { atan2(y, x) }
    static func ang(_ a: Double) -> V2 { V2(cos(a), sin(a)) }
}

/// زاوية بين -π و π
func wrapAngle(_ a: Double) -> Double {
    var v = a.truncatingRemainder(dividingBy: 2 * Double.pi)
    if v > Double.pi { v -= 2 * Double.pi }
    if v <= -Double.pi { v += 2 * Double.pi }
    return v
}

/// مولّد عشوائيّ ثابت (SplitMix64): نفس البذرة ⇒ نفس الكون
struct MRng {
    private var s: UInt64
    init(seed: UInt64) { s = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        s = s &+ 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// رقم بين 0 و 1 (بدون 1)
    mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
    mutating func int(_ n: Int) -> Int { n <= 1 ? 0 : Int(next() % UInt64(n)) }
    mutating func sign() -> Double { chance(0.5) ? 1 : -1 }
}

/// خلط بذرة مع رقم — لكلّ كوكب مولّده الخاصّ
func mixSeed(_ seed: UInt64, _ i: Int) -> UInt64 {
    var z = seed ^ (UInt64(truncatingIfNeeded: i) &* 0xD6E8_FEB8_6659_FD93)
    z = (z ^ (z >> 32)) &* 0xD6E8_FEB8_6659_FD93
    return z ^ (z >> 29)
}

/// حساب زاوية الإطلاق: وين لازم يكون المذنّب على الحلقة حتى خطّ المماس يعبر قرب الهدف
enum Aim {
    /// center/ringR: المدار الحالي · dir: +1 عكس عقارب الساعة، -1 مع العقارب
    /// offset: بُعد خطّ الطيران عن مركز الهدف (نصف قطر حلقته ⇒ دخول مثاليّ)
    static func releaseAngle(center c: V2, ringR R: Double, dir: Double, target t: V2, offset: Double) -> Double? {
        let d = t - c
        let dl = d.len
        guard dl > R + 1 else { return nil }
        let cv = (R - offset) / dl
        guard cv >= -1, cv <= 1 else { return nil }
        let phi = d.angle
        let a = acos(cv)
        return wrapAngle(dir >= 0 ? phi - a : phi + a)
    }

    /// اتّجاه المماس للمذنّب وهو بزاوية a
    static func tangent(_ a: Double, dir: Double) -> V2 {
        dir >= 0 ? V2(-sin(a), cos(a)) : V2(sin(a), -cos(a))
    }

    /// أقرب بُعد لخطّ يمرّ بـ p باتّجاه v عن النقطة c
    static func impact(_ p: V2, _ v: V2, _ c: V2) -> Double {
        abs((p - c).cross(v.norm))
    }
}
