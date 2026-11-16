import Foundation

var failures = 0
var checks = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) {
    checks += 1
    if !ok { failures += 1; print("FAIL: " + msg()) }
}
func near(_ a: Double, _ b: Double, _ eps: Double = 1e-6) -> Bool { abs(a - b) <= eps }

let NOW = 1_800_000_000.0
let DAY = 86400.0

// ── تنسيق الأحجام بالعربيّ
check(FZFormat.size(0) == "0 بايت", "0 bytes: \(FZFormat.size(0))")
check(FZFormat.size(512) == "512 بايت", "512 bytes")
check(FZFormat.size(1500) == "2 كيلو", "1.5k rounds: \(FZFormat.size(1500))")
check(FZFormat.size(820_000) == "820 كيلو", "820 kilo")
check(FZFormat.size(1_000_000) == "1 ميغا", "1 MB: \(FZFormat.size(1_000_000))")
check(FZFormat.size(2_500_000) == "2.5 ميغا", "2.5 MB: \(FZFormat.size(2_500_000))")
check(FZFormat.size(45_000_000) == "45 ميغا", "45 MB")
check(FZFormat.size(999_400_000) == "999 ميغا", "999 MB stays MB: \(FZFormat.size(999_400_000))")
check(FZFormat.size(999_960_000) == "1 غيغا", "rolls to GB: \(FZFormat.size(999_960_000))")
check(FZFormat.size(3_200_000_000) == "3.2 غيغا", "3.2 GB: \(FZFormat.size(3_200_000_000))")
check(FZFormat.size(12_000_000_000) == "12 غيغا", "12 GB")
check(FZFormat.size(150_000_000_000) == "150 غيغا", "150 GB")
check(FZFormat.size(-5) == "0 بايت", "negative clamps")
check(FZFormat.sizeParts(7_430_000_000).0 == "7.4" && FZFormat.sizeParts(7_430_000_000).1 == "غيغا", "parts")
check(FZFormat.photos(1) == "صورة واحدة" && FZFormat.photos(2) == "صورتان" && FZFormat.photos(7) == "7 صور" && FZFormat.photos(40) == "40 صورة", "photo plurals")
check(FZFormat.items(0) == "ولا عنصر" && FZFormat.items(11) == "11 عنصر", "item plurals")
check(FZFormat.days(3) == "3 أيّام" && FZFormat.days(14) == "14 يومًا", "day plurals")
check(FZFormat.duration(65) == "1:05", "duration m:ss \(FZFormat.duration(65))")
check(FZFormat.duration(3725) == "1:02:05", "duration h:mm:ss \(FZFormat.duration(3725))")
check(FZFormat.duration(9.6) == "0:10", "duration rounds")
check(FZFormat.thousands(12480) == "12,480" && FZFormat.thousands(999) == "999" && FZFormat.thousands(1_000_000) == "1,000,000", "thousands")
check(FZFormat.percent(0.634) == "63٪", "percent")

