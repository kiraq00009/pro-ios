import SwiftUI

// MARK: الهويّة البصريّة

enum SQ {
    static let bg = Color(red: 0.035, green: 0.03, blue: 0.075)
    static let s1 = Color(red: 0.085, green: 0.075, blue: 0.15)
    static let s2 = Color(red: 0.14, green: 0.12, blue: 0.23)
    static let s3 = Color(red: 0.22, green: 0.2, blue: 0.33)
    static let coral = Color(red: 1.0, green: 0.38, blue: 0.46)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.32)
    static let mint = Color(red: 0.36, green: 0.96, blue: 0.76)
    static let cyan = Color(red: 0.36, green: 0.84, blue: 1.0)
    static let violet = Color(red: 0.64, green: 0.48, blue: 1.0)
    static let red = Color(red: 1.0, green: 0.33, blue: 0.38)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.36)
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.45)
    static let hot = LinearGradient(colors: [coral, amber], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func grade(_ g: Grade) -> Color {
        switch g {
        case .perfect: return gold
        case .great: return mint
        case .good: return cyan
        case .ok: return violet
        case .miss: return red
        }
    }
    static let worldColors: [Color] = [coral, cyan, violet, mint, amber, red]
    static func world(_ w: Int) -> Color { worldColors[max(0, min(worldColors.count - 1, w))] }
}

struct Skin {
    let name: String
    let price: Int
    let bg0: Color
    let bg1: Color
    let a: Color
    let b: Color
}

struct Blade {
    let name: String
    let price: Int
    let a: Color
    let b: Color
    let width: CGFloat
    let rainbow: Bool
}

enum Catalog {
    static let skins: [Skin] = [
        Skin(name: "شفق", price: 0, bg0: Color(red: 0.09, green: 0.05, blue: 0.17), bg1: Color(red: 0.02, green: 0.02, blue: 0.05), a: SQ.coral, b: SQ.amber),
        Skin(name: "محيط", price: 150, bg0: Color(red: 0.02, green: 0.09, blue: 0.18), bg1: Color(red: 0.01, green: 0.02, blue: 0.06), a: Color(red: 0.2, green: 0.85, blue: 1), b: Color(red: 0.38, green: 0.42, blue: 1)),
        Skin(name: "غابة", price: 200, bg0: Color(red: 0.02, green: 0.13, blue: 0.09), bg1: Color(red: 0.01, green: 0.03, blue: 0.03), a: SQ.mint, b: Color(red: 0.62, green: 0.95, blue: 0.3)),
        Skin(name: "حلوى", price: 250, bg0: Color(red: 0.15, green: 0.04, blue: 0.14), bg1: Color(red: 0.04, green: 0.01, blue: 0.05), a: Color(red: 1, green: 0.55, blue: 0.85), b: Color(red: 0.72, green: 0.6, blue: 1)),
        Skin(name: "حمم", price: 300, bg0: Color(red: 0.16, green: 0.03, blue: 0.02), bg1: Color(red: 0.04, green: 0.01, blue: 0.01), a: Color(red: 1, green: 0.28, blue: 0.14), b: Color(red: 1, green: 0.86, blue: 0.22)),
        Skin(name: "جليد", price: 400, bg0: Color(red: 0.07, green: 0.1, blue: 0.15), bg1: Color(red: 0.02, green: 0.03, blue: 0.05), a: Color(red: 0.95, green: 0.98, blue: 1), b: Color(red: 0.55, green: 0.8, blue: 1)),
    ]
    static let blades: [Blade] = [
        Blade(name: "كلاسيك", price: 0, a: Color.white, b: Color(white: 0.8), width: 7, rainbow: false),
        Blade(name: "نيون", price: 80, a: SQ.cyan, b: SQ.violet, width: 8, rainbow: false),
        Blade(name: "لهب", price: 120, a: SQ.amber, b: SQ.red, width: 9, rainbow: false),
        Blade(name: "سمّ", price: 150, a: SQ.mint, b: Color(red: 0.4, green: 0.9, blue: 0.2), width: 8, rainbow: false),
        Blade(name: "ذهب", price: 250, a: SQ.gold, b: Color(red: 1, green: 0.62, blue: 0.2), width: 9, rainbow: false),
        Blade(name: "قوس قزح", price: 300, a: Color.white, b: Color.white, width: 9, rainbow: true),
        Blade(name: "بلازما", price: 400, a: Color(red: 1, green: 0.4, blue: 0.9), b: SQ.violet, width: 12, rainbow: false),
    ]
    static func skin(_ i: Int) -> Skin { skins[max(0, min(skins.count - 1, i))] }
    static func blade(_ i: Int) -> Blade { blades[max(0, min(blades.count - 1, i))] }
}

// MARK: الحفظ

struct SaveData: Codable {
    var stars: [Int] = Array(repeating: 0, count: Levels.total)
    var coins = 0
    var blades: [Int] = [0]
    var blade = 0
    var skins: [Int] = [0]
    var skin = 0
    var bestEndless = 0
    var bestEndlessRounds = 0
    var bestCombo = 0
    var daily: [String: Int] = [:]
    var cuts = 0
    var perfects = 0
    var rounds = 0
    var totalErr = 0.0
    var games = 0
    var recent: [Double] = []
    var sound = true
    var haptics = true
    var seenIntro = false
}

