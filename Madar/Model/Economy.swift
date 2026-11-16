import Foundation

/// لون بلا SwiftUI
struct RGB: Equatable, Codable {
    var r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
}

enum CometShape: Int, Codable {
    case orb = 0, star, diamond, ringed, spark, heart, crescent, cube
}

struct CometSkin: Equatable {
    let id: String
    let name: String
    let price: Int
    let core: RGB
    let glow: RGB
    let shape: CometShape
}

struct TrailSkin: Equatable {
    let id: String
    let name: String
    let price: Int
    let colors: [RGB]   // أكثر من لون ⇒ تدرّج متحرّك
    let sparkle: Bool
}

enum Catalog {
    static let comets: [CometSkin] = [
        CometSkin(id: "c0", name: "شهاب", price: 0, core: RGB(1, 1, 1), glow: RGB(0.45, 0.85, 1), shape: .orb),
        CometSkin(id: "c1", name: "جمرة", price: 60, core: RGB(1, 0.92, 0.7), glow: RGB(1, 0.45, 0.15), shape: .orb),
        CometSkin(id: "c2", name: "نجمة", price: 90, core: RGB(1, 0.97, 0.75), glow: RGB(1, 0.8, 0.25), shape: .star),
        CometSkin(id: "c3", name: "ماسة", price: 120, core: RGB(0.85, 1, 1), glow: RGB(0.3, 1, 0.9), shape: .diamond),
        CometSkin(id: "c4", name: "زحل الصغير", price: 150, core: RGB(1, 0.9, 0.75), glow: RGB(0.95, 0.65, 0.4), shape: .ringed),
        CometSkin(id: "c5", name: "شرارة", price: 180, core: RGB(1, 1, 0.85), glow: RGB(0.75, 0.55, 1), shape: .spark),
        CometSkin(id: "c6", name: "قلب", price: 220, core: RGB(1, 0.85, 0.9), glow: RGB(1, 0.3, 0.55), shape: .heart),
        CometSkin(id: "c7", name: "هلال", price: 260, core: RGB(1, 0.98, 0.88), glow: RGB(0.6, 0.75, 1), shape: .crescent),
        CometSkin(id: "c8", name: "مكعّب", price: 300, core: RGB(0.85, 1, 0.8), glow: RGB(0.35, 1, 0.45), shape: .cube),
        CometSkin(id: "c9", name: "سديم", price: 360, core: RGB(1, 0.9, 1), glow: RGB(1, 0.35, 0.95), shape: .orb),
        CometSkin(id: "c10", name: "نجم نيوترونيّ", price: 450, core: RGB(0.9, 0.95, 1), glow: RGB(0.4, 0.5, 1), shape: .spark),
        CometSkin(id: "c11", name: "الشمس الذهبيّة", price: 600, core: RGB(1, 1, 0.9), glow: RGB(1, 0.75, 0.1), shape: .star),
    ]

    static let trails: [TrailSkin] = [
        TrailSkin(id: "t0", name: "غبار أزرق", price: 0, colors: [RGB(0.4, 0.8, 1)], sparkle: false),
        TrailSkin(id: "t1", name: "لهب", price: 50, colors: [RGB(1, 0.85, 0.3), RGB(1, 0.35, 0.1)], sparkle: false),
        TrailSkin(id: "t2", name: "نعناع", price: 70, colors: [RGB(0.4, 1, 0.75)], sparkle: false),
        TrailSkin(id: "t3", name: "وردي", price: 90, colors: [RGB(1, 0.5, 0.8), RGB(0.7, 0.4, 1)], sparkle: false),
        TrailSkin(id: "t4", name: "ذهب", price: 120, colors: [RGB(1, 0.85, 0.35)], sparkle: true),
        TrailSkin(id: "t5", name: "شفق", price: 160, colors: [RGB(0.3, 1, 0.6), RGB(0.3, 0.6, 1), RGB(0.8, 0.4, 1)], sparkle: false),
        TrailSkin(id: "t6", name: "فضّة", price: 190, colors: [RGB(0.92, 0.95, 1)], sparkle: true),
        TrailSkin(id: "t7", name: "غروب", price: 230, colors: [RGB(1, 0.75, 0.3), RGB(1, 0.4, 0.45), RGB(0.6, 0.3, 0.8)], sparkle: false),
        TrailSkin(id: "t8", name: "بلازما", price: 280, colors: [RGB(0.4, 0.9, 1), RGB(1, 0.35, 0.95)], sparkle: true),
        TrailSkin(id: "t9", name: "قوس قزح", price: 400, colors: [RGB(1, 0.3, 0.3), RGB(1, 0.8, 0.2), RGB(0.3, 1, 0.4), RGB(0.3, 0.7, 1), RGB(0.7, 0.35, 1)], sparkle: true),
    ]

