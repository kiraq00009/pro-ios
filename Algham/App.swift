import SwiftUI

// لوحة ألوان «ألغام» — ثيم غامق + ألوان الأرقام الكلاسيكيّة لكنس الألغام.
enum AL {
    static let bg = Color(red: 0.055, green: 0.065, blue: 0.10)
    static let s1 = Color(red: 0.10, green: 0.115, blue: 0.17)
    static let s2 = Color(red: 0.145, green: 0.165, blue: 0.235)
    static let tileTop = Color(red: 0.26, green: 0.30, blue: 0.42)
    static let tileBot = Color(red: 0.185, green: 0.215, blue: 0.31)
    static let open = Color(red: 0.11, green: 0.125, blue: 0.185)
    static let openEdge = Color(white: 1, opacity: 0.05)
    static let accent = Color(red: 1, green: 0.62, blue: 0.22)   // برتقاليّ
    static let accent2 = Color(red: 1, green: 0.78, blue: 0.30)
    static let red = Color(red: 0.98, green: 0.33, blue: 0.36)
    static let green = Color(red: 0.36, green: 0.86, blue: 0.52)
    static let gold = Color(red: 1, green: 0.82, blue: 0.34)
    static let violet = Color(red: 0.64, green: 0.52, blue: 1)
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.44)

    /// لون الرقم الكلاسيكيّ (معدّل ليبين على الغامق).
    static func num(_ n: Int) -> Color {
        switch n {
        case 1: return Color(red: 0.36, green: 0.66, blue: 1)      // أزرق
        case 2: return Color(red: 0.40, green: 0.85, blue: 0.52)   // أخضر
        case 3: return Color(red: 1, green: 0.42, blue: 0.45)      // أحمر
        case 4: return Color(red: 0.68, green: 0.56, blue: 1)      // بنفسجيّ
        case 5: return Color(red: 1, green: 0.62, blue: 0.30)      // برتقاليّ
        case 6: return Color(red: 0.30, green: 0.82, blue: 0.80)   // سماويّ
        case 7: return Color(red: 1, green: 0.55, blue: 0.80)      // ورديّ
        default: return Color(white: 0.82)                          // 8 رماديّ
        }
    }
}

func clock(_ s: Int) -> String {
    let c = min(s, 5999)
    return String(format: "%d:%02d", c / 60, c % 60)
}

@MainActor
final class Game: ObservableObject {
    @Published var b: Board
    @Published var diff: Diff
    @Published var flagMode = false
    @Published var elapsed = 0
    @Published var running = false
    @Published var win = false
    @Published var lose = false
    @Published var shake = 0
    @Published var best: [String: Int] = [:]
    @Published var newBest = false

    private let ud = UserDefaults.standard

    init() {
        if Shot.on {
            best = ["e": 41, "m": 118, "h": 294]
            if Shot.isAny("game", "win", "lose") {
                let d = Diffs.medium
                diff = d
                let st = Game.staged(Shot.name, d)
                b = st.board
                elapsed = st.time
                win = st.win
                lose = st.lose
            } else {
                diff = Diffs.easy
                b = Board.empty(rows: Diffs.easy.rows, cols: Diffs.easy.cols, mines: Diffs.easy.mines, seed: 7)
            }
            return
        }
        if let d = ud.data(forKey: "al_best"), let v = try? JSONDecoder().decode([String: Int].self, from: d) {
            best = v
        }
        if let data = ud.data(forKey: "al_board"),
           let saved = try? JSONDecoder().decode(Board.self, from: data),
           !saved.dead, saved.started, !isWin(saved) {
            b = saved
            diff = Diffs.byKey(ud.string(forKey: "al_diffkey") ?? "e")
            elapsed = ud.integer(forKey: "al_time")
            running = true
        } else {
            diff = Diffs.easy
            b = Board.empty(rows: Diffs.easy.rows, cols: Diffs.easy.cols, mines: Diffs.easy.mines, seed: UInt64.random(in: 1...9_999_999))
        }
    }

    var hasSaved: Bool { b.started && !b.dead && !win && !lose }
    var mineCounter: Int { counts(b).remaining }
    var face: String {
        if lose { return "😵" }
        if win { return "😎" }
        return "🙂"
    }

