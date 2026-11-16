import SwiftUI

/// يبدّل بين الجولات بدون ما يسكّر الشاشة (إعادة فوريّة)
struct GameHost: View {
    @EnvironmentObject var store: GameStore
    @State private var req: GameReq
    let close: () -> Void

    init(start: GameReq, close: @escaping () -> Void) {
        _req = State(initialValue: start)
        self.close = close
    }

    var body: some View {
        GameView(req: req, store: store, next: { r in req = r }, close: close)
            .id(req.id)
            .transition(.opacity)
    }
}

struct GameView: View {
    @StateObject private var play: Play
    let next: (GameReq) -> Void
    let close: () -> Void

    init(req: GameReq, store: GameStore, next: @escaping (GameReq) -> Void, close: @escaping () -> Void) {
        _play = StateObject(wrappedValue: Play(req: req, store: store))
        self.next = next
        self.close = close
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { outer in
                GameCanvas(play: play, top: outer.safeAreaInsets.top + 118, bottom: outer.safeAreaInsets.bottom + 62)
                    .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                GameTopBar(play: play, restart: restart, close: close)
                Spacer()
                GameBottomBar(play: play)
            }
            if play.phase == .done, let v = play.verdict {
                ResultOverlay(play: play, v: v, primary: primary(v), retry: restart, close: close)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .statusBarHidden(false)
    }

    private func restart() {
        let r = play.req
        if r.mode == .endless {
            next(GameReq(mode: .endless, index: 0, runSeed: newSeed(), carry: 0))
        } else {
            next(GameReq(mode: r.mode, index: r.index, runSeed: r.runSeed, carry: r.carry))
        }
    }

    private func newSeed() -> UInt64 { UInt64.random(in: 1...UInt64(Int32.max)) }

    /// الزرّ الرئيسيّ بعد النتيجة
    private func primary(_ v: Verdict) -> (String, () -> Void)? {
        let r = play.req
        switch r.mode {
        case .campaign:
            if v.passed && r.index + 1 < Gen.campaignCount {
                return ("المرحلة الجاية", { next(GameReq(mode: .campaign, index: r.index + 1)) })
            }
            return nil
        case .endless:
            if v.passed {
                return ("الجولة الجاية", { next(GameReq(mode: .endless, index: r.index + 1, runSeed: r.runSeed, carry: v.total)) })
            }
            return ("جولة جديدة", { next(GameReq(mode: .endless, index: 0, runSeed: newSeed(), carry: 0)) })
        case .daily:
            return nil
        case .perfect:
            if v.passed && r.index + 1 < Gen.perfectCount {
                return ("التحدّي الجاي", { next(GameReq(mode: .perfect, index: r.index + 1)) })
            }
            return nil
        }
    }
}

/// اللوحة اللي ترسم اللعبة وتستقبل اللمس
struct GameCanvas: View {
    let play: Play
    let top: CGFloat
    let bottom: CGFloat

    var body: some View {
        GeometryReader { geo in
            let fit = Fit(size: geo.size, top: top, bottom: bottom)
            TimelineView(.animation) { tl in
                Canvas { g, size in
                    play.tick(tl.date.timeIntervalSinceReferenceDate)
                    Painter.game(g, size: size, play: play, fit: fit)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in play.setAim(fit.world(v.location)) }
                    .onEnded { v in play.shoot(fit.world(v.location)) }
            )
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct GameTopBar: View {
    @ObservedObject var play: Play
    let restart: () -> Void
    let close: () -> Void
    @State private var noCoins = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                roundButton("xmark", action: close)
                VStack(alignment: .leading, spacing: 2) {
                    Text(play.title).font(rnd(17, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                    Text(play.subtitle).font(rnd(11.5, .medium)).foregroundStyle(ST.tx3).lineLimit(1)
                }
                Spacer(minLength: 4)
                if play.phase == .aim && play.req.mode != .perfect {
                    Button {
                        if play.useHint() { Haptic.tap() } else { noCoins = true; Haptic.bad() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: play.hinted ? "pause.fill" : "lightbulb.fill").font(.system(size: 13, weight: .bold))
                            Text(play.hinted ? "الزمن واقف" : "تلميح ٤٠").font(rnd(12, .heavy))
                        }
                        .foregroundStyle(play.hinted ? ST.gold : Color.white)
                        .padding(.horizontal, 10).frame(height: 38)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(Press())
                    .disabled(play.hinted)
                }
                roundButton("arrow.counterclockwise", action: restart)
            }
            GoalBar(net: play.net, target: play.level.target, t2: play.level.t2, t3: play.level.t3,
                    total: play.level.goodTotal, perfect: play.req.mode == .perfect)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .alert("الكوينز ما تكفي", isPresented: $noCoins) {
            Button("تمام", role: .cancel) {}
        } message: {
            Text("التلميح يكلّف ٤٠ كوين. اجمع كوينز من المراحل والتحدّيات.")
        }
    }

    private func roundButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptic.tap(); action() }) {
            Image(systemName: icon).font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.1)))
        }
        .buttonStyle(Press())
    }
}

