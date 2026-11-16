import Foundation

var failures = 0
var checks = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) {
    checks += 1
    if !ok { failures += 1; print("FAIL: " + msg()) }
}
func near(_ a: Double, _ b: Double, _ eps: Double) -> Bool { abs(a - b) <= eps }

let N = 4096
let SR = 44100.0

// ───────── حسابات النغمات
check(near(NoteMath.midi(freq: 440), 69, 1e-9), "440 → midi 69")
check(near(NoteMath.freq(midi: 69), 440, 1e-9), "midi 69 → 440")
check(near(NoteMath.freq(midi: 60), 261.6256, 0.001), "C4 = 261.63")
check(near(NoteMath.freq(midi: 40), 82.4069, 0.001), "E2 = 82.41")
check(near(NoteMath.midi(freq: 880), 81, 1e-9), "octave = 12 semitones")
check(NoteMath.name(69) == "A4", "name A4: \(NoteMath.name(69))")
check(NoteMath.name(60) == "C4", "name C4")
check(NoteMath.name(40) == "E2", "name E2")
check(NoteMath.name(61) == "C♯4", "name C#4")
check(NoteMath.name(21) == "A0", "name A0")
check(NoteMath.name(0) == "C-1", "name C-1: \(NoteMath.name(0))")
check(NoteMath.solfege(69) == "لا" && NoteMath.solfege(60) == "دو" && NoteMath.solfege(67) == "صول" && NoteMath.solfege(71) == "سي", "solfege names")
check(NoteMath.solfege(62) == "ري" && NoteMath.solfege(64) == "مي" && NoteMath.solfege(65) == "فا", "solfege ري مي فا")
check(NoteMath.pitchClass(-1) == 11 && NoteMath.pitchClass(12) == 0, "pitch class wraps")
check(NoteMath.isSharp(61) && !NoteMath.isSharp(60) && NoteMath.isSharp(70), "sharps")
check(near(NoteMath.cents(445, from: 440), 19.56, 0.05), "445 Hz is +19.56c")
check(near(NoteMath.cents(440, from: 880), -1200, 1e-9), "octave down = -1200c")
let r1 = NoteMath.reading(freq: 466.1638)
check(r1.midi == 70 && abs(r1.cents) < 0.1, "reading A#4: \(r1)")
let r2 = NoteMath.reading(freq: 450, a4: 450)
check(r2.midi == 69 && abs(r2.cents) < 1e-6, "A4=450 reference")
let r3 = NoteMath.reading(freq: 440, a4: 432)
check(r3.midi == 69 && near(r3.cents, 31.77, 0.05), "440 vs A4=432 is +31.8c: \(r3.cents)")
let r4 = NoteMath.reading(freq: 435)
check(r4.midi == 69 && near(r4.cents, -19.79, 0.05), "435 is -19.8c")
check(near(NoteMath.fold(57, near: 69), 69, 1e-9) && near(NoteMath.fold(81.3, near: 69), 69.3, 1e-9), "octave fold")
check(near(NoteMath.fold(62, near: 69), 62, 1e-9), "fold keeps close notes")

// ───────── كاشف YIN
let yin = YIN(sampleRate: SR)
func detectCents(_ x: [Float], _ ref: Double, sr: Double = SR) -> Double? {
    var y = YIN(sampleRate: sr)
    y.minFreq = 28
    guard let r = y.detect(x) else { return nil }
    return NoteMath.cents(r.freq, from: ref)
}

if let r = yin.detect(Synth.sine(440, sr: SR, count: N)) {
    let rd = NoteMath.reading(freq: r.freq)
    check(rd.midi == 69 && abs(rd.cents) < 2, "440 Hz → A4 ±2c: \(rd)")
    check(r.confidence > 0.9, "pure sine confidence high: \(r.confidence)")
    check(near(r.rms, 0.5 / sqrt(2), 0.01), "rms of 0.5 sine: \(r.rms)")
} else { check(false, "440 sine not detected") }

