import Foundation

/// تنسيق الأحجام والأعداد بالعربيّ (الأحجام بالنظام العشريّ مثل إعدادات آيفون)
enum FZFormat {
    static func dec1(_ v: Double) -> String {
        let t = (v * 10).rounded() / 10
        if t == t.rounded() { return String(Int(t)) }
        return String(format: "%.1f", t)
    }

    /// (الرقم، الوحدة)
    static func sizeParts(_ b: Int64) -> (String, String) {
        let v = Double(max(0, b))
        if v < 1000 { return (String(Int(v)), "بايت") }
        if v < 999_500 { return (String(Int((v / 1000).rounded())), "كيلو") }
        if v < 999_950_000 {
            let m = v / 1_000_000
            return (m < 9.95 ? dec1(m) : String(Int(m.rounded())), "ميغا")
        }
        let g = v / 1_000_000_000
        return (g < 99.95 ? dec1(g) : String(Int(g.rounded())), "غيغا")
    }

    static func size(_ b: Int64) -> String {
        let p = sizeParts(b)
        return p.0 + " " + p.1
    }

    static func photos(_ n: Int) -> String {
        switch n {
        case ..<1: return "ولا صورة"
        case 1: return "صورة واحدة"
        case 2: return "صورتان"
        case 3...10: return "\(n) صور"
        default: return "\(n) صورة"
        }
    }

    static func items(_ n: Int) -> String {
        switch n {
        case ..<1: return "ولا عنصر"
        case 1: return "عنصر واحد"
        case 2: return "عنصران"
        case 3...10: return "\(n) عناصر"
        default: return "\(n) عنصر"
        }
    }

    static func days(_ n: Int) -> String {
        switch n {
        case ..<1: return "ولا يوم"
        case 1: return "يوم واحد"
        case 2: return "يومان"
        case 3...10: return "\(n) أيّام"
        default: return "\(n) يومًا"
        }
    }

    static func groups(_ n: Int) -> String {
        switch n {
        case ..<1: return "ولا مجموعة"
        case 1: return "مجموعة واحدة"
        case 2: return "مجموعتان"
        case 3...10: return "\(n) مجموعات"
        default: return "\(n) مجموعة"
        }
    }

    /// مدّة الفيديو 1:05 أو 1:02:05
    static func duration(_ s: Double) -> String {
        let t = max(0, Int(s.rounded()))
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    /// فاصل الآلاف 12,480
    static func thousands(_ n: Int) -> String {
        let neg = n < 0
        var s = String(abs(n))
        var out = ""
        while s.count > 3 {
            let tail = String(s.suffix(3))
            out = "," + tail + out
            s = String(s.dropLast(3))
        }
        return (neg ? "-" : "") + s + out
    }

    static func percent(_ f: Double) -> String { "\(Int((max(0, min(1, f)) * 100).rounded()))٪" }
}
