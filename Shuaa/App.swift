import SwiftUI

enum SU {
    static let bg = Color(red: 0.02, green: 0.03, blue: 0.07)
    static let s1 = Color(red: 0.06, green: 0.08, blue: 0.15)
    static let s2 = Color(red: 0.10, green: 0.13, blue: 0.23)
    static let s3 = Color(red: 0.17, green: 0.21, blue: 0.34)
    static let beam = Color(red: 0.25, green: 0.95, blue: 1)
    static let pink = Color(red: 1, green: 0.35, blue: 0.75)
    static let gold = Color(red: 1, green: 0.82, blue: 0.3)
    static let green = Color(red: 0.35, green: 0.95, blue: 0.6)
    static let tx2 = Color(white: 1, opacity: 0.72), tx3 = Color(white: 1, opacity: 0.45)
}

@MainActor
final class Saved: ObservableObject {
    @Published var stars: [Int: Int] = [:]
    @Published var dailyDone = ""
    private let ud = UserDefaults.standard
    private var cache: [Int: BeamLevel] = [:]
    init() {
        if Shot.on { for i in 0..<17 { stars[i] = [3, 3, 2, 3, 3, 1, 3, 2, 3, 3, 3, 2, 3, 1, 3, 3, 2][i] }; return }
        if let d = ud.data(forKey: "su_stars"), let v = try? JSONDecoder().decode([Int: Int].self, from: d) { stars = v }
        dailyDone = ud.string(forKey: "su_daily") ?? ""
    }
    var next: Int { min(Beam.total - 1, (stars.keys.max() ?? -1) + 1) }
    var totalStars: Int { stars.values.reduce(0, +) }
    func unlocked(_ i: Int) -> Bool { i <= next }
    func win(_ i: Int, _ s: Int) {
        stars[i] = max(stars[i] ?? 0, s)
        guard !Shot.on else { return }
        if let d = try? JSONEncoder().encode(stars) { ud.set(d, forKey: "su_stars") }
    }
    static var today: String { let c = Calendar.current.dateComponents([.year, .month, .day], from: Date()); return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)" }
    func winDaily() { dailyDone = Saved.today; ud.set(dailyDone, forKey: "su_daily") }
    func level(_ i: Int) async -> BeamLevel {
        if let l = cache[i] { return l }
        if let d = ud.data(forKey: "su_level_\(i)"), let l = try? JSONDecoder().decode(BeamLevel.self, from: d) { cache[i] = l; return l }
        let l = await Task.detached(priority: .userInitiated) { Beam.level(i) }.value
        cache[i] = l
        if let d = try? JSONEncoder().encode(l) { ud.set(d, forKey: "su_level_\(i)") }
        return l
    }
    func daily() async -> BeamLevel {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let y = c.year ?? 2026, m = c.month ?? 1, d = c.day ?? 1
        return await Task.detached(priority: .userInitiated) { Beam.daily(year: y, month: m, day: d) }.value
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
struct ShuaaApp: App {
    @StateObject private var prog = Saved()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(prog)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(SU.beam)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            SU.bg
            RadialGradient(colors: [SU.beam.opacity(0.2), Color.clear], center: .topLeading, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [SU.pink.opacity(0.16), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }
}

struct HomeView: View {
    @EnvironmentObject var prog: Saved
    @AppStorage("su_seen_how") private var seenHow = false
    @State private var stage: Stage? = nil
    @State private var how = false
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 9), count: 5)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("شعاع").font(rnd(40, .black)).foregroundStyle(Color.white)
                        Text("اقلب المرايا ووجّه الليزر على كلّ الأهداف").font(rnd(13)).foregroundStyle(SU.tx3)
                    }
                    Spacer()
                    Button { how = true } label: { Image(systemName: "questionmark").font(.system(size: 16, weight: .black)).foregroundStyle(Color.white).frame(width: 44, height: 44).background(SU.s2, in: Circle()) }.buttonStyle(Press())
                }
                Button { stage = .level(prog.next) } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prog.stars.isEmpty ? "ابدي اللعب" : "كمّل").font(rnd(15, .heavy)).opacity(0.75)
                            Text("المرحلة \(prog.next + 1)").font(rnd(30, .black))
                            Text("\(Beam.spec(prog.next).mirrors) مرايا · \(Beam.spec(prog.next).targets) أهداف").font(rnd(13, .bold)).opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 26, weight: .black)).frame(width: 66, height: 66).background(Color.black.opacity(0.18), in: Circle())
                    }
                    .foregroundStyle(Color.black.opacity(0.82)).padding(18)
                    .background(LinearGradient(colors: [SU.beam, Color(red: 0.4, green: 0.6, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: SU.beam.opacity(0.4), radius: 20, y: 8)
                }.buttonStyle(Press())

                HStack(spacing: 10) {
                    stat("\(prog.stars.count)/\(Beam.total)", "مرحلة", "flag.checkered", SU.green)
                    stat("\(prog.totalStars)", "نجمة", "star.fill", SU.gold)
                    Button { stage = .daily } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Image(systemName: prog.dailyDone == Saved.today ? "checkmark.seal.fill" : "calendar").font(.system(size: 15, weight: .bold)).foregroundStyle(SU.pink)
                            Text("لغز اليوم").font(rnd(17, .black)).foregroundStyle(Color.white)
                            Text(prog.dailyDone == Saved.today ? "حلّيته ✓" : "جديد كلّ يوم").font(rnd(11.5)).foregroundStyle(SU.tx3)
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).card(SU.s1, 18, stroke: SU.pink.opacity(0.3))
                    }.buttonStyle(Press())
                }
                Text("المراحل").font(rnd(18, .heavy)).foregroundStyle(Color.white)
                LazyVGrid(columns: cols, spacing: 9) {
                    ForEach(0..<Beam.total, id: \.self) { i in
                        let open = prog.unlocked(i), st = prog.stars[i] ?? 0
                        Button { if open { stage = .level(i) } } label: {
                            VStack(spacing: 3) {
                                if open { Text("\(i + 1)").font(rnd(19, .black)).foregroundStyle(Color.white) } else { Image(systemName: "lock.fill").font(.system(size: 14)).foregroundStyle(SU.tx3) }
                                HStack(spacing: 1.5) { ForEach(0..<3, id: \.self) { k in Image(systemName: "star.fill").font(.system(size: 7.5)).foregroundStyle(k < st ? SU.gold : Color(white: 1, opacity: 0.14)) } }
                            }
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .background(i == prog.next ? SU.beam.opacity(0.22) : (st > 0 ? SU.s2 : SU.s1), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(i == prog.next ? SU.beam : Color(white: 1, opacity: 0.06), lineWidth: i == prog.next ? 2 : 1))
                        }.buttonStyle(Press()).opacity(open ? 1 : 0.55)
                    }
                }.environment(\.layoutDirection, .leftToRight)
            }.padding(18)
        }
        .background(Backdrop())
        .fullScreenCover(item: $stage) { s in GameView(stage: s) { n in stage = n }.environmentObject(prog).environment(\.layoutDirection, .rightToLeft) }
        .sheet(isPresented: $how, onDismiss: { seenHow = true }) { HowView { how = false }.environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .onAppear {
            if Shot.isAny("game", "win", "hint", "big") { stage = .level(Shot.name == "big" ? 40 : 17) }
            else if Shot.name == "how" || (!seenHow && !Shot.on) { how = true }
        }
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(20, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(11.5)).foregroundStyle(SU.tx3)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).card(SU.s1, 18, stroke: c.opacity(0.25))
    }
}