if let r = yin.detect(Synth.sine(82.41, sr: SR, count: N)) {
    let rd = NoteMath.reading(freq: r.freq)
    check(rd.midi == 40 && abs(rd.cents) < 2, "82.41 Hz → E2: \(rd)")
    check(NoteMath.name(rd.midi) == "E2", "E2 name")
} else { check(false, "82.41 sine not detected") }

let lowCases: [(Double, Int)] = [(41.2034, 28), (30.8677, 23), (55, 33), (110, 45), (146.832, 50), (196, 55), (246.942, 59), (329.628, 64)]
for (f, m) in lowCases {
    if let r = yin.detect(Synth.sine(f, sr: SR, count: N)) {
        let rd = NoteMath.reading(freq: r.freq)
        check(rd.midi == m && abs(rd.cents) < 2, "sine \(f) → midi \(m): \(rd)")
    } else { check(false, "sine \(f) not detected") }
}
if let r = yin.detect(Synth.sine(1318.51, sr: SR, count: N)) {
    check(NoteMath.reading(freq: r.freq).midi == 88, "E6 high note")
} else { check(false, "E6 not detected") }

// مسح كامل: كلّ ثالث نصف درجة من C1 لغاية F♯6 وبمعدّلين
var sweepBad: [String] = []
for m in stride(from: 24, through: 90, by: 3) {
    let f = NoteMath.freq(midi: Double(m))
    for sr in [44100.0, 48000.0] {
        let c = detectCents(Synth.sine(f, sr: sr, count: N, amp: 0.4), f, sr: sr)
        if c == nil || abs(c ?? 99) > 1 { sweepBad.append("sine m\(m)@\(Int(sr)):\(String(describing: c))") }
    }
    if m <= 84 {
        let c = detectCents(Synth.saw(f, sr: SR, count: N, amp: 0.4), f)
        if c == nil || abs(c ?? 99) > 3 { sweepBad.append("saw m\(m):\(String(describing: c))") }
    }
}
check(sweepBad.isEmpty, "sweep within ±1c (sine) / ±3c (saw): \(sweepBad)")

// منشار (توافقيّات قويّة) ما يسبّب خطأ أوكتاف
for (f, m) in [(110.0, 45), (55.0, 33), (196.0, 55), (82.4069, 40)] {
    if let r = yin.detect(Synth.saw(f, sr: SR, count: N)) {
        let rd = NoteMath.reading(freq: r.freq)
        check(rd.midi == m && abs(rd.cents) < 3, "saw \(f) → \(m) no octave error: \(rd)")
    } else { check(false, "saw \(f) not detected") }
}
// صوت شبيه بالغناء
if let r = yin.detect(Synth.voice(220, sr: SR, count: N)) {
    let rd = NoteMath.reading(freq: r.freq)
    check(rd.midi == 57 && abs(rd.cents) < 2, "voice 220 → A3: \(rd)")
} else { check(false, "voice not detected") }
if let r = yin.detect(Synth.voice(220, sr: SR, count: N, vibratoCents: 30)) {
    let rd = NoteMath.reading(freq: r.freq)
    check(rd.midi == 57 && abs(rd.cents) < 40, "vibrato voice stays on A3: \(rd)")
} else { check(false, "vibrato voice not detected") }
// 48 kHz
if let r = YIN(sampleRate: 48000).detect(Synth.sine(440, sr: 48000, count: N)) {
    check(abs(NoteMath.cents(r.freq, from: 440)) < 2, "48k sample rate")
} else { check(false, "48k not detected") }
// طور مختلف وسعة صغيرة
if let r = yin.detect(Synth.sine(261.6256, sr: SR, count: N, amp: 0.02, phase: 1.3)) {
    check(NoteMath.reading(freq: r.freq).midi == 60, "quiet C4 with phase")
} else { check(false, "quiet C4 not detected") }
// ضوضاء
let noisy = Synth.add(Synth.sine(440, sr: SR, count: N), Synth.noise(count: N, seed: 11, amp: 0.05))
if let r = yin.detect(noisy) {
    check(abs(NoteMath.cents(r.freq, from: 440)) < 12, "440 + noise within 12c")
} else { check(false, "noisy sine not detected") }
check(yin.detect([Float](repeating: 0, count: N)) == nil, "silence → nil")
check(yin.detect(Synth.sine(440, sr: SR, count: N, amp: 0.001)) == nil, "below gate → nil")
check(yin.detect(Synth.sine(440, sr: SR, count: 50)) == nil, "too short → nil")
var noiseOK = true
for s in 1...4 {
    if let r = yin.detect(Synth.noise(count: N, seed: UInt64(s), amp: 0.3)), r.confidence > 0.6 { noiseOK = false }
}
check(noiseOK, "white noise is not a confident pitch")
check(YIN.rms([]) == 0, "empty rms")

