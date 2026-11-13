import Foundation
import CryptoKit

// منطق «درع» (Foundation + CryptoKit): قوّة كلمة السرّ، المولّد، رموز التحقّق TOTP، وتحليل الروابط — ينفحص آليًّا

enum Sec {
    // MARK: قوّة كلمة السرّ

    static let common: Set<String> = ["123456", "password", "12345678", "qwerty", "123456789", "12345", "1234", "111111", "1234567", "dragon", "123123", "baseball", "abc123", "football",
        "monkey", "letmein", "696969", "shadow", "master", "666666", "qwertyuiop", "123321", "mustang", "1234567890", "michael", "654321", "superman", "1qaz2wsx", "7777777", "121212",
        "000000", "qazwsx", "123qwe", "killer", "trustno1", "jordan", "jennifer", "zxcvbnm", "asdfgh", "hunter", "buster", "soccer", "harley", "batman", "andrew", "tigger", "sunshine",
        "iloveyou", "2000", "charlie", "robert", "thomas", "hockey", "ranger", "daniel", "starwars", "klaster", "112233", "george", "computer", "michelle", "jessica", "pepper", "1111",
        "zxcvbn", "555555", "11111111", "131313", "freedom", "777777", "pass", "maggie", "159753", "aaaaaa", "ginger", "princess", "joshua", "cheese", "amanda", "summer", "love", "ashley",
        "nicole", "chelsea", "biteme", "matthew", "access", "yankees", "987654321", "dallas", "austin", "thunder", "taylor", "matrix", "admin", "welcome", "login", "passw0rd", "p@ssw0rd",
        "password1", "password123", "qwerty123", "admin123", "iphone", "google", "samsung", "1q2w3e4r", "1q2w3e", "abcd1234", "a123456", "123abc", "asd123", "qwe123", "zaq12wsx"]
    private static let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm", "1234567890", "abcdefghijklmnopqrstuvwxyz"]

    struct Strength: Equatable {
        var score: Int              // 0 ضعيفة جدًّا … 4 قويّة جدًّا
        var bits: Double            // تقدير عشوائيّتها
        var issues: [String]        // مشاكل بصياغة مفهومة
        var crack: String           // وقت الكسر التقريبيّ
    }

    static func strength(_ pw: String) -> Strength {
        guard !pw.isEmpty else { return Strength(score: 0, bits: 0, issues: [], crack: "") }
        var issues: [String] = []
        let lower = pw.lowercased()
        var pool = 0
        if pw.unicodeScalars.contains(where: { CharacterSet.lowercaseLetters.contains($0) }) { pool += 26 }
        if pw.unicodeScalars.contains(where: { CharacterSet.uppercaseLetters.contains($0) }) { pool += 26 }
        if pw.unicodeScalars.contains(where: { CharacterSet.decimalDigits.contains($0) }) { pool += 10 }
        if pw.unicodeScalars.contains(where: { !CharacterSet.alphanumerics.contains($0) }) { pool += 33 }
        if pw.unicodeScalars.contains(where: { $0.value > 127 && CharacterSet.letters.contains($0) }) { pool += 30 }
        var bits = Double(pw.count) * log2(Double(max(2, pool)))

        // كلمة مشهورة (حتى لو متبوعة بأرقام أو مبدّلة حروفها برموز)
        let leet = String(lower.map { ch -> Character in ["0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i"][ch] ?? ch })
        let stripped = lower.trimmingCharacters(in: CharacterSet.decimalDigits.union(.punctuationCharacters).union(.symbols))
        if common.contains(lower) || common.contains(leet) { issues.append("من أشهر كلمات السرّ بالعالم — تنكسر بلحظة"); bits = min(bits, 4) }
        else if !stripped.isEmpty, stripped.count >= 4, common.contains(stripped) || common.contains(String(leet.filter { $0.isLetter })) { issues.append("كلمة مشهورة ومضاف إلها أرقام أو رموز — هاي أوّل شي يجرّبوه"); bits = min(bits, 14) }

        // تكرار وتسلسل
        let uniq = Set(pw).count
        if uniq <= 2 && pw.count >= 4 { issues.append("نفس الحرف مكرّر"); bits = min(bits, 8) }
        else if Double(uniq) / Double(pw.count) < 0.5 && pw.count >= 6 { issues.append("بيها تكرار هواية"); bits *= 0.7 }
        var seq = 0
        let chars = Array(lower)
        for row in rows {
            for r in [Array(row), Array(row.reversed())] {
                for i in chars.indices {
                    guard let p = r.firstIndex(of: chars[i]) else { continue }
                    var k = i, q = p, run = 0
                    while k < chars.count, q < r.count, chars[k] == r[q] { run += 1; k += 1; q += 1 }
                    seq = max(seq, run)
                }
            }
        }
        if seq >= 4 { issues.append("بيها تسلسل معروف (مثل 1234 أو qwerty)"); bits -= Double(seq) * 2.5 }
        if lower.range(of: "(19|20)\\d{2}", options: .regularExpression) != nil { issues.append("بيها سنة — سهلة التخمين"); bits -= 6 }
        if pw.count < 8 { issues.append("قصيرة — خلّيها ١٢ حرف أو أكثر") }
        else if pw.count < 12 && pool < 60 { issues.append("طوّلها شويّة أو ضيف أنواع حروف ثانية") }
        if pool <= 10 { issues.append("أرقام فقط") } else if pool <= 26 { issues.append("نوع واحد من الحروف") }
        bits = max(0, bits)
        let score = bits < 28 ? 0 : (bits < 40 ? 1 : (bits < 60 ? 2 : (bits < 80 ? 3 : 4)))
        return Strength(score: score, bits: bits, issues: issues, crack: crackTime(bits))
    }

