import Foundation

/// مقطع من اللحن الهدف: نغمة ثابتة (from == to) أو انزلاق
struct TargetSeg: Codable, Equatable {
    var start: Double
    var dur: Double
    var from: Double
    var to: Double
    var end: Double { start + dur }
    var isGlide: Bool { from != to }

    func midi(at t: Double) -> Double {
        guard dur > 0 else { return from }
        let p = min(1, max(0, (t - start) / dur))
        return from + (to - from) * p
    }
}

struct Melody: Equatable {
    var segs: [TargetSeg]
    var duration: Double { segs.map { $0.end }.max() ?? 0 }
    var lowest: Double { segs.map { min($0.from, $0.to) }.min() ?? 60 }
    var highest: Double { segs.map { max($0.from, $0.to) }.max() ?? 60 }

    func segIndex(at t: Double) -> Int? {
        for (i, s) in segs.enumerated() where t >= s.start && t < s.end { return i }
        return nil
    }

    func target(at t: Double) -> Double? {
        guard let i = segIndex(at: t) else { return nil }
        return segs[i].midi(at: t)
    }

    /// النغمات الثابتة المميّزة (لرسم خطوط الأسماء)
    var distinctNotes: [Int] {
        var s = Set<Int>()
        for g in segs { s.insert(Int(g.from.rounded())); s.insert(Int(g.to.rounded())) }
        return s.sorted()
    }
}

enum ExerciseKind: String, Codable, CaseIterable {
    case scale, arpeggio, siren, hold, interval, pattern

    var title: String {
        switch self {
        case .scale: return "سلالم"
        case .arpeggio: return "أربيجيو"
        case .siren: return "صفّارات"
        case .hold: return "ثبات النغمة"
        case .interval: return "قفزات"
        case .pattern: return "تمارين مرونة"
        }
    }

    var symbol: String {
        switch self {
        case .scale: return "chart.line.uptrend.xyaxis"
        case .arpeggio: return "chart.bar.fill"
        case .siren: return "waveform.path"
        case .hold: return "timer"
        case .interval: return "arrow.up.and.down"
        case .pattern: return "scribble.variable"
        }
    }
}

struct ExerciseDef: Identifiable, Equatable {
    let id: String
    let kind: ExerciseKind
    let title: String
    let detail: String
    let difficulty: Int
    let unlockLevel: Int
    let steps: [Int]
    let noteDur: Double

    var span: Int { (steps.max() ?? 0) - (steps.min() ?? 0) }

    func melody(root: Int) -> Melody {
        let r = Double(root)
        switch kind {
        case .hold:
            return Melody(segs: [TargetSeg(start: 0, dur: noteDur, from: r, to: r)])
        case .siren:
            var segs: [TargetSeg] = []
            var t = 0.0
            if steps.count >= 2 {
                for i in 0..<(steps.count - 1) {
                    segs.append(TargetSeg(start: t, dur: noteDur, from: r + Double(steps[i]), to: r + Double(steps[i + 1])))
                    t += noteDur
                }
            }
            return Melody(segs: segs)
        case .scale, .arpeggio, .interval, .pattern:
            var segs: [TargetSeg] = []
            for (i, s) in steps.enumerated() {
                let m = r + Double(s)
                segs.append(TargetSeg(start: Double(i) * noteDur, dur: noteDur, from: m, to: m))
            }
            return Melody(segs: segs)
        }
    }
}

enum Exercises {
    static let major = [0, 2, 4, 5, 7, 9, 11, 12, 11, 9, 7, 5, 4, 2, 0]
    static let minor = [0, 2, 3, 5, 7, 8, 10, 12, 10, 8, 7, 5, 3, 2, 0]
    static let hijaz = [0, 1, 4, 5, 7, 8, 10, 12, 10, 8, 7, 5, 4, 1, 0]

