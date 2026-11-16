import Foundation

var failures = 0
var checks = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { checks += 1; if !ok { failures += 1; print("FAIL: " + msg()) } }
func near(_ a: Double, _ b: Double, _ eps: Double = 1e-6) -> Bool { abs(a - b) <= eps }

struct LCG: RandomNumberGenerator {
    var s: UInt64
    mutating func next() -> UInt64 { s = s &* 6364136223846793005 &+ 1442695040888963407; return s }
}

// ── القاموس
check(Catalog.map.count == Catalog.raw.count, "no duplicate ids in catalog: \(Catalog.map.count) vs \(Catalog.raw.count)")
check(Catalog.map.count >= 60, "at least 60 Arabic labels: \(Catalog.map.count)")
check(Catalog.info("baby_crying").ar == "طفل يبكي" && Catalog.info("baby_crying").cat == .safety, "baby_crying label")
check(Catalog.info("speech").emoji == "🗣️", "speech emoji")
let lion = Catalog.info("lion_roar")
check(lion.emoji == "🦁" && lion.ar == "lion roar" && lion.cat == .animals, "guess by keyword: \(lion)")
let unk = Catalog.info("zzz_qq")
check(unk.emoji == "🔊" && unk.ar == "zzz qq" && unk.cat == .other, "unknown falls back to English id")
check(Catalog.humanize("water_tap_faucet") == "water tap faucet", "humanize")
check(Catalog.stableHash("a") == 0xaf63dc4c8601ec8c, "FNV-1a 64 of 'a'")
check(Catalog.stableHash("speech") == Catalog.stableHash("speech") && Catalog.stableHash("speech") != Catalog.stableHash("music"), "stable hash")
var anglesOk = true
for line in Catalog.raw { let id = line.components(separatedBy: "|")[0]; let a = Catalog.angle(id); if !(a >= 0 && a < 360) { anglesOk = false } }
check(anglesOk, "angles in 0..<360")
for c in SoundCat.allCases { check(!c.ar.isEmpty, "category name \(c)") }

// ── مجموعات الحراسة
check(Set(Watch.groups.map { $0.id }).count == Watch.groups.count, "unique watch ids")
for g in Watch.groups {
    check(!g.ids.isEmpty, "group \(g.id) has ids")
    for id in g.ids { check(Catalog.map[id] != nil, "watch id \(id) has Arabic label") }
}
check(Watch.group(forSound: "knock")?.id == "door", "knock → door")
check(Watch.group(forSound: "ambulance_siren")?.id == "siren", "ambulance → siren")
check(Watch.group(forSound: "speech") == nil, "speech not watchable")
check(Watch.group(id: "baby")?.emoji == "👶", "group by id")
if let baby = Watch.group(id: "baby") {
    let c = Watch.confidence(baby, in: [Hit(id: "crying_sobbing", conf: 0.4), Hit(id: "baby_crying", conf: 0.7), Hit(id: "speech", conf: 0.9)])
    check(near(c, 0.7), "group confidence = max of its ids: \(c)")
    check(Watch.confidence(baby, in: [Hit(id: "speech", conf: 0.9)]) == 0, "no member → 0")
}

// ── الحساسيّة
check(near(Tuning.threshold(sensitivity: 0), 0.9), "sens 0")
check(near(Tuning.threshold(sensitivity: 1), 0.35), "sens 1")
check(near(Tuning.threshold(sensitivity: 0.5), 0.625), "sens .5")
check(near(Tuning.threshold(sensitivity: 2), 0.35) && near(Tuning.threshold(sensitivity: -1), 0.9), "sens clamped")
let tp = Tuning.top([Hit(id: "a", conf: 0.5), Hit(id: "c", conf: 0.9), Hit(id: "b", conf: 0.9), Hit(id: "d", conf: 0.1), Hit(id: "silence", conf: 0.95)],
                    n: 3, minConf: 0.2, ignore: EventTracker.defaultIgnore)
