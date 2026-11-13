import SwiftUI

enum QF {
    static let bg = Color(red: 0.05, green: 0.04, blue: 0.10)
    static let s1 = Color(red: 0.10, green: 0.09, blue: 0.18)
    static let s2 = Color(red: 0.16, green: 0.14, blue: 0.27)
    static let s3 = Color(red: 0.23, green: 0.21, blue: 0.36)
    static let ac = Color(red: 0.55, green: 0.45, blue: 1)
    static let gold = Color(red: 1, green: 0.82, blue: 0.3)
    static let green = Color(red: 0.3, green: 0.9, blue: 0.6)
    static let red = Color(red: 1, green: 0.36, blue: 0.42)
    static let tx2 = Color(white: 1, opacity: 0.72), tx3 = Color(white: 1, opacity: 0.45)
    /// لون المربّع حسب رقمه
    static func tile(_ n: Int) -> Color {
        [gold, Color(red: 0.2, green: 0.82, blue: 0.75), Color(red: 0.32, green: 0.6, blue: 1), Color(red: 0.62, green: 0.45, blue: 1), Color(red: 1, green: 0.42, blue: 0.62), Color(red: 1, green: 0.6, blue: 0.25)][max(0, min(5, n))]
    }
}

/// التقدّم: نجوم كلّ مرحلة + المراحل المولَّدة (حتى ما تنحسب كلّ مرّة)
@MainActor
final class Saved: ObservableObject {
    @Published var stars: [Int: Int] = [:]
    @Published var dailyDone = ""
    private let ud = UserDefaults.standard
    private var cache: [Int: Level] = [:]

    init() {
        if Shot.on { for i in 0..<13 { stars[i] = [3, 3, 2, 3, 1, 3, 2, 3, 3, 2, 3, 3, 1][i] }; return }
        if let d = ud.data(forKey: "qf_stars"), let v = try? JSONDecoder().decode([Int: Int].self, from: d) { stars = v }
        dailyDone = ud.string(forKey: "qf_daily") ?? ""
    }
    var next: Int { min(Hops.total - 1, (stars.keys.max() ?? -1) + 1) }
    var totalStars: Int { stars.values.reduce(0, +) }
    func unlocked(_ i: Int) -> Bool { i <= next }
    func win(_ i: Int, _ s: Int) {
        stars[i] = max(stars[i] ?? 0, s)
        guard !Shot.on else { return }
        if let d = try? JSONEncoder().encode(stars) { ud.set(d, forKey: "qf_stars") }
    }
    static var today: String { let c = Calendar.current.dateComponents([.year, .month, .day], from: Date()); return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)" }
    func winDaily() { dailyDone = Saved.today; ud.set(dailyDone, forKey: "qf_daily") }

    /// المرحلة (من الكاش، أو تتولّد بالخلفيّة)
    func level(_ i: Int) async -> Level {
        if let l = cache[i] { return l }
        if let d = ud.data(forKey: "qf_level_\(i)"), let l = try? JSONDecoder().decode(Level.self, from: d) { cache[i] = l; return l }
        let l = await Task.detached(priority: .userInitiated) { Hops.level(i) }.value
        cache[i] = l
        if let d = try? JSONEncoder().encode(l) { ud.set(d, forKey: "qf_level_\(i)") }
        return l
    }
    func daily() async -> Level {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let y = c.year ?? 2026, m = c.month ?? 1, d = c.day ?? 1
        return await Task.detached(priority: .userInitiated) { Hops.daily(year: y, month: m, day: d) }.value
    }
}

enum Stage: Identifiable, Hashable {
    case level(Int), daily
    var id: String {
        if case .level(let i) = self { return "l\(i)" }
        return "d"
    }
}

@main
struct QafzaApp: App {
    @StateObject private var prog = Saved()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(prog)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(QF.ac)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            QF.bg
            RadialGradient(colors: [QF.ac.opacity(0.28), Color.clear], center: .top, startRadius: 0, endRadius: 480)
            RadialGradient(colors: [Color(red: 1, green: 0.4, blue: 0.6).opacity(0.12), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 400)
        }.ignoresSafeArea()
    }
}

