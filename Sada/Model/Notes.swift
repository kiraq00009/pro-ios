import Foundation

/// تسجيل/بصمة محفوظة: الصوت + النصّ + الملخّص
struct Note: Identifiable, Codable, Hashable {
    let id: UUID
    var file: String              // اسم ملفّ الصوت داخل مجلّد التطبيق
    var source: String            // واتساب / تليكرام / تسجيل / ملفّ
    var created: Date
    var duration: Double
    var lang: Lang?
    var segments: [Api.Segment] = []
    var summary: Api.Summary?
    var translation: [String]?    // ترجمة كلّ مقطع للعربي (إذا الأصل مو عربي)
    var state: Phase = .waiting
    var engine: String?
    var error: String?
    var starred = false

    enum Phase: String, Codable { case waiting, transcribing, summarizing, done, failed }

    var text: String { segments.map(\.text).joined(separator: " ") }
    var title: String {
        if let t = summary?.title, !t.isEmpty { return t }
        let w = text.split(separator: " ").prefix(6).joined(separator: " ")
        return w.isEmpty ? "بصمة \(source)" : w
    }
    var words: Int { text.split(separator: " ").count }

    /// كم وقت يوفّر عليك: قراءة ٢٣٠ كلمة/د مقابل سماع المدّة كاملة
    var savedSeconds: Double { max(0, duration - Double(words) / 230 * 60) }

    func segmentIndex(at t: Double) -> Int? {
        guard !segments.isEmpty else { return nil }
        var lo = 0, hi = segments.count - 1, ans: Int? = nil
        while lo <= hi {
            let m = (lo + hi) / 2
            if segments[m].s <= t { ans = m; lo = m + 1 } else { hi = m - 1 }
        }
        if let a = ans, t <= segments[a].e + 1.5 { return a }
        return ans
    }
}

enum Fmt {
    static func dur(_ s: Double) -> String {
        let t = Int(s.rounded())
        if t >= 3600 { return String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) }
        return String(format: "%d:%02d", t / 60, t % 60)
    }
    static func saved(_ s: Double) -> String {
        let t = Int(s.rounded())
        if t < 60 { return "\(t) ثانية" }
        return "\(t / 60) دقيقة"
    }
}

/// ملخّص على الجهاز (بلا نت): يختار أهمّ الجمل + يطلّع المواعيد والأرقام والمبالغ
enum LocalSummary {
    static let stop: Set<String> = ["في","من","على","الى","إلى","عن","هذا","هذه","ذلك","هو","هي","انا","آني","اني","انت","إنت","احنا","هم","كان","يكون","شي","شنو","يعني","بس","هم","لو","او","أو","و","ثم","لا","ما","مو","اكو","ماكو","هاي","هذول","حتى","كلش","زين","اي","إي","خوش","والله","هيچ","هيج",
                                   "این","آن","که","را","از","به","با","در","برای","است","هست","من","تو","ما","شما","او","یه","یک","هم","خیلی","دیگه","ولی","اما","یا","و"]

    static func sentences(_ text: String) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in text {
            cur.append(ch)
            if ".!?؟…\n".contains(ch) {
                let t = cur.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.count > 2 { out.append(t) }
                cur = ""
            }
        }
        let t = cur.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > 2 { out.append(t) }
        // كلام منطوق غالبًا بلا نقاط ⇒ نقسّم كلّ ~٢٠ كلمة
        if out.count <= 1 {
            let w = text.split(separator: " ").map(String.init)
            guard w.count > 24 else { return out }
            return stride(from: 0, to: w.count, by: 20).map { w[$0..<min($0 + 20, w.count)].joined(separator: " ") }
        }
        return out
    }

    static func tokens(_ s: String) -> [String] {
        Script.toArabic(s).lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stop.contains($0) }
    }

    static func make(_ text: String) -> Api.Summary {
        let sents = sentences(text)
        guard !sents.isEmpty else { return Api.Summary(title: "", summary: text, points: [], actions: [], engine: "device") }
        var freq: [String: Double] = [:]
        for t in tokens(text) { freq[t, default: 0] += 1 }
        let scored = sents.enumerated().map { (i, s) -> (Int, Double) in
            let tk = tokens(s)
            let base = tk.reduce(0) { $0 + (freq[$1] ?? 0) } / sqrt(Double(max(tk.count, 1)))
            let pos = i == 0 ? 1.25 : (i == sents.count - 1 ? 1.1 : 1)
            let hasNum = s.rangeOfCharacter(from: .decimalDigits) != nil || containsEasternDigit(s) ? 1.2 : 1
            return (i, base * pos * hasNum)
        }
        let k = min(max(2, sents.count / 4), 6)
        let top = scored.sorted { $0.1 > $1.1 }.prefix(k).map(\.0).sorted()
        let title = sents[0].split(separator: " ").prefix(6).joined(separator: " ")
        return Api.Summary(title: title, summary: top.prefix(2).map { sents[$0] }.joined(separator: " "),
                           points: top.map { sents[$0] }, actions: actions(text), engine: "device")
    }

    static func containsEasternDigit(_ s: String) -> Bool {
        s.contains { Script.persianDigits.contains($0) || Script.arabicDigits.contains($0) }
    }

    /// مواعيد/أرقام/مبالغ: «الساعة ٥»، «باچر»، «٢٥٠ ألف»، «رقمي 0770…»
    static func actions(_ text: String) -> [String] {
        let words = Script.latinDigits(text).split(separator: " ").map(String.init)
        let timeWords: Set<String> = ["باچر","باكر","بكرة","غدا","غدًا","اليوم","الليلة","عصر","العصر","الصبح","الساعة","ساعة","الخميس","الجمعة","السبت","الأحد","الاحد","الاثنين","الثلاثاء","الأربعاء","الاربعاء","فردا","امروز","امشب","ساعت"]
        let moneyWords: Set<String> = ["ألف","الف","مليون","دولار","دينار","تومان","تومن","ورقة","فلوس","هزار","میلیون"]
        var out: [String] = []
        var i = 0
        while i < words.count {
            let w = words[i].trimmingCharacters(in: .punctuationCharacters)
            let isNum = w.rangeOfCharacter(from: .decimalDigits) != nil
            if timeWords.contains(w) || isNum || moneyWords.contains(w) {
                let a = max(0, i - 2), b = min(words.count, i + 4)
                let frag = words[a..<b].joined(separator: " ")
                if !out.contains(where: { $0.contains(frag) || frag.contains($0) }) { out.append(frag) }
                i = b
                continue
            }
            i += 1
        }
        return Array(out.prefix(6))
    }
}

enum Search {
    static func key(_ s: String) -> String {
        Script.toArabic(s).lowercased()
            .replacingOccurrences(of: "أ", with: "ا").replacingOccurrences(of: "إ", with: "ا").replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ة", with: "ه").replacingOccurrences(of: "ى", with: "ي")
    }
    static func match(_ n: Note, _ q: String) -> Bool {
        let k = key(q)
        if k.isEmpty { return true }
        return key(n.title).contains(k) || key(n.text).contains(k) || key(n.summary?.summary ?? "").contains(k)
    }
}
