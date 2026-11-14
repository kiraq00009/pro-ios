import SwiftUI

// MARK: - جواهر — a jewel match-3 game. App entry, palette, home screen.

@main
struct JawahirApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(Pal.accent)
        }
    }
}

// MARK: - Palette (own colors, dark theme)

enum Pal {
    static let bg      = Color(red: 0.055, green: 0.067, blue: 0.106)
    static let bg2     = Color(red: 0.090, green: 0.106, blue: 0.160)
    static let surface = Color(red: 0.125, green: 0.145, blue: 0.205)
    static let line    = Color.white.opacity(0.09)
    static let text    = Color.white
    static let sub     = Color.white.opacity(0.62)
    static let accent  = Color(red: 1.00, green: 0.72, blue: 0.28)   // amber gold
    static let accent2 = Color(red: 1.00, green: 0.46, blue: 0.36)   // coral
    static let good    = Color(red: 0.32, green: 0.86, blue: 0.56)
}

// 6 distinct gems: unique hue AND unique shape for colorblind clarity.
enum GemStyle {
    static let colors: [Color] = [
        Color(red: 0.96, green: 0.27, blue: 0.36),  // 0 ruby
        Color(red: 0.28, green: 0.56, blue: 0.98),  // 1 sapphire
        Color(red: 0.22, green: 0.82, blue: 0.53),  // 2 emerald
        Color(red: 1.00, green: 0.77, blue: 0.24),  // 3 topaz
        Color(red: 0.70, green: 0.44, blue: 0.96),  // 4 amethyst
        Color(red: 0.26, green: 0.86, blue: 0.91),  // 5 aqua
    ]
    static let symbols: [String] = [
        "circle.fill",    // 0
        "diamond.fill",   // 1
        "square.fill",    // 2
        "triangle.fill",  // 3
        "hexagon.fill",   // 4
        "seal.fill",      // 5
    ]
    static func color(_ t: Int) -> Color {
        guard t >= 0 && t < colors.count else { return Pal.surface }
        return colors[t]
    }
    static func symbol(_ t: Int) -> String {
        guard t >= 0 && t < symbols.count else { return "circle" }
        return symbols[t]
    }
}

// MARK: - LTR number (Arabic UI, western digits left-to-right)

struct Num: View {
    let value: Int
    init(_ value: Int) { self.value = value }
    var body: some View {
        Text(String(value))
            .environment(\.layoutDirection, .leftToRight)
            .monospacedDigit()
    }
}

// MARK: - Root: switches between home and game, handles screenshot jumps

struct RootView: View {
    enum Screen { case home, game }
    @StateObject private var vm = GameVM()
    @State private var screen: Screen = .home

    var body: some View {
        ZStack {
            BackdropView()
            content
        }
        .onAppear { handleShot() }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .home:
            HomeView(vm: vm, onPlay: { startGame() }, onResume: { resumeGame() })
                .transition(.opacity)
        case .game:
            GameView(vm: vm, onExit: { withAnimation { screen = .home } })
                .transition(.opacity)
        }
    }

    private func startGame() {
        vm.newGame(level: 1)
        withAnimation { screen = .game }
    }

    private func resumeGame() {
        if !vm.resume() {
            vm.newGame(level: 1)
        }
        withAnimation { screen = .game }
    }

    private func handleShot() {
        guard Shot.on else {
            vm.loadBestOnly()
            return
        }
        if Shot.isAny("game", "win", "over") {
            vm.setupForShot(Shot.name)
            screen = .game
        } else {
            vm.loadBestOnly()
            screen = .home
        }
    }
}

// MARK: - Animated backdrop

