import SwiftUI

// MARK: هندسة اللوحة

struct Geo {
    let W: CGFloat, H: CGFloat
    let f: CGFloat = 9, tray: CGFloat = 38, bar: CGFloat = 36
    init(_ s: CGSize) { W = s.width; H = s.height }
    var left: CGFloat { f }
    var right: CGFloat { W - f }
    var top: CGFloat { f }
    var bottom: CGFloat { H - f - tray - 7 }
    var rowH: CGFloat { (bottom - top - bar) / 12 }
    var len: CGFloat { (right - left) * 0.44 }
    var d: CGFloat { max(8, min(rowH - 2, len / 5, 42)) }
    func row(_ i: Int) -> Int { i < 12 ? i : 23 - i }
    func y(_ i: Int) -> CGFloat {
        let r = row(i)
        return bottom - (CGFloat(r) + 0.5) * rowH - (r >= 6 ? bar : 0)
    }
    var barY: CGFloat { bottom - 6 * rowH - bar / 2 }
    var trayY: CGFloat { H - f - tray / 2 }
    /// مكان الحجر رقم k من أصل n بالمفتاح المعطى + قطره
    func spot(_ key: Int, _ k: Int, _ n: Int) -> (CGPoint, CGFloat) {
        let kk = CGFloat(k)
        if key < 24 {
            let step = n > 1 ? min(d, (len - d) / CGFloat(n - 1)) : d
            let x = key < 12 ? right - d / 2 - 3 - kk * step : left + d / 2 + 3 + kk * step
            return (CGPoint(x: x, y: y(key)), d)
        }
        if key == 100 { return (CGPoint(x: W / 2 + 30 + kk * d * 0.6, y: barY), min(d, bar - 6)) }
        if key == 101 { return (CGPoint(x: W / 2 - 30 - kk * d * 0.6, y: barY), min(d, bar - 6)) }
        let s = min(10.5, (W / 2 - f - 46) / 14)
        if key == 200 { return (CGPoint(x: right - 20 - kk * s, y: trayY), tray - 14) }
        return (CGPoint(x: left + 20 + kk * s, y: trayY), tray - 14)
    }
}

struct Slot: Identifiable {
    let id: Int
    let pt: CGPoint
    let d: CGFloat
    let z: Double
    let mark: Int        // 0 عاديّ · 1 يتحرّك · 2 مختار · 3 تلميح
}

struct CheckerView: View {
    let owner: Int
    let d: CGFloat
    let mark: Int
    var body: some View {
        let light = owner == 0
        let c1 = light ? Color.white : Color(red: 0.30, green: 0.31, blue: 0.36)
        let c2 = light ? Color(red: 0.84, green: 0.78, blue: 0.64) : Color(red: 0.06, green: 0.06, blue: 0.09)
        let ring = mark == 2 ? NT.gold : (mark == 3 ? NT.cyan : NT.gold.opacity(0.75))
        ZStack {
            Circle().fill(RadialGradient(colors: [c1, c2], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: d * 0.75))
            Circle().stroke(light ? Color.black.opacity(0.18) : Color.white.opacity(0.22), lineWidth: 1)
            Circle().stroke(light ? Color.black.opacity(0.10) : Color.white.opacity(0.10), lineWidth: 1.5).padding(d * 0.2)
            if mark > 0 { Circle().stroke(ring, lineWidth: mark == 1 ? 2 : 3.5).padding(-1.5) }
        }
        .frame(width: d, height: d)
        .shadow(color: Color.black.opacity(0.45), radius: 2, y: 1.5)
        .scaleEffect(mark >= 2 ? 1.12 : 1)
    }
}

struct BoardView: View {
    let stacks: [Int: [Int]]
    let sel: Int?
    let targets: [Int]
    let sources: Set<Int>
    let hint: Move?
    let turn: Int
    let tap: (Int) -> Void

