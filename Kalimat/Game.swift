import SwiftUI

// ───────────────────────── شاشة اللعب ─────────────────────────

struct FoundLine: Identifiable {
    let id = UUID()
    let cells: [Cell]
    let colorIndex: Int
}

@MainActor
final class GameState: ObservableObject {
    @Published var levelIndex: Int = 0
    @Published var theme: Theme = Levels.themes[0]
    @Published var grid: [[Character]] = []
    @Published var placements: [Placement] = []
    @Published var found: Set<String> = []
    @Published var foundLines: [FoundLine] = []
    @Published var selection: [Cell] = []
    @Published var elapsed = 0
    @Published var won = false
    @Published var hintCell: Cell? = nil

    var size: Int { theme.size }

    init(_ index: Int) { load(index) }

    func load(_ index: Int) {
        let lvl = Levels.level(index)
        let built = lvl.build()
        levelIndex = index
        theme = lvl.theme
        grid = built.grid
        placements = built.placements
        found = []
        foundLines = []
        selection = []
        elapsed = 0
        won = false
        hintCell = nil
        if Shot.on { seedShot() }
    }

    private func seedShot() {
        func add(_ p: Placement) {
            found.insert(p.word)
            foundLines.append(FoundLine(cells: p.cells, colorIndex: theme.words.firstIndex(of: p.word) ?? foundLines.count))
        }
        if Shot.isAny("win") {
            for p in placements { add(p) }
            won = true
            elapsed = 148
        } else {
            let k = min(4, placements.count)
            for i in 0..<k { add(placements[i]) }
            elapsed = 73
        }
    }

    func tick() { if !won && !Shot.on { elapsed += 1 } }

    /// يحوّل خطًّا حرًّا إلى أقرب خطّ مستقيم ضمن الحدود.
    func snap(from a: Cell, to b: Cell) -> [Cell] {
        let dr = b.r - a.r
        let dc = b.c - a.c
        if dr == 0 && dc == 0 { return [a] }
        let adr = abs(dr)
        let adc = abs(dc)
        var ur = 0
        var uc = 0
        if adr > 2 * adc { ur = dr > 0 ? 1 : -1; uc = 0 }
        else if adc > 2 * adr { ur = 0; uc = dc > 0 ? 1 : -1 }
        else { ur = dr > 0 ? 1 : -1; uc = dc > 0 ? 1 : -1 }
        let steps = max(adr, adc)
        var end = 0
        var i = steps
        while i >= 0 {
            let rr = a.r + ur * i
            let cc = a.c + uc * i
            if rr >= 0 && rr < size && cc >= 0 && cc < size { end = i; break }
            i -= 1
        }
        let target = Cell(a.r + ur * end, a.c + uc * end)
        return Search.cellsOnLine(from: a, to: target) ?? [a]
    }

    func updateSelection(from a: Cell, to b: Cell) {
        guard !won, !Shot.on else { return }
        selection = snap(from: a, to: b)
    }

    func endSelection() {
        guard !won, !Shot.on else { selection = []; return }
        defer { selection = [] }
        guard let f = selection.first, let l = selection.last, selection.count >= 2 else { return }
        let remaining = theme.words.filter { !found.contains($0) }
        if let w = Search.matchedWord(grid, from: f, to: l, targets: remaining) {
            found.insert(w)
            let ci = theme.words.firstIndex(of: w) ?? foundLines.count
            let cells = Search.cellsOnLine(from: f, to: l) ?? selection
            foundLines.append(FoundLine(cells: cells, colorIndex: ci))
            Haptic.ok()
            if found.count == theme.words.count { won = true; Haptic.thud() }
        } else {
            Haptic.tap()
        }
    }

    func hint() {
        guard let w = theme.words.first(where: { !found.contains($0) }),
              let p = placements.first(where: { $0.word == w }),
              let c = p.cells.first else { return }
        Haptic.tap()
        hintCell = c
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            Task { @MainActor in if self.hintCell == c { self.hintCell = nil } }
        }
    }
}

