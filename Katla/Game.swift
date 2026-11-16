import SwiftUI

// ── نموذج اللعبة: اللوح + الصينيّة + النقاط + المسح + الحفظ

struct FlashCell: Identifiable {
    let id: Int
    let r: Int
    let c: Int
    let color: Color
}

struct Snapshot: Codable {
    var board: [[Int]]
    var tray: [Piece?]
    var score: Int
    var combo: Int
    var nextId: Int
}

@MainActor
final class GameModel: ObservableObject {
    @Published var board: [[Int]] = Blocks.empty()
    @Published var tray: [Piece?] = [nil, nil, nil]
    @Published var score = 0
    @Published var best = 0
    @Published var combo = 0
    @Published var over = false
    @Published var flash: [FlashCell] = []
    @Published var gain: Int = 0
    @Published var gainTick = 0

    private var nextId = 0
    private var prev: Snapshot?
    @Published var canUndo = false

    static let saveKey = "kt_game"
    private let ud = UserDefaults.standard

    init() {
        best = ud.integer(forKey: "kt_best")
        if Shot.on {
            seedShot()
            return
        }
        if let s = GameModel.loadSnapshot() {
            board = s.board; tray = s.tray; score = s.score; combo = s.combo; nextId = s.nextId
            if !hasAnyMove() { over = true }
        } else {
            newGame()
        }
    }

    // ── دورة اللعب
    func newGame() {
        board = Blocks.empty()
        score = 0
        combo = 0
        over = false
        flash = []
        prev = nil
        canUndo = false
        nextId = 0
        deal()
        persist()
    }

    private var trayPieces: [Piece] { tray.compactMap { $0 } }

    private func deal() {
        var g = SystemRandomNumberGenerator()
        let seed = UInt64.random(in: 0...UInt64.max, using: &g)
        let ps = Blocks.dealPieces(seed: seed, startId: nextId)
        nextId += 3
        tray = ps.map { Optional($0) }
    }

    func canPlaceSlotAnywhere(_ slot: Int) -> Bool {
        guard let p = tray[slot] else { return false }
        return Blocks.canPlaceAnywhere(board, p)
    }

    private func hasAnyMove() -> Bool { Blocks.anyMoveAvailable(board, trayPieces) }

    /// محاولة وضع قطعة الصينيّة في الخليّة (r,c) = أعلى-يسار القطعة
    @discardableResult
    func place(slot: Int, row: Int, col: Int) -> Bool {
        guard slot >= 0, slot < 3, let p = tray[slot] else { return false }
        guard Blocks.canPlace(board, p, atRow: row, atCol: col) else { return false }

        // لقطة للتراجع
        prev = Snapshot(board: board, tray: tray, score: score, combo: combo, nextId: nextId)
        canUndo = true

        var b = Blocks.place(board, p, atRow: row, atCol: col)
        tray[slot] = nil
        var earned = Blocks.placeScore(p)

        let cl = Blocks.clearLines(b)
        if cl.cleared > 0 {
            combo += 1
            earned += Blocks.clearScore(lines: cl.cleared, combo: combo)
            // ومضة الخلايا الممسوحة قبل اختفائها
            var fl: [FlashCell] = []
            for (i, cell) in cl.cells.enumerated() {
                fl.append(FlashCell(id: nextFlashId(i), r: cell.r, c: cell.c, color: KT.block(b[cell.r][cell.c])))
            }
            b = cl.board
            Haptic.ok()
            if Shot.on {
                flash = []
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { flash = fl }
                let delay = 0.28
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    withAnimation(.easeOut(duration: 0.18)) { self?.flash = [] }
                }
            }
        } else {
            combo = 0
            Haptic.thud()
        }

        board = b
        score += earned
        gain = earned
        gainTick += 1
        if score > best {
            best = score
            if !Shot.on { ud.set(best, forKey: "kt_best") }
        }

        if trayPieces.isEmpty { deal() }

