import SwiftUI

/// اهتزاز اللوح عند الانفجار.
struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = sin(animatableData * .pi * 7) * 8
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

struct GameView: View {
    @EnvironmentObject var game: Game
    let close: () -> Void
    @State private var winSheet = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            hud
            boardArea
            flagBar
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Backdrop())
        .overlay { loseOverlay }
        .onReceive(timer) { _ in game.tick() }
        .onChange(of: game.win) { v in
            if v { winSheet = true }
        }
        .onAppear {
            if Shot.on { winSheet = game.win }
        }
        .sheet(isPresented: $winSheet) {
            WinView(again: {
                winSheet = false
                game.restart()
            }, home: {
                winSheet = false
                close()
            })
            .environmentObject(game)
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
            .presentationDetents([.medium])
        }
    }

    // ---- الشريط العلويّ ----
    private var hud: some View {
        HStack(spacing: 10) {
            Button { close() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white).frame(width: 44, height: 44).background(AL.s2, in: Circle())
            }
            .buttonStyle(Press())
            pill("💣", "\(game.mineCounter)")
            Spacer()
            Button { game.restart() } label: {
                Text(game.face).font(.system(size: 30)).frame(width: 56, height: 48).background(AL.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(Press())
            Spacer()
            pill("⏱", clock(game.elapsed))
        }
    }

    private func pill(_ glyph: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(glyph).font(.system(size: 15))
            Text(value).font(rnd(20, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
        }
        .frame(minWidth: 64)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .card(AL.s1, 14)
    }

    // ---- اللوح ----
    private var boardArea: some View {
        GeometryReader { geo in
            let cols = game.diff.cols
            let rows = game.diff.rows
            let gap: CGFloat = cols > 12 ? 2.5 : 3.5
            let wSide = (geo.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let hSide = (geo.size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            let side = max(14, min(wSide, hSide))
            let boardW = side * CGFloat(cols) + gap * CGFloat(cols - 1)
            let boardH = side * CGFloat(rows) + gap * CGFloat(rows - 1)
            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { c in
                            TileView(i: r * cols + c, side: side)
                        }
                    }
                }
            }
            .frame(width: boardW, height: boardH)
            .modifier(Shake(animatableData: CGFloat(game.shake)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // ---- شريط التبديل تحت ----
    private var flagBar: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { game.flagMode.toggle() }
            Haptic.tap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: game.flagMode ? "flag.fill" : "hand.tap.fill").font(.system(size: 18, weight: .black))
                Text(game.flagMode ? "وضع العلم 🚩" : "وضع الكشف").font(rnd(17, .black))
            }
            .foregroundStyle(game.flagMode ? Color.black.opacity(0.85) : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(game.flagMode ? AnyShapeStyle(LinearGradient(colors: [AL.accent2, AL.accent], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(AL.s2), in: Capsule())
            .overlay(Capsule().stroke(AL.accent.opacity(game.flagMode ? 0 : 0.3)))
        }
        .buttonStyle(Press())
    }

    // ---- طبقة الخسارة ----
    @ViewBuilder private var loseOverlay: some View {
        if game.lose {
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Text("💥").font(.system(size: 46))
                    Text("انفجرت!").font(rnd(27, .black)).foregroundStyle(Color.white)
                    Text("ضغطت لغم — جرّب مرّة لك").font(rnd(13.5)).foregroundStyle(AL.tx2)
                    HStack(spacing: 10) {
                        Button { game.restart() } label: {
                            bigLabel("جرّب مرّة لك", filled: true)
                        }
                        .buttonStyle(Press())
                        Button { close() } label: {
                            bigLabel("رجوع", filled: false)
                        }
                        .buttonStyle(Press())
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .card(AL.s1, 26, stroke: AL.red.opacity(0.4))
                .padding(14)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func bigLabel(_ t: String, filled: Bool) -> some View {
        Text(t)
            .font(rnd(16, .black))
            .foregroundStyle(filled ? Color.black.opacity(0.85) : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(filled ? AnyShapeStyle(AL.accent) : AnyShapeStyle(AL.s2), in: Capsule())
    }
}

struct TileView: View {
    @EnvironmentObject var game: Game
    let i: Int
    let side: CGFloat

    var body: some View {
        let b = game.b
        let rev = b.revealed[i]
        let isMine = b.mine[i]
        let n = b.adj[i]
        let r = max(4, side * 0.2)
        ZStack {
            if rev {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(i == b.boom ? AL.red.opacity(0.92) : AL.open)
                    .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(AL.openEdge))
                if isMine {
                    Text("💣").font(.system(size: side * 0.52))
                } else if n > 0 {
                    Text("\(n)")
                        .font(rnd(side * 0.56, .black))
                        .foregroundStyle(AL.num(n))
                        .environment(\.layoutDirection, .leftToRight)
                        .transition(.scale.combined(with: .opacity))
                }
            } else {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(LinearGradient(colors: [AL.tileTop, AL.tileBot], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(Color.white.opacity(0.09)))
                if b.flagged[i] {
                    Text("🚩").font(.system(size: side * 0.5)).transition(.scale)
                }
            }
        }
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .onTapGesture { game.tapCell(i) }
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.3).onEnded { _ in game.flag(i) })
    }
}

struct WinView: View {
    @EnvironmentObject var game: Game
    let again: () -> Void
    let home: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("🎉").font(.system(size: 54))
            Text("فزت!").font(rnd(34, .black)).foregroundStyle(Color.white)
            if game.newBest {
                Text("رقم قياسيّ جديد ⭐").font(rnd(13, .heavy)).foregroundStyle(Color.black.opacity(0.85)).padding(.horizontal, 12).padding(.vertical, 5).background(AL.gold, in: Capsule())
            }
            HStack(spacing: 10) {
                statBox("الوقت", clock(game.elapsed), AL.accent)
                statBox("أفضل وقت", clock(game.best[game.diff.key] ?? game.elapsed), AL.gold)
            }
            HStack(spacing: 10) {
                Button(action: again) {
                    Text("لعبة جديدة").font(rnd(17, .black)).foregroundStyle(Color.black.opacity(0.85)).frame(maxWidth: .infinity).frame(height: 54).background(AL.accent, in: Capsule())
                }
                .buttonStyle(Press())
                Button(action: home) {
                    Text("رجوع").font(rnd(17, .black)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 54).background(AL.s2, in: Capsule())
                }
                .buttonStyle(Press())
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AL.bg.ignoresSafeArea())
    }

    private func statBox(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 4) {
            Text(l).font(rnd(12, .heavy)).foregroundStyle(AL.tx3)
            Text(v).font(rnd(26, .black)).foregroundStyle(c).environment(\.layoutDirection, .leftToRight)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .card(AL.s1, 18, stroke: c.opacity(0.25))
    }
}
