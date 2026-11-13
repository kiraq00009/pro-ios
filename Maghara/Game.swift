import SwiftUI

struct Glyph: Identifiable {
    let id: String
    let text: String
    let pos: Int
    var scale: CGFloat = 0.66
    var dim = false
    var hp: Double? = nil
    var badge = ""
}

struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(animatableData * .pi * 4), y: 0))
    }
}

struct PopView: View {
    let pop: Pop
    let cell: CGFloat
    @State private var up = false
    var body: some View {
        let c: Color = pop.tone == 1 ? MG.red : (pop.tone == 2 ? MG.green : (pop.tone == 3 ? MG.gold : Color.white))
        Text(pop.text).font(rnd(max(11, cell * 0.36), .black)).foregroundStyle(c)
            .shadow(color: Color.black, radius: 2).shadow(color: Color.black, radius: 1)
            .fixedSize()
            .offset(y: up ? -cell * 1.05 : -cell * 0.45)
            .opacity(up && !Shot.on ? 0 : 1)
            .onAppear {
                if Shot.on { return }
                withAnimation(.easeOut(duration: 0.8)) { up = true }
            }
    }
}

struct GridView: View {
    @ObservedObject var run: Run

    var body: some View {
        GeometryReader { g in
            let cell = min(g.size.width / CGFloat(Cave.W), g.size.height / CGFloat(Cave.H)).rounded(.down)
            let w = cell * CGFloat(Cave.W), h = cell * CGFloat(Cave.H)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in drawTiles(ctx, cell) }
                Circle().fill(RadialGradient(colors: [MG.torch.opacity(0.28), Color.clear], center: .center, startRadius: 0, endRadius: cell * 3.4))
                    .frame(width: cell * 6.8, height: cell * 6.8)
                    .position(center(run.cave.hero.pos, cell)).blendMode(.plusLighter).allowsHitTesting(false)
                ForEach(glyphs()) { gl in
                    glyphView(gl, cell).position(center(gl.pos, cell))
                }
                ForEach(run.pops) { p in
                    PopView(pop: p, cell: cell).position(center(p.at, cell)).allowsHitTesting(false)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { v in handle(v, cell) })
            .modifier(Shake(animatableData: CGFloat(run.shake)))
            .animation(.linear(duration: 0.28), value: run.shake)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func center(_ p: Int, _ cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(p % Cave.W) + 0.5) * cell, y: (CGFloat(p / Cave.W) + 0.5) * cell)
    }

    private func handle(_ v: DragGesture.Value, _ cell: CGFloat) {
        let dx = v.translation.width, dy = v.translation.height
        if abs(dx) < 14 && abs(dy) < 14 {
            let x = Int(v.startLocation.x / cell), y = Int(v.startLocation.y / cell)
            guard x >= 0, y >= 0, x < Cave.W, y < Cave.H else { return }
            run.tap(y * Cave.W + x)
        } else if abs(dx) > abs(dy) {
            run.swipe(dx > 0 ? 0 : 2)
        } else {
            run.swipe(dy > 0 ? 1 : 3)
        }
    }

    private func glyphs() -> [Glyph] {
        let c = run.cave
        var out: [Glyph] = []
        for p in 0..<c.tiles.count where c.seen[p] {
            let dim = !c.lit[p]
            switch c.tiles[p] {
            case .exit:
                let locked = c.floor % 4 == 0 && c.bossAlive
                out.append(Glyph(id: "t\(p)", text: locked ? "🔒" : "🚪", pos: p, scale: 0.7, dim: dim))
            case .trap: out.append(Glyph(id: "t\(p)", text: "🔺", pos: p, scale: 0.42, dim: dim))
            case .shop: out.append(Glyph(id: "t\(p)", text: "🧞", pos: p, scale: 0.7, dim: dim))
            case .shrine: out.append(Glyph(id: "t\(p)", text: "⛩️", pos: p, scale: 0.7, dim: dim))
            default: break
            }
            if let it = c.items[p] { out.append(Glyph(id: "i\(p)", text: GridView.itemGlyph(it), pos: p, scale: 0.52, dim: dim)) }
        }
        for m in c.mons where c.lit[m.pos] {
            let k = Bestiary.all[m.kind]
            out.append(Glyph(id: "m\(m.id)", text: k.glyph, pos: m.pos, scale: k.boss ? 0.92 : 0.7, hp: m.hp < m.maxHp || k.boss ? Double(m.hp) / Double(max(1, m.maxHp)) : nil, badge: m.awake ? "" : "💤"))
        }
        out.append(Glyph(id: "hero", text: c.over && !c.won ? "🪦" : MG.hero, pos: c.hero.pos, scale: 0.78))
        return out
    }

    static func itemGlyph(_ it: Item) -> String {
        switch it {
        case .potion: return "🧪"
        case .bomb: return "💣"
        case .gold: return "🪙"
        case .sword: return "🗡️"
        case .shield: return "🛡️"
        case .heart: return "❤️"
        case .chest: return "🎁"
        }
    }

    private func glyphView(_ gl: Glyph, _ cell: CGFloat) -> some View {
        ZStack {
            Text(gl.text).font(.system(size: cell * gl.scale)).opacity(gl.dim ? 0.4 : 1)
            if let f = gl.hp {
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.7)).frame(width: cell * 0.8, height: 4.5)
                    Capsule().fill(f > 0.5 ? MG.green : (f > 0.25 ? MG.gold : MG.red)).frame(width: max(2, cell * 0.8 * CGFloat(f)), height: 4.5)
                }.offset(y: cell * 0.44)
            }
            if !gl.badge.isEmpty { Text(gl.badge).font(.system(size: cell * 0.3)).offset(x: cell * 0.3, y: -cell * 0.3) }
        }
        .frame(width: cell, height: cell)
        .allowsHitTesting(false)
    }

    private func drawTiles(_ ctx: GraphicsContext, _ cell: CGFloat) {
        let c = run.cave
        for p in 0..<c.tiles.count where c.seen[p] {
            let x = CGFloat(p % Cave.W) * cell, y = CGFloat(p / Cave.W) * cell
            let r = CGRect(x: x, y: y, width: cell, height: cell)
            if c.tiles[p] == .wall {
                ctx.fill(Path(r), with: .color(MG.wall))
                ctx.fill(Path(roundedRect: CGRect(x: x + 1.5, y: y + 1.5, width: cell - 3, height: cell * 0.34), cornerRadius: 4), with: .color(MG.wallTop))
            } else {
                let even = (p % Cave.W + p / Cave.W) % 2 == 0
                ctx.fill(Path(r), with: .color(Color.black))
                ctx.fill(Path(roundedRect: r.insetBy(dx: 1, dy: 1), cornerRadius: 5), with: .color(even ? MG.floorA : MG.floorB))
            }
            if !c.lit[p] { ctx.fill(Path(r), with: .color(Color.black.opacity(0.58))) }
        }
    }
}

