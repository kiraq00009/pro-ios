import Foundation

// الإحصاءات (مسافة/معدّل/أقسام الكيلو/الارتفاع/السعرات) + محرّك الجولة الكامل + سجلّ الجولة

/// نقطة على منحنى الجولة: المسافة التراكميّة والزمن الفعّال (بلا وقت الإيقاف)
struct DT: Codable, Equatable {
    var d: Double
    var t: Double
}

enum Stats {
    /// الزمن لكلّ وحدة (افتراضيًّا كيلو) بالاستيفاء عند نقطة العبور
    static func splits(_ prof: [DT], every unit: Double = 1000) -> [Double] {
        guard prof.count > 1 else { return [] }
        var out: [Double] = []
        var lastT = prof[0].t
        var k = 1
        for i in 1..<prof.count {
            let a = prof[i - 1], b = prof[i]
            while b.d >= Double(k) * unit {
                let target = Double(k) * unit
                let frac = b.d > a.d ? max(0, min(1, (target - a.d) / (b.d - a.d))) : 1
                let tt = a.t + (b.t - a.t) * frac
                out.append(tt - lastT)
                lastT = tt
                k += 1
            }
        }
        return out
    }

    /// أسرع زمن لأيّ مقطع متّصل بطول معيّن (أسرع كيلو، أسرع 5 كم…)
    static func fastest(_ prof: [DT], meters: Double) -> Double? {
        guard let last = prof.last, last.d >= meters, prof.count > 1 else { return nil }
        var best = Double.infinity
        var i = 0
        for j in 1..<prof.count {
            let target = prof[j].d - meters
            if target < 0 { continue }
            while i + 1 < j && prof[i + 1].d <= target { i += 1 }
            let a = prof[i], b = prof[i + 1]
            let tt = b.d > a.d ? a.t + (b.t - a.t) * max(0, min(1, (target - a.d) / (b.d - a.d))) : a.t
            best = min(best, prof[j].t - tt)
        }
        return best.isFinite ? best : nil
    }

    /// صعود/نزول بعتبة (حتى ضجيج الارتفاع ما ينحسب صعود)
    static func elevation(_ alts: [Double], threshold: Double = 3) -> (gain: Double, loss: Double) {
        guard var ref = alts.first else { return (0, 0) }
        var gain = 0.0, loss = 0.0
        for a in alts.dropFirst() {
            if a - ref >= threshold { gain += a - ref; ref = a } else if ref - a >= threshold { loss += ref - a; ref = a }
        }
        return (gain, loss)
    }

    /// ثواني لكلّ كيلو
    static func pace(seconds: Double, meters: Double) -> Double { meters > 0 ? seconds / (meters / 1000) : 0 }

    static func kmh(seconds: Double, meters: Double) -> Double { seconds > 0 ? meters / seconds * 3.6 : 0 }

    static func paceText(_ s: Double) -> String {
        guard s.isFinite, s > 0, s < 3600 else { return "–:––" }
        let v = Int(s.rounded())
        return "\(v / 60):" + String(format: "%02d", v % 60)
    }

    static func durationText(_ s: Double) -> String {
        let v = max(0, Int(s.rounded(.down)))
        let h = v / 3600, m = (v % 3600) / 60, sec = v % 60
        if h > 0 { return "\(h):" + String(format: "%02d:%02d", m, sec) }
        return "\(m):" + String(format: "%02d", sec)
    }

    static func calories(_ a: Activity, weightKg: Double, seconds: Double, meters: Double) -> Double {
        guard seconds > 0 else { return 0 }
        let met = a.met(kmh: kmh(seconds: seconds, meters: meters))
        return met * weightKg * seconds / 3600
    }

    /// تقليل نقاط المسار مع الحفاظ على البداية والنهاية
    static func downsample(_ c: [Coord], max n: Int) -> [Coord] {
        guard c.count > n, n >= 2 else { return c }
        var out: [Coord] = []
        let step = Double(c.count - 1) / Double(n - 1)
        for i in 0..<n { out.append(c[min(c.count - 1, Int((Double(i) * step).rounded()))]) }
        return out
    }
}

struct Session: Codable, Identifiable, Equatable {
    var id: String
    var activity: Activity
    var start: Double
    var end: Double
    var active: Double
    var distance: Double
    var elevGain: Double
    var calories: Double
    var route: [[Coord]]
    var splits: [Double]
    var cells: [Hex]
    var newCells: Int
    var loops: Int
    var biggestLoop: Double
    var best1k: Double?
    var best5k: Double?

    var pace: Double { Stats.pace(seconds: active, meters: distance) }
    var kmh: Double { Stats.kmh(seconds: active, meters: distance) }
}

