import Foundation

/// كشف التشويش: تباين لابلاس على صورة رماديّة صغيرة.
/// الصورة الحادّة فيها حواف كثيرة ⇒ قيم لابلاس متباعدة ⇒ تباين عالي. المشوّشة ناعمة ⇒ تباين واطي.
enum FZBlur {
    /// تحويل RGBA (4 بايت للبكسل) إلى رماديّ بمعادلة الإضاءة
    static func gray(rgba: [UInt8], width: Int, height: Int) -> [UInt8] {
        let n = max(0, width * height)
        guard rgba.count >= n * 4 else { return [] }
        var out = [UInt8](repeating: 0, count: n)
        for i in 0..<n {
            let r = Int(rgba[i * 4]), g = Int(rgba[i * 4 + 1]), b = Int(rgba[i * 4 + 2])
            out[i] = UInt8(min(255, (r * 299 + g * 587 + b * 114 + 500) / 1000))
        }
        return out
    }

    /// لابلاس رباعيّ الجيران للبكسلات الداخليّة فقط: (w-2)×(h-2)
    static func laplacian(_ px: [Double], width w: Int, height h: Int) -> [Double] {
        guard w >= 3, h >= 3, px.count >= w * h else { return [] }
        var out = [Double]()
        out.reserveCapacity((w - 2) * (h - 2))
        for y in 1..<(h - 1) {
            let row = y * w
            for x in 1..<(w - 1) {
                let c = px[row + x]
                let l = px[row + x - 1] + px[row + x + 1] + px[row - w + x] + px[row + w + x] - 4 * c
                out.append(l)
            }
        }
        return out
    }

    static func mean(_ v: [Double]) -> Double {
        guard !v.isEmpty else { return 0 }
        return v.reduce(0, +) / Double(v.count)
    }

    static func mean(_ px: [UInt8]) -> Double {
        guard !px.isEmpty else { return 0 }
        var s = 0
        for p in px { s += Int(p) }
        return Double(s) / Double(px.count)
    }

    /// تباين المجتمع (القسمة على n)
    static func variance(_ v: [Double]) -> Double {
        guard !v.isEmpty else { return 0 }
        let m = mean(v)
        var acc = 0.0
        for x in v { let d = x - m; acc += d * d }
        return acc / Double(v.count)
    }

    static func laplacianVariance(_ px: [Double], width: Int, height: Int) -> Double {
        variance(laplacian(px, width: width, height: height))
    }

    static func laplacianVariance(_ px: [UInt8], width: Int, height: Int) -> Double {
        laplacianVariance(px.map { Double($0) }, width: width, height: height)
    }

    /// تمويه صندوقيّ (للاختبار ولمعاينة الفرق)
    static func boxBlur(_ px: [Double], width w: Int, height h: Int, radius r: Int) -> [Double] {
        guard w > 0, h > 0, r > 0, px.count >= w * h else { return px }
        var out = [Double](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                var s = 0.0, n = 0
                for dy in -r...r {
                    let yy = y + dy
                    if yy < 0 || yy >= h { continue }
                    for dx in -r...r {
                        let xx = x + dx
                        if xx < 0 || xx >= w { continue }
                        s += px[yy * w + xx]; n += 1
                    }
                }
                out[y * w + x] = n > 0 ? s / Double(n) : 0
            }
        }
        return out
    }

    /// النتيجة المختصرة لصورة رماديّة
    struct Reading: Equatable {
        var variance: Double
        var brightness: Double
    }

    static func read(_ px: [UInt8], width: Int, height: Int) -> Reading {
        Reading(variance: laplacianVariance(px, width: width, height: height), brightness: mean(px))
    }

    /// مشوّشة؟ نتجاهل الصور المظلمة جدًّا أو البيضاء جدًّا لأنّ حوافها قليلة طبيعيًّا
    static func isBlurry(_ r: Reading, threshold: Double) -> Bool {
        if r.brightness < 18 || r.brightness > 240 { return false }
        return r.variance < threshold
    }

    /// 0…1 درجة الحدّة للعرض (لوغاريتميّ: 1000+ = حادّة جدًّا)
    static func sharpnessScore(_ variance: Double) -> Double {
        let v = log1p(max(0, variance)) / log1p(1000)
        return max(0, min(1, v))
    }
}