    static let all: [ExerciseDef] = [
        ExerciseDef(id: "five", kind: .scale, title: "إحماء الخمس نغمات", detail: "طلوع ونزول هادئ لتسخين الصوت", difficulty: 1, unlockLevel: 1, steps: [0, 2, 4, 5, 7, 5, 4, 2, 0], noteDur: 0.75),
        ExerciseDef(id: "hold3", kind: .hold, title: "ثبّت النغمة ٣ ثواني", detail: "نغمة وحدة بدون ما تهتزّ", difficulty: 1, unlockLevel: 1, steps: [0], noteDur: 3),
        ExerciseDef(id: "siren5", kind: .siren, title: "صفّارة ناعمة", detail: "انزلاق من القاعدة للخامسة ورجوع", difficulty: 1, unlockLevel: 1, steps: [0, 7, 0], noteDur: 1.7),
        ExerciseDef(id: "major", kind: .scale, title: "السلّم الكبير", detail: "دو ري مي فا صول لا سي دو وبالعكس", difficulty: 2, unlockLevel: 2, steps: major, noteDur: 0.6),
        ExerciseDef(id: "arpmaj", kind: .arpeggio, title: "أربيجيو كبير", detail: "قفزات التآلف المبهج ١-٣-٥-٨", difficulty: 2, unlockLevel: 2, steps: [0, 4, 7, 12, 7, 4, 0], noteDur: 0.75),
        ExerciseDef(id: "hold5", kind: .hold, title: "ثبّت النغمة ٥ ثواني", detail: "نفَس طويل وثبات أدقّ", difficulty: 2, unlockLevel: 2, steps: [0], noteDur: 5),
        ExerciseDef(id: "minor", kind: .scale, title: "السلّم الصغير", detail: "طابع حزين وأنصاف درجات دقيقة", difficulty: 3, unlockLevel: 3, steps: minor, noteDur: 0.6),
        ExerciseDef(id: "arpmin", kind: .arpeggio, title: "أربيجيو صغير", detail: "التآلف الصغير ١-♭٣-٥-٨", difficulty: 3, unlockLevel: 3, steps: [0, 3, 7, 12, 7, 3, 0], noteDur: 0.7),
        ExerciseDef(id: "siren8", kind: .siren, title: "صفّارة الأوكتاف", detail: "انزلاق كامل لأوكتاف فوق ورجوع", difficulty: 3, unlockLevel: 3, steps: [0, 12, 0], noteDur: 2.0),
        ExerciseDef(id: "fifths", kind: .interval, title: "قفزات الخامسة", detail: "اقفز للخامسة والأوكتاف بدقّة", difficulty: 3, unlockLevel: 4, steps: [0, 7, 0, 7, 12, 7, 0], noteDur: 0.8),
        ExerciseDef(id: "hold8", kind: .hold, title: "ثبّت النغمة ٨ ثواني", detail: "تحدّي النفَس الطويل", difficulty: 4, unlockLevel: 4, steps: [0], noteDur: 8),
        ExerciseDef(id: "octaves", kind: .interval, title: "قفزات الأوكتاف", detail: "تحت ← فوق ← تحت بدون انزلاق", difficulty: 4, unlockLevel: 5, steps: [0, 12, 0, 12, 0], noteDur: 0.9),
        ExerciseDef(id: "hijaz", kind: .scale, title: "سلّم الحجاز", detail: "مسافة الدرجة والنصف المميّزة", difficulty: 4, unlockLevel: 5, steps: hijaz, noteDur: 0.6),
        ExerciseDef(id: "fast", kind: .scale, title: "السلّم السريع", detail: "نفس السلّم الكبير بسرعة مضاعفة", difficulty: 5, unlockLevel: 6, steps: major, noteDur: 0.34),
        ExerciseDef(id: "swirl", kind: .pattern, title: "الدوّامة", detail: "نمط متعرّج يطلع ويرجع", difficulty: 5, unlockLevel: 7, steps: [0, 2, 4, 2, 4, 5, 4, 5, 7, 5, 7, 9, 7, 5, 4, 2, 0], noteDur: 0.4),
    ]