// MARK: - الشكل: خطّ تمييز الكلمة

struct LinePath: Shape {
    let cells: [Cell]
    let cell: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let f = cells.first, let l = cells.last else { return p }
        let a = CGPoint(x: (CGFloat(f.c) + 0.5) * cell, y: (CGFloat(f.r) + 0.5) * cell)
        let b = CGPoint(x: (CGFloat(l.c) + 0.5) * cell, y: (CGFloat(l.r) + 0.5) * cell)
        p.move(to: a)
        p.addLine(to: b)
        return p
    }
}

// MARK: - الشاشة

struct GameView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var st: GameState
    let onClose: () -> Void

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(levelIndex: Int, onClose: @escaping () -> Void) {
        _st = StateObject(wrappedValue: GameState(levelIndex))
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 14) {
                topBar
                statusRow
                GridBoard(st: st)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 6)
                wordList
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            if st.won { WinView(st: st, onClose: onClose) }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onReceive(timer) { _ in st.tick() }
        .onChange(of: st.won) { win in
            if win && !Shot.on { app.markSolved(st.levelIndex, time: st.elapsed) }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { Haptic.tap(); onClose() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .black)).foregroundStyle(KL.tx2)
                    .frame(width: 40, height: 40).background(KL.s2, in: Circle())
            }
            .buttonStyle(Press())
            Spacer()
            VStack(spacing: 1) {
                Text("\(st.theme.emoji) \(st.theme.name)").font(rnd(17, .heavy)).foregroundStyle(KL.tx1)
                Text("المرحلة \(st.levelIndex + 1)").font(rnd(11, .bold)).foregroundStyle(KL.tx3)
            }
            Spacer()
            Button(action: { st.hint() }) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(KL.gold)
                    .frame(width: 40, height: 40).background(KL.gold.opacity(0.16), in: Circle())
            }
            .buttonStyle(Press())
            .disabled(st.won)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            StatPill(icon: "clock.fill", text: timeText(st.elapsed), color: KL.orange2)
            StatPill(icon: "checkmark.circle.fill", text: "\(st.found.count) / \(st.theme.words.count)", color: KL.green)
            Spacer()
        }
    }

    private var wordList: some View {
        let cols = [GridItem(.adaptive(minimum: 78), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(Array(st.theme.words.enumerated()), id: \.offset) { pair in
                WordChip(word: pair.element, found: st.found.contains(pair.element), color: KL.mark(pair.offset))
            }
        }
    }

    private func timeText(_ s: Int) -> String {
        let m = s / 60, r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}

struct StatPill: View {
    let icon: String
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
            Text(text).font(rnd(14, .heavy)).foregroundStyle(KL.tx1)
                .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(KL.s2, in: Capsule())
    }
}

struct WordChip: View {
    let word: String
    let found: Bool
    let color: Color
    var body: some View {
        Text(word)
            .font(rnd(14, .bold))
            .strikethrough(found, color: color)
            .foregroundStyle(found ? color : KL.tx1)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(found ? color.opacity(0.14) : KL.s1, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(found ? color.opacity(0.4) : Color.white.opacity(0.06)))
            .opacity(found ? 0.85 : 1)
            .animation(.easeOut(duration: 0.2), value: found)
    }
}

// MARK: - اللوحة

