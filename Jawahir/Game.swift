import SwiftUI

// MARK: - Game view model + board view for جواهر.
// Mode: LEVEL-TARGET (limited moves, reach a target score to win).

final class GameVM: ObservableObject {

    struct Gem: Identifiable, Equatable {
        let id: Int
        var type: Int
    }

    enum Phase: Equatable { case playing, won, over }

    // Board: 8x8, stable gem ids for smooth animation.
    @Published var grid: [[Gem?]] =
        Array(repeating: Array(repeating: nil, count: JAW_COLS), count: JAW_ROWS)

    @Published var score = 0
    @Published var best = 0
    @Published var moves = 0
    @Published var level = 1
    @Published var target = 0
    @Published var phase: Phase = .playing
    @Published var selected: Cell? = nil
    @Published var busy = false
    @Published var combo = 0
    @Published var flashing: Set<Int> = []   // gem ids currently clearing

    private var nextID = 1
    private var rng = SeededRNG(seed: 0xA11CE)

    private let defMovesPerLevel = 24
    private let saveKey = "jawahir.save.v1"
    private let bestKey = "jawahir.best.v1"

    // MARK: Lifecycle

    init() {
        best = persistedBest()
    }

    func loadBestOnly() {
        best = persistedBest()
    }

    var hasSave: Bool {
        guard !Shot.on else { return false }
        return UserDefaults.standard.dictionary(forKey: saveKey) != nil
    }

    func newGame(level lvl: Int) {
        level = max(1, lvl)
        moves = defMovesPerLevel
        target = targetFor(level)
        score = 0
        combo = 0
        phase = .playing
        selected = nil
        busy = false
        rng = SeededRNG(seed: UInt64(truncatingIfNeeded: Int.random(in: 1...Int.max)))
        let types = Match.fillInitial(seed: freshSeed())
        load(types: types)
        best = persistedBest()
        save()
    }

    private func targetFor(_ lvl: Int) -> Int {
        700 + (lvl - 1) * 450
    }

    // MARK: Board helpers

    private func newGemID() -> Int {
        let v = nextID
        nextID += 1
        return v
    }

    private func randType() -> Int {
        Int(rng.next() % UInt64(JAW_TYPES))
    }

    private func freshSeed() -> UInt64 {
        rng.next()
    }

    private func load(types: [[Int]]) {
        var g: [[Gem?]] = []
        for r in 0..<JAW_ROWS {
            var row: [Gem?] = []
            for c in 0..<JAW_COLS {
                row.append(Gem(id: newGemID(), type: types[r][c]))
            }
            g.append(row)
        }
        grid = g
    }

    func typeGrid() -> [[Int]] {
        grid.map { rowArr in rowArr.map { $0?.type ?? -1 } }
    }

    func gem(_ r: Int, _ c: Int) -> Gem? {
        guard r >= 0, r < JAW_ROWS, c >= 0, c < JAW_COLS else { return nil }
        return grid[r][c]
    }

    func isSelected(_ r: Int, _ c: Int) -> Bool {
        guard let s = selected else { return false }
        return s.r == r && s.c == c
    }

    static func adjacent(_ a: Cell, _ b: Cell) -> Bool {
        abs(a.r - b.r) + abs(a.c - b.c) == 1
    }

    // MARK: Input

    func tap(_ r: Int, _ c: Int) {
        guard !busy, phase == .playing else { return }
        let cell = Cell(r: r, c: c)
        guard let s = selected else {
            selected = cell
            Haptic.tap()
            return
        }
        if s == cell {
            selected = nil
            return
        }
        if GameVM.adjacent(s, cell) {
            selected = nil
            attemptSwap(s, cell)
        } else {
            selected = cell
            Haptic.tap()
        }
    }

    func swipe(_ r: Int, _ c: Int, dx: CGFloat, dy: CGFloat) {
        guard !busy, phase == .playing else { return }
        let a = Cell(r: r, c: c)
        var b = a
        if abs(dx) > abs(dy) {
            // RTL board is drawn LTR internally, so positive dx = screen-right = +col.
            b = Cell(r: r, c: c + (dx > 0 ? 1 : -1))
        } else {
            b = Cell(r: r + (dy > 0 ? 1 : -1), c: c)
        }
        guard b.r >= 0, b.r < JAW_ROWS, b.c >= 0, b.c < JAW_COLS else { return }
        selected = nil
        attemptSwap(a, b)
    }

    // MARK: Swap + resolve

    private func swapGems(_ a: Cell, _ b: Cell) {
        let tmp = grid[a.r][a.c]
        grid[a.r][a.c] = grid[b.r][b.c]
        grid[b.r][b.c] = tmp
    }

