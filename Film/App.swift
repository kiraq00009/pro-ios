import SwiftUI

// MARK: - Brand palette

enum DW {
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.055)
    static let bg2 = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let card = Color(red: 0.11, green: 0.11, blue: 0.135)
    static let card2 = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let orange = Color(red: 1, green: 0.48, blue: 0.12)
    static let orange2 = Color(red: 1, green: 0.62, blue: 0.2)
    static let text = Color.white
    static let dim = Color.white.opacity(0.62)
    static let faint = Color.white.opacity(0.4)
    static let stroke = Color.white.opacity(0.08)

    static var grad: LinearGradient {
        LinearGradient(colors: [orange, orange2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var pageGrad: LinearGradient {
        LinearGradient(colors: [bg2, bg],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Light persistence (guarded against screenshot mode)

enum Store {
    private static let hsKey = "film_high_score"
    private static let wheelKey = "film_last_wheel"

    static var highScore: Int {
        get { UserDefaults.standard.integer(forKey: hsKey) }
        set { if !Shot.on { UserDefaults.standard.set(newValue, forKey: hsKey) } }
    }
    static var lastWheel: String {
        get { UserDefaults.standard.string(forKey: wheelKey) ?? "" }
        set { if !Shot.on { UserDefaults.standard.set(newValue, forKey: wheelKey) } }
    }
}

// MARK: - App entry

@main
struct FilmApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(DW.orange)
        }
    }
}

// MARK: - Root (tab bar + screenshot routing)

enum Tab: Int, CaseIterable {
    case home, wheel, duel, vote, guess
    var title: String {
        switch self {
        case .home: return "البيت"
        case .wheel: return "العجلة"
        case .duel: return "هذا أو هذا"
        case .vote: return "تصويت"
        case .guess: return "خمّن"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .wheel: return "dial.medium.fill"
        case .duel: return "arrow.left.arrow.right"
        case .vote: return "chart.bar.fill"
        case .guess: return "questionmark.circle.fill"
        }
    }
}

struct RootView: View {
    @State private var tab: Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            DW.pageGrad.ignoresSafeArea()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 74)
            TabBar(tab: $tab)
        }
        .onAppear(perform: routeForScreenshot)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home: HomeView(go: { tab = $0 })
        case .wheel: WheelView()
        case .duel: DuelView()
        case .vote: VoteView()
        case .guess: GuessView()
        }
    }

    private func routeForScreenshot() {
        guard Shot.on else { return }
        if Shot.isAny("wheel") { tab = .wheel }
        else if Shot.isAny("duel") { tab = .duel }
        else if Shot.isAny("vote") { tab = .vote }
        else if Shot.isAny("guess") { tab = .guess }
        else { tab = .home }
    }
}

// MARK: - Tab bar (floating glass)

struct TabBar: View {
    @Binding var tab: Tab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.rawValue) { t in
                Button {
                    Haptic.tap()
                    tab = t
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(t.title)
                            .font(rnd(9, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(tab == t ? DW.orange : DW.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(Press())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DW.stroke, lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}

// MARK: - Shared small pieces

/// Dawwirli open-link button.
struct DawwirliButton: View {
    @Environment(\.openURL) private var openURL
    var deepLink: String? = nil

    private var url: URL {
        var s = "https://dawwirli.watch"
        if let d = deepLink, !d.isEmpty { s += d }
        return URL(string: s) ?? URL(string: "https://dawwirli.watch")!
    }

    var body: some View {
        Button {
            Haptic.ok()
            openURL(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                Text("افتح دورلي")
                    .font(rnd(16, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DW.grad, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(Press())
    }
}

/// Section header with accent bar.
struct Header: View {
    let title: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Capsule().fill(DW.grad).frame(width: 5, height: 22)
                Text(title).font(rnd(24, weight: .heavy)).foregroundStyle(DW.text)
            }
            if let sub = sub {
                Text(sub).font(rnd(13)).foregroundStyle(DW.dim)
                    .padding(.leading, 13)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