struct GridBoard: View {
    @ObservedObject var st: GameState

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(max(1, st.size))
            ZStack(alignment: .topLeading) {
                tiles(cell)
                linesLayer(cell)
                letters(cell)
            }
            .frame(width: side, height: side)
            .background(KL.s1.opacity(0.5), in: RoundedRectangle(cornerRadius: cell * 0.3, style: .continuous))
            .contentShape(Rectangle())
            .gesture(drag(cell))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func center(_ r: Int, _ c: Int, _ cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(c) + 0.5) * cell, y: (CGFloat(r) + 0.5) * cell)
    }

    private func tiles(_ cell: CGFloat) -> some View {
        ForEach(Array(0..<(st.size * st.size)), id: \.self) { k in
            let r = k / st.size
            let c = k % st.size
            RoundedRectangle(cornerRadius: cell * 0.22, style: .continuous)
                .fill(KL.s2)
                .frame(width: cell - 3, height: cell - 3)
                .position(center(r, c, cell))
        }
    }

    @ViewBuilder
    private func linesLayer(_ cell: CGFloat) -> some View {
        let w = cell * 0.74
        ForEach(st.foundLines) { fl in
            LinePath(cells: fl.cells, cell: cell)
                .stroke(KL.mark(fl.colorIndex).opacity(0.40), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
        if !st.selection.isEmpty {
            LinePath(cells: st.selection, cell: cell)
                .stroke(KL.orange.opacity(0.5), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
    }

    private func letters(_ cell: CGFloat) -> some View {
        ForEach(Array(0..<(st.size * st.size)), id: \.self) { k in
            let r = k / st.size
            let c = k % st.size
            cellLetter(r, c, cell)
        }
    }

    @ViewBuilder
    private func cellLetter(_ r: Int, _ c: Int, _ cell: CGFloat) -> some View {
        let isHint = st.hintCell == Cell(r, c)
        Text(String(letterAt(r, c)))
            .font(rnd(cell * 0.46, .heavy))
            .foregroundStyle(isHint ? KL.bg : KL.tx1)
            .frame(width: cell, height: cell)
            .background(
                Circle().fill(KL.gold).frame(width: cell * 0.82, height: cell * 0.82).opacity(isHint ? 1 : 0)
            )
            .scaleEffect(isHint ? 1.12 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHint)
            .position(center(r, c, cell))
    }

    private func letterAt(_ r: Int, _ c: Int) -> Character {
        guard r >= 0, r < st.grid.count, c >= 0, c < st.grid[r].count else { return " " }
        return st.grid[r][c]
    }

    private func drag(_ cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let a = cellAt(v.startLocation, cell)
                let b = cellAt(v.location, cell)
                st.updateSelection(from: a, to: b)
            }
            .onEnded { _ in st.endSelection() }
    }

    private func cellAt(_ p: CGPoint, _ cell: CGFloat) -> Cell {
        let c = Int(p.x / cell)
        let r = Int(p.y / cell)
        let cc = min(st.size - 1, max(0, c))
        let rr = min(st.size - 1, max(0, r))
        return Cell(rr, cc)
    }
}

// MARK: - شاشة الفوز

struct WinView: View {
    @ObservedObject var st: GameState
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🏆").font(.system(size: 64))
                Text("فزت!").font(rnd(34, .black)).foregroundStyle(KL.gold)
                Text("لگّيت كلّ كلمات \(st.theme.name)")
                    .font(rnd(15, .semibold)).foregroundStyle(KL.tx2)
                HStack(spacing: 10) {
                    StatPill(icon: "clock.fill", text: timeText(st.elapsed), color: KL.orange2)
                    StatPill(icon: "star.fill", text: "\(st.theme.words.count) كلمات", color: KL.green)
                }
                .padding(.top, 2)
                VStack(spacing: 10) {
                    Button(action: nextLevel) {
                        Label("المرحلة التالية", systemImage: "arrow.left.circle.fill")
                            .font(rnd(17, .heavy)).foregroundStyle(KL.bg)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LinearGradient(colors: [KL.orange2, KL.orange], startPoint: .top, endPoint: .bottom),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(Press())
                    Button(action: { Haptic.tap(); onClose() }) {
                        Text("للرئيسيّة")
                            .font(rnd(15, .bold)).foregroundStyle(KL.tx2)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(KL.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(Press())
                }
                .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .card(KL.s1, 26, stroke: KL.gold.opacity(0.3))
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }

    private func nextLevel() {
        Haptic.thud()
        st.load(min(st.levelIndex + 1, Levels.count - 1))
    }

    private func timeText(_ s: Int) -> String {
        let m = s / 60, r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}
