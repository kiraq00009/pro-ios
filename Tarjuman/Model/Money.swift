import Foundation

/// فلوس إيران تلخبط أيّ زائر: الريال الرسميّ، التومان (= ١٠ ريال) اللي يحجون بيه،
/// والسوق يگول «٥٠ تومن» ويقصد ٥٠ ألف تومان. هنا نفكّ هاللخبطة ونحوّل لدينار/دولار.
enum Unit: String, Codable, CaseIterable, Identifiable {
    case toman, rial
    var id: String { rawValue }
    var name: String { self == .toman ? "تومان" : "ريال" }
}

struct Rates: Codable, Equatable {
    /// كم تومان بالدولار (سعر السوق الحرّ — المستخدم يعدّله)
    var tomanPerUSD: Double = 110_000
    /// كم دينار عراقي بالدولار
    var iqdPerUSD: Double = 1_450
    var updated: Date = Date(timeIntervalSince1970: 1_763_000_000)

    func toUSD(toman: Double) -> Double { toman / tomanPerUSD }
    func toIQD(toman: Double) -> Double { toman / tomanPerUSD * iqdPerUSD }
    func toToman(iqd: Double) -> Double { iqd / iqdPerUSD * tomanPerUSD }
    func toToman(usd: Double) -> Double { usd * tomanPerUSD }
}

struct PriceReading: Equatable {
    let label: String        // شرح القراءة
    let toman: Double
    let likely: Bool         // القراءة الأرجح
}

enum Money {
    static let faOnes = ["صفر","یک","دو","سه","چهار","پنج","شش","هفت","هشت","نه"]
    static let faTeens = ["ده","یازده","دوازده","سیزده","چهارده","پانزده","شانزده","هفده","هجده","نوزده"]
    static let faTens = ["","","بیست","سی","چهل","پنجاه","شصت","هفتاد","هشتاد","نود"]
    static let faHundreds = ["","صد","دویست","سیصد","چهارصد","پانصد","ششصد","هفتصد","هشتصد","نهصد"]

    /// رقم ← كلمات فارسيّة (حتى نوري البيّاع الرقم مكتوب أو نلفظه)
    static func faWords(_ n: Int) -> String {
        if n == 0 { return faOnes[0] }
        if n < 0 { return "منفی " + faWords(-n) }
        var parts: [String] = []
        let scales: [(Int, String)] = [(1_000_000_000, "میلیارد"), (1_000_000, "میلیون"), (1_000, "هزار")]
        var rest = n
        for (v, w) in scales where rest >= v {
            parts.append(under1000(rest / v) + " " + w)
            rest %= v
        }
        if rest > 0 { parts.append(under1000(rest)) }
        return parts.joined(separator: " و ")
    }

    private static func under1000(_ n: Int) -> String {
        var p: [String] = []
        let h = n / 100, r = n % 100
        if h > 0 { p.append(faHundreds[h]) }
        if r >= 20 {
            p.append(faTens[r / 10])
            if r % 10 > 0 { p.append(faOnes[r % 10]) }
        } else if r >= 10 { p.append(faTeens[r - 10]) }
        else if r > 0 { p.append(faOnes[r]) }
        return p.joined(separator: " و ")
    }

    /// كلمات فارسيّة/عربيّة منطوقة ← رقم ("صد و پنجاه هزار" ⇒ 150000)
    static func parseWords(_ s: String) -> Double? {
        var map: [String: Double] = [:]
        for (i, w) in faOnes.enumerated() { map[w] = Double(i) }
        for (i, w) in faTeens.enumerated() { map[w] = Double(10 + i) }
        for (i, w) in faTens.enumerated() where !w.isEmpty { map[w] = Double(i * 10) }
        for (i, w) in faHundreds.enumerated() where !w.isEmpty { map[w] = Double(i * 100) }
        let extra: [String: Double] = ["یه": 1, "شیش": 6, "پونصد": 500, "پونزده": 15, "شونزده": 16, "نیم": 0.5]
        for (k, v) in extra { map[k] = v }
        let scales: [String: Double] = ["هزار": 1_000, "تومن": 0, "میلیون": 1_000_000, "ملیون": 1_000_000, "میلیارد": 1_000_000_000,
                                         "الف": 1_000, "ألف": 1_000, "مليون": 1_000_000]
        let toks = Script.toPersian(Script.latinDigits(s))
            .replacingOccurrences(of: "،", with: " ").replacingOccurrences(of: ",", with: "")
            .split(whereSeparator: { $0 == " " || $0 == "\u{200C}" }).map(String.init)
        var total = 0.0, group = 0.0, any = false
        for t in toks {
            if t == "و" { continue }
            if let v = Double(t) { group += v; any = true; continue }
            if let v = map[t] { group += v; any = true; continue }
            if let sc = scales[Script.toPersian(t)] ?? scales[t] {
                if sc == 0 { continue }
                total += (group == 0 ? 1 : group) * sc; group = 0; any = true
                continue
            }
        }
        return any ? total + group : nil
    }

    /// سعر مسموع/مكتوب ← قراءات محتملة بالتومان، مرتّبة الأرجح أوّلًا
    static func readings(_ input: String) -> [PriceReading] {
        let raw = Script.toPersian(Script.latinDigits(input))
        guard let n = parseWords(raw), n > 0 else { return [] }
        let isRial = raw.contains("ریال") || raw.contains("ريال")
        let hasScale = raw.contains("هزار") || raw.contains("میلیون") || raw.contains("ملیون") || raw.contains("الف") || raw.contains("ألف")
        var out: [PriceReading] = []
        if isRial {
            out.append(PriceReading(label: "ريال رسميّ (÷١٠ = تومان)", toman: n / 10, likely: true))
            return out
        }
        if !hasScale && n < 1000 {
            // «٥٠ تومن» بالسوق = ٥٠ ألف تومان
            out.append(PriceReading(label: "بالسوق «\(Script.digits(String(Int(n)), for: .fa)) تومن» = \(Int(n)) ألف تومان", toman: n * 1000, likely: true))
            out.append(PriceReading(label: "حرفيًّا \(Int(n)) تومان", toman: n, likely: false))
        } else {
            out.append(PriceReading(label: "تومان", toman: n, likely: true))
            out.append(PriceReading(label: "إذا قصده ريال (÷١٠)", toman: n / 10, likely: false))
        }
        return out
    }

    /// تنسيق رقم كبير بفواصل
    static func fmt(_ v: Double, digits: Int = 0) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: v)) ?? String(Int(v))
    }

    /// شلون البيّاع الإيرانيّ يگول المبلغ (تومان) — نختصر بالألف مثل السوق
    static func streetSay(toman: Double) -> String {
        let t = Int(toman.rounded())
        if t >= 1_000_000 && t % 500_000 == 0 {
            let m = Double(t) / 1_000_000
            let s = m == m.rounded() ? faWords(Int(m)) : (faWords(Int(m)) + " و نیم")
            return s + " میلیون تومن"
        }
        if t >= 1000 && t < 1_000_000 && t % 1000 == 0 { return faWords(t / 1000) + " تومن" }
        return faWords(t) + " تومان"
    }
}
