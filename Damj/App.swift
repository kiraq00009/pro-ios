import SwiftUI

// MARK: - Palette (dark, warm)

enum Pal {
    static let bg = Color(red: 0.07, green: 0.06, blue: 0.09)
    static let panel = Color(red: 0.13, green: 0.12, blue: 0.16)
    static let slot = Color(red: 0.19, green: 0.17, blue: 0.22)
    static let board = Color(red: 0.11, green: 0.10, blue: 0.14)
    static let tint = Color(red: 1.0, green: 0.55, blue: 0.19)
    static let ink = Color.white
    static let dim = Color.white.opacity(0.55)

    // Each tile value gets its own warm color, cooling toward gold at the top.
    static func tile(_ v: Int) -> Color {
        switch v {
        case 2:    return Color(red: 0.30, green: 0.27, blue: 0.33)
        case 4:    return Color(red: 0.42, green: 0.33, blue: 0.30)
        case 8:    return Color(red: 0.86, green: 0.52, blue: 0.30)
        case 16:   return Color(red: 0.92, green: 0.46, blue: 0.26)
        case 32:   return Color(red: 0.95, green: 0.39, blue: 0.28)
        case 64:   return Color(red: 0.96, green: 0.31, blue: 0.24)
        case 128:  return Color(red: 0.97, green: 0.62, blue: 0.24)
        case 256:  return Color(red: 0.98, green: 0.69, blue: 0.20)
        case 512:  return Color(red: 0.99, green: 0.74, blue: 0.16)
        case 1024: return Color(red: 1.00, green: 0.80, blue: 0.22)
        case 2048: return Color(red: 1.00, green: 0.84, blue: 0.30)
        default:   return Color(red: 0.55, green: 0.30, blue: 0.85)
        }
    }

    static func ink(_ v: Int) -> Color { v <= 4 ? Color.white.opacity(0.92) : Color(red: 0.12, green: 0.08, blue: 0.05) }
}

// MARK: - App

@main
struct DamjApp: App {
    @StateObject private var game = Game()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .environment(\.layoutDirection, .rightToLeft)
                .tint(Pal.tint)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root

enum Screen { case home, game }

struct ContentView: View {
    @EnvironmentObject var game: Game
    @State private var screen: Screen = .home
    @State private var showHowTo = false

    var body: some View {
        ZStack {
            Pal.bg.ignoresSafeArea()
            Group {
                if screen == .home {
                    HomeView(screen: $screen, showHowTo: $showHowTo)
                } else {
                    GameView(screen: $screen)
                }
            }
            .transition(.opacity)
        }
        .sheet(isPresented: $showHowTo) { HowToSheet() }
        .onAppear { bootstrap() }
    }

    private func bootstrap() {
        if Shot.on {
            seedForShot()
            return
        }
    }

