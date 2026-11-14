import SwiftUI

struct GameView: View {
    let puzzle: Puzzle
    let penalty: Bool
    let onNext: () -> Void
    let onClose: () -> Void
    @EnvironmentObject var store: Store

    @State private var cells: [[Int]]           // 0 فارغ · 1 مملوء · 2 علامة X
    @State private var markMode = false
    @State private var seconds = 0
    @State private var mistakes = 0
    @State private var won = false
    @State private var dead = false
    @State private var dragVal: Int?
    @State private var lastCell: [Int]?

    private let maxMistakes = 5
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(puzzle: Puzzle, penalty: Bool, onNext: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.puzzle = puzzle
        self.penalty = penalty
        self.onNext = onNext
        self.onClose = onClose
        let n = puzzle.size.n
        _cells = State(initialValue: Array(repeating: Array(repeating: 0, count: n), count: n))
    }

    private var n: Int { puzzle.size.n }
    private var maxRowClue: Int { max(1, puzzle.rowClues.map { $0.count }.max() ?? 1) }
    private var maxColClue: Int { max(1, puzzle.colClues.map { $0.count }.max() ?? 1) }

    var body: some View {
        VStack(spacing: 14) {
            topBar
            GeometryReader { geo in
                boardFit(geo.size)
            }
            controls
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(Backdrop())
        .onReceive(timer) { _ in
            if !won && !dead { seconds += 1 }
        }
        .onAppear(perform: seedShot)
        .sheet(isPresented: $won) {
            ResultSheet(win: true, puzzle: puzzle, time: seconds, best: store.best[puzzle.id], hasNext: store.nextAfter(puzzle) != nil, onPrimary: primaryWin, onClose: closeAll)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(NN.accent)
        }
        .sheet(isPresented: $dead) {
            ResultSheet(win: false, puzzle: puzzle, time: seconds, best: store.best[puzzle.id], hasNext: false, onPrimary: { dead = false; resetBoard() }, onClose: closeAll)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(NN.accent)
        }
    }

    // ── الشريط العلويّ ──
    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.forward").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.white)
                    .frame(width: 40, height: 40).background(NN.s2, in: Circle())
            }
            .buttonStyle(Press())
            VStack(alignment: .leading, spacing: 1) {
                Text(puzzle.name).font(rnd(20, .black)).foregroundStyle(Color.white)
                Text(puzzle.size.title).font(rnd(11.5)).foregroundStyle(NN.tx3)
            }
            Spacer()
            badge("clock", mmss(seconds), NN.accent)
            if penalty {
                badge("heart.fill", "\(max(0, maxMistakes - mistakes))", NN.accent2)
            }
        }
    }

    private func badge(_ icon: String, _ v: String, _ c: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
            Text(v).font(rnd(15, .black)).environment(\.layoutDirection, .leftToRight)
        }
        .foregroundStyle(c).padding(.horizontal, 11).padding(.vertical, 8).background(NN.s1, in: Capsule())
    }

    // ── اللوحة ──
    private func boardFit(_ size: CGSize) -> some View {
        let slotsW = CGFloat(n + maxRowClue)
        let slotsH = CGFloat(n + maxColClue)
        let byW = (size.width - 6) / slotsW
        let byH = (size.height - 6) / slotsH
        let cell = max(12, min(34, min(byW, byH)))
        return board(cell)
            .frame(width: size.width, height: size.height, alignment: .center)
    }

    private func board(_ cell: CGFloat) -> some View {
        let gridW = cell * CGFloat(n)
        let rowClueW = cell * CGFloat(maxRowClue)
        let colClueH = cell * CGFloat(maxColClue)
        return VStack(spacing: 2) {
            HStack(spacing: 2) {
                colCluesRow(cell).frame(width: gridW, height: colClueH)
                Color.clear.frame(width: rowClueW, height: colClueH)
            }
            HStack(spacing: 2) {
                cellsGrid(cell).frame(width: gridW, height: gridW)
                rowCluesColumn(cell).frame(width: rowClueW, height: gridW)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func colCluesRow(_ cell: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { c in
                clueCell(puzzle.colClues[c], vertical: true, satisfied: colSatisfied(c), cell: cell)
                    .frame(width: cell)
            }
        }
    }

    private func rowCluesColumn(_ cell: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { r in
                clueCell(puzzle.rowClues[r], vertical: false, satisfied: rowSatisfied(r), cell: cell)
                    .frame(height: cell)
            }
        }
    }

    private func clueCell(_ clue: [Int], vertical: Bool, satisfied: Bool, cell: CGFloat) -> some View {
        let nums = clue == [0] ? [] : clue
        let fs = max(9, min(15, cell * 0.5))
        let col = satisfied ? NN.good.opacity(0.65) : NN.tx2
        return Group {
            if vertical {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ForEach(Array(nums.enumerated()), id: \.offset) { pair in
                        Text("\(pair.element)").font(rnd(fs, .heavy)).foregroundStyle(col).frame(height: cell * 0.76)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(nums.enumerated()), id: \.offset) { pair in
                        Text("\(pair.element)").font(rnd(fs, .heavy)).foregroundStyle(col).frame(width: cell * 0.76)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(vertical ? .vertical : .horizontal, 1)
    }

    private func cellsGrid(_ cell: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<n, id: \.self) { c in
                        cellView(r, c, cell)
                    }
                }
            }
        }
        .overlay(gridLines(cell))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in paintAt(g.location, cell) }
                .onEnded { _ in dragVal = nil; lastCell = nil }
        )
    }

    private func cellView(_ r: Int, _ c: Int, _ cell: CGFloat) -> some View {
        let s = cells[r][c]
        return ZStack {
            Rectangle().fill(cellFill(s))
            if s == 2 {
                Image(systemName: "xmark").font(.system(size: cell * 0.4, weight: .heavy)).foregroundStyle(NN.tx3)
            }
        }
        .frame(width: cell, height: cell)
    }

    private func cellFill(_ s: Int) -> Color {
        if s == 1 { return won ? NN.of(puzzle.ink) : NN.ink }
        if s == 2 { return NN.bg.opacity(0.7) }
        return NN.s2.opacity(0.9)
    }

    private func gridLines(_ cell: CGFloat) -> some View {
        Canvas { ctx, _ in
            let span = cell * CGFloat(n)
            for i in 0...n {
                let x = CGFloat(i) * cell
                let thick = (i % 5 == 0)
                let w: CGFloat = thick ? 1.3 : 0.6
                let o = thick ? 0.28 : 0.09
                var v = Path()
                v.move(to: CGPoint(x: x, y: 0))
                v.addLine(to: CGPoint(x: x, y: span))
                ctx.stroke(v, with: .color(Color.white.opacity(o)), lineWidth: w)
                var h = Path()
                h.move(to: CGPoint(x: 0, y: x))
                h.addLine(to: CGPoint(x: span, y: x))
                ctx.stroke(h, with: .color(Color.white.opacity(o)), lineWidth: w)
            }
        }
        .allowsHitTesting(false)
    }

    // ── التفاعل ──
    private func paintAt(_ loc: CGPoint, _ cell: CGFloat) {
        guard !won && !dead, cell > 0 else { return }
        let c = Int(loc.x / cell)
        let r = Int(loc.y / cell)
        guard r >= 0, r < n, c >= 0, c < n else { return }
        let isFirst = (lastCell == nil)
        if let lc = lastCell, lc == [r, c] { return }
        lastCell = [r, c]

        if markMode {
            if dragVal == nil { dragVal = cells[r][c] == 2 ? 0 : 2 }
            cells[r][c] = dragVal ?? 2
            Haptic.tap()
            afterChange(r, c)
            return
        }
        if penalty {
            if !isFirst { return }          // بوضع الأخطاء: نقرة لكلّ خانة (بلا سحب)
            tapFillPenalty(r, c)
            return
        }
        // وضع حرّ: السحب يرسم
        if dragVal == nil { dragVal = cells[r][c] == 1 ? 0 : 1 }
        cells[r][c] = dragVal ?? 1
        Haptic.tap()
        afterChange(r, c)
    }

    private func tapFillPenalty(_ r: Int, _ c: Int) {
        if cells[r][c] != 0 {
            cells[r][c] = 0
            Haptic.tap()
            afterChange(r, c)
            return
        }
        if puzzle.bitmap[r][c] {
            cells[r][c] = 1
            Haptic.tap()
        } else {
            mistakes += 1
            cells[r][c] = 2
            Haptic.bad()
            if mistakes >= maxMistakes { dead = true }
        }
        afterChange(r, c)
    }

    private func afterChange(_ r: Int, _ c: Int) {
        autoCrossRow(r)
        autoCrossCol(c)
        checkWin()
    }

    private func autoCrossRow(_ r: Int) {
        let line = cells[r].map { $0 == 1 }
        guard Nono.lineMatchesClue(line, puzzle.rowClues[r]) else { return }
        for c in 0..<n where cells[r][c] == 0 { cells[r][c] = 2 }
    }

    private func autoCrossCol(_ c: Int) {
        let line = (0..<n).map { cells[$0][c] == 1 }
        guard Nono.lineMatchesClue(line, puzzle.colClues[c]) else { return }
        for r in 0..<n where cells[r][c] == 0 { cells[r][c] = 2 }
    }

    private func rowSatisfied(_ r: Int) -> Bool {
        Nono.lineMatchesClue(cells[r].map { $0 == 1 }, puzzle.rowClues[r])
    }

    private func colSatisfied(_ c: Int) -> Bool {
        Nono.lineMatchesClue((0..<n).map { cells[$0][c] == 1 }, puzzle.colClues[c])
    }

    private func checkWin() {
        let fill = cells.map { $0.map { $0 == 1 } }
        guard Nono.isSolved(fill, puzzle.bitmap) else { return }
        if !won { Haptic.ok() }
        won = true
        store.win(puzzle.id, time: seconds)
    }

    // ── الأزرار السفليّة ──
    private var controls: some View {
        HStack(spacing: 10) {
            modeToggle
            Button { resetBoard() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 14, weight: .bold))
                    Text("مسح").font(rnd(15, .bold))
                }
                .foregroundStyle(NN.tx2).frame(height: 52).padding(.horizontal, 16).card(NN.s1, 16)
            }
            .buttonStyle(Press())
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            seg(title: "تعبئة", icon: "square.fill", on: !markMode) { markMode = false }
            seg(title: "علّم X", icon: "xmark", on: markMode) { markMode = true }
        }
        .padding(4).background(NN.s1, in: Capsule()).frame(maxWidth: .infinity)
    }

    private func seg(title: String, icon: String, on: Bool, _ act: @escaping () -> Void) -> some View {
        Button {
            act()
            Haptic.tap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(rnd(15, .heavy))
            }
            .foregroundStyle(on ? Color.black.opacity(0.85) : NN.tx2)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(on ? NN.accent : Color.clear, in: Capsule())
        }
        .buttonStyle(Press())
    }

    private func resetBoard() {
        cells = Array(repeating: Array(repeating: 0, count: n), count: n)
        mistakes = 0
        seconds = 0
        dead = false
        won = false
        dragVal = nil
        lastCell = nil
        Haptic.thud()
    }

    private func primaryWin() {
        won = false
        if store.nextAfter(puzzle) != nil {
            onNext()
        } else {
            onClose()
        }
    }

    private func closeAll() {
        won = false
        dead = false
        onClose()
    }

    // ── بذور وضع التصوير ──
    private func seedShot() {
        guard Shot.on else { return }
        if Shot.name == "win" {
            for r in 0..<n {
                for c in 0..<n {
                    cells[r][c] = puzzle.bitmap[r][c] ? 1 : 2
                }
            }
            seconds = 96
            won = true
        } else if Shot.name == "game" {
            var k = 0
            for r in 0..<n {
                for c in 0..<n where puzzle.bitmap[r][c] {
                    k += 1
                    cells[r][c] = (k % 8 == 0) ? 0 : 1
                }
            }
            if n > 1 {
                cells[0][0] = 2
                cells[0][n - 1] = 2
                cells[n - 1][0] = 2
            }
            seconds = 73
            mistakes = 1
        }
    }
}

