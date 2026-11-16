import Foundation

// التتبّع: قراءات GPS، فلتر التنعيم ورفض القفزات، كاشف الدوائر، والإقليم

struct GPSFix: Codable, Equatable {
    var t: Double          // ثواني منذ 1970
    var lat: Double
    var lon: Double
    var alt: Double
    var acc: Double        // الدقّة الأفقيّة بالمتر (سالبة = غير صالحة)
    var vacc: Double       // الدقّة العموديّة
}

struct TrackPoint: Codable, Equatable {
    var t: Double
    var lat: Double
    var lon: Double
    var alt: Double
    var coord: Coord { Coord(lat, lon) }
}

enum Activity: String, Codable, CaseIterable, Identifiable {
    case walk, run, cycle
    var id: String { rawValue }

    var title: String {
        switch self {
        case .walk: return "مشي"
        case .run: return "ركض"
        case .cycle: return "درّاجة"
        }
    }

    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .run: return "figure.run"
        case .cycle: return "bicycle"
        }
    }

    /// أعلى سرعة معقولة (م/ث) — أيّ قفزة أسرع منها تُرفض
    var maxSpeed: Double {
        switch self {
        case .walk: return 7
        case .run: return 12
        case .cycle: return 30
        }
    }

    /// المكافئ الأيضيّ حسب السرعة كم/س
    func met(kmh: Double) -> Double {
        switch self {
        case .walk:
            if kmh < 3.5 { return 2.8 }
            if kmh < 5 { return 3.5 }
            if kmh < 6.5 { return 4.8 }
            return 6.0
        case .run:
            return max(6.0, kmh * 1.02)
        case .cycle:
            if kmh < 16 { return 4.0 }
            if kmh < 20 { return 6.8 }
            if kmh < 25 { return 8.0 }
            return 10.0
        }
    }
}

/// فلتر كالمان مبسّط على خطّ العرض/الطول + رفض القراءات الرديئة والقفزات المستحيلة
struct GPSFilter {
    var maxAcc: Double = 35
    var maxSpeed: Double
    var noise: Double = 3          // ضجيج الحركة م/ث
    private(set) var lat = 0.0
    private(set) var lon = 0.0
    private(set) var alt = 0.0
    private(set) var variance = -1.0
    private(set) var t = 0.0
    private(set) var streak = 0
    private(set) var rejected = 0

    init(maxSpeed: Double) { self.maxSpeed = maxSpeed }

    var ready: Bool { variance >= 0 }

    mutating func reset() { variance = -1; streak = 0 }

    private mutating func seed(_ f: GPSFix) -> TrackPoint {
        lat = f.lat; lon = f.lon; alt = f.alt; t = f.t
        variance = f.acc * f.acc
        streak = 0
        return TrackPoint(t: t, lat: lat, lon: lon, alt: alt)
    }

    mutating func push(_ f: GPSFix) -> TrackPoint? {
        guard f.acc > 0, f.acc <= maxAcc else { rejected += 1; return nil }
        if variance < 0 { return seed(f) }
        let dt = f.t - t
        guard dt > 0 else { return nil }
        let jump = Geo.haversine(Coord(lat, lon), Coord(f.lat, f.lon))
        if (jump - f.acc) / dt > maxSpeed {
            streak += 1; rejected += 1
            // خمس قراءات متتالية بعيدة = انتقال حقيقيّ (نفق مثلًا) ⇒ نبدأ من جديد
            if streak >= 5 { return seed(f) }
            return nil
        }
        streak = 0
        variance += dt * noise * noise
        let k = variance / (variance + f.acc * f.acc)
        lat += k * (f.lat - lat)
        lon += k * (f.lon - lon)
        variance *= (1 - k)
        t = f.t
        if f.vacc > 0 && f.vacc < 30 { alt += 0.35 * (f.alt - alt) }
        return TrackPoint(t: t, lat: lat, lon: lon, alt: alt)
    }
}

/// يكتشف لمّا يرجع المسار قرب نقطة سابقة ويكوّن دائرة مقفولة — بحث مكانيّ بالدلاء ومساحة بالمجاميع التراكميّة
struct LoopDetector {
    var radius: Double = 35
    var minLength: Double = 250
    var minArea: Double = 6000

    private struct BK: Hashable { let x: Int; let y: Int }
    private(set) var pts: [P] = []
    private var cum: [Double] = []
    private var cross: [Double] = []
    private var buckets: [BK: [Int]] = [:]
    private(set) var anchor = 0

