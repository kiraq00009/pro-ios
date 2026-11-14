import SwiftUI

// ── ألوان «وصّل»: خلفيّة غامقة + أنابيب برّاقة متمايزة
enum WS {
    static let bg = Color(red: 0.045, green: 0.05, blue: 0.09)
    static let s1 = Color(red: 0.09, green: 0.10, blue: 0.16)
    static let s2 = Color(red: 0.135, green: 0.15, blue: 0.23)
    static let cell = Color(red: 0.11, green: 0.125, blue: 0.19)
    static let grid = Color(white: 1, opacity: 0.06)
    static let tint = Color(red: 1, green: 0.55, blue: 0.2)
    static let gold = Color(red: 1, green: 0.82, blue: 0.32)
    static let green = Color(red: 0.36, green: 0.9, blue: 0.56)
    static let tx = Color.white
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.44)

    // ألوان الأنابيب — زاهية ومتمايزة
    static let pipes: [Color] = [
        Color(red: 0.98, green: 0.27, blue: 0.33),   // أحمر
        Color(red: 0.26, green: 0.6, blue: 1.0),     // أزرق
        Color(red: 0.36, green: 0.9, blue: 0.5),     // أخضر
        Color(red: 1.0, green: 0.82, blue: 0.26),    // أصفر
        Color(red: 1.0, green: 0.55, blue: 0.16),    // برتقاليّ
        Color(red: 0.72, green: 0.45, blue: 1.0),    // بنفسجيّ
        Color(red: 0.2, green: 0.85, blue: 0.86),    // سماويّ
        Color(red: 1.0, green: 0.45, blue: 0.78),    // ورديّ
        Color(red: 0.6, green: 0.78, blue: 0.3),      // زيتيّ
        Color(red: 0.85, green: 0.6, blue: 0.4)       // بنّيّ فاتح
    ]
    static func pipe(_ i: Int) -> Color { pipes[i % pipes.count] }
}

// رقم بخانة LTR حتى تنعرض الأرقام صحّ بواجهة عربيّة
struct Num: View {
    let s: String
    init(_ v: Int) { s = "\(v)" }
    init(_ str: String) { s = str }
    var body: some View { Text(s).environment(\.layoutDirection, .leftToRight) }
}

// ── حالة التقدّم: المراحل المحلولة + النجوم، تُحفظ محليًّا
@MainActor
final class Store: ObservableObject {
    @Published var stars: [Int: Int] = [:]      // رقم المرحلة → نجوم (1..3)
    @Published var dailyStars: Int = 0
    @Published var dailyKey: String = ""
    private let ud = UserDefaults.standard

    init() {
        if Shot.on {
            for i in 0..<30 {
                let pat = [3, 2, 3, 3, 1, 2, 3, 2]
                stars[i] = pat[i % pat.count]
            }
            dailyStars = 3
            dailyKey = Store.todayKey
            return
        }
        if let d = ud.dictionary(forKey: "ws_stars") as? [String: Int] {
            for (k, v) in d { if let i = Int(k) { stars[i] = v } }
        }
        dailyStars = ud.integer(forKey: "ws_daily_stars")
        dailyKey = ud.string(forKey: "ws_daily_key") ?? ""
    }

    static var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    var totalStars: Int { stars.values.reduce(0, +) + (dailyKey == Store.todayKey ? dailyStars : 0) }
    var solvedCount: Int { stars.count }
    var dailyDoneToday: Bool { dailyKey == Store.todayKey }

    func isUnlocked(_ i: Int) -> Bool { i == 0 || stars[i - 1] != nil }

    // أعلى مرحلة مفتوحة غير محلولة (للزرّ «كمّل»)
    var continueIndex: Int {
        for i in 0..<Levels.count where stars[i] == nil && isUnlocked(i) { return i }
        return min(solvedCount, Levels.count - 1)
    }

    func record(level i: Int, stars s: Int) {
        if s > (stars[i] ?? 0) { stars[i] = s }
        persist()
    }

    func recordDaily(_ s: Int) {
        dailyKey = Store.todayKey
        dailyStars = max(dailyStars, s)
        guard !Shot.on else { return }
        ud.set(dailyStars, forKey: "ws_daily_stars")
        ud.set(dailyKey, forKey: "ws_daily_key")
    }

    private func persist() {
        guard !Shot.on else { return }
        var d: [String: Int] = [:]
        for (k, v) in stars { d["\(k)"] = v }
        ud.set(d, forKey: "ws_stars")
    }
}

@main
struct WasselApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(WS.tint)
        }
    }
}

