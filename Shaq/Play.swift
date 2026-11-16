import SwiftUI

/// يلفّ شاشة اللعب حتى «من جديد» و«التالية» يبنون محرّك جديد
struct PlayHost: View {
    @State private var mode: PlayMode
    @State private var attempt = 0
    let close: () -> Void

    init(mode: PlayMode, close: @escaping () -> Void) {
        _mode = State(initialValue: mode)
        self.close = close
    }

    var body: some View {
        ArenaScreen(mode: mode, restart: { attempt += 1 }, next: goNext, close: close)
            .id("\(mode.key)-\(attempt)")
    }

    private func goNext() {
        if case .campaign(let id) = mode, id + 1 < Levels.total { mode = .campaign(id + 1) }
        attempt += 1
    }
}

struct PlayBackdrop: View {
    let skin: Skin
    var body: some View {
        ZStack {
            LinearGradient(colors: [skin.bg0, skin.bg1], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [skin.a.opacity(0.16), Color.clear], center: .center, startRadius: 0, endRadius: 380)
            RadialGradient(colors: [skin.b.opacity(0.10), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }
}

struct ArenaScreen: View {
    @EnvironmentObject var prog: Prog
    @StateObject private var arena: Arena
    @State private var shown: Finish? = nil
    let restart: () -> Void
    let next: () -> Void
    let close: () -> Void

    init(mode: PlayMode, restart: @escaping () -> Void, next: @escaping () -> Void, close: @escaping () -> Void) {
        _arena = StateObject(wrappedValue: Arena(mode: mode))
        self.restart = restart
        self.next = next
        self.close = close
    }

    var body: some View {
        let skin = Catalog.skin(prog.d.skin)
        let blade = Catalog.blade(prog.d.blade)
        ZStack {
            PlayBackdrop(skin: skin)
            Stage(arena: arena, skin: skin, blade: blade)
            HUD(arena: arena, pause: { Haptic.tap(); arena.paused = true })
            if arena.paused && shown == nil {
                PauseCard(title: arena.mode.title, resume: { arena.paused = false }, restart: restart, home: close)
                    .transition(.opacity)
            }
            if let f = shown {
                ResultCard(f: f, prog: prog, next: next, retry: restart, home: close)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .onAppear {
            arena.haptics = prog.d.haptics
            Synth.shared.enabled = prog.d.sound
            Synth.shared.start()
            let p = prog
            arena.onRound = { e, g in p.recordRound(e, g) }
            if Shot.on {
                arena.prepareShot(Shot.name)
                if let f = arena.finish, shown == nil { shown = prog.commit(f) }
            }
        }
        .onChange(of: arena.finish?.id) { _ in
            guard let f = arena.finish, shown == nil else { return }
            let res = prog.commit(f)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { shown = res }
                if res.coins > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { Synth.shared.play("coin") } }
            }
        }
        .animation(.easeOut(duration: 0.2), value: arena.paused)
    }
}

/// الساحة: Canvas يُرسم كلّ فريم + سحب الإصبع
struct Stage: View {
    let arena: Arena
    let skin: Skin
    let blade: Blade

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let now = tl.date.timeIntervalSinceReferenceDate
                arena.size = size
                arena.frame(now)
                Painter.draw(&ctx, size, arena, skin, blade, now)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .coordinateSpace(name: "stage")
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("stage"))
                .onChanged { v in arena.drag(v.location, from: v.startLocation) }
                .onEnded { v in arena.release(v.startLocation, v.location) }
        )
    }
}

// MARK: الواجهة فوق الساحة

