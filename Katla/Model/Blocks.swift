import Foundation

// ── منطق لعبة «كتلة» خالص (بلا SwiftUI) — قابل للاختبار وحتميّ
// لوح 8×8، قطع بولي-أومينو، مسح الصفوف والأعمدة الممتلئة، نقاط وكومبو.

/// خليّة نسبيّة داخل القطعة أو مطلقة على اللوح
public struct Cell: Equatable, Hashable, Codable {
    public var r: Int
    public var c: Int
    public init(r: Int, c: Int) { self.r = r; self.c = c }
}

/// قطعة قابلة للسحب: نوع الشكل + لون + خلايا منسّقة (أعلى-يسار = 0,0)
public struct Piece: Equatable, Codable, Identifiable {
    public var id: Int        // رقم فريد لكلّ نسخة (ثبات أثناء السحب)
    public var kind: Int      // الفهرس داخل Blocks.shapes
    public var color: Int     // 1...colorCount
    public var cells: [Cell]  // خلايا نسبيّة منسّقة

    public init(id: Int, kind: Int, color: Int, cells: [Cell]) {
        self.id = id; self.kind = kind; self.color = color; self.cells = cells
    }
    public var w: Int { (cells.map { $0.c }.max() ?? 0) + 1 }
    public var h: Int { (cells.map { $0.r }.max() ?? 0) + 1 }
    public var size: Int { cells.count }
}

/// مولّد أرقام شبه-عشوائيّ حتميّ (SplitMix64)
public struct SMRng {
    public var state: UInt64
    public init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    public mutating func int(_ n: Int) -> Int { n <= 0 ? 0 : Int(next() % UInt64(n)) }
}

public enum Blocks {
    public static let N = 8
    public static let colorCount = 6