// ── لابلاس والتشويش
let flat = [Double](repeating: 120, count: 64)
check(FZBlur.laplacianVariance(flat, width: 8, height: 8) == 0, "flat image has zero variance")
var grad = [Double]()
for y in 0..<8 { for x in 0..<8 { grad.append(Double(x * 2 + y)) } }
check(near(FZBlur.laplacianVariance(grad, width: 8, height: 8), 0), "linear gradient: laplacian is zero")
check(FZBlur.laplacian(grad, width: 8, height: 8).count == 36, "interior size (w-2)(h-2)")
var spike = [Double](repeating: 0, count: 25); spike[12] = 100
let lap = FZBlur.laplacian(spike, width: 5, height: 5)
check(lap.count == 9 && lap[4] == -400 && lap[1] == 100 && lap[0] == 0, "spike laplacian: \(lap)")
check(near(FZBlur.laplacianVariance(spike, width: 5, height: 5), 200000.0 / 9.0, 1e-6), "spike variance")
var checker = [Double]()
for y in 0..<8 { for x in 0..<8 { checker.append((x + y) % 2 == 0 ? 255 : 0) } }
let vChecker = FZBlur.laplacianVariance(checker, width: 8, height: 8)
check(near(vChecker, 1020.0 * 1020.0), "checkerboard variance = 1020²: \(vChecker)")
let blurred = FZBlur.boxBlur(checker, width: 8, height: 8, radius: 1)
let vBlurred = FZBlur.laplacianVariance(blurred, width: 8, height: 8)
check(vBlurred < vChecker / 10, "box blur kills edges: \(vBlurred)")
check(FZBlur.boxBlur(flat, width: 8, height: 8, radius: 2) == flat, "blur of flat is flat")
// صورة عشوائيّة حادّة vs نفس الصورة مموّهة مرّتين
var rr = FZRand(11)
var noise = [Double]()
for _ in 0..<(32 * 32) { noise.append(Double(rr.int(0, 255))) }
let vn = FZBlur.laplacianVariance(noise, width: 32, height: 32)
let vn2 = FZBlur.laplacianVariance(FZBlur.boxBlur(FZBlur.boxBlur(noise, width: 32, height: 32, radius: 2), width: 32, height: 32, radius: 2), width: 32, height: 32)
check(vn > 1000 && vn2 < vn / 20, "noise sharp vs blurred: \(vn) \(vn2)")
check(FZBlur.laplacianVariance([UInt8](repeating: 9, count: 4), width: 2, height: 2) == 0, "too small image ⇒ 0")
let u8: [UInt8] = checker.map { UInt8($0) }
check(near(FZBlur.laplacianVariance(u8, width: 8, height: 8), vChecker), "UInt8 overload matches")
check(FZBlur.mean(u8) == 127.5, "mean of checker")
let g = FZBlur.gray(rgba: [255, 0, 0, 255, 255, 255, 255, 255, 0, 0, 0, 255], width: 3, height: 1)
check(g == [76, 255, 0], "luma gray: \(g)")
check(FZBlur.gray(rgba: [1, 2, 3], width: 1, height: 1).isEmpty, "short rgba buffer ⇒ empty")
check(FZBlur.isBlurry(FZBlur.Reading(variance: 20, brightness: 120), threshold: 75), "low variance = blurry")
check(!FZBlur.isBlurry(FZBlur.Reading(variance: 20, brightness: 8), threshold: 75), "very dark is not judged")
check(!FZBlur.isBlurry(FZBlur.Reading(variance: 300, brightness: 120), threshold: 75), "sharp is not blurry")
check(FZBlur.sharpnessScore(0) == 0 && FZBlur.sharpnessScore(5000) == 1 && FZBlur.sharpnessScore(100) > 0.5, "sharpness score")

// ── اتّحاد-إيجاد
var uf = FZUnionFind(6)
check(uf.union(0, 1) && uf.union(1, 2) && !uf.union(0, 2), "union returns merge flag")
uf.union(4, 5)
check(uf.same(0, 2) && !uf.same(2, 3) && uf.same(4, 5), "same set")
let ufg = uf.groups()
check(ufg == [[0, 1, 2], [4, 5]], "groups: \(ufg)")
check(uf.groups(minSize: 1).count == 3, "singletons included with minSize 1")
let added = uf.add()
check(added == 6 && uf.count == 7 && !uf.same(6, 0), "grow")

// ── المسافات والتجميع
let a1: [Float] = [1, 0, 0], a2: [Float] = [0.95, 0.1, 0], b1: [Float] = [0, 1, 0], c1: [Float] = [0, 0, 1]
check(near(FZVec.distance(a1, a1), 0) && near(FZVec.distance(a1, b1), 2.0.squareRoot()), "euclid")
check(FZVec.distance(a1, [1, 0]) == .infinity, "dimension mismatch")
let nv = FZVec.normalized([3, 4])
check(near(Double(nv[0]), 0.6, 1e-6) && near(Double(nv[1]), 0.8, 1e-6), "normalize")
check(FZVec.normalized([0, 0]) == [0, 0], "zero vector stays")
let na2 = FZVec.normalized(a2)
check(FZVec.distance(a1, na2) < 0.2, "near-duplicates are close")