    static func find(_ id: String) -> ExerciseDef? { all.first { $0.id == id } }

    /// نختار قاعدة بحيث يقع التمرين بنصّ مدى المغنّي
    static func root(for def: ExerciseDef, low: Int?, high: Int?) -> Int {
        guard let lo = low, let hi = high, hi > lo else { return 55 }
        let span = def.span
        if hi - lo <= span { return lo }
        return lo + (hi - lo - span) / 2
    }
}

struct TrailPoint: Codable, Equatable {
    var t: Double
    var midi: Double?
}

struct ScoreResult: Codable, Equatable {
    var percent: Int
    var meanCents: Double
    var voiced: Double
    var stars: Int
}

enum Scorer {
    static func stars(_ p: Int) -> Int { p >= 90 ? 3 : (p >= 75 ? 2 : (p >= 55 ? 1 : 0)) }

    /// نقارن كلّ نقطة من أثر الصوت بالهدف بلحظتها:
    /// داخل الحدّ = نقطة كاملة، داخل ضعف الحدّ = نصّ نقطة، صمت = صفر.
    /// نتجاهل أوّل لحظات كلّ نغمة جديدة (وقت الوصول)
    static func score(trail: [TrailPoint], melody: Melody, tolerance: Double = 50, attack: Double = 0.18, octaveFree: Bool = true) -> ScoreResult {
        var total = 0.0, hits = 0.0, voiced = 0.0, absSum = 0.0, absN = 0.0
        for p in trail {
            guard let i = melody.segIndex(at: p.t) else { continue }
            let seg = melody.segs[i]
            let fresh = i == 0 || melody.segs[i - 1].to != seg.from
            if fresh && p.t < seg.start + attack { continue }
            total += 1
            guard let m = p.midi else { continue }
            voiced += 1
            let target = seg.midi(at: p.t)
            let sung = octaveFree ? NoteMath.fold(m, near: target) : m
            let diff = abs((sung - target) * 100)
            if diff <= tolerance { hits += 1 } else if diff <= tolerance * 2 { hits += 0.5 }
            if diff <= 300 { absSum += diff; absN += 1 }
        }
        guard total > 0 else { return ScoreResult(percent: 0, meanCents: 0, voiced: 0, stars: 0) }
        let pct = Int((hits / total * 100).rounded())
        return ScoreResult(percent: pct, meanCents: absN > 0 ? absSum / absN : 0, voiced: voiced / total, stars: stars(pct))
    }
}

enum Leveling {
    /// مجموع النقاط المطلوب للوصول لمستوى: 1→0، 2→100، 3→300، 4→600، 5→1000 …
    static func xpNeeded(level: Int) -> Int { 50 * (level - 1) * level }

    static func level(xp: Int) -> Int {
        var l = 1
        while l < 99 && xpNeeded(level: l + 1) <= xp { l += 1 }
        return l
    }

    /// التقدّم داخل المستوى الحاليّ (0…1)
    static func progress(xp: Int) -> Double {
        let l = level(xp: xp)
        let a = xpNeeded(level: l), b = xpNeeded(level: l + 1)
        guard b > a else { return 1 }
        return Double(xp - a) / Double(b - a)
    }

    static func award(percent: Int, difficulty: Int, newStars: Int) -> Int {
        max(0, percent) * (difficulty + 1) / 10 + 10 * max(0, newStars)
    }

    static func title(_ level: Int) -> String {
        switch level {
        case ..<2: return "مبتدئ"
        case 2..<4: return "هاوي"
        case 4..<6: return "متمكّن"
        case 6..<9: return "محترف"
        default: return "أستاذ الطبقات"
        }
    }
}

enum Streak {
    static func dayIndex(_ d: Date, calendar: Calendar = Calendar.current) -> Int {
        calendar.ordinality(of: .day, in: .era, for: d) ?? 0
    }

