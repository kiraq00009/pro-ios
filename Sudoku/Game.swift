import SwiftUI

// ── الحفظ والاستمرار ──────────────────────────────────────────────────────

struct SavedSudoku: Codable {
    var puzzle: [Int]
    var board: [Int]
    var solution: [Int]
    var givens: [Bool]
    var notes: [[Int]]
    var hinted: [Int]
    var mistakes: Int
    var seconds: Int
    var hints: Int
    var diffRaw: Int
    var diff: Difficulty { Difficulty(rawValue: diffRaw) ?? .easy }
}

final class Store: ObservableObject {
    @Published var saved: SavedSudoku? = nil
    @Published var best: [Int: Int] = [:]
    private let ud = UserDefaults.standard

    init() {
        if Shot.on {
            best = [0: 182, 1: 274, 2: 461, 3: 735]
            if Shot.name == "home" {
                let g = Sudoku.generate(seed: 7, difficulty: .hard)
                saved = SavedSudoku(puzzle: g.puzzle, board: g.puzzle, solution: g.solution, givens: g.givens, notes: [[Int]](repeating: [], count: 81), hinted: [], mistakes: 1, seconds: 268, hints: 0, diffRaw: Difficulty.hard.rawValue)
            }
            return
        }
        load()
    }

    private func load() {
        if let d = ud.data(forKey: "sd_saved"), let v = try? JSONDecoder().decode(SavedSudoku.self, from: d) { saved = v }
        if let d = ud.data(forKey: "sd_best"), let v = try? JSONDecoder().decode([Int: Int].self, from: d) { best = v }
    }

    func keep(_ g: SavedSudoku?) {
        saved = g
        if Shot.on { return }
        if let g = g, let d = try? JSONEncoder().encode(g) {
            ud.set(d, forKey: "sd_saved")
        } else {
            ud.removeObject(forKey: "sd_saved")
        }
    }

    func recordWin(diff: Difficulty, seconds: Int) -> Bool {
        let prev = best[diff.rawValue]
        let isRecord = prev == nil || seconds < prev!
        if isRecord { best[diff.rawValue] = seconds }
        if !Shot.on, let d = try? JSONEncoder().encode(best) { ud.set(d, forKey: "sd_best") }
        return isRecord
    }
}

struct GameLaunch: Identifiable {
    let id = UUID()
    let difficulty: Difficulty
    let saved: SavedSudoku?
}

private struct Snap {
    var board: [Int]
    var notes: [Set<Int>]
    var hinted: Set<Int>
    var mistakes: Int
}

// ── شاشة اللعب ──────────────────────────────────────────────────────────────

struct GameView: View {
    let difficulty: Difficulty
    let store: Store
    let close: () -> Void

    @State private var board: [Int]
    @State private var puzzle: [Int]
    @State private var solution: [Int]
    @State private var givens: [Bool]
    @State private var notes: [Set<Int>]
    @State private var hinted: Set<Int>
    @State private var selected: Int? = nil
    @State private var notesMode = false
    @State private var mistakes = 0
    @State private var seconds = 0
    @State private var hints = 0
    @State private var won = false
    @State private var showWin = false
    @State private var paused = false
    @State private var newRecord = false
    @State private var undoStack: [Snap] = []

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(difficulty: Difficulty, saved: SavedSudoku?, store: Store, close: @escaping () -> Void) {
        self.difficulty = difficulty
        self.store = store
        self.close = close
        if let s = saved {
            _board = State(initialValue: s.board)
            _puzzle = State(initialValue: s.puzzle)
            _solution = State(initialValue: s.solution)
            _givens = State(initialValue: s.givens)
            _notes = State(initialValue: s.notes.map { Set($0) })
            _hinted = State(initialValue: Set(s.hinted))
            _mistakes = State(initialValue: s.mistakes)
            _seconds = State(initialValue: s.seconds)
            _hints = State(initialValue: s.hints)
        } else {
            let seed: UInt64 = Shot.on ? 42 : UInt64.random(in: 1...UInt64.max)
            let g = Sudoku.generate(seed: seed, difficulty: difficulty)
            _board = State(initialValue: g.puzzle)
            _puzzle = State(initialValue: g.puzzle)
            _solution = State(initialValue: g.solution)
            _givens = State(initialValue: g.givens)
            _notes = State(initialValue: [Set<Int>](repeating: [], count: 81))
            _hinted = State(initialValue: [])
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            topBar
            statsRow
            boardSquare.padding(.horizontal, 2)
            Spacer(minLength: 4)
            controlRow
            numberPad
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Backdrop())
        .onReceive(tick) { _ in
            if !won && !paused && !Shot.on { seconds += 1 }
        }
        .onAppear {
            if Shot.on { seedDemo() }
        }
        .onDisappear {
            if !won { save() }
        }
        .sheet(isPresented: $showWin) {
            WinSheet(difficulty: difficulty, seconds: seconds, mistakes: mistakes, hints: hints, record: newRecord, again: { restart() }, home: { close() })
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(SD.accent)
        }
    }

