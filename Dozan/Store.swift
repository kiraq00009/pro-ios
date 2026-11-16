import SwiftUI

struct DZSettings: Codable, Equatable {
    var a4: Double = 440
    /// 0 = الاثنين، 1 = غربي، 2 = صولفيج
    var naming: Int = 0
    var tolerance: Double = 3
    var instrument: String = "guitar"
    var tuning: String = "g_std"
    var autoString: Bool = true
    var haptics: Bool = true
    var octaveFree: Bool = true
    var singTolerance: Double = 50
    var timbre: Int = 1
}

struct SessionRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var exercise: String
    var title: String
    var percent: Int
    var stars: Int
    var xp: Int
    var seconds: Double
}

struct DZProfile: Codable, Equatable {
    var xp: Int = 0
    var best: [String: Int] = [:]
    var stars: [String: Int] = [:]
    var plays: [String: Int] = [:]
    var days: [Int] = []
    var history: [SessionRecord] = []
    var low: Int? = nil
    var high: Int? = nil
    var tuneCount: Int = 0
    var practiceSec: Double = 0
    var onboarded: Bool = false
}

struct AwardInfo: Equatable {
    var xp: Int
    var newStars: Int
    var levelUp: Bool
    var newLevel: Int
    var isBest: Bool
}

final class DozanStore: ObservableObject {
    @Published var settings = DZSettings() { didSet { save() } }
    @Published var profile = DZProfile() { didSet { save() } }

    private let key = "dozan_v1"
    private var loading = true

    init() {
        if Shot.on {
            settings = DozanStore.demoSettings()
            profile = DozanStore.demoProfile()
        } else if let data = UserDefaults.standard.data(forKey: key),
                  let blob = try? JSONDecoder().decode(Blob.self, from: data) {
            settings = blob.settings
            profile = blob.profile
        }
        loading = false
    }

    private struct Blob: Codable { var settings: DZSettings; var profile: DZProfile }

    private func save() {
        guard !loading, !Shot.on else { return }
        if let data = try? JSONEncoder().encode(Blob(settings: settings, profile: profile)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: مشتقّات
    var level: Int { Leveling.level(xp: profile.xp) }
    var today: Int { Streak.dayIndex(Date()) }
    var streak: Int { Streak.current(days: Set(profile.days), today: today) }
    var bestStreak: Int { Streak.best(days: Set(profile.days)) }
    var practicedToday: Bool { profile.days.contains(today) }
    var instrument: Instrument { Instruments.find(settings.instrument) }
    var tuning: Tuning? { Instruments.tuning(instrument, settings.tuning) }
    var averageScore: Int {
        let h = profile.history
        guard !h.isEmpty else { return 0 }
        return h.map { $0.percent }.reduce(0, +) / h.count
    }

    func isUnlocked(_ d: ExerciseDef) -> Bool { level >= d.unlockLevel }

    func noteLabel(_ m: Int) -> String {
        switch settings.naming {
        case 1: return NoteMath.name(m)
        case 2: return NoteMath.solfegeName(m)
        default: return "\(NoteMath.name(m)) · \(NoteMath.solfege(m))"
        }
    }

    func shortLabel(_ m: Int) -> String {
        settings.naming == 2 ? NoteMath.solfege(m) : NoteMath.western(m)
    }

    /// يسجّل نتيجة تمرين ويرجع شنو انكسب
    func record(_ def: ExerciseDef, result: ScoreResult, seconds: Double) -> AwardInfo {
        let oldStars = profile.stars[def.id] ?? 0
        let newStars = max(0, result.stars - oldStars)
        let oldLevel = level
        let gain = Leveling.award(percent: result.percent, difficulty: def.difficulty, newStars: newStars)
        let oldBest = profile.best[def.id] ?? -1
        var p = profile
        p.xp += gain
        p.best[def.id] = max(oldBest, result.percent)
        p.stars[def.id] = max(oldStars, result.stars)
        p.plays[def.id, default: 0] += 1
        let t = today
        if !p.days.contains(t) { p.days.append(t) }
        p.practiceSec += seconds
        p.history.insert(SessionRecord(date: Date(), exercise: def.id, title: def.title, percent: result.percent, stars: result.stars, xp: gain, seconds: seconds), at: 0)
        if p.history.count > 200 { p.history.removeLast(p.history.count - 200) }
        profile = p
        let nl = Leveling.level(xp: p.xp)
        return AwardInfo(xp: gain, newStars: newStars, levelUp: nl > oldLevel, newLevel: nl, isBest: result.percent > oldBest && oldBest >= 0)
    }

    func addTuned() {
        profile.tuneCount += 1
        let t = today
        if !profile.days.contains(t) { profile.days.append(t) }
    }

    func saveRange(low: Int, high: Int) {
        var p = profile
        p.low = min(low, high)
        p.high = max(low, high)
        profile = p
    }

    func resetProgress() {
        var p = DZProfile()
        p.onboarded = true
        profile = p
    }

    /// دقائق التمرين لآخر ٧ أيّام (الأقدم أوّلًا)
    func weekMinutes() -> [Double] {
        let t = today
        var out = [Double](repeating: 0, count: 7)
        for r in profile.history {
            let d = t - Streak.dayIndex(r.date)
            if d >= 0 && d < 7 { out[6 - d] += r.seconds / 60 }
        }
        return out
    }

    // MARK: بيانات العرض
    static func demoSettings() -> DZSettings {
        var s = DZSettings()
        s.instrument = "guitar"
        s.tuning = "g_std"
        return s
    }

    static func demoProfile() -> DZProfile {
        var p = DZProfile()
        p.onboarded = true
        p.xp = 740
        p.low = 43
        p.high = 67
        p.tuneCount = 38
        let today = Streak.dayIndex(Date())
        p.days = Array((today - 8)...today) + [today - 12, today - 13, today - 14, today - 20]
        let scores: [(String, Int)] = [("five", 96), ("hold3", 92), ("siren5", 88), ("major", 84), ("arpmaj", 79), ("hold5", 90), ("minor", 71), ("arpmin", 66)]
        for (id, sc) in scores {
            p.best[id] = sc
            p.stars[id] = Scorer.stars(sc)
            p.plays[id] = 3 + sc % 5
        }
        var rng = SeededRNG(42)
        var hist: [SessionRecord] = []
        let ids = ["major", "five", "arpmaj", "hold5", "minor", "siren5", "arpmin", "hold3", "major", "five", "arpmaj", "minor", "siren5", "five"]
        for (i, id) in ids.enumerated() {
            let def = Exercises.find(id)
            let pct = 58 + Int(rng.unit() * 40)
            let secs = (def.map { $0.melody(root: 55).duration } ?? 8) * Double(2 + i % 3)
            let date = Date().addingTimeInterval(-Double(i) * 86400 * 0.62 - 1800 - rng.unit() * 3000)
            hist.append(SessionRecord(date: date, exercise: id, title: def?.title ?? id, percent: pct, stars: Scorer.stars(pct), xp: pct * 3 / 10, seconds: secs))
        }
        p.history = hist
        p.practiceSec = 5460
        return p
    }
}
