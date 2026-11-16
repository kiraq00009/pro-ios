import Foundation
import SwiftUI
import CoreLocation

/// خليّة جاهزة للرسم على الخريطة
struct MapHex {
    let corners: [CLLocationCoordinate2D]
    let tone: Int       // 0 = مأخوذة بهالجولة، 1…4 = طازجة → ذابلة
}

extension Coord {
    var cl: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

enum MasarTone {
    static func of(_ fresh: Double) -> Int {
        if fresh > 0.75 { return 1 }
        if fresh > 0.5 { return 2 }
        if fresh > 0.25 { return 3 }
        return 4
    }
}

private struct SaveFile: Codable {
    var sessions: [Session]
    var cells: [CellRec]
    var origin: Coord?
}

/// كلّ بيانات التطبيق: الجولات، الإقليم، والإعدادات — محفوظة بملفّ JSON على الجهاز
final class MasarStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var territory = Territory()
    @Published private(set) var origin: Coord? = nil
    @Published private(set) var revision = 0
    @Published private(set) var mapHexes: [MapHex] = []
    @Published var justEarned: [Badge] = []

    @Published var weight: Double = 70 { didSet { UserDefaults.standard.set(weight, forKey: "ms_weight") } }
    @Published var weeklyGoal: Double = 15 { didSet { UserDefaults.standard.set(weeklyGoal, forKey: "ms_goal") } }
    @Published var voiceOn: Bool = true { didSet { UserDefaults.standard.set(voiceOn, forKey: "ms_voice") } }
    @Published var keepAwake: Bool = true { didSet { UserDefaults.standard.set(keepAwake, forKey: "ms_keepawake") } }

    private var undo: (id: String, terr: Territory)? = nil
    private(set) var demo = false
    var nowOverride: Double? = nil

    var now: Double { nowOverride ?? Date().timeIntervalSince1970 }
    var tz: Double { Double(TimeZone.current.secondsFromGMT()) }
    var grid: HexGrid { HexGrid(proj: Projection(origin: origin ?? Demo.center)) }

    private var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("masar.json")
    }

    init() {
        let d = UserDefaults.standard
        if let w = d.object(forKey: "ms_weight") as? Double { weight = w }
        if let g = d.object(forKey: "ms_goal") as? Double { weeklyGoal = g }
        if let v = d.object(forKey: "ms_voice") as? Bool { voiceOn = v }
        if let k = d.object(forKey: "ms_keepawake") as? Bool { keepAwake = k }
        if Shot.on { loadDemo() } else { load() }
    }

    // MARK: حفظ وتحميل

    private func load() {
        guard let data = try? Data(contentsOf: url), let f = try? JSONDecoder().decode(SaveFile.self, from: data) else { rebuild(); return }
        sessions = f.sessions.sorted { $0.start > $1.start }
        territory = Territory(records: f.cells)
        origin = f.origin
        territory.prune(now: now)
        rebuild()
    }

    func save() {
        guard !demo else { return }
        let f = SaveFile(sessions: sessions, cells: territory.records, origin: origin)
        let u = url
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(f) { try? data.write(to: u, options: .atomic) }
        }
    }

    func loadDemo() {
        demo = true
        let t = Date().timeIntervalSince1970
        nowOverride = t
        let h = Demo.history(now: t, tz: tz, weight: weight)
        sessions = h.sessions
        territory = h.territory
        origin = Demo.center
        rebuild()
    }

    private func rebuild() {
        let g = grid, n = now
        var out: [MapHex] = []
        for (h, f) in territory.active(now: n) {
            out.append(MapHex(corners: g.cornerCoords(h).map { (c: Coord) -> CLLocationCoordinate2D in c.cl }, tone: MasarTone.of(f)))
        }
        mapHexes = out
        revision += 1
    }

    func refresh() { rebuild() }

    func ensureOrigin(_ c: Coord) {
        if origin == nil { origin = c; save() }
    }

    // MARK: الجولات

    func finish(_ s: Session, territory newTerr: Territory) {
        let before = earnedIDs
        undo = (s.id, territory)
        territory = newTerr
        sessions.insert(s, at: 0)
        let after = earnedIDs
        justEarned = Badges.all.filter { after.contains($0.id) && !before.contains($0.id) }
        rebuild()
        save()
    }

    func delete(_ id: String) {
        sessions.removeAll { $0.id == id }
        if let u = undo, u.id == id { territory = u.terr; undo = nil }
        rebuild()
        save()
    }

    func resetAll() {
        sessions = []
        territory = Territory()
        origin = nil
        undo = nil
        rebuild()
        save()
    }

    // MARK: أرقام مشتقّة

    var areaKm2: Double { territory.areaKm2(now: now, cellArea: grid.cellArea) }
    var activeCells: Int { territory.activeCount(now: now) }
    var fadingSoon: Int { territory.fading(now: now, withinDays: 3) }
    var totalDistance: Double { sessions.reduce(0) { $0 + $1.distance } }
    var totalTime: Double { sessions.reduce(0) { $0 + $1.active } }
    var totalCalories: Double { sessions.reduce(0) { $0 + $1.calories } }
    var today: Int { Days.index(now, tz: tz) }
    var streak: (current: Int, best: Int) { Days.streak(Set(sessions.map { Days.index($0.start, tz: tz) }), today: today) }
    var firstWeekday: Int { Calendar.current.firstWeekday - 1 }
    var weekDays: [Double] { Week.days(sessions, today: today, firstWeekday: firstWeekday, tz: tz) }
    var weekKm: Double { weekDays.reduce(0, +) / 1000 }
    var xp: Int { Levels.xp(sessions) }
    var level: (level: Int, into: Int, need: Int) { Levels.level(xp) }
    var records: Records { Records.of(sessions) }

    var earnedIDs: Set<String> {
        Badges.earned(BadgeContext(sessions: sessions, areaKm2: areaKm2, everCells: territory.everCount, bestStreak: streak.best, tz: tz))
    }

    /// خلايا جولة معيّنة جاهزة للرسم
    func hexes(for s: Session) -> [MapHex] {
        let g = grid
        return s.cells.map { (h: Hex) -> MapHex in MapHex(corners: g.cornerCoords(h).map { $0.cl }, tone: 1) }
    }
}
