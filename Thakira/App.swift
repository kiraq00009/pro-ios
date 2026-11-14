import SwiftUI

// MARK: - Palette (own to Thakira; dark, warm amber identity)
enum Pal {
    static let bg      = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let bg2     = Color(red: 0.09, green: 0.09, blue: 0.12)
    static let surface = Color(red: 0.13, green: 0.13, blue: 0.17)
    static let surface2 = Color(red: 0.17, green: 0.16, blue: 0.21)
    static let amber   = Color(red: 1.00, green: 0.62, blue: 0.20)
    static let amberDeep = Color(red: 0.95, green: 0.42, blue: 0.11)
    static let gold    = Color(red: 1.00, green: 0.80, blue: 0.35)
    static let mint    = Color(red: 0.35, green: 0.86, blue: 0.62)
    static let sky     = Color(red: 0.38, green: 0.70, blue: 1.00)
    static let violet  = Color(red: 0.72, green: 0.55, blue: 1.00)
    static let rose     = Color(red: 1.00, green: 0.45, blue: 0.55)
    static let text    = Color.white
    static let dim     = Color.white.opacity(0.55)
    static let faint   = Color.white.opacity(0.08)

    static let heroGrad = LinearGradient(
        colors: [amber, amberDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let bgGrad = LinearGradient(
        colors: [bg, bg2],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - App entry
@main
struct ThakiraApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(Pal.amber)
        }
    }
}

// MARK: - Navigation root
enum Screen: Equatable {
    case home
    case match(GridSize)
    case sequence
}

final class Nav: ObservableObject {
    @Published var screen: Screen = .home
}

struct RootView: View {
    @StateObject private var nav = Nav()
    @StateObject private var store = Scores()

    var body: some View {
        ZStack {
            Pal.bgGrad.ignoresSafeArea()
            content
        }
        .environmentObject(nav)
        .environmentObject(store)
        .onAppear(perform: seedForShot)
    }

    @ViewBuilder
    private var content: some View {
        switch nav.screen {
        case .home:
            HomeView()
                .transition(.opacity)
        case .match(let size):
            MatchGameView(size: size)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .sequence:
            SequenceGameView()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    // Jump straight to a seeded state for App Store screenshots.
    private func seedForShot() {
        guard Shot.on else { return }
        if Shot.isAny("game", "win") {
            nav.screen = .match(.m4x4)
        } else if Shot.isAny("seq") {
            nav.screen = .sequence
        } else {
            nav.screen = .home
        }
    }
}

// MARK: - Grid sizes (difficulty)
enum GridSize: Int, CaseIterable, Identifiable {
    case m4x4, m4x6, m6x6
    var id: Int { rawValue }
    var cols: Int { self == .m6x6 ? 6 : 4 }
    var rows: Int {
        switch self {
        case .m4x4: return 4
        case .m4x6: return 6
        case .m6x6: return 6
        }
    }
    var pairs: Int { (cols * rows) / 2 }
    var title: String {
        switch self {
        case .m4x4: return "سهل"
        case .m4x6: return "متوسط"
        case .m6x6: return "صعب"
        }
    }
    // LTR digits inside RTL text.
    var sub: String { "\u{2066}\(cols)×\(rows)\u{2069}" }
    var key: String { "4x4_4x6_6x6".components(separatedBy: "_")[rawValue] }
}

// MARK: - Persisted best scores (guarded against screenshot mode)
final class Scores: ObservableObject {
    @Published var bestMoves: [String: Int] = [:]
    @Published var bestTime: [String: Int] = [:]
    @Published var seqBest: Int = 0

    private let dMoves = "thakira.bestMoves"
    private let dTime  = "thakira.bestTime"
    private let dSeq   = "thakira.seqBest"

    init() {
        let d = UserDefaults.standard
        bestMoves = (d.dictionary(forKey: dMoves) as? [String: Int]) ?? [:]
        bestTime  = (d.dictionary(forKey: dTime) as? [String: Int]) ?? [:]
        seqBest   = d.integer(forKey: dSeq)
        if Shot.on { seedShotScores() }
    }

    func submitMatch(size: GridSize, moves: Int, time: Int) {
        let k = size.key
        if let m = bestMoves[k] { if moves < m { bestMoves[k] = moves } } else { bestMoves[k] = moves }
        if let t = bestTime[k] { if time < t { bestTime[k] = time } } else { bestTime[k] = time }
        persist()
    }

    func submitSeq(_ score: Int) {
        if score > seqBest { seqBest = score; persist() }
    }

    private func persist() {
        guard !Shot.on else { return }
        let d = UserDefaults.standard
        d.set(bestMoves, forKey: dMoves)
        d.set(bestTime, forKey: dTime)
        d.set(seqBest, forKey: dSeq)
    }

    private func seedShotScores() {
        bestMoves = ["4x4": 11, "4x6": 19, "6x6": 31]
        bestTime  = ["4x4": 38, "4x6": 72, "6x6": 141]
        seqBest = 14
    }
}

// MARK: - Helpers for LTR digits inside RTL
func ltr(_ s: String) -> String { "\u{2066}" + s + "\u{2069}" }
func fmtTime(_ sec: Int) -> String {
    let m = sec / 60
    let s = sec % 60
    return ltr(String(format: "%d:%02d", m, s))
}

// MARK: - Home
struct HomeView: View {
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var store: Scores
    @State private var pickSize = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                modeCards
                bestsPanel
                howTo
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .onAppear { if Shot.isAny("home") { pickSize = false } }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Pal.heroGrad)
                    .frame(width: 92, height: 92)
                    .shadow(color: Pal.amber.opacity(0.5), radius: 22, y: 8)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 10)
            Text("ذاكرة")
                .font(rnd(40, weight: .heavy))
                .foregroundStyle(Pal.text)
            Text("درّب عقلك كل يوم")
                .font(rnd(16))
                .foregroundStyle(Pal.dim)
        }
        .frame(maxWidth: .infinity)
    }

    private var modeCards: some View {
        VStack(spacing: 14) {
            ModeCard(
                title: "مطابقة",
                desc: "دوّر الأزواج المتشابهة",
                icon: "square.grid.3x3.fill",
                grad: LinearGradient(colors: [Pal.amber, Pal.amberDeep], startPoint: .leading, endPoint: .trailing),
                action: { pickSize = true })
            ModeCard(
                title: "تسلسل",
                desc: "احفظ التسلسل وعيده",
                icon: "waveform.path.ecg",
                grad: LinearGradient(colors: [Pal.sky, Pal.violet], startPoint: .leading, endPoint: .trailing),
                action: { withAnimation(.easeInOut) { nav.screen = .sequence } })
        }
        .sheet(isPresented: $pickSize) {
            DifficultySheet { size in
                pickSize = false
                withAnimation(.easeInOut) { nav.screen = .match(size) }
            }
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
    }

    private var bestsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("أفضل النتائج")
                .font(rnd(18, weight: .bold))
                .foregroundStyle(Pal.text)
            HStack(spacing: 10) {
                ForEach(GridSize.allCases) { size in
                    BestTile(size: size,
                             moves: store.bestMoves[size.key],
                             time: store.bestTime[size.key])
                }
            }
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(Pal.sky)
                Text("تسلسل — أفضل")
                    .font(rnd(15))
                    .foregroundStyle(Pal.dim)
                Spacer()
                Text(store.seqBest > 0 ? ltr("\(store.seqBest)") : "—")
                    .font(rnd(20, weight: .bold))
                    .foregroundStyle(Pal.gold)
            }
            .padding(14)
            .card(bg: Pal.surface, r: 16, stroke: Pal.faint)
        }
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("كيف تلعب")
                .font(rnd(18, weight: .bold))
                .foregroundStyle(Pal.text)
            HowRow(icon: "hand.tap.fill", text: "اقلب ورقتين، إذا تطابقن يبقن مكشوفات")
            HowRow(icon: "timer", text: "كل ما تخلّص بحركات ووقت أقل، نتيجتك أحسن")
            HowRow(icon: "eye.fill", text: "بالتسلسل: راقب الأضواء وعيدها بنفس الترتيب")
        }
        .padding(16)
        .card(bg: Pal.surface, r: 18, stroke: Pal.faint)
    }
}