struct HowView: View {
    let done: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("شلون ألعب؟").font(rnd(30, .black)).foregroundStyle(Color.white)
            VStack(alignment: .leading, spacing: 14) {
                rule("bolt.fill", SU.beam, "الليزر يمشي مستقيم", "يطلع من المصدر ويكمّل لحدّ ما يضرب جدار أو يطلع من اللوحة.")
                rule("line.diagonal", Color.white, "المرايا تعكسه", "اضغط على المراية حتى تقلبها وتغيّر اتّجاه الشعاع. المرايا الرماديّة ثابتة.")
                rule("target", SU.pink, "ضوّي كلّ الأهداف", "تفوز لمّا الشعاع يمرّ على كلّ الدوائر.")
            }
            Spacer()
            Button(action: done) { Text("يلّا").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.8)).frame(maxWidth: .infinity).frame(height: 56).background(SU.beam, in: Capsule()) }.buttonStyle(Press())
            Text("ثلاث نجوم = حلّيتها بأقلّ عدد ضغطات.").font(rnd(12)).foregroundStyle(SU.tx3)
        }.padding(24).background(SU.bg.ignoresSafeArea())
    }
    private func rule(_ icon: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 22, weight: .black)).foregroundStyle(c).frame(width: 56, height: 56).background(SU.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) { Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white); Text(s).font(rnd(13.5)).foregroundStyle(SU.tx2).lineSpacing(3) }
        }
    }
}