    func newGame(_ d: Diff) {
        diff = d
        b = Board.empty(rows: d.rows, cols: d.cols, mines: d.mines, seed: UInt64.random(in: 1...9_999_999))
        elapsed = 0
        running = false
        win = false
        lose = false
        newBest = false
        flagMode = false
        shake = 0
        persist()
    }

    func restart() {
        newGame(diff)
        Haptic.tap()
    }

    func tapCell(_ i: Int) {
        guard i >= 0, i < b.size, !b.dead, !win else { return }
        if flagMode {
            if !b.revealed[i] {
                toggleFlag(&b, at: i)
                Haptic.tap()
                persist()
            }
            return
        }
        if b.flagged[i] { return }
        if b.revealed[i] {
            chord(i)
            return
        }
        if !b.started {
            b = layout(rows: diff.rows, cols: diff.cols, mines: diff.mines, safe: i, seed: b.seed)
            running = true
        }
        withAnimation(.easeOut(duration: 0.17)) {
            reveal(&b, at: i)
        }
        settle(wasReveal: true)
    }

    func flag(_ i: Int) {
        guard i >= 0, i < b.size, !b.dead, !win, !b.revealed[i] else { return }
        toggleFlag(&b, at: i)
        Haptic.tap()
        persist()
    }

    /// نقرة على رقم مكشوف وعدد أعلامه المجاورة = الرقم → يكشف بقيّة الجيران (chord).
    private func chord(_ i: Int) {
        guard b.revealed[i], b.adj[i] > 0 else { return }
        let ns = neighbors(i, b.rows, b.cols)
        let f = ns.filter { b.flagged[$0] }.count
        guard f == b.adj[i] else { return }
        withAnimation(.easeOut(duration: 0.17)) {
            for n in ns where !b.flagged[n] && !b.revealed[n] {
                reveal(&b, at: n)
            }
        }
        settle(wasReveal: true)
    }

    private func settle(wasReveal: Bool) {
        if b.dead {
            running = false
            withAnimation(.easeOut(duration: 0.3)) {
                for i in 0..<b.size where b.mine[i] { b.revealed[i] = true }
            }
            withAnimation(.default) { shake += 1 }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { lose = true }
            Haptic.bad()
            clearSaved()
            return
        }
        if isWin(b) {
            running = false
            win = true
            for i in 0..<b.size where b.mine[i] { b.flagged[i] = true }
            recordBest()
            Haptic.ok()
            clearSaved()
            return
        }
        if wasReveal { Haptic.tap() }
        persist()
    }

    private func recordBest() {
        if best[diff.key] == nil || elapsed < best[diff.key]! {
            best[diff.key] = elapsed
            newBest = true
            saveBest()
        }
    }

    func tick() {
        guard running, !win, !lose, b.started, !Shot.on else { return }
        if elapsed < 5999 { elapsed += 1 }
    }

    private func persist() {
        guard !Shot.on else { return }
        if let d = try? JSONEncoder().encode(b) { ud.set(d, forKey: "al_board") }
        ud.set(diff.key, forKey: "al_diffkey")
        ud.set(elapsed, forKey: "al_time")
    }
    private func clearSaved() {
        guard !Shot.on else { return }
        ud.removeObject(forKey: "al_board")
    }
    private func saveBest() {
        guard !Shot.on else { return }
        if let d = try? JSONEncoder().encode(best) { ud.set(d, forKey: "al_best") }
    }