/// شريط الهدف مع علامات النجوم
struct GoalBar: View {
    let net: Int
    let target: Int
    let t2: Int
    let t3: Int
    let total: Int
    let perfect: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(net >= target ? "وصلت الهدف!" : "الهدف").font(rnd(12, .heavy)).foregroundStyle(net >= target ? ST.lime : ST.tx2)
                Spacer()
                HStack(spacing: 2) {
                    Text("\(max(0, net))").font(rnd(17, .black)).foregroundStyle(Color.white)
                    Text("/ \(target)").font(rnd(13, .heavy)).foregroundStyle(ST.tx3)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            GeometryReader { geo in
                let w = geo.size.width
                let maxV = Double(max(total, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(net >= target ? AnyShapeStyle(ST.hot) : AnyShapeStyle(ST.cool))
                        .frame(width: max(8, w * CGFloat(min(1, Double(max(0, net)) / maxV))))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: net)
                    marker(w * CGFloat(Double(target) / maxV), lit: net >= target)
                    if !perfect {
                        marker(w * CGFloat(Double(t2) / maxV), lit: net >= t2)
                        marker(w * CGFloat(Double(t3) / maxV), lit: net >= t3)
                    }
                }
            }
            .frame(height: 10)
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .card(Color.black.opacity(0.35), 18)
    }

    private func marker(_ x: CGFloat, lit: Bool) -> some View {
        Image(systemName: "star.fill")
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(lit ? ST.gold : Color.white.opacity(0.35))
            .shadow(color: lit ? ST.gold.opacity(0.8) : .clear, radius: 5)
            .offset(x: x - 6)
    }
}

struct KindCount: Identifiable {
    let kind: OrbKind
    let n: Int
    var id: Int { kind.rawValue }
}

struct GameBottomBar: View {
    @ObservedObject var play: Play

    private var present: [KindCount] {
        var out: [KindCount] = []
        for k in OrbKind.allCases {
            let n = play.level.world.orbs.reduce(0) { $0 + ($1.kind == k ? 1 : 0) }
            if n > 0 && k != .normal { out.append(KindCount(kind: k, n: n)) }
        }
        return out
    }

    var body: some View {
        VStack(spacing: 8) {
            if play.phase == .aim {
                if !present.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(present) { item in
                            HStack(spacing: 3) {
                                OrbIcon(kind: item.kind, size: 22, live: false)
                                Text("\(item.n)").font(rnd(11.5, .heavy)).foregroundStyle(ST.tx2)
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(ST.spark)
                    Text(play.hinted ? "الزمن واقف — اضغط على الدائرة الذهبيّة" : "عندك شرارة وحدة — دوس وصوّب، وفلّت حتى تنفجر")
                        .font(rnd(12.5, .heavy)).foregroundStyle(Color.white)
                }
                .padding(.horizontal, 14).frame(height: 38)
                .background(Color.black.opacity(0.4), in: Capsule())
                .overlay(Capsule().stroke(ST.spark.opacity(0.35)))
            } else if play.phase == .running {
                Text("تفرّج على السلسلة…").font(rnd(12.5, .heavy)).foregroundStyle(ST.tx3).frame(height: 38)
            }
        }
        .padding(.bottom, 10)
        .allowsHitTesting(false)
    }
}

// MARK: النتيجة

struct ResultOverlay: View {
    @ObservedObject var play: Play
    let v: Verdict
    let primary: (String, () -> Void)?
    let retry: () -> Void
    let close: () -> Void
    @State private var shown = 0
    @State private var appear = false

    private var mode: Mode { play.req.mode }

    private var title: String {
        switch mode {
        case .campaign, .daily:
            if !v.passed { return "قرّبت!" }
            return v.stars >= 3 ? "ضربة خرافيّة!" : (v.stars == 2 ? "حلوة!" : "عبرت!")
        case .endless: return v.passed ? "الجولة \(play.req.index + 1) خلصت" : "انتهت الرحلة"
        case .perfect: return v.passed ? "ضربة كاملة!" : "مو كاملة بعد"
        }
    }