struct HUD: View {
    @ObservedObject var arena: Arena
    let pause: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            topBar
            goal.allowsHitTesting(false)
            Spacer()
            bottom.allowsHitTesting(false)
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 14)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: pause) {
                Image(systemName: "pause.fill").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 44, height: 44).background(Color.white.opacity(0.09), in: Circle())
            }.buttonStyle(Press())
            VStack(alignment: .leading, spacing: 4) {
                Text(arena.mode.title).font(rnd(16, .black)).foregroundStyle(Color.white)
                progress
            }
            Spacer()
            if arena.combo >= 2 && arena.mode != .zen {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.system(size: 12, weight: .black))
                    Text("×\(arena.combo)").font(rnd(14, .black)).environment(\.layoutDirection, .leftToRight)
                }
                .foregroundStyle(Color.black.opacity(0.8)).padding(.horizontal, 10).frame(height: 30)
                .background(SQ.hot, in: Capsule())
                .transition(.scale.combined(with: .opacity))
            }
            if arena.mode == .endless {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < arena.lives ? "heart.fill" : "heart").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(i < arena.lives ? SQ.coral : SQ.tx3)
                    }
                }
            }
            if arena.mode != .zen {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(arena.score)").font(rnd(22, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
                        .contentTransition(.numericText())
                    Text("نقطة").font(rnd(10.5, .bold)).foregroundStyle(SQ.tx3)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: arena.combo)
        .animation(.easeOut(duration: 0.25), value: arena.score)
    }

    @ViewBuilder private var progress: some View {
        if let n = arena.totalRounds {
            HStack(spacing: 4) {
                ForEach(0..<n, id: \.self) { i in
                    Capsule().fill(i < arena.roundIndex ? SQ.amber : (i == arena.roundIndex ? Color.white : Color.white.opacity(0.18)))
                        .frame(width: i == arena.roundIndex ? 18 : 8, height: 5)
                }
            }
        } else {
            Text("الجولة \(arena.roundIndex + 1)").font(rnd(11.5, .bold)).foregroundStyle(SQ.tx3)
        }
    }

    private var goal: some View {
        VStack(spacing: 6) {
            Text(arena.goalText).font(rnd(30, .black)).foregroundStyle(Color.white)
                .shadow(color: SQ.coral.opacity(0.6), radius: 14)
                .environment(\.layoutDirection, .rightToLeft)
            if arena.cutsLeft > 0, arena.verdict == nil, arena.round.goal.cuts == 2 {
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { i in
                        Image(systemName: "scissors").font(.system(size: 12, weight: .black))
                            .foregroundStyle(i < arena.cutsLeft ? SQ.amber : SQ.tx3)
                    }
                    Text(arena.cutsLeft == 2 ? "قطعتان" : "قطعة وحدة باقية").font(rnd(12, .bold)).foregroundStyle(SQ.tx2)
                }
            }
        }.padding(.top, 8)
    }

    @ViewBuilder private var bottom: some View {
        if let v = arena.verdict {
            VStack(spacing: 4) {
                Text(v.main).font(rnd(34, .black)).foregroundStyle(SQ.grade(v.grade)).environment(\.layoutDirection, .leftToRight)
                    .minimumScaleFactor(0.6).lineLimit(1)
                HStack(spacing: 8) {
                    Text(v.sub).font(rnd(13.5, .bold)).foregroundStyle(SQ.tx2)
                    if v.points > 0 {
                        Text("+\(v.points)").font(rnd(13.5, .black)).foregroundStyle(SQ.gold).environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(SQ.grade(v.grade).opacity(0.35)))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if !arena.hint.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "hand.draw.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(SQ.amber)
                Text(arena.hint).font(rnd(14, .bold)).foregroundStyle(SQ.tx2)
            }
            .padding(.horizontal, 16).frame(height: 40)
            .background(Color.white.opacity(0.07), in: Capsule())
        }
    }
}

struct PauseCard: View {
    let title: String
    let resume: () -> Void
    let restart: () -> Void
    let home: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "pause.circle.fill").font(.system(size: 46)).foregroundStyle(SQ.amber)
                Text("استراحة").font(rnd(28, .black)).foregroundStyle(Color.white)
                Text(title).font(rnd(14, .bold)).foregroundStyle(SQ.tx3)
                BigButton(title: "كمّل", icon: "play.fill", filled: true, action: resume).padding(.top, 6)
                BigButton(title: "من جديد", icon: "arrow.counterclockwise", filled: false, action: restart)
                BigButton(title: "الرئيسيّة", icon: "house.fill", filled: false, action: home)
            }
            .padding(22).frame(maxWidth: 340).card(SQ.s1, 28, stroke: SQ.amber.opacity(0.2)).padding(24)
        }
    }
}

struct BigButton: View {
    let title: String
    let icon: String
    let filled: Bool
    let action: () -> Void
    var body: some View {
        Button { Haptic.tap(); action() } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15, weight: .black))
                Text(title).font(rnd(17, .black))
            }
            .foregroundStyle(filled ? Color.black.opacity(0.82) : Color.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(filled ? AnyShapeStyle(SQ.hot) : AnyShapeStyle(Color.white.opacity(0.08)), in: Capsule())
        }.buttonStyle(Press())
    }
}