// ───────── المرشّح الوسيط والمتتبّع
var med = MedianSmoother(size: 3)
_ = med.push(1)
check(near(med.push(100), 50.5, 1e-9), "median of two")
check(near(med.push(2), 2, 1e-9), "median rejects spike")
_ = med.push(3)
check(near(med.push(2), 2, 1e-9) && med.values.count == 3, "window size kept")
med.reset()
check(med.values.isEmpty && med.median == 0, "reset")

var tr = PitchTracker()
for _ in 0..<5 { _ = tr.push(PitchReading(freq: 440, confidence: 0.95, rms: 0.2)) }
check(near(tr.midi ?? 0, 69, 0.01), "tracker on A4")
_ = tr.push(PitchReading(freq: 880, confidence: 0.95, rms: 0.2))
check(near(tr.midi ?? 0, 69, 0.01), "single octave spike ignored: \(String(describing: tr.midi))")
for _ in 0..<3 { _ = tr.push(PitchReading(freq: 523.2511, confidence: 0.95, rms: 0.2)) }
check(near(tr.midi ?? 0, 72, 0.05), "tracker follows new note quickly: \(String(describing: tr.midi))")
for _ in 0..<3 { _ = tr.push(PitchReading(freq: 300, confidence: 0.2, rms: 0.2)) }
check(tr.midi != nil, "short dropout keeps last note")
_ = tr.push(nil)
check(tr.midi == nil, "long dropout clears")
var tr432 = PitchTracker(a4: 432)
_ = tr432.push(PitchReading(freq: 432, confidence: 0.9, rms: 0.1))
check(near(tr432.midi ?? 0, 69, 1e-6), "tracker honours A4")

// ───────── الآلات والأوتار
let guitar = Instruments.find("guitar")
let std = Instruments.tuning(guitar, "g_std")
check(std?.notes.map { NoteMath.western($0) } == ["E", "A", "D", "G", "B", "E"], "guitar standard EADGBE")
check(Instruments.tuning(guitar, "g_dadgad")?.notes.map { NoteMath.western($0) } == ["D", "A", "D", "G", "A", "D"], "DADGAD")
check(Instruments.tuning(guitar, "g_dropd")?.notes.first == 38, "drop D low D2")
check(Instruments.tuning(guitar, "nope")?.id == "g_std", "unknown tuning → first")
check(Instruments.find("nope").id == "chromatic" && Instruments.chromatic.isChromatic, "unknown instrument → chromatic")
check(Instruments.find("oud").tunings.count == 3 && Instruments.find("oud").tunings[0].notes.count == 6, "oud tunings")
check(Instruments.find("oud").tunings[0].notes.map { NoteMath.solfege($0) } == ["دو", "فا", "لا", "ري", "صول", "دو"], "oud classic solfege")
check(Instruments.find("bass").tunings[0].notes.map { NoteMath.name($0) } == ["E1", "A1", "D2", "G2"], "bass EADG")
check(Instruments.find("violin").tunings[0].notes.map { NoteMath.name($0) } == ["G3", "D4", "A4", "E5"], "violin GDAE")
check(Instruments.find("ukulele").tunings[0].notes.map { NoteMath.name($0) } == ["G4", "C4", "E4", "A4"], "ukulele reentrant")
var tIDs = Set<String>()
var dupT = false
for i in Instruments.all { for t in i.tunings { if tIDs.contains(t.id) { dupT = true }; tIDs.insert(t.id) } }
check(!dupT && tIDs.count == 18, "tuning ids unique: \(tIDs.count)")
check(Set(Instruments.all.map { $0.id }).count == Instruments.all.count, "instrument ids unique")