// ── خلفيّة متدرّجة
struct Backdrop: View {
    var body: some View {
        ZStack {
            WS.bg
            RadialGradient(colors: [WS.tint.opacity(0.17), Color.clear], center: .top, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [Color(red: 0.3, green: 0.4, blue: 1).opacity(0.14), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 440)
        }
        .ignoresSafeArea()
    }
}

struct HomeView: View {
    @EnvironmentObject var store: Store
    @AppStorage("ws_seen_how") private var seenHow = false
    @State private var playIndex: Int? = nil
    @State private var playDaily = false
    @State private var how = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                art
                continueButton
                dailyAndStats
                Text("المراحل").font(rnd(20, .heavy)).foregroundStyle(WS.tx).padding(.top, 4)
                LevelGrid { playIndex = $0 }
                Text("تشتغل كاملة بلا إنترنت · كلّ مرحلة حلّ مضمون").font(rnd(11.5)).foregroundStyle(WS.tx3).frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(18)
        }
        .background(Backdrop())
        .fullScreenCover(item: Binding(get: { playIndex.map { Idx(id: $0) } }, set: { playIndex = $0?.id })) { item in
            GameView(mode: .level(item.id)) { playIndex = nil }
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $playDaily) {
            GameView(mode: .daily) { playDaily = false }
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $how, onDismiss: { seenHow = true }) {
            HowView { how = false }
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .onAppear(perform: shotSetup)
    }

    private func shotSetup() {
        if Shot.isAny("game", "win") { playIndex = 26 }
        else if Shot.name == "how" { how = true }
        else if !seenHow && !Shot.on { how = true }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("وصّل").font(rnd(44, .black)).foregroundStyle(WS.tx)
                Text("وصّل كلّ نقطتين بلون واحد · واملأ الشبكة").font(rnd(13)).foregroundStyle(WS.tx3)
            }
            Spacer()
            Button { how = true } label: {
                Image(systemName: "questionmark").font(.system(size: 16, weight: .black)).foregroundStyle(WS.tx)
                    .frame(width: 44, height: 44).background(WS.s2, in: Circle())
            }
            .buttonStyle(Press())
        }
    }

    private var art: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(LinearGradient(colors: [WS.s2, WS.s1], startPoint: .top, endPoint: .bottom))
            MiniPreview(level: Levels.level(6))
                .padding(16)
        }
        .frame(height: 160)
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(WS.tint.opacity(0.22)))
    }

    private var continueButton: some View {
        Button { playIndex = store.continueIndex } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill").font(.system(size: 17, weight: .black))
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.solvedCount == 0 ? "ابدأ اللعب" : "كمّل").font(rnd(18, .black))
                    HStack(spacing: 3) {
                        Text("المرحلة").font(rnd(12, .semibold))
                        Num(store.continueIndex + 1).font(rnd(12, .black))
                    }
                    .opacity(0.8)
                }
                Spacer()
            }
            .foregroundStyle(Color.black.opacity(0.85)).padding(.horizontal, 20).frame(maxWidth: .infinity).frame(height: 62)
            .background(LinearGradient(colors: [WS.gold, WS.tint], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            .shadow(color: WS.tint.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(Press())
    }

    private var dailyAndStats: some View {
        HStack(spacing: 10) {
            Button { playDaily = true } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").font(.system(size: 16, weight: .bold)).foregroundStyle(Color(red: 0.72, green: 0.45, blue: 1))
                        if store.dailyDoneToday { Image(systemName: "checkmark.seal.fill").font(.system(size: 13)).foregroundStyle(WS.green) }
                    }
                    Text("لغز اليوم").font(rnd(16, .heavy)).foregroundStyle(WS.tx)
                    Text(store.dailyDoneToday ? "خلّصته اليوم" : "لغز واحد لكلّ الناس").font(rnd(11.5)).foregroundStyle(WS.tx3).lineLimit(1).minimumScaleFactor(0.8)
                }
                .padding(13).frame(maxWidth: .infinity, alignment: .leading).card(WS.s1, 20, stroke: Color(red: 0.72, green: 0.45, blue: 1).opacity(0.3))
            }
            .buttonStyle(Press())
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "star.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(WS.gold)
                HStack(spacing: 4) {
                    Num(store.totalStars).font(rnd(22, .black)).foregroundStyle(WS.tx)
                    Text("نجوم").font(rnd(13, .heavy)).foregroundStyle(WS.tx2)
                }
                Text("حلّيت \(numStr(store.solvedCount)) من \(numStr(Levels.count))").font(rnd(11.5)).foregroundStyle(WS.tx3).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(13).frame(maxWidth: .infinity, alignment: .leading).card(WS.s1, 20, stroke: WS.gold.opacity(0.25))
        }
    }

    private func numStr(_ v: Int) -> String { "\(v)" }
}