// صور: 0,1,2 متشابهة بنفس الدقيقة · 3 مختلفة · 4 تشبه 0 لكن بعد يوم ⇒ ما تنضمّ
let times: [Double] = [0, 3, 7, 10, 86400]
let vecs: [[Float]] = [a1, na2, FZVec.normalized([0.97, 0.05, 0.02]), b1, a1]
let cg = FZCluster.groups(times: times, vectors: vecs, threshold: 0.3, maxGap: 240)
check(cg == [[0, 1, 2]], "time-window clustering: \(cg)")
let cgWide = FZCluster.groups(times: times, vectors: vecs, threshold: 0.3, maxGap: 200000)
check(cgWide == [[0, 1, 2, 4]], "wide gap joins far one: \(cgWide)")
let cgUnsorted = FZCluster.groups(times: [7, 0, 10, 3], vectors: [vecs[2], a1, b1, na2], threshold: 0.3, maxGap: 240)
check(cgUnsorted == [[0, 1, 3]], "order-independent: \(cgUnsorted)")
check(FZCluster.groups(times: [0], vectors: [a1], threshold: 1, maxGap: 10).isEmpty, "single item ⇒ none")
// التسلسل: union-find يربط أ-ب-ج، الجشع ما يربط ج بمرساة أ
let chainV: [[Float]] = [[0, 0], [0.25, 0], [0.5, 0]]
check(FZCluster.groups(times: [0, 1, 2], vectors: chainV, threshold: 0.3, maxGap: 60) == [[0, 1, 2]], "union-find chains")
check(FZCluster.greedy(vectors: chainV, threshold: 0.3) == [[0, 1]], "greedy anchors stop chaining: \(FZCluster.greedy(vectors: chainV, threshold: 0.3))")
check(FZCluster.greedy(vectors: [a1, b1, c1, a1, b1], threshold: 0.1) == [[0, 3], [1, 4]], "greedy two groups")

// المتدفّق يطابق الدفعة
var st = FZStreamCluster(threshold: 0.3, maxGap: 240)
for i in 0..<times.count { st.add(time: times[i], vector: vecs[i]) }
check(st.groups() == [[0, 1, 2]], "stream = batch: \(st.groups())")
check(st.buffered == 1, "old entries evicted from window: \(st.buffered)")
var st2 = FZStreamCluster(threshold: 0.3, maxGap: 240, window: 2)
st2.add(time: 0, vector: a1); st2.add(time: 1, vector: b1); st2.add(time: 2, vector: c1); st2.add(time: 3, vector: a1)
check(st2.groups().isEmpty, "window limit drops far-back match")
var st3 = FZStreamCluster(threshold: 0.3, maxGap: 240)
st3.add(time: 0, vector: a1); st3.add(time: 1, vector: nil); st3.add(time: 2, vector: a1)
check(st3.groups() == [[0, 2]] && st3.count == 3, "nil vectors keep numbering")

// ── أفضل لقطة
check(FZBest.pick([]) == nil, "empty pick")
check(FZBest.pick([FZShotMetrics(sharpness: 50), FZShotMetrics(sharpness: 400), FZShotMetrics(sharpness: 120)]) == 1, "sharpest wins")
check(FZBest.pick([FZShotMetrics(sharpness: 300, faces: 0, faceArea: 0), FZShotMetrics(sharpness: 250, faces: 2, faceArea: 0.2)]) == 1, "faces beat slightly sharper")
check(FZBest.pick([FZShotMetrics(sharpness: 10, isFavorite: true), FZShotMetrics(sharpness: 500)]) == 0, "favorite always kept")
check(FZBest.pick([FZShotMetrics(sharpness: 200, pixels: 1000), FZShotMetrics(sharpness: 200, pixels: 4000)]) == 1, "resolution breaks ties")
check(FZBest.pick([FZShotMetrics(sharpness: 200), FZShotMetrics(sharpness: 200)]) == 0, "full tie ⇒ first")
let sc = FZBest.scores([FZShotMetrics(sharpness: 100), FZShotMetrics(sharpness: 0)])
check(sc.count == 2 && sc[0] > sc[1] && sc[1] == 0, "scores")

