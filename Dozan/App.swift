import SwiftUI

enum DZ {
    static let bg = Color(red: 0.035, green: 0.03, blue: 0.075)
    static let s1 = Color(red: 0.075, green: 0.066, blue: 0.14)
    static let s2 = Color(red: 0.125, green: 0.11, blue: 0.215)
    static let s3 = Color(red: 0.19, green: 0.165, blue: 0.30)
    static let mint = Color(red: 0.30, green: 1.0, blue: 0.76)
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.32)
    static let rose = Color(red: 1.0, green: 0.38, blue: 0.53)
    static let violet = Color(red: 0.63, green: 0.47, blue: 1.0)
    static let sky = Color(red: 0.36, green: 0.73, blue: 1.0)
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.45)
    static let ink = Color(red: 0.04, green: 0.05, blue: 0.09)

    static var grad: LinearGradient {
        LinearGradient(colors: [mint, sky, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func tuneColor(_ c: Double, tol: Double) -> Color {
        let a = abs(c)
        if a <= tol { return mint }
        if a <= 15 { return amber }
        return rose
    }

    static func pitchColor(_ cents: Double, tol: Double) -> Color {
        let a = abs(cents)
        if a <= tol { return mint }
        if a <= tol * 2 { return amber }
        return rose
    }
}

enum DZTab: Int, CaseIterable {
    case tuner, trainer, tools, me

    var title: String {
        switch self {
        case .tuner: return "الموالف"
        case .trainer: return "الغناء"
        case .tools: return "الأدوات"
        case .me: return "إنجازاتي"
        }
    }

    var symbol: String {
        switch self {
        case .tuner: return "tuningfork"
        case .trainer: return "music.mic"
        case .tools: return "metronome.fill"
        case .me: return "chart.bar.xaxis"
        }
    }
}

@main
struct DozanApp: App {
    @StateObject private var store = DozanStore()
    @StateObject private var mic = MicPitch()
    @StateObject private var synth = ToneEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(mic)
                .environmentObject(synth)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(DZ.mint)
        }
    }
}

struct DZBackdrop: View {
    var accent: Color = DZ.violet
    var body: some View {
        ZStack {
            DZ.bg
            RadialGradient(colors: [accent.opacity(0.30), Color.clear], center: .top, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [DZ.mint.opacity(0.10), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
    }
}

struct RootView: View {
    @EnvironmentObject var store: DozanStore
    @EnvironmentObject var mic: MicPitch
    @State private var tab: DZTab = .tuner
    @State private var onboarding = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .tuner: TunerView()
                case .trainer: TrainerView()
                case .tools: ToolsView()
                case .me: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 74) }
            DZTabBar(tab: $tab)
        }
        .background(DZBackdrop())
        .onAppear(perform: boot)
        .onChange(of: store.settings.a4) { v in mic.a4 = v }
        .fullScreenCover(isPresented: $onboarding) {
            OnboardingView { onboarding = false }
                .environmentObject(store)
                .environmentObject(mic)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
    }

    private func boot() {
        mic.a4 = store.settings.a4
        if Shot.on {
            switch Shot.name {
            case "session", "trainer", "range": tab = .trainer
            case "tools": tab = .tools
            case "stats": tab = .me
            case "onboard": onboarding = true
            default: tab = .tuner
            }
        } else if !store.profile.onboarded {
            onboarding = true
        }
    }
}

struct DZTabBar: View {
    @Binding var tab: DZTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DZTab.allCases, id: \.rawValue) { t in
                item(t)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08)))
        .shadow(color: Color.black.opacity(0.45), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func item(_ t: DZTab) -> some View {
        let on = tab == t
        return Button {
            if tab != t { Haptic.tap() }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = t }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: t.symbol).font(.system(size: 17, weight: .bold))
                Text(t.title).font(rnd(10.5, .heavy)).lineLimit(1)
            }
            .foregroundStyle(on ? Color.black.opacity(0.85) : DZ.tx2)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                if on {
                    Capsule().fill(DZ.grad).matchedGeometryEffect(id: "pill", in: ns)
                        .shadow(color: DZ.mint.opacity(0.45), radius: 10)
                }
            }
        }
        .buttonStyle(Press())
    }
}

// MARK: عناصر مشتركة

struct SectionTitle: View {
    let text: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(rnd(19, .black)).foregroundStyle(Color.white)
            if let s = sub { Text(s).font(rnd(12.5)).foregroundStyle(DZ.tx3) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChipButton: View {
    let text: String
    let on: Bool
    var color: Color = DZ.mint
    let action: () -> Void
    var body: some View {
        Button { Haptic.tap(); action() } label: {
            Text(text).font(rnd(13.5, .heavy))
                .foregroundStyle(on ? Color.black.opacity(0.85) : Color.white)
                .padding(.horizontal, 14).frame(height: 38)
                .background(on ? color : DZ.s2, in: Capsule())
        }
        .buttonStyle(Press())
    }
}

struct GlowButton: View {
    let title: String
    let symbol: String
    var colors: [Color] = [DZ.mint, DZ.sky]
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol).font(.system(size: 16, weight: .black))
                Text(title).font(rnd(17, .black))
            }
            .foregroundStyle(Color.black.opacity(0.85))
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: (colors.first ?? DZ.mint).opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(Press())
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            Text(value).font(rnd(20, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(rnd(10.5)).foregroundStyle(DZ.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(DZ.s1, 16, stroke: color.opacity(0.22))
    }
}

struct StarsRow: View {
    let count: Int
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < count ? DZ.amber : DZ.tx3.opacity(0.6))
            }
        }
    }
}

struct MicBanner: View {
    @EnvironmentObject var mic: MicPitch
    var body: some View {
        if mic.denied || mic.failed {
            HStack(spacing: 10) {
                Image(systemName: "mic.slash.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(DZ.rose)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mic.denied ? "المايك مسكّر" : "ما گدرنا نشغّل المايك").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                    Text(mic.denied ? "افتح الإعدادات واسمح لـ«دوزان» يستخدم المايكروفون" : "سكّر التطبيقات اللي تستخدم الصوت وارجع").font(rnd(11.5)).foregroundStyle(DZ.tx3)
                }
                Spacer(minLength: 0)
                if mic.denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Text("الإعدادات").font(rnd(12.5, .heavy)).foregroundStyle(Color.black.opacity(0.85)).padding(.horizontal, 12).frame(height: 32).background(DZ.rose, in: Capsule())
                    }.buttonStyle(Press())
                }
            }
            .padding(12)
            .card(DZ.s1, 18, stroke: DZ.rose.opacity(0.35))
        }
    }
}