    private var line: String {
        let o = v.outcome
        switch mode {
        case .endless:
            if v.passed { return "فجّرت \(o.net) من \(play.level.target) · المجموع \(v.total)" }
            return "وصلت للجولة \(play.req.index + 1) · المجموع \(v.total)"
        case .perfect:
            return "فجّرت \(o.net) — المطلوب \(play.level.target)"
        case .campaign, .daily:
            return v.passed ? "فجّرت \(o.net) من \(play.level.goodTotal)" : "فجّرت \(o.net) — تحتاج \(play.level.target)"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 16) {
                if v.newBest && v.passed {
                    Text("رقم قياسيّ جديد").font(rnd(12, .heavy)).foregroundStyle(Color.black)
                        .padding(.horizontal, 12).padding(.vertical, 5).background(ST.gold, in: Capsule())
                }
                Text(title).font(rnd(38, .black)).foregroundStyle(v.passed ? AnyShapeStyle(ST.hot) : AnyShapeStyle(Color.white))
                    .multilineTextAlignment(.center)
                if mode != .endless { starsRow }
                Text(line).font(rnd(14.5, .heavy)).foregroundStyle(ST.tx2).multilineTextAlignment(.center)
                statsGrid
                if v.coins > 0 {
                    HStack(spacing: 6) {
                        CoinView(size: 18)
                        Text("+\(v.coins)").font(rnd(18, .black)).foregroundStyle(ST.gold)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
                buttons
            }
            .padding(22)
            .frame(maxWidth: 360)
            .card(ST.s1.opacity(0.96), 30, stroke: Color.white.opacity(0.1))
            .shadow(color: (v.passed ? ST.spark : ST.violet).opacity(0.35), radius: 40)
            .padding(.horizontal, 20)
            .scaleEffect(appear ? 1 : 0.9)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            if Shot.on { shown = 3; appear = true; return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { appear = true }
            for k in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + 0.22 * Double(k)) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { shown = k }
                    if k <= v.stars { Haptic.thud() }
                }
            }
        }
    }

    private var starsRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { k in
                Image(systemName: "star.fill")
                    .font(.system(size: k == 1 ? 54 : 44, weight: .black))
                    .foregroundStyle(k < v.stars ? ST.gold : ST.s3)
                    .shadow(color: k < v.stars ? ST.gold.opacity(0.7) : .clear, radius: 14)
                    .scaleEffect(k < shown ? 1 : 0.2)
                    .opacity(k < shown ? 1 : 0)
                    .offset(y: k == 1 ? -8 : 0)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var statsGrid: some View {
        let o = v.outcome
        return HStack(spacing: 8) {
            statCell("النقاط", "\(o.score)", ST.gold)
            statCell("السلسلة", "\(o.pops)", ST.spark)
            statCell("العمق", "\(o.maxGen)", ST.cyan)
            statCell("مظلمة", "\(o.bad)", o.bad > 0 ? ST.red : ST.tx3)
        }
    }

    private func statCell(_ t: String, _ val: String, _ c: Color) -> some View {
        VStack(spacing: 3) {
            Text(val).font(rnd(19, .black)).foregroundStyle(c)
            Text(t).font(rnd(10.5, .heavy)).foregroundStyle(ST.tx3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .card(Color.white.opacity(0.05), 14)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            if let p = primary {
                Button(action: { Haptic.tap(); p.1() }) {
                    Text(p.0).font(rnd(18, .black)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(ST.hot, in: Capsule())
                        .shadow(color: ST.flame.opacity(0.5), radius: 14, y: 4)
                }
                .buttonStyle(Press())
            }
            HStack(spacing: 10) {
                Button(action: { Haptic.tap(); retry() }) {
                    Label("عيدها", systemImage: "arrow.counterclockwise")
                        .font(rnd(15, .heavy)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(primary == nil ? AnyShapeStyle(ST.hot) : AnyShapeStyle(Color.white.opacity(0.08)), in: Capsule())
                }
                .buttonStyle(Press())
                Button(action: { Haptic.tap(); close() }) {
                    Label("القائمة", systemImage: "square.grid.2x2.fill")
                        .font(rnd(15, .heavy)).foregroundStyle(ST.tx2)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(Press())
            }
        }
        .padding(.top, 4)
    }
}

/// عملة صغيرة
struct CoinView: View {
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.9, blue: 0.45), Color(red: 0.95, green: 0.62, blue: 0.12)], startPoint: .top, endPoint: .bottom))
            Circle().stroke(Color.white.opacity(0.5), lineWidth: size * 0.08).padding(size * 0.14)
            Image(systemName: "bolt.fill").font(.system(size: size * 0.5, weight: .black)).foregroundStyle(Color(red: 0.6, green: 0.32, blue: 0.02))
        }
        .frame(width: size, height: size)
        .shadow(color: ST.gold.opacity(0.5), radius: size * 0.3)
    }
}
