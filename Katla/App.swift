import SwiftUI

// ── لوحة ألوان «كتلة» (ثيم غامق + كتل ملوّنة)
enum KT {
    static let bg = Color(red: 0.055, green: 0.06, blue: 0.11)
    static let s1 = Color(red: 0.10, green: 0.11, blue: 0.19)
    static let s2 = Color(red: 0.15, green: 0.16, blue: 0.27)
    static let s3 = Color(red: 0.22, green: 0.23, blue: 0.37)
    static let ac = Color(red: 1.0, green: 0.62, blue: 0.22)    // برتقاليّ
    static let ac2 = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.3)
    static let green = Color(red: 0.32, green: 0.9, blue: 0.62)
    static let grid = Color(white: 1, opacity: 0.05)
    static let hole = Color(white: 1, opacity: 0.035)
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.44)

    // ألوان الكتل حسب الفهرس (1...6)
    static let blocks: [Color] = [
        Color(red: 1.0, green: 0.62, blue: 0.22),   // برتقاليّ
        Color(red: 0.36, green: 0.68, blue: 1.0),   // أزرق
        Color(red: 0.42, green: 0.86, blue: 0.56),  // أخضر
        Color(red: 0.74, green: 0.5, blue: 1.0),    // بنفسجيّ
        Color(red: 1.0, green: 0.45, blue: 0.62),   // وردي
        Color(red: 1.0, green: 0.82, blue: 0.32),   // ذهبيّ
    ]
    static func block(_ i: Int) -> Color { blocks[max(0, min(blocks.count - 1, i - 1))] }
}

/// رقم بالإنكليزيّة ملفوف LTR (حتى ما ينعكس داخل الواجهة العربيّة)
struct Num: View {
    let value: Int
    init(_ v: Int) { value = v }
    var body: some View {
        Text("\(value)").environment(\.layoutDirection, .leftToRight)
    }
}

@main
struct KatlaApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(KT.ac)
        }
    }
}