// MARK: - Home sub-views
struct ModeCard: View {
    let title: String
    let desc: String
    let icon: String
    let grad: LinearGradient
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(grad)
                        .frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(rnd(22, weight: .bold))
                        .foregroundStyle(Pal.text)
                    Text(desc)
                        .font(rnd(14))
                        .foregroundStyle(Pal.dim)
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Pal.dim)
            }
            .padding(16)
            .card(bg: Pal.surface, r: 20, stroke: Pal.faint)
        }
        .buttonStyle(Press())
    }
}

struct BestTile: View {
    let size: GridSize
    let moves: Int?
    let time: Int?
    var body: some View {
        VStack(spacing: 6) {
            Text(size.title)
                .font(rnd(14, weight: .bold))
                .foregroundStyle(Pal.amber)
            Text(size.sub)
                .font(rnd(11))
                .foregroundStyle(Pal.dim)
            Divider().background(Pal.faint)
            if let m = moves {
                Text(ltr("\(m)") + " حركة")
                    .font(rnd(12, weight: .semibold))
                    .foregroundStyle(Pal.text)
            } else {
                Text("—")
                    .font(rnd(12))
                    .foregroundStyle(Pal.dim)
            }
            if let t = time {
                Text(fmtTime(t))
                    .font(rnd(12))
                    .foregroundStyle(Pal.dim)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card(bg: Pal.bg2, r: 14, stroke: Pal.faint)
    }
}

struct HowRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Pal.amber)
                .frame(width: 26)
            Text(text)
                .font(rnd(14))
                .foregroundStyle(Pal.dim)
            Spacer()
        }
    }
}

struct DifficultySheet: View {
    let pick: (GridSize) -> Void
    var body: some View {
        ZStack {
            Pal.bg2.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("اختر الصعوبة")
                    .font(rnd(22, weight: .bold))
                    .foregroundStyle(Pal.text)
                    .padding(.top, 8)
                ForEach(GridSize.allCases) { size in
                    Button {
                        pick(size)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(size.title)
                                    .font(rnd(18, weight: .bold))
                                    .foregroundStyle(Pal.text)
                                Text(size.sub + " — " + ltr("\(size.pairs)") + " زوج")
                                    .font(rnd(13))
                                    .foregroundStyle(Pal.dim)
                            }
                            Spacer()
                            Image(systemName: "chevron.left")
                                .foregroundStyle(Pal.amber)
                        }
                        .padding(16)
                        .card(bg: Pal.surface, r: 16, stroke: Pal.faint)
                    }
                    .buttonStyle(Press())
                }
                Spacer()
            }
            .padding(18)
        }
    }
}