    // ── الشريط العلويّ ───────────────────────────────────────────────────────

    private var topBar: some View {
        HStack {
            Button {
                Haptic.tap()
                if !won { save() }
                close()
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .black)).foregroundStyle(SD.tx).frame(width: 42, height: 42).background(SD.s1, in: Circle())
            }
            .buttonStyle(Press())
            Spacer()
            Text(difficulty.title).font(rnd(20, .black)).foregroundStyle(SD.tx)
            Spacer()
            Button {
                Haptic.tap()
                paused.toggle()
            } label: {
                Image(systemName: paused ? "play.fill" : "pause.fill").font(.system(size: 15, weight: .black)).foregroundStyle(SD.tx).frame(width: 42, height: 42).background(SD.s1, in: Circle())
            }
            .buttonStyle(Press())
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill("clock.fill", SD.fmt(seconds), "الوقت")
            statPill("xmark.circle.fill", "\(mistakes)", "أخطاء")
            statPill("lightbulb.fill", "\(hints)", "تلميح")
        }
    }

    private func statPill(_ icon: String, _ v: String, _ l: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(SD.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(v).font(rnd(16, .black)).foregroundStyle(SD.tx).environment(\.layoutDirection, .leftToRight)
                Text(l).font(rnd(10, .semibold)).foregroundStyle(SD.tx3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .card(SD.s1, 14, stroke: SD.lineThin)
    }

    // ── اللوحة ────────────────────────────────────────────────────────────────

    private var boardSquare: some View {
        GeometryReader { geo in
            buildBoard(min(geo.size.width, geo.size.height))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func buildBoard(_ side: CGFloat) -> some View {
        let cell = side / 9
        let cf = Sudoku.conflicts(board)
        let sv = selValue
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { c in
                            cellAt(r * 9 + c, cell: cell, conflicts: cf, selVal: sv)
                        }
                    }
                }
            }
            thickLines(side)
            if paused { pauseCover(side) }
        }
        .frame(width: side, height: side)
        .environment(\.layoutDirection, .leftToRight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(SD.line, lineWidth: 2))
    }

    private func cellAt(_ i: Int, cell: CGFloat, conflicts: Set<Int>, selVal: Int) -> some View {
        let locked = givens[i] || hinted.contains(i)
        let v = board[i]
        let wrong = (!locked && v != 0 && v != solution[i]) || conflicts.contains(i)
        let isSel = selected == i
        let sameNum = selVal != 0 && v == selVal && !isSel
        let peer = isPeerOf(i) && !isSel
        return Button {
            tap(i)
        } label: {
            CellView(value: v, notes: notes[i], locked: locked, hinted: hinted.contains(i), wrong: wrong, selected: isSel, sameNum: sameNum, peer: peer, size: cell)
        }
        .buttonStyle(.plain)
    }

    private func thickLines(_ side: CGFloat) -> some View {
        Path { p in
            for k in 1..<3 {
                let x = side / 3 * CGFloat(k)
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: side))
                p.move(to: CGPoint(x: 0, y: x))
                p.addLine(to: CGPoint(x: side, y: x))
            }
        }
        .stroke(SD.line, lineWidth: 2)
        .allowsHitTesting(false)
    }

    private func pauseCover(_ side: CGFloat) -> some View {
        ZStack {
            SD.bg.opacity(0.96)
            VStack(spacing: 10) {
                Image(systemName: "pause.circle.fill").font(.system(size: 44, weight: .bold)).foregroundStyle(SD.accent)
                Text("إيقاف مؤقّت").font(rnd(20, .black)).foregroundStyle(SD.tx)
                Text("اضغط للاستمرار").font(rnd(13)).foregroundStyle(SD.tx3)
            }
        }
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .onTapGesture { paused = false }
    }

    // ── شريط الأدوات ولوحة الأرقام ─────────────────────────────────────────────

    private var controlRow: some View {
        HStack(spacing: 10) {
            ctrl("arrow.uturn.backward", "تراجع", active: false, enabled: !undoStack.isEmpty) { undo() }
            ctrl("eraser.fill", "امسح", active: false, enabled: true) { erase() }
            ctrl("pencil", "ملاحظات", active: notesMode, enabled: true) { toggleNotes() }
            ctrl("lightbulb.fill", "تلميح", active: false, enabled: true) { hint() }
        }
    }

    private func ctrl(_ icon: String, _ label: String, active: Bool, enabled: Bool, _ act: @escaping () -> Void) -> some View {
        Button {
            act()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(active ? Color.black.opacity(0.82) : SD.tx)
                Text(label).font(rnd(11, .bold)).foregroundStyle(active ? Color.black.opacity(0.7) : SD.tx2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(active ? SD.accent : SD.s1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(SD.lineThin))
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(Press())
        .disabled(!enabled)
    }

    private var numberPad: some View {
        HStack(spacing: 5) {
            ForEach(1...9, id: \.self) { v in padButton(v) }
        }
    }

    private func padButton(_ v: Int) -> some View {
        let left = 9 - board.filter { $0 == v }.count
        let done = left <= 0
        return Button {
            place(v)
        } label: {
            VStack(spacing: 1) {
                Text("\(v)").font(rnd(24, .black)).foregroundStyle(done ? SD.tx3 : SD.accent).environment(\.layoutDirection, .leftToRight)
                Text("\(max(0, left))").font(rnd(9.5, .bold)).foregroundStyle(SD.tx3).environment(\.layoutDirection, .leftToRight)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .card(SD.s1, 13, stroke: SD.lineThin)
            .opacity(done ? 0.45 : 1)
        }
        .buttonStyle(Press())
        .disabled(done)
    }

    // ── الحسابات المساعدة ──────────────────────────────────────────────────────

    private var selValue: Int {
        if let i = selected, board[i] != 0 { return board[i] }
        return 0
    }

    private func isPeerOf(_ i: Int) -> Bool {
        guard let s = selected else { return false }
        if s == i { return false }
        if s / 9 == i / 9 { return true }
        if s % 9 == i % 9 { return true }
        return Sudoku.box(ofIndex: s) == Sudoku.box(ofIndex: i)
    }

    private func isLocked(_ i: Int) -> Bool { givens[i] || hinted.contains(i) }

    // ── الأفعال ────────────────────────────────────────────────────────────────

    private func tap(_ i: Int) {
        if paused { return }
        Haptic.tap()
        selected = i
    }

    private func pushUndo() {
        undoStack.append(Snap(board: board, notes: notes, hinted: hinted, mistakes: mistakes))
        if undoStack.count > 80 { undoStack.removeFirst() }
    }

    private func toggleNotes() {
        Haptic.tap()
        notesMode.toggle()
    }

    private func place(_ v: Int) {
        guard let i = selected, !isLocked(i), !won, !paused else { return }
        if notesMode {
            pushUndo()
            if notes[i].contains(v) { notes[i].remove(v) } else { notes[i].insert(v) }
            Haptic.tap()
            save()
            return
        }
        pushUndo()
        if board[i] == v {
            board[i] = 0
            Haptic.tap()
            save()
            return
        }
        board[i] = v
        notes[i] = []
        if v != solution[i] {
            mistakes += 1
            Haptic.bad()
        } else {
            Haptic.tap()
            clearPeerNotes(i, v)
            checkWin()
        }
        save()
    }

    private func erase() {
        guard let i = selected, !isLocked(i), !won, !paused else { return }
        if board[i] == 0 && notes[i].isEmpty { return }
        pushUndo()
        board[i] = 0
        notes[i] = []
        Haptic.tap()
        save()
    }

    private func undo() {
        guard let s = undoStack.popLast() else { return }
        board = s.board
        notes = s.notes
        hinted = s.hinted
        mistakes = s.mistakes
        Haptic.tap()
        save()
    }

    private func hint() {
        guard !won, !paused else { return }
        var target: Int? = nil
        if let i = selected, !isLocked(i), board[i] == 0 { target = i }
        if target == nil { target = (0..<81).first { board[$0] == 0 } }
        guard let t = target else { return }
        pushUndo()
        board[t] = solution[t]
        notes[t] = []
        hinted.insert(t)
        hints += 1
        selected = t
        clearPeerNotes(t, solution[t])
        Haptic.ok()
        checkWin()
        save()
    }

    private func clearPeerNotes(_ i: Int, _ v: Int) {
        for p in 0..<81 where board[p] == 0 {
            if isPeerIndex(i, p) { notes[p].remove(v) }
        }
    }

    private func isPeerIndex(_ a: Int, _ b: Int) -> Bool {
        if a == b { return false }
        if a / 9 == b / 9 { return true }
        if a % 9 == b % 9 { return true }
        return Sudoku.box(ofIndex: a) == Sudoku.box(ofIndex: b)
    }

    private func checkWin() {
        if board == solution {
            won = true
            newRecord = store.recordWin(diff: difficulty, seconds: seconds)
            store.keep(nil)
            Haptic.ok()
            showWin = true
        }
    }

    private func save() {
        if won || Shot.on { return }
        let n = notes.map { Array($0).sorted() }
        let s = SavedSudoku(puzzle: puzzle, board: board, solution: solution, givens: givens, notes: n, hinted: Array(hinted), mistakes: mistakes, seconds: seconds, hints: hints, diffRaw: difficulty.rawValue)
        store.keep(s)
    }

    private func restart() {
        let seed = UInt64.random(in: 1...UInt64.max)
        let g = Sudoku.generate(seed: seed, difficulty: difficulty)
        board = g.puzzle
        puzzle = g.puzzle
        solution = g.solution
        givens = g.givens
        notes = [Set<Int>](repeating: [], count: 81)
        hinted = []
        selected = nil
        notesMode = false
        mistakes = 0
        seconds = 0
        hints = 0
        won = false
        newRecord = false
        showWin = false
        undoStack = []
        save()
    }

    // ── بيانات العرض للصور ──────────────────────────────────────────────────────

    private func seedDemo() {
        if Shot.name == "win" {
            board = solution
            seconds = 243
            mistakes = 2
            hints = 1
            newRecord = true
            won = true
            selected = nil
            showWin = true
            return
        }
        var b = puzzle
        for i in 0..<81 where b[i] == 0 {
            if (i * 7 + 3) % 5 != 0 { b[i] = solution[i] }
        }
        board = b
        seconds = 324
        mistakes = 1
        hints = 1
        if let e = (0..<81).first(where: { board[$0] == 0 }) {
            notes[e] = [2, 5, 7]
            selected = e
        }
        if Shot.name == "notes" { notesMode = true }
    }
}

// ── خليّة واحدة ──────────────────────────────────────────────────────────────

struct CellView: View {
    let value: Int
    let notes: Set<Int>
    let locked: Bool
    let hinted: Bool
    let wrong: Bool
    let selected: Bool
    let sameNum: Bool
    let peer: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            (locked ? SD.cellGiven : SD.cell)
            highlight
            if value != 0 {
                Text("\(value)").font(rnd(size * 0.52, locked ? .bold : .heavy)).foregroundStyle(digitColor)
            } else if !notes.isEmpty {
                notesView
            }
        }
        .frame(width: size, height: size)
        .overlay(Rectangle().stroke(SD.lineThin, lineWidth: 0.5))
        .contentShape(Rectangle())
    }

    private var highlight: Color {
        if selected { return SD.sel }
        if sameNum { return SD.same }
        if peer { return SD.peer }
        return Color.clear
    }

    private var digitColor: Color {
        if wrong { return SD.bad }
        if hinted { return SD.good }
        if locked { return SD.tx }
        return SD.accent
    }

    private var notesView: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        noteCell(r * 3 + c + 1)
                    }
                }
            }
        }
    }

    private func noteCell(_ n: Int) -> some View {
        Text(notes.contains(n) ? "\(n)" : "")
            .font(rnd(size * 0.22, .semibold))
            .foregroundStyle(SD.tx2)
            .frame(width: size / 3, height: size / 3)
    }
}

