import SwiftUI

// ───────────────────────── كلمات — بحث عن الكلمات ─────────────────────────
// لوحة ألوان برتقاليّة دافئة، ثيم غامق.

enum KL {
    static let bg = Color(red: 0.05, green: 0.045, blue: 0.06)
    static let s1 = Color(red: 0.10, green: 0.09, blue: 0.11)
    static let s2 = Color(red: 0.15, green: 0.13, blue: 0.16)
    static let s3 = Color(red: 0.21, green: 0.18, blue: 0.22)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.18)
    static let orange2 = Color(red: 1.0, green: 0.72, blue: 0.30)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.38)
    static let green = Color(red: 0.36, green: 0.86, blue: 0.56)
    static let tx1 = Color.white
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.42)

    /// ألوان تمييز الكلمات المكتشَفة (تتناوب)
    static let marks: [Color] = [
        Color(red: 1.0, green: 0.55, blue: 0.18),
        Color(red: 0.38, green: 0.70, blue: 1.0),
        Color(red: 0.42, green: 0.86, blue: 0.56),
        Color(red: 0.78, green: 0.55, blue: 1.0),
        Color(red: 1.0, green: 0.46, blue: 0.62),
        Color(red: 0.30, green: 0.82, blue: 0.80),
        Color(red: 1.0, green: 0.80, blue: 0.34),
        Color(red: 0.62, green: 0.80, blue: 0.40)
    ]
    static func mark(_ i: Int) -> Color { marks[((i % marks.count) + marks.count) % marks.count] }
}

// MARK: - حالة التطبيق (المراحل المحلولة محفوظة)

@MainActor
final class AppState: ObservableObject {
    @Published var solved: Set<Int> = []
    @Published var bestTimes: [Int: Int] = [:]

    private let kSolved = "kalimat_solved_v1"
    private let kTimes = "kalimat_times_v1"

    init() { load() }

    func load() {
        guard !Shot.on else { return }
        let d = UserDefaults.standard
        if let arr = d.array(forKey: kSolved) as? [Int] { solved = Set(arr) }
        if let dict = d.dictionary(forKey: kTimes) as? [String: Int] {
            bestTimes = Dictionary(uniqueKeysWithValues: dict.compactMap { k, v in Int(k).map { ($0, v) } })
        }
    }

    func markSolved(_ index: Int, time: Int) {
        solved.insert(index)
        if let prev = bestTimes[index] { bestTimes[index] = min(prev, time) } else { bestTimes[index] = time }
        save()
    }

    private func save() {
        guard !Shot.on else { return }
        let d = UserDefaults.standard
        d.set(Array(solved), forKey: kSolved)
        let dict = Dictionary(uniqueKeysWithValues: bestTimes.map { (String($0.key), $0.value) })
        d.set(dict, forKey: kTimes)
    }

    var nextUnsolved: Int {
        for i in 0..<Levels.count where !solved.contains(i) { return i }
        return 0
    }
    var progress: Double { Levels.count == 0 ? 0 : Double(solved.count) / Double(Levels.count) }
}

@main
struct KalimatApp: App {
    @StateObject private var app = AppState()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(KL.orange)
        }
    }
}

// MARK: - الخلفيّة

struct Backdrop: View {
    var body: some View {
        ZStack {
            KL.bg
            RadialGradient(colors: [KL.orange.opacity(0.16), .clear], center: .topTrailing, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [KL.gold.opacity(0.10), .clear], center: .bottomLeading, startRadius: 0, endRadius: 480)
        }
        .ignoresSafeArea()
    }
}

// MARK: - الجذر

struct RootView: View {
    @EnvironmentObject var app: AppState
    @State private var activeLevel: Int? = nil
    @State private var showHow = false

    var body: some View {
        ZStack {
            Backdrop()
            HomeView(onPlay: { idx in activeLevel = idx }, onHow: { showHow = true })
        }
        .fullScreenCover(item: Binding(get: { activeLevel.map { LevelRef(id: $0) } }, set: { activeLevel = $0?.id })) { ref in
            GameView(levelIndex: ref.id, onClose: { activeLevel = nil })
                .environmentObject(app)
        }
        .sheet(isPresented: $showHow) { HowToView() }
        .onAppear { applyShot() }
    }

    private func applyShot() {
        guard Shot.on else { return }
        if Shot.isAny("how") { showHow = true }
        else if Shot.isAny("game", "win") { activeLevel = 2 }
        else { activeLevel = nil }
    }
}

struct LevelRef: Identifiable { let id: Int }

// MARK: - الشاشة الرئيسيّة

struct HomeView: View {
    @EnvironmentObject var app: AppState
    let onPlay: (Int) -> Void
    let onHow: () -> Void

