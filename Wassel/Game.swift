import SwiftUI

enum Mode: Equatable {
    case level(Int)
    case daily
}

struct GameView: View {
    @EnvironmentObject var store: Store
    let done: () -> Void

    @State private var mode: Mode
    @State private var level: FlowLevel
    @State private var board: Board
    @State private var dragColor: Int? = nil
    @State private var resets = 0
    @State private var hints = 0
    @State private var won = false
    @State private var showWin = false
    @State private var earnedStars = 0
    @State private var lastConnected = 0
    @State private var pulse = false

    init(mode: Mode, done: @escaping () -> Void) {
        self.done = done
        let lv: FlowLevel
        switch mode {
        case .level(let i): lv = Levels.level(i)
        case .daily: lv = Levels.daily()
        }
        _mode = State(initialValue: mode)
        _level = State(initialValue: lv)
        _board = State(initialValue: Board(lv))
    }

    private var hasNext: Bool {
        if case .level(let i) = mode { return i + 1 < Levels.count }
        return false
    }

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 14) {
                topBar
                stats
                boardView
                controls
                Text("امسك نقطة واسحب لين النقطة اللي بنفس لونها").font(rnd(12)).foregroundStyle(WS.tx3).multilineTextAlignment(.center)
            }
            .padding(16)
            if showWin { winOverlay }
        }
        .onAppear(perform: applyShot)
    }

    // MARK: شريط علويّ
    private var topBar: some View {
        HStack {
            Button(action: done) {
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .black)).foregroundStyle(WS.tx)
                    .frame(width: 44, height: 44).background(WS.s2, in: Circle())
            }
            .buttonStyle(Press())
            Spacer()
            VStack(spacing: 1) {
                HStack(spacing: 5) {
                    Text(mode == .daily ? "لغز اليوم" : "المرحلة").font(rnd(18, .black)).foregroundStyle(WS.tx)
                    if case .level(let i) = mode { Num(i + 1).font(rnd(18, .black)).foregroundStyle(WS.tx) }
                }
                Text("\(numStr(level.size))×\(numStr(level.size)) · \(numStr(level.pairs)) ألوان").font(rnd(11.5)).foregroundStyle(WS.tx3)
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    // MARK: شريط التقدّم (تعبئة + عدد الأنابيب)
    private var stats: some View {
        let st = board.status
        return HStack(spacing: 10) {
            statChip("\(numStr(st.filledPercent))٪", "تعبئة", WS.tint)
            statChip("\(numStr(board.connectedCount))/\(numStr(level.pairs))", "موصولة", WS.green)
            statChip("\(numStr(earnedStarsPreview))", "نجوم متوقّعة", WS.gold)
        }
    }

    private var earnedStarsPreview: Int { max(1, 3 - min(2, resets + hints)) }

    private func statChip(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(rnd(16, .black)).foregroundStyle(c).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(10.5)).foregroundStyle(WS.tx3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 9).card(WS.s1, 14, stroke: c.opacity(0.2))
    }

    // MARK: اللوح
    private var boardView: some View {
        GeometryReader { geo in
            let n = level.size
            let side = min(geo.size.width, geo.size.height)
            let cw = side / CGFloat(n)
            ZStack {
                Canvas { ctx, _ in draw(ctx, n: n, cw: cw, side: side) }
                    .frame(width: side, height: side)
            }
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(WS.s1))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(won ? WS.green.opacity(0.7) : WS.grid, lineWidth: won ? 2 : 1))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in handleDrag(g.location, side: side, origin: originFor(geo: geo, side: side)) }
                    .onEnded { _ in endDrag() }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func originFor(geo: GeometryProxy, side: CGFloat) -> CGPoint {
        CGPoint(x: (geo.size.width - side) / 2, y: (geo.size.height - side) / 2)
    }

    // رسم الشبكة والأنابيب والنقاط
    private func draw(_ ctx: GraphicsContext, n: Int, cw: CGFloat, side: CGFloat) {
        // خلفيّة الخانات
        for r in 0..<n {
            for c in 0..<n {
                let rect = CGRect(x: CGFloat(c) * cw + 1.5, y: CGFloat(r) * cw + 1.5, width: cw - 3, height: cw - 3)
                ctx.fill(Path(roundedRect: rect, cornerRadius: cw * 0.16), with: .color(WS.cell))
            }
        }
        // الأنابيب
        for color in 0..<level.pairs {
            let idxs = board.paths[color]
            guard idxs.count >= 1 else { continue }
            let col = WS.pipe(color)
            // تعبئة ناعمة تحت الأنبوب
            for i in idxs {
                let rr = i / n, cc = i % n
                let rect = CGRect(x: CGFloat(cc) * cw + 1.5, y: CGFloat(rr) * cw + 1.5, width: cw - 3, height: cw - 3)
                ctx.fill(Path(roundedRect: rect, cornerRadius: cw * 0.16), with: .color(col.opacity(0.18)))
            }
            if idxs.count >= 2 {
                var p = Path()
                for (k, i) in idxs.enumerated() {
                    let pt = center(i, n: n, cw: cw)
                    if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                ctx.stroke(p, with: .color(col.opacity(0.35)), style: StrokeStyle(lineWidth: cw * 0.52, lineCap: .round, lineJoin: .round))
                ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: cw * 0.3, lineCap: .round, lineJoin: .round))
            }
        }
        // النقاط (الأطراف)
        for color in 0..<level.pairs {
            let col = WS.pipe(color)
            let connected = board.connected(color)
            for end in [board.ea[color], board.eb[color]] {
                let pt = center(end, n: n, cw: cw)
                let d = cw * 0.62
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d)), with: .color(col))
                let inner = cw * (connected ? 0.26 : 0.2)
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - inner / 2, y: pt.y - inner / 2, width: inner, height: inner)), with: .color(.white.opacity(connected ? 0.9 : 0.35)))
            }
        }
        // رأس الأنبوب غير الموصول
        if let dc = dragColor, !board.connected(dc), let h = board.head(dc) {
            let pt = center(h, n: n, cw: cw)
            let d = cw * 0.4
            ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d)), with: .color(.white.opacity(0.85)), lineWidth: 2)
        }
    }

    private func center(_ i: Int, n: Int, cw: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(i % n) + 0.5) * cw, y: (CGFloat(i / n) + 0.5) * cw)
    }

    // MARK: التحكّم
    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: reset) {
                label("امسح", "arrow.counterclockwise", WS.pipe(0))
            }
            .buttonStyle(Press())
            Button(action: hint) {
                label("تلميح", "lightbulb.fill", WS.gold)
            }
            .buttonStyle(Press())
            .disabled(board.connectedCount == level.pairs)
        }
    }

    private func label(_ t: String, _ icon: String, _ c: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold))
            Text(t).font(rnd(16, .heavy))
        }
        .foregroundStyle(c).frame(maxWidth: .infinity).frame(height: 52).card(WS.s1, 18, stroke: c.opacity(0.3))
    }

    // MARK: المنطق
    private func handleDrag(_ loc: CGPoint, side: CGFloat, origin: CGPoint) {
        let n = level.size
        let cw = side / CGFloat(n)
        let x = loc.x - origin.x
        let y = loc.y - origin.y
        guard x >= 0, y >= 0, x < side, y < side else { return }
        let c = min(n - 1, max(0, Int(x / cw)))
        let r = min(n - 1, max(0, Int(y / cw)))
        let i = r * n + c
        if dragColor == nil {
            if let col = board.endpointColor(i) {
                board.start(col, at: i)
                dragColor = col
                Haptic.tap()
            } else if let col = board.owner(i) {
                board.grab(col, at: i)
                dragColor = col
                Haptic.tap()
            }
            afterMutation()
            return
        }
        drive(dragColor!, toRow: r, toCol: c, n: n)
        afterMutation()
    }

    private func drive(_ color: Int, toRow tr: Int, toCol tc: Int, n: Int) {
        var guardN = 0
        let cap = n * n + 2
        while guardN < cap {
            guardN += 1
            guard let h = board.head(color) else { break }
            let hr = h / n, hc = h % n
            if hr == tr && hc == tc { break }
            var next = h
            if hr != tr {
                next = h + (tr > hr ? n : -n)
            } else {
                next = h + (tc > hc ? 1 : -1)
            }
            let before = board.connectedCount
            if !board.extend(color, to: next) { break }
            if board.connectedCount > before { Haptic.ok() }
        }
    }

    private func endDrag() {
        dragColor = nil
        checkWin()
    }

    private func afterMutation() {
        let cc = board.connectedCount
        if cc != lastConnected { lastConnected = cc }
        checkWin()
    }

    private func checkWin() {
        guard !won, board.won else { return }
        won = true
        earnedStars = max(1, 3 - min(2, resets + hints))
        Haptic.ok()
        switch mode {
        case .level(let i): store.record(level: i, stars: earnedStars)
        case .daily: store.recordDaily(earnedStars)
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { showWin = true }
    }

    private func reset() {
        board.clearAll()
        resets += 1
        won = false
        dragColor = nil
        lastConnected = 0
        Haptic.thud()
    }

    private func hint() {
        for color in 0..<level.pairs where !board.connected(color) {
            let path = level.solution[color].map { level.idx($0) }
            withAnimation(.easeOut(duration: 0.2)) { board.solve(color, path: path) }
            hints += 1
            Haptic.tap()
            checkWin()
            return
        }
    }

    private func loadNext() {
        guard case .level(let i) = mode, i + 1 < Levels.count else { done(); return }
        let ni = i + 1
        let lv = Levels.level(ni)
        mode = .level(ni)
        level = lv
        board = Board(lv)
        resets = 0
        hints = 0
        won = false
        dragColor = nil
        lastConnected = 0
        showWin = false
    }

    private func replay() {
        board.clearAll()
        resets += 1
        won = false
        dragColor = nil
        lastConnected = 0
        showWin = false
    }

    // MARK: شاشة الفوز
    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea().onTapGesture {}
            VStack(spacing: 16) {
                Text("فزت!").font(rnd(40, .black)).foregroundStyle(WS.tx)
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { k in
                        Image(systemName: k < earnedStars ? "star.fill" : "star")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(k < earnedStars ? WS.gold : WS.tx3)
                            .scaleEffect(pulse && k < earnedStars ? 1 : 0.6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(Double(k) * 0.12), value: pulse)
                    }
                }
                Text(winSubtitle).font(rnd(14)).foregroundStyle(WS.tx2).multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    if hasNext {
                        Button(action: loadNext) {
                            Text("التالي").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.85)).frame(maxWidth: .infinity).frame(height: 54).background(WS.tint, in: Capsule())
                        }
                        .buttonStyle(Press())
                    }
                    HStack(spacing: 10) {
                        Button(action: replay) {
                            Text("مرّة ثانية").font(rnd(16, .heavy)).foregroundStyle(WS.tx).frame(maxWidth: .infinity).frame(height: 50).card(WS.s2, 16, stroke: WS.grid)
                        }
                        .buttonStyle(Press())
                        Button(action: done) {
                            Text("المراحل").font(rnd(16, .heavy)).foregroundStyle(WS.tx).frame(maxWidth: .infinity).frame(height: 50).card(WS.s2, 16, stroke: WS.grid)
                        }
                        .buttonStyle(Press())
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .card(WS.s1, 28, stroke: WS.tint.opacity(0.3))
            .padding(24)
            .onAppear { pulse = true }
            .onDisappear { pulse = false }
        }
    }

    private var winSubtitle: String {
        switch earnedStars {
        case 3: return "ممتاز! حلّيتها بلا أيّ مساعدة."
        case 2: return "حلو! جرّب بلا تلميح للنجمة الثالثة."
        default: return "برافو! خلّصتها."
        }
    }

    private func numStr(_ v: Int) -> String { "\(v)" }

    // MARK: وضع التصوير
    private func applyShot() {
        guard Shot.on else { return }
        if Shot.name == "win" {
            for color in 0..<level.pairs {
                let path = level.solution[color].map { level.idx($0) }
                board.solve(color, path: path)
            }
            earnedStars = 3
            won = true
            showWin = true
            pulse = true
        } else if Shot.name == "game" {
            // ارسم أغلب الألوان حتى يبيّن لوح ملوّن بتعبئة عالية
            for color in 0..<max(1, level.pairs - 1) {
                let path = level.solution[color].map { level.idx($0) }
                board.solve(color, path: path)
            }
            // ارسم نصف اللون الأخير حتى يبيّن رأس أنبوب
            if level.pairs >= 1 {
                let last = level.pairs - 1
                let full = level.solution[last].map { level.idx($0) }
                let half = Array(full.prefix(max(2, full.count / 2)))
                board.solve(last, path: half)
            }
        }
    }
}
