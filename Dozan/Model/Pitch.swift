import Foundation

struct PitchReading: Equatable {
    var freq: Double
    var confidence: Double
    var rms: Double
}

/// كاشف الطبقة بخوارزميّة YIN (de Cheveigné & Kawahara 2002)
/// فرق ذاتيّ ← تطبيع تراكميّ ← أوّل قاع تحت العتبة ← استيفاء قطع مكافئ
struct YIN {
    var sampleRate: Double
    var threshold: Double = 0.15
    var minFreq: Double = 28
    var maxFreq: Double = 1600
    var silenceRMS: Double = 0.004
    /// إذا ما لكينا قاع تحت العتبة، نقبل أصغر قيمة إذا هي أقلّ من هذا
    var fallbackLimit: Double = 0.4

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    static func rms(_ x: [Float]) -> Double {
        guard !x.isEmpty else { return 0 }
        var e = 0.0
        for v in x { e += Double(v) * Double(v) }
        return sqrt(e / Double(x.count))
    }

    func detect(_ x: [Float]) -> PitchReading? {
        let n = x.count
        guard n >= 128, sampleRate > 0 else { return nil }
        let level = YIN.rms(x)
        if level < silenceRMS { return nil }
        let w = n / 2
        let tauMin = max(2, Int(sampleRate / maxFreq))
        let tauMax = min(w - 2, Int(sampleRate / minFreq) + 1)
        guard tauMax > tauMin + 2 else { return nil }

        // ١) دالّة الفرق
        var d = [Double](repeating: 0, count: tauMax + 2)
        x.withUnsafeBufferPointer { p in
            for tau in 1...(tauMax + 1) {
                var s = 0.0
                var j = 0
                while j < w {
                    let df = Double(p[j]) - Double(p[j + tau])
                    s += df * df
                    j += 1
                }
                d[tau] = s
            }
        }

        // ٢) الفرق المطبَّع التراكميّ
        var cm = [Double](repeating: 1, count: tauMax + 2)
        var running = 0.0
        for tau in 1...(tauMax + 1) {
            running += d[tau]
            cm[tau] = running > 0 ? d[tau] * Double(tau) / running : 1
        }

        // ٣) أوّل قاع تحت العتبة
        var best = -1
        var tau = tauMin
        while tau <= tauMax {
            if cm[tau] < threshold {
                while tau + 1 <= tauMax && cm[tau + 1] < cm[tau] { tau += 1 }
                best = tau
                break
            }
            tau += 1
        }
        if best < 0 {
            var m = Double.greatestFiniteMagnitude
            for t in tauMin...tauMax where cm[t] < m { m = cm[t]; best = t }
            if best < 0 || cm[best] > fallbackLimit { return nil }
        }

        // ٤) نضبط على قاع دالّة الفرق الخام ثمّ نستوفي
        var t0 = best
        while t0 + 1 <= tauMax && d[t0 + 1] < d[t0] { t0 += 1 }
        while t0 - 1 >= tauMin && d[t0 - 1] < d[t0] { t0 -= 1 }
        let a = d[t0 - 1], b = d[t0], c = d[t0 + 1]
        let den = a - 2 * b + c
        var shift = 0.0
        if abs(den) > 1e-12 { shift = 0.5 * (a - c) / den }
        shift = max(-1, min(1, shift))
        let period = Double(t0) + shift
        guard period > 0 else { return nil }
        let conf = max(0, min(1, 1 - cm[best]))
        return PitchReading(freq: sampleRate / period, confidence: conf, rms: level)
    }
}

/// مرشّح وسيط: يشيل القفزات المفاجئة (مثل خطأ الأوكتاف لإطار واحد)
struct MedianSmoother {
    let size: Int
    private(set) var values: [Double] = []

    init(size: Int) { self.size = max(1, size) }

    mutating func push(_ v: Double) -> Double {
        values.append(v)
        if values.count > size { values.removeFirst(values.count - size) }
        return median
    }

    var median: Double {
        let s = values.sorted()
        let n = s.count
        if n == 0 { return 0 }
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    mutating func reset() { values.removeAll() }
}

/// يحوّل قراءات YIN الخام إلى نغمة ناعمة (بالـMIDI الكسريّ)
struct PitchTracker {
    var a4: Double = 440
    var minConfidence: Double = 0.55
    var dropAfter: Int = 4
    private(set) var midi: Double? = nil
    private var smoother = MedianSmoother(size: 5)
    private var misses = 0

    init(a4: Double = 440, window: Int = 5) {
        self.a4 = a4
        self.smoother = MedianSmoother(size: window)
    }

    mutating func push(_ r: PitchReading?) -> Double? {
        guard let r = r, r.confidence >= minConfidence, r.freq > 0 else {
            misses += 1
            if misses >= dropAfter { smoother.reset(); midi = nil }
            return midi
        }
        misses = 0
        let m = NoteMath.midi(freq: r.freq, a4: a4)
        // قفزة كبيرة ومستمرّة (نغمة جديدة): نلحقها بسرعة بدل ما ننتظر الوسيط
        if let cur = midi, abs(m - cur) > 1.5, let last = smoother.values.last, abs(last - m) < 0.5 {
            smoother.reset()
            _ = smoother.push(last)
        }
        midi = smoother.push(m)
        return midi
    }

    mutating func reset() { smoother.reset(); midi = nil; misses = 0 }
}
