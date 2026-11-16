import SwiftUI

struct ShopView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0
    @State private var note: String? = nil
    @State private var shakeId: String? = nil

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                PreviewStage(skin: Catalog.comet(store.p.wallet.comet), trail: Catalog.trail(store.p.wallet.trail))
                    .frame(height: 150)
                    .card(MD.s1, 24, stroke: MD.cyan.opacity(0.22))
                tabs
                if let n = note {
                    Text(n).font(rnd(13, .bold)).foregroundStyle(MD.gold).frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
                LazyVGrid(columns: cols, spacing: 10) {
                    if tab == 0 {
                        ForEach(Catalog.comets, id: \.id) { c in cometCard(c) }
                    } else {
                        ForEach(Catalog.trails, id: \.id) { t in trailCard(t) }
                    }
                }
                Text("الجواهر تجمعها بالطيران وبالمهمّات اليوميّة. كلّ شي بالمتجر بالجواهر بس — ماكو شراء بفلوس.")
                    .font(rnd(12)).foregroundStyle(MD.tx3).frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 4)
            }
            .padding(18)
        }
        .background(MD.bg.ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: note)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("المتجر").font(rnd(30, .black)).foregroundStyle(Color.white)
                Text("مذنّبات وذيول تخلّي طيرانك على كيفك").font(rnd(13)).foregroundStyle(MD.tx3)
            }
            Spacer()
            GemChip(gems: store.p.wallet.gems)
        }.padding(.top, 8)
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            tabChip("المذنّبات", 0, "sparkle")
            tabChip("الذيول", 1, "wind")
        }
    }

    private func tabChip(_ t: String, _ i: Int, _ icon: String) -> some View {
        Button { FX.tap(); tab = i } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(t).font(rnd(15, .heavy))
            }
            .foregroundStyle(tab == i ? Color.black.opacity(0.85) : Color.white)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(tab == i ? AnyShapeStyle(MD.hero) : AnyShapeStyle(MD.s2), in: Capsule())
        }.buttonStyle(Press())
    }

    private func act(_ id: String, _ price: Int) {
        let w = store.p.wallet
        if w.comet == id || w.trail == id { return }
        if w.has(id) {
            store.equip(id)
            Synth.shared.play("click")
            FX.tap()
            note = nil
            return
        }
        switch store.buy(id) {
        case .bought:
            Synth.shared.play("buy")
            FX.ok()
            note = "صار عندك! ولبسته هسّه"
        case .poor:
            FX.bad()
            note = "تحتاج \(price - w.gems) جوهرة بعد"
            withAnimation(.default) { shakeId = id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeId = nil }
        case .owned, .unknown:
            break
        }
    }

    private func cometCard(_ c: CometSkin) -> some View {
        let w = store.p.wallet
        return Button { act(c.id, c.price) } label: {
            VStack(spacing: 6) {
                Canvas { ctx, size in
                    drawComet(&ctx, c, at: CGPoint(x: size.width / 2, y: size.height / 2), r: 11, rot: 0.3)
                }
                .frame(height: 70)
                .environment(\.layoutDirection, .leftToRight)
                Text(c.name).font(rnd(13, .heavy)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.7)
                PriceTag(price: c.price, owned: w.has(c.id), equipped: w.comet == c.id, poor: w.gems < c.price)
            }
            .padding(10).frame(maxWidth: .infinity)
            .card(w.comet == c.id ? MD.s2 : MD.s1, 18, stroke: w.comet == c.id ? MD.cyan.opacity(0.7) : Color.white.opacity(0.06))
            .offset(x: shakeId == c.id ? 6 : 0)
        }.buttonStyle(Press())
    }

    private func trailCard(_ t: TrailSkin) -> some View {
        let w = store.p.wallet
        return Button { act(t.id, t.price) } label: {
            VStack(spacing: 6) {
                Canvas { ctx, size in
                    TrailSwatch.paint(&ctx, size, t)
                }
                .frame(height: 70)
                .environment(\.layoutDirection, .leftToRight)
                Text(t.name).font(rnd(13, .heavy)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.7)
                PriceTag(price: t.price, owned: w.has(t.id), equipped: w.trail == t.id, poor: w.gems < t.price)
            }
            .padding(10).frame(maxWidth: .infinity)
            .card(w.trail == t.id ? MD.s2 : MD.s1, 18, stroke: w.trail == t.id ? MD.cyan.opacity(0.7) : Color.white.opacity(0.06))
            .offset(x: shakeId == t.id ? 6 : 0)
        }.buttonStyle(Press())
    }
}

