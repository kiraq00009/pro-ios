import Foundation

// بيانات تجريبيّة حتميّة: مسارات حول بلوكات مدينة شبكيّة، تمرّ من نفس المحرّك الحقيقيّ

struct MRng: RandomNumberGenerator {
    private var s: UInt64
    init(_ seed: UInt64) { s = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992.0 }
    mutating func gauss() -> Double {
        let u1 = max(1e-12, unit()), u2 = unit()
        return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }
}

enum Demo {
    /// مدينة شبكيّة افتراضيّة (بلوك ≈ 133 م)
    static let center = Coord(41.3925, 2.1620)
    static let block: Double = 133

    /// مستطيل بالبلوكات: (x, y, عرض, ارتفاع) ⇒ نقاط بالمتر تبدأ وترجع لنفس الزاوية
    static func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, laps: Int = 1) -> [P] {
        let b = block
        let c = [P(x * b, y * b), P((x + w) * b, y * b), P((x + w) * b, (y + h) * b), P(x * b, (y + h) * b)]
        var out: [P] = []
        for _ in 0..<max(1, laps) { out.append(contentsOf: c) }
        out.append(c[0])
        return out
    }

    /// يحوّل خطّ نقاط إلى قراءات GPS كلّ dt ثانية بسرعة ثابتة مع ضجيج واقعيّ
    static func fixes(_ way: [P], center: Coord, speed: Double, t0: Double, dt: Double = 2,
                      noise: Double = 3, hill: Double = 10, rng: inout MRng) -> [GPSFix] {
        guard way.count > 1 else { return [] }
        let proj = Projection(origin: center)
        let total = Geo.pathLength(way)
        var out: [GPSFix] = []
        var t = t0, travelled = 0.0
        var seg = 0, segPos = 0.0
        let step = speed * dt
        while seg < way.count - 1 {
            let a = way[seg], b = way[seg + 1]
            let len = a.dist(b)
            if segPos > len { segPos -= len; seg += 1; continue }
            let k = len > 0 ? segPos / len : 0
            let p = P(a.x + (b.x - a.x) * k + rng.gauss() * noise, a.y + (b.y - a.y) * k + rng.gauss() * noise)
            let c = proj.coord(p)
            let alt = 40 + hill * sin(travelled / max(1, total) * 2 * Double.pi * 2) + rng.gauss() * 0.6
            out.append(GPSFix(t: t, lat: c.lat, lon: c.lon, alt: alt, acc: 4 + abs(rng.gauss()) * 2, vacc: 4))
            t += dt * (0.9 + rng.unit() * 0.2)
            segPos += step
            travelled += step
        }
        let end = proj.coord(way[way.count - 1])
        out.append(GPSFix(t: t, lat: end.lat, lon: end.lon, alt: 40, acc: 5, vacc: 4))
        return out
    }

    struct Plan {
        let daysAgo: Int
        let hour: Double
        let activity: Activity
        let way: [P]
    }

    static func plans() -> [Plan] {
        [
            Plan(daysAgo: 24, hour: 18.5, activity: .run, way: rect(-9, 4, 4, 3, laps: 2)),
            Plan(daysAgo: 20, hour: 7.2, activity: .cycle, way: rect(-10, -8, 16, 13, laps: 1)),
            Plan(daysAgo: 16, hour: 19, activity: .walk, way: rect(6, 2, 3, 2)),
            Plan(daysAgo: 12, hour: 6.1, activity: .run, way: rect(-1, -6, 5, 3, laps: 2)),
            Plan(daysAgo: 10, hour: 18, activity: .run, way: rect(0, -2, 3, 3, laps: 3)),
            Plan(daysAgo: 8, hour: 20, activity: .run, way: rect(-4, 2, 5, 3, laps: 2)),
            Plan(daysAgo: 6, hour: 17.5, activity: .walk, way: rect(2, 3, 2, 2)),
            Plan(daysAgo: 5, hour: 22.4, activity: .run, way: rect(2, -5, 4, 4, laps: 2)),
            Plan(daysAgo: 3, hour: 7.5, activity: .cycle, way: rect(-8, -6, 12, 10, laps: 1)),
            Plan(daysAgo: 2, hour: 18.2, activity: .run, way: rect(-6, -3, 6, 5, laps: 2)),
            Plan(daysAgo: 1, hour: 19.3, activity: .walk, way: rect(1, 1, 3, 2)),
            Plan(daysAgo: 0, hour: 6.4, activity: .run, way: rect(-2, -1, 5, 4, laps: 2))
        ]
    }

    static func speed(_ a: Activity, _ rng: inout MRng) -> Double {
        switch a {
        case .walk: return 1.35 + rng.unit() * 0.25
        case .run: return 2.9 + rng.unit() * 0.6
        case .cycle: return 5.6 + rng.unit() * 1.4
        }
    }

    /// تشغيل جولة كاملة على المحرّك
    static func run(_ fixes: [GPSFix], grid: HexGrid, activity: Activity, terr: inout Territory, id: String, weight: Double) -> Session {
        var e = Engine(grid: grid, activity: activity)
        for f in fixes { _ = e.push(f, into: &terr) }
        let start = fixes.first?.t ?? 0, end = fixes.last?.t ?? 0
        return e.session(id: id, start: start, end: end, weightKg: weight)
    }

    /// سجلّ كامل لشهر: جلسات + إقليم — الأحدث أوّلًا
    static func history(center: Coord = Demo.center, now: Double, tz: Double, weight: Double = 72) -> (sessions: [Session], territory: Territory) {
        var rng = MRng(2026)
        let grid = HexGrid(proj: Projection(origin: center))
        var terr = Territory()
        var out: [Session] = []
        let today0 = Double(Days.index(now, tz: tz)) * 86400 - tz
        for (i, p) in plans().enumerated() {
            var start = today0 - Double(p.daysAgo) * 86400 + p.hour * 3600
            let v = speed(p.activity, &rng)
            let dur = Geo.pathLength(p.way) / v
            if start + dur > now - 600 { start = now - dur - 1800 }
            let fx = fixes(p.way, center: center, speed: v, t0: start, rng: &rng)
            out.append(run(fx, grid: grid, activity: p.activity, terr: &terr, id: "demo-\(i)", weight: weight))
        }
        return (out.reversed(), terr)
    }

    /// جولة حيّة نصّها مخلّص: دائرة مقفولة + طريق للدائرة الثانية
    static func live(center: Coord = Demo.center, t0: Double) -> [GPSFix] {
        var rng = MRng(77)
        var way = rect(3, -2, 3, 3)
        way.append(contentsOf: [P(3 * block, -4 * block), P(7 * block, -4 * block), P(7 * block, -1.5 * block)])
        return fixes(way, center: center, speed: 3.1, t0: t0, rng: &rng)
    }
}