    /// وقت التخمين بافتراض ١٠ مليار محاولة بالثانية (مهاجم بكروت شاشة)
    static func crackTime(_ bits: Double) -> String {
        let secs = pow(2, bits) / 2 / 1e10
        if secs < 1 { return "أقلّ من ثانية" }
        if secs < 60 { return "ثواني" }
        if secs < 3600 { return "\(Int(secs / 60)) دقيقة" }
        if secs < 86400 { return "\(Int(secs / 3600)) ساعة" }
        if secs < 86400 * 365 { return "\(Int(secs / 86400)) يوم" }
        let years = secs / (86400 * 365)
        if years < 1000 { return "\(Int(years)) سنة" }
        if years < 1e6 { return "\(Int(years / 1000)) ألف سنة" }
        if years < 1e9 { return "\(Int(years / 1e6)) مليون سنة" }
        return "أكثر من مليار سنة"
    }

    // MARK: المولّد

    static func generate(length: Int, upper: Bool, digits: Bool, symbols: Bool, readable: Bool, using rng: inout some RandomNumberGenerator) -> String {
        var lower = "abcdefghijklmnopqrstuvwxyz", up = "ABCDEFGHIJKLMNOPQRSTUVWXYZ", num = "0123456789"
        let sym = "!@#$%^&*-_=+?"
        if readable { lower = "abcdefghijkmnpqrstuvwxyz"; up = "ABCDEFGHJKLMNPQRSTUVWXYZ"; num = "23456789" }     // بلا الحروف المتشابهة (l/1 · O/0)
        var sets = [Array(lower)]
        if upper { sets.append(Array(up)) }; if digits { sets.append(Array(num)) }; if symbols { sets.append(Array(sym)) }
        let n = max(sets.count, min(64, length))
        var out: [Character] = sets.map { $0.randomElement(using: &rng)! }                 // حرف من كلّ نوع مضمون
        let all = sets.flatMap { $0 }
        while out.count < n { out.append(all.randomElement(using: &rng)!) }
        out.shuffle(using: &rng)
        return String(out)
    }
    static let words = ["river", "stone", "cloud", "tiger", "maple", "ocean", "piano", "rocket", "silver", "garden", "window", "castle", "forest", "bridge", "candle", "dragon", "falcon", "harbor",
                        "island", "jungle", "kernel", "lantern", "meadow", "nebula", "orange", "pepper", "quartz", "rabbit", "saddle", "tunnel", "velvet", "walnut", "yellow", "zephyr", "anchor",
                        "breeze", "copper", "desert", "ember", "feather", "glacier", "hammer", "ivory", "jasmine", "kitten", "lemon", "marble", "north", "olive", "planet", "quiver", "ribbon",
                        "spider", "thunder", "umbrella", "valley", "winter", "amber", "basket", "comet", "dolphin", "engine", "flame", "ginger"]
    /// عبارة سرّ: كلمات عشوائيّة يسهل حفظها ويصعب تخمينها
    static func passphrase(words n: Int, using rng: inout some RandomNumberGenerator) -> String {
        var parts = (0..<max(3, min(8, n))).map { _ in words.randomElement(using: &rng)! }
        let i = Int.random(in: 0..<parts.count, using: &rng)
        parts[i] = parts[i].capitalized + String(Int.random(in: 10...99, using: &rng))
        return parts.joined(separator: "-")
    }