check(tp.map { $0.id } == ["b", "c", "a"], "top-n sorted, ties by id, ignores silence: \(tp.map { $0.id })")
check(Tuning.top([], n: 5, minConf: 0, ignore: []).isEmpty, "top of empty")

// ── بوّابة التنبيه
var g = AlertGate(threshold: 0.6, cooldown: 30, hitsNeeded: 2, window: 3)
check(!g.feed("baby", conf: 0.7, at: 0), "first hit not enough")
check(g.feed("baby", conf: 0.7, at: 1), "second hit within window fires")
check(near(g.remaining("baby", at: 11), 20), "cooldown remaining 20")
check(!g.feed("baby", conf: 0.9, at: 2), "after fire, counting restarts")
check(!g.feed("baby", conf: 0.9, at: 3), "cooldown blocks")
check(g.feed("door", conf: 0.8, at: 3) == false && g.feed("door", conf: 0.8, at: 3.5), "other key independent")
check(!g.feed("baby", conf: 0.9, at: 40), "stale hits dropped after window")
check(g.feed("baby", conf: 0.9, at: 41), "fires again after cooldown")
check(!g.feed("baby", conf: 0.5, at: 80) && !g.feed("baby", conf: 0.5, at: 81), "below threshold ignored")
var g2 = AlertGate(threshold: 0.6, cooldown: 10, hitsNeeded: 2, window: 3)
check(!g2.feed("x", conf: 0.9, at: 0) && !g2.feed("x", conf: 0.9, at: 5), "hits too far apart do not fire")
var g3 = AlertGate(threshold: 0.5, cooldown: 5, hitsNeeded: 1, window: 3)
check(g3.feed("x", conf: 0.6, at: 0) && !g3.feed("x", conf: 0.6, at: 4) && g3.feed("x", conf: 0.6, at: 5), "single-hit mode with cooldown")
g3.reset()
check(g3.remaining("x", at: 6) == 0 && g3.feed("x", conf: 0.6, at: 6), "reset clears")
check(near(g.remaining("never", at: 0), 0), "never fired → 0")

// ── تجميع الأحداث
var tr = EventTracker(threshold: 0.55, gap: 2.5)
var o = tr.feed([Hit(id: "speech", conf: 0.8), Hit(id: "dog", conf: 0.3)], at: 0, db: 50)
check(o.started.map { $0.sound } == ["speech"] && o.closed.isEmpty, "speech started, dog below threshold")
check(o.started.first?.id == "speech-0", "event id")
o = tr.feed([Hit(id: "speech", conf: 0.7)], at: 1, db: 60)
check(o.started.isEmpty && o.closed.isEmpty, "speech continues")
o = tr.feed([Hit(id: "speech", conf: 0.9), Hit(id: "dog_bark", conf: 0.6)], at: 2, db: 55)
check(o.started.map { $0.sound } == ["dog_bark"], "dog_bark started")
o = tr.feed([], at: 3, db: 30)
check(o.closed.isEmpty && tr.open.count == 2, "gap not exceeded yet")
o = tr.feed([], at: 6, db: 30)
check(o.closed.map { $0.sound } == ["speech", "dog_bark"], "both closed in start order: \(o.closed.map { $0.sound })")
if let sp = o.closed.first {
    check(near(sp.duration, 2) && near(sp.peak, 0.9) && near(sp.db, 60), "speech aggregated: \(sp)")
}
check(tr.open.isEmpty, "nothing open")
o = tr.feed([Hit(id: "speech", conf: 0.9)], at: 7, db: 40)
check(o.started.first?.id == "speech-7000", "new event after gap")
o = tr.feed([Hit(id: "silence", conf: 0.99)], at: 7.5, db: 20)
check(o.started.isEmpty, "silence ignored")
let fl = tr.flush()
check(fl.count == 1 && fl[0].id == "speech-7000" && tr.open.isEmpty, "flush closes open events")
// إطارات متتالية مع انقطاعات قصيرة = حدث واحد
var tr2 = EventTracker(threshold: 0.5, gap: 2)
var closedAll: [SoundEvent] = []
for i in 0..<20 { let t = Double(i) * 0.5; let hits = (i % 3 == 2) ? [] : [Hit(id: "snoring", conf: 0.8)]; closedAll += tr2.feed(hits, at: t, db: 45).closed }
closedAll += tr2.flush()
check(closedAll.count == 1 && near(closedAll[0].duration, 9.5), "short dropouts merge into one event: \(closedAll.map { $0.duration })")

