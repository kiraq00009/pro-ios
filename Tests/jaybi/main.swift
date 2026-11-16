import Foundation

var failures = 0
var passed = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) {
    if ok { passed += 1 } else { failures += 1; print("FAIL:", msg()) }
}
func amt(_ s: String) -> Double? { SpeechParse.parse(s).amount }

// ——— الأرقام المنطوقة ———
check(amt("صرفت خمسة وعشرين ألف على العشا") == 25000, "خمسة وعشرين ألف = \(String(describing: amt("صرفت خمسة وعشرين ألف على العشا")))")
check(amt("عشرة آلاف تكسي") == 10000, "عشرة آلاف")
check(amt("ربع مليون ايجار") == 250000, "ربع مليون")
check(amt("نص مليون") == 500000, "نص مليون")
check(amt("مليون ونص سيارة") == 1500000, "مليون ونص")
check(amt("الف ونص چاي") == 1500, "الف ونص")
check(amt("ميتين وخمسين الف") == 250000, "ميتين وخمسين الف")
check(amt("مية الف") == 100000, "مية الف")
check(amt("خمس مية دينار خبز") == 500, "خمس مية = \(String(describing: amt("خمس مية دينار خبز")))")
check(amt("خمسمية دينار") == 500, "خمسمية")
check(amt("الفين وخمسمية بنزين") == 2500, "الفين وخمسمية")
check(amt("ثلاث تالاف رصيد") == 3000, "ثلاث تالاف")
check(amt("ثلاث الاف وخمسمية") == 3500, "ثلاث الاف وخمسمية")
check(amt("مليون وميتين الف") == 1200000, "مليون وميتين الف")
check(amt("خمسطعش الف") == 15000, "خمسطعش الف")
check(amt("25 ألف عشا") == 25000, "25 ألف")
check(amt("25الف") == 25000, "25الف ملتصقة")
check(amt("٢٥ ألف") == 25000, "أرقام هنديّة")
check(amt("12,500 سوبرماركت") == 12500, "12,500")
check(amt("2.5 مليون") == 2500000, "2.5 مليون")
check(amt("دفعت 8000 تكسي") == 8000, "8000")
check(amt("ب25 الف") == 25000, "ب25 الف")
check(amt("شاورما وحده بخمسة الاف") == 5000, "الأكبر يفوز: \(String(describing: amt("شاورما وحده بخمسة الاف")))")
check(amt("تكسي") == nil, "بلا رقم = nil")
check(amt("نص كيلو لحم") == nil, "نص لوحدها مو رقم")
check(amt("عشرين دولار") == 20, "عشرين")
check(amt("مية وخمسين الف") == 150000, "مية وخمسين الف")

// ——— الأصناف ———
func cat(_ s: String) -> String { SpeechParse.parse(s).cat }
check(cat("صرفت خمسة وعشرين ألف على العشا ويّا الربع") == "food", "عشا = أكل")
check(cat("تكسي للدوام 8 الاف") == "transport", "تكسي = مواصلات")
check(cat("عبيت بنزين بعشرين الف") == "fuel", "بنزين")
check(cat("رصيد زين خمس تالاف") == "bills", "رصيد = فواتير")
check(cat("اغراض للبيت من الماركت") == "market", "للبيت/الماركت = سوبرماركت: \(cat("اغراض للبيت من الماركت"))")
check(cat("قهوة ويا صديقي") == "coffee", "قهوة")
check(cat("دواء من الصيدلية") == "health", "صيدلية = صحّة")
check(cat("هدية عيد ميلاد") == "gifts", "هدية")
check(cat("قاط جديد") == "shopping", "قاط = ملابس")
check(cat("شي ما معروف ميه الف") == "other", "غير معروف = غيرها")
check(cat("بالمطعم 40 الف") == "food", "بالمطعم ← مطعم")
check(cat("شريت شاورمتين") == "food", "شاورمتين ← بادئة شاورم")

// ——— الملاحظة واليوم ———
let d1 = SpeechParse.parse("صرفت خمسة وعشرين ألف على العشا ويّا الربع")
check(d1.note == "العشا ويّا الربع", "الملاحظة: '\(d1.note)'")
check(d1.dayOffset == 0, "اليوم")
check(SpeechParse.parse("امس دفعت عشرة الاف تكسي").dayOffset == -1, "امس")
check(SpeechParse.parse("البارحة رصيد").dayOffset == -1, "البارحة")
check(SpeechParse.parse("اول امس غدا").dayOffset == -2, "اول امس")
check(SpeechParse.parse("خمسة الاف").note == "غيرها", "ملاحظة فاضية ← اسم الصنف: \(SpeechParse.parse("خمسة الاف").note)")

// ——— التطبيع ———
check(AR.norm("أإآ") == "ااا", "توحيد الألف")
check(AR.norm("مدرسة") == "مدرسه", "التاء المربوطة")
check(AR.norm("١٢٣") == "123", "أرقام هنديّة")
check(AR.norm("گچ") == "كج", "گ وچ")
check(AR.splitDigits("25الف") == "25 الف", "فصل الأرقام")
check(AR.splitDigits("12,500دينار") == "12,500 دينار", "فصل مع فاصلة")

// ——— الوصولات ———
check(Receipt.numbers(in: "المجموع 12,500") == [12500], "12,500")
check(Receipt.numbers(in: "Total: 3.75") == [3.75], "3.75")
check(Receipt.numbers(in: "١٢٬٥٠٠ د.ع") == [12500], "أرقام هنديّة بالوصل")
check(Receipt.numbers(in: "1,234.50") == [1234.5], "فاصلتين")
check(Receipt.numbers(in: "12.500") == [12500], "نقطة آلاف")
check(Receipt.numbers(in: "07701234567") == [], "تلفون يتجاهل")