    // لقطات الشاشة — لوح بحالة مقنعة.
    private static func staged(_ name: String, _ d: Diff) -> (board: Board, time: Int, win: Bool, lose: Bool) {
        let safe = (d.rows / 2) * d.cols + (d.cols / 2)
        var b = layout(rows: d.rows, cols: d.cols, mines: d.mines, safe: safe, seed: 424242)
        reveal(&b, at: safe)
        // وسّع الكشف بخانات آمنة متفرّقة
        for extra in [d.cols + 1, d.count - d.cols - 2, d.cols * 3 + 2] where extra >= 0 && extra < d.count {
            if !b.mine[extra] { reveal(&b, at: extra) }
        }
        switch name {
        case "win":
            for i in 0..<b.size where !b.mine[i] { reveal(&b, at: i) }
            for i in 0..<b.size where b.mine[i] { b.flagged[i] = true }
            return (b, 118, true, false)
        case "lose":
            var f = 0
            for i in 0..<b.size where b.mine[i] && f < 3 { b.flagged[i] = true; f += 1 }
            if let bomb = (0..<b.size).first(where: { b.mine[$0] && !b.flagged[$0] }) {
                reveal(&b, at: bomb)
            }
            for i in 0..<b.size where b.mine[i] { b.revealed[i] = true }
            return (b, 73, false, true)
        default: // game
            var f = 0
            for i in 0..<b.size where b.mine[i] {
                if f >= 4 { break }
                if neighbors(i, b.rows, b.cols).contains(where: { b.revealed[$0] }) {
                    b.flagged[i] = true
                    f += 1
                }
            }
            return (b, 23, false, false)
        }
    }
}

@main
struct AlghamApp: App {
    @StateObject private var game = Game()
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(game)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(AL.accent)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            AL.bg
            RadialGradient(colors: [AL.accent.opacity(0.18), Color.clear], center: .top, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [AL.violet.opacity(0.14), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct HomeView: View {
    @EnvironmentObject var game: Game
    @AppStorage("al_seen_how") private var seenHow = false
    @State private var playing = false
    @State private var how = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                art
                if game.hasSaved { resume }
                newButtons
                stats
                Text("تشتغل كاملة بلا إنترنت · أوّل نقرة آمنة دائمًا").font(rnd(11.5)).foregroundStyle(AL.tx3).frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .background(Backdrop())
        .fullScreenCover(isPresented: $playing) {
            GameView { playing = false }
                .environmentObject(game)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(AL.accent)
        }
        .sheet(isPresented: $how, onDismiss: { seenHow = true }) {
            HowView { how = false }
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            if Shot.isAny("game", "win", "lose") { playing = true }
            else if Shot.name == "how" { how = true }
            else if !seenHow && !Shot.on { how = true }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("كنس الألغام").font(rnd(40, .black)).foregroundStyle(Color.white)
                Text("دوّر على الألغام بلا ما تضغطها").font(rnd(13)).foregroundStyle(AL.tx3)
            }
            Spacer()
            Button { how = true } label: {
                Image(systemName: "questionmark").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white).frame(width: 42, height: 42).background(AL.s2, in: Circle())
            }
            .buttonStyle(Press())
        }
    }

