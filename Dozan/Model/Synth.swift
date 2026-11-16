import Foundation

/// مولّد إشارات اصطناعيّة (للاختبارات ولوضع العرض)
enum Synth {
    static func sine(_ f: Double, sr: Double, count: Int, amp: Double = 0.5, phase: Double = 0) -> [Float] {
        var out = [Float](repeating: 0, count: max(0, count))
        let w = 2 * Double.pi * f / sr
        for i in 0..<out.count { out[i] = Float(amp * sin(w * Double(i) + phase)) }
        return out
    }

    /// منشار محدود الحزمة (مجموع توافقيّات 1/k تحت نايكوِست)
    static func saw(_ f: Double, sr: Double, count: Int, amp: Double = 0.5, harmonics: Int = 12) -> [Float] {
        var out = [Float](repeating: 0, count: max(0, count))
        let nyq = sr / 2
        var ks: [Int] = []
        var k = 1
        while k <= harmonics && Double(k) * f < nyq * 0.95 { ks.append(k); k += 1 }
        let w = 2 * Double.pi * f / sr
        let g = amp * 2 / Double.pi
        for i in 0..<out.count {
            var v = 0.0
            for kk in ks { v += sin(w * Double(kk) * Double(i)) / Double(kk) }
            out[i] = Float(g * v)
        }
        return out
    }

    /// صوت شبيه بالغناء: أساسيّ + توافقيّات متناقصة + اهتزاز خفيف (vibrato)
    static func voice(_ f: Double, sr: Double, count: Int, amp: Double = 0.4, vibratoCents: Double = 0, vibratoHz: Double = 5.5) -> [Float] {
        var out = [Float](repeating: 0, count: max(0, count))
        var phase = 0.0
        let weights: [Double] = [1.0, 0.55, 0.32, 0.18, 0.1]
        for i in 0..<out.count {
            let t = Double(i) / sr
            let cents = vibratoCents * sin(2 * Double.pi * vibratoHz * t)
            let fi = f * pow(2, cents / 1200)
            phase += 2 * Double.pi * fi / sr
            var v = 0.0
            for (k, wgt) in weights.enumerated() { v += wgt * sin(phase * Double(k + 1)) }
            out[i] = Float(amp * v / 2.15)
        }
        return out
    }

    static func noise(count: Int, seed: UInt64, amp: Double = 0.3) -> [Float] {
        var s = seed &+ 0x9E3779B97F4A7C15
        var out = [Float](repeating: 0, count: max(0, count))
        for i in 0..<out.count {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let u = Double(s >> 11) / Double(UInt64(1) << 53)
            out[i] = Float((u * 2 - 1) * amp)
        }
        return out
    }

    static func add(_ a: [Float], _ b: [Float], gain: Float = 1) -> [Float] {
        let n = min(a.count, b.count)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n { out[i] = a[i] + b[i] * gain }
        return out
    }
}

/// مولّد عشوائيّ ثابت البذرة (لبيانات العرض)
struct SeededRNG: RandomNumberGenerator {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &+ 0x2545F4914F6CDD1D }
    mutating func next() -> UInt64 {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
}