// ── قواعد التصنيف
let rules = FZRules()
func photo(_ id: String, w: Int = 4032, h: Int = 3024, bytes: Int64 = 3_000_000, age: Double = 10, name: String = "IMG_1.HEIC", sharp: Double? = 500) -> FZAsset {
    FZAsset(id: id, kind: .photo, bytes: bytes, width: w, height: h, created: NOW - age * DAY, fileName: name, sharpness: sharp, brightness: 120)
}
check(FZClassify.isScreenSize(2556, 1179) && !FZClassify.isScreenSize(4032, 3024), "screen size either orientation")
var ss = photo("s1", w: 1179, h: 2556, name: "IMG_2.PNG");
check(FZClassify.isScreenshotLike(ss), "png at screen size = screenshot")
ss.fileName = "IMG_2.JPG"
check(!FZClassify.isScreenshotLike(ss), "jpg at screen size alone is not")
ss.isScreenshot = true
check(FZClassify.isScreenshotLike(ss), "system screenshot flag")
check(FZClassify.isScreenshotLike(photo("s3", name: "Screenshot 2024-01-01.png")), "named screenshot")
check(FZClassify.looksForwardedName("IMG-20230105-WA0012.jpg") && FZClassify.looksForwardedName("WhatsApp Image 2023.jpeg"), "WA names")
check(!FZClassify.looksForwardedName("IMG-20230105-WAX012.jpg") && !FZClassify.looksForwardedName("IMG_4411.HEIC") && !FZClassify.looksForwardedName("x-WA12"), "non WA names")
check(FZClassify.isForwardedLike(photo("f1", w: 1600, h: 1200, bytes: 240_000, age: 120), rules: rules, now: NOW), "small compressed old = forwarded")
check(!FZClassify.isForwardedLike(photo("f2", w: 1600, h: 1200, bytes: 240_000, age: 20), rules: rules, now: NOW), "too recent")
check(!FZClassify.isForwardedLike(photo("f3", bytes: 240_000, age: 120), rules: rules, now: NOW), "full-res camera photo is not forwarded")
check(FZClassify.isForwardedLike(photo("f4", bytes: 2_000_000, age: 400, name: "IMG-20220101-WA0001.jpg"), rules: rules, now: NOW), "WA name wins regardless of size")
check(!FZClassify.isForwardedLike(photo("f5", w: 1280, h: 960, bytes: 900_000, age: 120), rules: rules, now: NOW), "too heavy for forwarded")
check(FZClassify.isBlurry(photo("b1", sharp: 20), rules: rules) && !FZClassify.isBlurry(photo("b2", sharp: 300), rules: rules), "blur rule")
check(!FZClassify.isBlurry(photo("b3", sharp: nil), rules: rules), "unanalysed is not blurry")
var strict = rules; strict.blurLevel = 2
check(FZClassify.isBlurry(photo("b4", sharp: 100), rules: strict) && !FZClassify.isBlurry(photo("b4", sharp: 100), rules: rules), "blur level threshold")
check(rules.similarDistance == 0.42 && rules.blurThreshold == 75 && rules.bigVideoBytes == 50_000_000, "rule defaults")
var bad = rules; bad.similarity = 9; bad.blurLevel = -3
check(bad.similarDistance == 0.55 && bad.blurThreshold == 45, "rule clamps")

let vid = FZAsset(id: "v1", kind: .video, bytes: 600_000_000, width: 3840, height: 2160, created: NOW - 5 * DAY, duration: 90)
let smallVid = FZAsset(id: "v2", kind: .video, bytes: 12_000_000, width: 1920, height: 1080, created: NOW - 5 * DAY, duration: 9)
let live = FZAsset(id: "l1", kind: .live, bytes: 5_000_000, pairedBytes: 2_000_000, width: 4032, height: 3024, created: NOW - 9 * DAY, sharpness: 400, brightness: 100)
check(FZClassify.cats(vid, rules: rules, now: NOW) == [.videos], "big video")
check(FZClassify.cats(smallVid, rules: rules, now: NOW).isEmpty, "small video ignored")
check(FZClassify.cats(live, rules: rules, now: NOW) == [.live], "live photo")
check(FZClassify.saving(live, .live) == 2_000_000 && FZClassify.saving(live, .blurry) == 5_000_000, "saving per category")
var blurShot = photo("x", w: 1179, h: 2556, name: "a.png", sharp: 10)
check(FZClassify.cats(blurShot, rules: rules, now: NOW) == [.screenshots], "screenshots are never 'blurry'")
blurShot.isFavorite = true
check(FZClassify.cats(blurShot, rules: rules, now: NOW).isEmpty, "favorites protected")
var unprot = rules; unprot.protectFavorites = false
check(FZClassify.cats(blurShot, rules: unprot, now: NOW) == [.screenshots], "protection can be turned off")
var gA = photo("g1", sharp: 300); gA.group = 4; gA.isBest = true
var gB = photo("g2", sharp: 30); gB.group = 4
check(FZClassify.cats(gA, rules: rules, now: NOW).isEmpty && FZClassify.cats(gB, rules: rules, now: NOW) == [.similar, .blurry], "best shot kept, other similar+blurry")