final class Prog: ObservableObject {
    @Published var d: SaveData { didSet { save() } }
    private let key = "shq_save_v1"

    init() {
        if Shot.on {
            var s = SaveData()
            let pattern = [3, 3, 2, 3, 3, 1, 3, 2, 3, 3, 3, 2, 3, 3, 2, 3, 1, 3, 3, 2, 3, 3, 2, 3, 2, 3, 1]
            for (i, v) in pattern.enumerated() { s.stars[i] = v }
            s.coins = 640
            s.blades = [0, 1, 2, 5]; s.blade = 5
            s.skins = [0, 1, 3]; s.skin = 0
            s.bestEndless = 4210; s.bestEndlessRounds = 27; s.bestCombo = 11
            s.daily = [Prog.todayKey: 2350]
            s.cuts = 386; s.perfects = 74; s.rounds = 341; s.totalErr = 341 * 2.7; s.games = 58
            s.recent = [3.1, 0.6, 1.8, 4.2, 0.4, 2.2, 7.5, 1.1, 0.8, 2.9, 0.3, 5.1, 1.4, 0.9, 12.0, 2.0, 0.7, 1.6, 0.2, 3.3]
            s.seenIntro = true
            d = s
            return
        }
        if let raw = UserDefaults.standard.data(forKey: "shq_save_v1"), let v = try? JSONDecoder().decode(SaveData.self, from: raw) {
            var fixed = v
            if fixed.stars.count < Levels.total { fixed.stars += Array(repeating: 0, count: Levels.total - fixed.stars.count) }
            d = fixed
        } else {
            d = SaveData()
        }
    }

    private func save() {
        guard !Shot.on else { return }
        if let raw = try? JSONEncoder().encode(d) { UserDefaults.standard.set(raw, forKey: key) }
    }

    static var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year ?? 2026)-\(c.month ?? 1)-\(c.day ?? 1)"
    }
    static var today: (Int, Int, Int) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    var totalStars: Int { d.stars.reduce(0, +) }
    func worldStars(_ w: Int) -> Int { (0..<Levels.perWorld).reduce(0) { $0 + d.stars[w * Levels.perWorld + $1] } }
    func unlocked(_ id: Int) -> Bool { id == 0 || (id > 0 && id < Levels.total && d.stars[id - 1] > 0) }
    func worldOpen(_ w: Int) -> Bool { unlocked(w * Levels.perWorld) }
    /// أوّل مرحلة ما خلصت بثلاث نجوم مفتوحة (للزرّ «كمّل»)
    var nextLevel: Int {
        for i in 0..<Levels.total where unlocked(i) && d.stars[i] == 0 { return i }
        for i in 0..<Levels.total where d.stars[i] < 3 { return i }
        return Levels.total - 1
    }
    var dailyToday: Int? { d.daily[Prog.todayKey] }
    var avgError: Double { d.rounds > 0 ? d.totalErr / Double(d.rounds) : 0 }

    func recordRound(_ e: Double, _ g: Grade) {
        var s = d
        s.cuts += 1; s.rounds += 1
        s.totalErr += min(e, 25)
        if g == .perfect { s.perfects += 1 }
        s.recent.append(min(e, 25))
        if s.recent.count > 24 { s.recent.removeFirst(s.recent.count - 24) }
        d = s
    }

    /// يسجّل نهاية الجولة ويرجّعها مع العملات والرقم القياسيّ
    func commit(_ f: Finish) -> Finish {
        var out = f
        var s = d
        s.games += 1
        s.bestCombo = max(s.bestCombo, f.bestCombo)
        switch f.mode {
        case .campaign(let id):
            let old = s.stars[id]
            if f.stars > old { s.stars[id] = f.stars }
            out.coins = Scoring.coins(stars: f.stars, perfects: f.perfects, improved: max(0, f.stars - old))
            out.newBest = f.stars > old && old > 0
        case .endless:
            out.newBest = f.score > s.bestEndless
            if out.newBest { s.bestEndless = f.score; s.bestEndlessRounds = f.rounds }
            out.coins = f.score / 100
        case .daily:
            let k = Prog.todayKey
            let first = s.daily[k] == nil
            out.newBest = (s.daily[k] ?? 0) < f.score
            s.daily[k] = max(s.daily[k] ?? 0, f.score)
            out.coins = first ? 20 + f.score / 80 : 0
        case .zen:
            out.coins = 0
        }
        s.coins += out.coins
        d = s
        return out
    }

    func buySkin(_ i: Int) -> Bool {
        let k = Catalog.skin(i)
        if d.skins.contains(i) { d.skin = i; return true }
        guard d.coins >= k.price else { return false }
        var s = d; s.coins -= k.price; s.skins.append(i); s.skin = i; d = s
        return true
    }
    func buyBlade(_ i: Int) -> Bool {
        let k = Catalog.blade(i)
        if d.blades.contains(i) { d.blade = i; return true }
        guard d.coins >= k.price else { return false }
        var s = d; s.coins -= k.price; s.blades.append(i); s.blade = i; d = s
        return true
    }
    func reset() {
        var s = SaveData()
        s.seenIntro = true
        s.sound = d.sound; s.haptics = d.haptics
        d = s
    }
}