    // ── مكتبة الأشكال: تُقرأ من شبكات نصّيّة مرّة واحدة وتُنسّق
    private static func parse(_ rows: [String]) -> [Cell] {
        var cells: [Cell] = []
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() where ch == "X" {
                cells.append(Cell(r: r, c: c))
            }
        }
        let mr = cells.map { $0.r }.min() ?? 0
        let mc = cells.map { $0.c }.min() ?? 0
        return cells.map { Cell(r: $0.r - mr, c: $0.c - mc) }
    }

    private static let grids: [[String]] = [
        ["X"],                                   // 1 مفردة
        ["XX"],                                  // 2 أفقيّ
        ["X", "X"],                              // عموديّ 2
        ["XXX"],                                 // 3 أفقيّ
        ["X", "X", "X"],                         // عموديّ 3
        ["XXXX"],                                // 4 أفقيّ
        ["X", "X", "X", "X"],                    // عموديّ 4
        ["XXXXX"],                               // 5 أفقيّ
        ["X", "X", "X", "X", "X"],               // عموديّ 5
        ["X.", "XX"],                            // زاوية صغيرة
        ["XX", "X."],
        ["XX", ".X"],
        [".X", "XX"],
        ["XX", "XX"],                            // مربّع 2×2
        ["XXX", ".X."],                          // T
        [".X.", "XXX"],
        [".X", "XX", ".X"],
        ["X.", "XX", "X."],
        [".XX", "XX."],                          // S
        ["XX.", ".XX"],                          // Z
        ["X.", "XX", ".X"],                      // S عموديّ
        [".X", "XX", "X."],                      // Z عموديّ
        ["X.", "X.", "XX"],                      // L
        ["XXX", "X.."],
        ["XX", ".X", ".X"],
        ["..X", "XXX"],
        [".X", ".X", "XX"],                      // J
        ["X..", "XXX"],
        ["XX", "X.", "X."],
        ["XXX", "..X"],
        [".X.", "XXX", ".X."],                   // زائد +
        ["XXX", "XXX"],                          // 2×3
        ["XX", "XX", "XX"],                      // 3×2
        ["XXX", "XXX", "XXX"],                   // 3×3 ممتلئ
        ["X..", "X..", "XXX"],                   // زاوية كبيرة
        ["XXX", "X..", "X.."],
        ["XXX", "..X", "..X"],
        ["..X", "..X", "XXX"],
        ["X.X", "XXX"],                          // U
        ["XXX", "X.X"],                          // U مقلوب
    ]

    /// كلّ الأشكال كخلايا منسّقة (40 شكلًا)
    public static let shapes: [[Cell]] = grids.map { parse($0) }

    public static func empty() -> [[Int]] {
        Array(repeating: Array(repeating: 0, count: N), count: N)
    }

    /// صنع قطعة من فهرس شكل
    public static func piece(kind: Int, id: Int, color: Int) -> Piece {
        let k = ((kind % shapes.count) + shapes.count) % shapes.count
        let col = max(1, min(colorCount, color))
        return Piece(id: id, kind: k, color: col, cells: shapes[k])
    }

    /// هل تنطبق القطعة على اللوح عند (r0,c0)؟ ترفض التجاوز والخلايا المشغولة
    public static func canPlace(_ board: [[Int]], _ piece: Piece, atRow r0: Int, atCol c0: Int) -> Bool {
        for cell in piece.cells {
            let r = r0 + cell.r
            let c = c0 + cell.c
            if r < 0 || r >= N || c < 0 || c >= N { return false }
            if board[r][c] != 0 { return false }
        }
        return true
    }

    /// تضع القطعة وترجّع لوحًا جديدًا (الأصل لا يتغيّر)
    public static func place(_ board: [[Int]], _ piece: Piece, atRow r0: Int, atCol c0: Int) -> [[Int]] {
        var b = board
        for cell in piece.cells {
            let r = r0 + cell.r
            let c = c0 + cell.c
            if r >= 0 && r < N && c >= 0 && c < N { b[r][c] = piece.color }
        }
        return b
    }

    /// تمسح كلّ الصفوف والأعمدة الممتلئة دفعة واحدة (تُحسب من اللوح الأصليّ)
    public static func clearLines(_ board: [[Int]]) -> (board: [[Int]], cleared: Int, cells: [Cell]) {
        var fullRows: [Int] = []
        var fullCols: [Int] = []
        for r in 0..<N where board[r].allSatisfy({ $0 != 0 }) { fullRows.append(r) }
        for c in 0..<N where (0..<N).allSatisfy({ board[$0][c] != 0 }) { fullCols.append(c) }

        var keys = Set<Int>()
        for r in fullRows { for c in 0..<N { keys.insert(r * N + c) } }
        for c in fullCols { for r in 0..<N { keys.insert(r * N + c) } }

        var b = board
        var cells: [Cell] = []
        for key in keys {
            let r = key / N
            let c = key % N
            b[r][c] = 0
            cells.append(Cell(r: r, c: c))
        }
        cells.sort { $0.r == $1.r ? $0.c < $1.c : $0.r < $1.r }
        return (b, fullRows.count + fullCols.count, cells)
    }

    /// هل أكو مكان لأيّ قطعة من المجموعة؟
    public static func anyMoveAvailable(_ board: [[Int]], _ pieces: [Piece]) -> Bool {
        for p in pieces {
            if p.h > N || p.w > N || p.cells.isEmpty { continue }
            for r in 0...(N - p.h) {
                for c in 0...(N - p.w) {
                    if canPlace(board, p, atRow: r, atCol: c) { return true }
                }
            }
        }
        return false
    }

    /// هل تنطبق هذي القطعة بأيّ مكان؟
    public static func canPlaceAnywhere(_ board: [[Int]], _ piece: Piece) -> Bool {
        anyMoveAvailable(board, [piece])
    }

    /// توزيع ثلاث قطع حتميًّا حسب البذرة
    public static func dealPieces(seed: UInt64, startId: Int = 0) -> [Piece] {
        var rng = SMRng(seed: seed)
        var out: [Piece] = []
        for i in 0..<3 {
            let k = rng.int(shapes.count)
            let col = rng.int(colorCount) + 1
            out.append(piece(kind: k, id: startId + i, color: col))
        }
        return out
    }

    // ── النقاط
    /// نقطة لكلّ خليّة توضع
    public static func placeScore(_ piece: Piece) -> Int { piece.size }

    /// نقاط المسح: أساس لكلّ خطّ + مكافأة الخطوط المتعدّدة + مكافأة التتابع (كومبو)
    public static func clearScore(lines: Int, combo: Int) -> Int {
        guard lines > 0 else { return 0 }
        let base = lines * 10
        let multi = lines > 1 ? (lines - 1) * 10 : 0
        let streak = combo > 1 ? (combo - 1) * 5 : 0
        return base + multi + streak
    }

    /// عدد الخلايا المشغولة
    public static func filled(_ board: [[Int]]) -> Int {
        var n = 0
        for row in board { for v in row where v != 0 { n += 1 } }
        return n
    }
}