// cleanable بدون عدّ مكرّر
let pool: [FZAsset] = [vid, smallVid, live, gA, gB, photo("n", sharp: 800)]
check(FZClassify.cleanable(pool, rules: rules, now: NOW) == 600_000_000 + 2_000_000 + 3_000_000, "cleanable union: \(FZClassify.cleanable(pool, rules: rules, now: NOW))")
let sm = FZClassify.summary(pool, rules: rules, now: NOW)
check(sm[.similar]?.count == 1 && sm[.blurry]?.count == 1 && sm[.videos]?.bytes == 600_000_000 && sm[.live]?.bytes == 2_000_000 && sm[.screenshots]?.count == 0, "summary")
check(sm.count == FZCat.allCases.count, "summary has every category")

// ترتيب الفيديوهات من الأكبر
let vids: [FZAsset] = [smallVid, vid, FZAsset(id: "v3", kind: .video, bytes: 2_000_000_000, width: 1, height: 1, created: 0)]
let sortedV = FZClassify.members(.videos, vids, rules: rules, now: NOW)
check(sortedV.map { $0.id } == ["v3", "v1"], "videos sorted by size: \(sortedV.map { $0.id })")

// المجموعات وأفضل لقطة
var gl: [FZAsset] = []
let sharps: [Double] = [100, 900, 300, 50]
for k in 0..<4 { var p = photo("m\(k)", sharp: sharps[k]); p.group = 1; p.created = NOW + Double(k); gl.append(p) }
var lonely = photo("lonely"); lonely.group = 2; gl.append(lonely)
FZClassify.markBest(&gl)
check(gl[1].isBest && gl.filter { $0.isBest }.count == 1, "markBest picks sharpest")
check(gl[4].group == nil, "single-member group dissolved")
let gs = FZClassify.groups(gl)
check(gs.count == 1 && gs[0].count == 4 && FZClassify.groupSaving(gs[0]) == 9_000_000, "groups + saving")
let q = FZClassify.quickQueue(pool, rules: rules, now: NOW, limit: 2)
check(q.map { $0.id } == ["v1", "g2"], "quick queue biggest first, no live: \(q.map { $0.id })")
check(FZClassify.mainReason(gB, rules: rules, now: NOW) == .similar && FZClassify.mainReason(photo("z"), rules: rules, now: NOW) == nil, "main reason")

// ── السجلّ والسلسلة
var led = FZLedger()
led.record(bytes: 100, count: 0, day: 10)
check(led.sessions == 0, "empty clean ignored")
led.record(bytes: 500_000_000, count: 10, day: 100)
led.record(bytes: 200_000_000, count: 5, day: 100)
check(led.streak == 1 && led.history.count == 1 && led.history[0].bytes == 700_000_000 && led.sessions == 2, "same day merges")
led.record(bytes: 1_000_000_000, count: 3, day: 101)
led.record(bytes: 1, count: 1, day: 102)
check(led.streak == 3 && led.best == 3, "streak grows")
check(led.liveStreak(today: 103) == 3 && led.liveStreak(today: 104) == 0, "live streak breaks after a missed day")
led.record(bytes: 1, count: 1, day: 110)
check(led.streak == 1 && led.best == 3, "streak resets, best kept")
check(led.freed == 1_700_000_002 && led.items == 20, "totals")
let wk = led.week(today: 102)
check(wk.count == 7 && wk[6] == 1 && wk[5] == 1_000_000_000 && wk[4] == 700_000_000 && wk[0] == 0, "week bars: \(wk)")
check(FZLevel.index(0) == 0 && FZLevel.index(150_000_000) == 1 && FZLevel.index(60_000_000_000) == 5, "levels")
check(near(FZLevel.progress(550_000_000), 0.5), "level progress: \(FZLevel.progress(550_000_000))")
check(FZLevel.progress(80_000_000_000) == 1 && FZLevel.remaining(900_000_000) == 100_000_000, "level remaining")
let badges = FZBadges.all(led)
check(badges.first { $0.id == "first" }?.unlocked == true && badges.first { $0.id == "gb1" }?.unlocked == true && badges.first { $0.id == "streak7" }?.unlocked == false, "badges")
check(FZBadges.unlockedCount(FZLedger()) == 0, "no badges at start")
// ترميز السجلّ
if let data = try? JSONEncoder().encode(led), let back = try? JSONDecoder().decode(FZLedger.self, from: data) {
    check(back == led, "ledger codable roundtrip")
} else { check(false, "ledger encode") }