let gn = std?.notes ?? []
let targets: [(Double, Int)] = [(82.41, 0), (110, 1), (146.83, 2), (196, 3), (246.94, 4), (329.63, 5)]
for (f, i) in targets {
    let c = StringFinder.closest(freq: f, notes: gn)
    check(c?.index == i && abs(c?.cents ?? 99) < 1, "auto string \(f) → \(i)")
}
let sharpA = StringFinder.closest(freq: 112, notes: gn)
check(sharpA?.index == 1 && (sharpA?.cents ?? 0) > 30 && (sharpA?.cents ?? 0) < 33, "112 Hz is A string +31c")
let flatE = StringFinder.closest(freq: 80, notes: gn)
check(flatE?.index == 0 && (flatE?.cents ?? 0) < -40, "80 Hz is flat low E")
check(StringFinder.closest(freq: 73.42, notes: Instruments.tuning(guitar, "g_dropd")?.notes ?? [])?.index == 0, "drop D detect")
let uke = Instruments.find("ukulele").tunings[0].notes
check(StringFinder.closest(freq: 392, notes: uke)?.index == 0 && StringFinder.closest(freq: 261.63, notes: uke)?.index == 1, "ukulele strings")
check(StringFinder.closest(freq: 65.41, notes: Instruments.find("oud").tunings[0].notes)?.index == 0, "oud low C")
check(StringFinder.closest(freq: 0, notes: gn) == nil && StringFinder.closest(freq: 100, notes: []) == nil, "closest guards")
// مع مرجع 442
let s442 = StringFinder.closest(freq: 110.5, notes: gn, a4: 442)
check(s442?.index == 1 && abs(s442?.cents ?? 99) < 0.2, "A string at A4=442")
check(StringFinder.advice(cents: 1, tolerance: 3) == "مضبوط تمامًا", "advice in tune")
check(StringFinder.advice(cents: 20, tolerance: 3) == "عالي شويّة — رخِّ بهدوء", "advice loosen")
check(StringFinder.advice(cents: -50, tolerance: 3) == "واطي كثير — شدّ الوتر", "advice tighten")

// ───────── قفل «مضبوط»
var lk = InTuneLock(tolerance: 3, holdTime: 0.6)
var fired = 0
for _ in 0..<4 { if lk.update(cents: 1, dt: 0.125) { fired += 1 } }
check(fired == 0 && !lk.locked && near(lk.progress, 0.5 / 0.6, 1e-9), "not locked before hold time")
if lk.update(cents: -2, dt: 0.125) { fired += 1 }
check(fired == 1 && lk.locked, "locks after 0.625s")
if lk.update(cents: 0, dt: 0.125) { fired += 1 }
check(fired == 1 && lk.locked && lk.progress == 1, "fires once only")
_ = lk.update(cents: 5, dt: 0.125)
check(lk.locked, "hysteresis keeps lock at 5c")
_ = lk.update(cents: 8, dt: 0.125)
check(!lk.locked, "unlocks beyond release band")
for _ in 0..<5 { _ = lk.update(cents: 2, dt: 0.125) }
check(lk.locked, "relock")
_ = lk.update(cents: nil, dt: 0.25)
check(lk.locked, "brief silence keeps lock")
_ = lk.update(cents: nil, dt: 0.25)
check(!lk.locked, "long silence drops lock")
var lk2 = InTuneLock(tolerance: 3, holdTime: 0.6)
for _ in 0..<3 { _ = lk2.update(cents: 1, dt: 0.125) }
_ = lk2.update(cents: 20, dt: 0.125)
check(near(lk2.held, 0.125, 1e-9), "out of tune drains hold: \(lk2.held)")

