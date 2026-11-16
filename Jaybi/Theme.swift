import SwiftUI

/// هويّة «جيبي»: داكن + نعناعيّ
enum JB {
    static let bg = Color(red: 0.051, green: 0.059, blue: 0.078)
    static let card = Color(red: 0.090, green: 0.102, blue: 0.133)
    static let card2 = Color(red: 0.118, green: 0.133, blue: 0.188)
    static let line = Color(white: 1, opacity: 0.07)
    static let tx = Color(red: 0.957, green: 0.961, blue: 0.969)
    static let tx2 = Color(red: 0.604, green: 0.631, blue: 0.698)
    static let mint = Color(red: 0.239, green: 0.863, blue: 0.592)
    static let mint2 = Color(red: 0.122, green: 0.647, blue: 0.424)
    static let mintInk = Color(red: 0.02, green: 0.15, blue: 0.10)
    static let coral = Color(red: 1.0, green: 0.478, blue: 0.349)
    static let sun = Color(red: 1.0, green: 0.788, blue: 0.302)

    static func color(_ cat: String) -> Color {
        let c = Cats.get(cat)
        return Color(hue: c.hue, saturation: 0.62, brightness: 0.98)
    }

    static let mintGrad = LinearGradient(colors: [mint, mint2], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// تنسيق المبالغ: 25,000 — والكسور فقط إذا موجودة
enum Money {
    static let fmt0: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()
    static let fmt2: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func s(_ v: Double) -> String {
        let r = v.rounded()
        if abs(v - r) < 0.005 { return fmt0.string(from: NSNumber(value: r)) ?? "\(Int(r))" }
        return fmt2.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    /// مختصر: 1.2M / 450K للأماكن الضيّقة
    static func short(_ v: Double) -> String {
        if v >= 1_000_000 {
            let m = v / 1_000_000
            return (m == m.rounded() ? String(Int(m)) : String(format: "%.1f", m)) + " مليون"
        }
        if v >= 10_000 { return String(Int((v / 1000).rounded())) + " ألف" }
        return s(v)
    }

    static let currencies: [(String, String)] = [
        ("د.ع", "دينار عراقيّ"), ("$", "دولار"), ("€", "يورو"), ("ر.س", "ريال سعوديّ"), ("د.إ", "درهم إماراتيّ"),
        ("د.ك", "دينار كويتيّ"), ("ر.ق", "ريال قطريّ"), ("د.أ", "دينار أردنيّ"), ("ج.م", "جنيه مصريّ"), ("ل.ت", "ليرة تركيّة"),
        ("£", "جنيه إسترلينيّ"), ("د.م", "درهم مغربيّ"),
    ]
}

/// تواريخ بالعربيّ
enum JDate {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ar")
        return c
    }()
    static let months = ["كانون الثاني", "شباط", "آذار", "نيسان", "أيّار", "حزيران", "تمّوز", "آب", "أيلول", "تشرين الأوّل", "تشرين الثاني", "كانون الأوّل"]

    static func month(_ d: Date) -> String {
        let m = cal.component(.month, from: d)
        return months[max(0, min(11, m - 1))]
    }

    static func monthYear(_ d: Date) -> String {
        month(d) + " " + String(cal.component(.year, from: d))
    }

    static func time(_ d: Date) -> String {
        let h = cal.component(.hour, from: d)
        let m = cal.component(.minute, from: d)
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d", h12, m) + (h < 12 ? " ص" : " م")
    }

    static func dayTitle(_ d: Date, now: Date = Date()) -> String {
        if cal.isDate(d, inSameDayAs: now) { return "اليوم" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(d, inSameDayAs: y) { return "البارحة" }
        let days = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
        let wd = cal.component(.weekday, from: d)
        let name = days[max(0, min(6, wd - 1))]
        return name + " " + String(cal.component(.day, from: d)) + " " + month(d)
    }
}