    private var art: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(LinearGradient(colors: [AL.s2, AL.s1], startPoint: .top, endPoint: .bottom))
            RadialGradient(colors: [AL.accent.opacity(0.4), Color.clear], center: .center, startRadius: 0, endRadius: 150)
            HStack(spacing: 12) {
                miniTile("1", AL.num(1))
                miniTile("💣", nil)
                miniTile("2", AL.num(2))
                miniTile("🚩", nil)
                miniTile("3", AL.num(3))
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .frame(height: 140)
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(AL.accent.opacity(0.25)))
    }

    private func miniTile(_ t: String, _ c: Color?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(c == nil ? AnyShapeStyle(LinearGradient(colors: [AL.tileTop, AL.tileBot], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(AL.open))
            Text(t).font(rnd(c == nil ? 26 : 30, .black)).foregroundStyle(c ?? Color.white)
        }
        .frame(width: 54, height: 54)
    }

    private var resume: some View {
        Button { playing = true } label: {
            HStack(spacing: 14) {
                Text("🚩").font(.system(size: 30)).frame(width: 56, height: 56).background(AL.s2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("كمّل لعبتك").font(rnd(13, .heavy)).foregroundStyle(AL.accent)
                    Text(game.diff.name).font(rnd(20, .black)).foregroundStyle(Color.white)
                    Text("الوقت \(clock(game.elapsed)) · \(game.diff.cols)×\(game.diff.rows)").font(rnd(12)).foregroundStyle(AL.tx3).environment(\.layoutDirection, .leftToRight)
                }
                Spacer()
                Image(systemName: "play.fill").font(.system(size: 18, weight: .black)).foregroundStyle(AL.accent)
            }
            .padding(13)
            .card(AL.s1, 22, stroke: AL.accent.opacity(0.45))
        }
        .buttonStyle(Press())
    }

    private var newButtons: some View {
        VStack(spacing: 10) {
            ForEach(Diffs.all, id: \.key) { d in
                diffChip(d)
            }
        }
    }

    private func diffChip(_ d: Diff) -> some View {
        Button {
            game.newGame(d)
            playing = true
        } label: {
            HStack(spacing: 14) {
                Text(icon(d)).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name).font(rnd(18, .black)).foregroundStyle(Color.white)
                    Text("\(d.cols)×\(d.rows) · \(d.mines) لغم").font(rnd(12.5)).foregroundStyle(AL.tx3).environment(\.layoutDirection, .leftToRight)
                }
                Spacer()
                if let t = game.best[d.key] {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("أفضل وقت").font(rnd(10)).foregroundStyle(AL.tx3)
                        Text(clock(t)).font(rnd(16, .heavy)).foregroundStyle(AL.gold).environment(\.layoutDirection, .leftToRight)
                    }
                }
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .black)).foregroundStyle(AL.tx3)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .card(AL.s1, 20, stroke: tint(d).opacity(0.3))
        }
        .buttonStyle(Press())
    }

    private func icon(_ d: Diff) -> String {
        switch d.key { case "e": return "🟢"; case "m": return "🟠"; default: return "🔴" }
    }
    private func tint(_ d: Diff) -> Color {
        switch d.key { case "e": return AL.green; case "m": return AL.accent; default: return AL.red }
    }

    private var stats: some View {
        HStack(spacing: 9) {
            stat(game.best["e"].map(clock) ?? "—", "سهل", AL.green)
            stat(game.best["m"].map(clock) ?? "—", "متوسّط", AL.accent)
            stat(game.best["h"].map(clock) ?? "—", "صعب", AL.red)
        }
    }
    private func stat(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 5) {
            Text("أفضل وقت").font(rnd(10)).foregroundStyle(AL.tx3)
            Text(v).font(rnd(18, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(11.5, .heavy)).foregroundStyle(c)
        }
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .card(AL.s1, 16, stroke: c.opacity(0.22))
    }
}

struct HowView: View {
    let done: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("شلون ألعب؟").font(rnd(28, .black)).foregroundStyle(Color.white).padding(.top, 22)
                rule("hand.tap.fill", AL.accent, "اكشف", "اضغط أيّ خانة حتى تفتحها. أوّل نقرة آمنة دائمًا — أبدًا ما تكون لغم.")
                rule("number", AL.num(1), "الأرقام", "الرقم يعني عدد الألغام المخبّاة حوالي الخانة (من 1 لـ 8). منها تعرف وين اللغم.")
                rule("flag.fill", AL.red, "علم 🚩", "إذا متأكّد بيها لغم، حطّ علم. بدّل لوضع العلم من الزرّ تحت، أو اضغط ضغطة طويلة على الخانة.")
                rule("bolt.fill", AL.gold, "فتح سريع", "إذا رقم مكشوف وكلّ ألغامه معلّمة، اضغط عليه يفتح بقيّة جيرانه دفعة وحدة.")
                rule("checkmark.seal.fill", AL.green, "فزت!", "لمّا تكشف كلّ الخانات اللي مو ألغام، تفوز — والساعة تنطفئ على وقتك.")
                rule("burst.fill", AL.red, "انفجرت!", "إذا ضغطت لغم، تنفجر وتبيّن كلّ الألغام. جرّب مرّة لك بلوح جديد.")
                Button(action: done) {
                    Text("يلّا نلعب").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.85)).frame(maxWidth: .infinity).frame(height: 56).background(AL.accent, in: Capsule())
                }
                .buttonStyle(Press())
                .padding(.top, 6)
            }
            .padding(22)
        }
        .background(AL.bg.ignoresSafeArea())
    }
    private func rule(_ icon: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 20, weight: .black)).foregroundStyle(c).frame(width: 52, height: 52).background(AL.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white)
                Text(s).font(rnd(13.5)).foregroundStyle(AL.tx2).lineSpacing(3)
            }
        }
    }
}