struct Idx: Identifiable { let id: Int }

// ── شبكة المراحل المفتوحة
struct LevelGrid: View {
    @EnvironmentObject var store: Store
    let open: (Int) -> Void
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: cols, spacing: 10) {
            ForEach(0..<Levels.count, id: \.self) { i in
                tile(i)
            }
        }
    }

    private func tile(_ i: Int) -> some View {
        let unlocked = store.isUnlocked(i)
        let s = store.stars[i] ?? 0
        let spec = Levels.book[i]
        return Button { if unlocked { open(i) } } label: {
            VStack(spacing: 5) {
                if unlocked {
                    Num(i + 1).font(rnd(20, .black)).foregroundStyle(WS.tx)
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { k in
                            Image(systemName: k < s ? "star.fill" : "star").font(.system(size: 8)).foregroundStyle(k < s ? WS.gold : WS.tx3)
                        }
                    }
                    Text("\(numStr(spec.size))×\(numStr(spec.size))").font(rnd(9.5, .semibold)).foregroundStyle(WS.tx3)
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 17)).foregroundStyle(WS.tx3)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 68)
            .card(s > 0 ? WS.s2 : WS.s1, 16, stroke: s > 0 ? WS.tint.opacity(0.35) : WS.grid)
        }
        .buttonStyle(Press())
        .disabled(!unlocked)
    }

    private func numStr(_ v: Int) -> String { "\(v)" }
}

// ── معاينة صغيرة ملوّنة للوحة محلولة (للبطل)
struct MiniPreview: View {
    let level: FlowLevel
    var body: some View {
        GeometryReader { geo in
            let n = level.size
            let side = min(geo.size.width, geo.size.height)
            let cs = side / CGFloat(n)
            Canvas { ctx, _ in
                for color in 0..<level.pairs {
                    let cells = level.solution[color]
                    guard cells.count >= 2 else { continue }
                    var p = Path()
                    for (k, cell) in cells.enumerated() {
                        let pt = CGPoint(x: (CGFloat(cell.c) + 0.5) * cs, y: (CGFloat(cell.r) + 0.5) * cs)
                        if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                    ctx.stroke(p, with: .color(WS.pipe(color)), style: StrokeStyle(lineWidth: cs * 0.34, lineCap: .round, lineJoin: .round))
                    for end in [cells.first!, cells.last!] {
                        let pt = CGPoint(x: (CGFloat(end.c) + 0.5) * cs, y: (CGFloat(end.r) + 0.5) * cs)
                        let d = cs * 0.52
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d)), with: .color(WS.pipe(color)))
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

// ── شلون ألعب؟
struct HowView: View {
    let done: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("شلون ألعب؟").font(rnd(28, .black)).foregroundStyle(WS.tx).padding(.top, 22)
                rule("hand.draw.fill", WS.tint, "اسحب بإصبعك", "امسك نقطة ملوّنة واسحب لين النقطة الثانية بنفس اللون. تنرسم خطّ يوصل بينهم.")
                rule("arrow.triangle.branch", WS.pipe(1), "لا تتقاطع", "الخطوط ما تگدر تتقاطع. لو سحبت فوق خطّ موجود، تقطعه وتبدّل مكانه.")
                rule("square.grid.3x3.fill", WS.green, "املأ الكلّ", "ما تفوز إلّا لمّا توصل كلّ الألوان وتملأ كلّ خانة بالشبكة — ١٠٠٪ تعبئة.")
                rule("star.fill", WS.gold, "٣ نجوم", "خلّص المرحلة بلا ما تمسح وبلا تلميح حتى تاخذ ثلاث نجوم.")
                rule("lightbulb.fill", WS.pipe(5), "تلميح", "گلت عليك؟ اضغط «تلميح» وراح يوصّلك لون واحد. بس ينقّص نجمة.")
                Button(action: done) {
                    Text("خلّينا نبدأ").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.85)).frame(maxWidth: .infinity).frame(height: 56).background(WS.tint, in: Capsule())
                }
                .buttonStyle(Press()).padding(.top, 6)
            }
            .padding(22)
        }
        .background(WS.bg.ignoresSafeArea())
    }

    private func rule(_ icon: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 20, weight: .black)).foregroundStyle(c).frame(width: 52, height: 52).background(WS.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(rnd(17, .heavy)).foregroundStyle(WS.tx)
                Text(s).font(rnd(13.5)).foregroundStyle(WS.tx2).lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
    }
}