/// نتيجة كلّ قراءة GPS داخل المحرّك
struct Update {
    var accepted = false
    var point: TrackPoint? = nil
    var newCells: [Hex] = []
    var touched = 0
    var loop: [P]? = nil
    var loopCells = 0
    var km: Int? = nil
}

/// محرّك الجولة: فلتر → مسافة → خلايا → دوائر → كيلومترات. نفسه يشتغل بالتطبيق وبالاختبارات وبالبيانات التجريبيّة
struct Engine {
    let grid: HexGrid
    let activity: Activity
    var filter: GPSFilter
    var detector = LoopDetector()
    var gate: Double = 5
    private(set) var segments: [[TrackPoint]] = []
    private(set) var profile: [DT] = []
    private(set) var distance: Double = 0
    private(set) var activeT: Double = 0
    private(set) var touched: [Hex] = []
    private var touchedSet: Set<Hex> = []
    private(set) var newCells = 0
    private(set) var loops = 0
    private(set) var biggestLoop = 0.0
    private(set) var lastLoop: [P] = []
    private var anchorPt: TrackPoint? = nil
    private var lastXY: P? = nil
    private var nextKm = 1

    init(grid: HexGrid, activity: Activity) {
        self.grid = grid
        self.activity = activity
        self.filter = GPSFilter(maxSpeed: activity.maxSpeed)
    }

    var pointCount: Int { segments.reduce(0) { $0 + $1.count } }

    mutating func newSegment() {
        if let last = segments.last, last.isEmpty { return }
        segments.append([])
        anchorPt = nil
        lastXY = nil
        filter.reset()
        detector.breakPath()
    }

    private mutating func take(_ h: Hex, _ t: Double, _ terr: inout Territory, _ u: inout Update) -> Bool {
        guard touchedSet.insert(h).inserted else { return false }
        touched.append(h)
        u.touched += 1
        if terr.capture(h, at: t) { newCells += 1; u.newCells.append(h) }
        return true
    }

    mutating func push(_ f: GPSFix, into terr: inout Territory) -> Update {
        var u = Update()
        if segments.isEmpty { newSegment() }
        guard let p = filter.push(f) else { return u }
        u.accepted = true
        u.point = p
        if let a = anchorPt {
            let d = Geo.haversine(a.coord, p.coord)
            if d < gate { return u }       // رجفة بمكانك — ما تنحسب
            distance += d
            activeT += max(0, p.t - a.t)
        }
        anchorPt = p
        segments[segments.count - 1].append(p)
        profile.append(DT(d: distance, t: activeT))

        let xy = grid.proj.xy(p.coord)
        let path: [Hex] = lastXY.map { grid.cells(from: $0, to: xy) } ?? [grid.hex(at: xy)]
        lastXY = xy
        for h in path { _ = take(h, p.t, &terr, &u) }

        if let poly = detector.add(xy) {
            loops += 1
            let a = Geo.polygonArea(poly)
            biggestLoop = max(biggestLoop, a)
            lastLoop = poly
            var c = 0
            let inside = grid.cellsInside(poly)
            for h in inside {
                if take(h, p.t, &terr, &u) { c += 1 }
            }
            u.loop = poly
            u.loopCells = c
        }

        if distance >= Double(nextKm) * 1000 {
            u.km = nextKm
            nextKm = Int(distance / 1000) + 1
        }
        return u
    }

    /// معدّل السرعة الحاليّ من آخر ~250 م
    var currentPace: Double {
        guard let last = profile.last, profile.count > 2 else { return 0 }
        var i = profile.count - 1
        while i > 0 && last.d - profile[i].d < 250 { i -= 1 }
        let d = last.d - profile[i].d, t = last.t - profile[i].t
        return d > 30 ? t / (d / 1000) : 0
    }

    func session(id: String, start: Double, end: Double, active: Double? = nil, weightKg: Double) -> Session {
        let act = active ?? activeT
        let route: [[Coord]] = segments.filter { $0.count > 1 }.map { seg in
            Stats.downsample(seg.map { $0.coord }, max: max(2, 500 / max(1, segments.count)))
        }
        let alts = segments.flatMap { $0.map { $0.alt } }
        return Session(
            id: id, activity: activity, start: start, end: end, active: act, distance: distance,
            elevGain: Stats.elevation(alts).gain,
            calories: Stats.calories(activity, weightKg: weightKg, seconds: act, meters: distance),
            route: route, splits: Stats.splits(profile), cells: touched, newCells: newCells,
            loops: loops, biggestLoop: biggestLoop,
            best1k: Stats.fastest(profile, meters: 1000), best5k: Stats.fastest(profile, meters: 5000))
    }
}
