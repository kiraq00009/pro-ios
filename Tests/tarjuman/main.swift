import Foundation

var fails = 0, passes = 0
func check(_ c: Bool, _ m: String) { if c { passes += 1 } else { fails += 1; print("FAIL:", m) } }

// الأرقام
check(Script.latinDigits("۱۲۳٤٥") == "12345", "digits")
check(Script.digits("250", for: .fa) == "۲۵۰", "fa digits")
check(Script.toPersian("كيف حالك يا علي") == "کیف حالک یا علی", "toPersian")
check(Script.toArabic("خیلی ممنون") == "خيلي ممنون", "toArabic")
check(Script.toPersian("كَتَبَ عَلِيٌّ") == "کتب علی", "toPersian strips tashkeel: \(Script.toPersian("كَتَبَ عَلِيٌّ"))")

// تخمين اللغة
check(Script.guess("خیلی ممنون، حالت چطوره؟") == .fa, "guess fa")
check(Script.guess("شلونك شنو أخبارك اليوم") == .ar, "guess ar")
check(Script.guess("این چنده") == .fa, "guess fa short")
check(Script.guess("where is the hotel") == .en, "guess en")
check(Script.guess("Teşekkür ederim") == .tr, "guess tr")
check(Script.guess("أريد أروح إلى المطار") == .ar, "guess ar 2")

// الأرقام الفارسيّة بالكلمات
check(Money.faWords(150_000) == "صد و پنجاه هزار", "words 150k: \(Money.faWords(150_000))")
check(Money.faWords(2_500_000) == "دو میلیون و پانصد هزار", "words 2.5M: \(Money.faWords(2_500_000))")
check(Money.faWords(47) == "چهل و هفت", "words 47")
check(Money.faWords(1_000) == "یک هزار", "words 1000: \(Money.faWords(1000))")
for n in [7, 19, 99, 101, 999, 1_234, 50_000, 320_000, 1_500_000, 12_345_678] {
    check(Money.parseWords(Money.faWords(n)) == Double(n), "roundtrip \(n): \(Money.faWords(n)) -> \(String(describing: Money.parseWords(Money.faWords(n))))")
}
check(Money.parseWords("۵۰ هزار") == 50_000, "50 hezar")
check(Money.parseWords("2 میلیون") == 2_000_000, "2 million")
check(Money.parseWords("پونصد تومن") == 500, "colloquial 500")

// قراءات السعر
let r1 = Money.readings("۵۰ تومن")
check(r1.first?.toman == 50_000 && r1.first?.likely == true, "50 toman street = 50k")
let r2 = Money.readings("۵۰۰۰۰۰ ریال")
check(r2.first?.toman == 50_000, "rial /10")
let r3 = Money.readings("۲۰۰ هزار تومان")
check(r3.first?.toman == 200_000, "200k toman")
check(Money.readings("سلام").isEmpty, "no number")

// التحويل
let rates = Rates(tomanPerUSD: 100_000, iqdPerUSD: 1_500)
check(abs(rates.toIQD(toman: 100_000) - 1_500) < 0.001, "toman->iqd")
check(abs(rates.toToman(iqd: 15_000) - 1_000_000) < 0.001, "iqd->toman")
check(Money.streetSay(toman: 50_000) == "پنجاه تومن", "street 50k: \(Money.streetSay(toman: 50_000))")
check(Money.streetSay(toman: 1_500_000) == "یک و نیم میلیون تومن", "street 1.5M: \(Money.streetSay(toman: 1_500_000))")
check(Money.streetSay(toman: 1_200_000) == "یک میلیون و دویست هزار تومان", "street 1.2M: \(Money.streetSay(toman: 1_200_000))")

// العبارات
check(Phrases.all.count >= 120, "phrases count \(Phrases.all.count)")
for c in Phrases.cats { check(Phrases.of(c.id).count >= 5, "cat \(c.id) has phrases") }
check(Set(Phrases.all.map { $0.cat }).isSubset(of: Set(Phrases.cats.map { $0.id })), "all cats known")
check(!Phrases.search("ممنون").isEmpty, "search fa")
check(!Phrases.search("مستشفى").isEmpty, "search ar")
check(!Phrases.search("خيلي").isEmpty, "search mixed ya")
for p in Phrases.all { check(!p.ar.isEmpty && !p.fa.isEmpty && !p.say.isEmpty, "phrase \(p.id) complete") }
// الفارسيّ بالعبارات لازم يكون بحروف فارسيّة (ی لا ي)
for p in Phrases.all { check(!p.fa.contains("ي") && !p.fa.contains("ك"), "phrase \(p.id) uses Persian letters: \(p.fa)") }

// المحادثة
check(Convo.target(heard: .fa, pair: (.ar, .fa)) == .ar, "fa -> ar")
check(Convo.target(heard: .ar, pair: (.ar, .fa)) == .fa, "ar -> fa")
check(Convo.target(heard: .en, pair: (.ar, .fa)) == .fa, "other -> second")

// بناء الطلب
let req = Api.request("/talk", query: ["to": "fa", "from": "ar"], body: Data([1, 2]), type: "audio/mp4", base: Api.bases[0])
check(req.url?.absoluteString == "https://dawwirli.watch/proapi/talk?from=ar&to=fa", "url \(req.url?.absoluteString ?? "")")
check(req.value(forHTTPHeaderField: "X-Key") == Api.key, "key header")
let talkJSON = #"{"lang":"fa","heard":"سلام","translated":"مرحبا","engine":"nllb"}"#.data(using: .utf8)!
check((try? JSONDecoder().decode(Api.Talk.self, from: talkJSON))?.translated == "مرحبا", "decode talk")
let heardJSON = #"{"lang":"ar","text":"هلا","segments":[{"s":0,"e":1.2,"text":"هلا","words":[{"s":0,"e":0.5,"w":"هلا"}]}],"secs":1.2}"#.data(using: .utf8)!
check((try? JSONDecoder().decode(Api.Heard.self, from: heardJSON))?.segments.first?.words?.count == 1, "decode heard")

print("tarjuman: \(passes) passed, \(fails) failed")
exit(fails == 0 ? 0 : 1)
