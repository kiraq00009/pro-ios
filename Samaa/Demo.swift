import SwiftUI

/// بيانات تجريبيّة لوضع التصوير (بدون مايك وبدون صلاحيّات)
struct DemoRNG {
    var s: UInt64
    mutating func next() -> UInt64 { s = s &* 6364136223846793005 &+ 1442695040888963407; return s }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
    mutating func pick<T>(_ xs: [T]) -> T { xs[Int(next() % UInt64(xs.count))] }
}

extension Store {
    func fillDemo() {
        var r = DemoRNG(s: 2026)
        let now = nowT()
        let tz = localTZ
        let today = Stats.dayStart(now, tz: tz)

        // ── سجلّ ٧ أيام
        let pool: [(String, Int)] = [
            ("speech", 30), ("music", 12), ("laughter", 7), ("dog_bark", 6), ("door_bell", 3), ("knock", 3),
            ("car_horn", 4), ("water_tap_faucet", 5), ("dishes_pots_pans", 6), ("typing", 6), ("cat_meow", 3),
            ("vacuum_cleaner", 2), ("toilet_flush", 3), ("kettle_whistle", 2), ("bird_chirp_tweet", 4),
            ("car_passing_by", 5), ("baby_crying", 2), ("siren", 1), ("telephone_bell_ringing", 2), ("cough", 3),
        ]
        var bag: [String] = []
        for p in pool { for _ in 0..<p.1 { bag.append(p.0) } }
        let hourW: [Double] = [0.2, 0.1, 0.1, 0.05, 0.05, 0.1, 0.4, 1.0, 1.6, 1.4, 1.2, 1.3, 1.6, 1.4, 1.1, 1.0, 1.2, 1.5, 1.9, 2.2, 2.1, 1.6, 1.0, 0.5]
        let wsum = hourW.reduce(0, +)
        var evs: [SoundEvent] = []
        for d in 0..<7 {
            let base = today - Double(6 - d) * 86400
            let n = 46 + Int(r.next() % 40)
            for _ in 0..<n {
                var u = r.unit() * wsum
                var h = 0
                for (i, w) in hourW.enumerated() { if u < w { h = i; break }; u -= w; h = i }
                let t = base + Double(h) * 3600 + r.range(0, 3599)
                if t > now - 60 { continue }
                let s = r.pick(bag)
                let dur = s == "speech" || s == "music" ? r.range(4, 90) : r.range(1, 8)
                evs.append(SoundEvent(id: EventTracker.eventId(s, t), sound: s, start: t, end: t + dur, peak: r.range(0.58, 0.97),
                                      db: r.range(42, 78), clip: r.unit() < 0.25 ? "demo.caf" : nil))
            }
        }
        events = evs.sorted { $0.start < $1.start }

        // ── تنبيهات
        let al: [(String, String, Double, Double)] = [
            ("door", "door_bell", 0.93, now - 1500), ("baby", "baby_crying", 0.88, now - 3 * 3600),
            ("dog", "dog_bark", 0.81, now - 5 * 3600 - 400), ("water", "water_tap_faucet", 0.77, now - 26 * 3600),
            ("door", "knock", 0.84, now - 29 * 3600), ("smoke", "smoke_detector", 0.95, now - 52 * 3600),
            ("baby", "baby_crying", 0.9, now - 74 * 3600), ("dog", "dog_bark", 0.79, now - 98 * 3600),
        ]
        alerts = al.map { AlertRec(id: UUID().uuidString, group: $0.0, sound: $0.1, conf: $0.2, t: $0.3, clip: "demo.caf") }

        // ── الليالي
        var ns: [SleepSession] = []
        for k in 0..<6 {
            let start = today - Double(k) * 86400 - 3600 * (0.3 + r.range(0, 1.2))
            let len = 3600 * r.range(6.4, 8.1)
            ns.append(demoNight(&r, start: start, len: len, snoreLevel: k == 0 ? 1.0 : r.range(0.2, 1.6)))
        }
        nights = ns

        // ── الحيّ
        watched = ["baby", "door", "smoke", "glass", "dog", "water"]
        live.top = [Hit(id: "speech", conf: 0.82), Hit(id: "laughter", conf: 0.51), Hit(id: "music", conf: 0.36),
                    Hit(id: "dishes_pots_pans", conf: 0.22), Hit(id: "cat_meow", conf: 0.13)]
        var tr: [Double] = []
        for i in 0..<150 {
            let x = Double(i)
            tr.append(54 + 7 * sin(x / 9) + 4 * sin(x / 2.7) + (i > 110 && i < 122 ? 14 : 0) + r.range(-2, 2))
        }
        live.trail = tr
        live.db = tr.last ?? 58
        var ex = Exposure()
        for i in 0..<300 {
            let l = 52 + 12 * sin(Double(i) / 17) + (i % 47 == 0 ? 30 : 0) + r.range(-4, 4)
            ex.add(level: l, seconds: 62)
        }
        live.exposure = ex
        heard = ["speech": 14, "laughter": 5, "music": 4, "dishes_pots_pans": 3, "door_bell": 1, "cat_meow": 2]
        listenStart = now - 1520
        mic = .granted
        running = true

        if Shot.name == "alert" {
            alert = LiveAlert(id: "demo", group: "baby", sound: "baby_crying", conf: 0.91, t: now, clip: nil)
        }
    }

