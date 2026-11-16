import Foundation

struct LevelSample: Codable, Equatable {
    var t: Double
    var db: Double
}

struct SoundCount: Equatable {
    var sound: String
    var count: Int
    var seconds: Double
}

/// تجميع السجلّ: لكلّ صوت، لكلّ ساعة، لكلّ يوم
enum Stats {
    /// الساعة المحليّة 0..23 لوقت (ثواني منذ 1970) مع فرق التوقيت بالثواني
    static func hourOf(_ t: Double, tz: Int) -> Int {
        let h = Int(floor((t + Double(tz)) / 3600))
        return ((h % 24) + 24) % 24
    }

    static func dayKey(_ t: Double, tz: Int) -> Int {
        Int(floor((t + Double(tz)) / 86400))
    }

    /// بداية اليوم المحليّ (ثواني منذ 1970)
    static func dayStart(_ t: Double, tz: Int) -> Double {
        Double(dayKey(t, tz: tz)) * 86400 - Double(tz)
    }

    static func hourly(_ events: [SoundEvent], tz: Int) -> [Int] {
        var b = [Int](repeating: 0, count: 24)
        for e in events { b[hourOf(e.start, tz: tz)] += 1 }
        return b
    }

    static func counts(_ events: [SoundEvent]) -> [SoundCount] {
        var m: [String: SoundCount] = [:]
        for e in events {
            var c = m[e.sound] ?? SoundCount(sound: e.sound, count: 0, seconds: 0)
            c.count += 1
            c.seconds += e.duration
            m[e.sound] = c
        }
        return m.values.sorted { a, b in a.count == b.count ? a.sound < b.sound : a.count > b.count }
    }

    /// أنشط ساعة (أوّل وحدة إذا تعادلت)، nil إذا ماكو شي
    static func busiestHour(_ h: [Int]) -> Int? {
        var best = -1, bi = -1
        for (i, v) in h.enumerated() where v > best { best = v; bi = i }
        return best > 0 ? bi : nil
    }

    static func within(_ events: [SoundEvent], from: Double, to: Double) -> [SoundEvent] {
        events.filter { $0.start >= from && $0.start < to }
    }

    /// عدد الأحداث لكلّ يوم لآخر n أيام (الأقدم أوّلًا) — اليوم الأخير يحتوي now
    static func daily(_ events: [SoundEvent], days n: Int, now: Double, tz: Int) -> [Int] {
        let k = max(1, n)
        var out = [Int](repeating: 0, count: k)
        let today = dayKey(now, tz: tz)
        for e in events {
            let d = today - dayKey(e.start, tz: tz)
            if d >= 0 && d < k { out[k - 1 - d] += 1 }
        }
        return out
    }

    /// متوسّط طاقيّ لكلّ فترة بين start و end (nil للفترة الفارغة)
    static func bins(_ samples: [LevelSample], start: Double, end: Double, bin: Double) -> [Double?] {
        guard end > start, bin > 0 else { return [] }
        let n = Int(ceil((end - start) / bin))
        var groups = [[Double]](repeating: [], count: n)
        for s in samples where s.t >= start && s.t < end {
            let i = min(n - 1, Int((s.t - start) / bin))
            groups[i].append(s.db)
        }
        return groups.map { $0.isEmpty ? nil : Level.leq($0) }
    }

    static func durationText(_ s: Double) -> String {
        let m = Int((s / 60).rounded())
        if m < 1 { return "\(Int(s.rounded())) ث" }
        if m < 60 { return "\(m) د" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) س" : "\(h) س \(r) د"
    }
}