    init() {}
    init(radius: Double, minLength: Double, minArea: Double) {
        self.radius = radius; self.minLength = minLength; self.minArea = minArea
    }

    private func key(_ p: P) -> BK { BK(x: Int((p.x / radius).rounded(.down)), y: Int((p.y / radius).rounded(.down))) }

    /// بعد الإيقاف المؤقّت ما نربط دائرة عبر الفجوة
    mutating func breakPath() { anchor = pts.count }

    func area(_ i: Int, _ n: Int) -> Double {
        let a = pts[n], b = pts[i]
        return abs(cross[n] - cross[i] + (a.x * b.y - b.x * a.y)) / 2
    }

    /// يرجّع مضلّع الدائرة إذا انقفلت هسه
    mutating func add(_ p: P) -> [P]? {
        if let last = pts.last {
            cum.append((cum.last ?? 0) + last.dist(p))
            cross.append((cross.last ?? 0) + (last.x * p.y - p.x * last.y))
        } else {
            cum.append(0); cross.append(0)
        }
        pts.append(p)
        let n = pts.count - 1
        let k = key(p)
        var best: Int? = nil
        for dx in -1...1 {
            for dy in -1...1 {
                guard let list = buckets[BK(x: k.x + dx, y: k.y + dy)] else { continue }
                for i in list where i >= anchor && i < n {
                    if let b = best, i >= b { continue }
                    if cum[n] - cum[i] < minLength { continue }
                    if pts[i].dist(p) > radius { continue }
                    if area(i, n) < minArea { continue }
                    best = i
                }
            }
        }
        buckets[k, default: []].append(n)
        guard let i = best else { return nil }
        anchor = n
        return Array(pts[i...n])
    }
}

struct CellRec: Codable, Equatable {
    var q: Int
    var r: Int
    var first: Double
    var last: Double
    var visits: Int
}

/// الإقليم: كلّ خليّة مأخوذة مع آخر زيارة — تذبل خلال 14 يوم إلّا إذا رجعت لها
struct Territory {
    static let lifetime: Double = 14 * 86400
    private(set) var cells: [Hex: CellRec] = [:]

    init() {}
    init(records: [CellRec]) { for c in records { cells[Hex(c.q, c.r)] = c } }

    var records: [CellRec] { Array(cells.values) }
    var everCount: Int { cells.count }

    static func freshness(age: Double) -> Double { max(0, min(1, 1 - age / lifetime)) }

    func freshness(_ h: Hex, now: Double) -> Double {
        guard let c = cells[h] else { return 0 }
        return Territory.freshness(age: now - c.last)
    }

    func isActive(_ h: Hex, now: Double) -> Bool { freshness(h, now: now) > 0 }

    /// يرجّع true إذا الخليّة جديدة (أو كانت ذابلة وانرجعت)
    @discardableResult
    mutating func capture(_ h: Hex, at t: Double) -> Bool {
        if var c = cells[h] {
            let wasActive = Territory.freshness(age: t - c.last) > 0
            c.last = max(c.last, t)
            c.visits += 1
            if !wasActive { c.first = t }
            cells[h] = c
            return !wasActive
        }
        cells[h] = CellRec(q: h.q, r: h.r, first: t, last: t, visits: 1)
        return true
    }

    func active(now: Double) -> [(Hex, Double)] {
        var out: [(Hex, Double)] = []
        for (h, c) in cells {
            let f = Territory.freshness(age: now - c.last)
            if f > 0 { out.append((h, f)) }
        }
        return out
    }

    func activeCount(now: Double) -> Int { cells.values.filter { now - $0.last < Territory.lifetime }.count }

    /// خلايا راح تذبل خلال كم يوم
    func fading(now: Double, withinDays d: Double) -> Int {
        cells.values.filter { (c: CellRec) -> Bool in
            let left = Territory.lifetime - (now - c.last)
            return left > 0 && left <= d * 86400
        }.count
    }

    func areaKm2(now: Double, cellArea: Double) -> Double { Double(activeCount(now: now)) * cellArea / 1_000_000 }

    /// نشيل الخلايا الميّتة من زمان حتى الملف يبقى صغير
    mutating func prune(now: Double, olderThanDays d: Double = 120) {
        cells = cells.filter { now - $0.value.last < d * 86400 }
    }
}
