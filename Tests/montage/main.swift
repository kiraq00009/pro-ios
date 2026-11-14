import Foundation

var fails = 0, passes = 0
func check(_ c: Bool, _ m: String) { if c { passes += 1 } else { fails += 1; print("FAIL:", m) } }

func words(_ t: String, _ s: Double, _ step: Double) -> [Api.Word] {
    t.split(separator: " ").enumerated().map { i, w in Api.Word(s: s + Double(i) * step, e: s + Double(i + 1) * step, w: String(w)) }
}

// تقسيم المقاطع
let short = Api.Segment(s: 0, e: 2, text: "Hello there", words: words("Hello there", 0, 1), tr: "هلا")
let longText = "This is a very long sentence that keeps going and going for quite a while longer"
let long = Api.Segment(s: 2, e: 12, text: longText, words: words(longText, 2, 0.6))
let cues = Subs.cues(from: [short, long])
check(cues.first?.tr == "هلا", "keeps server translation")
check(cues.count >= 3, "long segment split: \(cues.count)")
check(cues.allSatisfy { $0.text.count <= 45 }, "cue length")
check(cues.dropFirst().allSatisfy { $0.e - $0.s <= 6.1 }, "cue duration")
check(zip(cues, cues.dropFirst()).allSatisfy { $0.0.e <= $0.1.s }, "no overlap")
check(cues.map(\.text).joined(separator: " ") == "Hello there " + longText, "no words lost")
check(Subs.cues(from: [Api.Segment(s: 0, e: 1, text: "  ")]).isEmpty, "drops empty")
let tiny = Subs.cues(from: [Api.Segment(s: 3, e: 3.1, text: "Hi")])
check(tiny.first.map { $0.e - $0.s >= 0.79 } == true, "min duration")

// التداخل
let ov = Subs.fixOverlaps([Cue(s: 0, e: 3, text: "a"), Cue(s: 2, e: 4, text: "b")])
check(ov[0].e <= ov[1].s, "overlap fixed")

// التفاف السطر
check(Subs.wrap("قصير") == ["قصير"], "wrap short")
let w2 = Subs.wrap("هذي جملة طويلة شوية حتى تنقسم على سطرين متوازنين")
check(w2.count == 2 && abs(w2[0].count - w2[1].count) <= 8, "wrap balanced: \(w2)")

// تيك توك
let c = Cue(s: 0, e: 3, text: "one two three four five", tr: "واحد اثنين ثلاثة أربعة خمسة", words: words("one two three four five", 0, 0.6))
let ch = Subs.chunks(c, per: 2, translated: false)
check(ch.count == 3 && ch[0].words == ["one", "two"] && ch[2].words == ["five"], "chunks original")
check(ch[0].starts == [0, 0.6], "chunk word starts")
check(abs(ch[0].e - 1.2) < 0.001, "chunk ends at next chunk start")
let cht = Subs.chunks(c, per: 3, translated: true)
check(cht.count == 2 && cht[0].words.count == 3, "chunks translated")
check(abs(cht.first!.s - 0) < 0.001 && abs(cht.last!.e - 3) < 0.001, "translated span covers cue")
check(cht.flatMap(\.starts) == cht.flatMap(\.starts).sorted(), "starts ascending")
check(Subs.chunks(Cue(s: 0, e: 1, text: ""), per: 3, translated: true).isEmpty, "empty chunks")
check(Subs.chunks(c, per: 99, translated: false).count == 1, "per clamp")

// SRT
check(Subs.stamp(3725.5) == "01:02:05,500", "stamp \(Subs.stamp(3725.5))")
check(Subs.parseStamp("01:02:05,500") == 3725.5, "parse stamp")
let srt = Subs.srt([c, Cue(s: 4, e: 5.5, text: "six")], mode: .translation)
check(srt.hasPrefix("1\n00:00:00,000 --> 00:00:03,000\nواحد"), "srt head")
check(srt.contains("2\n00:00:04,000 --> 00:00:05,500\nsix"), "srt fallback to original when no tr")
let back = Subs.parseSRT(srt)
check(back.count == 2 && back[1].s == 4 && back[1].text == "six", "srt roundtrip")
check(Subs.srt([c], mode: .both).contains("واحد اثنين ثلاثة أربعة خمسة\none two"), "srt both")

// السطر الحاليّ
let list = [Cue(s: 0, e: 1, text: "a"), Cue(s: 2, e: 3, text: "b"), Cue(s: 5, e: 8, text: "c")]
check(Subs.active(list, at: 0.5)?.text == "a", "active a")
check(Subs.active(list, at: 1.5) == nil, "gap none")
check(Subs.active(list, at: 7)?.text == "c", "active c")
check(Subs.active([], at: 1) == nil, "empty active")

// الإزاحة
let sh = Subs.shift(list, by: -0.5)
check(sh[0].s == 0 && sh[1].s == 1.5, "shift clamps at zero")

// الستايل
var st = Style()
check(st.fontSize(videoWidth: 1080) == 76, "tiktok font \(st.fontSize(videoWidth: 1080))")
st.look = .cinema; st.size = 1.5
check(st.fontSize(videoWidth: 1000) == 63, "cinema font")
check(Place.bottom.y > Place.middle.y && Place.middle.y > Place.top.y, "places ordered")
check(c.shown(.original) == c.text && c.shown(.translation) == c.tr, "shown")
let enc = try! JSONEncoder().encode(Style())
check((try? JSONDecoder().decode(Style.self, from: enc)) == Style(), "style codable")

print("montage: \(passes) passed, \(fails) failed")
exit(fails == 0 ? 0 : 1)