    // MARK: فحص التسريب (k-anonymity): ما ينبعث من الكلمة إلّا أوّل ٥ حروف من بصمتها

    static func sha1(_ s: String) -> String { Insecure.SHA1.hash(data: Data(s.utf8)).map { String(format: "%02X", $0) }.joined() }
    static func pwnedCount(rangeBody: String, hash: String) -> Int {
        let suffix = String(hash.dropFirst(5)).uppercased()
        for line in rangeBody.split(whereSeparator: { $0.isNewline }) {
            let parts = line.split(separator: ":")
            if parts.count == 2, parts[0].uppercased() == suffix { return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0 }
        }
        return 0
    }

    // MARK: رموز التحقّق بخطوتين (TOTP — RFC 6238)

    static func base32(_ s: String) -> Data? {
        let abc = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var bits = 0, value = 0
        var out = Data()
        for ch in s.uppercased() where ch != "=" && ch != " " && ch != "-" {
            guard let v = abc.firstIndex(of: ch) else { return nil }
            value = (value << 5) | v; bits += 5
            if bits >= 8 { bits -= 8; out.append(UInt8((value >> bits) & 0xFF)) }
        }
        return out.isEmpty ? nil : out
    }
    static func hotp(key: Data, counter: UInt64, digits: Int = 6) -> String {
        var c = counter.bigEndian
        let msg = Data(bytes: &c, count: 8)
        let mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: msg, using: SymmetricKey(data: key)))
        let off = Int(mac[mac.count - 1] & 0x0F)
        let bin = (UInt32(mac[off] & 0x7F) << 24) | (UInt32(mac[off + 1]) << 16) | (UInt32(mac[off + 2]) << 8) | UInt32(mac[off + 3])
        var mod: UInt32 = 1; for _ in 0..<digits { mod *= 10 }
        let code = String(bin % mod)
        return String(repeating: "0", count: max(0, digits - code.count)) + code
    }
    static func totp(secret: String, at time: TimeInterval, period: Int = 30, digits: Int = 6) -> String? {
        guard let key = base32(secret) else { return nil }
        return hotp(key: key, counter: UInt64(max(0, time)) / UInt64(max(1, period)), digits: digits)
    }

    struct OTPAccount: Codable, Identifiable, Hashable {
        var id = UUID(); var issuer: String; var name: String; var secret: String; var digits = 6; var period = 30
    }
    /// يقرا رابط otpauth://totp/Issuer:name?secret=…&issuer=…
    static func parseOTP(_ text: String) -> OTPAccount? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = URLComponents(string: t), c.scheme?.lowercased() == "otpauth", c.host?.lowercased() == "totp" else { return nil }
        let q = Dictionary((c.queryItems ?? []).map { ($0.name.lowercased(), $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        guard let secret = q["secret"], base32(secret) != nil else { return nil }
        var label = String(c.path.dropFirst()).removingPercentEncoding ?? ""
        var issuer = q["issuer"] ?? ""
        if let colon = label.firstIndex(of: ":") {
            if issuer.isEmpty { issuer = String(label[..<colon]) }
            label = String(label[label.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        return OTPAccount(issuer: issuer.isEmpty ? label : issuer, name: label, secret: secret.uppercased().replacingOccurrences(of: " ", with: ""),
                          digits: Int(q["digits"] ?? "") ?? 6, period: Int(q["period"] ?? "") ?? 30)
    }

    // MARK: تحليل الروابط

    struct Flag: Equatable { var level: Int; var text: String }       // 2 خطير · 1 انتبه · 0 معلومة
    struct LinkReport { var host: String; var flags: [Flag]; var verdict: Int }   // 0 ما بيه شي واضح · 1 انتبه · 2 خطير

    static let brands = ["google", "facebook", "instagram", "whatsapp", "apple", "icloud", "microsoft", "paypal", "amazon", "netflix", "telegram", "twitter", "tiktok", "snapchat",
                         "youtube", "linkedin", "binance", "coinbase", "outlook", "yahoo", "dropbox", "steam", "discord", "spotify", "ebay", "visa", "mastercard"]
    static let shorteners: Set<String> = ["bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd", "buff.ly", "cutt.ly", "rb.gy", "shorturl.at", "rebrand.ly", "tiny.cc", "t.ly", "lnkd.in", "s.id"]
    static let riskyTLD: Set<String> = ["zip", "mov", "xyz", "top", "tk", "ml", "ga", "cf", "gq", "click", "work", "country", "kim", "cam", "rest", "icu", "buzz", "monster", "quest"]

    static func edit(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }; if y.isEmpty { return x.count }
        var prev = Array(0...y.count), cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count { cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1)) }
            swap(&prev, &cur)
        }
        return prev[y.count]
    }

    static func analyze(_ raw: String) -> LinkReport? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let hadScheme = s.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) != nil
        if !hadScheme { s = "https://" + s }
        guard let c = URLComponents(string: s), let host0 = c.host?.lowercased(), host0.contains(".") || host0 == "localhost" else { return nil }
        var flags: [Flag] = []
        let host = host0.hasPrefix("www.") ? String(host0.dropFirst(4)) : host0
        let labels = host.split(separator: ".").map(String.init)
        let tld = labels.last ?? ""
        let reg = labels.count >= 2 ? labels[labels.count - 2] : host              // اسم الموقع الأساسيّ
        let isIP = host.range(of: "^\\d{1,3}(\\.\\d{1,3}){3}$", options: .regularExpression) != nil

        if hadScheme && c.scheme?.lowercased() == "http" { flags.append(Flag(level: 1, text: "اتّصال غير مشفّر (http) — لا تكتب بيه كلمة سرّ أو بطاقة")) }
        if c.user != nil || raw.contains("@") && !(c.path.contains("@") || (c.query ?? "").contains("@")) { flags.append(Flag(level: 2, text: "بيه علامة @ قبل اسم الموقع — حيلة تخلّي العنوان يبيّن غير الحقيقيّ")) }
        if isIP { flags.append(Flag(level: 2, text: "العنوان رقم IP بلا اسم — المواقع المحترمة ما تسوّيها")) }
        if host.contains("xn--") { flags.append(Flag(level: 2, text: "الاسم بيه حروف من لغة ثانية تشبه الإنكليزيّة (تقليد حروف)")) }
        if host.unicodeScalars.contains(where: { $0.value > 127 }) { flags.append(Flag(level: 2, text: "الاسم بيه حروف غير إنكليزيّة ممكن تقلّد حروف حقيقيّة")) }
        if shorteners.contains(host) { flags.append(Flag(level: 1, text: "رابط مختصر — يخفي الوجهة الحقيقيّة")) }
        if riskyTLD.contains(tld) { flags.append(Flag(level: 1, text: "نهاية الموقع (.\(tld)) تنستعمل هواية بالمواقع الاحتياليّة")) }
        if labels.count >= 5 { flags.append(Flag(level: 1, text: "اسم طويل بنطاقات فرعيّة هواية — يخفون بيه الاسم الحقيقيّ")) }
        if host.filter({ $0 == "-" }).count >= 3 { flags.append(Flag(level: 1, text: "شرطات هواية بالاسم")) }

        // تقليد اسم مشهور
        if !isIP {
            let clean = reg.replacingOccurrences(of: "-", with: "")
            let deleet = String(clean.map { ch -> Character in ["0": "o", "1": "l", "3": "e", "5": "s", "4": "a", "7": "t"][ch] ?? ch })
            for b in brands {
                if reg == b { continue }                                               // الموقع الأصليّ نفسه
                let inSub = labels.dropLast(2).contains { $0.contains(b) }
                if deleet == b || (clean != b && clean.count >= 5 && edit(clean, b) == 1) { flags.append(Flag(level: 2, text: "يقلّد اسم «\(b)» بحرف مختلف — الأصليّ \(b).com")); break }
                if (clean.contains(b) || deleet.contains(b)) && clean != b { flags.append(Flag(level: 2, text: "بيه اسم «\(b)» بس هو مو موقعهم الرسميّ")); break }
                if inSub { flags.append(Flag(level: 2, text: "اسم «\(b)» محطوط بأوّل العنوان، بس الموقع الحقيقيّ هو \(reg).\(tld)")); break }
            }
        }
        let path = (c.path + "?" + (c.query ?? "")).lowercased()
        if ["login", "verify", "secure", "account", "update", "signin", "confirm", "wallet", "password"].contains(where: { path.contains($0) || host.contains($0) }) && !flags.isEmpty {
            flags.append(Flag(level: 1, text: "يطلب تسجيل دخول أو «تأكيد حساب» — لا تدخّل بياناتك"))
        }
        if [".exe", ".apk", ".scr", ".bat", ".msi", ".dmg", ".ipa"].contains(where: { path.contains($0) }) { flags.append(Flag(level: 1, text: "ينزّل ملفّ برنامج — لا تفتحه إلّا إذا واثق من المصدر")) }
        let verdict = flags.map { $0.level }.max() ?? 0
        return LinkReport(host: host, flags: flags.sorted { $0.level > $1.level }, verdict: verdict)
    }
}
