import Foundation

/// طريقة تسجيل المصروف
enum Via: String, Codable {
    case type, voice, scan
}

/// مصروف واحد
struct Expense: Codable, Identifiable, Equatable {
    var id: UUID
    var amount: Double
    var cat: String
    var note: String
    var date: Date
    var via: Via

    init(id: UUID = UUID(), amount: Double, cat: String, note: String, date: Date, via: Via) {
        self.id = id
        self.amount = amount
        self.cat = cat
        self.note = note
        self.date = date
        self.via = via
    }
}

/// صنف مصروف: اسم + رمز + لون (hue) + كلمات يتعرّف عليها من الكلام والوصولات
struct Cat: Equatable {
    let id: String
    let name: String
    let emoji: String
    let hue: Double
    let words: [String]
}

enum Cats {
    static let all: [Cat] = [
        Cat(id: "food", name: "أكل ومطاعم", emoji: "🍔", hue: 0.04, words: [
            "عشا", "عشاء", "غدا", "غداء", "ريوك", "فطور", "ريوگ", "مطعم", "مطاعم", "اكل", "أكل", "اكله", "شاورما", "شاورمه",
            "برگر", "برجر", "بركر", "بيتزا", "كباب", "تكه", "سندويج", "سندويچ", "لفه", "لفّة", "فلافل", "مشويات", "دجاج",
            "سمك", "مسگوف", "باجه", "پاچة", "كص", "فاست", "ماكدونالدز", "كنتاكي", "طلبات", "توصيل", "ديليفري", "شاورم", "burger", "pizza", "shawarma", "chicken", "fries", "restaurant", "grill", "kitchen", "kfc", "mcdonald", "sandwich", "food"]),
        Cat(id: "coffee", name: "قهوة وحلويات", emoji: "☕", hue: 0.08, words: [
            "قهوه", "قهوة", "كافي", "كوفي", "كافيه", "ستاربكس", "چاي", "شاي", "جاي", "نسكافيه", "عصير", "عصائر",
            "حلويات", "حلوى", "كيك", "كيكه", "دونات", "ايس", "ايسكريم", "آيس", "بوظه", "موطا", "كنافه", "بقلاوه", "شوكولاته", "coffee", "cafe", "café", "starbucks", "tea", "juice", "cake", "dessert", "bakery", "donut"]),
        Cat(id: "market", name: "سوبرماركت وبيت", emoji: "🛒", hue: 0.13, words: [
            "سوبرماركت", "ماركت", "سوبر", "هايبر", "خضره", "خضار", "فواكه", "فاكهه", "لحم", "لحمه", "خبز", "صمون", "حليب",
            "بيض", "رز", "تمن", "سكر", "زيت", "طحين", "منظفات", "مواد", "اغراض", "أغراض", "بيت", "معجون", "مناديل", "ماي", "مي", "قنينه", "market", "supermarket", "hypermarket", "grocery", "carrefour", "lulu"]),
        Cat(id: "transport", name: "مواصلات", emoji: "🚕", hue: 0.58, words: [
            "تكسي", "تاكسي", "كريم", "اوبر", "أوبر", "باص", "كيا", "كوستر", "مواصلات", "اجره", "اجرة", "كروه", "كروة",
            "توك", "تكتك", "ستوته", "مترو", "قطار", "موقف", "باركنج", "كراج", "غسل", "غسيل"]),
        Cat(id: "fuel", name: "بنزين وسيارة", emoji: "⛽", hue: 0.0, words: [
            "بنزين", "وقود", "كاز", "گاز", "ديزل", "تانكي", "محطه", "سياره", "سيارة", "تصليح", "ميكانيك", "تاير", "تايرات", "دهن", "زيت السياره", "fuel", "petrol", "gasoline", "station"]),
        Cat(id: "bills", name: "فواتير ورصيد", emoji: "📱", hue: 0.75, words: [
            "رصيد", "كارت", "انترنت", "نت", "واي", "فاتوره", "فاتورة", "فواتير", "كهرباء", "كهربا", "مولده", "مولدة", "امبير",
            "ماء", "ايجار", "إيجار", "اشتراك", "باقه", "باقة", "اسيا", "اسياسيل", "كورك", "شحن"]),
        Cat(id: "shopping", name: "تسوّق وملابس", emoji: "🛍️", hue: 0.88, words: [
            "ملابس", "هدوم", "قاط", "قميص", "تيشيرت", "بنطرون", "بنطلون", "جينز", "حذاء", "قندره", "جزمه", "نعال", "مول",
            "تسوق", "تسوّق", "عطر", "عطور", "ساعه", "نظاره", "شنطه", "جنطه", "اكسسوارات", "مكياج", "حلاق", "حلاقه", "صالون", "mall", "fashion", "shoes", "store", "boutique"]),
        Cat(id: "health", name: "صحّة ودواء", emoji: "💊", hue: 0.47, words: [
            "دواء", "دوا", "ادويه", "صيدليه", "صيدلية", "طبيب", "دكتور", "عياده", "مستشفى", "تحليل", "تحاليل", "سونار",
            "اشعه", "اسنان", "نظارات", "فيتامين", "علاج", "مراجعه", "جيم", "نادي", "pharmacy", "clinic", "hospital", "medical", "gym"]),
        Cat(id: "fun", name: "ترفيه", emoji: "🎮", hue: 0.80, words: [
            "سينما", "فلم", "فيلم", "cinema", "netflix", "لعبه", "العاب", "ألعاب", "بلايستيشن", "سوني", "نتفلكس", "سبوتيفاي",
            "ملاهي", "طلعه", "كوفي شوب", "شيشه", "اركيله", "نركيله", "بولنج", "حفله", "مباراه", "تذكره مباراه"]),
        Cat(id: "gifts", name: "هدايا ومناسبات", emoji: "🎁", hue: 0.93, words: [
            "هديه", "هدية", "هدايا", "عيديه", "عيدية", "ورد", "بوكيه", "عرس", "زواج", "خطوبه", "تعزيه", "مولود", "عيد ميلاد", "صدقه", "تبرع"]),
        Cat(id: "edu", name: "تعليم", emoji: "📚", hue: 0.62, words: [
            "كتاب", "كتب", "دوره", "دورة", "كورس", "جامعه", "جامعة", "مدرسه", "مدرسة", "قسط", "اقساط", "قرطاسيه", "دفتر",
            "اقلام", "ملزمه", "ملازم", "استنساخ", "طباعه", "مدرس", "خصوصي"]),
        Cat(id: "travel", name: "سفر", emoji: "✈️", hue: 0.55, words: [
            "سفر", "فندق", "اوتيل", "طياره", "طيارة", "تذكره", "تذاكر", "حجز", "فيزا", "مطار", "جواز", "رحله", "رحلة", "hotel", "airlines", "airways", "booking"]),
        Cat(id: "other", name: "غيرها", emoji: "📦", hue: 0.36, words: []),
    ]