// ───────── التمارين
let all = Exercises.all
check(all.count == 15, "15 exercises")
check(Set(all.map { $0.id }).count == all.count, "exercise ids unique")
check(all.allSatisfy { $0.difficulty >= 1 && $0.difficulty <= 5 && $0.unlockLevel >= 1 && $0.noteDur > 0 && !$0.steps.isEmpty }, "exercise sanity")
check(all.filter { $0.unlockLevel == 1 }.count >= 3, "three starters unlocked")
check(Set(all.map { $0.kind }) == Set(ExerciseKind.allCases), "every kind used")
let majorDef = Exercises.find("major")
let mj = majorDef?.melody(root: 60) ?? Melody(segs: [])
check(mj.segs.count == 15 && near(mj.duration, 9.0, 1e-9), "major scale 15 notes 9s: \(mj.duration)")
check(mj.lowest == 60 && mj.highest == 72, "major range")
check(mj.target(at: 0.3) == 60 && mj.target(at: 0.65) == 62 && mj.target(at: 4.3) == 72, "major targets")
check(mj.target(at: 9.05) == nil && mj.target(at: -0.1) == nil, "outside melody nil")
check(mj.distinctNotes == [60, 62, 64, 65, 67, 69, 71, 72], "distinct notes: \(mj.distinctNotes)")
check(majorDef?.span == 12, "major span")
let sir = Exercises.find("siren5")?.melody(root: 55) ?? Melody(segs: [])
check(sir.segs.count == 2 && near(sir.duration, 3.4, 1e-9), "siren segs")
check(near(sir.target(at: 0.85) ?? 0, 58.5, 1e-9), "siren glide midpoint")
check(sir.segs[0].isGlide && !mj.segs[0].isGlide, "glide flag")
let hold = Exercises.find("hold5")?.melody(root: 57) ?? Melody(segs: [])
check(hold.segs.count == 1 && hold.duration == 5 && hold.target(at: 4.9) == 57, "hold 5s")
check(Exercises.find("hijaz")?.melody(root: 62).segs[1].from == 63, "hijaz flat second")
if let d = majorDef {
    check(Exercises.root(for: d, low: 48, high: 72) == 54, "root centred in range")
    check(Exercises.root(for: d, low: nil, high: nil) == 55, "default root")
    check(Exercises.root(for: d, low: 50, high: 55) == 50, "narrow range → low")
}
check(ExerciseKind.allCases.allSatisfy { !$0.title.isEmpty && !$0.symbol.isEmpty }, "kind labels")

