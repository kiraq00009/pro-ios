import Foundation
import CryptoKit
import Security

// منطق التشفير وإخفاء الرسائل — خالص وينفحص آليًّا.
// التشفير: AES‑GCM بمفتاح مشتقّ من كلمة سرّ عبر HKDF‑SHA256 + ملح عشوائيّ.
// الإخفاء داخل صورة: LSB على بايتات البكسل (RGBA) مع رأس طول + توقيع.

enum Crypto {
    static let magic: [UInt8] = [0x53, 0x46, 0x31]       // "SF1"

    /// يشتقّ مفتاح ٣٢ بايت من كلمة السرّ والملح
    static func derive(pass: String, salt: Data) -> SymmetricKey {
        let base = SymmetricKey(data: Data(SHA256.hash(data: Data(pass.utf8))))
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: base, salt: salt, info: Data("shifra".utf8), outputByteCount: 32)
        return key
    }

    /// يشفّر نصًّا ويرجّع كتلة: magic(3) + salt(16) + nonce(12) + ciphertext+tag
    static func encryptRaw(_ text: String, pass: String) -> Data? {
        guard !pass.isEmpty else { return nil }
        var rng = SystemRandomNumberGenerator()
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255, using: &rng) })
        let key = derive(pass: pass, salt: salt)
        guard let sealed = try? AES.GCM.seal(Data(text.utf8), using: key) else { return nil }
        guard let combined = sealed.combined else { return nil }     // nonce + ct + tag
        return Data(magic) + salt + combined
    }

    static func decryptRaw(_ data: Data, pass: String) -> String? {
        guard data.count > 3 + 16 + 28, Array(data.prefix(3)) == magic else { return nil }
        let salt = data.subdata(in: 3..<19)
        let combined = data.subdata(in: 19..<data.count)
        let key = derive(pass: pass, salt: salt)
        guard let box = try? AES.GCM.SealedBox(combined: combined),
              let plain = try? AES.GCM.open(box, using: key) else { return nil }
        return String(data: plain, encoding: .utf8)
    }

    /// النصّ المشفّر جاهز للّصق: سطر توقيع + Base64 مقسّم
    static func encrypt(_ text: String, pass: String) -> String? {
        guard let raw = encryptRaw(text, pass: pass) else { return nil }
        let b64 = raw.base64EncodedString()
        var body = ""
        var i = b64.startIndex
        while i < b64.endIndex {
            let j = b64.index(i, offsetBy: 64, limitedBy: b64.endIndex) ?? b64.endIndex
            body += b64[i..<j] + "\n"; i = j
        }
        return "-----شفرة مقفلة-----\n" + body + "-----نهاية-----"
    }

    /// يفكّ أيّ نصّ ملصوق فيه شفرة (يتجاهل الزوائد)
    static func decrypt(_ blob: String, pass: String) -> String? {
        let inner: String
        if let r = blob.range(of: "-----شفرة مقفلة-----"), let e = blob.range(of: "-----نهاية-----") {
            inner = String(blob[r.upperBound..<e.lowerBound])
        } else { inner = blob }
        let b64 = inner.filter { !$0.isWhitespace }
        guard let raw = Data(base64Encoded: b64) else { return nil }
        return decryptRaw(raw, pass: pass)
    }

    /// يبيّن إذا النصّ يحتوي شفرة
    static func looksEncrypted(_ s: String) -> Bool { s.contains("-----شفرة مقفلة-----") }
}

// MARK: الإخفاء داخل صورة (Steganography — LSB)

enum Stego {
    static let header: [UInt8] = [0x53, 0x54, 0x47]      // "STG"

    /// أقصى عدد بايتات يمكن إخفاؤها بصورة بعدد بكسل معيّن (نستعمل 3 قنوات لكلّ بكسل)
    static func capacity(pixels: Int) -> Int { max(0, pixels * 3 / 8 - 7) }

    /// يحوّل بايتات لبِتّات (MSB أوّل)
    static func bits(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []; out.reserveCapacity(bytes.count * 8)
        for b in bytes { for k in stride(from: 7, through: 0, by: -1) { out.append((b >> k) & 1) } }
        return out
    }
    static func unbits(_ bits: ArraySlice<UInt8>) -> [UInt8] {
        var out: [UInt8] = []
        var i = bits.startIndex
        while i + 8 <= bits.endIndex {
            var b: UInt8 = 0
            for k in 0..<8 { b = (b << 1) | (bits[i + k] & 1) }
            out.append(b); i += 8
        }
        return out
    }

    /// يبني الحمولة الكاملة: header(3) + length(4 big‑endian) + payload
    static func payload(_ data: Data) -> [UInt8] {
        let n = UInt32(data.count)
        let len = [UInt8((n >> 24) & 255), UInt8((n >> 16) & 255), UInt8((n >> 8) & 255), UInt8(n & 255)]
        return header + len + Array(data)
    }