    private func attemptSwap(_ a: Cell, _ b: Cell) {
        busy = true
        let types = typeGrid()
        let good = Match.swapWouldMatch(types, a, b)
        if good {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
                swapGems(a, b)
            }
            moves -= 1
            combo = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                self?.resolveStep()
            }
        } else {
            // Illegal: slide over and bounce back.
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
                swapGems(a, b)
            }
            Haptic.bad()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                guard let self = self else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                    self.swapGems(a, b)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    self.busy = false
                }
            }
        }
    }

    private func resolveStep() {
        let types = typeGrid()
        let matches = Match.findMatches(types)
        if matches.isEmpty {
            finishResolve()
            return
        }
        combo += 1
        if combo >= 3 {
            Haptic.thud()
        } else {
            Haptic.ok()
        }
        let gained = matches.count * 10 * combo
        flashing = Set(matches.compactMap { grid[$0.r][$0.c]?.id })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.14)) {
                for cell in matches {
                    self.grid[cell.r][cell.c] = nil
                }
            }
            self.score += gained
            self.flashing = []
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                    self.collapse()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    self.resolveStep()
                }
            }
        }
    }

    private func collapse() {
        for c in 0..<JAW_COLS {
            var survivors: [Gem] = []
            for r in 0..<JAW_ROWS {
                if let g = grid[r][c] { survivors.append(g) }
            }
            let holes = JAW_ROWS - survivors.count
            for r in 0..<JAW_ROWS {
                if r < holes {
                    grid[r][c] = Gem(id: newGemID(), type: randType())
                } else {
                    grid[r][c] = survivors[r - holes]
                }
            }
        }
    }

    private func finishResolve() {
        combo = 0
        // Guard against a dead board.
        if Match.findMatches(typeGrid()).isEmpty, !Match.anyPossibleMove(typeGrid()) {
            reshuffle()
        }
        if score >= target {
            phase = .won
            Haptic.ok()
            updateBest()
            clearSave()
        } else if moves <= 0 {
            phase = .over
            Haptic.bad()
            updateBest()
            clearSave()
        } else {
            save()
        }
        selected = nil
        busy = false
    }

    private func reshuffle() {
        let types = Match.fillInitial(seed: freshSeed())
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            load(types: types)
        }
    }

    func nextLevel() {
        newGame(level: level + 1)
    }

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(score) / Double(target))
    }

    // MARK: Persistence (guarded by !Shot.on)

    private func persistedBest() -> Int {
        guard !Shot.on else { return UserDefaults.standard.integer(forKey: bestKey) }
        return UserDefaults.standard.integer(forKey: bestKey)
    }

    private func updateBest() {
        if score > best {
            best = score
            if !Shot.on {
                UserDefaults.standard.set(best, forKey: bestKey)
            }
        }
    }

    private func save() {
        guard !Shot.on, phase == .playing else { return }
        var flat: [Int] = []
        for r in 0..<JAW_ROWS {
            for c in 0..<JAW_COLS {
                flat.append(grid[r][c]?.type ?? 0)
            }
        }
        let dict: [String: Any] = [
            "types": flat,
            "score": score,
            "moves": moves,
            "level": level,
            "target": target,
        ]
        UserDefaults.standard.set(dict, forKey: saveKey)
    }

    private func clearSave() {
        guard !Shot.on else { return }
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    @discardableResult
    func resume() -> Bool {
        guard !Shot.on,
              let dict = UserDefaults.standard.dictionary(forKey: saveKey),
              let flat = dict["types"] as? [Int],
              flat.count == JAW_ROWS * JAW_COLS else {
            return false
        }
        var types = Array(repeating: Array(repeating: 0, count: JAW_COLS), count: JAW_ROWS)
        for r in 0..<JAW_ROWS {
            for c in 0..<JAW_COLS {
                types[r][c] = flat[r * JAW_COLS + c]
            }
        }
        load(types: types)
        score = dict["score"] as? Int ?? 0
        moves = dict["moves"] as? Int ?? defMovesPerLevel
        level = dict["level"] as? Int ?? 1
        target = dict["target"] as? Int ?? targetFor(level)
        phase = .playing
        selected = nil
        busy = false
        combo = 0
        best = persistedBest()
        // If the restored board happens to be dead, reshuffle.
        if !Match.anyPossibleMove(typeGrid()) {
            reshuffle()
        }
        return true
    }

    // MARK: Screenshot setup

    func setupForShot(_ name: String) {
        level = 3
        target = targetFor(level)
        rng = SeededRNG(seed: 0xD15EA5E)
        let types = Match.fillInitial(seed: 0xBEEF_CAFE)
        load(types: types)
        best = 9_240
        switch name {
        case "win":
            score = target + 180
            moves = 6
            phase = .won
        case "over":
            score = Int(Double(target) * 0.62)
            moves = 0
            phase = .over
        default: // "game"
            score = Int(Double(target) * 0.58)
            moves = 11
            phase = .playing
            // Highlight a lively cluster to suggest a cascade in motion.
            var ids: Set<Int> = []
            for r in 2...3 {
                for c in 2...4 {
                    if let g = gem(r, c) { ids.insert(g.id) }
                }
            }
            flashing = ids
        }
        busy = false
        selected = nil
    }
}