    static func comet(_ id: String) -> CometSkin { comets.first { $0.id == id } ?? comets[0] }
    static func trail(_ id: String) -> TrailSkin { trails.first { $0.id == id } ?? trails[0] }
    static func price(_ id: String) -> Int? {
        if let c = comets.first(where: { $0.id == id }) { return c.price }
        if let t = trails.first(where: { $0.id == id }) { return t.price }
        return nil
    }
}

enum BuyResult: Equatable { case bought, owned, poor, unknown }

/// المحفظة: الجواهر + المملوك + المختار
struct Wallet: Codable, Equatable {
    var gems = 0
    var owned: Set<String> = ["c0", "t0"]
    var comet = "c0"
    var trail = "t0"
    static let continueCost = 30

    func has(_ id: String) -> Bool { owned.contains(id) || Catalog.price(id) == 0 }

    mutating func buy(_ id: String) -> BuyResult {
        guard let p = Catalog.price(id) else { return .unknown }
        if has(id) { return .owned }
        guard gems >= p else { return .poor }
        gems -= p
        owned.insert(id)
        return .bought
    }

    @discardableResult
    mutating func equip(_ id: String) -> Bool {
        guard has(id) else { return false }
        if Catalog.comets.contains(where: { $0.id == id }) { comet = id; return true }
        if Catalog.trails.contains(where: { $0.id == id }) { trail = id; return true }
        return false
    }

    mutating func spend(_ n: Int) -> Bool {
        guard n >= 0, gems >= n else { return false }
        gems -= n
        return true
    }
}

/// التحدّي اليوميّ: نفس البذرة لكلّ اللاعبين بنفس اليوم
enum Daily {
    static func key(year: Int, month: Int, day: Int) -> Int { year * 10000 + month * 100 + day }
    static func seed(_ key: Int) -> UInt64 { mixSeed(0xDA11_0C0F_FEE5_EED5, key) }
}

/// إحصاء الجولة الوحدة
struct RunStats: Codable, Equatable {
    var score = 0
    var perfects = 0
    var gems = 0
    var planets = 0
    var bestCombo = 0
    var warps = 0
    var daily = false
    var cause: DeathCause? = nil
    var when = Date(timeIntervalSince1970: 0)

    init() {}
    init(sim: Sim, daily: Bool, when: Date) {
        score = sim.score.points
        perfects = sim.score.perfects
        gems = sim.gemsRun
        planets = sim.maxPlanet
        bestCombo = sim.score.bestCombo
        warps = sim.warps
        self.daily = daily
        cause = sim.cause
        self.when = when
    }
}

enum MKind: String, Codable, CaseIterable {
    case perfects, score, gems, planets, combo, warps
}

struct Mission: Codable, Equatable {
    let kind: MKind
    let target: Int
    let reward: Int

    var title: String {
        switch kind {
        case .perfects: return "امسك \(target) مسكات مثاليّة بجولة وحدة"
        case .score: return "اجمع \(target) نقطة بجولة وحدة"
        case .gems: return "اجمع \(target) جواهر بجولة وحدة"
        case .planets: return "اوصل الكوكب رقم \(target)"
        case .combo: return "سوّي كومبو ×\(target + 1)"
        case .warps: return "ادخل \(target) ثقب دوديّ"
        }
    }
    var icon: String {
        switch kind {
        case .perfects: return "scope"
        case .score: return "star.fill"
        case .gems: return "diamond.fill"
        case .planets: return "arrow.up.circle.fill"
        case .combo: return "flame.fill"
        case .warps: return "tornado"
        }
    }