    /// يخبّي البايتات داخل قنوات RGB (يتخطّى قناة ألفا كلّ بايت رابع). يرجّع القنوات معدّلة.
    /// channels: مصفوفة RGBA مسطّحة (4 لكلّ بكسل)
    static func embed(into channels: inout [UInt8], data: Data) -> Bool {
        let payloadBits = bits(payload(data))
        // المواقع القابلة للكتابة: كلّ القنوات عدا ألفا (المؤشّر %4 == 3)
        var idx = 0
        var written = 0
        while written < payloadBits.count && idx < channels.count {
            if idx % 4 != 3 {
                channels[idx] = (channels[idx] & 0xFE) | payloadBits[written]
                written += 1
            }
            idx += 1
        }
        return written == payloadBits.count
    }

    /// يطلّع البايتات المخبّاة
    static func extract(from channels: [UInt8]) -> Data? {
        var readBits: [UInt8] = []
        readBits.reserveCapacity(channels.count)
        for (i, c) in channels.enumerated() where i % 4 != 3 { readBits.append(c & 1) }
        // أوّل 7 بايت = header + length
        guard readBits.count >= 56 else { return nil }
        let head = unbits(readBits[0..<56])
        guard Array(head.prefix(3)) == header else { return nil }
        let n = (Int(head[3]) << 24) | (Int(head[4]) << 16) | (Int(head[5]) << 8) | Int(head[6])
        guard n >= 0, n < 10_000_000 else { return nil }
        let need = 56 + n * 8
        guard readBits.count >= need else { return nil }
        let body = unbits(readBits[56..<need])
        return Data(body)
    }
}

// MARK: مولّد كلمات سرّ + قوّتها

struct Strength {
    let score: Int        // 0…4
    let label: String
    let crackTime: String
}

enum Pass {
    static let lowers = Array("abcdefghijkmnpqrstuvwxyz")
    static let uppers = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    static let digits = Array("23456789")
    static let symbols = Array("!@#$%^&*-_=+?")

    static func generate(length: Int, upper: Bool, digit: Bool, symbol: Bool) -> String {
        var pool = lowers
        if upper { pool += uppers }
        if digit { pool += digits }
        if symbol { pool += symbols }
        var out = ""
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<max(4, length) { out.append(pool[Int.random(in: 0..<pool.count, using: &rng)]) }
        return out
    }

    /// تقدير القوّة عبر الإنتروبي (بتّات) وأنماط شائعة
    static func rate(_ p: String) -> Strength {
        if p.isEmpty { return Strength(score: 0, label: "فارغة", crackTime: "—") }
        var pool = 0
        if p.contains(where: { $0.isLowercase && $0.isLetter }) { pool += 26 }
        if p.contains(where: { $0.isUppercase && $0.isLetter }) { pool += 26 }
        if p.contains(where: { $0.isNumber }) { pool += 10 }
        if p.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }) { pool += 20 }
        pool = max(pool, 10)
        var entropy = Double(p.count) * log2(Double(pool))
        // عقوبات: تكرار وتسلسل
        let chars = Array(p.lowercased())
        var seq = 0
        for i in 1..<max(1, chars.count) {
            if let a = chars[i - 1].asciiValue, let b = chars[i].asciiValue, b == a + 1 || b == a { seq += 1 }
        }
        if chars.count > 0 { entropy -= Double(seq) * 1.5 }
        if Set(chars).count <= 2 { entropy *= 0.4 }
        entropy = max(0, entropy)
        let score = entropy < 28 ? 0 : (entropy < 40 ? 1 : (entropy < 60 ? 2 : (entropy < 80 ? 3 : 4)))
        let labels = ["ضعيفة جدًّا", "ضعيفة", "متوسّطة", "قويّة", "قويّة جدًّا"]
        return Strength(score: score, label: labels[score], crackTime: crack(entropy))
    }
    static func crack(_ entropy: Double) -> String {
        // بافتراض 10 مليار محاولة/ثانية
        let guesses = pow(2, entropy) / 2
        let sec = guesses / 1e10
        if sec < 1 { return "لحظيّ" }
        if sec < 60 { return "\(Int(sec)) ثانية" }
        if sec < 3600 { return "\(Int(sec / 60)) دقيقة" }
        if sec < 86400 { return "\(Int(sec / 3600)) ساعة" }
        if sec < 31536000 { return "\(Int(sec / 86400)) يوم" }
        let years = sec / 31536000
        if years < 1000 { return "\(Int(years)) سنة" }
        if years < 1e6 { return "\(Int(years / 1000)) ألف سنة" }
        if years < 1e9 { return "\(Int(years / 1e6)) مليون سنة" }
        return "مليارات السنين"
    }
}