    private func seedForShot() {
        let mid = [[2, 32, 4, 2], [16, 128, 8, 64], [4, 8, 256, 2], [2, 4, 16, 8]]
        if Shot.isAny("home") {
            game.seed(board: mid, score: 6208)
            game.best = 11640
            screen = .home
        } else if Shot.isAny("game") {
            game.seed(board: mid, score: 6208)
            screen = .game
        } else if Shot.isAny("win") {
            let w = [[2048, 4, 2, 16], [8, 32, 128, 4], [2, 8, 16, 64], [4, 2, 8, 2]]
            game.seed(board: w, score: 20492, won: true)
            screen = .game
        } else if Shot.isAny("over") {
            let o = [[2, 4, 2, 4], [64, 32, 16, 8], [4, 2, 128, 2], [16, 8, 4, 16]]
            game.seed(board: o, score: 3120, over: true)
            screen = .game
        } else {
            game.seed(board: mid, score: 6208)
            screen = .home
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject var game: Game
    @Binding var screen: Screen
    @Binding var showHowTo: Bool

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            VStack(spacing: 10) {
                Text("دمج")
                    .font(rnd(84, weight: .black))
                    .foregroundColor(Pal.tint)
                Text("دمج الأرقام ووصّل لـ 2048")
                    .font(rnd(17))
                    .foregroundColor(Pal.dim)
            }

            bestCard

            sizeToggle

            VStack(spacing: 12) {
                if game.hasSaved {
                    Button {
                        if game.loadSaved() { go(.game) }
                    } label: {
                        bigLabel("كمّل اللعبة", filled: true)
                    }
                    .buttonStyle(Press())
                }
                Button {
                    game.newGame(size: game.size)
                    go(.game)
                } label: {
                    bigLabel("لعبة جديدة", filled: !game.hasSaved)
                }
                .buttonStyle(Press())

                Button { showHowTo = true } label: {
                    bigLabel("شلون العب؟", filled: false)
                }
                .buttonStyle(Press())
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding()
    }

    private var bestCard: some View {
        HStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("الأفضل").font(rnd(13, weight: .semibold)).foregroundColor(Pal.dim)
                Text("\(game.best)")
                    .font(rnd(30, weight: .bold))
                    .foregroundColor(Pal.ink)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: 260)
        .card(Pal.panel, r: 20, stroke: Pal.tint.opacity(0.25))
    }

    private var sizeToggle: some View {
        HStack(spacing: 10) {
            ForEach([4, 5], id: \.self) { n in
                Button {
                    game.size = n
                    Haptic.tap()
                } label: {
                    Text("\(n)×\(n)")
                        .font(rnd(16, weight: .bold))
                        .environment(\.layoutDirection, .leftToRight)
                        .foregroundColor(game.size == n ? Pal.ink : Pal.dim)
                        .frame(width: 74, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(game.size == n ? Pal.tint.opacity(0.9) : Pal.panel)
                        )
                }
                .buttonStyle(Press())
            }
        }
    }

    private func bigLabel(_ t: String, filled: Bool) -> some View {
        Text(t)
            .font(rnd(19, weight: .bold))
            .foregroundColor(filled ? Color(red: 0.12, green: 0.08, blue: 0.05) : Pal.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(filled ? Pal.tint : Pal.panel)
            )
    }

    private func go(_ s: Screen) {
        withAnimation(.easeInOut(duration: 0.25)) { screen = s }
    }
}

// MARK: - Game screen

struct GameView: View {
    @EnvironmentObject var game: Game
    @Binding var screen: Screen

    var body: some View {
        VStack(spacing: 16) {
            topBar
            scoreRow
            BoardView()
                .padding(.horizontal, 6)
            controlRow
            Spacer(minLength: 0)
        }
        .padding()
        .overlay { overlays }
    }

    private var topBar: some View {
        HStack {
            Button {
                game.save()
                withAnimation(.easeInOut(duration: 0.25)) { screen = .home }
            } label: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Pal.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Pal.panel))
            }
            .buttonStyle(Press())
            Spacer()
            Text("دمج").font(rnd(30, weight: .black)).foregroundColor(Pal.tint)
            Spacer()
            Button {
                game.newGame(size: game.size)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Pal.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Pal.panel))
            }
            .buttonStyle(Press())
        }
    }

    private var scoreRow: some View {
        HStack(spacing: 12) {
            statBox(title: "النقاط", value: game.score)
            statBox(title: "الأفضل", value: game.best)
        }
    }

    private func statBox(title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title).font(rnd(12, weight: .semibold)).foregroundColor(Pal.dim)
            Text("\(value)")
                .font(rnd(24, weight: .bold))
                .foregroundColor(Pal.ink)
                .environment(\.layoutDirection, .leftToRight)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card(Pal.panel, r: 16, stroke: .clear)
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Button { game.undo() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("تراجع").font(rnd(16, weight: .bold))
                }
                .foregroundColor(game.canUndo ? Pal.ink : Pal.dim.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .card(Pal.panel, r: 16, stroke: .clear)
            }
            .buttonStyle(Press())
            .disabled(!game.canUndo)

            Button { game.newGame(size: game.size) } label: {
                Text("لعبة جديدة")
                    .font(rnd(16, weight: .bold))
                    .foregroundColor(Color(red: 0.12, green: 0.08, blue: 0.05))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Pal.tint))
            }
            .buttonStyle(Press())
        }
    }

    @ViewBuilder
    private var overlays: some View {
        if game.won {
            EndOverlay(
                title: "فزت!",
                subtitle: "وصلت لـ 2048 — تكدر تكمّل وتجمع أكثر",
                primary: "كمّل اللعبة",
                secondary: "لعبة جديدة",
                primaryAction: { game.continueAfterWin() },
                secondaryAction: { game.newGame(size: game.size) }
            )
        } else if game.over {
            EndOverlay(
                title: "خلصت اللعبة",
                subtitle: "ماكو حركة باقية — نقاطك \(game.score)",
                primary: "لعبة جديدة",
                secondary: "تراجع",
                primaryAction: { game.newGame(size: game.size) },
                secondaryAction: { game.undo() }
            )
        }
    }
}