// ── منظّم المقاطع
var ct = ClipThrottle(minGap: 20, maxCount: 2)
check(ct.allow(at: 0) && !ct.allow(at: 5) && ct.allow(at: 25) && !ct.allow(at: 100), "clip throttle gap + max")

// ── الديسيبل
check(near(Level.rms([1, -1, 1, -1]), 1), "rms square wave")
check(Level.rms([]) == 0, "rms empty")
check(near(Level.dbfs(rms: 1), 0) && near(Level.dbfs(rms: 0.1), -20, 1e-9), "dbfs")
check(near(Level.dbfs(rms: 0), -140, 1e-9), "dbfs floor")
check(near(Level.spl(rms: 0.01, offset: 95), 55, 1e-9), "spl with offset")
check(Level.spl(rms: 0, offset: 95) == 0 && Level.spl(rms: 10, offset: 120) == 130, "spl clamped")
check(near(Level.leq([60, 60]), 60, 1e-9), "leq equal")
check(near(Level.leq([60, 70]), 67.4036, 1e-3), "leq mixed: \(Level.leq([60, 70]))")
check(Level.leq([]) == 0, "leq empty")
check(near(Level.allowedSeconds(85), 28800, 1e-6) && near(Level.allowedSeconds(88), 14400, 1e-6) && near(Level.allowedSeconds(82), 57600, 1e-6), "3 dB exchange rate")
check(near(Level.smooth(40, 60), 51) && near(Level.smooth(60, 40), 56.4), "attack/release smoothing")
check([30.0, 50, 70, 80, 90].map { Level.zone($0) } == [0, 1, 2, 3, 4], "zones")
check(Level.zoneAr.count == 5 && Level.zoneTip.count == 5, "zone texts")
check(Level.gauge(20) == 0 && Level.gauge(110) == 1 && near(Level.gauge(65), 0.5), "gauge mapping")
var ex = Exposure()
ex.add(level: 85, seconds: 3600)
check(near(ex.dose, 0.125, 1e-9), "1h at 85 = 12.5%")
ex.add(level: 88, seconds: 14400)
check(near(ex.dose, 1.125, 1e-9) && near(ex.percent, 112.5, 1e-6), "dose accumulates: \(ex.dose)")
check(ex.leq > 85 && ex.leq < 88 && ex.peak == 88 && near(ex.loudSeconds, 18000), "exposure stats")
ex.add(level: 90, seconds: 0)
check(near(ex.seconds, 18000), "zero dt ignored")
check(Exposure().leq == 0, "empty exposure leq")

// ── المخزن الدائريّ
var r = Ring<Int>(capacity: 5, fill: 0)
for i in 1...3 { r.append(i) }
check(r.ordered() == [1, 2, 3] && r.count == 3 && !r.isFull, "ring partial")
for i in 4...7 { r.append(i) }
check(r.ordered() == [3, 4, 5, 6, 7] && r.isFull, "ring wraps: \(r.ordered())")
check(r.last(2) == [6, 7] && r.last(10) == [3, 4, 5, 6, 7] && r.last(0).isEmpty && r.last(-3).isEmpty, "ring last")
check(r.physical(0) == 2 && r[logical: 0] == 3 && r[logical: 4] == 7, "ring index math")
r.append(contentsOf: Array(10...16))
check(r.ordered() == [12, 13, 14, 15, 16], "bulk append bigger than capacity: \(r.ordered())")
r.append(17)
check(r.ordered() == [13, 14, 15, 16, 17], "append after bulk")
r.removeAll()
check(r.count == 0 && r.last(3).isEmpty, "ring cleared")
var rng = LCG(s: 42)
var ring2 = Ring<Int>(capacity: 37, fill: -1)
var naive: [Int] = []
var counter = 0
var ringOk = true
for _ in 0..<400 {
    let k = Int(rng.next() % 50)
    var chunk: [Int] = []
    for _ in 0..<k { counter += 1; chunk.append(counter) }
    ring2.append(contentsOf: chunk)
    naive += chunk
    let want = Array(naive.suffix(37))
    if ring2.ordered() != want { ringOk = false }
    let n = Int(rng.next() % 45)
    if ring2.last(n) != Array(naive.suffix(min(n, 37))) { ringOk = false }
}
check(ringOk, "ring matches naive suffix under random chunks")
check(Ring<Int>(capacity: 0, fill: 0).capacity == 1, "capacity at least 1")