// ───────── التقييم
func trail(_ m: Melody, step: Double = 1.0 / 30, f: (Double, Double) -> Double?) -> [TrailPoint] {
    var out: [TrailPoint] = []
    var i = 0
    while Double(i) * step < m.duration {
        let t = Double(i) * step
        if let target = m.target(at: t) { out.append(TrailPoint(t: t, midi: f(t, target))) }
        i += 1
    }
    return out
}
let perfect = Scorer.score(trail: trail(mj) { _, g in g }, melody: mj)
check(perfect.percent == 100 && perfect.stars == 3 && perfect.voiced == 1 && perfect.meanCents < 1e-9, "perfect = 100%: \(perfect)")
let off30 = Scorer.score(trail: trail(mj) { _, g in g + 0.3 }, melody: mj)
check(off30.percent == 100 && near(off30.meanCents, 30, 1e-6), "30c off still full: \(off30)")
let off80 = Scorer.score(trail: trail(mj) { _, g in g + 0.8 }, melody: mj)
check(off80.percent == 50 && off80.stars == 0, "80c off = half credit: \(off80)")
let off150 = Scorer.score(trail: trail(mj) { _, g in g + 1.5 }, melody: mj)
check(off150.percent == 0, "150c off = zero")
let silentS = Scorer.score(trail: trail(mj) { _, _ in nil }, melody: mj)
check(silentS.percent == 0 && silentS.voiced == 0, "silence = 0")
let octDown = trail(mj) { _, g in g - 12 }
check(Scorer.score(trail: octDown, melody: mj).percent == 100, "octave-free accepts lower octave")
check(Scorer.score(trail: octDown, melody: mj, octaveFree: false).percent == 0, "strict octave rejects")
var flip = false
let halfS = Scorer.score(trail: trail(mj) { _, g in flip.toggle(); return flip ? g : nil }, melody: mj)
check(halfS.percent >= 45 && halfS.percent <= 55, "half voiced ≈ 50%: \(halfS)")
check(Scorer.score(trail: [], melody: mj).percent == 0, "empty trail")
let sirPerfect = Scorer.score(trail: trail(sir) { _, g in g }, melody: sir)
check(sirPerfect.percent == 100, "siren perfect")
// الوصول المتأخّر لأوّل النغمة ما ينحسب ضدّك
let lateAttack = Scorer.score(trail: trail(mj) { t, g in
    let st = mj.segs[mj.segIndex(at: t) ?? 0].start
    return t - st < 0.15 ? g + 3 : g
}, melody: mj)
check(lateAttack.percent == 100, "attack window forgiven: \(lateAttack)")
check(Scorer.stars(90) == 3 && Scorer.stars(89) == 2 && Scorer.stars(75) == 2 && Scorer.stars(74) == 1 && Scorer.stars(55) == 1 && Scorer.stars(54) == 0, "star thresholds")
// غناء حقيقيّ: صوت اصطناعيّ يمرّ على YIN ثمّ يتقيّم
let holdA = Exercises.find("hold3")?.melody(root: 57) ?? Melody(segs: [])
var simTrail: [TrailPoint] = []
var simTracker = PitchTracker()
let hop = 2048
let sung = Synth.voice(220 * pow(2, 12.0 / 1200), sr: SR, count: Int(SR * 3.2), vibratoCents: 15)
var pos = 0
while pos + N <= sung.count {
    let frame = Array(sung[pos..<(pos + N)])
    let m = simTracker.push(yin.detect(frame))
    simTrail.append(TrailPoint(t: Double(pos + N / 2) / SR, midi: m))
    pos += hop
}
let simScore = Scorer.score(trail: simTrail, melody: holdA)
check(simScore.percent >= 95 && simScore.meanCents < 30, "end-to-end sung A3 scores high: \(simScore)")

// ───────── المستويات
check(Leveling.level(xp: 0) == 1 && Leveling.level(xp: 99) == 1 && Leveling.level(xp: 100) == 2, "level 1→2 at 100")
check(Leveling.level(xp: 299) == 2 && Leveling.level(xp: 300) == 3 && Leveling.level(xp: 650) == 4 && Leveling.level(xp: 1000) == 5, "level curve")
check(Leveling.level(xp: 10_000_000) == 99, "level cap")
check(near(Leveling.progress(xp: 150), 0.25, 1e-9), "progress inside level")
check(Leveling.award(percent: 100, difficulty: 1, newStars: 0) == 20, "award base")
check(Leveling.award(percent: 80, difficulty: 3, newStars: 2) == 52, "award with stars")
check(Leveling.award(percent: -5, difficulty: 1, newStars: -1) == 0, "award never negative")
check(Leveling.title(1) == "مبتدئ" && Leveling.title(5) == "متمكّن" && Leveling.title(20) == "أستاذ الطبقات", "level titles")
// كلّ تمرين يفتح بمستوى ممكن الوصول
check(all.allSatisfy { $0.unlockLevel <= 7 }, "unlocks reachable")

