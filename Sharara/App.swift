import SwiftUI

enum ST {
    static let bg = Color(red: 0.025, green: 0.015, blue: 0.06)
    static let s1 = Color(red: 0.075, green: 0.055, blue: 0.14)
    static let s2 = Color(red: 0.12, green: 0.09, blue: 0.21)
    static let s3 = Color(red: 0.19, green: 0.15, blue: 0.31)
    static let spark = Color(red: 1.0, green: 0.58, blue: 0.16)
    static let flame = Color(red: 1.0, green: 0.36, blue: 0.22)
    static let pink = Color(red: 1.0, green: 0.32, blue: 0.62)
    static let violet = Color(red: 0.62, green: 0.42, blue: 1.0)
    static let cyan = Color(red: 0.32, green: 0.86, blue: 1.0)
    static let lime = Color(red: 0.55, green: 1.0, blue: 0.45)
    static let gold = Color(red: 1.0, green: 0.83, blue: 0.32)
    static let red = Color(red: 1.0, green: 0.28, blue: 0.32)
    static let tx2 = Color(white: 1, opacity: 0.74)
    static let tx3 = Color(white: 1, opacity: 0.46)
    static let hot = LinearGradient(colors: [Color(red: 1, green: 0.74, blue: 0.24), Color(red: 1, green: 0.36, blue: 0.3), Color(red: 0.92, green: 0.25, blue: 0.62)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cool = LinearGradient(colors: [Color(red: 0.36, green: 0.84, blue: 1), Color(red: 0.55, green: 0.4, blue: 1)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
    static func c(_ v: RGB, _ o: Double = 1) -> Color { Color(red: v.r, green: v.g, blue: v.b).opacity(o) }
    /// لون كلّ مجرّة
    static let galaxy: [Color] = [
        Color(red: 1.0, green: 0.62, blue: 0.24), Color(red: 1.0, green: 0.38, blue: 0.62),
        Color(red: 0.42, green: 0.84, blue: 1.0), Color(red: 0.35, green: 0.95, blue: 0.6),
        Color(red: 1.0, green: 0.8, blue: 0.3), Color(red: 0.7, green: 0.45, blue: 1.0),
        Color(red: 0.6, green: 0.6, blue: 0.75), Color(red: 1.0, green: 0.45, blue: 0.25),
    ]
    static func galaxyColor(_ g: Int) -> Color { galaxy[min(max(g, 0), galaxy.count - 1)] }
}

/// المخزن: التقدّم + الإعدادات، يحفظ نفسه
final class GameStore: ObservableObject {
    @Published var p: Career { didSet { save() } }
    @Published var sound: Bool { didSet { UserDefaults.standard.set(sound, forKey: "sh_sound"); Synth.shared.enabled = sound } }
    @Published var haptics: Bool { didSet { UserDefaults.standard.set(haptics, forKey: "sh_haptic") } }
    @Published var calmShake: Bool { didSet { UserDefaults.standard.set(calmShake, forKey: "sh_calm") } }
    private let key = "sh_progress_v1"

    init() {
        let d = UserDefaults.standard
        sound = d.object(forKey: "sh_sound") as? Bool ?? true
        haptics = d.object(forKey: "sh_haptic") as? Bool ?? true
        calmShake = d.bool(forKey: "sh_calm")
        if Shot.on {
            p = GameStore.demo()
        } else if let data = d.data(forKey: key), let v = try? JSONDecoder().decode(Career.self, from: data) {
            p = v
        } else {
            p = Career()
        }
        Synth.shared.enabled = sound
    }

    private func save() {
        if Shot.on { return }
        if let data = try? JSONEncoder().encode(p) { UserDefaults.standard.set(data, forKey: key) }
    }

    func reset() {
        var fresh = Career()
        fresh.onboarded = true
        p = fresh
    }

    var today: Int { Days.index(Date().timeIntervalSince1970, tzOffset: TimeZone.current.secondsFromGMT()) }
    var streak: Int { Days.streak(p.dailyDone, today: today) }
    var dailyDoneToday: Bool { p.dailyDone.contains(today) }

    func buzz(_ k: Int) {
        guard haptics, !Shot.on else { return }
        switch k {
        case 0: Haptic.tap()
        case 1: Haptic.thud()
        case 2: Haptic.ok()
        default: Haptic.bad()
        }
    }

    static func demo() -> Career {
        var d = Career()
        let st = [3, 3, 2, 3, 3, 1, 3, 2, 3, 3, 2, 3, 3, 3, 2, 1, 3, 2, 3, 2, 3, 1, 2]
        for (i, s) in st.enumerated() { d.stars[i] = s; d.best[i] = 400 + i * 37 }
        d.coins = 1840
        d.coinsEarned = 4210
        d.owned = ["ember", "ice", "royal", "nebula", "aurora"]
        d.spark = "ember"
        d.back = "nebula"
        d.endlessRounds = 14
        d.endlessScore = 18450
        d.shots = 212
        d.wins = 164
        d.totalPops = 5873
        d.badPops = 41
        d.longest = 47
        d.deepest = 19
        d.topScore = 3920
        for i in 0..<7 { d.perfect[i] = true }
        d.onboarded = true
        return d
    }
}

enum Screen: Equatable { case home, levels, shop, stats, settings }

/// طلب لعب — يتغيّر id مع كلّ مرحلة جديدة
struct GameReq: Identifiable, Equatable {
    let id = UUID()
    var mode: Mode
    var index: Int
    var runSeed: UInt64 = 0
    var carry: Int = 0
    static func == (a: GameReq, b: GameReq) -> Bool { a.id == b.id }
}

@main
struct ShararaApp: App {
    @StateObject private var store = GameStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(ST.spark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: GameStore
    @State private var screen: Screen = .home
    @State private var req: GameReq? = nil
    @State private var onboarding = false

    var body: some View {
        ZStack {
            SpaceBackdrop(back: Catalog.back(store.p.back))
            Group {
                switch screen {
                case .home: HomeView(go: go, play: play)
                case .levels: LevelsView(back: { go(.home) }, play: play)
                case .shop: ShopView(back: { go(.home) })
                case .stats: StatsView(back: { go(.home) })
                case .settings: SettingsView(back: { go(.home) }, replayIntro: { onboarding = true })
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
        }
        .fullScreenCover(item: $req) { r in
            GameHost(start: r) { req = nil }
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $onboarding) {
            OnboardingView {
                store.p.onboarded = true
                onboarding = false
            }
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
        }
        .onAppear(perform: boot)
    }

    private func go(_ s: Screen) {
        withAnimation(.easeOut(duration: 0.22)) { screen = s }
    }

    private func play(_ r: GameReq) {
        Synth.shared.start()
        req = r
    }

    private func boot() {
        if Shot.on {
            switch Shot.name {
            case "levels": screen = .levels
            case "shop": screen = .shop
            case "stats": screen = .stats
            case "play", "chain", "result": req = GameReq(mode: .campaign, index: 23)
            case "intro": onboarding = true
            default: screen = .home
            }
            return
        }
        if !store.p.onboarded { onboarding = true }
    }
}