// ── المقاطع
let dec = ClipMath.decimate([1, 2, 3, 4, 5], factor: 2)
check(dec == [1.5, 3.5, 5], "decimate average: \(dec)")
check(ClipMath.decimate([1, 2], factor: 1) == [1, 2], "decimate x1")
check(ClipMath.factor(sampleRate: 48000) == 3 && ClipMath.factor(sampleRate: 44100) == 2 && ClipMath.factor(sampleRate: 16000) == 1 && ClipMath.factor(sampleRate: 8000) == 1, "decimation factor")
let nm = ClipMath.normalize([0.1, -0.05])
check(abs(nm[0] - 0.8) < 1e-5 && abs(nm[1] + 0.4) < 1e-5, "normalize to 0.8: \(nm)")
check(abs(ClipMath.normalize([0.01])[0] - 0.08) < 1e-6, "gain capped at 8")
check(ClipMath.normalize([0, 0]) == [0, 0], "silent clip unchanged")

// ── الساعات والأيّام
let tz = 3 * 3600
check(Stats.hourOf(0, tz: 0) == 0 && Stats.hourOf(3600 * 25, tz: 0) == 1 && Stats.hourOf(0, tz: tz) == 3 && Stats.hourOf(-3600, tz: 0) == 23, "hourOf")
check(Stats.dayKey(86399, tz: 0) == 0 && Stats.dayKey(86400, tz: 0) == 1, "dayKey")
check(Stats.dayStart(100000, tz: 0) == 86400 && Stats.dayStart(87400, tz: tz) == 75600, "dayStart with tz")
func ev(_ s: String, _ t: Double, _ d: Double = 0) -> SoundEvent { SoundEvent(id: EventTracker.eventId(s, t), sound: s, start: t, end: t + d, peak: 0.8, db: 50, clip: nil) }
let hevs = [ev("a", 3600 * 1 + 10, 2), ev("b", 3600 * 1 + 900), ev("a", 3600 * 5, 3)]
let hb = Stats.hourly(hevs, tz: 0)
check(hb.count == 24 && hb[1] == 2 && hb[5] == 1 && hb.reduce(0, +) == 3, "hourly buckets")
check(Stats.busiestHour(hb) == 1 && Stats.busiestHour([Int](repeating: 0, count: 24)) == nil, "busiest hour")
let cs = Stats.counts(hevs)
check(cs.count == 2 && cs[0] == SoundCount(sound: "a", count: 2, seconds: 5) && cs[1].sound == "b", "counts per sound: \(cs)")
check(Stats.within(hevs, from: 3600, to: 3600 * 2).count == 2, "within range")
let now = 10 * 86400.0 + 100
let devs = [ev("x", 10 * 86400 + 5), ev("x", 9 * 86400), ev("x", 9 * 86400 + 500), ev("x", 7 * 86400), ev("x", 11 * 86400)]
check(Stats.daily(devs, days: 3, now: now, tz: 0) == [0, 2, 1], "daily counts: \(Stats.daily(devs, days: 3, now: now, tz: 0))")
let bs = Stats.bins([LevelSample(t: 0, db: 50), LevelSample(t: 30, db: 50), LevelSample(t: 60, db: 70)], start: 0, end: 180, bin: 60)
check(bs.count == 3 && near(bs[0] ?? -1, 50, 1e-9) && near(bs[1] ?? -1, 70, 1e-9) && bs[2] == nil, "level bins")
check(Stats.bins([], start: 10, end: 5, bin: 60).isEmpty, "bad range bins")
check(Stats.durationText(29) == "29 ث" && Stats.durationText(600) == "10 د" && Stats.durationText(3600) == "1 س" && Stats.durationText(5400) == "1 س 30 د", "duration text")