// ── رزمة السحب
var deck = FZDeck(ids: ["a", "b", "c", "d"], sizes: [100, 200, 300])
check(deck.sizes == [100, 200, 300, 0] && deck.currentID == "a" && deck.remaining == 4, "deck init pads sizes")
deck.choose(.trash); deck.choose(.keep); deck.choose(.trash)
check(deck.trashIDs == ["a", "c"] && deck.trashBytes == 400 && deck.keepCount == 1 && deck.currentID == "d", "deck choices")
check(deck.undo() == .trash && deck.currentID == "c" && deck.trashBytes == 100, "undo")
deck.choose(.keep); deck.choose(.trash)
check(deck.isDone && deck.currentID == nil && !deck.choose(.keep) && deck.fraction == 1, "deck done")
deck.set(1, .trash)
check(deck.trashIDs == ["a", "b", "d"] && deck.trashBytes == 300 && deck.trashCount == 3, "edit decision later")
deck.restart()
check(deck.position == 0 && deck.trashBytes == 0, "restart")
check(FZDeck(ids: [], sizes: []).isDone, "empty deck done")

// ── الحلقة
let arcs = FZRing.segments([1, 1, 2], total: 8)
check(arcs.count == 3 && near(arcs[0].end, 0.125) && near(arcs[1].start, 0.125) && near(arcs[2].end, 0.5), "ring arcs")
let full = FZRing.segments([5, 5], total: 4)
check(near(full[1].end, 1), "overflow scales to fill")
let gapped = FZRing.segments([1, 0, 1], total: 2, gap: 0.02)
check(gapped[1].length == 0 && near(gapped[0].start, 0.01) && near(gapped[2].end, 0.99), "gaps: \(gapped)")
check(FZRing.segments([0, 0], total: 0).allSatisfy { $0.length == 0 }, "empty ring")

// ── التقدّم والأيّام
check(FZProgress.overall(phase: 0, fraction: 0) == 0 && near(FZProgress.overall(phase: 1, fraction: 0.5), 0.52) && near(FZProgress.overall(phase: 2, fraction: 1), 1), "progress weights")
check(near(FZProgress.overall(phase: 7, fraction: 3), 1), "progress clamps")
check(FZDay.of(0) == 0 && FZDay.of(86399) == 0 && FZDay.of(86400) == 1 && FZDay.of(86000, offset: 3600) == 1 && FZDay.of(-1) == -1, "day numbers")

// ── المكتبة التجريبيّة: كلّ الفئات حاضرة وحتميّة
let demo = FZDemoLib.make(seed: 7, now: NOW)
let demo2 = FZDemoLib.make(seed: 7, now: NOW)
check(demo == demo2, "demo deterministic")
check(Set(demo.map { $0.id }).count == demo.count, "unique ids")
let ds = FZClassify.summary(demo, rules: rules, now: NOW)
for c in FZCat.allCases { check((ds[c]?.count ?? 0) > 0, "demo has \(c.rawValue)") }
check((ds[.videos]?.count ?? 0) == 11 && (ds[.forwarded]?.count ?? 0) == 20 && (ds[.screenshots]?.count ?? 0) == 24, "demo counts: \(ds)")
let dg = FZClassify.groups(demo)
check(dg.count == 9 && dg.allSatisfy { g in g.filter { $0.isBest }.count == 1 }, "each demo group has exactly one best")
let dc = FZClassify.cleanable(demo, rules: rules, now: NOW)
check(dc > 7_000_000_000 && dc < 20_000_000_000, "demo cleanable sensible: \(FZFormat.size(dc))")
check(zip(demo, demo.dropFirst()).allSatisfy { $0.created <= $1.created }, "demo sorted by time")
if let data = try? JSONEncoder().encode(demo), let back = try? JSONDecoder().decode([FZAsset].self, from: data) {
    check(back == demo, "assets codable roundtrip")
} else { check(false, "assets encode") }
let dl = FZDemoLib.ledger(today: 500)
check(dl.streak == 5 && dl.best == 5 && dl.liveStreak(today: 500) == 5 && dl.items == 227, "demo ledger: \(dl.streak) \(dl.items)")

// ── عشوائيّ ثابت
var r1 = FZRand(3), r2 = FZRand(3)
check((0..<20).allSatisfy { _ in r1.next() == r2.next() }, "rng deterministic")
var r3 = FZRand(5)
check((0..<500).allSatisfy { _ in let v = r3.int(2, 6); return v >= 2 && v <= 6 }, "rng int range")
check((0..<500).allSatisfy { _ in let u = r3.unit(); return u >= 0 && u < 1 }, "rng unit range")

print("farz: \(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
