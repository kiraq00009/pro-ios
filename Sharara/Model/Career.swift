import Foundation

/// لون كمكوّنات (بلا SwiftUI)
struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
}

/// شكل الشرارة
struct SparkSkin {
    let id: String
    let name: String
    let price: Int
    let core: RGB
    let glow: RGB
    let rainbow: Bool
}

/// الخلفيّة
struct BackSkin {
    let id: String
    let name: String
    let price: Int
    let top: RGB
    let bottom: RGB
    let accent: RGB
    let stars: Int
}

enum Catalog {
    static let sparks: [SparkSkin] = [
        SparkSkin(id: "ember", name: "جمرة", price: 0, core: RGB(1, 0.86, 0.55), glow: RGB(1, 0.5, 0.12), rainbow: false),
        SparkSkin(id: "ice", name: "جليد", price: 250, core: RGB(0.85, 0.97, 1), glow: RGB(0.25, 0.75, 1), rainbow: false),
        SparkSkin(id: "venom", name: "سمّ", price: 400, core: RGB(0.85, 1, 0.7), glow: RGB(0.35, 1, 0.3), rainbow: false),
        SparkSkin(id: "royal", name: "ملكيّ", price: 600, core: RGB(0.95, 0.85, 1), glow: RGB(0.65, 0.35, 1), rainbow: false),
        SparkSkin(id: "rose", name: "ورديّ", price: 800, core: RGB(1, 0.85, 0.92), glow: RGB(1, 0.3, 0.6), rainbow: false),
        SparkSkin(id: "gold", name: "ذهب", price: 1200, core: RGB(1, 0.96, 0.75), glow: RGB(1, 0.78, 0.2), rainbow: false),
        SparkSkin(id: "prism", name: "قوس قزح", price: 2000, core: RGB(1, 1, 1), glow: RGB(1, 0.4, 0.8), rainbow: true),
    ]
    static let backs: [BackSkin] = [
        BackSkin(id: "nebula", name: "سديم", price: 0, top: RGB(0.07, 0.03, 0.16), bottom: RGB(0.01, 0.01, 0.05), accent: RGB(0.55, 0.2, 0.9), stars: 120),
        BackSkin(id: "deep", name: "فضاء عميق", price: 300, top: RGB(0.01, 0.03, 0.09), bottom: RGB(0, 0, 0.02), accent: RGB(0.15, 0.4, 0.9), stars: 220),
        BackSkin(id: "aurora", name: "شفق", price: 500, top: RGB(0.0, 0.10, 0.10), bottom: RGB(0.01, 0.02, 0.06), accent: RGB(0.1, 0.9, 0.6), stars: 90),
        BackSkin(id: "dusk", name: "غروب", price: 700, top: RGB(0.16, 0.04, 0.08), bottom: RGB(0.03, 0.01, 0.05), accent: RGB(1, 0.42, 0.2), stars: 70),
        BackSkin(id: "synth", name: "نيون", price: 1000, top: RGB(0.10, 0.0, 0.14), bottom: RGB(0.02, 0.0, 0.05), accent: RGB(1, 0.2, 0.8), stars: 60),
        BackSkin(id: "void", name: "فراغ", price: 1500, top: RGB(0.02, 0.02, 0.02), bottom: RGB(0, 0, 0), accent: RGB(0.9, 0.9, 1), stars: 30),
    ]
    static func spark(_ id: String) -> SparkSkin { sparks.first { $0.id == id } ?? sparks[0] }
    static func back(_ id: String) -> BackSkin { backs.first { $0.id == id } ?? backs[0] }
    static func price(_ id: String) -> Int? {
        if let s = sparks.first(where: { $0.id == id }) { return s.price }
        if let b = backs.first(where: { $0.id == id }) { return b.price }
        return nil
    }
}

/// كلّ التقدّم، ينحفظ JSON
struct Career: Codable, Equatable {
    var stars: [Int] = [Int](repeating: 0, count: Gen.campaignCount)
    var best: [Int] = [Int](repeating: 0, count: Gen.campaignCount)
    var perfect: [Bool] = [Bool](repeating: false, count: Gen.perfectCount)
    var coins = 0
    var coinsEarned = 0
    var owned: [String] = ["ember", "nebula"]
    var spark = "ember"
    var back = "nebula"
    var endlessRounds = 0
    var endlessScore = 0
    var dailyDone: [Int] = []
    var dailyBest: [Int: Int] = [:]
    var shots = 0
    var wins = 0
    var totalPops = 0
    var badPops = 0
    var longest = 0
    var deepest = 0
    var topScore = 0
    var onboarded = false