    private let cols = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                continueCard
                levelsHeader
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(0..<Levels.count, id: \.self) { i in
                        LevelTile(index: i, solved: app.solved.contains(i), onTap: { onPlay(i) })
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("كلمات")
                .font(rnd(46, .black))
                .foregroundStyle(LinearGradient(colors: [KL.orange2, KL.orange], startPoint: .top, endPoint: .bottom))
            Text("دوّر على الكلمات المخبّاية بالشبكة")
                .font(rnd(14, .semibold))
                .foregroundStyle(KL.tx2)
            Button(action: { Haptic.tap(); onHow() }) {
                Label("شلون ألعب؟", systemImage: "questionmark.circle.fill")
                    .font(rnd(13, .bold))
                    .foregroundStyle(KL.tx2)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(KL.s2, in: Capsule())
            }
            .buttonStyle(Press())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private var continueCard: some View {
        let idx = app.nextUnsolved
        let lvl = Levels.level(idx)
        return Button(action: { Haptic.thud(); onPlay(idx) }) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(app.solved.isEmpty ? "ابدأ اللعب" : "كمّل اللعب")
                        .font(rnd(19, .heavy)).foregroundStyle(KL.tx1)
                    Text("المرحلة \(idx + 1) · \(lvl.theme.emoji) \(lvl.theme.name)")
                        .font(rnd(13, .semibold)).foregroundStyle(KL.tx2)
                    ProgBar(value: app.progress)
                        .frame(height: 7).padding(.top, 2)
                    Text("حليت \(app.solved.count) من \(Levels.count)")
                        .font(rnd(11, .bold)).foregroundStyle(KL.tx3)
                }
                Spacer(minLength: 4)
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(KL.bg)
                    .frame(width: 54, height: 54)
                    .background(LinearGradient(colors: [KL.orange2, KL.orange], startPoint: .top, endPoint: .bottom), in: Circle())
            }
            .padding(16)
            .card(KL.s1, 22, stroke: KL.orange.opacity(0.22))
        }
        .buttonStyle(Press())
    }

    private var levelsHeader: some View {
        HStack {
            Text("المراحل").font(rnd(18, .heavy)).foregroundStyle(KL.tx1)
            Spacer()
            Text("\(Levels.themes.count) مواضيع").font(rnd(12, .bold)).foregroundStyle(KL.tx3)
        }
        .padding(.top, 4)
    }
}

struct ProgBar: View {
    let value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(KL.s3)
                Capsule()
                    .fill(LinearGradient(colors: [KL.orange, KL.gold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(7, g.size.width * CGFloat(min(1, max(0, value)))))
            }
        }
    }
}

struct LevelTile: View {
    let index: Int
    let solved: Bool
    let onTap: () -> Void

    var body: some View {
        let lvl = Levels.level(index)
        Button(action: { Haptic.tap(); onTap() }) {
            VStack(spacing: 7) {
                HStack {
                    Text("\(index + 1)")
                        .font(rnd(13, .black))
                        .foregroundStyle(solved ? KL.green : KL.tx3)
                    Spacer()
                    Image(systemName: solved ? "checkmark.seal.fill" : "lock.open.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(solved ? KL.green : KL.tx3.opacity(0.7))
                }
                Text(lvl.theme.emoji).font(.system(size: 30))
                Text(lvl.theme.name)
                    .font(rnd(13, .bold)).foregroundStyle(KL.tx1)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14).padding(.horizontal, 10)
            .card(solved ? KL.green.opacity(0.10) : KL.s1, 18,
                  stroke: solved ? KL.green.opacity(0.35) : Color.white.opacity(0.07))
        }
        .buttonStyle(Press())
    }
}

// MARK: - كيف ألعب

struct HowToView: View {
    @Environment(\.dismiss) private var dismiss
    private let steps: [(String, String, String)] = [
        ("hand.draw.fill", "اسحب على الحروف", "دوس وجرّ إصبعك فوق حروف متتالية بخطّ مستقيم — أفقيّ، عموديّ، أو مائل."),
        ("checkmark.circle.fill", "طابق الكلمة", "إذا الخطّ هجّى وحدة من كلمات القائمة، تنقفل بلون وتنشطب من القائمة."),
        ("arrow.left.arrow.right", "بالاتّجاهين", "الكلمة ممكن تنقري من اليمين لليسار أو العكس، وحتى بالقطر."),
        ("lightbulb.fill", "محتار؟ خذ تلميح", "زرّ التلميح يومض أوّل حرف من كلمة ما لگيتها بعد."),
        ("trophy.fill", "كمّل الكلمات", "لگّي كلّ الكلمات حتى تفوز وتفتح المرحلة الجاية.")
    ]

    var body: some View {
        ZStack {
            KL.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("شلون ألعب؟").font(rnd(26, .black)).foregroundStyle(KL.tx1)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28)).foregroundStyle(KL.tx3)
                        }
                    }
                    ForEach(0..<steps.count, id: \.self) { i in
                        HowRow(icon: steps[i].0, title: steps[i].1, text: steps[i].2, color: KL.mark(i))
                    }
                }
                .padding(20)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
}

struct HowRow: View {
    let icon: String
    let title: String
    let text: String
    let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 46, height: 46)
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(rnd(16, .heavy)).foregroundStyle(KL.tx1)
                Text(text).font(rnd(13, .medium)).foregroundStyle(KL.tx2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .card(KL.s1, 18)
    }
}