// MARK: - Board

struct BoardView: View {
    @EnvironmentObject var game: Game

    var body: some View {
        GeometryReader { geo in
            let n = game.size
            let gap: CGFloat = n == 4 ? 12 : 9
            let side = min(geo.size.width, geo.size.height)
            let cell = (side - gap * CGFloat(n + 1)) / CGFloat(n)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22).fill(Pal.board)

                ForEach(0..<n, id: \.self) { r in
                    ForEach(0..<n, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Pal.slot)
                            .frame(width: cell, height: cell)
                            .offset(x: pos(c, cell, gap), y: pos(r, cell, gap))
                    }
                }

                ForEach(game.tiles) { t in
                    TileView(value: t.value, cell: cell)
                        .scaleEffect(t.pop ? 1.08 : 1.0)
                        .offset(x: pos(t.col, cell, gap), y: pos(t.row, cell, gap))
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(t.pop ? 2 : 1)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.layoutDirection, .leftToRight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 14)
                    .onEnded { v in handle(v.translation) }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func pos(_ i: Int, _ cell: CGFloat, _ gap: CGFloat) -> CGFloat {
        gap + CGFloat(i) * (cell + gap)
    }

    private func handle(_ d: CGSize) {
        if abs(d.width) > abs(d.height) {
            game.move(d.width > 0 ? .right : .left)
        } else {
            game.move(d.height > 0 ? .down : .up)
        }
    }
}

struct TileView: View {
    let value: Int
    let cell: CGFloat

    private var fontSize: CGFloat {
        let digits = String(value).count
        let base = cell * (digits <= 2 ? 0.42 : digits == 3 ? 0.34 : 0.27)
        return max(14, base)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Pal.tile(value))
            .overlay(
                Text("\(value)")
                    .font(rnd(fontSize, weight: .black))
                    .foregroundColor(Pal.ink(value))
                    .environment(\.layoutDirection, .leftToRight)
                    .minimumScaleFactor(0.5)
                    .padding(4)
            )
            .shadow(color: value >= 8 ? Pal.tile(value).opacity(0.5) : .clear, radius: 8, y: 2)
            .frame(width: cell, height: cell)
    }
}

// MARK: - End overlay

struct EndOverlay: View {
    let title: String
    let subtitle: String
    let primary: String
    let secondary: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(title)
                    .font(rnd(44, weight: .black))
                    .foregroundColor(Pal.tint)
                Text(subtitle)
                    .font(rnd(16))
                    .foregroundColor(Pal.dim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                VStack(spacing: 10) {
                    Button(action: primaryAction) {
                        Text(primary)
                            .font(rnd(18, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.08, blue: 0.05))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Pal.tint))
                    }
                    .buttonStyle(Press())
                    Button(action: secondaryAction) {
                        Text(secondary)
                            .font(rnd(17, weight: .bold))
                            .foregroundColor(Pal.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Pal.panel))
                    }
                    .buttonStyle(Press())
                }
            }
            .padding(26)
            .frame(maxWidth: 340)
            .card(Pal.board, r: 26, stroke: Pal.tint.opacity(0.3))
            .padding(30)
        }
        .transition(.opacity)
    }
}

// MARK: - How to

struct HowToSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .trailing, spacing: 18) {
            Text("شلون العب؟")
                .font(rnd(30, weight: .black))
                .foregroundColor(Pal.tint)
                .frame(maxWidth: .infinity, alignment: .trailing)

            row("اسحب فوق/تحت/يمين/يسار تتحرك كل البلاطات.")
            row("لمن تلتكي بلاطتين بنفس الرقم ينصهرن وحدة أكبر.")
            row("كل حركة تطلع بلاطة جديدة 2 أو 4 بمكان فاضي.")
            row("هدفك توصل بلاطة 2048 — وبعدها تكدر تكمّل.")
            row("تخلص اللعبة لمن ماكو ولا حركة تنفع.")

            Spacer()
            Button { dismiss() } label: {
                Text("فهمت")
                    .font(rnd(18, weight: .bold))
                    .foregroundColor(Color(red: 0.12, green: 0.08, blue: 0.05))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Pal.tint))
            }
            .buttonStyle(Press())
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Pal.bg.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func row(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(t)
                .font(rnd(16))
                .foregroundColor(Pal.ink)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Circle().fill(Pal.tint).frame(width: 8, height: 8).padding(.top, 7)
        }
    }
}
