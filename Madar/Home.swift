import SwiftUI

struct Launch: Identifiable {
    let id = UUID()
    let daily: Bool
}

enum HomeSheet: String, Identifiable {
    case shop, missions, stats, settings
    var id: String { rawValue }
}

struct HomeView: View {
    @EnvironmentObject var store: Store
    @AppStorage("md_seen_how") private var seenHow = false
    @State private var launch: Launch? = nil
    @State private var sheet: HomeSheet? = nil
    @State private var how = false

    var body: some View {
        ZStack(alignment: .top) {
            MD.bg.ignoresSafeArea()
            HomeHero(skin: Catalog.comet(store.p.wallet.comet), trail: Catalog.trail(store.p.wallet.trail))
                .frame(height: 380)
                .ignoresSafeArea(edges: .top)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    topBar
                    titleBlock.padding(.top, 150)
                    playButton
                    dailyCard
                    missionsCard
                    menuRow
                    Text("يشتغل بلا إنترنت · تقدّمك ينحفظ على جهازك").font(rnd(11.5)).foregroundStyle(MD.tx3).frame(maxWidth: .infinity).padding(.top, 4)
                }
                .padding(.horizontal, 18).padding(.bottom, 26)
            }
        }
        .fullScreenCover(item: $launch) { l in
            GameView(store: store, daily: l.daily) { launch = nil }
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .sheet(item: $sheet) { s in
            sheetView(s).environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $how, onDismiss: { seenHow = true }) {
            HowView { how = false }
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .onAppear {
            store.refreshDay()
            if Shot.isAny("play", "perfect", "gameover") { launch = Launch(daily: false) }
            else if Shot.name == "skins" { sheet = .shop }
            else if Shot.name == "missions" { sheet = .missions }
            else if Shot.name == "stats" { sheet = .stats }
            else if Shot.name == "how" || (!seenHow && !Shot.on) { how = true }
        }
    }

    @ViewBuilder private func sheetView(_ s: HomeSheet) -> some View {
        switch s {
        case .shop: ShopView()
        case .missions: MissionsView()
        case .stats: StatsView()
        case .settings: SettingsView()
        }
    }

    private var topBar: some View {
        HStack {
            GemChip(gems: store.p.wallet.gems)
            Spacer()
            Button { FX.tap(); sheet = .settings } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.white)
                    .frame(width: 44, height: 44).background(Color.white.opacity(0.1), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12)))
            }.buttonStyle(Press())
        }.padding(.top, 6)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("مدار").font(rnd(58, .black)).foregroundStyle(MD.hero)
                .shadow(color: MD.violet.opacity(0.6), radius: 18)
            Text("اضغط، انطلق، وامسك المدار الجاي").font(rnd(15, .bold)).foregroundStyle(MD.tx2)
            HStack(spacing: 8) {
                Label("\(store.p.best)", systemImage: "trophy.fill").font(rnd(14, .black)).foregroundStyle(MD.gold)
                    .environment(\.layoutDirection, .leftToRight)
                Text("أفضل نتيجة").font(rnd(12.5)).foregroundStyle(MD.tx3)
                Spacer()
                Label("\(store.p.bestPlanets)", systemImage: "arrow.up.circle.fill").font(rnd(14, .black)).foregroundStyle(MD.cyan)
                    .environment(\.layoutDirection, .leftToRight)
                Text("أعلى كوكب").font(rnd(12.5)).foregroundStyle(MD.tx3)
            }.padding(.top, 6)
        }
    }

    private var playButton: some View {
        Button { FX.thud(); Synth.shared.play("click"); launch = Launch(daily: false) } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill").font(.system(size: 24, weight: .black))
                    .frame(width: 58, height: 58).background(Color.white.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("العب").font(rnd(26, .black))
                    Text("كون جديد كلّ جولة").font(rnd(12.5, .semibold)).opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .black)).opacity(0.7)
            }
            .foregroundStyle(Color.white)
            .padding(14)
            .background(MD.hero, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: MD.violet.opacity(0.55), radius: 22, y: 10)
        }.buttonStyle(Press())
    }

    private var dailyCard: some View {
        Button { FX.tap(); launch = Launch(daily: true) } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(MD.goldGrad).frame(width: 54, height: 54)
                    Image(systemName: "calendar").font(.system(size: 22, weight: .black)).foregroundStyle(Color.black.opacity(0.8))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("تحدّي اليوم").font(rnd(18, .black)).foregroundStyle(Color.white)
                    Text("نفس الكون لكلّ اللاعبين — يتغيّر كلّ يوم").font(rnd(12)).foregroundStyle(MD.tx3).lineLimit(1).minimumScaleFactor(0.8)
                    HStack(spacing: 10) {
                        Text("أفضلك اليوم \(store.p.dailyBest)").font(rnd(12.5, .heavy)).foregroundStyle(MD.gold)
                        Text("محاولات \(store.p.dailyRuns)").font(rnd(12.5, .heavy)).foregroundStyle(MD.tx2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .black)).foregroundStyle(MD.tx3)
            }
            .padding(14).card(MD.s1, 24, stroke: MD.gold.opacity(0.3))
        }.buttonStyle(Press())
    }

    private var missionsCard: some View {
        Button { FX.tap(); sheet = .missions } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Image(systemName: "target").foregroundStyle(MD.magenta)
                    Text("مهمّات اليوم").font(rnd(17, .black)).foregroundStyle(Color.white)
                    Spacer()
                    Text("\(store.p.missionsDone.count)/3").font(rnd(14, .black)).foregroundStyle(MD.tx2).environment(\.layoutDirection, .leftToRight)
                }
                let ms = store.p.missions
                ForEach(0..<ms.count, id: \.self) { i in
                    MissionRow(m: ms[i], progress: i < store.p.bestProgress.count ? store.p.bestProgress[i] : 0, done: store.p.missionsDone.contains(i), compact: true)
                }
            }
            .padding(14).card(MD.s1, 24, stroke: MD.magenta.opacity(0.25))
        }.buttonStyle(Press())
    }

    private var menuRow: some View {
        HStack(spacing: 10) {
            menuTile("المتجر", "sparkles", MD.cyan) { sheet = .shop }
            menuTile("إحصائيّاتي", "chart.bar.fill", MD.green) { sheet = .stats }
            menuTile("طريقة اللعب", "questionmark.circle.fill", MD.violet) { how = true }
        }
    }

    private func menuTile(_ t: String, _ icon: String, _ c: Color, _ act: @escaping () -> Void) -> some View {
        Button { FX.tap(); act() } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(c)
                Text(t).font(rnd(13, .heavy)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).frame(height: 86)
            .card(MD.s1, 20, stroke: c.opacity(0.25))
        }.buttonStyle(Press())
    }
}

