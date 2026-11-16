import Foundation

/// نتيجة واحدة من المصنّف: معرّف الصوت + الثقة 0..1
struct Hit: Equatable, Codable {
    var id: String
    var conf: Double
}

enum Tuning {
    /// الحساسيّة 0..1 ← عتبة الثقة. حساسيّة أعلى = عتبة أوطأ
    static func threshold(sensitivity s: Double) -> Double {
        let c = min(1, max(0, s))
        return 0.9 - 0.55 * c
    }

    /// أعلى n أصوات مرتّبة بالثقة، بلا المتجاهَلة وبلا الضعيفة
    static func top(_ hits: [Hit], n: Int, minConf: Double, ignore: Set<String>) -> [Hit] {
        let f = hits.filter { $0.conf >= minConf && !ignore.contains($0.id) }
        let s = f.sorted { a, b in a.conf == b.conf ? a.id < b.id : a.conf > b.conf }
        return Array(s.prefix(max(0, n)))
    }
}

/// بوّابة التنبيه: لازم الصوت يتكرّر (hitsNeeded) خلال نافذة قصيرة حتى ما ننبّه على غلطة،
/// وبعد التنبيه فترة تهدئة (cooldown) لنفس المجموعة
struct AlertGate {
    var threshold: Double
    var cooldown: Double
    var hitsNeeded: Int
    var window: Double
    private(set) var recent: [String: [Double]] = [:]
    private(set) var lastFired: [String: Double] = [:]

    init(threshold: Double, cooldown: Double, hitsNeeded: Int = 2, window: Double = 3) {
        self.threshold = threshold
        self.cooldown = cooldown
        self.hitsNeeded = max(1, hitsNeeded)
        self.window = window
    }

    mutating func feed(_ key: String, conf: Double, at t: Double) -> Bool {
        guard conf >= threshold else { return false }
        var arr = (recent[key] ?? []).filter { t >= $0 && t - $0 <= window }
        arr.append(t)
        recent[key] = arr
        if arr.count < hitsNeeded { return false }
        if let lf = lastFired[key], t - lf < cooldown { return false }
        lastFired[key] = t
        recent[key] = []
        return true
    }

    func remaining(_ key: String, at t: Double) -> Double {
        guard let lf = lastFired[key] else { return 0 }
        return max(0, cooldown - (t - lf))
    }

    mutating func reset() {
        recent = [:]
        lastFired = [:]
    }
}

/// حدث صوتيّ مجمَّع (عدّة إطارات متتالية لنفس الصوت = حدث واحد)
struct SoundEvent: Codable, Identifiable, Equatable {
    var id: String
    var sound: String
    var start: Double
    var end: Double
    var peak: Double
    var db: Double
    var clip: String?

    var duration: Double { max(0, end - start) }
}

struct TrackOut: Equatable {
    var started: [SoundEvent] = []
    var closed: [SoundEvent] = []
}

/// يجمع الإطارات الحيّة إلى أحداث: نفس الصوت إذا رجع خلال gap ثانية يكمّل نفس الحدث
struct EventTracker {
    var threshold: Double
    var gap: Double
    var ignore: Set<String>
    private(set) var open: [String: SoundEvent] = [:]

    static let defaultIgnore: Set<String> = ["silence", "noise", "white_noise", "pink_noise", "static", "hum", "mains_hum"]

    init(threshold: Double = 0.55, gap: Double = 2.5, ignore: Set<String> = EventTracker.defaultIgnore) {
        self.threshold = threshold
        self.gap = gap
        self.ignore = ignore
    }

    static func eventId(_ sound: String, _ t: Double) -> String {
        "\(sound)-\(Int((t * 1000).rounded()))"
    }

    mutating func feed(_ hits: [Hit], at t: Double, db: Double) -> TrackOut {
        var out = TrackOut()
        for h in hits where h.conf >= threshold && !ignore.contains(h.id) {
            if var e = open[h.id] {
                e.end = t
                e.peak = max(e.peak, h.conf)
                e.db = max(e.db, db)
                open[h.id] = e
            } else {
                let e = SoundEvent(id: EventTracker.eventId(h.id, t), sound: h.id, start: t, end: t, peak: h.conf, db: db, clip: nil)
                open[h.id] = e
                out.started.append(e)
            }
        }
        out.started.sort { $0.sound < $1.sound }
        out.closed = close(at: t)
        return out
    }

    /// يسكّر الأحداث اللي انقطع صوتها أكثر من gap
    mutating func close(at t: Double) -> [SoundEvent] {
        var out: [SoundEvent] = []
        for (k, e) in open where t - e.end > gap {
            out.append(e)
            open[k] = nil
        }
        return out.sorted { a, b in a.start == b.start ? a.sound < b.sound : a.start < b.start }
    }

    /// يسكّر كلّشي (عند الإيقاف)
    mutating func flush() -> [SoundEvent] {
        let out = open.values.sorted { a, b in a.start == b.start ? a.sound < b.sound : a.start < b.start }
        open = [:]
        return out
    }
}

/// منظّم المقاطع: ما نسجّل مقطعين متقاربين، وفي حدّ أعلى بالجلسة
struct ClipThrottle {
    var minGap: Double
    var maxCount: Int
    private(set) var last: Double = -1e18
    private(set) var count = 0

    init(minGap: Double, maxCount: Int) {
        self.minGap = minGap
        self.maxCount = maxCount
    }

    mutating func allow(at t: Double) -> Bool {
        guard count < maxCount, t - last >= minGap else { return false }
        last = t
        count += 1
        return true
    }
}
