import SwiftUI

enum MD {
    static let bg = Color(red: 0.02, green: 0.02, blue: 0.07)
    static let s1 = Color(red: 0.07, green: 0.065, blue: 0.16)
    static let s2 = Color(red: 0.12, green: 0.11, blue: 0.25)
    static let s3 = Color(red: 0.19, green: 0.17, blue: 0.36)
    static let cyan = Color(red: 0.35, green: 0.9, blue: 1)
    static let magenta = Color(red: 1, green: 0.36, blue: 0.85)
    static let violet = Color(red: 0.56, green: 0.46, blue: 1)
    static let gold = Color(red: 1, green: 0.82, blue: 0.35)
    static let green = Color(red: 0.4, green: 1, blue: 0.65)
    static let red = Color(red: 1, green: 0.36, blue: 0.42)
    static let tx2 = Color(white: 1, opacity: 0.74), tx3 = Color(white: 1, opacity: 0.46)
    static let hero = LinearGradient(colors: [Color(red: 0.36, green: 0.86, blue: 1), Color(red: 0.62, green: 0.42, blue: 1), Color(red: 1, green: 0.38, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let goldGrad = LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.45), Color(red: 1, green: 0.6, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let zoneNames = ["المدار الأوّل", "حزام الكويكبات", "سديم الورد", "البحر البنفسجيّ", "الفراغ العميق", "حافّة المجرّة", "قلب النجوم"]
    static func zoneName(_ z: Int) -> String { zoneNames[max(0, z) % zoneNames.count] }
    /// ألوان السماء لكلّ منطقة (أعلى، أسفل، سديم)
    static let zoneSky: [(RGB, RGB, RGB)] = [
        (RGB(0.03, 0.03, 0.10), RGB(0.05, 0.08, 0.20), RGB(0.25, 0.45, 1)),
        (RGB(0.05, 0.03, 0.09), RGB(0.12, 0.07, 0.16), RGB(1, 0.55, 0.3)),
        (RGB(0.07, 0.02, 0.09), RGB(0.20, 0.05, 0.18), RGB(1, 0.35, 0.75)),
        (RGB(0.04, 0.02, 0.12), RGB(0.11, 0.05, 0.26), RGB(0.6, 0.4, 1)),
        (RGB(0.01, 0.01, 0.03), RGB(0.03, 0.04, 0.09), RGB(0.3, 0.9, 0.85)),
        (RGB(0.06, 0.03, 0.02), RGB(0.16, 0.08, 0.06), RGB(1, 0.75, 0.3)),
        (RGB(0.02, 0.05, 0.06), RGB(0.04, 0.15, 0.16), RGB(0.4, 1, 0.7)),
    ]
}

func col(_ c: RGB, _ o: Double = 1) -> Color { Color(red: c.r, green: c.g, blue: c.b).opacity(o) }
func mixRGB(_ a: RGB, _ b: RGB, _ t: Double) -> RGB { RGB(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t) }

/// الاهتزاز والصوت حسب الإعدادات
enum FX {
    static var haptics: Bool { !Shot.on && (UserDefaults.standard.object(forKey: "md_haptic") as? Bool ?? true) }
    static var sound: Bool { !Shot.on && (UserDefaults.standard.object(forKey: "md_sound") as? Bool ?? true) }
    static var guide: Bool { UserDefaults.standard.object(forKey: "md_guide") as? Bool ?? true }
    static func tap() { if haptics { Haptic.tap() } }
    static func thud() { if haptics { Haptic.thud() } }
    static func ok() { if haptics { Haptic.ok() } }
    static func bad() { if haptics { Haptic.bad() } }
}

final class Store: ObservableObject {
    @Published var p: Profile
    static let key = "md_profile_v1"

    init() {
        if Shot.on { p = Store.demo(); return }
        if let d = UserDefaults.standard.data(forKey: Store.key), let v = try? JSONDecoder().decode(Profile.self, from: d) {
            p = v
        } else {
            p = Profile()
        }
        p.roll(Store.today)
    }

    static var today: Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let y: Int = c.year ?? 2026
        let m: Int = c.month ?? 1
        let d: Int = c.day ?? 1
        return Daily.key(year: y, month: m, day: d)
    }

    func refreshDay() { p.roll(Store.today) }

    func save() {
        guard !Shot.on else { return }
        if let d = try? JSONEncoder().encode(p) { UserDefaults.standard.set(d, forKey: Store.key) }
    }

    func record(_ r: RunStats) -> Profile.Outcome {
        let o = p.record(r, key: Store.today)
        save()
        return o
    }

    /// معاينة النتيجة بدون حفظ (حتى نعرضها قبل قرار الإكمال)
    func preview(_ r: RunStats) -> Profile.Outcome {
        var copy = p
        return copy.record(r, key: Store.today)
    }

    func buy(_ id: String) -> BuyResult {
        let r = p.wallet.buy(id)
        if r == .bought { p.wallet.equip(id) }
        save()
        return r
    }

    func equip(_ id: String) {
        p.wallet.equip(id)
        save()
    }

    func spendContinue() -> Bool {
        let ok = p.wallet.spend(Wallet.continueCost)
        if ok { save() }
        return ok
    }

    func reset() {
        p = Profile()
        p.roll(Store.today)
        save()
    }

    static func demo() -> Profile {
        var p = Profile()
        p.roll(Store.today)
        p.wallet.gems = 385
        p.wallet.owned = ["c0", "c1", "c2", "c3", "c5", "t0", "t1", "t3", "t4"]
        p.wallet.comet = "c2"
        p.wallet.trail = "t1"
        p.best = 1840
        p.runs = 63
        p.totalPerfects = 412
        p.totalGems = 1290
        p.totalPlanets = 1544
        p.bestCombo = 9
        p.bestPlanets = 58
        p.dailyBest = 960
        p.dailyRuns = 4
        let scores = [960, 420, 1840, 610, 300, 1220, 780, 150, 990, 1430, 520, 670, 260, 880, 1110, 340, 720, 1500, 450, 810]
        p.history = scores.enumerated().map { e in
            RunRecord(score: e.element, planets: e.element / 30 + 3, perfects: e.element / 70, daily: e.offset % 4 == 0, when: Date().addingTimeInterval(-Double(e.offset) * 5400 - 600))
        }
        let ms = p.missions
        p.missionsDone = [0]
        p.bestProgress = ms.enumerated().map { e in e.offset == 0 ? e.element.target : max(1, e.element.target * (e.offset == 1 ? 3 : 1) / 5) }
        return p
    }
}

@main
struct MadarApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(MD.cyan)
        }
    }
}