struct GameView: View {
    @EnvironmentObject var run: Run
    let close: () -> Void
    private var c: Cave { run.cave }

    var body: some View {
        VStack(spacing: 8) {
            top
            bars
            GridView(run: run)
            Text(c.log.last ?? "اضغط خانة حتى تمشي إلها").font(rnd(13, .bold)).foregroundStyle(MG.tx2).lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).frame(height: 20)
            actions
        }
        .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 8)
        .background(Backdrop())
        .overlay { overlays }
    }

    @ViewBuilder private var overlays: some View {
        if c.over { endCard }
        else if !c.perks.isEmpty { perkCard }
        else if c.atShop { shopCard }
        else if c.atShrine { shrineCard }
    }

    private var top: some View {
        HStack(spacing: 8) {
            Button { run.stop(); close() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(Color.white).frame(width: 38, height: 38).background(MG.s2, in: Circle()) }.buttonStyle(Press())
            VStack(alignment: .leading, spacing: 0) {
                Text("الطابق \(c.floor)").font(rnd(18, .black)).foregroundStyle(Color.white)
                Text(c.floor % 4 == 0 ? "طابق الزعيم" : "من \(Cave.lastFloor)").font(rnd(10.5, .bold)).foregroundStyle(c.floor % 4 == 0 ? MG.red : MG.tx3)
            }
            Spacer(minLength: 4)
            chip("⚔️", "\(c.hero.atk)")
            chip("🛡️", "\(c.hero.def)")
            chip("🪙", "\(c.hero.gold)")
            chip("⭐️", "\(c.hero.level)")
        }
    }
    private func chip(_ g: String, _ v: String) -> some View {
        HStack(spacing: 3) {
            Text(g).font(.system(size: 12))
            Text(v).font(rnd(14, .black)).foregroundStyle(Color.white)
        }.padding(.horizontal, 8).frame(height: 32).background(MG.s2, in: Capsule()).environment(\.layoutDirection, .leftToRight)
    }

    private var bars: some View {
        let hpF = CGFloat(max(0, c.hero.hp)) / CGFloat(max(1, c.hero.maxHp))
        let xpF = CGFloat(c.hero.xp) / CGFloat(max(1, c.need))
        let hpColor = c.hero.poison > 0 ? MG.violet : (hpF > 0.4 ? MG.red : Color(red: 1, green: 0.5, blue: 0.2))
        return VStack(spacing: 4) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(MG.s2)
                    Capsule().fill(hpColor).frame(width: max(8, g.size.width * hpF))
                    HStack {
                        Text("❤️ \(max(0, c.hero.hp)) / \(c.hero.maxHp)").font(rnd(12, .black)).foregroundStyle(Color.white)
                        Spacer()
                        if c.hero.poison > 0 { Text("مسموم ☠️").font(rnd(11, .heavy)).foregroundStyle(Color.white) }
                    }.padding(.horizontal, 10)
                }
            }.frame(height: 22)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(MG.s2)
                    Capsule().fill(MG.gold).frame(width: max(4, g.size.width * xpF))
                }
            }.frame(height: 5)
        }
        .environment(\.layoutDirection, .leftToRight)
        .animation(.easeOut(duration: 0.25), value: c.hero.hp)
    }

    private var actions: some View {
        HStack(spacing: 9) {
            act("🧪", "دوا", c.hero.potions, c.hero.potions > 0 && c.hero.hp < c.hero.maxHp) { run.drink() }
            act("💣", "قنبلة", c.hero.bombs, c.hero.bombs > 0) { run.bomb() }
            act("⏳", "انتظر", -1, true) { run.rest() }
        }
    }
    private func act(_ g: String, _ t: String, _ n: Int, _ on: Bool, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            HStack(spacing: 7) {
                Text(g).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 0) {
                    Text(t).font(rnd(14, .heavy)).foregroundStyle(Color.white)
                    if n >= 0 { Text("×\(n)").font(rnd(12, .black)).foregroundStyle(MG.torch).environment(\.layoutDirection, .leftToRight) }
                }
            }.frame(maxWidth: .infinity).frame(height: 54).card(MG.s1, 17, stroke: MG.torch.opacity(on ? 0.35 : 0.08))
        }.buttonStyle(Press()).opacity(on ? 1 : 0.45)
    }

    // MARK: النوافذ

    private func panel<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        ZStack {
            Color.black.opacity(0.66).ignoresSafeArea()
            VStack(spacing: 13) { content() }
                .padding(20).card(MG.s1, 28, stroke: MG.torch.opacity(0.3)).padding(.horizontal, 22)
        }.transition(.opacity)
    }

    private var perkCard: some View {
        panel {
            Text("⭐️ المستوى \(c.hero.level)").font(rnd(24, .black)).foregroundStyle(MG.gold)
            Text("اختار ترقية وحدة").font(rnd(13, .bold)).foregroundStyle(MG.tx3)
            ForEach(c.perks, id: \.self) { k in
                Button { run.choose(k) } label: {
                    HStack(spacing: 13) {
                        Image(systemName: Perk.all[k].icon).font(.system(size: 19, weight: .black)).foregroundStyle(MG.torch).frame(width: 50, height: 50).background(MG.s2, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Perk.all[k].name).font(rnd(17, .heavy)).foregroundStyle(Color.white)
                            Text(Perk.all[k].text).font(rnd(12.5)).foregroundStyle(MG.tx2)
                        }
                        Spacer(minLength: 0)
                        if c.hero.perks[k] > 0 { Text("×\(c.hero.perks[k])").font(rnd(12, .black)).foregroundStyle(MG.tx3) }
                    }.padding(10).card(MG.bg, 18, stroke: MG.torch.opacity(0.25))
                }.buttonStyle(Press())
            }
        }
    }

    private var shopCard: some View {
        let names = ["دوا", "قنبلة", "سيف أمضى", "درع أثخن", "قلب"]
        let notes = ["يرجّع نصّ صحّتك", "تضرب كلّ القريبين", "+1 هجوم دائم", "+1 دفاع دائم", "+5 صحّة قصوى"]
        let glyphs = ["🧪", "💣", "🗡️", "🛡️", "❤️"]
        return panel {
            HStack {
                Text("🧞 دكّان الجنّي").font(rnd(22, .black)).foregroundStyle(Color.white)
                Spacer()
                Text("🪙 \(c.hero.gold)").font(rnd(16, .black)).foregroundStyle(MG.gold).environment(\.layoutDirection, .leftToRight)
            }
            ForEach(0..<5, id: \.self) { i in
                let can = c.hero.gold >= c.price(i)
                HStack(spacing: 11) {
                    Text(glyphs[i]).font(.system(size: 24)).frame(width: 44, height: 44).background(MG.s2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(names[i]).font(rnd(15.5, .heavy)).foregroundStyle(Color.white)
                        Text(notes[i]).font(rnd(11.5)).foregroundStyle(MG.tx3)
                    }
                    Spacer(minLength: 0)
                    Button { run.buy(i) } label: {
                        Text("\(c.price(i)) 🪙").font(rnd(14, .black)).foregroundStyle(can ? Color.black.opacity(0.82) : MG.tx3)
                            .frame(width: 78, height: 38).background(can ? MG.gold : MG.s2, in: Capsule()).environment(\.layoutDirection, .leftToRight)
                    }.buttonStyle(Press()).disabled(!can)
                }
            }
            Button { run.leave() } label: { Text("خلّصت التسوّق").font(rnd(16, .black)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 48).background(MG.s2, in: Capsule()) }.buttonStyle(Press()).padding(.top, 2)
        }
    }

    private var shrineCard: some View {
        let cost = max(1, c.hero.maxHp / 4)
        return panel {
            Text("⛩️").font(.system(size: 50))
            Text("مذبح قديم").font(rnd(24, .black)).foregroundStyle(Color.white)
            Text("تضحّي بـ\(cost) من صحّتك وتاخذ +2 هجوم للأبد.").font(rnd(14)).foregroundStyle(MG.tx2).multilineTextAlignment(.center)
            Button { run.pray() } label: { Text("أضحّي").font(rnd(17, .black)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 52).background(MG.red, in: Capsule()) }
                .buttonStyle(Press()).opacity(c.hero.hp > cost ? 1 : 0.4)
            Button { run.leave() } label: { Text("لا، أكمّل طريقي").font(rnd(15, .bold)).foregroundStyle(MG.tx2).frame(maxWidth: .infinity).frame(height: 40) }
        }
    }

    private var endCard: some View {
        panel {
            Text(c.won ? "🏆" : "🪦").font(.system(size: 58))
            Text(c.won ? "طلعت من المغارة حيّ!" : "انتهت المغامرة").font(rnd(25, .black)).foregroundStyle(Color.white).multilineTextAlignment(.center)
            Text(c.won ? "غلبت التنّين وخلّصت الـ12 طابق" : (c.log.last ?? "")).font(rnd(13, .bold)).foregroundStyle(MG.tx2).multilineTextAlignment(.center)
            if run.newBest { Text("رقم قياسيّ جديد ⭐️").font(rnd(12.5, .heavy)).foregroundStyle(Color.black.opacity(0.8)).padding(.horizontal, 12).padding(.vertical, 5).background(MG.gold, in: Capsule()) }
            HStack(spacing: 8) {
                box("\(c.floor)", "الطابق")
                box("\(c.hero.kills)", "قتلى")
                box("\(c.hero.gold)", "ذهب")
                box("\(c.score)", "نقاط")
            }
            Button { run.start(seed: UInt64.random(in: 1...UInt64(Int.max))) } label: {
                Text("مغامرة جديدة").font(rnd(17, .black)).foregroundStyle(Color.black.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 54).background(MG.torch, in: Capsule())
            }.buttonStyle(Press())
            Button { run.stop(); close() } label: { Text("الرئيسيّة").font(rnd(15, .bold)).foregroundStyle(MG.tx2).frame(maxWidth: .infinity).frame(height: 38) }
        }
    }
    private func box(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(rnd(20, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(rnd(11)).foregroundStyle(MG.tx3)
        }.frame(maxWidth: .infinity).padding(.vertical, 9).background(MG.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
