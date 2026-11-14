import SwiftUI

// ألوان «بكسل» (ثيم غامق، برتقاليّ)
enum NN {
    static let bg = Color(red: 0.04, green: 0.05, blue: 0.09)
    static let s1 = Color(red: 0.09, green: 0.11, blue: 0.18)
    static let s2 = Color(red: 0.14, green: 0.17, blue: 0.27)
    static let s3 = Color(red: 0.22, green: 0.26, blue: 0.38)
    static let ink = Color(red: 0.96, green: 0.97, blue: 1)        // خانة مملوءة قبل الكشف
    static let accent = Color(red: 1, green: 0.55, blue: 0.26)     // برتقاليّ
    static let accent2 = Color(red: 1, green: 0.38, blue: 0.4)
    static let good = Color(red: 0.4, green: 0.95, blue: 0.6)
    static let bad = Color(red: 1, green: 0.42, blue: 0.42)
    static let gold = Color(red: 1, green: 0.82, blue: 0.3)
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.45)
    static func of(_ k: Ink) -> Color { Color(red: k.r, green: k.g, blue: k.b) }
}

func mmss(_ s: Int) -> String {
    String(format: "%d:%02d", s / 60, s % 60)
}

@MainActor
final class Store: ObservableObject {
    @Published var solved: Set<String> = []
    @Published var best: [String: Int] = [:]
    private let ud = UserDefaults.standard

    init() {
        if Shot.on {
            solved = ["heart5", "diamond5", "plus5", "tree5", "arrow5", "heart10", "smiley10"]
            best = ["heart5": 38, "diamond5": 52, "plus5": 29, "heart10": 141, "smiley10": 207]
            return
        }
        if let a = ud.array(forKey: "bx_solved") as? [String] { solved = Set(a) }
        if let d = ud.dictionary(forKey: "bx_best") as? [String: Int] { best = d }
    }

    func isSolved(_ id: String) -> Bool { solved.contains(id) }

    func win(_ id: String, time: Int) {
        solved.insert(id)
        if let b = best[id] { best[id] = min(b, time) } else { best[id] = time }
        guard !Shot.on else { return }
        ud.set(Array(solved), forKey: "bx_solved")
        ud.set(best, forKey: "bx_best")
    }

    // فتح تدريجيّ داخل كلّ باقة: الأوّل مفتوح، والباقي يفتح بعد حلّ اللي قبله
    func unlocked(_ p: Puzzle) -> Bool {
        let pack = Nono.puzzles(p.size)
        guard let i = pack.firstIndex(of: p) else { return false }
        if i == 0 { return true }
        return isSolved(pack[i - 1].id)
    }

    func nextAfter(_ p: Puzzle) -> Puzzle? {
        let lib = Nono.library()
        guard let i = lib.firstIndex(of: p) else { return nil }
        if i + 1 < lib.count {
            for q in lib[(i + 1)...] where unlocked(q) && !isSolved(q.id) { return q }
        }
        return lib.first { unlocked($0) && !isSolved($0.id) }
    }

    var continuePuzzle: Puzzle? {
        Nono.library().first { unlocked($0) && !isSolved($0.id) } ?? Nono.library().first
    }
}