struct GemChip: View {
    let gems: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "diamond.fill").font(.system(size: 13, weight: .black)).foregroundStyle(MD.gold)
            Text("\(gems)").font(rnd(17, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 14).frame(height: 44)
        .background(Color.white.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(MD.gold.opacity(0.3)))
    }
}

struct MissionRow: View {
    let m: Mission
    let progress: Int
    let done: Bool
    var compact = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.seal.fill" : m.icon).font(.system(size: compact ? 15 : 19, weight: .bold))
                .foregroundStyle(done ? MD.green : MD.cyan)
                .frame(width: compact ? 28 : 44, height: compact ? 28 : 44)
                .background(MD.s2, in: RoundedRectangle(cornerRadius: compact ? 9 : 13, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(m.title).strikethrough(done, color: MD.tx3).font(rnd(compact ? 13 : 15, .bold)).foregroundStyle(done ? MD.tx3 : Color.white).lineLimit(2)
                GeometryReader { g in
                    let f = CGFloat(min(1, Double(done ? m.target : progress) / Double(max(1, m.target))))
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(done ? AnyShapeStyle(MD.green) : AnyShapeStyle(MD.hero)).frame(width: max(6, g.size.width * f))
                    }
                }
                .frame(height: 6)
                .environment(\.layoutDirection, .rightToLeft)
            }
            Text("+\(m.reward)").font(rnd(compact ? 12.5 : 14, .black)).foregroundStyle(MD.gold)
                .environment(\.layoutDirection, .leftToRight)
            Image(systemName: "diamond.fill").font(.system(size: 9, weight: .black)).foregroundStyle(MD.gold)
        }
    }
}