// MARK: - Game screen

struct GameView: View {
    @ObservedObject var vm: GameVM
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            topBar
            scoreBoard
            Spacer(minLength: 2)
            BoardView(vm: vm)
            Spacer(minLength: 2)
            footerBar
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay { overlay }
        .accessibilityIdentifier(vm.phase == .won ? "win" : (vm.phase == .over ? "over" : "game"))
    }

    private var topBar: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "house.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Pal.text)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Pal.surface))
                    .overlay(Circle().stroke(Pal.line, lineWidth: 1))
            }
            .buttonStyle(Press())
            Spacer()
            VStack(spacing: 2) {
                Text("المرحلة").font(rnd(12, .semibold)).foregroundStyle(Pal.sub)
                Num(vm.level).font(rnd(20, .heavy)).foregroundStyle(Pal.accent)
            }
            Spacer()
            Button { vm.newGame(level: vm.level) } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Pal.text)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Pal.surface))
                    .overlay(Circle().stroke(Pal.line, lineWidth: 1))
            }
            .buttonStyle(Press())
        }
    }

    private var scoreBoard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(title: "النقاط", value: vm.score, icon: "star.fill", tint: Pal.accent)
                StatTile(title: "الحركات", value: vm.moves, icon: "hand.tap.fill", tint: Pal.accent2)
                StatTile(title: "الأفضل", value: vm.best, icon: "crown.fill", tint: Pal.good)
            }
            targetBar
        }
    }

    private var targetBar: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "target").foregroundStyle(Pal.accent)
                    Text("الهدف").font(rnd(14, .semibold)).foregroundStyle(Pal.sub)
                }
                Spacer()
                Num(vm.target).font(rnd(15, .bold)).foregroundStyle(Pal.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Pal.surface)
                    Capsule()
                        .fill(LinearGradient(colors: [Pal.accent, Pal.accent2],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * vm.progress))
                }
            }
            .frame(height: 12)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Pal.bg2))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Pal.line, lineWidth: 1))
    }

    private var footerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(Pal.accent)
            Text("بدّل الجواهر وسوّي صفّ من ٣")
                .font(rnd(14, .medium))
                .foregroundStyle(Pal.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Pal.bg2))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Pal.line, lineWidth: 1))
    }

    @ViewBuilder
    private var overlay: some View {
        switch vm.phase {
        case .won:
            EndOverlay(win: true, score: vm.score, best: vm.best,
                       onPrimary: { vm.nextLevel() },
                       onHome: onExit)
        case .over:
            EndOverlay(win: false, score: vm.score, best: vm.best,
                       onPrimary: { vm.newGame(level: vm.level) },
                       onHome: onExit)
        case .playing:
            EmptyView()
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let title: String
    let value: Int
    let icon: String
    let tint: Color
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
                Text(title).font(rnd(12, .semibold)).foregroundStyle(Pal.sub)
            }
            Num(value).font(rnd(24, .heavy)).foregroundStyle(Pal.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Pal.bg2))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Pal.line, lineWidth: 1))
    }
}

// MARK: - Board