// ── شاشة الفوز ───────────────────────────────────────────────────────────────

struct WinSheet: View {
    let difficulty: Difficulty
    let seconds: Int
    let mistakes: Int
    let hints: Int
    let record: Bool
    let again: () -> Void
    let home: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)
            ZStack {
                Circle().fill(SD.accent.opacity(0.18)).frame(width: 112, height: 112)
                Image(systemName: "trophy.fill").font(.system(size: 52, weight: .bold)).foregroundStyle(SD.accent)
            }
            Text("فزت!").font(rnd(36, .black)).foregroundStyle(SD.tx)
            Text("خلّصت لغز " + difficulty.title).font(rnd(14)).foregroundStyle(SD.tx3)
            if record {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles").font(.system(size: 13, weight: .bold))
                    Text("رقم قياسيّ جديد!").font(rnd(13, .heavy))
                }
                .foregroundStyle(Color.black.opacity(0.82))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(SD.accent, in: Capsule())
            }
            HStack(spacing: 10) {
                winStat("clock.fill", SD.fmt(seconds), "الوقت")
                winStat("xmark.circle.fill", "\(mistakes)", "أخطاء")
                winStat("lightbulb.fill", "\(hints)", "تلميح")
            }
            Spacer(minLength: 4)
            Button {
                Haptic.tap()
                again()
            } label: {
                Text("لعبة جديدة").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 56).background(SD.accent, in: Capsule())
            }
            .buttonStyle(Press())
            Button {
                Haptic.tap()
                home()
            } label: {
                Text("القائمة الرئيسيّة").font(rnd(16, .heavy)).foregroundStyle(SD.tx2).frame(maxWidth: .infinity).frame(height: 52).card(SD.s1, 26, stroke: SD.lineThin)
            }
            .buttonStyle(Press())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SD.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func winStat(_ icon: String, _ v: String, _ l: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(SD.accent)
            Text(v).font(rnd(19, .black)).foregroundStyle(SD.tx).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(10.5, .semibold)).foregroundStyle(SD.tx3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card(SD.s1, 16, stroke: SD.lineThin)
    }
}