@main
struct BixelApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(NN.accent)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            NN.bg
            RadialGradient(colors: [NN.accent.opacity(0.2), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [NN.accent2.opacity(0.14), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct HomeView: View {
    @EnvironmentObject var store: Store
    @AppStorage("bx_seen_how") private var seenHow = false
    @AppStorage("bx_penalty") private var penalty = true
    @State private var active: Puzzle?
    @State private var how = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                continueCard
                modePicker
                ForEach(Size.allCases, id: \.self) { size in
                    pack(size)
                }
                Color.clear.frame(height: 8)
            }
            .padding(18)
        }
        .background(Backdrop())
        .fullScreenCover(item: $active) { p in
            GameView(puzzle: p, penalty: penalty, onNext: { active = store.nextAfter(p) }, onClose: { active = nil })
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(NN.accent)
        }
        .sheet(isPresented: $how, onDismiss: { seenHow = true }) {
            HowView { how = false }
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .onAppear(perform: seed)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("بكسل").font(rnd(42, .black)).foregroundStyle(Color.white)
                Text("امْلا الخانات حسب الأرقام واكشف الصورة").font(rnd(13)).foregroundStyle(NN.tx3)
            }
            Spacer()
            Button { how = true } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 16, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 44, height: 44).background(NN.s2, in: Circle())
            }
            .buttonStyle(Press())
        }
    }

    private var continueCard: some View {
        Group {
            if let p = store.continuePuzzle {
                Button { active = p } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.solved.isEmpty ? "ابدا اللعب" : "كمّل").font(rnd(15, .heavy)).opacity(0.8)
                            Text(p.name).font(rnd(30, .black))
                            Text(p.size.title).font(rnd(13, .bold)).opacity(0.72)
                        }
                        Spacer()
                        MiniPreview(puzzle: p, lit: false)
                            .frame(width: 66, height: 66)
                    }
                    .foregroundStyle(Color.black.opacity(0.85)).padding(18)
                    .background(LinearGradient(colors: [NN.accent, NN.gold], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: NN.accent.opacity(0.4), radius: 20, y: 8)
                }
                .buttonStyle(Press())
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 10) {
            modeButton(on: penalty, title: "وضع الأخطاء", sub: "ملء غلط = خطأ", icon: "heart.fill", c: NN.accent2) { penalty = true }
            modeButton(on: !penalty, title: "وضع حرّ", sub: "بلا عقوبة", icon: "infinity", c: NN.good) { penalty = false }
        }
    }

    private func modeButton(on: Bool, title: String, sub: String, icon: String, c: Color, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(on ? c : NN.tx3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(rnd(14.5, .heavy)).foregroundStyle(Color.white)
                    Text(sub).font(rnd(11)).foregroundStyle(NN.tx3)
                }
                Spacer(minLength: 0)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .card(on ? NN.s2 : NN.s1, 16, stroke: on ? c.opacity(0.55) : Color(white: 1, opacity: 0.06))
        }
        .buttonStyle(Press())
    }

    private func pack(_ size: Size) -> some View {
        let items = Nono.puzzles(size)
        let doneCount = items.filter { store.isSolved($0.id) }.count
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(size.title).font(rnd(18, .heavy)).foregroundStyle(Color.white)
                Spacer()
                Text("\(doneCount)/\(items.count)").font(rnd(13, .bold)).foregroundStyle(NN.tx3).environment(\.layoutDirection, .leftToRight)
            }
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(items) { p in
                    tile(p)
                }
            }
        }
    }

    private func tile(_ p: Puzzle) -> some View {
        let open = store.unlocked(p)
        let done = store.isSolved(p.id)
        return Button { if open { active = p } } label: {
            VStack(spacing: 8) {
                ZStack {
                    if open {
                        MiniPreview(puzzle: p, lit: done)
                    } else {
                        Image(systemName: "lock.fill").font(.system(size: 20)).foregroundStyle(NN.tx3)
                    }
                }
                .frame(width: 60, height: 60)
                Text(open ? p.name : "مقفل").font(rnd(12.5, .bold)).foregroundStyle(open ? Color.white : NN.tx3).lineLimit(1)
                if done, let b = store.best[p.id] {
                    Text(mmss(b)).font(rnd(10.5, .bold)).foregroundStyle(NN.gold).environment(\.layoutDirection, .leftToRight)
                } else {
                    Text(open ? "جاهز" : " ").font(rnd(10.5)).foregroundStyle(NN.tx3)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .card(done ? NN.s2 : NN.s1, 18, stroke: done ? NN.gold.opacity(0.4) : Color(white: 1, opacity: 0.06))
        }
        .buttonStyle(Press())
        .opacity(open ? 1 : 0.55)
    }

    private func seed() {
        if Shot.name == "how" {
            how = true
        } else if Shot.name == "game" {
            active = Nono.library().first { $0.id == "house10" }
        } else if Shot.name == "win" {
            active = Nono.library().first { $0.id == "heart10" }
        } else if !seenHow && !Shot.on {
            how = true
        }
    }
}

// معاينة مصغّرة للصورة من البتماب
struct MiniPreview: View {
    let puzzle: Puzzle
    let lit: Bool
    var body: some View {
        GeometryReader { geo in
            let n = puzzle.size.n
            let cell = min(geo.size.width, geo.size.height) / CGFloat(n)
            let color = lit ? NN.of(puzzle.ink) : NN.ink.opacity(0.9)
            ZStack(alignment: .topLeading) {
                ForEach(0..<n, id: \.self) { r in
                    ForEach(0..<n, id: \.self) { c in
                        if puzzle.bitmap[r][c] {
                            Rectangle()
                                .fill(color)
                                .frame(width: cell, height: cell)
                                .offset(x: CGFloat(c) * cell, y: CGFloat(r) * cell)
                        }
                    }
                }
            }
            .frame(width: cell * CGFloat(n), height: cell * CGFloat(n))
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct HowView: View {
    let done: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("شلون ألعب؟").font(rnd(30, .black)).foregroundStyle(Color.white)
            VStack(alignment: .leading, spacing: 14) {
                rule("number", NN.accent, "الأرقام تدلّك", "كلّ رقم = طول سلسلة خانات مملوءة بالصفّ أو العمود، بالترتيب.")
                rule("hand.tap.fill", NN.good, "املا أو علّم", "اضغط لتملا الخانة. بدّل الوضع حتى تعلّم X على الخانة الفارغة.")
                rule("photo.fill", NN.gold, "اكشف الصورة", "لمّا تطابق كلّ الأرقام تنكشف الصورة وتفوز.")
            }
            Spacer()
            Button(action: done) {
                Text("يلّا").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity).frame(height: 56).background(NN.accent, in: Capsule())
            }
            .buttonStyle(Press())
            Text("بوضع الأخطاء عندك ٥ أخطاء بس — دير بالك!").font(rnd(12)).foregroundStyle(NN.tx3)
        }
        .padding(24)
        .background(NN.bg.ignoresSafeArea())
    }

    private func rule(_ icon: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 22, weight: .black)).foregroundStyle(c)
                .frame(width: 56, height: 56).background(NN.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white)
                Text(s).font(rnd(13.5)).foregroundStyle(NN.tx2).lineSpacing(3)
            }
        }
    }
}
