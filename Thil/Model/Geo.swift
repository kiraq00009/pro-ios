import Foundation

// هندسة خالصة: نقاط/أحجام/مستطيلات + حساب الاحتواء والتعبئة + حدود القناع

struct TP: Codable, Equatable {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    static func + (a: TP, b: TP) -> TP { TP(a.x + b.x, a.y + b.y) }
    static func - (a: TP, b: TP) -> TP { TP(a.x - b.x, a.y - b.y) }
    /// دوران بالراديان (محور y نازل ⇒ الموجب باتّجاه عقارب الساعة على الشاشة)
    func rotated(_ a: Double) -> TP {
        let c = cos(a), s = sin(a)
        return TP(x * c - y * s, x * s + y * c)
    }
    func dist(_ o: TP) -> Double { hypot(x - o.x, y - o.y) }
}

struct TSize: Codable, Equatable {
    var w: Double
    var h: Double
    init(_ w: Double, _ h: Double) { self.w = w; self.h = h }
    /// العرض ÷ الارتفاع
    var ratio: Double { h > 0 ? w / h : 1 }
}

struct TRect: Codable, Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) { self.x = x; self.y = y; self.w = w; self.h = h }
    var midX: Double { x + w / 2 }
    var midY: Double { y + h / 2 }
    var maxX: Double { x + w }
    var maxY: Double { y + h }
    var size: TSize { TSize(w, h) }
    func contains(_ p: TP) -> Bool { p.x >= x && p.x <= maxX && p.y >= y && p.y <= maxY }
}

enum Fit {
    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }

    /// أكبر مستطيل بنفس نسبة المحتوى داخل الصندوق، بالوسط
    static func fit(_ c: TSize, in b: TRect) -> TRect {
        guard c.w > 0, c.h > 0, b.w > 0, b.h > 0 else { return TRect(b.midX, b.midY, 0, 0) }
        let k = min(b.w / c.w, b.h / c.h)
        let w = c.w * k, h = c.h * k
        return TRect(b.x + (b.w - w) / 2, b.y + (b.h - h) / 2, w, h)
    }

    /// أصغر مستطيل بنفس النسبة يغطّي الصندوق كلّه، بالوسط
    static func fill(_ c: TSize, in b: TRect) -> TRect {
        guard c.w > 0, c.h > 0, b.w > 0, b.h > 0 else { return TRect(b.midX, b.midY, 0, 0) }
        let k = max(b.w / c.w, b.h / c.h)
        let w = c.w * k, h = c.h * k
        return TRect(b.x + (b.w - w) / 2, b.y + (b.h - h) / 2, w, h)
    }

    /// تحويل نقطة من الشاشة إلى إحداثيّات طبيعيّة (0…1) داخل مستطيل معروض
    static func normalized(_ p: TP, in r: TRect) -> TP? {
        guard r.w > 0, r.h > 0, r.contains(p) else { return nil }
        return TP((p.x - r.x) / r.w, (p.y - r.y) / r.h)
    }

    /// صندوق البكسلات اللي شفافيّتها فوق العتبة (للقصّ حول الموضوع). nil = القناع فاضي
    static func alphaBounds(_ a: [UInt8], width: Int, height: Int, threshold: UInt8 = 10) -> TRect? {
        guard width > 0, height > 0, a.count >= width * height else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where a[row + x] > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0 else { return nil }
        return TRect(Double(minX), Double(minY), Double(maxX - minX + 1), Double(maxY - minY + 1))
    }

    static func scaled(_ r: TRect, by k: Double) -> TRect { TRect(r.x * k, r.y * k, r.w * k, r.h * k) }

    /// يوسّع المستطيل بنسبة من ضلعه الأطول بدون ما يطلع برّا الحدود
    static func padded(_ r: TRect, frac: Double, bounds: TSize) -> TRect {
        let p = max(r.w, r.h) * frac
        let x0 = max(0, r.x - p), y0 = max(0, r.y - p)
        let x1 = min(bounds.w, r.maxX + p), y1 = min(bounds.h, r.maxY + p)
        return TRect(x0, y0, max(0, x1 - x0), max(0, y1 - y0))
    }

    /// نسبة العنصر من عرض اللوحة حتى يدخل بحدود (maxW من العرض، maxH من الارتفاع)
    /// hOverW = ارتفاع العنصر ÷ عرضه · canvasRatio = عرض اللوحة ÷ ارتفاعها
    static func scaleToFit(hOverW: Double, maxW: Double, maxH: Double, canvasRatio: Double) -> Double {
        guard hOverW > 0, canvasRatio > 0 else { return maxW }
        return min(maxW, maxH / (hOverW * canvasRatio))
    }
}