    /// السلسلة الحاليّة: تنحسب لو تمرّنت اليوم أو البارحة
    static func current(days: Set<Int>, today: Int) -> Int {
        var d = days.contains(today) ? today : today - 1
        var n = 0
        while days.contains(d) { n += 1; d -= 1 }
        return n
    }

    static func best(days: Set<Int>) -> Int {
        var best = 0
        for d in days where !days.contains(d - 1) {
            var n = 0
            var x = d
            while days.contains(x) { n += 1; x += 1 }
            best = max(best, n)
        }
        return best
    }
}

/// يكتشف أوطى وأعلى نغمة تگدر تثبّتها
struct RangeTracker {
    var holdNeeded: Double = 0.35
    private(set) var low: Int? = nil
    private(set) var high: Int? = nil
    private var cur: Int? = nil
    private var held: Double = 0

    init(holdNeeded: Double = 0.35) { self.holdNeeded = holdNeeded }

    /// ترجع النغمة إذا ثبتت بهذا الإطار
    mutating func push(midi: Double?, dt: Double) -> Int? {
        guard let m = midi else { cur = nil; held = 0; return nil }
        let n = Int(m.rounded())
        if n == cur { held += dt } else { cur = n; held = 0 }
        guard held >= holdNeeded else { return nil }
        if low.map({ n < $0 }) ?? true { low = n }
        if high.map({ n > $0 }) ?? true { high = n }
        return n
    }

    mutating func reset() { low = nil; high = nil; cur = nil; held = 0 }
}

enum VoiceType: String, CaseIterable {
    case bass, baritone, tenor, alto, mezzo, soprano

    var title: String {
        switch self {
        case .bass: return "باص"
        case .baritone: return "باريتون"
        case .tenor: return "تينور"
        case .alto: return "ألتو"
        case .mezzo: return "ميزو سوبرانو"
        case .soprano: return "سوبرانو"
        }
    }

    var note: String {
        switch self {
        case .bass: return "أعمق الأصوات — دافئ وثقيل"
        case .baritone: return "الصوت الرجاليّ الأكثر شيوعًا"
        case .tenor: return "صوت رجاليّ عالي ولامع"
        case .alto: return "صوت عميق ودافئ"
        case .mezzo: return "وسط بين العمق واللمعة"
        case .soprano: return "أعلى الأصوات — خفيف وساطع"
        }
    }

    static func classify(low: Int, high: Int) -> VoiceType {
        let c = Double(low + high) / 2
        if c < 50 { return .bass }
        if c < 54 { return .baritone }
        if c < 58 { return .tenor }
        if c < 62 { return .alto }
        if c < 66 { return .mezzo }
        return .soprano
    }
}

enum Metronome {
    static func interval(bpm: Double) -> Double { 60 / max(1, bpm) }

    /// سرعة من نقرات متتالية (بالثواني)
    static func tapTempo(_ taps: [Double]) -> Double? {
        guard taps.count >= 2 else { return nil }
        var gaps: [Double] = []
        for i in 1..<taps.count {
            let g = taps[i] - taps[i - 1]
            if g > 0.18 && g < 2.5 { gaps.append(g) }
        }
        let recent = Array(gaps.suffix(6))
        guard !recent.isEmpty else { return nil }
        var m = MedianSmoother(size: recent.count)
        for g in recent { _ = m.push(g) }
        let bpm = 60 / m.median
        return min(260, max(30, bpm.rounded()))
    }

    static func tempoName(_ bpm: Double) -> String {
        switch bpm {
        case ..<60: return "لارغو · بطيء جدًّا"
        case 60..<76: return "أداجيو · بطيء"
        case 76..<108: return "أندانتي · مشي هادئ"
        case 108..<120: return "موديراتو · معتدل"
        case 120..<168: return "أليغرو · سريع"
        default: return "بريستو · سريع جدًّا"
        }
    }

    static func isAccent(beat: Int, perBar: Int) -> Bool { perBar > 0 && beat % perBar == 0 }
}