        if !hasAnyMove() {
            over = true
            canUndo = false
            Haptic.bad()
            GameModel.clearSaved()
        } else {
            persist()
        }
        return true
    }

    private var flashCounter = 0
    private func nextFlashId(_ i: Int) -> Int { flashCounter += 1; return flashCounter }

    func undo() {
        guard let s = prev else { return }
        board = s.board; tray = s.tray; score = s.score; combo = s.combo; nextId = s.nextId
        over = false
        prev = nil
        canUndo = false
        persist()
    }

    // ── الحفظ
    func persist() {
        guard !Shot.on, !over else { return }
        let s = Snapshot(board: board, tray: tray, score: score, combo: combo, nextId: nextId)
        if let d = try? JSONEncoder().encode(s) { ud.set(d, forKey: GameModel.saveKey) }
    }

    static func loadSnapshot() -> Snapshot? {
        guard let d = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: d)
    }

    static var hasSavedGame: Bool {
        guard let s = loadSnapshot() else { return false }
        return Blocks.filled(s.board) > 0 || s.score > 0
    }

    static func clearSaved() { UserDefaults.standard.removeObject(forKey: saveKey) }

    // ── بذر شاشات التصوير
    private func seedShot() {
        best = 4820
        var b = Blocks.empty()
        let fill: [(Int, Int, Int)] = [
            (0, 0, 2), (0, 1, 2), (0, 2, 6), (0, 5, 4), (0, 6, 4),
            (1, 0, 2), (1, 2, 6), (1, 3, 6), (1, 5, 4), (1, 6, 3), (1, 7, 3),
            (2, 1, 1), (2, 2, 1), (2, 5, 5), (2, 6, 3),
            (3, 0, 3), (3, 1, 1), (3, 6, 5), (3, 7, 5),
            (4, 0, 3), (4, 3, 2), (4, 4, 2), (4, 7, 6),
            (5, 2, 4), (5, 3, 2), (5, 6, 1), (5, 7, 6),
            (6, 2, 4), (6, 3, 4), (6, 5, 1), (6, 6, 1),
            (7, 0, 5), (7, 1, 5), (7, 5, 3), (7, 6, 3), (7, 7, 3),
        ]
        for (r, c, v) in fill { b[r][c] = v }
        board = b
        score = 2360
        tray = [
            Optional(Blocks.piece(kind: 14, id: 0, color: 1)),   // T
            Optional(Blocks.piece(kind: 13, id: 1, color: 3)),   // مربّع 2×2
            Optional(Blocks.piece(kind: 3, id: 2, color: 5)),    // 3 أفقيّ
        ]
        combo = 2

        if Shot.name == "over" {
            // لوح شبه ممتلئ بثقوب مفردة متباعدة لا تقبل أيّ قطعة بالصينيّة
            var f = Array(repeating: Array(repeating: 2, count: Blocks.N), count: Blocks.N)
            let holes = [(0, 0), (0, 3), (0, 6), (2, 1), (2, 4), (2, 7), (4, 0), (4, 3), (4, 6), (6, 1), (6, 4), (6, 7), (7, 2), (7, 5)]
            var k = 1
            for (r, c) in holes { f[r][c] = 0; f[r][(c + 1) % Blocks.N] = ((k % 5) + 1); k += 1 }
            // لوّن المصفوفة قليلًا للمنظر
            for r in 0..<Blocks.N { for c in 0..<Blocks.N where f[r][c] != 0 { f[r][c] = ((r + c) % 6) + 1 } }
            for (r, c) in holes { f[r][c] = 0 }
            board = f
            tray = [
                Optional(Blocks.piece(kind: 13, id: 0, color: 2)),   // 2×2
                Optional(Blocks.piece(kind: 1, id: 1, color: 4)),    // دومينو
                Optional(Blocks.piece(kind: 33, id: 2, color: 6)),   // 3×3
            ]
            score = 3180
            over = true
        }
    }
}

