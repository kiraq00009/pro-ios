import SwiftUI

struct GameView: View {
    @StateObject private var eng: Engine
    @Environment(\.scenePhase) private var scenePhase
    @State private var down = false
    let close: () -> Void

    init(store: Store, daily: Bool, close: @escaping () -> Void) {
        _eng = StateObject(wrappedValue: Engine(store: store, daily: daily))
        self.close = close
    }

    var body: some View {
        ZStack {
            MD.bg.ignoresSafeArea()
            GameCanvas(eng: eng)
                .environment(\.layoutDirection, .leftToRight)
                .ignoresSafeArea()
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !down { down = true; eng.tap() }
                    }
                    .onEnded { _ in down = false })
            GameHUD(eng: eng)
            if eng.phase == .ready && !eng.paused { ReadyHint(daily: eng.daily, revived: eng.usedContinue) }
            if let b = eng.banner { ZoneBanner(text: b).transition(.scale.combined(with: .opacity)) }
            if eng.paused { PauseCard(eng: eng, home: leave) }
            if eng.phase == .over, let s = eng.stats { OverCard(eng: eng, stats: s, home: leave) }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: eng.phase == .over)
        .animation(.easeOut(duration: 0.25), value: eng.banner)
        .animation(.easeOut(duration: 0.2), value: eng.paused)
        .onChange(of: scenePhase) { v in
            if v != .active && (eng.phase == .playing || eng.phase == .ready) && !Shot.on { eng.paused = true }
        }
        .onAppear { Synth.shared.warm() }
        .statusBarHidden(true)
    }

    private func leave() {
        eng.commit()
        close()
    }
}

struct GameCanvas: View {
    @ObservedObject var eng: Engine
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                eng.frame(tl.date, size)
                eng.draw(&ctx, size)
            }
        }
    }
}

struct GameHUD: View {
    @ObservedObject var eng: Engine
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Button {
                    FX.tap(); eng.paused = true
                } label: {
                    Image(systemName: "pause.fill").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                        .frame(width: 44, height: 44).background(Color.white.opacity(0.1), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12)))
                }.buttonStyle(Press())
                .opacity(eng.phase == .over ? 0 : 1)
                Spacer()
                VStack(spacing: 2) {
                    Text("\(eng.score)").font(rnd(46, .black)).foregroundStyle(Color.white)
                        .shadow(color: MD.cyan.opacity(0.5), radius: 12)
                        .environment(\.layoutDirection, .leftToRight)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up").font(.system(size: 10, weight: .black))
                        Text("كوكب \(eng.height)").font(rnd(12, .heavy))
                        if eng.daily { Text("· تحدّي اليوم").font(rnd(12, .heavy)).foregroundStyle(MD.gold) }
                    }.foregroundStyle(MD.tx2)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: eng.score)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "diamond.fill").font(.system(size: 12, weight: .black)).foregroundStyle(MD.gold)
                    Text("\(eng.gemsRun)").font(rnd(16, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12)))
            }
            if eng.combo >= 1 {
                ComboBadge(combo: eng.combo).padding(.top, 6).transition(.scale.combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: eng.combo)
    }
}

struct ComboBadge: View {
    let combo: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").font(.system(size: 13, weight: .black))
            Text("كومبو ×\(Scoring.mult(combo))").font(rnd(15, .black))
        }
        .foregroundStyle(Color.black.opacity(0.85))
        .padding(.horizontal, 14).frame(height: 32)
        .background(MD.goldGrad, in: Capsule())
        .shadow(color: MD.gold.opacity(0.6), radius: 12)
        .scaleEffect(1 + min(0.25, Double(combo) * 0.04))
    }
}

struct ReadyHint: View {
    let daily: Bool
    let revived: Bool
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            if revived {
                Text("رجعت للمدار — خذ نَفَس وانطلق").font(rnd(14, .heavy)).foregroundStyle(MD.green)
            } else if daily {
                Text("تحدّي اليوم: نفس الكون لكلّ اللاعبين").font(rnd(14, .heavy)).foregroundStyle(MD.gold)
            }
            HStack(spacing: 9) {
                Image(systemName: "hand.tap.fill").font(.system(size: 18, weight: .bold))
                Text("اضغط بأيّ مكان حتى تنطلق").font(rnd(18, .black))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 22).frame(height: 54)
            .background(Color.white.opacity(0.1), in: Capsule())
            .overlay(Capsule().stroke(MD.cyan.opacity(0.45)))
            .scaleEffect(pulse ? 1.04 : 0.97)
            Text("اطلق المذنّب لمّا يكون باتّجاه الكوكب الجاي").font(rnd(12.5)).foregroundStyle(MD.tx3)
        }
        .padding(.bottom, 60)
        .allowsHitTesting(false)
        .onAppear {
            if Shot.on { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

struct ZoneBanner: View {
    let text: String
    var body: some View {
        VStack(spacing: 4) {
            Text("منطقة جديدة").font(rnd(13, .heavy)).foregroundStyle(MD.tx2)
            Text(text).font(rnd(30, .black)).foregroundStyle(MD.hero)
        }
        .padding(.horizontal, 26).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.bottom, 180)
        .allowsHitTesting(false)
    }
}

struct PauseCard: View {
    @ObservedObject var eng: Engine
    let home: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "pause.circle.fill").font(.system(size: 54)).foregroundStyle(MD.hero)
                Text("استراحة").font(rnd(30, .black)).foregroundStyle(Color.white)
                Text("نقاطك \(eng.score) · كوكب \(eng.height)").font(rnd(14, .bold)).foregroundStyle(MD.tx2)
                BigButton(title: "كمّل", icon: "play.fill", grad: MD.hero) { FX.tap(); eng.paused = false }
                HStack(spacing: 10) {
                    SmallButton(title: "من جديد", icon: "arrow.counterclockwise") { eng.restart() }
                    SmallButton(title: "القائمة", icon: "house.fill") { home() }
                }
            }
            .padding(24).frame(maxWidth: 340)
            .card(MD.s1, 30, stroke: MD.violet.opacity(0.3))
            .padding(24)
        }
    }
}

