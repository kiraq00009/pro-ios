import Foundation

var fails = 0, passes = 0
func check(_ c: Bool, _ m: String) { if c { passes += 1 } else { fails += 1; print("FAIL:", m) } }

func seg(_ a: [(Double, Double, String)]) -> [Api.Segment] { a.map { Api.Segment(s: $0.0, e: $0.1, text: $0.2) } }

var n = Note(id: UUID(), file: "a.m4a", source: "واتساب", created: Date(), duration: 120)
n.segments = seg([(0, 5, "هلا خيري شلونك"), (5, 12, "الشحنة توصل باچر العصر"), (12, 20, "السايق يريد مية وخمسين ألف"), (40, 50, "وحوّل الدفعة قبل الخميس")])
check(n.text.hasPrefix("هلا خيري"), "text join")
check(n.segmentIndex(at: 0) == 0, "idx 0")
check(n.segmentIndex(at: 6) == 1, "idx 6")
check(n.segmentIndex(at: 19.9) == 2, "idx 19.9")
check(n.segmentIndex(at: 30) == 2, "idx gap -> previous")
check(n.segmentIndex(at: 45) == 3, "idx 45")
check(n.title == "هلا خيري شلونك الشحنة توصل باچر", "title fallback: \(n.title)")
check(n.savedSeconds > 100, "saved \(n.savedSeconds)")
var empty = Note(id: UUID(), file: "b", source: "تسجيل", created: Date(), duration: 0)
check(empty.segmentIndex(at: 3) == nil, "empty idx")
check(empty.title == "بصمة تسجيل", "empty title")
empty.summary = Api.Summary(title: "اجتماع", summary: "", points: [], actions: [], engine: nil)
check(empty.title == "اجتماع", "summary title")

check(Fmt.dur(65) == "1:05", "dur 65")
check(Fmt.dur(3725) == "1:02:05", "dur hours")
check(Fmt.saved(30) == "30 ثانية" && Fmt.saved(150) == "2 دقيقة", "saved fmt")

// الملخّص المحليّ
let long = """
هلا خيري شلونك، اسمع عندي كم شغلة مهمّة بخصوص الشحنة. البضاعة توصل باچر العصر للمخزن، بس لازم واحد يكون موجود يستلم الساعة 4. السايق طلب 150 ألف دينار أجرة النقل وآني كتله زين بس بعد ما يفرّغ. وبعدين الفاتورة الجديدة ارسلتها على الواتساب، شوفها وگلّي إذا الأسعار زينة. وإذا تكدر حوّل الدفعة الثانية قبل الخميس حتى ما يتأخّر الطلب. والله كلّش تعبت اليوم. يلا مع السلامة.
"""
let s = LocalSummary.make(long)
check(!s.summary.isEmpty, "summary not empty")
check(s.points.count >= 2 && s.points.count <= 6, "points count \(s.points.count)")
check(s.engine == "device", "engine")
check(s.actions.contains { $0.contains("150") || $0.contains("ألف") }, "money action: \(s.actions)")
check(s.actions.contains { $0.contains("باچر") || $0.contains("الساعة") }, "time action: \(s.actions)")
check(s.actions.count <= 6, "actions cap")
check(LocalSummary.sentences(long).count >= 6, "sentences \(LocalSummary.sentences(long).count)")
// كلام بلا نقاط
let noPunct = Array(repeating: "كلمة", count: 70).joined(separator: " ")
check(LocalSummary.sentences(noPunct).count == 4, "chunk unpunctuated: \(LocalSummary.sentences(noPunct).count)")
check(LocalSummary.make("").summary == "", "empty summary")
check(LocalSummary.tokens("في من على الشحنة").contains("الشحنه") || LocalSummary.tokens("في من على الشحنة").contains("الشحنة"), "tokens drop stop words")
check(!LocalSummary.tokens("في من على").contains("على"), "stop words")

// البحث
var m = Note(id: UUID(), file: "c", source: "ملفّ", created: Date(), duration: 10)
m.segments = seg([(0, 3, "سعر الزعفران صار عالي")])
check(Search.match(m, "الزعفران"), "search plain")
check(Search.match(m, "زعفران"), "search partial")
check(Search.match(m, ""), "search empty")
check(!Search.match(m, "دولار"), "search miss")
m.segments = seg([(0, 3, "قیمت زعفران امروز")])
check(Search.match(m, "قيمت"), "search persian ya-insensitive")
check(Search.key("الساعة") == Search.key("الساعه"), "ta marbuta")

// الترجمة المباشرة (فكّ الردّ)
let gtx = #"[[["مرحبا ","سلام",null,null,3],["كيف حالك؟","حالت چطوره؟",null,null,3]],null,"fa",null]"#.data(using: .utf8)!
let p = Direct.parse(gtx)
check(p?.text == "مرحبا كيف حالك؟", "gtx parse: \(p?.text ?? "nil")")
check(p?.detected == "fa", "gtx detected")
check(Direct.parse(Data("oops".utf8)) == nil, "gtx bad")
check(Direct.url("x y", from: nil, to: .ku).absoluteString.contains("tl=ckb"), "kurdish code")
check(Direct.url("x", from: .fa, to: .ar).absoluteString.contains("sl=fa"), "src code")

// ترميز الملاحظة
let enc = try! JSONEncoder().encode([n])
let dec = try! JSONDecoder().decode([Note].self, from: enc)
check(dec.first?.segments.count == 4 && dec.first?.source == "واتساب", "codable roundtrip")
let srv = #"{"lang":"fa","text":"سلام","segments":[{"s":0,"e":1,"text":"سلام"}],"secs":1}"#.data(using: .utf8)!
check((try? JSONDecoder().decode(Api.Heard.self, from: srv))?.segments.first?.tr == nil, "decode heard without optional fields")
let sumJ = #"{"title":"t","summary":"s","points":["a"],"actions":[],"engine":"gemini"}"#.data(using: .utf8)!
check((try? JSONDecoder().decode(Api.Summary.self, from: sumJ))?.points == ["a"], "decode summary")

print("sada: \(passes) passed, \(fails) failed")
exit(fails == 0 ? 0 : 1)