// ───────── السلسلة اليوميّة
check(Streak.current(days: [10, 11, 12], today: 12) == 3, "streak today")
check(Streak.current(days: [10, 11, 12], today: 13) == 3, "streak alive till tomorrow")
check(Streak.current(days: [10, 11, 12], today: 14) == 0, "streak broken")
check(Streak.current(days: [], today: 5) == 0, "empty streak")
check(Streak.best(days: [1, 2, 3, 7, 8, 9, 10, 20]) == 4 && Streak.best(days: []) == 0, "best streak")
var utc = Calendar(identifier: .gregorian)
if let tz = TimeZone(secondsFromGMT: 0) { utc.timeZone = tz }
let d0 = Date(timeIntervalSince1970: 86400 * 1000 + 3600)
check(Streak.dayIndex(d0.addingTimeInterval(86400), calendar: utc) - Streak.dayIndex(d0, calendar: utc) == 1, "day index +1")
check(Streak.dayIndex(d0.addingTimeInterval(3600 * 20), calendar: utc) == Streak.dayIndex(d0, calendar: utc), "same day")

// ───────── المدى الصوتيّ
var rt = RangeTracker(holdNeeded: 0.35)
var got: [Int] = []
for _ in 0..<4 { if let n = rt.push(midi: 55.1, dt: 0.125) { got.append(n) } }
check(got == [55] && rt.low == 55 && rt.high == 55, "held note registers once threshold reached: \(got)")
for _ in 0..<2 { _ = rt.push(midi: 70, dt: 0.125) }
check(rt.high == 55, "short blip ignored")
_ = rt.push(midi: nil, dt: 0.125)
for _ in 0..<4 { _ = rt.push(midi: 47.8, dt: 0.125) }
check(rt.low == 48, "low found")
for _ in 0..<5 { _ = rt.push(midi: 67.2, dt: 0.125) }
check(rt.low == 48 && rt.high == 67, "high found")
rt.reset()
check(rt.low == nil && rt.high == nil, "range reset")
check(VoiceType.classify(low: 40, high: 64) == .baritone, "baritone")
check(VoiceType.classify(low: 43, high: 67) == .tenor, "tenor")
check(VoiceType.classify(low: 36, high: 60) == .bass, "bass")
check(VoiceType.classify(low: 50, high: 72) == .alto, "alto")
check(VoiceType.classify(low: 53, high: 77) == .mezzo, "mezzo")
check(VoiceType.classify(low: 55, high: 81) == .soprano, "soprano")
check(VoiceType.allCases.allSatisfy { !$0.title.isEmpty && !$0.note.isEmpty }, "voice labels")

// ───────── المترونوم
check(Metronome.tapTempo([0, 0.5, 1.0, 1.5]) == 120, "tap 120")
check(Metronome.tapTempo([0, 1, 2]) == 60, "tap 60")
check(Metronome.tapTempo([3]) == nil, "one tap = nil")
check(Metronome.tapTempo([0, 0.5, 1.0, 4.0, 4.5]) == 120, "long pause ignored")
check(Metronome.tapTempo([0, 0.1]) == nil, "double-tap bounce ignored")
check(near(Metronome.interval(bpm: 120), 0.5, 1e-12), "interval")
check(Metronome.tempoName(100).contains("أندانتي") && Metronome.tempoName(200).contains("بريستو"), "tempo names")
check(Metronome.isAccent(beat: 0, perBar: 4) && !Metronome.isAccent(beat: 5, perBar: 4) && Metronome.isAccent(beat: 8, perBar: 4), "accents")

// ───────── المولّد
let sn = Synth.sine(440, sr: SR, count: 1000)
check(sn.count == 1000 && (sn.map { abs($0) }.max() ?? 0) <= 0.5001, "sine amplitude")
check(Synth.noise(count: 64, seed: 3) == Synth.noise(count: 64, seed: 3) && Synth.noise(count: 64, seed: 3) != Synth.noise(count: 64, seed: 4), "seeded noise")
check(Synth.saw(15000, sr: SR, count: 100).count == 100, "saw near nyquist")
var g1 = SeededRNG(7), g2 = SeededRNG(7)
check(g1.next() == g2.next() && (0..<100).allSatisfy { _ in let u = g1.unit(); return u >= 0 && u < 1 }, "seeded rng")

print(failures == 0 ? "ALL DOZAN TESTS PASSED (\(checks) checks)" : "\(failures) FAILURES of \(checks)")
exit(failures == 0 ? 0 : 1)