/// المشهد المتحرّك أعلى الشاشة الرئيسيّة: كوكب ومذنّب يدور
struct HomeHero: View {
    let skin: CometSkin
    let trail: TrailSkin
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = Shot.on ? 3.1 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
                HomeHero.paint(&ctx, size, t, skin, trail)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(false)
    }

    static func paint(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double, _ skin: CometSkin, _ trail: TrailSkin) {
        let W = size.width, H = size.height
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .linearGradient(Gradient(colors: [Color(red: 0.05, green: 0.04, blue: 0.16), MD.bg]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: H)))
        let nc = CGPoint(x: W * 0.2, y: H * 0.35)
        ctx.fill(circlePath(nc, W * 0.6), with: .radialGradient(Gradient(colors: [MD.magenta.opacity(0.16), Color.clear]), center: nc, startRadius: 0, endRadius: W * 0.6))
        let nc2 = CGPoint(x: W * 0.9, y: H * 0.2)
        ctx.fill(circlePath(nc2, W * 0.5), with: .radialGradient(Gradient(colors: [MD.cyan.opacity(0.14), Color.clear]), center: nc2, startRadius: 0, endRadius: W * 0.5))
        var r = MRng(seed: 31)
        for _ in 0..<80 {
            let x = CGFloat(r.unit()) * W, y = CGFloat(r.unit()) * H
            let s = CGFloat(r.range(0.5, 1.8))
            let tw = 0.3 + 0.7 * abs(sin(t * r.range(0.5, 1.6) + r.range(0, 6)))
            ctx.fill(circlePath(CGPoint(x: x, y: y), s), with: .color(Color.white.opacity(tw * 0.8)))
        }
        // كوكب بعيد
        let p2 = CGPoint(x: W * 0.2, y: H * 0.2)
        ctx.stroke(circlePath(p2, 34), with: .color(Color.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1.2, dash: [4, 6], dashPhase: CGFloat(-t * 10)))
        ctx.fill(circlePath(p2, 12), with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.7), Color(red: 0.9, green: 0.4, blue: 0.3), Color(red: 0.3, green: 0.08, blue: 0.1)]), center: CGPoint(x: p2.x - 4, y: p2.y - 4), startRadius: 0, endRadius: 18))
        // الكوكب الرئيسيّ
        let c = CGPoint(x: W * 0.66, y: H * 0.42)
        let R: CGFloat = min(W, H) * 0.27
        let body = R * 0.42
        ctx.fill(circlePath(c, R * 1.25), with: .radialGradient(Gradient(stops: [.init(color: Color.clear, location: 0.7), .init(color: MD.cyan.opacity(0.10), location: 0.85), .init(color: Color.clear, location: 1)]), center: c, startRadius: 0, endRadius: R * 1.25))
        ctx.stroke(circlePath(c, R), with: .color(MD.cyan.opacity(0.55)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 7], dashPhase: CGFloat(t * 16)))
        ctx.fill(circlePath(c, body * 2.6), with: .radialGradient(Gradient(colors: [MD.violet.opacity(0.45), Color.clear]), center: c, startRadius: body * 0.5, endRadius: body * 2.6))
        ctx.fill(circlePath(c, body), with: .radialGradient(Gradient(colors: [Color(red: 0.8, green: 0.85, blue: 1), Color(red: 0.45, green: 0.35, blue: 0.95), Color(red: 0.1, green: 0.05, blue: 0.3)]), center: CGPoint(x: c.x - body * 0.35, y: c.y - body * 0.4), startRadius: 0, endRadius: body * 1.55))
        var e = Path(ellipseIn: CGRect(x: -body * 1.8, y: -body * 0.42, width: body * 3.6, height: body * 0.84))
        e = e.applying(CGAffineTransform(rotationAngle: CGFloat(-0.35)).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
        ctx.stroke(e, with: .color(Color(red: 0.85, green: 0.85, blue: 1).opacity(0.6)), lineWidth: 3)
        // قمر
        let ma = t * 0.7
        let mp = CGPoint(x: c.x + CGFloat(cos(ma)) * R * 1.45, y: c.y + CGFloat(sin(ma)) * R * 1.45)
        ctx.fill(circlePath(mp, 6), with: .radialGradient(Gradient(colors: [Color(white: 0.95), Color(white: 0.35)]), center: CGPoint(x: mp.x - 2, y: mp.y - 2), startRadius: 0, endRadius: 8))
        // المذنّب وذيله
        let w = 1.9
        let cs = trail.colors
        for i in 0..<26 {
            let a0 = -t * w + Double(i) * 0.06
            let a1 = a0 + 0.06
            var seg = Path()
            seg.move(to: CGPoint(x: c.x + CGFloat(cos(a0)) * R, y: c.y + CGFloat(sin(a0)) * R))
            seg.addLine(to: CGPoint(x: c.x + CGFloat(cos(a1)) * R, y: c.y + CGFloat(sin(a1)) * R))
            let f = 1 - Double(i) / 26
            ctx.stroke(seg, with: .color(col(cs[(i / 6) % max(1, cs.count)], f * 0.9)), style: StrokeStyle(lineWidth: CGFloat(7 * f + 0.5), lineCap: .round))
        }
        let ca = -t * w
        let cp = CGPoint(x: c.x + CGFloat(cos(ca)) * R, y: c.y + CGFloat(sin(ca)) * R)
        drawComet(&ctx, skin, at: cp, r: 7, rot: t * 2)
        // تلاشي للأسفل
        ctx.fill(Path(CGRect(x: 0, y: H * 0.6, width: W, height: H * 0.4)), with: .linearGradient(Gradient(colors: [MD.bg.opacity(0), MD.bg]), startPoint: CGPoint(x: 0, y: H * 0.6), endPoint: CGPoint(x: 0, y: H)))
    }
}