struct BackdropView: View {
    var body: some View {
        ZStack {
            Pal.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Pal.accent.opacity(0.16), .clear],
                center: .top, startRadius: 10, endRadius: 520
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Pal.accent2.opacity(0.12), .clear],
                center: .bottomLeading, startRadius: 10, endRadius: 460
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @ObservedObject var vm: GameVM
    let onPlay: () -> Void
    let onResume: () -> Void
    @State private var showHow = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)
            logo
            bestChip
            Spacer(minLength: 8)
            buttons
            Spacer(minLength: 28)
            footer
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .sheet(isPresented: $showHow) { HowToView() }
        .accessibilityIdentifier("home")
    }

    private var logo: some View {
        VStack(spacing: 14) {
            GemBadge()
            Text("جواهر")
                .font(rnd(56, .heavy))
                .foregroundStyle(
                    LinearGradient(colors: [Pal.accent, Pal.accent2],
                                   startPoint: .leading, endPoint: .trailing)
                )
            Text("طابق ثلاث جواهر أو أكثر")
                .font(rnd(17, .medium))
                .foregroundStyle(Pal.sub)
        }
    }

    private var bestChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill").foregroundStyle(Pal.accent)
            Text("الأفضل").font(rnd(15, .semibold)).foregroundStyle(Pal.sub)
            Num(vm.best).font(rnd(18, .bold)).foregroundStyle(Pal.text)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(Pal.surface))
        .overlay(Capsule().stroke(Pal.line, lineWidth: 1))
    }

    private var buttons: some View {
        VStack(spacing: 14) {
            if vm.hasSave {
                Button(action: onResume) {
                    HomeButtonLabel(icon: "play.circle.fill", title: "كمّل", primary: true)
                }
                .buttonStyle(Press())
                Button(action: onPlay) {
                    HomeButtonLabel(icon: "sparkles", title: "لعبة جديدة", primary: false)
                }
                .buttonStyle(Press())
            } else {
                Button(action: onPlay) {
                    HomeButtonLabel(icon: "play.fill", title: "العب", primary: true)
                }
                .buttonStyle(Press())
            }
            Button { showHow = true } label: {
                HomeButtonLabel(icon: "questionmark.circle", title: "كيف ألعب", primary: false)
            }
            .buttonStyle(Press())
        }
    }

    private var footer: some View {
        Text("رتّب الجواهر، اكسب النقاط، واوصل للهدف")
            .font(rnd(13, .regular))
            .foregroundStyle(Pal.sub)
            .multilineTextAlignment(.center)
    }
}

struct HomeButtonLabel: View {
    let icon: String
    let title: String
    let primary: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold))
            Text(title).font(rnd(20, .bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .foregroundStyle(primary ? Pal.bg : Pal.text)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(primary ? Color.clear : Pal.line, lineWidth: 1)
        )
    }
    @ViewBuilder private var background: some View {
        if primary {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Pal.accent, Pal.accent2],
                                     startPoint: .leading, endPoint: .trailing))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Pal.surface)
        }
    }
}

struct GemBadge: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Pal.surface)
                .frame(width: 112, height: 112)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Pal.line, lineWidth: 1)
                )
            HStack(spacing: -10) {
                gem(1, 0.85, -12)
                gem(3, 1.0, 0).zIndex(1)
                gem(4, 0.85, 12)
            }
        }
    }
    private func gem(_ t: Int, _ scale: CGFloat, _ y: CGFloat) -> some View {
        Image(systemName: GemStyle.symbol(t))
            .font(.system(size: 40, weight: .black))
            .foregroundStyle(GemStyle.color(t))
            .shadow(color: GemStyle.color(t).opacity(0.6), radius: 10)
            .scaleEffect(scale)
            .offset(y: y)
    }
}

// MARK: - How to play

struct HowToView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("كيف ألعب").font(rnd(26, .heavy)).foregroundStyle(Pal.text)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Pal.sub)
                }
            }
            row("hand.tap.fill", "دزّ على جوهرة، وبعدها على اللي جنبها حتى تبدّلهن")
            row("arrow.left.arrow.right", "التبديل يصير بس إذا صار صفّ من ٣ أو أكثر")
            row("sparkles", "الجواهر المتطابقة تختفي، واللي فوقها تنزل مكانها")
            row("flame.fill", "سلسلة تطابقات ورا بعض تعطيك نقاط مضاعفة")
            row("target", "اوصل للهدف قبل لا تخلص الحركات")
            Spacer()
        }
        .padding(24)
        .background(Pal.bg.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
    }
    private func row(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Pal.accent)
                .frame(width: 30)
            Text(text).font(rnd(16, .medium)).foregroundStyle(Pal.text)
            Spacer()
        }
    }
}
