import Foundation

/// اللغات المدعومة — الفارسيّ والعربيّ أساسيّتان، والباقي إضافة
enum Lang: String, CaseIterable, Codable, Identifiable {
    case ar, fa, en, tr, ku
    var id: String { rawValue }
    var name: String {
        switch self {
        case .ar: return "عربي"
        case .fa: return "فارسي"
        case .en: return "إنكليزي"
        case .tr: return "تركي"
        case .ku: return "كردي"
        }
    }
    var native: String {
        switch self {
        case .ar: return "العربية"
        case .fa: return "فارسی"
        case .en: return "English"
        case .tr: return "Türkçe"
        case .ku: return "کوردی"
        }
    }
    var flag: String {
        switch self {
        case .ar: return "🇮🇶"
        case .fa: return "🇮🇷"
        case .en: return "🇬🇧"
        case .tr: return "🇹🇷"
        case .ku: return "☀️"
        }
    }
    /// لغة تُكتب من اليمين لليسار
    var rtl: Bool { self != .en && self != .tr }
    /// رمز لغة النطق بالجهاز (AVSpeech)
    var voice: String {
        switch self {
        case .ar: return "ar-SA"
        case .fa: return "fa-IR"
        case .en: return "en-US"
        case .tr: return "tr-TR"
        case .ku: return "ckb-IQ"
        }
    }
}

/// تنظيف النصّ قبل الترجمة — أكبر سبب لسوء ترجمة الفارسيّ هو حروف عربيّة بدل فارسيّة والعكس
enum Script {
    static let persianDigits: [Character] = ["۰","۱","۲","۳","۴","۵","۶","۷","۸","۹"]
    static let arabicDigits: [Character] = ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"]

    /// يحوّل أيّ أرقام (فارسيّة/عربيّة‑هنديّة) إلى لاتينيّة
    static func latinDigits(_ s: String) -> String {
        String(s.map { c -> Character in
            if let i = persianDigits.firstIndex(of: c) { return Character(String(i)) }
            if let i = arabicDigits.firstIndex(of: c) { return Character(String(i)) }
            return c
        })
    }

    static func digits(_ s: String, for lang: Lang) -> String {
        let l = latinDigits(s)
        switch lang {
        case .fa: return String(l.map { c in c.isASCII && c.isNumber ? persianDigits[Int(String(c))!] : c })
        default: return l
        }
    }

    /// يحوّل النصّ لكتابة فارسيّة صحيحة: ي→ی، ك→ک، ة تبقى، ى→ی
    /// يحوّل النصّ لكتابة فارسيّة صحيحة: ي→ی، ك→ک، ى→ی، ويشيل التشكيل
    /// (نشتغل على unicodeScalars لأنّ الحرف + حركته بسويفت = Character واحد)
    static func toPersian(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            switch u.value {
            case 0x064A, 0x0649: out.append(Unicode.Scalar(0x06CC)!)
            case 0x0643: out.append(Unicode.Scalar(0x06A9)!)
            case 0x064B...0x0652: continue
            default: out.append(u)
            }
        }
        return String(out)
    }

    /// يحوّل للكتابة العربيّة: ی→ي، ک→ك
    static func toArabic(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            switch u.value {
            case 0x06CC: out.append(Unicode.Scalar(0x064A)!)
            case 0x06A9: out.append(Unicode.Scalar(0x0643)!)
            default: out.append(u)
            }
        }
        return String(out)
    }

    static func normalize(_ s: String, as lang: Lang) -> String {
        let t = s.replacingOccurrences(of: "\u{200C}", with: lang == .fa ? "\u{200C}" : " ")
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        switch lang {
        case .fa: return toPersian(t)
        case .ar: return toArabic(t)
        default: return t
        }
    }

    /// تخمين لغة النصّ من حروفه (بلا شبكة): حروف فارسيّة خاصّة ⇒ فارسي
    static func guess(_ s: String) -> Lang {
        var arabicScript = 0, latin = 0, persianOnly = 0, arabicOnly = 0, turkish = 0
        let pOnly: Set<Character> = ["پ","چ","ژ","گ","ی","ک","ۆ","ێ","ڕ","ڵ"]
        let aOnly: Set<Character> = ["ة","ي","ك","ى","ث","ذ","ض","ظ"]
        let tr: Set<Character> = ["ş","ğ","ı","ç","ö","ü","İ","Ş","Ğ"]
        for c in s {
            if let u = c.unicodeScalars.first?.value, (0x0600...0x06FF).contains(u) || (0xFB50...0xFEFF).contains(u) {
                arabicScript += 1
                if pOnly.contains(c) { persianOnly += 1 }
                if aOnly.contains(c) { arabicOnly += 1 }
            } else if c.isLetter {
                latin += 1
                if tr.contains(c) { turkish += 1 }
            }
        }
        if arabicScript == 0 && latin == 0 { return .ar }
        if latin > arabicScript { return turkish > 0 ? .tr : .en }
        // كلمات فارسيّة شائعة جدًّا بلا حروف خاصّة
        let words = Set(s.split(separator: " ").map(String.init))
        let faWords: Set<String> = ["است","این","آن","من","تو","شما","ما","چه","کجا","خوب","نه","بله","هست","نیست","را","برای","با","از","به","که","می","خیلی","ممنون","مرسی","چطور"]
        let arWords: Set<String> = ["هذا","هذه","في","على","من","إلى","الى","شنو","ليش","وين","شلون","اريد","أريد","هو","هي","كان","ماذا","كيف","أين","نعم","لا"]
        let fw = words.filter { faWords.contains(toPersian($0)) }.count
        let aw = words.filter { arWords.contains(toArabic($0)) }.count
        let faScore = persianOnly * 2 + fw * 3
        let arScore = arabicOnly * 2 + aw * 3
        return faScore > arScore ? .fa : .ar
    }
}