struct BoardView: View {
    @ObservedObject var vm: GameVM

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(JAW_COLS)
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Pal.bg2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Pal.line, lineWidth: 1)
                    )
                gridLines(cell: cell, side: side)
                gems(cell: cell)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Keep the playfield left-to-right so coordinates stay stable under RTL.
            .environment(\.layoutDirection, .leftToRight)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func gridLines(cell: CGFloat, side: CGFloat) -> some View {
        ZStack {
            ForEach(0..<JAW_ROWS, id: \.self) { r in
                ForEach(0..<JAW_COLS, id: \.self) { c in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity((r + c) % 2 == 0 ? 0.03 : 0.015))
                        .frame(width: cell - 6, height: cell - 6)
                        .position(x: CGFloat(c) * cell + cell / 2,
                                  y: CGFloat(r) * cell + cell / 2)
                }
            }
        }
    }

    private func gems(cell: CGFloat) -> some View {
        ForEach(placed(), id: \.id) { item in
            GemView(type: item.type,
                    selected: vm.isSelected(item.r, item.c),
                    flashing: vm.flashing.contains(item.id),
                    size: cell)
                .position(x: CGFloat(item.c) * cell + cell / 2,
                          y: CGFloat(item.r) * cell + cell / 2)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.3).combined(with: .opacity)))
                .onTapGesture { vm.tap(item.r, item.c) }
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { g in
                            vm.swipe(item.r, item.c,
                                     dx: g.translation.width, dy: g.translation.height)
                        }
                )
                .zIndex(vm.flashing.contains(item.id) ? 2 : 1)
        }
    }

    private struct Placed: Identifiable {
        let id: Int
        let type: Int
        let r: Int
        let c: Int
    }

    private func placed() -> [Placed] {
        var out: [Placed] = []
        for r in 0..<JAW_ROWS {
            for c in 0..<JAW_COLS {
                if let g = vm.gem(r, c) {
                    out.append(Placed(id: g.id, type: g.type, r: r, c: c))
                }
            }
        }
        return out
    }
}

// MARK: - A single gem

struct GemView: View {
    let type: Int
    let selected: Bool
    let flashing: Bool
    let size: CGFloat

    var body: some View {
        let inset: CGFloat = size * 0.11
        let dim = size - inset * 2
        ZStack {
            RoundedRectangle(cornerRadius: dim * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [GemStyle.color(type).opacity(0.95),
                                 GemStyle.color(type).opacity(0.70)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: dim * 0.28, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                )
                .overlay(highlight(dim: dim))
                .shadow(color: GemStyle.color(type).opacity(selected ? 0.8 : 0.35),
                        radius: selected ? 10 : 4, y: 2)
            Image(systemName: GemStyle.symbol(type))
                .font(.system(size: dim * 0.42, weight: .black))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: dim, height: dim)
        .scaleEffect(flashing ? 1.18 : (selected ? 1.08 : 1.0))
        .overlay(selectionRing(dim: dim))
        .opacity(flashing ? 0.85 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selected)
        .animation(.easeInOut(duration: 0.15), value: flashing)
    }

    private func highlight(dim: CGFloat) -> some View {
        Ellipse()
            .fill(Color.white.opacity(0.22))
            .frame(width: dim * 0.5, height: dim * 0.26)
            .offset(x: -dim * 0.14, y: -dim * 0.22)
            .blur(radius: 1)
    }

    @ViewBuilder
    private func selectionRing(dim: CGFloat) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: dim * 0.28, style: .continuous)
                .stroke(Color.white, lineWidth: 2.5)
                .frame(width: dim, height: dim)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Win / Game over overlay

struct EndOverlay: View {
    let win: Bool
    let score: Int
    let best: Int
    let onPrimary: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: win ? "crown.fill" : "hourglass")
                    .font(.system(size: 54, weight: .black))
                    .foregroundStyle(win ? Pal.accent : Pal.accent2)
                    .shadow(color: (win ? Pal.accent : Pal.accent2).opacity(0.6), radius: 14)
                Text(win ? "فزت!" : "خلصت الحركات")
                    .font(rnd(34, .heavy))
                    .foregroundStyle(Pal.text)
                VStack(spacing: 8) {
                    resultRow("النقاط", score)
                    resultRow("الأفضل", best)
                }
                .padding(.vertical, 6)
                VStack(spacing: 12) {
                    Button(action: onPrimary) {
                        label(win ? "المرحلة الجاية" : "عيدها", primary: true)
                    }
                    .buttonStyle(Press())
                    Button(action: onHome) {
                        label("الصفحة الرئيسية", primary: false)
                    }
                    .buttonStyle(Press())
                }
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Pal.surface))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Pal.line, lineWidth: 1))
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }

    private func resultRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title).font(rnd(16, .semibold)).foregroundStyle(Pal.sub)
            Spacer()
            Num(value).font(rnd(20, .heavy)).foregroundStyle(Pal.text)
        }
        .frame(maxWidth: 220)
    }

    private func label(_ text: String, primary: Bool) -> some View {
        Text(text)
            .font(rnd(19, .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(primary ? Pal.bg : Pal.text)
            .background(bg(primary))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(primary ? Color.clear : Pal.line, lineWidth: 1)
            )
    }

    @ViewBuilder
    private func bg(_ primary: Bool) -> some View {
        if primary {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Pal.accent, Pal.accent2],
                                     startPoint: .leading, endPoint: .trailing))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Pal.bg2)
        }
    }
}