    func value(_ r: RunStats) -> Int {
        switch kind {
        case .perfects: return r.perfects
        case .score: return r.score
        case .gems: return r.gems
        case .planets: return r.planets
        case .combo: return r.bestCombo
        case .warps: return r.warps
        }
    }
    func done(_ r: RunStats) -> Bool { value(r) >= target }
}

enum Missions {
    /// ثلاث مهمّات مختلفة لكلّ يوم
    static func forDay(_ key: Int) -> [Mission] {
        var r = MRng(seed: mixSeed(0x4D15_5104, key))
        var kinds = MKind.allCases
        var out: [Mission] = []
        while out.count < 3 && !kinds.isEmpty {
            let k = kinds.remove(at: r.int(kinds.count))
            let lvl = r.int(3)
            out.append(make(k, lvl))
        }
        return out
    }

    static func make(_ k: MKind, _ lvl: Int) -> Mission {
        let l = min(2, max(0, lvl))
        switch k {
        case .perfects: return Mission(kind: k, target: [3, 5, 8][l], reward: [15, 25, 40][l])
        case .score: return Mission(kind: k, target: [150, 300, 600][l], reward: [15, 25, 45][l])
        case .gems: return Mission(kind: k, target: [8, 15, 25][l], reward: [10, 20, 35][l])
        case .planets: return Mission(kind: k, target: [10, 20, 35][l], reward: [15, 30, 50][l])
        case .combo: return Mission(kind: k, target: [2, 3, 5][l], reward: [15, 25, 45][l])
        case .warps: return Mission(kind: k, target: [1, 1, 2][l], reward: [20, 20, 40][l])
        }
    }
}

struct RunRecord: Codable, Equatable {
    var score: Int
    var planets: Int
    var perfects: Int
    var daily: Bool
    var when: Date
}

/// كلّ تقدّم اللاعب
struct Profile: Codable, Equatable {
    var wallet = Wallet()
    var best = 0
    var runs = 0
    var totalPerfects = 0
    var totalGems = 0
    var totalPlanets = 0
    var bestCombo = 0
    var bestPlanets = 0
    var history: [RunRecord] = []
    var dailyKey = 0
    var dailyBest = 0
    var dailyRuns = 0
    var missionKey = 0
    var missionsDone: [Int] = []
    var bestProgress: [Int] = [0, 0, 0]
    static let historyCap = 30

    /// يجهّز مهمّات اليوم (ويصفّر القديمة إذا تغيّر اليوم)
    mutating func roll(_ key: Int) {
        if missionKey != key {
            missionKey = key
            missionsDone = []
            bestProgress = [0, 0, 0]
        }
        if dailyKey != key {
            dailyKey = key
            dailyBest = 0
            dailyRuns = 0
        }
    }

    var missions: [Mission] { Missions.forDay(missionKey) }

    struct Outcome: Equatable {
        var newBest = false
        var newDailyBest = false
        var completed: [Int] = []
        var reward = 0
    }

    /// يسجّل جولة: الأرقام القياسيّة + الجواهر + المهمّات
    mutating func record(_ r: RunStats, key: Int) -> Outcome {
        roll(key)
        var o = Outcome()
        runs += 1
        totalPerfects += r.perfects
        totalGems += r.gems
        totalPlanets += r.planets
        bestCombo = max(bestCombo, r.bestCombo)
        bestPlanets = max(bestPlanets, r.planets)
        wallet.gems += r.gems
        if r.score > best { best = r.score; o.newBest = true }
        if r.daily {
            dailyRuns += 1
            if r.score > dailyBest { dailyBest = r.score; o.newDailyBest = true }
        }
        let ms = missions
        for (i, m) in ms.enumerated() {
            if i < bestProgress.count { bestProgress[i] = max(bestProgress[i], min(m.target, m.value(r))) }
            if !missionsDone.contains(i) && m.done(r) {
                missionsDone.append(i)
                o.completed.append(i)
                o.reward += m.reward
            }
        }
        wallet.gems += o.reward
        history.insert(RunRecord(score: r.score, planets: r.planets, perfects: r.perfects, daily: r.daily, when: r.when), at: 0)
        if history.count > Profile.historyCap { history.removeLast(history.count - Profile.historyCap) }
        return o
    }

    var average: Int {
        guard !history.isEmpty else { return 0 }
        return history.reduce(0) { $0 + $1.score } / history.count
    }
}