    static func get(_ id: String) -> Cat {
        if let c = all.first(where: { $0.id == id }) { return c }
        return all[all.count - 1]
    }

    /// الكلمات بعد التطبيع، محسوبة مرّة وحدة
    static let normWords: [(String, [String])] = all.map { c in (c.id, c.words.map { AR.norm($0) }) }
}

/// أدوات النصّ العربيّ: توحيد الحروف والأرقام
enum AR {
    static func norm(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for ch in s.unicodeScalars {
            let v = ch.value
            switch v {
            case 0x064B...0x065F, 0x0670, 0x0640:
                continue
            case 0x0623, 0x0625, 0x0622, 0x0671:
                out.append("ا")
            case 0x0629:
                out.append("ه")
            case 0x0649:
                out.append("ي")
            case 0x06CC:
                out.append("ي")
            case 0x0660...0x0669:
                out.append(Unicode.Scalar(UInt8(v - 0x0660 + 48)))
            case 0x06F0...0x06F9:
                out.append(Unicode.Scalar(UInt8(v - 0x06F0 + 48)))
            case 0x066C:
                out.append(",")
            case 0x066B:
                out.append(".")
            case 0x0686:
                out.append("ج")
            case 0x06AF, 0x06A9:
                out.append("ك")
            case 0x067E:
                out.append("ب")
            default:
                out.append(ch)
            }
        }
        return String(out).lowercased()
    }

    static func isDigit(_ c: Character) -> Bool {
        guard let a = c.asciiValue else { return false }
        return a >= 48 && a <= 57
    }

    /// يفصل الأرقام عن الحروف الملتصقة بيها: «25الف» ← «25 الف»
    static func splitDigits(_ s: String) -> String {
        var out = ""
        var prevKind = 0  // 0 بداية/فراغ، 1 رقم، 2 حرف
        let chars = Array(s)
        for (i, c) in chars.enumerated() {
            var kind = 2
            if c.isWhitespace {
                kind = 0
            } else if isDigit(c) {
                kind = 1
            } else if (c == "." || c == ",") && prevKind == 1 && i + 1 < chars.count && isDigit(chars[i + 1]) {
                kind = 1
            }
            if kind != 0 && prevKind != 0 && kind != prevKind { out.append(" ") }
            out.append(c)
            prevKind = kind
        }
        return out
    }
}
