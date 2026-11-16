import Foundation

enum SleepKind: String, Codable, CaseIterable {
    case snore, cough, talk, other

    var ar: String {
        switch self {
        case .snore: return "شخير"
        case .cough: return "كحّة وعطاس"
        case .talk: return "كلام وأصوات"
        case .other: return "ضوضاء"
        }
    }

    var emoji: String {
        switch self {
        case .snore: return "😴"
        case .cough: return "🤧"
        case .talk: return "💬"
        case .other: return "🔊"
        }
    }
}

/// ليلة نوم مسجّلة
struct SleepSession: Codable, Identifiable, Equatable {
    var id: String
    var start: Double
    var end: Double
    var events: [SoundEvent]
    var levels: [LevelSample]     // قراءة لكلّ دقيقة

    var duration: Double { max(0, end - start) }
}

struct SleepSummary: Equatable {
    var snoreSeconds: Double
    var snoreCount: Int
    var coughs: Int
    var talks: Int
    var others: Int
    var loudMinutes: Int
    var quietPct: Double
    var leq: Double
    var score: Int
}

enum SleepMath {
    static let snoreIds: Set<String> = ["snoring"]
    static let coughIds: Set<String> = ["cough", "sneeze", "throat_clearing", "nose_blowing", "gasp"]
    static let talkIds: Set<String> = ["speech", "whispering", "laughter", "shout", "yell", "crying_sobbing", "sigh", "giggling", "screaming", "humming", "singing"]
    /// أصوات تنفّس هادئة ما نحسبها إزعاج
    static let ignoreIds: Set<String> = ["breathing", "silence", "tick_tock", "clock"]

    static func kind(_ id: String) -> SleepKind {
        if snoreIds.contains(id) { return .snore }
        if coughIds.contains(id) { return .cough }
        if talkIds.contains(id) { return .talk }
        return .other
    }

    /// يستاهل نحفظله مقطع صوت؟
    static func wantsClip(_ id: String) -> Bool {
        let k = kind(id)
        return k == .snore || k == .cough || k == .talk
    }

    static let loudDb = 55.0
    static let quietDb = 40.0

    static func summary(events: [SoundEvent], duration: Double, levels: [Double]) -> SleepSummary {
        var snoreS = 0.0, snoreN = 0, coughs = 0, talks = 0, others = 0
        for e in events where !ignoreIds.contains(e.sound) {
            switch kind(e.sound) {
            case .snore: snoreS += max(1, e.duration); snoreN += 1
            case .cough: coughs += 1
            case .talk: talks += 1
            case .other: others += 1
            }
        }
        let loud = levels.filter { $0 >= loudDb }.count
        let quiet = levels.filter { $0 < quietDb }.count
        let quietPct = levels.isEmpty ? 100 : Double(quiet) / Double(levels.count) * 100
        let sc = score(snoreSeconds: snoreS, coughs: coughs, talks: talks, others: others,
                       loudFraction: levels.isEmpty ? 0 : Double(loud) / Double(levels.count), duration: duration)
        return SleepSummary(snoreSeconds: snoreS, snoreCount: snoreN, coughs: coughs, talks: talks, others: others,
                            loudMinutes: loud, quietPct: quietPct, leq: Level.leq(levels), score: sc)
    }

    /// درجة هدوء الليلة 0..100 (أعلى = أهدى)
    static func score(snoreSeconds: Double, coughs: Int, talks: Int, others: Int, loudFraction: Double, duration: Double) -> Int {
        guard duration >= 60 else { return 100 }
        let hours = max(0.5, duration / 3600)
        let snoreFrac = min(1, snoreSeconds / duration)
        var p = 0.0
        p += min(35, snoreFrac * 100)
        p += min(20, Double(coughs) / hours * 3)
        p += min(15, Double(talks) / hours * 3)
        p += min(15, Double(others) / hours * 2)
        p += min(15, max(0, loudFraction) * 60)
        return Int(min(100, max(0, (100 - p).rounded())))
    }

    static func grade(_ score: Int) -> String {
        if score >= 85 { return "ليلة هادئة جدًّا" }
        if score >= 70 { return "ليلة جيّدة" }
        if score >= 50 { return "ليلة متقطّعة" }
        return "ليلة مزعجة"
    }

    /// أحداث كلّ فترة حسب النوع (للرسم)
    static func kindBins(_ events: [SoundEvent], start: Double, end: Double, bin: Double) -> [[SleepKind: Int]] {
        guard end > start, bin > 0 else { return [] }
        let n = Int(ceil((end - start) / bin))
        var out = [[SleepKind: Int]](repeating: [:], count: n)
        for e in events where e.start >= start && e.start < end && !ignoreIds.contains(e.sound) {
            let i = min(n - 1, Int((e.start - start) / bin))
            out[i][kind(e.sound), default: 0] += 1
        }
        return out
    }
}
