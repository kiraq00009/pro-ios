import Foundation

// MARK: - Pure match-3 logic (no SwiftUI). Deterministic + fully testable.

/// Board geometry.
public let JAW_ROWS = 8
public let JAW_COLS = 8
public let JAW_TYPES = 6   // gem ids 0..5 ; -1 means empty

/// A single board position.
public struct Cell: Hashable {
    public let r: Int
    public let c: Int
    public init(r: Int, c: Int) { self.r = r; self.c = c }
}

/// One gem sliding down a column during gravity.
public struct Movement: Equatable {
    public let col: Int
    public let fromRow: Int
    public let toRow: Int
    public init(col: Int, fromRow: Int, toRow: Int) {
        self.col = col; self.fromRow = fromRow; self.toRow = toRow
    }
}

// MARK: - Deterministic RNG (splitmix64-style). Same seed -> same board.

public struct SeededRNG: RandomNumberGenerator {
    public var state: UInt64
    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }
    public mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Advance a seed to an independent, well-mixed next seed.
@inline(__always)
public func jawNextSeed(_ s: UInt64) -> UInt64 {
    var z = s &+ 0x9E37_79B9_7F4A_7C15
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
}

// MARK: - Core engine

public enum Match {

    /// All cells that belong to a horizontal or vertical run of length >= 3.
    /// Overlapping L / T shapes are returned as the union of both runs.
    public static func findMatches(_ grid: [[Int]]) -> Set<Cell> {
        var result = Set<Cell>()
        let rows = grid.count
        guard rows > 0 else { return result }
        let cols = grid[0].count
        guard cols > 0 else { return result }

        // Horizontal runs
        for r in 0..<rows {
            var c = 0
            while c < cols {
                let v = grid[r][c]
                if v < 0 { c += 1; continue }
                var end = c + 1
                while end < cols && grid[r][end] == v { end += 1 }
                if end - c >= 3 {
                    for cc in c..<end { result.insert(Cell(r: r, c: cc)) }
                }
                c = end
            }
        }
        // Vertical runs
        for c in 0..<cols {
            var r = 0
            while r < rows {
                let v = grid[r][c]
                if v < 0 { r += 1; continue }
                var end = r + 1
                while end < rows && grid[end][c] == v { end += 1 }
                if end - r >= 3 {
                    for rr in r..<end { result.insert(Cell(r: rr, c: c)) }
                }
                r = end
            }
        }
        return result
    }

    /// Is the gem at (r,c) part of a run of 3+ through that cell?
    public static func hasMatchAt(_ grid: [[Int]], _ r: Int, _ c: Int) -> Bool {
        let rows = grid.count
        guard rows > 0 else { return false }
        let cols = grid[0].count
        guard r >= 0, r < rows, c >= 0, c < cols else { return false }
        let v = grid[r][c]
        if v < 0 { return false }

        // Horizontal count through (r,c)
        var count = 1
        var cc = c - 1
        while cc >= 0 && grid[r][cc] == v { count += 1; cc -= 1 }
        cc = c + 1
        while cc < cols && grid[r][cc] == v { count += 1; cc += 1 }
        if count >= 3 { return true }

        // Vertical count through (r,c)
        count = 1
        var rr = r - 1
        while rr >= 0 && grid[rr][c] == v { count += 1; rr -= 1 }
        rr = r + 1
        while rr < rows && grid[rr][c] == v { count += 1; rr += 1 }
        return count >= 3
    }

    /// Would swapping the two cells create a new match? (non-destructive)
    public static func swapWouldMatch(_ grid: [[Int]], _ a: Cell, _ b: Cell) -> Bool {
        let rows = grid.count
        guard rows > 0 else { return false }
        let cols = grid[0].count
        guard a.r >= 0, a.r < rows, a.c >= 0, a.c < cols,
              b.r >= 0, b.r < rows, b.c >= 0, b.c < cols else { return false }
        if grid[a.r][a.c] < 0 || grid[b.r][b.c] < 0 { return false }

        var g = grid
        let tmp = g[a.r][a.c]
        g[a.r][a.c] = g[b.r][b.c]
        g[b.r][b.c] = tmp
        return hasMatchAt(g, a.r, a.c) || hasMatchAt(g, b.r, b.c)
    }

