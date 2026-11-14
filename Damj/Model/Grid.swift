import Foundation

// MARK: - Direction

public enum Move: CaseIterable {
    case up, down, left, right
}

// MARK: - Spawn result

public struct SpawnResult {
    public let grid: [[Int]]
    public let seed: UInt64
    public let placed: Bool
    public let at: (Int, Int)?
}

// MARK: - Pure grid logic (Foundation only, deterministic, fully tested)

public enum Grid {

    /// An empty n x n grid (0 = empty cell).
    public static func empty(_ n: Int) -> [[Int]] {
        Array(repeating: Array(repeating: 0, count: n), count: n)
    }

    /// Ordered coordinate "lines" for a move. Each line is listed from the
    /// side the tiles pile toward (the target side first). Lines partition
    /// every cell of the grid exactly once.
    static func lines(_ n: Int, _ dir: Move) -> [[(Int, Int)]] {
        var res = [[(Int, Int)]]()
        switch dir {
        case .left:
            for r in 0..<n { res.append((0..<n).map { (r, $0) }) }
        case .right:
            for r in 0..<n { res.append((0..<n).reversed().map { (r, $0) }) }
        case .up:
            for c in 0..<n { res.append((0..<n).map { ($0, c) }) }
        case .down:
            for c in 0..<n { res.append((0..<n).reversed().map { ($0, c) }) }
        }
        return res
    }

    /// Classic collapse of a single line toward the front. Each tile merges at
    /// most once per move. Returns the resulting values (padded with zeros),
    /// the score gained, and the output indices that are merge results.
    static func collapse(_ vals: [Int]) -> (out: [Int], score: Int, mergedIdx: [Int]) {
        let nz = vals.filter { $0 != 0 }
        var out = [Int]()
        var score = 0
        var merged = [Int]()
        var i = 0
        while i < nz.count {
            if i + 1 < nz.count && nz[i] == nz[i + 1] {
                let v = nz[i] * 2
                out.append(v)
                score += v
                merged.append(out.count - 1)
                i += 2
            } else {
                out.append(nz[i])
                i += 1
            }
        }
        while out.count < vals.count { out.append(0) }
        return (out, score, merged)
    }

    /// Slide + merge the whole grid in a direction.
    /// Returns the new grid, score gained, whether anything moved, and the
    /// coordinates (in the new grid) where merges landed.
    public static func slide(_ grid: [[Int]], _ dir: Move)
        -> (grid: [[Int]], gained: Int, moved: Bool, merged: [(Int, Int)]) {
        let n = grid.count
        var g = grid
        var gained = 0
        var mergedCoords = [(Int, Int)]()
        for line in lines(n, dir) {
            let vals = line.map { grid[$0.0][$0.1] }
            let r = collapse(vals)
            gained += r.score
            for (k, coord) in line.enumerated() { g[coord.0][coord.1] = r.out[k] }
            for mi in r.mergedIdx { mergedCoords.append(line[mi]) }
        }
        let moved = g != grid
        return (g, gained, moved, mergedCoords)
    }

    /// All empty cells in row-major order.
    public static func emptyCells(_ grid: [[Int]]) -> [(Int, Int)] {
        var res = [(Int, Int)]()
        let n = grid.count
        for r in 0..<n {
            for c in 0..<n where grid[r][c] == 0 { res.append((r, c)) }
        }
        return res
    }

    /// SplitMix64 bit mixer — deterministic from a seed.
    static func mix(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Spawn a new 2 (90%) or 4 (10%) tile into a random empty cell.
    /// Deterministic in `seed`; returns the advanced seed so callers can chain.
    public static func spawn(_ grid: [[Int]], seed: UInt64) -> SpawnResult {
        let cells = emptyCells(grid)
        if cells.isEmpty {
            return SpawnResult(grid: grid, seed: seed, placed: false, at: nil)
        }
        let s1 = mix(seed)
        let idx = Int(s1 % UInt64(cells.count))
        let s2 = mix(s1)
        let value = (s2 % 10 == 0) ? 4 : 2
        var g = grid
        let (r, c) = cells[idx]
        g[r][c] = value
        return SpawnResult(grid: g, seed: s2, placed: true, at: (r, c))
    }

    /// Can any direction change the board?
    public static func canMove(_ grid: [[Int]]) -> Bool {
        for d in Move.allCases where slide(grid, d).moved { return true }
        return false
    }

    public static func isGameOver(_ grid: [[Int]]) -> Bool { !canMove(grid) }

    public static func hasWon(_ grid: [[Int]], target: Int) -> Bool {
        for row in grid {
            for v in row where v >= target { return true }
        }
        return false
    }
}
