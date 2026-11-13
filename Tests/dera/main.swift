import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── TOTP: متّجهات الاختبار الرسميّة (RFC 6238، SHA1، المفتاح "12345678901234567890")
let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
check(Sec.base32(secret) == Data("12345678901234567890".utf8), "base32 decode")
check(Sec.totp(secret: secret, at: 59, digits: 8) == "94287082", "totp T=59: \(Sec.totp(secret: secret, at: 59, digits: 8) ?? "nil")")
check(Sec.totp(secret: secret, at: 1111111109, digits: 8) == "07081804", "totp T=1111111109")
check(Sec.totp(secret: secret, at: 1234567890, digits: 8) == "89005924", "totp T=1234567890")
check(Sec.totp(secret: secret, at: 2000000000, digits: 8) == "69279037", "totp T=2000000000")
check(Sec.totp(secret: secret, at: 59) == "287082", "totp 6 digits")
check(Sec.totp(secret: "gezd gnbv-gy3t qojq", at: 59) != nil, "base32 tolerates spaces/dashes/lowercase")
check(Sec.totp(secret: "not base32 !!", at: 59) == nil, "bad secret rejected")

// ── روابط otpauth
if let a = Sec.parseOTP("otpauth://totp/GitHub:me%40mail.com?secret=jbswy3dpehpk3pxp&issuer=GitHub&digits=6&period=30") {
    check(a.issuer == "GitHub" && a.name == "me@mail.com" && a.secret == "JBSWY3DPEHPK3PXP", "otpauth parse: \(a)")
} else { check(false, "otpauth nil") }
check(Sec.parseOTP("otpauth://totp/Acme?secret=JBSWY3DPEHPK3PXP")?.issuer == "Acme", "otpauth label only")
check(Sec.parseOTP("https://example.com") == nil && Sec.parseOTP("otpauth://totp/x?secret=!!!") == nil, "otpauth rejects")

// ── SHA1 وفحص التسريب
let h = Sec.sha1("password")
check(h == "5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8", "sha1: \(h)")
check(Sec.pwnedCount(rangeBody: "003D68EB55068C33ACE09247EE4C639306B:3\r\n1E4C9B93F3F0682250B6CF8331B7EE68FD8:9545824\r\nFFF:1", hash: h) == 9545824, "pwned range match")
check(Sec.pwnedCount(rangeBody: "AAA:1\nBBB:2", hash: h) == 0, "pwned no match")

// ── قوّة كلمة السرّ
let weak = ["123456", "password", "qwerty123", "P@ssw0rd", "aaaaaaaa", "11111111", "abc123", "iloveyou2024"]
for w in weak { check(Sec.strength(w).score <= 1, "should be weak: \(w) → \(Sec.strength(w).score) bits \(Sec.strength(w).bits)") }
let strong = ["x7#Kq9!mZ2@pLw4$", "correct-horse-battery-staple-92", "Tr0ub4dor&3xQ!vN8zRm"]
for w in strong { check(Sec.strength(w).score >= 3, "should be strong: \(w) → \(Sec.strength(w).score) bits \(Sec.strength(w).bits)") }
check(Sec.strength("").score == 0 && Sec.strength("").issues.isEmpty, "empty")
check(Sec.strength("qwertyui").issues.contains { $0.contains("تسلسل") }, "detects keyboard sequence")
check(Sec.strength("987654").issues.contains { $0.contains("تسلسل") }, "detects reversed sequence")
check(Sec.strength("x7#Kq9!mZ2@pLw4$").issues.isEmpty, "no issues for strong: \(Sec.strength("x7#Kq9!mZ2@pLw4$").issues)")
check(Sec.strength("abcdefgh12").score < Sec.strength("x7#Kq9!mZ2").score, "ordering")
check(Sec.crackTime(10) == "أقلّ من ثانية" && Sec.crackTime(200) == "أكثر من مليار سنة", "crack time ends")

// ── المولّد
var rng = SystemRandomNumberGenerator()
for len in [4, 12, 24, 64] {
    let p = Sec.generate(length: len, upper: true, digits: true, symbols: true, readable: false, using: &rng)
    check(p.count == len, "gen length \(len) got \(p.count)")
    check(p.contains { $0.isUppercase } && p.contains { $0.isLowercase } && p.contains { $0.isNumber } && p.contains { !$0.isLetter && !$0.isNumber }, "gen has all classes: \(p)")
}
let r = Sec.generate(length: 40, upper: true, digits: true, symbols: false, readable: true, using: &rng)
check(!r.contains { "lIO01".contains($0) }, "readable avoids lookalikes: \(r)")
check(Sec.generate(length: 16, upper: false, digits: false, symbols: false, readable: false, using: &rng).allSatisfy { $0.isLowercase }, "gen lowercase only")
check(Sec.strength(Sec.generate(length: 16, upper: true, digits: true, symbols: true, readable: false, using: &rng)).score >= 3, "generated is strong")
let pp = Sec.passphrase(words: 4, using: &rng)
check(pp.split(separator: "-").count == 4 && pp.contains { $0.isNumber } && pp.contains { $0.isUppercase }, "passphrase: \(pp)")
check(Sec.strength(pp).score >= 3, "passphrase strong: \(pp) \(Sec.strength(pp).bits)")

// ── الروابط
func verdict(_ u: String) -> Int { Sec.analyze(u)?.verdict ?? -1 }
for ok in ["https://www.google.com/search?q=x", "apple.com", "https://github.com/login", "https://en.wikipedia.org/wiki/Phishing", "https://accounts.google.com/signin"] {
    check(verdict(ok) == 0, "should be clean: \(ok) → \(Sec.analyze(ok)?.flags.map { $0.text } ?? [])")
}
for bad in ["http://paypa1.com/login", "https://google.com.secure-login.xyz/verify", "https://faceb00k.com", "http://192.168.4.20/bank", "https://apple.com@evil.top/id",
            "https://xn--pple-43d.com", "https://paypal-support-center.com/update", "https://gooogle.com"] {
    check(verdict(bad) == 2, "should be dangerous: \(bad) → \(verdict(bad)) \(Sec.analyze(bad)?.flags.map { $0.text } ?? [])")
}
check(verdict("https://bit.ly/3xYz") == 1, "shortener is a warning")
check(verdict("http://example.org/page") == 1, "plain http is a warning")
check(Sec.analyze("") == nil && Sec.analyze("not a url") == nil, "garbage rejected")
check(Sec.analyze("https://WWW.Example.com/a")?.host == "example.com", "host normalized")
check(Sec.edit("kitten", "sitting") == 3 && Sec.edit("", "abc") == 3 && Sec.edit("same", "same") == 0, "edit distance")

print(failures == 0 ? "ALL DERA TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