    var body: some View {
        GeometryReader { g in
            let G = Geo(g.size)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in draw(ctx, G) }
                trayLabels(G)
                ForEach(slots(G)) { s in
                    CheckerView(owner: s.id < 15 ? 0 : 1, d: s.d, mark: s.mark)
                        .position(s.pt).zIndex(s.z + (s.mark >= 2 ? 50 : 0))
                }
                marks(G)
                taps(G)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func k(_ loc: Int) -> Int { Match.key(loc, turn) }

    private func slots(_ G: Geo) -> [Slot] {
        var out: [Slot] = []
        let selKey: Int = sel.map { k($0) } ?? -9
        let hintKey: Int = hint.map { k($0.from) } ?? -9
        var src = Set<Int>()
        for s in sources { src.insert(k(s)) }
        for (key, ids) in stacks {
            let n = ids.count
            for (i, id) in ids.enumerated() {
                let sp = G.spot(key, i, n)
                var mark = 0
                if i == n - 1 && (id < 15 ? 0 : 1) == turn && key < 200 {
                    if selKey == key { mark = hintKey == key ? 3 : 2 }
                    else if sel == nil && src.contains(key) { mark = 1 }
                }
                out.append(Slot(id: id, pt: sp.0, d: sp.1, z: Double(i), mark: mark))
            }
        }
        return out.sorted { $0.id < $1.id }
    }

    private func landing(_ G: Geo, _ t: Int) -> CGPoint {
        let ids = stacks[t] ?? []
        var n = 0
        if let f = ids.first, (f < 15 ? 0 : 1) == turn { n = ids.count }
        return G.spot(t, n, n + 1).0
    }

    @ViewBuilder private func marks(_ G: Geo) -> some View {
        ForEach(targets, id: \.self) { t in
            let isHint = hint?.to == t
            let c = isHint ? NT.cyan : NT.green
            if t == 99 {
                RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(c, lineWidth: 3)
                    .background(c.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(width: G.W / 2 - G.f - 4, height: G.tray)
                    .position(x: turn == 0 ? G.W * 0.75 - 1 : G.W * 0.25 + 1, y: G.trayY)
                    .allowsHitTesting(false)
            } else {
                Circle().fill(c.opacity(0.35))
                    .overlay(Circle().stroke(c, lineWidth: 2.5))
                    .frame(width: G.d * 0.82, height: G.d * 0.82)
                    .position(landing(G, t)).zIndex(80)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder private func trayLabels(_ G: Geo) -> some View {
        let a = stacks[200]?.count ?? 0, b = stacks[201]?.count ?? 0
        Text(a > 0 ? "\(a)" : "بيتك").font(rnd(a > 0 ? 15 : 11, .heavy)).foregroundStyle(NT.ivory.opacity(a > 0 ? 0.95 : 0.4))
            .position(x: G.W / 2 + 22, y: G.trayY)
        Text(b > 0 ? "\(b)" : "").font(rnd(15, .heavy)).foregroundStyle(NT.ivory.opacity(0.95))
            .position(x: G.W / 2 - 22, y: G.trayY)
    }

    @ViewBuilder private func taps(_ G: Geo) -> some View {
        let w = (G.right - G.left) / 2
        ForEach(0..<24, id: \.self) { i in
            Color.clear.frame(width: w, height: G.rowH).contentShape(Rectangle())
                .onTapGesture { tap(i) }
                .position(x: i < 12 ? G.right - w / 2 : G.left + w / 2, y: G.y(i))
        }
        Color.clear.frame(width: G.W, height: G.bar).contentShape(Rectangle())
            .onTapGesture { tap(-1) }
            .position(x: G.W / 2, y: G.barY)
        Color.clear.frame(width: G.W, height: G.tray + 10).contentShape(Rectangle())
            .onTapGesture { tap(99) }
            .position(x: G.W / 2, y: G.trayY)
    }

    private func draw(_ ctx: GraphicsContext, _ G: Geo) {
        let outer = CGRect(x: 0, y: 0, width: G.W, height: G.H)
        ctx.fill(Path(roundedRect: outer, cornerRadius: 24), with: .linearGradient(Gradient(colors: [NT.wood, NT.woodDark]), startPoint: .zero, endPoint: CGPoint(x: G.W, y: G.H)))
        let felt = CGRect(x: G.left, y: G.top, width: G.right - G.left, height: G.bottom - G.top)
        ctx.fill(Path(roundedRect: felt, cornerRadius: 14), with: .linearGradient(Gradient(colors: [NT.felt, NT.feltDark]), startPoint: CGPoint(x: 0, y: G.top), endPoint: CGPoint(x: 0, y: G.bottom)))
        for i in 0..<24 {
            let yc = G.y(i), h = G.rowH / 2 - 1.5
            let base = i < 12 ? G.right - 1 : G.left + 1
            let tip = i < 12 ? G.right - G.len : G.left + G.len
            var p = Path()
            p.move(to: CGPoint(x: base, y: yc - h))
            p.addLine(to: CGPoint(x: tip, y: yc))
            p.addLine(to: CGPoint(x: base, y: yc + h))
            p.closeSubpath()
            ctx.fill(p, with: .color(G.row(i) % 2 == 0 ? NT.triA : NT.triB))
        }
        let barRect = CGRect(x: G.left, y: G.barY - G.bar / 2 + 2, width: G.right - G.left, height: G.bar - 4)
        ctx.fill(Path(roundedRect: barRect, cornerRadius: 8), with: .color(NT.woodDark.opacity(0.92)))
        let tw = (G.right - G.left - 6) / 2
        let t1 = CGRect(x: G.left, y: G.trayY - G.tray / 2, width: tw, height: G.tray)
        let t2 = CGRect(x: G.right - tw, y: G.trayY - G.tray / 2, width: tw, height: G.tray)
        ctx.fill(Path(roundedRect: t1, cornerRadius: 12), with: .color(Color.black.opacity(0.38)))
        ctx.fill(Path(roundedRect: t2, cornerRadius: 12), with: .color(Color.black.opacity(0.38)))
    }
}

// MARK: الزار

struct DieView: View {
    let face: Int
    var used = false
    var size: CGFloat = 46
    private static let pips: [[Int]] = [[], [4], [0, 8], [0, 4, 8], [0, 2, 6, 8], [0, 2, 4, 6, 8], [0, 2, 3, 5, 6, 8]]
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [Color.white, Color(red: 0.88, green: 0.85, blue: 0.78)], startPoint: .top, endPoint: .bottom))
            ForEach(DieView.pips[max(0, min(6, face))], id: \.self) { i in
                Circle().fill(Color(red: 0.1, green: 0.1, blue: 0.13))
                    .frame(width: size * 0.19, height: size * 0.19)
                    .offset(x: CGFloat(i % 3 - 1) * size * 0.27, y: CGFloat(i / 3 - 1) * size * 0.27)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
        .opacity(used ? 0.3 : 1)
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: شاشة اللعب

struct GameView: View {
    @StateObject private var m: Match
    let close: () -> Void
    init(setup: Setup, saved: SavedGame?, rec: Rec, close: @escaping () -> Void) {
        _m = StateObject(wrappedValue: Match(setup: setup, saved: saved, rec: rec))
        self.close = close
    }
    private var two: Bool { m.setup.level < 0 }
    private func name(_ p: Int) -> String {
        if two { return p == 0 ? "الأبيض" : "الأسود" }
        return p == 0 ? "أنت" : "الجهاز"
    }

    var body: some View {
        VStack(spacing: 9) {
            topBar
            playerRow(1)
            BoardView(stacks: m.stacks, sel: m.sel, targets: m.targets, sources: (m.phase == .move && m.humanTurn) ? m.sources : [], hint: m.hint, turn: m.turn) { m.tap($0) }
            playerRow(0)
            controls
        }
        .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 8)
        .background(Backdrop())
        .overlay { if let o = m.outcome { resultCard(o) } }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { m.stop(); close() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color.white).frame(width: 40, height: 40).background(NT.s2, in: Circle()) }.buttonStyle(Press())
            VStack(spacing: 5) {
                Text(m.setup.target == 1 ? "جولة وحدة" : "مباراة لـ\(m.setup.target) نقاط").font(rnd(12, .bold)).foregroundStyle(NT.tx3)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(red: 0.16, green: 0.16, blue: 0.2))
                        Capsule().fill(NT.ivory).frame(width: max(6, g.size.width * CGFloat(m.chance)))
                    }
                }
                .frame(height: 6).environment(\.layoutDirection, .leftToRight)
                .animation(.easeInOut(duration: 0.4), value: m.chance)
            }
            Button { m.askHint() } label: { Image(systemName: "lightbulb.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(NT.gold).frame(width: 40, height: 40).background(NT.s2, in: Circle()) }
                .buttonStyle(Press()).opacity(m.phase == .move && m.humanTurn && !m.options.isEmpty ? 1 : 0.35)
        }
    }

    private func playerRow(_ p: Int) -> some View {
        let active = m.turn == p && m.phase != .over
        let thinking = active && !two && p == 1
        return HStack(spacing: 10) {
            CheckerView(owner: p, d: 28, mark: 0)
            VStack(alignment: .leading, spacing: 1) {
                Text(name(p)).font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text(thinking ? "يلعب…" : "باقي \(m.board.pips(p)) خطوة").font(rnd(11.5)).foregroundStyle(NT.tx3)
            }
            Spacer()
            if active { Text("الدور").font(rnd(11, .heavy)).foregroundStyle(Color.black.opacity(0.8)).padding(.horizontal, 9).padding(.vertical, 4).background(NT.gold, in: Capsule()) }
            Text("\(m.score[p])").font(rnd(20, .black)).foregroundStyle(Color.white).frame(minWidth: 34).padding(.vertical, 3).background(NT.s2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .card(NT.s1, 16, stroke: active ? NT.gold.opacity(0.7) : Color(white: 1, opacity: 0.06))
        .animation(.easeInOut(duration: 0.25), value: active)
    }

    private var diceShown: [(Int, Bool)] {
        var remaining = m.left
        var out: [(Int, Bool)] = []
        for f in m.faces {
            if let k = remaining.firstIndex(of: f) { remaining.remove(at: k); out.append((f, false)) } else { out.append((f, !m.rolling)) }
        }
        // المستعمل أوّل حتى الباقي يبين على جهة وحدة
        return out.sorted { $0.1 && !$1.1 }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button { m.undo() } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 17, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 54, height: 54).background(NT.s2, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }.buttonStyle(Press()).opacity(m.phase == .move && m.humanTurn && !m.played.isEmpty ? 1 : 0.3)
            ZStack {
                if !m.note.isEmpty {
                    Text(m.note).font(rnd(12.5, .bold)).foregroundStyle(NT.gold).multilineTextAlignment(.center)
                } else if m.faces.isEmpty {
                    Text(m.humanTurn ? "دورك — ارمِ الزار" : "دور الجهاز").font(rnd(13, .bold)).foregroundStyle(NT.tx3)
                } else {
                    let list = diceShown
                    HStack(spacing: 7) {
                        ForEach(0..<list.count, id: \.self) { i in
                            DieView(face: list[i].0, used: list[i].1, size: list.count > 2 ? 36 : 46)
                                .rotationEffect(.degrees(m.rolling ? Double(i % 2 == 0 ? -14 : 12) : 0))
                        }
                    }
                }
            }.frame(maxWidth: .infinity).frame(height: 54)
            primary
        }
    }

    @ViewBuilder private var primary: some View {
        if m.phase == .roll && m.humanTurn && !m.rolling {
            big("ارمِ", "dice.fill", NT.gold) { m.roll() }
        } else if m.canFinish {
            big("تمام", "checkmark", NT.green) { m.done() }
        } else {
            big(m.phase == .move ? "حرّك" : "…", "hand.point.up.left.fill", NT.s2, dim: true) {}
        }
    }
    private func big(_ t: String, _ icon: String, _ c: Color, dim: Bool = false, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 6) {
                if !dim { Image(systemName: icon).font(.system(size: 15, weight: .black)) }
                Text(t).font(rnd(16, .black))
            }
            .foregroundStyle(dim ? NT.tx3 : Color.black.opacity(0.82))
            .frame(width: 104, height: 54)
            .background(c, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }.buttonStyle(Press()).disabled(dim)
    }