    /// Drop every gem down its column over the -1 holes. Returns the new grid
    /// and the list of gem movements (useful for animation).
    public static func applyGravity(_ grid: [[Int]]) -> (grid: [[Int]], movements: [Movement]) {
        var g = grid
        let rows = g.count
        guard rows > 0 else { return (g, []) }
        let cols = g[0].count
        var moves: [Movement] = []

        for c in 0..<cols {
            var writeRow = rows - 1
            var readRow = rows - 1
            while readRow >= 0 {
                if g[readRow][c] >= 0 {
                    if writeRow != readRow {
                        g[writeRow][c] = g[readRow][c]
                        g[readRow][c] = -1
                        moves.append(Movement(col: c, fromRow: readRow, toRow: writeRow))
                    }
                    writeRow -= 1
                }
                readRow -= 1
            }
        }
        return (g, moves)
    }

    /// Fill every -1 hole with a fresh gem, top-to-bottom, deterministically.
    public static func refill(_ grid: [[Int]], seed: UInt64) -> [[Int]] {
        var g = grid
        let rows = g.count
        guard rows > 0 else { return g }
        let cols = g[0].count
        var rng = SeededRNG(seed: seed)
        for r in 0..<rows {
            for c in 0..<cols {
                if g[r][c] < 0 {
                    g[r][c] = Int(rng.next() % UInt64(JAW_TYPES))
                }
            }
        }
        return g
    }

    /// Repeatedly match -> clear -> gravity -> refill until the board is stable.
    /// Returns the settled grid, the total number of cleared cells, and how
    /// many cascade steps happened.
    public static func fullResolve(_ grid: [[Int]], seed: UInt64)
        -> (grid: [[Int]], totalCleared: Int, cascades: Int) {
        var g = grid
        var total = 0
        var cascades = 0
        var s = seed
        while true {
            let m = findMatches(g)
            if m.isEmpty { break }
            total += m.count
            cascades += 1
            for cell in m { g[cell.r][cell.c] = -1 }
            g = applyGravity(g).grid
            s = jawNextSeed(s)
            g = refill(g, seed: s)
        }
        return (g, total, cascades)
    }

    /// Is there at least one adjacent swap that would create a match?
    public static func anyPossibleMove(_ grid: [[Int]]) -> Bool {
        let rows = grid.count
        guard rows > 0 else { return false }
        let cols = grid[0].count
        for r in 0..<rows {
            for c in 0..<cols {
                if c + 1 < cols,
                   swapWouldMatch(grid, Cell(r: r, c: c), Cell(r: r, c: c + 1)) {
                    return true
                }
                if r + 1 < rows,
                   swapWouldMatch(grid, Cell(r: r, c: c), Cell(r: r + 1, c: c)) {
                    return true
                }
            }
        }
        return false
    }

    /// Build a starting board (8x8) with NO pre-existing matches and at least
    /// one possible move. Deterministic for a given seed.
    public static func fillInitial(seed: UInt64) -> [[Int]] {
        var rng = SeededRNG(seed: seed)
        var guardCount = 0
        while true {
            guardCount += 1
            var g = Array(repeating: Array(repeating: -1, count: JAW_COLS), count: JAW_ROWS)
            for r in 0..<JAW_ROWS {
                for c in 0..<JAW_COLS {
                    var choices = Array(0..<JAW_TYPES)
                    // Avoid completing a horizontal triple to the left.
                    if c >= 2, g[r][c - 1] == g[r][c - 2] {
                        let bad = g[r][c - 1]
                        choices.removeAll { $0 == bad }
                    }
                    // Avoid completing a vertical triple above.
                    if r >= 2, g[r - 1][c] == g[r - 2][c] {
                        let bad = g[r - 1][c]
                        choices.removeAll { $0 == bad }
                    }
                    let idx = Int(rng.next() % UInt64(choices.count))
                    g[r][c] = choices[idx]
                }
            }
            if findMatches(g).isEmpty && anyPossibleMove(g) {
                return g
            }
            // Safety valve: extremely unlikely, but never spin forever.
            if guardCount > 10_000 {
                // Reshuffle fallback guaranteed to have a move: build a known-good board.
                return fallbackBoard()
            }
        }
    }

    /// A hand-built 8x8 board: no matches, and guaranteed at least one move.
    private static func fallbackBoard() -> [[Int]] {
        // A simple striped pattern has no 3-in-a-row; then nudge one cell to
        // guarantee a legal move exists.
        var g = Array(repeating: Array(repeating: 0, count: JAW_COLS), count: JAW_ROWS)
        for r in 0..<JAW_ROWS {
            for c in 0..<JAW_COLS {
                g[r][c] = (r + c) % JAW_TYPES
            }
        }
        // Create a near-match so a single swap completes a triple.
        // Rows 0..2 col0 become type pattern that a swap can line up.
        g[0][0] = 1; g[1][0] = 2; g[2][0] = 1
        g[0][1] = 2; g[1][1] = 1; g[2][1] = 2
        // Now swapping (1,0)<->(1,1) makes col0 = 1,1,1.
        return g
    }
}