// ── النوم
let night = 8 * 3600.0
check(SleepMath.score(snoreSeconds: 0, coughs: 0, talks: 0, others: 0, loudFraction: 0, duration: night) == 100, "perfect night")
var nevs: [SoundEvent] = []
for i in 0..<4 { nevs.append(ev("snoring", Double(i) * 3600, 720)) }
for i in 0..<8 { nevs.append(ev("cough", 100 + Double(i) * 1000)) }
nevs.append(ev("breathing", 50, 600))
let lv = [Double](repeating: 35, count: 432) + [Double](repeating: 58, count: 48)
let sm = SleepMath.summary(events: nevs, duration: night, levels: lv)
check(near(sm.snoreSeconds, 2880) && sm.snoreCount == 4 && sm.coughs == 8 && sm.talks == 0 && sm.others == 0, "sleep tallies, breathing ignored: \(sm)")
check(sm.loudMinutes == 48 && near(sm.quietPct, 90, 1e-9), "loud/quiet minutes")
check(sm.score == 81, "sleep score 100-10-3-6 = 81: \(sm.score)")
check(SleepMath.grade(sm.score) == "ليلة جيّدة" && SleepMath.grade(90) == "ليلة هادئة جدًّا" && SleepMath.grade(60) == "ليلة متقطّعة" && SleepMath.grade(10) == "ليلة مزعجة", "grades")
check(SleepMath.score(snoreSeconds: night, coughs: 200, talks: 100, others: 100, loudFraction: 1, duration: night) == 0, "worst night = 0")
check(SleepMath.score(snoreSeconds: 3600, coughs: 0, talks: 0, others: 0, loudFraction: 0, duration: night) < SleepMath.score(snoreSeconds: 1800, coughs: 0, talks: 0, others: 0, loudFraction: 0, duration: night), "more snoring lowers score")
check(SleepMath.score(snoreSeconds: 10, coughs: 5, talks: 0, others: 0, loudFraction: 0, duration: 30) == 100, "too short → 100")
check(SleepMath.kind("snoring") == .snore && SleepMath.kind("sneeze") == .cough && SleepMath.kind("speech") == .talk && SleepMath.kind("dog") == .other, "sleep kinds")
check(SleepMath.wantsClip("snoring") && !SleepMath.wantsClip("car_passing_by"), "clip policy")
let kb = SleepMath.kindBins([ev("snoring", 0), ev("cough", 10), ev("snoring", 70), ev("breathing", 80)], start: 0, end: 120, bin: 60)
check(kb.count == 2 && kb[0][.snore] == 1 && kb[0][.cough] == 1 && kb[1][.snore] == 1 && kb[1][.other] == nil, "kind bins")
let emptySum = SleepMath.summary(events: [], duration: night, levels: [])
check(emptySum.score == 100 && emptySum.quietPct == 100 && emptySum.leq == 0, "empty night summary")
for k in SleepKind.allCases { check(!k.ar.isEmpty && !k.emoji.isEmpty, "sleep kind text \(k)") }
// ترميز الجلسة
let ses = SleepSession(id: "n1", start: 0, end: night, events: nevs, levels: [LevelSample(t: 0, db: 35)])
if let d = try? JSONEncoder().encode(ses), let back = try? JSONDecoder().decode(SleepSession.self, from: d) {
    check(back == ses && near(back.duration, night), "session codable round-trip")
} else { check(false, "session codable") }

print("samaa: \(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