/// خلفيّة متدرّجة
struct Backdrop: View {
    var body: some View {
        ZStack {
            KT.bg
            RadialGradient(colors: [KT.ac.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [KT.ac2.opacity(0.14), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct HomeView: View {
    @AppStorage("kt_best") private var best = 0
    @State private var playing = false
    @State private var how = false
    @State private var hasSaved = GameModel.hasSavedGame

    private var decoBoard: [[Int]] {
        // لوح زينة صغير للواجهة
        var b = Array(repeating: Array(repeating: 0, count: 6), count: 4)
        let seed: [(Int, Int, Int)] = [(0, 1, 1), (0, 2, 1), (1, 1, 1), (1, 4, 3), (1, 5, 3),
                                       (2, 0, 4), (2, 4, 3), (3, 0, 4), (3, 1, 4), (3, 3, 5), (3, 4, 5)]
        for (r, c, v) in seed { b[r][c] = v }
        return b
    }

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 22) {
                Spacer(minLength: 8)

                VStack(spacing: 14) {
                    DecoGrid(board: decoBoard)
                        .frame(width: 168, height: 112)
                    Text("كتلة")
                        .font(rnd(54, .black))
                        .foregroundStyle(LinearGradient(colors: [.white, KT.ac], startPoint: .top, endPoint: .bottom))
                    Text("حطّ القطع — إملا صفّ أو عمود يروح!")
                        .font(rnd(14))
                        .foregroundStyle(KT.tx3)
                }

                Spacer(minLength: 0)

                VStack(spacing: 13) {
                    if hasSaved {
                        Button { playing = true } label: { bigButton("كمّل اللعبة", "arrow.right.circle.fill", filled: true) }
                            .buttonStyle(Press())
                    }
                    Button {
                        GameModel.clearSaved()
                        hasSaved = false
                        playing = true
                    } label: { bigButton(hasSaved ? "لعبة جديدة" : "ابدي اللعب", "play.fill", filled: !hasSaved) }
                        .buttonStyle(Press())
                }

                HStack(spacing: 12) {
                    statCard("الأفضل", best, "trophy.fill", KT.gold)
                    Button { how = true } label: {
                        VStack(spacing: 7) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(KT.ac)
                            Text("شلون ألعب")
                                .font(rnd(14, .heavy))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .card(KT.s1, 20, stroke: KT.ac.opacity(0.22))
                    }
                    .buttonStyle(Press())
                }

                Spacer(minLength: 10)
            }
            .padding(22)
        }
        .fullScreenCover(isPresented: $playing, onDismiss: { hasSaved = GameModel.hasSavedGame }) {
            GameView()
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(KT.ac)
        }
        .sheet(isPresented: $how) {
            HowView { how = false }
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            if Shot.isAny("game", "over") { playing = true }
            else if Shot.name == "how" { how = true }
        }
    }

    private func bigButton(_ title: String, _ icon: String, filled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 22, weight: .black))
            Text(title).font(rnd(20, .black))
            Spacer()
            Image(systemName: "chevron.left").font(.system(size: 16, weight: .black)).opacity(0.7)
        }
        .foregroundStyle(filled ? Color.black.opacity(0.85) : .white)
        .padding(.horizontal, 22)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(filled ? AnyShapeStyle(LinearGradient(colors: [KT.gold, KT.ac], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(KT.s2))
        }
        .shadow(color: (filled ? KT.ac : .clear).opacity(0.5), radius: 18, y: 8)
    }

    private func statCard(_ label: String, _ value: Int, _ icon: String, _ c: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(c)
            Num(value).font(rnd(24, .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
            Text(label).font(rnd(13, .heavy)).foregroundStyle(KT.tx3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card(KT.s1, 20, stroke: c.opacity(0.22))
    }
}

/// شبكة زينة صغيرة للواجهة
struct DecoGrid: View {
    let board: [[Int]]
    var body: some View {
        GeometryReader { geo in
            let cols = board.first?.count ?? 1
            let rows = board.count
            let cell = min(geo.size.width / CGFloat(cols), geo.size.height / CGFloat(rows))
            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 4) {
                        ForEach(0..<cols, id: \.self) { c in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(board[r][c] == 0 ? AnyShapeStyle(KT.hole) : AnyShapeStyle(KT.block(board[r][c]).gradient))
                                .frame(width: cell - 4, height: cell - 4)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// شرح اللعبة
struct HowView: View {
    let done: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("شلون ألعب؟").font(rnd(30, .black)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 16) {
                rule("square.grid.3x3.fill", KT.ac, "اسحب القطعة", "شيل أيّ قطعة من تحت وحطّها على اللوح بمكان فاضي.")
                rule("rectangle.compress.vertical", KT.green, "إملا خطّ", "أيّ صفّ أو عمود يمتلي كامل، يمسح وياخذ نقاط.")
                rule("flame.fill", KT.ac2, "كومبو", "امسح أكثر من خطّ أو خطوط متتالية ⇒ نقاط أكثر.")
                rule("xmark.octagon.fill", KT.gold, "خلصت اللعبة", "لمّا ما يبقى مكان لأيّ قطعة من الثلاثة.")
            }
            Spacer()
            Button(action: done) {
                Text("يلّا نلعب").font(rnd(18, .black)).foregroundStyle(.black.opacity(0.85))
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(LinearGradient(colors: [KT.gold, KT.ac], startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
            .buttonStyle(Press())
        }
        .padding(24)
        .background(KT.bg.ignoresSafeArea())
    }

    private func rule(_ icon: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(.black.opacity(0.8))
                .frame(width: 54, height: 54).background(c.gradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(rnd(17, .heavy)).foregroundStyle(.white)
                Text(s).font(rnd(13.5)).foregroundStyle(KT.tx2).lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
    }
}