struct ResultSheet: View {
    let win: Bool
    let puzzle: Puzzle
    let time: Int
    let best: Int?
    let hasNext: Bool
    let onPrimary: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            MiniPreview(puzzle: puzzle, lit: win)
                .frame(width: 168, height: 168)
                .padding(18)
                .card(NN.s1, 26, stroke: (win ? NN.of(puzzle.ink) : NN.bad).opacity(0.4))
                .opacity(win ? 1 : 0.4)
            VStack(spacing: 6) {
                Text(win ? "فزت! 🎉" : "خلصت الأخطاء").font(rnd(30, .black)).foregroundStyle(Color.white)
                Text(win ? puzzle.name : "جرّب من جديد").font(rnd(17, .bold)).foregroundStyle(NN.tx2)
            }
            if win {
                HStack(spacing: 10) {
                    chip("الوقت", mmss(time), "clock", NN.accent)
                    if let b = best {
                        chip("أفضل وقت", mmss(b), "trophy.fill", NN.gold)
                    }
                }
            }
            Spacer()
            Button(action: onPrimary) {
                Text(win ? (hasNext ? "التالي" : "تمام") : "حاول مرّة ثانية")
                    .font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity).frame(height: 56).background(NN.accent, in: Capsule())
            }
            .buttonStyle(Press())
            Button(action: onClose) {
                Text("المراحل").font(rnd(16, .bold)).foregroundStyle(NN.tx2)
                    .frame(maxWidth: .infinity).frame(height: 50)
            }
            .buttonStyle(Press())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NN.bg.ignoresSafeArea())
    }

    private func chip(_ label: String, _ value: String, _ icon: String, _ c: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(c)
            Text(value).font(rnd(20, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
            Text(label).font(rnd(11.5)).foregroundStyle(NN.tx3)
        }
        .padding(14).frame(maxWidth: .infinity).card(NN.s1, 18, stroke: c.opacity(0.25))
    }
}