struct ResultCard: View {
    let f: Finish
    @ObservedObject var prog: Prog
    let next: () -> Void
    let retry: () -> Void
    let home: () -> Void
    @State private var shownStars = 0

    private var canNext: Bool {
        if case .campaign(let id) = f.mode { return f.stars > 0 && id + 1 < Levels.total }
        return false
    }
    private var headline: String {
        switch f.mode {
        case .campaign: return f.stars == 3 ? "جرّاح محترف!" : (f.stars > 0 ? "خلصت المرحلة" : "قريب! جرّب مرّة ثانية")
        case .endless: return f.newBest ? "رقم قياسيّ جديد!" : "خلصت المحاولات"
        case .daily: return "خلصت تحدّي اليوم"
        case .zen: return "جلسة هادئة"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(headline).font(rnd(26, .black)).foregroundStyle(Color.white).multilineTextAlignment(.center)
                if case .campaign = f.mode { starsRow }
                if case .daily = f.mode { starsRow }
                Text("\(f.score)").font(rnd(52, .black)).foregroundStyle(SQ.hot).environment(\.layoutDirection, .leftToRight)
                    .shadow(color: SQ.coral.opacity(0.4), radius: 16)
                statGrid
                if f.coins > 0 {
                    HStack(spacing: 6) {
                        CoinDot(size: 18)
                        Text("+\(f.coins)").font(rnd(17, .black)).foregroundStyle(SQ.gold).environment(\.layoutDirection, .leftToRight)
                        Text("عملة").font(rnd(13, .bold)).foregroundStyle(SQ.tx2)
                    }
                    .padding(.horizontal, 14).frame(height: 36).background(SQ.gold.opacity(0.12), in: Capsule())
                }
                if case .daily = f.mode {
                    Text("ارجع بكرة لتحدٍّ جديد — نفس الجولات للكلّ").font(rnd(12.5)).foregroundStyle(SQ.tx3)
                }
                VStack(spacing: 10) {
                    if canNext { BigButton(title: "المرحلة التالية", icon: "chevron.left", filled: true, action: next) }
                    BigButton(title: "العب مرّة ثانية", icon: "arrow.counterclockwise", filled: !canNext, action: retry)
                    BigButton(title: "الرئيسيّة", icon: "house.fill", filled: false, action: home)
                }.padding(.top, 4)
            }
            .padding(22).frame(maxWidth: 360).card(SQ.s1, 30, stroke: SQ.coral.opacity(0.25)).padding(20)
        }
        .onAppear {
            for i in 0..<f.stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.22) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { shownStars = i + 1 }
                    if !Shot.on && prog.d.haptics { Haptic.thud() }
                    Synth.shared.play("tap")
                }
            }
            if Shot.on { shownStars = f.stars }
        }
    }

    private var starsRow: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill").font(.system(size: i == 1 ? 46 : 36, weight: .black))
                    .foregroundStyle(i < shownStars ? SQ.gold : Color.white.opacity(0.12))
                    .shadow(color: i < shownStars ? SQ.gold.opacity(0.7) : Color.clear, radius: 12)
                    .scaleEffect(i < shownStars ? 1 : 0.8)
                    .offset(y: i == 1 ? -8 : 0)
            }
        }
    }

    private var statGrid: some View {
        HStack(spacing: 8) {
            mini(String(format: "±%.1f%%", f.avg), "معدّل الخطأ", SQ.cyan)
            mini("\(f.perfects)", "مثالي", SQ.gold)
            mini("×\(f.bestCombo)", "أعلى كومبو", SQ.coral)
            mini("\(f.rounds)", "جولة", SQ.mint)
        }
    }
    private func mini(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 3) {
            Text(v).font(rnd(16, .black)).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.6).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(10.5, .bold)).foregroundStyle(SQ.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity).padding(.vertical, 10).card(SQ.s2, 14)
    }
}

struct CoinDot: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [SQ.gold, Color(red: 0.95, green: 0.55, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(Color.white.opacity(0.5), lineWidth: size * 0.08).padding(size * 0.14)
            Image(systemName: "scissors").font(.system(size: size * 0.42, weight: .black)).foregroundStyle(Color.black.opacity(0.55))
        }.frame(width: size, height: size)
    }
}