    private func demoNight(_ r: inout DemoRNG, start: Double, len: Double, snoreLevel: Double) -> SleepSession {
        var lv: [LevelSample] = []
        var evs: [SoundEvent] = []
        let mins = Int(len / 60)
        // فترات شخير
        var snoreWindows: [(Int, Int)] = []
        let nw = 2 + Int(r.next() % 3)
        for _ in 0..<nw {
            let a = Int(r.range(40, Double(max(60, mins - 60))))
            snoreWindows.append((a, a + Int(r.range(12, 34) * snoreLevel) + 4))
        }
        for m in 0..<mins {
            let t = start + Double(m) * 60
            var db = 31 + 3 * sin(Double(m) / 23) + r.range(-1.5, 1.5)
            let inSnore = snoreWindows.contains { m >= $0.0 && m < $0.1 }
            if inSnore {
                db += r.range(8, 14)
                if r.unit() < 0.55 {
                    let s = t + r.range(0, 40)
                    evs.append(SoundEvent(id: EventTracker.eventId("snoring", s), sound: "snoring", start: s, end: s + r.range(8, 45),
                                          peak: r.range(0.6, 0.95), db: db + 4, clip: r.unit() < 0.4 ? "demo.caf" : nil))
                }
            }
            if r.unit() < 0.012 {
                let s = t + r.range(0, 50)
                evs.append(SoundEvent(id: EventTracker.eventId("cough", s), sound: "cough", start: s, end: s + r.range(1, 3), peak: r.range(0.6, 0.9), db: db + 18, clip: "demo.caf"))
                db += 6
            }
            if r.unit() < 0.006 {
                let s = t + r.range(0, 50)
                let snd = r.pick(["speech", "whispering", "laughter"])
                evs.append(SoundEvent(id: EventTracker.eventId(snd, s), sound: snd, start: s, end: s + r.range(2, 7), peak: r.range(0.55, 0.85), db: db + 10, clip: "demo.caf"))
            }
            if r.unit() < 0.008 {
                let s = t + r.range(0, 50)
                let snd = r.pick(["car_passing_by", "dog_bark", "door_slam", "siren"])
                evs.append(SoundEvent(id: EventTracker.eventId(snd, s), sound: snd, start: s, end: s + r.range(2, 12), peak: r.range(0.55, 0.9), db: db + 20, clip: nil))
                db += 16
            }
            lv.append(LevelSample(t: t, db: db))
        }
        return SleepSession(id: UUID().uuidString, start: start, end: start + len, events: evs.sorted { $0.start < $1.start }, levels: lv)
    }
}