    var totalStars: Int { stars.reduce(0, +) }
    func galaxyStars(_ g: Int) -> Int {
        let a = g * Gen.perGalaxy
        let b = min(stars.count, a + Gen.perGalaxy)
        if a >= b { return 0 }
        return stars[a..<b].reduce(0, +)
    }
    func unlocked(_ i: Int) -> Bool {
        if i <= 0 { return true }
        if i >= stars.count { return false }
        return stars[i - 1] > 0
    }
    /// أوّل مرحلة ما انحلّت
    var current: Int {
        for i in 0..<stars.count where stars[i] == 0 { return i }
        return stars.count - 1
    }
    var perfectCleared: Int { perfect.filter { $0 }.count }
    func perfectUnlocked(_ i: Int) -> Bool { i <= 0 || (i - 1 < perfect.count && perfect[i - 1]) || i < 3 }

    // MARK: تسجيل الضربات

    private mutating func logShot(_ o: Outcome) {
        shots += 1
        totalPops += o.pops
        badPops += o.bad
        longest = max(longest, o.pops)
        deepest = max(deepest, o.maxGen)
        topScore = max(topScore, o.score)
    }

    private mutating func pay(_ c: Int) {
        coins += c
        coinsEarned += c
    }

    /// يرجع عدد الكوينز المكسوبة
    @discardableResult
    mutating func finishCampaign(_ i: Int, stars s: Int, outcome o: Outcome) -> Int {
        logShot(o)
        guard i >= 0 && i < stars.count else { return 0 }
        let old = stars[i]
        var c = Reward.coins(pops: o.pops, starsGained: max(0, s - old), firstClear: old == 0 && s > 0)
        if s > 0 { wins += 1 } else { c = 0 }
        stars[i] = max(old, s)
        best[i] = max(best[i], o.score)
        pay(c)
        return c
    }

    @discardableResult
    mutating func finishEndless(rounds: Int, score: Int, outcome o: Outcome, passed: Bool) -> Int {
        logShot(o)
        if passed { wins += 1 }
        endlessRounds = max(endlessRounds, rounds)
        endlessScore = max(endlessScore, score)
        let c = passed ? 5 + o.pops / 3 : 0
        pay(c)
        return c
    }

    @discardableResult
    mutating func finishDaily(day: Int, outcome o: Outcome, passed: Bool) -> Int {
        logShot(o)
        let first = passed && !dailyDone.contains(day)
        if passed {
            wins += 1
            if first { dailyDone.append(day) }
        }
        dailyBest[day] = max(dailyBest[day] ?? 0, o.score)
        let c = first ? 120 : (passed ? 5 : 0)
        pay(c)
        return c
    }

    @discardableResult
    mutating func finishPerfect(_ i: Int, outcome o: Outcome, passed: Bool) -> Int {
        logShot(o)
        guard i >= 0 && i < perfect.count else { return 0 }
        let first = passed && !perfect[i]
        if passed { wins += 1; perfect[i] = true }
        let c = first ? 60 + i * 5 : 0
        pay(c)
        return c
    }

    // MARK: المتجر

    func owns(_ id: String) -> Bool { owned.contains(id) }

    mutating func buy(_ id: String) -> Bool {
        guard let p = Catalog.price(id), !owns(id), coins >= p else { return false }
        coins -= p
        owned.append(id)
        return true
    }

    mutating func select(_ id: String) -> Bool {
        guard owns(id) else { return false }
        if Catalog.sparks.contains(where: { $0.id == id }) { spark = id; return true }
        if Catalog.backs.contains(where: { $0.id == id }) { back = id; return true }
        return false
    }
}

enum Reward {
    /// كوينز المرحلة: نجوم جديدة + جزء من الانفجارات + مكافأة أوّل فوز
    static func coins(pops: Int, starsGained: Int, firstClear: Bool) -> Int {
        starsGained * 15 + pops / 3 + (firstClear ? 20 : 0)
    }
}

/// كلام السلسلة
enum ChainWords {
    static func tier(_ n: Int) -> String {
        switch n {
        case ..<1: return ""
        case 1: return "حلو!"
        case 2: return "نار!"
        case 3: return "خرافي!"
        case 4: return "أسطوري!"
        default: return "شرارة مطلقة!"
        }
    }
}
