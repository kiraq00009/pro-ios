import SwiftUI

@main
struct MasarApp: App {
    @StateObject private var store = MasarStore()
    @StateObject private var tracker = Tracker()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(tracker)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(MT.mint)
        }
    }
}

enum MTab: Int, CaseIterable {
    case track, territory, profile, history

    var title: String {
        switch self {
        case .track: return "جولة"
        case .territory: return "منطقتي"
        case .profile: return "إنجازاتي"
        case .history: return "السجلّ"
        }
    }

    var icon: String {
        switch self {
        case .track: return "location.north.circle.fill"
        case .territory: return "hexagon.fill"
        case .profile: return "crown.fill"
        case .history: return "list.bullet.rectangle.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: MasarStore
    @EnvironmentObject var tracker: Tracker
    @AppStorage("ms_onboarded") private var onboarded = false
    @State private var tab: MTab = .track
    @State private var onboard = false
    @State private var shotSession: Session? = nil
    @State private var booted = false

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: tab == .track ? 64 : 74) }
            TabBar(tab: $tab, live: tracker.isActive)
        }
        .background(MT.bg.ignoresSafeArea())
        .onAppear(perform: boot)
        .fullScreenCover(isPresented: $onboard) {
            OnboardView { onboarded = true; onboard = false }
                .environmentObject(tracker)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .sheet(item: $tracker.finished) { s in
            SessionView(session: s, fresh: true) { tracker.finished = nil }
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .sheet(item: $shotSession) { s in
            SessionView(session: s, fresh: false) { shotSession = nil }
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .track: TrackView()
        case .territory: TerritoryView()
        case .profile: ProfileView()
        case .history: HistoryView()
        }
    }

    private func boot() {
        guard !booted else { return }
        booted = true
        if Shot.on {
            switch Shot.name {
            case "track": tracker.loadDemo(store); tab = .track
            case "territory": tab = .territory
            case "profile", "settings": tab = .profile
            case "history": tab = .history
            case "summary":
                tab = .history
                if let s = store.sessions.first(where: { $0.activity == .run && $0.loops > 0 }) ?? store.sessions.first {
                    store.justEarned = []
                    shotSession = s
                }
            case "onboard": onboard = true
            default: tab = .track
            }
            return
        }
        if !onboarded { onboard = true }
    }
}

struct TabBar: View {
    @Binding var tab: MTab
    let live: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MTab.allCases, id: \.rawValue) { t in
                item(t)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08)))
        .shadow(color: Color.black.opacity(0.4), radius: 18, y: 8)
        .padding(.horizontal, 16).padding(.bottom, 4)
    }

    private func item(_ t: MTab) -> some View {
        let on = tab == t
        return Button {
            guard tab != t else { return }
            Haptic.tap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { tab = t }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: t.icon).font(.system(size: 19, weight: .bold))
                    if t == .track && live && !on {
                        Circle().fill(MT.coral).frame(width: 8, height: 8).offset(x: 4, y: -2)
                    }
                }
                Text(t.title).font(rnd(10.5, .heavy))
            }
            .foregroundStyle(on ? MT.ink : MT.tx2)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(on ? AnyShapeStyle(MT.brand) : AnyShapeStyle(Color.clear), in: Capsule())
        }.buttonStyle(Press())
    }
}