struct OverCard: View {
    @ObservedObject var eng: Engine
    let stats: RunStats
    let home: () -> Void
    private var store: Store { eng.store }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    statGrid
                    missionsDone
                    actions
                }
                .padding(22)
                .card(MD.s1, 32, stroke: MD.violet.opacity(0.3))
                .padding(.horizontal, 18).padding(.vertical, 40)
            }
        }
    }

    private var isBest: Bool { eng.preview?.newBest ?? false }

    private var header: some View {
        VStack(spacing: 6) {
            Text(stats.cause?.title ?? "انتهت الجولة").font(rnd(15, .heavy)).foregroundStyle(MD.red)
            if isBest {
                Text("رقم قياسيّ جديد!").font(rnd(14, .black)).foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 12).frame(height: 28).background(MD.goldGrad, in: Capsule())
            }
            Text("\(stats.score)").font(rnd(64, .black)).foregroundStyle(MD.hero)
                .environment(\.layoutDirection, .leftToRight)
            let best = max(store.p.best, stats.score)
            Text("أفضل نتيجة \(best)").font(rnd(14, .bold)).foregroundStyle(MD.tx2)
        }
    }

    private var statGrid: some View {
        HStack(spacing: 8) {
            tile("\(stats.planets)", "كوكب", "arrow.up.circle.fill", MD.cyan)
            tile("\(stats.perfects)", "مثاليّة", "scope", MD.gold)
            tile("\(stats.gems)", "جواهر", "diamond.fill", MD.magenta)
            tile("×\(Scoring.mult(stats.bestCombo))", "أعلى كومبو", "flame.fill", MD.green)
        }
    }

    private func tile(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(19, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(10.5)).foregroundStyle(MD.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .card(MD.s2, 16, stroke: c.opacity(0.25))
    }

    @ViewBuilder private var missionsDone: some View {
        let done: [Int] = eng.preview?.completed ?? []
        if !done.isEmpty {
            let ms = store.p.missions
            VStack(alignment: .leading, spacing: 8) {
                Text("مهمّات خلصت").font(rnd(13, .heavy)).foregroundStyle(MD.green)
                ForEach(done, id: \.self) { i in
                    if i < ms.count {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(MD.green)
                            Text(ms[i].title).font(rnd(13, .bold)).foregroundStyle(Color.white).lineLimit(2)
                            Spacer()
                            Text("+\(ms[i].reward) 💎").font(rnd(13, .black)).foregroundStyle(MD.gold)
                        }
                    }
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .card(MD.green.opacity(0.08), 16, stroke: MD.green.opacity(0.3))
        }
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: 10) {
            if !eng.usedContinue && !eng.committed {
                let can = eng.canAffordContinue
                Button {
                    if can { eng.continueRun() } else { FX.bad() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill").font(.system(size: 16, weight: .black))
                        Text("كمّل من وين وقفت").font(rnd(17, .black))
                        Spacer(minLength: 4)
                        HStack(spacing: 3) {
                            Image(systemName: "diamond.fill").font(.system(size: 11, weight: .black))
                            Text("\(Wallet.continueCost)").font(rnd(15, .black)).environment(\.layoutDirection, .leftToRight)
                        }
                        .padding(.horizontal, 10).frame(height: 30).background(Color.black.opacity(0.2), in: Capsule())
                    }
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 18).frame(height: 56)
                    .background(MD.goldGrad, in: Capsule())
                    .opacity(can ? 1 : 0.45)
                }.buttonStyle(Press())
                if !can {
                    Text("ما عندك جواهر كافية — عندك \(store.p.wallet.gems)").font(rnd(12)).foregroundStyle(MD.tx3)
                }
            }
            BigButton(title: "جولة ثانية", icon: "arrow.counterclockwise", grad: MD.hero) { eng.restart() }
            SmallButton(title: "القائمة", icon: "house.fill") { home() }
        }
        .padding(.top, 4)
    }
}

struct BigButton: View {
    let title: String
    let icon: String
    let grad: LinearGradient
    let act: () -> Void
    var body: some View {
        Button(action: act) {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 17, weight: .black))
                Text(title).font(rnd(19, .black))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity).frame(height: 58)
            .background(grad, in: Capsule())
            .shadow(color: MD.violet.opacity(0.5), radius: 16, y: 6)
        }.buttonStyle(Press())
    }
}

struct SmallButton: View {
    let title: String
    let icon: String
    let act: () -> Void
    var body: some View {
        Button(action: act) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
                Text(title).font(rnd(15, .heavy))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(MD.s2, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08)))
        }.buttonStyle(Press())
    }
}