let r1 = Receipt.parse([
    "سوبرماركت النخلة",
    "فاتورة رقم 4471",
    "حليب x2 ........ 3,000",
    "خبز ............ 1,000",
    "رز 5 كغ ........ 6,500",
    "بيض ............ 2,000",
    "المجموع ...... 12,500",
    "نقدا 15,000",
    "الباقي 2,500",
    "شكرا لزيارتكم",
])
check(r1.total == 12500, "مجموع الوصل = \(String(describing: r1.total))")
check(r1.merchant == "سوبرماركت النخلة", "المحلّ = '\(r1.merchant)'")
check(r1.items.count == 4, "4 مواد = \(r1.items.count)")
check(r1.items.first?.price == 3000, "سعر الحليب")
check(Receipt.itemName("رز 5 كغ ........ 6,500") == "رز 5 كغ", "اسم مادّة بكمّيّة: '\(Receipt.itemName("رز 5 كغ ........ 6,500"))'")
check(Receipt.itemName("حليب x2 ........ 3,000") == "حليب x2", "حليب x2")
check(Num.groups(SpeechParse.tokens("نص الف").norm) == [500], "نص الف = 500")
check(r1.cat == "market", "صنف الوصل = \(r1.cat)")

let r2 = Receipt.parse([
    "BURGER HOUSE",
    "Tel 0770 123 4567",
    "Classic Burger 9,000",
    "Fries 3,000",
    "Pepsi 1,500",
    "Subtotal 13,500",
    "Service 1,350",
    "TOTAL 14,850",
    "CASH 20,000",
])
check(r2.total == 14850, "TOTAL بالإنكليزي = \(String(describing: r2.total))")
check(r2.merchant == "BURGER HOUSE", "محلّ إنكليزي = \(r2.merchant)")
check(r2.cat == "food", "برگر = أكل: \(r2.cat)")

let r3 = Receipt.parse(["صيدلية الشفاء", "باراسيتامول 2,000", "فيتامين د 8,000"])
check(r3.total == 8000, "بلا كلمة مجموع ← أكبر رقم = \(String(describing: r3.total))")
check(r3.cat == "health", "صيدلية = صحّة: \(r3.cat)")

let r4 = Receipt.parse(["الإجمالي", "45,000"])
check(r4.total == 45000, "المجموع بالسطر الجاي")

// ——— الإحصاءات ———
var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h)) ?? Date()
}
let xs: [Expense] = [
    Expense(amount: 10000, cat: "food", note: "a", date: day(2026, 11, 1), via: .voice),
    Expense(amount: 20000, cat: "food", note: "b", date: day(2026, 11, 5), via: .type),
    Expense(amount: 5000, cat: "transport", note: "c", date: day(2026, 11, 5), via: .scan),
    Expense(amount: 30000, cat: "market", note: "d", date: day(2026, 11, 10), via: .type),
    Expense(amount: 9000, cat: "food", note: "e", date: day(2026, 10, 3), via: .type),
    Expense(amount: 50000, cat: "market", note: "f", date: day(2026, 10, 8), via: .type),
    Expense(amount: 7000, cat: "transport", note: "g", date: day(2026, 10, 20), via: .type),
    Expense(amount: 99999, cat: "fun", note: "h", date: day(2026, 12, 1), via: .type),
]
let nov = Stats.inMonth(xs, day(2026, 11, 10), cal)
check(nov.count == 4, "تشرين الثاني 4 مصاريف = \(nov.count)")
check(Stats.sum(nov) == 65000, "مجموع الشهر")
check(Stats.byCat(nov).first == CatSum(cat: "food", total: 30000), "أكبر صنف أكل")
check(Stats.byCat(nov).count == 3, "3 أصناف")
check(Stats.inDay(xs, day(2026, 11, 5, 20), cal).count == 2, "مصاريف يوم 5")
let dl = Stats.daily(xs, day(2026, 11, 10), cal)
check(dl.count == 30 && dl[4] == 25000 && dl[0] == 10000, "يوميّ")
check(Stats.daysInMonth(day(2026, 2, 3), cal) == 28, "شباط 28")
check(Stats.dailyAvg(spent: 65000, day: 10) == 6500, "المعدّل")
check(Stats.runOutDay(budget: 100000, spent: 65000, day: 10, daysInMonth: 30) == 15, "تخلص يوم 15 = \(String(describing: Stats.runOutDay(budget: 100000, spent: 65000, day: 10, daysInMonth: 30)))")
check(Stats.runOutDay(budget: 1000000, spent: 65000, day: 10, daysInMonth: 30) == nil, "ما تخلص")
check(Stats.runOutDay(budget: 50000, spent: 65000, day: 10, daysInMonth: 30) == 10, "خلصت")
check(Stats.runOutDay(budget: 0, spent: 65000, day: 10, daysInMonth: 30) == nil, "بلا ميزانيّة")
let ins = Stats.biggestRise(xs, now: day(2026, 11, 10), cal, minBase: 1000)
check(ins?.cat == "food", "الأكل زاد: \(String(describing: ins))")
check(ins?.pct == 233, "نسبة الزيادة 233٪ = \(String(describing: ins?.pct))")
let csv = Stats.csv(Array(xs.prefix(2)), cur: "د.ع")
check(csv.hasPrefix("\u{FEFF}التاريخ"), "CSV يبدي بالعنوان")
check(csv.contains(",10000,د.ع,أكل ومطاعم,a,صوت"), "سطر CSV")
check(Cats.get("nope").id == "other", "صنف مجهول ← غيرها")
check(Set(Cats.all.map { $0.id }).count == Cats.all.count, "معرّفات الأصناف فريدة")

print("jaybi: \(passed) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