// ── مفتاح لالتقاط إطار اللوح
private struct BoardRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var m = GameModel()

    @State private var boardRect: CGRect = .zero
    @State private var dragSlot: Int? = nil
    @State private var dragLoc: CGPoint = .zero

    private let N = Blocks.N

    private var cell: CGFloat { boardRect.width > 0 ? boardRect.width / CGFloat(N) : 40 }
    private let lift: CGFloat = 70

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 6)
                boardView
                    .padding(.horizontal, 14)
                Spacer(minLength: 10)
                trayView
                    .padding(.bottom, 18)
            }
            dragOverlay
            if m.over {
                overScreen
            }
        }
        .coordinateSpace(name: "root")
        .onPreferenceChange(BoardRectKey.self) { boardRect = $0 }
        .onAppear {
            if Shot.name == "over" { m.over = true }
        }
    }

    // ── الشريط العلويّ
    private var topBar: some View {
        HStack(spacing: 12) {
            Button { m.persist(); dismiss() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(KT.s2, in: Circle())
            }
            .buttonStyle(Press())

            VStack(spacing: 1) {
                Text("النقاط").font(rnd(12, .heavy)).foregroundStyle(KT.tx3)
                Num(m.score).font(rnd(30, .black)).foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.25), value: m.score)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) { gainBadge }

            VStack(spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: "trophy.fill").font(.system(size: 10)).foregroundStyle(KT.gold)
                    Text("الأفضل").font(rnd(12, .heavy)).foregroundStyle(KT.tx3)
                }
                Num(m.best).font(rnd(17, .black)).foregroundStyle(KT.gold)
            }
            .frame(width: 70)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .overlay(alignment: .bottomTrailing) { undoButton }
    }

    @ViewBuilder private var gainBadge: some View {
        if m.gain > 0 {
            Text("+\(m.gain)")
                .font(rnd(15, .black))
                .foregroundStyle(KT.green)
                .environment(\.layoutDirection, .leftToRight)
                .id(m.gainTick)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .offset(y: -18)
        }
    }

    @ViewBuilder private var undoButton: some View {
        if m.canUndo && !m.over {
            Button { m.undo() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 12, weight: .black))
                    Text("تراجع").font(rnd(12, .heavy))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).frame(height: 32)
                .background(KT.s2, in: Capsule())
            }
            .buttonStyle(Press())
            .padding(.trailing, 16)
            .padding(.bottom, -6)
        }
    }

    // ── اللوح
    private var boardView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cs = side / CGFloat(N)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(KT.s1)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(white: 1, opacity: 0.06)))
                boardCells(cs)
                flashLayer(cs)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                GeometryReader { g in
                    Color.clear.preference(key: BoardRectKey.self, value: g.frame(in: .named("root")))
                }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func boardCells(_ cs: CGFloat) -> some View {
        let proj = projection()
        return ZStack(alignment: .topLeading) {
            ForEach(0..<N, id: \.self) { r in
                ForEach(0..<N, id: \.self) { c in
                    cellView(r, c, cs, proj)
                        .frame(width: cs, height: cs)
                        .offset(x: CGFloat(c) * cs, y: CGFloat(r) * cs)
                }
            }
        }
        .frame(width: cs * CGFloat(N), height: cs * CGFloat(N), alignment: .topLeading)
    }

    @ViewBuilder
    private func cellView(_ r: Int, _ c: Int, _ cs: CGFloat, _ proj: Projection) -> some View {
        let key = r * N + c
        let v = m.board[r][c]
        let ghost = proj.cells.contains(key)
        let willClear = proj.clear.contains(key)
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(v == 0 ? AnyShapeStyle(KT.hole) : AnyShapeStyle(KT.block(v).gradient))
                .overlay {
                    if v != 0 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }
                }
            if ghost {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((proj.valid ? proj.color : KT.ac2).opacity(willClear ? 0.95 : 0.55))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.5), lineWidth: willClear ? 2 : 1))
            }
        }
        .padding(1.5)
    }

    private func flashLayer(_ cs: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(m.flash) { f in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
                    .frame(width: cs - 3, height: cs - 3)
                    .offset(x: CGFloat(f.c) * cs + 1.5, y: CGFloat(f.r) * cs + 1.5)
                    .shadow(color: f.color, radius: 8)
            }
        }
        .frame(width: cs * CGFloat(N), height: cs * CGFloat(N), alignment: .topLeading)
        .allowsHitTesting(false)
    }

    // ── الصينيّة (ثلاث قطع)
    private var trayView: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { slot in
                traySlot(slot)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 120)
    }

    @ViewBuilder
    private func traySlot(_ slot: Int) -> some View {
        let piece = m.tray[slot]
        let dragging = dragSlot == slot
        let placeable = m.canPlaceSlotAnywhere(slot)
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(KT.s1.opacity(0.7))
            if let p = piece {
                PieceView(piece: p, cell: trayCell(p), color: KT.block(p.color))
                    .opacity(dragging ? 0 : (placeable ? 1 : 0.4))
                    .scaleEffect(dragging ? 0.9 : 1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .overlay {
            if piece != nil && !placeable && !dragging {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(KT.ac2)
                    .padding(6)
                    .background(KT.s2, in: Circle())
                    .offset(x: 0, y: -36)
            }
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(slot: slot))
    }

    private func trayCell(_ p: Piece) -> CGFloat {
        let maxDim = CGFloat(max(p.w, p.h))
        return min(26, 92 / max(1, maxDim))
    }

    private func dragGesture(slot: Int) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("root"))
            .onChanged { value in
                if m.tray[slot] == nil { return }
                if dragSlot != slot { dragSlot = slot }
                dragLoc = value.location
            }
            .onEnded { value in
                defer { dragSlot = nil }
                guard m.tray[slot] != nil else { return }
                dragLoc = value.location
                let proj = projection()
                if proj.valid {
                    _ = m.place(slot: slot, row: proj.row, col: proj.col)
                }
            }
    }

    // ── القطعة الطائرة أثناء السحب
    @ViewBuilder private var dragOverlay: some View {
        if let slot = dragSlot, let p = m.tray[slot] {
            let cs = cell
            let pw = CGFloat(p.w) * cs
            let ph = CGFloat(p.h) * cs
            PieceView(piece: p, cell: cs, color: KT.block(p.color))
                .frame(width: pw, height: ph)
                .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
                .position(x: dragLoc.x, y: dragLoc.y - lift)
                .allowsHitTesting(false)
        }
    }

    // ── الإسقاط: مكان هبوط القطعة والخلايا اللي تنمسح
    private struct Projection {
        var cells: Set<Int> = []
        var clear: Set<Int> = []
        var valid = false
        var color: Color = .white
        var row = 0
        var col = 0
    }

    private func projection() -> Projection {
        guard let slot = dragSlot, let p = m.tray[slot], boardRect.width > 0 else { return Projection() }
        let cs = cell
        let pw = CGFloat(p.w) * cs
        let ph = CGFloat(p.h) * cs
        let anchorX = dragLoc.x - pw / 2
        let anchorY = (dragLoc.y - lift) - ph / 2
        let col = Int((anchorX - boardRect.minX) / cs + 0.5)
        let row = Int((anchorY - boardRect.minY) / cs + 0.5)

        var pr = Projection()
        pr.row = row; pr.col = col
        pr.color = KT.block(p.color)
        let valid = Blocks.canPlace(m.board, p, atRow: row, atCol: col)
        pr.valid = valid
        if valid {
            var b = m.board
            for cell in p.cells {
                let rr = row + cell.r
                let cc = col + cell.c
                pr.cells.insert(rr * N + cc)
                b[rr][cc] = p.color
            }
            // أيّ خطوط تمتلي؟
            for r in 0..<N where b[r].allSatisfy({ $0 != 0 }) {
                for c in 0..<N { pr.clear.insert(r * N + c) }
            }
            for c in 0..<N where (0..<N).allSatisfy({ b[$0][c] != 0 }) {
                for r in 0..<N { pr.clear.insert(r * N + c) }
            }
        } else {
            // بيّن مكان القطعة بالأحمر إذا كانت داخل حدود اللوح جزئيًّا
            for cell in p.cells {
                let rr = row + cell.r
                let cc = col + cell.c
                if rr >= 0 && rr < N && cc >= 0 && cc < N { pr.cells.insert(rr * N + cc) }
            }
        }
        return pr
    }

    // ── شاشة نهاية اللعبة
    private var overScreen: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(KT.gold)
                Text("خلصت اللعبة").font(rnd(30, .black)).foregroundStyle(.white)
                VStack(spacing: 10) {
                    overStat("النقاط", m.score, KT.ac)
                    overStat("الأفضل", m.best, KT.gold)
                }
                if m.score >= m.best && m.score > 0 {
                    Text("رقم قياسيّ جديد! 🎉").font(rnd(15, .heavy)).foregroundStyle(KT.green)
                }
                VStack(spacing: 11) {
                    Button { m.newGame() } label: {
                        Text("لعبة جديدة").font(rnd(18, .black)).foregroundStyle(.black.opacity(0.85))
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(LinearGradient(colors: [KT.gold, KT.ac], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    }
                    .buttonStyle(Press())
                    Button { dismiss() } label: {
                        Text("رجوع للرئيسيّة").font(rnd(16, .heavy)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(KT.s2, in: Capsule())
                    }
                    .buttonStyle(Press())
                }
                .padding(.top, 4)
            }
            .padding(26)
            .frame(maxWidth: 360)
            .card(KT.s1, 28, stroke: KT.ac.opacity(0.3))
            .padding(26)
        }
        .transition(.opacity)
    }

    private func overStat(_ label: String, _ value: Int, _ c: Color) -> some View {
        HStack {
            Text(label).font(rnd(15, .heavy)).foregroundStyle(KT.tx2)
            Spacer()
            Num(value).font(rnd(24, .black)).foregroundStyle(c)
        }
        .padding(.horizontal, 18).frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(KT.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// رسم قطعة كشبكة مربّعات
struct PieceView: View {
    let piece: Piece
    let cell: CGFloat
    let color: Color
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(piece.cells.enumerated()), id: \.offset) { _, cl in
                RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                    .fill(color.gradient)
                    .overlay(RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .frame(width: cell - 2.5, height: cell - 2.5)
                    .offset(x: CGFloat(cl.c) * cell + 1.25, y: CGFloat(cl.r) * cell + 1.25)
            }
        }
        .frame(width: CGFloat(piece.w) * cell, height: CGFloat(piece.h) * cell, alignment: .topLeading)
    }
}