enum TrailSwatch {
    static func paint(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: TrailSkin) {
        let n = 30
        let cs = t.colors
        for i in 1..<n {
            let f0 = Double(i - 1) / Double(n), f1 = Double(i) / Double(n)
            let p0 = CGPoint(x: size.width * CGFloat(0.1 + 0.8 * f0), y: size.height / 2 + CGFloat(sin(f0 * 6)) * 12)
            let p1 = CGPoint(x: size.width * CGFloat(0.1 + 0.8 * f1), y: size.height / 2 + CGFloat(sin(f1 * 6)) * 12)
            var seg = Path()
            seg.move(to: p0)
            seg.addLine(to: p1)
            let ci = (i / 6) % max(1, cs.count)
            ctx.stroke(seg, with: .color(col(cs[ci], 0.3 + 0.7 * f1)), style: StrokeStyle(lineWidth: CGFloat(2 + 7 * f1), lineCap: .round))
        }
        if t.sparkle {
            for k in 0..<6 {
                let x = size.width * CGFloat(0.15 + 0.12 * Double(k))
                let y = size.height / 2 + CGFloat(k % 2 == 0 ? -14 : 13)
                ctx.fill(starPath(CGPoint(x: x, y: y), 3, points: 4, inner: 0.3, rot: 0), with: .color(Color.white.opacity(0.85)))
            }
        }
        let end = CGPoint(x: size.width * 0.9, y: size.height / 2 + CGFloat(sin(6.0)) * 12)
        ctx.fill(circlePath(end, 6), with: .color(Color.white))
    }
}

struct PriceTag: View {
    let price: Int
    let owned: Bool
    let equipped: Bool
    let poor: Bool
    var body: some View {
        Group {
            if equipped {
                Label("لابسه", systemImage: "checkmark.circle.fill").foregroundStyle(MD.cyan)
            } else if owned {
                Text("البس").foregroundStyle(Color.white)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "diamond.fill").font(.system(size: 9, weight: .black))
                    Text("\(price)").environment(\.layoutDirection, .leftToRight)
                }.foregroundStyle(poor ? MD.tx3 : MD.gold)
            }
        }
        .font(rnd(12.5, .black))
        .frame(maxWidth: .infinity).frame(height: 28)
        .background(Color.white.opacity(equipped ? 0.06 : 0.1), in: Capsule())
    }
}

/// معاينة المذنّب والذيل المختارين وهم يدورون
struct PreviewStage: View {
    let skin: CometSkin
    let trail: TrailSkin
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = Shot.on ? 2.2 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let R: CGFloat = 48
                ctx.stroke(circlePath(c, R), with: .color(Color.white.opacity(0.22)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 6], dashPhase: CGFloat(t * 14)))
                ctx.fill(circlePath(c, 20), with: .radialGradient(Gradient(colors: [Color(red: 0.9, green: 0.95, blue: 1), Color(red: 0.3, green: 0.5, blue: 1), Color(red: 0.05, green: 0.08, blue: 0.3)]), center: CGPoint(x: c.x - 6, y: c.y - 7), startRadius: 0, endRadius: 30))
                let cs = trail.colors
                for i in 0..<30 {
                    let a0 = -t * 2 + Double(i) * 0.07
                    let a1 = a0 + 0.07
                    var seg = Path()
                    seg.move(to: CGPoint(x: c.x + CGFloat(cos(a0)) * R, y: c.y + CGFloat(sin(a0)) * R))
                    seg.addLine(to: CGPoint(x: c.x + CGFloat(cos(a1)) * R, y: c.y + CGFloat(sin(a1)) * R))
                    let f = 1 - Double(i) / 30
                    ctx.stroke(seg, with: .color(col(cs[(i / 6) % max(1, cs.count)], f)), style: StrokeStyle(lineWidth: CGFloat(8 * f + 0.5), lineCap: .round))
                }
                let ca = -t * 2
                drawComet(&ctx, skin, at: CGPoint(x: c.x + CGFloat(cos(ca)) * R, y: c.y + CGFloat(sin(ca)) * R), r: 8, rot: t * 2)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}
