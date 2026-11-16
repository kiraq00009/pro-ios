import SwiftUI

enum SM {
    static let bg = Color(red: 0.020, green: 0.028, blue: 0.060)
    static let s1 = Color(red: 0.060, green: 0.072, blue: 0.125)
    static let s2 = Color(red: 0.100, green: 0.115, blue: 0.185)
    static let s3 = Color(red: 0.150, green: 0.165, blue: 0.250)
    static let sonar = Color(red: 0.22, green: 0.96, blue: 0.84)
    static let sonarDeep = Color(red: 0.05, green: 0.55, blue: 0.62)
    static let violet = Color(red: 0.56, green: 0.45, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.36, blue: 0.42)
    static let amber = Color(red: 1.0, green: 0.76, blue: 0.30)
    static let moon = Color(red: 0.62, green: 0.66, blue: 1.0)
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.45)
    static let line = Color(white: 1, opacity: 0.07)

    static func cat(_ c: SoundCat) -> Color {
        switch c {
        case .people: return Color(red: 0.35, green: 0.80, blue: 1.0)
        case .home: return Color(red: 0.62, green: 0.55, blue: 1.0)
        case .safety: return coral
        case .animals: return amber
        case .nature: return Color(red: 0.40, green: 0.92, blue: 0.55)
        case .music: return Color(red: 1.0, green: 0.50, blue: 0.85)
        case .transport: return Color(red: 1.0, green: 0.62, blue: 0.35)
        case .other: return Color(white: 0.75)
        }
    }

    static func color(_ id: String) -> Color { cat(Catalog.info(id).cat) }

    static func zone(_ z: Int) -> Color {
        switch z {
        case 0: return sonar
        case 1: return Color(red: 0.45, green: 0.90, blue: 0.50)
        case 2: return amber
        case 3: return Color(red: 1.0, green: 0.55, blue: 0.30)
        default: return coral
        }
    }

    static func kind(_ k: SleepKind) -> Color {
        switch k {
        case .snore: return violet
        case .cough: return amber
        case .talk: return Color(red: 0.35, green: 0.80, blue: 1.0)
        case .other: return Color(white: 0.6)
        }
    }

    static let grad = LinearGradient(colors: [sonar, Color(red: 0.30, green: 0.62, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

@main
struct SamaaApp: App {
    @StateObject private var store = Store()
    @StateObject private var player = ClipPlayer()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(store.live).environmentObject(player)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(SM.sonar)
        }
    }
}

struct Backdrop: View {
    var tint: Color = SM.sonar
    var body: some View {
        ZStack {
            SM.bg
            RadialGradient(colors: [tint.opacity(0.16), Color.clear], center: .top, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [SM.violet.opacity(0.12), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 460)
        }.ignoresSafeArea()
    }
}

enum SMTab: Int, CaseIterable {
    case radar, watch, history, sleep, meter

    var title: String {
        switch self {
        case .radar: return "الرادار"
        case .watch: return "التنبيهات"
        case .history: return "السجلّ"
        case .sleep: return "النوم"
        case .meter: return "الضجيج"
        }
    }

    var icon: String {
        switch self {
        case .radar: return "dot.radiowaves.left.and.right"
        case .watch: return "bell.badge.fill"
        case .history: return "chart.bar.xaxis"
        case .sleep: return "moon.zzz.fill"
        case .meter: return "speaker.wave.3.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.scenePhase) private var phase
    @AppStorage("sm_onboarded") private var onboarded = false
    @State private var tab: SMTab = RootView.initialTab()

    static func initialTab() -> SMTab {
        switch Shot.name {
        case "watch": return .watch
        case "history": return .history
        case "sleep": return .sleep
        case "meter": return .meter
        default: return .radar
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .radar: RadarScreen()
                case .watch: WatchScreen()
                case .history: HistoryScreen()
                case .sleep: SleepScreen()
                case .meter: MeterScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 74) }
            TabBar(tab: $tab)
            if let a = store.alert {
                AlertOverlay(alert: a).transition(.opacity.combined(with: .scale(scale: 1.04))).zIndex(5)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: store.alert?.id)
        .fullScreenCover(isPresented: Binding(get: { !onboarded && !Shot.on }, set: { v in if !v { onboarded = true } })) {
            OnboardView { onboarded = true }
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .onAppear { store.boot() }
        .onChange(of: phase) { p in store.scene(p) }
    }
}

struct TabBar: View {
    @Binding var tab: SMTab
    @EnvironmentObject var store: Store
    var body: some View {
        HStack(spacing: 0) {
            ForEach(SMTab.allCases, id: \.rawValue) { t in
                Button {
                    if tab != t { Haptic.tap() }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = t }
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: t.icon).font(.system(size: 18, weight: .bold))
                            if t == .sleep && store.sleep != nil {
                                Circle().fill(SM.violet).frame(width: 8, height: 8).offset(x: 6, y: -3)
                            }
                            if t == .radar && store.running {
                                Circle().fill(SM.sonar).frame(width: 7, height: 7).offset(x: 6, y: -3)
                            }
                        }
                        Text(t.title).font(rnd(10.5, .bold))
                    }
                    .foregroundStyle(tab == t ? SM.sonar : SM.tx3)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(
                        Capsule().fill(SM.sonar.opacity(tab == t ? 0.13 : 0)).padding(.horizontal, 6).padding(.vertical, 4)
                    )
                }.buttonStyle(Press())
            }
        }
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(SM.line))
        .padding(.horizontal, 12).padding(.bottom, 4)
    }
}

/// عنوان كلّ شاشة
struct ScreenHeader<Trailing: View>: View {
    let title: String
    let sub: String
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(rnd(32, .black)).foregroundStyle(Color.white)
                Text(sub).font(rnd(13)).foregroundStyle(SM.tx3)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

struct Chip: View {
    let text: String
    let on: Bool
    var color: Color = SM.sonar
    let tap: () -> Void
    var body: some View {
        Button { Haptic.tap(); tap() } label: {
            Text(text).font(rnd(13, .bold))
                .foregroundStyle(on ? Color.black.opacity(0.85) : SM.tx2)
                .padding(.horizontal, 14).frame(height: 36)
                .background(on ? color : SM.s2, in: Capsule())
        }.buttonStyle(Press())
    }
}

struct SectionTitle: View {
    let text: String
    var icon: String = ""
    var body: some View {
        HStack(spacing: 7) {
            if !icon.isEmpty { Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(SM.sonar) }
            Text(text).font(rnd(15, .heavy)).foregroundStyle(Color.white)
            Spacer()
        }
    }
}

struct EmptyCard: View {
    let emoji: String
    let title: String
    let note: String
    var body: some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 44))
            Text(title).font(rnd(17, .heavy)).foregroundStyle(Color.white)
            Text(note).font(rnd(13)).foregroundStyle(SM.tx3).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30).padding(.horizontal, 20).card(SM.s1, 22)
    }
}

func clockText(_ t: Double) -> String {
    let d = Date(timeIntervalSince1970: t)
    let f = DateFormatter()
    f.locale = Locale(identifier: "ar")
    f.dateFormat = "h:mm a"
    return f.string(from: d)
}

func dayText(_ t: Double) -> String {
    let d = Date(timeIntervalSince1970: t)
    let cal = Calendar.current
    if cal.isDateInToday(d) { return "اليوم" }
    if cal.isDateInYesterday(d) { return "أمس" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "ar")
    f.dateFormat = "EEEE d MMMM"
    return f.string(from: d)
}

func pct(_ x: Double) -> String { "\(Int((x * 100).rounded()))٪" }