    private func resultCard(_ o: Outcome) -> some View {
        let mine = two || o.winner == 0
        let title = two ? "فاز \(name(o.winner))" : (o.winner == 0 ? "فزت!" : "خسرت هالجولة")
        let kind = o.value == 3 ? "مارس مضاعف · ٣ نقاط" : (o.value == 2 ? "مارس · نقطتين" : "فوز عاديّ · نقطة")
        return ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: mine ? "trophy.fill" : "flag.fill").font(.system(size: 44, weight: .black)).foregroundStyle(mine ? NT.gold : NT.tx2)
                    .frame(width: 96, height: 96).background((mine ? NT.gold : Color.white).opacity(0.14), in: Circle())
                Text(title).font(rnd(30, .black)).foregroundStyle(Color.white)
                Text(kind).font(rnd(14, .bold)).foregroundStyle(mine ? NT.gold : NT.tx2)
                HStack(spacing: 18) {
                    scoreBox(name(0), m.score[0], 0)
                    Text("—").font(rnd(20, .black)).foregroundStyle(NT.tx3)
                    scoreBox(name(1), m.score[1], 1)
                }.padding(.vertical, 4)
                if o.matchOver { Text(two ? "خلصت المباراة" : (o.winner == 0 ? "المباراة إلك 👑" : "المباراة راحت للجهاز")).font(rnd(13, .bold)).foregroundStyle(NT.tx2) }
                Button { m.nextGame() } label: {
                    Text(o.matchOver ? "مباراة جديدة" : "الجولة الجاية").font(rnd(17, .black)).foregroundStyle(Color.black.opacity(0.82))
                        .frame(maxWidth: .infinity).frame(height: 54).background(NT.gold, in: Capsule())
                }.buttonStyle(Press())
                Button { m.stop(); close() } label: { Text("الرئيسيّة").font(rnd(15, .bold)).foregroundStyle(NT.tx2).frame(maxWidth: .infinity).frame(height: 40) }
            }
            .padding(22).card(NT.s1, 30, stroke: NT.gold.opacity(0.3)).padding(.horizontal, 30)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }
    private func scoreBox(_ n: String, _ v: Int, _ p: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(v)").font(rnd(34, .black)).foregroundStyle(Color.white)
            HStack(spacing: 5) {
                CheckerView(owner: p, d: 14, mark: 0)
                Text(n).font(rnd(12, .bold)).foregroundStyle(NT.tx3)
            }
        }.frame(width: 92)
    }
}
