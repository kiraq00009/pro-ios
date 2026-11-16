import SwiftUI

// ───────────────────────── الحفظ والإحصاء
struct SaveBlob: Codable {
    var state: GameState
    var elapsed: Int
    var moves: Int
    var score: Int
}

@MainActor
final class Rec: ObservableObject {
    @Published var wins = 0
    @Published var best = 0          // أفضل وقت بالثواني (0 = لا شي بعد)
    @Published var saved: SaveBlob? = nil
    private let ud = UserDefaults.standard

    init() {
        if Shot.on {
            wins = 37
            best = 214
            saved = SaveBlob(state: GameState.deal(seed: 7), elapsed: 126, moves: 83, score: 240)
            return
        }
        wins = ud.integer(forKey: "sl_wins")
        best = ud.integer(forKey: "sl_best")
        if let d = ud.data(forKey: "sl_saved"), let v = try? JSONDecoder().decode(SaveBlob.self, from: d) { saved = v }
    }

    func store(_ b: SaveBlob?) {
        guard !Shot.on else { return }
        saved = b
        if let b = b, let d = try? JSONEncoder().encode(b) { ud.set(d, forKey: "sl_saved") }
        else { ud.removeObject(forKey: "sl_saved") }
    }

    func recordWin(time: Int) {
        guard !Shot.on else { return }
        wins += 1
        if best == 0 || time < best { best = time }
        ud.set(wins, forKey: "sl_wins")
        ud.set(best, forKey: "sl_best")
        store(nil)
    }
}

// ───────────────────────── مصدر السحب
enum DragSource: Equatable {
    case waste
    case tableau(Int, Int)       // عمود، فهرس بداية السلسلة
}

struct Drag: Equatable {
    var source: DragSource
    var translation: CGSize
}

// ───────────────────────── محرّك اللعبة
@MainActor
final class Game: ObservableObject {
    @Published var g: GameState
    @Published var moves = 0
    @Published var score = 0
    @Published var elapsed = 0
    @Published var won = false
    @Published var drag: Drag? = nil
    @Published var hintSource: DragSource? = nil

    private var hist: [(GameState, Int, Int)] = []
    let rec: Rec
    private var autoRunning = false

    init(rec: Rec, startFresh: Bool, draw3: Bool) {
        self.rec = rec
        if Shot.on {
            g = Game.demo(draw3: draw3)
            elapsed = 198; moves = 96; score = 640
            won = Shot.name == "win"
            return
        }
        if !startFresh, let s = rec.saved {
            g = s.state; elapsed = s.elapsed; moves = s.moves; score = s.score
        } else {
            g = GameState.deal(seed: UInt64.random(in: 1...UInt64.max), draw3: draw3)
        }
    }

    var canUndo: Bool { !hist.isEmpty }
    var canAuto: Bool { !won && !g.isWon && g.allTableauFaceUp && (!g.stock.isEmpty || !g.waste.isEmpty || g.foundations.reduce(0) { $0 + $1.count } < 52) }

    private func faceDown(_ s: GameState) -> Int { s.tableau.reduce(0) { $0 + $1.filter { !$0.faceUp }.count } }

    /// يطبّق حركة مع النقاط والتاريخ. يرجع هل نجحت.
    @discardableResult
    func perform(_ m: Move, scored: Bool = true) -> Bool {
        let fdBefore = faceDown(g)
        guard let ng = g.applying(m) else { return false }
        hist.append((g, moves, score))
        if hist.count > 600 { hist.removeFirst(hist.count - 600) }
        var delta = (fdBefore - faceDown(ng)) * 5
        if scored {
            switch m {
            case .wasteToFoundation, .tableauToFoundation: delta += 10
            case .wasteToTableau: delta += 5
            case .foundationToTableau: delta -= 15
            default: break
            }
        }
        g = ng
        moves += 1
        score = max(0, score + delta)
        save()
        if g.isWon { finishWin() }
        return true
    }

