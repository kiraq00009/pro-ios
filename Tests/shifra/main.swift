import Foundation
import CryptoKit

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── التشفير: ذهاب وإياب
for (text, pass) in [("مرحبا خيري 👋", "سرّي123"), ("hello world", "p@ss"), ("", "x"), (String(repeating: "أ", count: 2000), "طويل")] {
    let blob = Crypto.encrypt(text, pass: pass)!
    check(Crypto.looksEncrypted(blob), "has markers")
    check(Crypto.decrypt(blob, pass: pass) == text, "round trip: \(text.prefix(10))")
    check(Crypto.decrypt(blob, pass: "غلط") == nil, "wrong pass fails")
}
// كلمة سرّ فارغة ما تشفّر
check(Crypto.encrypt("x", pass: "") == nil, "empty pass rejected")
// كلّ تشفير يطلع مختلف (ملح + nonce)
let a = Crypto.encrypt("same", pass: "k")!, b = Crypto.encrypt("same", pass: "k")!
check(a != b, "salt/nonce randomized")
check(Crypto.decrypt(a, pass: "k") == "same" && Crypto.decrypt(b, pass: "k") == "same", "both decrypt")
// يفكّ حتى لو ملصوق بين كلام
let wrapped = "شوف هاي الرسالة:\n\n" + Crypto.encrypt("خبر", pass: "k")! + "\n\nردّ عليّ"
check(Crypto.decrypt(wrapped, pass: "k") == "خبر", "extracts from surrounding text")
// تعديل حرف يكسر الفكّ (سلامة)
var tamper = Array(Crypto.encryptRaw("secret", pass: "k")!)
tamper[tamper.count - 1] ^= 0xFF
check(Crypto.decryptRaw(Data(tamper), pass: "k") == nil, "tamper detected (GCM)")
// نصّ عشوائيّ مو شفرة
check(Crypto.decrypt("مجرّد كلام عاديّ", pass: "k") == nil, "plain text not decryptable")

// ── الإخفاء داخل صورة
func canvas(_ pixels: Int) -> [UInt8] {
    var c = [UInt8](repeating: 0, count: pixels * 4)
    var s: UInt64 = 7
    for i in 0..<c.count { s = s &* 6364136223846793005 &+ 1; c[i] = UInt8((s >> 33) & 0xFF); if i % 4 == 3 { c[i] = 255 } }
    return c
}
check(Stego.capacity(pixels: 1000) == 1000 * 3 / 8 - 7, "capacity formula")
for (text, px) in [("سرّ مخفي", 4000), ("hi", 500), (String(repeating: "x", count: 500), 4000)] {
    var ch = canvas(px)
    let data = Data(text.utf8)
    let ok = Stego.embed(into: &ch, data: data)
    check(ok, "embed \(text.prefix(5))")
    let out = Stego.extract(from: ch)
    check(out == data && String(data: out ?? Data(), encoding: .utf8) == text, "stego round trip \(text.prefix(5))")
    // ألفا ما تتغيّر
    check(stride(from: 3, to: ch.count, by: 4).allSatisfy { ch[$0] == 255 }, "alpha untouched")
}
// ما يكفي مكان
var small = canvas(20)
check(!Stego.embed(into: &small, data: Data(repeating: 1, count: 100)), "too small fails")
// صورة بلا رسالة = ما أكو ناتج (توقيع غلط غالبًا)
let blank = [UInt8](repeating: 128, count: 4000)
let ex = Stego.extract(from: blank)
check(ex == nil || ex!.count < 10_000_000, "blank image safe")
// صورة بيها رسالة مشفّرة ثمّ مخبّاة (الاستعمال الحقيقيّ)
var ph = canvas(8000)
let enc = Crypto.encryptRaw("لقاء الساعة ٩", pass: "code")!
check(Stego.embed(into: &ph, data: enc), "embed encrypted")
let got = Stego.extract(from: ph)!
check(Crypto.decryptRaw(got, pass: "code") == "لقاء الساعة ٩", "extract+decrypt")

// ── مولّد وقوّة كلمة السرّ
for _ in 0..<50 {
    let p = Pass.generate(length: 16, upper: true, digit: true, symbol: true)
    check(p.count == 16, "generated length")
    check(Pass.rate(p).score >= 3, "generated is strong: \(p) -> \(Pass.rate(p).score)")
}
check(Pass.rate("123456").score == 0 && Pass.rate("password").score <= 1, "weak passwords rated low")
check(Pass.rate("aaaaaaaa").score == 0, "repeated chars weak")
check(Pass.rate("Tr0ub4dour&3xplosion!").score == 4, "complex long strong")
check(Pass.rate("").score == 0, "empty")
check(Pass.generate(length: 12, upper: false, digit: false, symbol: false).allSatisfy { Pass.lowers.contains($0) }, "lowercase only pool")
let crack = Pass.rate("Xk9#mPq2$wZ7!vL4").crackTime
check(!crack.isEmpty && crack != "لحظيّ", "strong pass long crack time: \(crack)")

print(failures == 0 ? "ALL SHIFRA TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