struct HomeView: View {
    @EnvironmentObject var prog: Saved
    @AppStorage("qf_seen_how") private var seenHow = false
    @State private var stage: Stage? = nil
    @State private var how = false
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 9), count: 5)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("قفزة").font(rnd(40, .black)).foregroundStyle(Color.white)
                        Text("اقفز على كلّ المربّعات — مرّة وحدة لكلّ مربّع").font(rnd(13)).foregroundStyle(QF.tx3)
                    }
                    Spacer()
                    Button { how = true } label: { Image(systemName: "questionmark").font(.system(size: 16, weight: .black)).foregroundStyle(Color.white).frame(width: 44, height: 44).background(QF.s2, in: Circle()) }.buttonStyle(Press())
                }

                Button { stage = .level(prog.next) } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prog.stars.isEmpty ? "ابدي اللعب" : "كمّل").font(rnd(15, .heavy)).opacity(0.8)
                            Text("المرحلة \(prog.next + 1)").font(rnd(30, .black))
                            let s = Hops.size(prog.next)
                            Text("\(s.w)×\(s.h) مربّع").font(rnd(13, .bold)).opacity(0.75).environment(\.layoutDirection, .leftToRight)
                        }
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 26, weight: .black)).frame(width: 66, height: 66).background(Color.white.opacity(0.2), in: Circle())
                    }
                    .foregroundStyle(Color.white).padding(18)
                    .background(LinearGradient(colors: [QF.ac, Color(red: 0.85, green: 0.4, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: QF.ac.opacity(0.45), radius: 20, y: 8)
                }.buttonStyle(Press())

                HStack(spacing: 10) {
                    stat("\(prog.stars.count)/\(Hops.total)", "مرحلة", "flag.checkered", QF.green)
                    stat("\(prog.totalStars)", "نجمة", "star.fill", QF.gold)
                    Button { stage = .daily } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Image(systemName: prog.dailyDone == Saved.today ? "checkmark.seal.fill" : "calendar").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(red: 1, green: 0.5, blue: 0.65))
                            Text("لغز اليوم").font(rnd(17, .black)).foregroundStyle(Color.white)
                            Text(prog.dailyDone == Saved.today ? "حلّيته ✓" : "جديد كلّ يوم").font(rnd(11.5)).foregroundStyle(QF.tx3)
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).card(QF.s1, 18, stroke: Color(red: 1, green: 0.5, blue: 0.65).opacity(0.3))
                    }.buttonStyle(Press())
                }

                Text("المراحل").font(rnd(18, .heavy)).foregroundStyle(Color.white)
                LazyVGrid(columns: cols, spacing: 9) {
                    ForEach(0..<Hops.total, id: \.self) { i in
                        let open = prog.unlocked(i), st = prog.stars[i] ?? 0
                        Button { if open { stage = .level(i) } } label: {
                            VStack(spacing: 3) {
                                if open { Text("\(i + 1)").font(rnd(19, .black)).foregroundStyle(Color.white) } else { Image(systemName: "lock.fill").font(.system(size: 14)).foregroundStyle(QF.tx3) }
                                HStack(spacing: 1.5) { ForEach(0..<3, id: \.self) { k in Image(systemName: "star.fill").font(.system(size: 7.5)).foregroundStyle(k < st ? QF.gold : Color(white: 1, opacity: 0.14)) } }
                            }
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .background(i == prog.next ? QF.ac.opacity(0.35) : (st > 0 ? QF.s2 : QF.s1), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(i == prog.next ? QF.ac : Color(white: 1, opacity: 0.06), lineWidth: i == prog.next ? 2 : 1))
                        }.buttonStyle(Press()).opacity(open ? 1 : 0.55)
                    }
                }.environment(\.layoutDirection, .leftToRight)
            }.padding(18)
        }
        .background(Backdrop())
        .fullScreenCover(item: $stage) { s in GameView(stage: s) { n in stage = n }.environmentObject(prog).environment(\.layoutDirection, .rightToLeft) }
        .sheet(isPresented: $how, onDismiss: { seenHow = true }) { HowView { how = false }.environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .onAppear {
            if Shot.isAny("game", "win", "stuck", "hint") { stage = .level(13) }
            else if Shot.name == "how" || (!seenHow && !Shot.on) { how = true }
        }
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(20, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(11.5)).foregroundStyle(QF.tx3)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).card(QF.s1, 18, stroke: c.opacity(0.25))
    }
}

/// شرح اللعبة
struct HowView: View {
    let done: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("شلون ألعب؟").font(rnd(30, .black)).foregroundStyle(Color.white)
            VStack(alignment: .leading, spacing: 14) {
                rule("2", QF.tile(2), "الرقم = طول القفزة", "من المربّع اللي عليه «2» تقفز مربّعين بالضبط — فوق، جوّه، يمين، أو يسار.")
                rule("✓", QF.s3, "كلّ مربّع مرّة وحدة", "المربّع اللي تمرّ عليه ينطفي وما ترجعله.")
                rule("★", QF.gold, "خلّص عند النجمة", "النجمة آخر محطّة. إذا وصلتها وباقي مربّعات، ارجع خطوة.")
            }
            Spacer()
            Button(action: done) {
                Text("يلّا").font(rnd(18, .black)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 56).background(QF.ac, in: Capsule())
            }.buttonStyle(Press())
            Text("ثلاث نجوم = حلّيتها بلا رجوع وبلا تلميح.").font(rnd(12)).foregroundStyle(QF.tx3)
        }.padding(24).background(QF.bg.ignoresSafeArea())
    }
    private func rule(_ sym: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(sym).font(rnd(24, .black)).foregroundStyle(Color.black.opacity(0.75)).frame(width: 56, height: 56).background(c.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) { Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white); Text(s).font(rnd(13.5)).foregroundStyle(QF.tx2).lineSpacing(3) }
        }
    }
}