    func tapStock() {
        if g.stock.isEmpty {
            if g.waste.isEmpty { return }
            perform(.recycle, scored: false)
        } else {
            perform(.draw, scored: false)
        }
        Haptic.tap()
    }

    /// نقرة ورقة → تطير للأساس إذا تنفع
    func tapToFoundation(_ s: DragSource) {
        let ok: Bool
        switch s {
        case .waste:
            ok = perform(.wasteToFoundation)
        case .tableau(let col, let k):
            guard k == g.tableau[col].count - 1 else { return }
            ok = perform(.tableauToFoundation(col))
        }
        if ok { Haptic.ok() } else { Haptic.bad() }
    }

    func dropToFoundation(_ s: DragSource, _ fi: Int) -> Bool {
        switch s {
        case .waste:
            guard let c = g.waste.last, c.suit.rawValue == fi else { return false }
            return perform(.wasteToFoundation)
        case .tableau(let col, let k):
            guard k == g.tableau[col].count - 1, let c = g.tableau[col].last, c.suit.rawValue == fi else { return false }
            return perform(.tableauToFoundation(col))
        }
    }

    func dropToColumn(_ s: DragSource, _ col: Int) -> Bool {
        switch s {
        case .waste:
            return perform(.wasteToTableau(col))
        case .tableau(let from, let k):
            let count = g.tableau[from].count - k
            return perform(.tableauToTableau(from, col, count))
        }
    }

    func undo() {
        guard let last = hist.popLast() else { return }
        g = last.0; moves = last.1; score = last.2; won = false
        save()
        Haptic.thud()
    }

    func showHint() {
        guard let m = g.hint() else { Haptic.bad(); return }
        let src: DragSource?
        switch m {
        case .wasteToFoundation, .wasteToTableau: src = .waste
        case .tableauToFoundation(let col): src = .tableau(col, g.tableau[col].count - 1)
        case .tableauToTableau(let from, _, let count): src = .tableau(from, g.tableau[from].count - count)
        default: src = nil
        }
        Haptic.tap()
        withAnimation(.easeOut(duration: 0.2)) { hintSource = src }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) { self?.hintSource = nil }
        }
    }

    /// إكمال تلقائيّ بتتابع ناعم
    func runAuto() {
        guard !autoRunning else { return }
        autoRunning = true
        autoStep()
    }
    private func autoStep() {
        var did = false
        if let c = g.waste.last, g.canMoveToFoundation(c, c.suit.rawValue) { did = withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { perform(.wasteToFoundation) } }
        if !did {
            for col in 0..<7 {
                if let c = g.tableau[col].last, c.faceUp, g.canMoveToFoundation(c, c.suit.rawValue) {
                    did = withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { perform(.tableauToFoundation(col)) }
                    break
                }
            }
        }
        if !did {
            if !g.stock.isEmpty { withAnimation(.easeOut(duration: 0.18)) { perform(.draw, scored: false) }; did = true }
            else if !g.waste.isEmpty { perform(.recycle, scored: false); did = true }
        }
        if did && !g.isWon {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in self?.autoStep() }
        } else {
            autoRunning = false
        }
    }

    private func finishWin() {
        won = true
        Haptic.ok()
        rec.recordWin(time: elapsed)
    }

    func save() {
        guard !Shot.on, !won else { if won { rec.store(nil) }; return }
        rec.store(SaveBlob(state: g, elapsed: elapsed, moves: moves, score: score))
    }

    // مشهد تجريبيّ للتصوير: لعبة بنص الطريق
    static func demo(draw3: Bool) -> GameState {
        var g = GameState.deal(seed: 7, draw3: draw3)
        for _ in 0..<18 { if let m = g.hint() { g.apply(m) } else { break } }
        g.apply(.draw); g.apply(.draw); if draw3 { g.apply(.draw) }
        return g
    }
}

// ───────────────────────── مواضع الكومات (لفحص الإفلات)
enum Slot: Hashable {
    case stock, waste
    case found(Int)
    case col(Int)
}

struct FrameKey: PreferenceKey {
    static var defaultValue: [Slot: CGRect] = [:]
    static func reduce(value: inout [Slot: CGRect], nextValue: () -> [Slot: CGRect]) { value.merge(nextValue()) { _, b in b } }
}

// ───────────────────────── الطاولة
struct GameView: View {
    @StateObject private var game: Game
    @ObservedObject var rec: Rec
    var close: () -> Void

    @State private var frames: [Slot: CGRect] = [:]
    @State private var showWin = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(rec: Rec, startFresh: Bool, draw3: Bool, close: @escaping () -> Void) {
        self.rec = rec
        self.close = close
        _game = StateObject(wrappedValue: Game(rec: rec, startFresh: startFresh, draw3: draw3))
    }

    var body: some View {
        GeometryReader { geo in
            table(geo)
        }
        .background(feltBg)
        .overlay(alignment: .center) { if showWin { winSheet } }
        .onReceive(timer) { _ in
            if !game.won && !Shot.on {
                game.elapsed += 1
                if game.elapsed % 5 == 0 { game.save() }
            }
        }
        .onChange(of: game.won) { w in if w { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation(.spring()) { showWin = true } } } }
        .onAppear { if Shot.name == "win" { showWin = true } }
    }

    private var feltBg: some View {
        ZStack {
            ST.feltDark
            RadialGradient(colors: [ST.felt, ST.feltDark], center: .center, startRadius: 40, endRadius: 520)
        }
        .ignoresSafeArea()
    }

    private func table(_ geo: GeometryProxy) -> some View {
        let pad: CGFloat = 9
        let gap: CGFloat = 6
        let cardW = (geo.size.width - pad * 2 - gap * 6) / 7
        let cardH = cardW * 1.42
        let topReserve = cardH + 104
        let tabH = max(cardH * 2.2, geo.size.height - topReserve - pad)
        return VStack(spacing: 11) {
            topBar
            topPiles(cardW: cardW, cardH: cardH, gap: gap)
            tableauRow(cardW: cardW, cardH: cardH, gap: gap, tabH: tabH)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, pad)
        .padding(.top, 6)
        .coordinateSpace(name: "table")
        .onPreferenceChange(FrameKey.self) { frames = $0 }
    }

    // ───────── الشريط العلويّ
    private var topBar: some View {
        HStack(spacing: 8) {
            iconBtn("xmark") { game.save(); close() }
            stat("الوقت", timeStr(game.elapsed))
            stat("الحركات", "\(game.moves)")
            stat("النقاط", "\(game.score)")
            Spacer(minLength: 0)
            iconBtn("lightbulb.fill", tint: ST.gold) { game.showHint() }
            iconBtn("arrow.uturn.backward", dim: !game.canUndo) { game.undo() }
            iconBtn("plus") { withAnimation(.spring()) { newGame() } }
        }
    }

    private func newGame() {
        game.undoAllAndDeal()
    }

    private func iconBtn(_ s: String, tint: Color = .white, dim: Bool = false, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: s).font(.system(size: 15, weight: .black)).foregroundStyle(dim ? ST.tx3 : tint).frame(width: 40, height: 40).background(ST.s1.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(Press())
        .disabled(dim)
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(spacing: 1) {
            Text(v).font(rnd(15, .black)).foregroundStyle(ST.tx).environment(\.layoutDirection, .leftToRight)
            Text(t).font(rnd(9.5, .semibold)).foregroundStyle(ST.tx3)
        }
        .frame(minWidth: 46)
        .padding(.vertical, 5).padding(.horizontal, 7)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // ───────── صفّ المخزن/المرمى/الأساسات
    private func topPiles(cardW: CGFloat, cardH: CGFloat, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            stockView(cardW, cardH)
            wasteView(cardW, cardH)
            Spacer(minLength: gap)
            ForEach(0..<4, id: \.self) { fi in foundationView(fi, cardW, cardH) }
        }
        .frame(height: cardH)
    }

    private func stockView(_ w: CGFloat, _ h: CGFloat) -> some View {
        Button { withAnimation(.easeOut(duration: 0.18)) { game.tapStock() } } label: {
            ZStack {
                slotBox(w, h)
                if let c = game.g.stock.last { CardBack(w: w, h: h).id(c.id) }
                else { Image(systemName: "arrow.clockwise").font(.system(size: w * 0.34, weight: .bold)).foregroundStyle(ST.tx3) }
                if game.g.stock.count > 1 {
                    Text("\(game.g.stock.count)").font(rnd(10, .black)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 1).background(Color.black.opacity(0.4), in: Capsule()).offset(y: h * 0.5 - 8)
                }
            }
            .frame(width: w, height: h)
        }
        .buttonStyle(Press())
        .reportFrame(.stock)
    }

    private func wasteView(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            slotBox(w, h)
            ForEach(Array(wasteVisible.enumerated()), id: \.element.id) { idx, c in
                let isTop = idx == wasteVisible.count - 1
                CardFace(card: c, w: w, h: h, dim: false)
                    .offset(x: CGFloat(idx) * (w * 0.22) * dirSign)
                    .offset(isTop ? dragOffset(.waste) : .zero)
                    .zIndex(isTop && game.drag?.source == .waste ? 900 : Double(idx))
                    .highlight(game.hintSource == .waste && isTop)
                    .maybeGesture(isTop, cardDrag(.waste))
                    .onTapGesture { if isTop { game.tapToFoundation(.waste) } }
            }
        }
        .frame(width: w + w * 0.22 * 2, height: h, alignment: dirAlign)
        .reportFrame(.waste)
    }

    private var wasteVisible: [Card] { Array(game.g.waste.suffix(3)) }
    private var dirSign: CGFloat { -1 }     // تتراكب نحو اليسار بصريًّا
    private var dirAlign: Alignment { .trailing }

    private func foundationView(_ fi: Int, _ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            slotBox(w, h)
            Text(Suit(rawValue: fi)!.symbol).font(rnd(w * 0.5, .bold)).foregroundStyle(Color.white.opacity(0.12))
            if let c = game.g.foundations[fi].last { CardFace(card: c, w: w, h: h, dim: false) }
        }
        .frame(width: w, height: h)
        .reportFrame(.found(fi))
    }

    // ───────── الأعمدة السبعة
    private func tableauRow(cardW: CGFloat, cardH: CGFloat, gap: CGFloat, tabH: CGFloat) -> some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(0..<7, id: \.self) { col in column(col, cardW, cardH, tabH) }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func column(_ col: Int, _ w: CGFloat, _ h: CGFloat, _ tabH: CGFloat) -> some View {
        let pile = game.g.tableau[col]
        let ys = layoutYs(pile, h: h, tabH: tabH)
        let colH = max(h, (ys.last ?? 0) + h)
        return ZStack(alignment: .top) {
            slotBox(w, h).frame(height: h)
            ForEach(Array(pile.enumerated()), id: \.element.id) { i, c in
                cardInColumn(col: col, i: i, card: c, w: w, h: h, y: ys[i])
            }
        }
        .frame(width: w, height: colH, alignment: .top)
        .reportFrame(.col(col))
    }

    @ViewBuilder
    private func cardInColumn(col: Int, i: Int, card: Card, w: CGFloat, h: CGFloat, y: CGFloat) -> some View {
        let pile = game.g.tableau[col]
        let runStart = pile.count - game.g.runLength(col: col)
        let eligible = card.faceUp && i >= runStart
        let dragging = isDraggingTableau(col: col, index: i)
        Group {
            if card.faceUp { CardFace(card: card, w: w, h: h, dim: false) }
            else { CardBack(w: w, h: h) }
        }
        .highlight(game.hintSource == .tableau(col, runStart) && i >= runStart)
        .offset(y: y)
        .offset(dragging ? (game.drag?.translation ?? .zero) : .zero)
        .zIndex(dragging ? 1000 + Double(i) : Double(i))
        .maybeGesture(eligible, cardDrag(.tableau(col, i)))
        .onTapGesture { if card.faceUp && i == pile.count - 1 { game.tapToFoundation(.tableau(col, i)) } }
    }

    private func isDraggingTableau(col: Int, index: Int) -> Bool {
        guard let d = game.drag, case .tableau(let c, let k) = d.source else { return false }
        return c == col && index >= k
    }

    private func dragOffset(_ s: DragSource) -> CGSize {
        game.drag?.source == s ? (game.drag?.translation ?? .zero) : .zero
    }

    // ───────── سحب الأوراق
    private func cardDrag(_ s: DragSource) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("table"))
            .onChanged { v in
                if game.drag?.source != s { game.drag = Drag(source: s, translation: v.translation) }
                else { game.drag?.translation = v.translation }
            }
            .onEnded { v in
                let applied = dropHit(s, at: v.location)
                if !applied { Haptic.bad() }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { game.drag = nil }
            }
    }

    private func dropHit(_ s: DragSource, at loc: CGPoint) -> Bool {
        for fi in 0..<4 {
            if let fr = frames[.found(fi)], fr.contains(loc) { if game.dropToFoundation(s, fi) { return true } }
        }
        var best: (Int, CGFloat)? = nil
        for col in 0..<7 {
            if let fr = frames[.col(col)], fr.contains(loc) {
                let dx = abs(loc.x - fr.midX)
                if best == nil || dx < best!.1 { best = (col, dx) }
            }
        }
        if let b = best, game.dropToColumn(s, b.0) { return true }
        return false
    }

    // ───────── عناصر مشتركة
    private func slotBox(_ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: w * 0.14, style: .continuous)
            .fill(Color.black.opacity(0.16))
            .overlay(RoundedRectangle(cornerRadius: w * 0.14, style: .continuous).stroke(ST.slot, lineWidth: 1))
            .frame(width: w, height: h)
    }

    // ───────── شاشة الفوز
    private var winSheet: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture {}
            VStack(spacing: 16) {
                Text("🎉").font(.system(size: 56))
                Text("فزت!").font(rnd(34, .black)).foregroundStyle(ST.tx)
                Text("رتّبت كلّ الورق — برافو!").font(rnd(14)).foregroundStyle(ST.tx2)
                HStack(spacing: 10) {
                    winStat("الوقت", timeStr(game.elapsed))
                    winStat("الحركات", "\(game.moves)")
                    winStat("النقاط", "\(game.score)")
                }
                if rec.best > 0 { Text("أفضل وقت إلك: \(timeStr(rec.best))").font(rnd(12.5, .semibold)).foregroundStyle(ST.gold) }
                Button { withAnimation(.spring()) { showWin = false; newGame() } } label: {
                    Text("لعبة جديدة").font(rnd(17, .heavy)).foregroundStyle(ST.ink).frame(maxWidth: .infinity).padding(.vertical, 14).background(ST.gold, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(Press())
                Button { game.save(); close() } label: {
                    Text("رجوع للقائمة").font(rnd(15, .heavy)).foregroundStyle(ST.tx2)
                }
                .buttonStyle(Press())
            }
            .padding(24)
            .frame(maxWidth: 360)
            .card(ST.s1, 26, stroke: ST.slot)
            .padding(24)
        }
        .transition(.opacity)
    }

    private func winStat(_ t: String, _ v: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(rnd(19, .black)).foregroundStyle(ST.tx).environment(\.layoutDirection, .leftToRight)
            Text(t).font(rnd(10.5, .semibold)).foregroundStyle(ST.tx3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // تخطيط مواضع الأوراق عموديًّا مع ضغطها لتناسب الشاشة
    private func layoutYs(_ pile: [Card], h: CGFloat, tabH: CGFloat) -> [CGFloat] {
        guard pile.count > 1 else { return pile.isEmpty ? [] : [0] }
        var ys: [CGFloat] = []
        var y: CGFloat = 0
        let faceStep = h * 0.30
        let downStep = h * 0.15
        for i in 0..<pile.count {
            if i > 0 { y += pile[i - 1].faceUp ? faceStep : downStep }
            ys.append(y)
        }
        let rawLast = ys.last ?? 0
        if rawLast + h > tabH && rawLast > 0 {
            let scale = (tabH - h) / rawLast
            ys = ys.map { $0 * max(0.18, scale) }
        }
        return ys
    }
}

// زرّ لعبة جديدة من داخل المحرّك (توزيع جديد وتصفير)
extension Game {
    func undoAllAndDeal() {
        let draw3 = g.draw3
        g = GameState.deal(seed: UInt64.random(in: 1...UInt64.max), draw3: draw3)
        moves = 0; score = 0; elapsed = 0; won = false
        hist.removeAll()
        drag = nil; hintSource = nil
        save()
        Haptic.tap()
    }
}

// ───────────────────────── بطاقات
struct CardFace: View {
    let card: Card
    let w: CGFloat
    let h: CGFloat
    var dim: Bool
    var body: some View {
        let ink = card.isRed ? ST.red : ST.ink
        RoundedRectangle(cornerRadius: w * 0.14, style: .continuous)
            .fill(dim ? ST.faceDim : ST.face)
            .overlay(RoundedRectangle(cornerRadius: w * 0.14, style: .continuous).stroke(Color.black.opacity(0.12), lineWidth: 0.8))
            .overlay(corner(ink), alignment: .topLeading)
            .overlay(Text(card.suit.symbol).font(rnd(w * 0.52, .bold)).foregroundStyle(ink.opacity(0.9)))
            .overlay(corner(ink).rotationEffect(.degrees(180)), alignment: .bottomTrailing)
            .environment(\.layoutDirection, .leftToRight)
            .frame(width: w, height: h)
            .shadow(color: .black.opacity(0.28), radius: 2.5, x: 0, y: 1.5)
    }
    private func corner(_ ink: Color) -> some View {
        VStack(spacing: -1) {
            Text(card.label).font(rnd(w * 0.34, .black)).foregroundStyle(ink)
            Text(card.suit.symbol).font(rnd(w * 0.30, .bold)).foregroundStyle(ink)
        }
        .padding(.leading, w * 0.1)
        .padding(.top, h * 0.06)
    }
}

struct CardBack: View {
    let w: CGFloat
    let h: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: w * 0.14, style: .continuous)
            .fill(LinearGradient(colors: [ST.back1, ST.back2], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: w * 0.09, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.4)
                    .padding(w * 0.11)
            )
            .overlay(Image(systemName: "suit.spade.fill").font(.system(size: w * 0.34, weight: .bold)).foregroundStyle(Color.white.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: w * 0.14, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 0.8))
            .frame(width: w, height: h)
            .shadow(color: .black.opacity(0.28), radius: 2.5, x: 0, y: 1.5)
    }
}

// ───────────────────────── مساعدات الواجهة
extension View {
    func reportFrame(_ slot: Slot) -> some View {
        background(GeometryReader { p in Color.clear.preference(key: FrameKey.self, value: [slot: p.frame(in: .named("table"))]) })
    }
    @ViewBuilder
    func maybeGesture<G: Gesture>(_ on: Bool, _ gesture: G) -> some View {
        if on { self.gesture(gesture) } else { self }
    }
    @ViewBuilder
    func highlight(_ on: Bool) -> some View {
        if on {
            overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(ST.gold, lineWidth: 3).shadow(color: ST.gold.opacity(0.8), radius: 6))
        } else {
            self
        }
    }
}
