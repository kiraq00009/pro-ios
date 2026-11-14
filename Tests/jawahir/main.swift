import Foundation

// Standalone test runner for the Jawahir match-3 engine.
// Builds with: swiftc -O Jawahir/Model/*.swift Tests/jawahir/main.swift

var failures: [String] = []

func check(_ cond: Bool, _ msg: String) {
    if !cond { failures.append(msg) }
}

// MARK: findMatches - horizontal

do {
    // Row 0 has a run of 3 of type 2 at cols 1..3.
    var g = Array(repeating: Array(repeating: 0, count: 8), count: 8)
    g[0][1] = 2; g[0][2] = 2; g[0][3] = 2
    // Break surrounding cells so only this run exists.
    g[0][0] = 1; g[0][4] = 1; g[0][5] = 3; g[0][6] = 1; g[0][7] = 3
    for c in 0..<8 { if c % 2 == 0 { g[1][c] = 4 } else { g[1][c] = 5 } }
    for r in 2..<8 { for c in 0..<8 { g[r][c] = ((r + c) % 2 == 0) ? 4 : 5 } }
    let m = Match.findMatches(g)
    check(m.contains(Cell(r: 0, c: 1)), "h-match missing (0,1)")
    check(m.contains(Cell(r: 0, c: 2)), "h-match missing (0,2)")
    check(m.contains(Cell(r: 0, c: 3)), "h-match missing (0,3)")
    check(!m.contains(Cell(r: 0, c: 0)), "h-match wrongly includes (0,0)")
    check(!m.contains(Cell(r: 0, c: 4)), "h-match wrongly includes (0,4)")
}

// MARK: findMatches - vertical

do {
    // Hand-built 6x4 board: only col 2 rows 1..3 (type 5) is a match.
    let g: [[Int]] = [
        [0, 1, 0, 1],
        [1, 0, 5, 0],
        [0, 1, 5, 1],
        [1, 0, 5, 0],
        [0, 1, 0, 1],
        [1, 0, 1, 0],
    ]
    let m = Match.findMatches(g)
    check(m.contains(Cell(r: 1, c: 2)), "v-match missing (1,2)")
    check(m.contains(Cell(r: 2, c: 2)), "v-match missing (2,2)")
    check(m.contains(Cell(r: 3, c: 2)), "v-match missing (3,2)")
    check(!m.contains(Cell(r: 0, c: 2)), "v-match wrongly includes (0,2)")
}

// MARK: 3 is a match, 2 is not

do {
    var g = Array(repeating: Array(repeating: -1, count: 5), count: 3)
    for r in 0..<3 { for c in 0..<5 { g[r][c] = ((r + c) % 2 == 0) ? 0 : 1 } }
    // A pair only (length 2) of type 3.
    g[0][0] = 3; g[0][1] = 3; g[0][2] = 0
    let m2 = Match.findMatches(g)
    check(!m2.contains(Cell(r: 0, c: 0)), "length-2 should NOT be a match")
    // Extend to length 3.
    g[0][2] = 3
    let m3 = Match.findMatches(g)
    check(m3.contains(Cell(r: 0, c: 0)) && m3.contains(Cell(r: 0, c: 2)),
          "length-3 should be a match")
}

// MARK: L / T overlap (shared cell counted once, both arms present)

do {
    // Build a T: horizontal run of 3 across the top, vertical run of 3 hanging
    // from the middle. All type 7-> use type 2.
    var g = Array(repeating: Array(repeating: 0, count: 5), count: 5)
    // Fill background so nothing else matches.
    for r in 0..<5 { for c in 0..<5 { g[r][c] = ((r * 2 + c) % 3) + 3 } } // types 3,4,5
    let t = 2
    g[0][1] = t; g[0][2] = t; g[0][3] = t   // horizontal arm
    g[1][2] = t; g[2][2] = t                 // vertical arm (plus shared (0,2))
    // Ensure neighbors differ.
    g[0][0] = 3; g[0][4] = 4
    g[1][1] = 3; g[1][3] = 4
    g[2][1] = 4; g[2][3] = 3
    let m = Match.findMatches(g)
    check(m.contains(Cell(r: 0, c: 1)) && m.contains(Cell(r: 0, c: 3)),
          "T-overlap horizontal arm missing")
    check(m.contains(Cell(r: 1, c: 2)) && m.contains(Cell(r: 2, c: 2)),
          "T-overlap vertical arm missing")
    check(m.contains(Cell(r: 0, c: 2)), "T-overlap shared cell missing")
    check(m.count == 5, "T-overlap should contain exactly 5 cells, got \(m.count)")
}

// MARK: swapWouldMatch true / false

do {
    var g = Array(repeating: Array(repeating: 0, count: 5), count: 5)
    for r in 0..<5 { for c in 0..<5 { g[r][c] = ((r + c) % 2 == 0) ? 0 : 1 } }
    // Set up so swapping (1,0)<->(1,1) makes col 1 = type 2 vertically.
    g[0][1] = 2; g[2][1] = 2
    g[1][0] = 2; g[1][1] = 0
    check(Match.swapWouldMatch(g, Cell(r: 1, c: 0), Cell(r: 1, c: 1)),
          "swapWouldMatch should be TRUE for a move that lines up a vertical triple")
    // A swap that changes nothing useful should be false.
    var g2 = Array(repeating: Array(repeating: -1, count: 5), count: 5)
    for r in 0..<5 { for c in 0..<5 { g2[r][c] = ((r * 2 + c) % 3) } }
    // Make absolutely sure no accidental triple is produced for this specific swap:
    // pick two isolated distinct cells.
    g2[0][0] = 0; g2[0][1] = 1
    g2[0][2] = 2; g2[1][0] = 2; g2[1][1] = 0
    g2[2][0] = 1; g2[2][1] = 2
    let before = Match.swapWouldMatch(g2, Cell(r: 0, c: 0), Cell(r: 0, c: 1))
    check(before == false, "swapWouldMatch should be FALSE when no triple forms")
}

// MARK: applyGravity drops gems and leaves -1 on top

do {
    var g = Array(repeating: Array(repeating: -1, count: 3), count: 4)
    // Column 0: gems at rows 0 and 2, holes at 1 and 3.
    g[0][0] = 5
    g[2][0] = 3
    let (ng, moves) = Match.applyGravity(g)
    // After gravity column 0 should have the two gems at the bottom (rows 2,3).
    check(ng[3][0] == 3, "gravity: bottom gem should be type 3 at (3,0)")
    check(ng[2][0] == 5, "gravity: next gem should be type 5 at (2,0)")
    check(ng[0][0] == -1 && ng[1][0] == -1, "gravity: top cells should be empty")
    check(!moves.isEmpty, "gravity: should report movements")
}

// MARK: fullResolve clears the right count and cascades

do {
    // Craft a board where a single existing horizontal triple clears, then the
    // refill is deterministic. We only assert on the guaranteed first clear and
    // that it reaches a stable (match-free) state.
    var g = Array(repeating: Array(repeating: -1, count: 8), count: 8)
    for r in 0..<8 { for c in 0..<8 { g[r][c] = ((r * 3 + c * 5) % 6) } }
    // Guarantee at least one triple in the starting board at row 7 cols 0..2.
    g[7][0] = 2; g[7][1] = 2; g[7][2] = 2
    // Make sure neighbors of that run differ so the run is exactly length 3.
    g[7][3] = 3
    let hadMatch = !Match.findMatches(g).isEmpty
    check(hadMatch, "fullResolve setup should start with a match")
    let (fg, cleared, cascades) = Match.fullResolve(g, seed: 12345)
    check(cleared >= 3, "fullResolve should clear at least the first triple, got \(cleared)")
    check(cascades >= 1, "fullResolve should run at least one cascade")
    check(Match.findMatches(fg).isEmpty, "fullResolve must leave a match-free board")
    check(fg.count == 8 && fg[0].count == 8, "fullResolve must preserve board size")
    // No empties left after full resolve.
    var anyEmpty = false
    for r in 0..<8 { for c in 0..<8 { if fg[r][c] < 0 { anyEmpty = true } } }
    check(!anyEmpty, "fullResolve must leave a completely filled board")
}

// MARK: anyPossibleMove detects a board with / without a move

do {
    // Board WITH a move: a near-triple.
    var g = Array(repeating: Array(repeating: 0, count: 5), count: 5)
    for r in 0..<5 { for c in 0..<5 { g[r][c] = ((r + c) % 2 == 0) ? 0 : 1 } }
    g[0][1] = 2; g[2][1] = 2; g[1][0] = 2
    check(Match.anyPossibleMove(g), "anyPossibleMove should be TRUE here")

    // Board WITHOUT a move: the diagonal pattern (r+c)%3. Any 3 consecutive in a
    // row or column are three distinct values, and no single swap can line up a
    // triple (proven by the mod-3 structure) -> a genuinely dead board.
    var dead = Array(repeating: Array(repeating: 0, count: 6), count: 6)
    for r in 0..<6 { for c in 0..<6 { dead[r][c] = (r + c) % 3 } }
    check(Match.findMatches(dead).isEmpty, "dead board should have no matches")
    check(!Match.anyPossibleMove(dead), "dead board should have NO possible move")
}

// MARK: fillInitial - no matches, >=1 move, deterministic

do {
    let a = Match.fillInitial(seed: 99)
    let b = Match.fillInitial(seed: 99)
    check(a == b, "fillInitial must be deterministic for a given seed")
    check(a.count == 8 && a[0].count == 8, "fillInitial must be 8x8")
    check(Match.findMatches(a).isEmpty, "fillInitial must have no pre-existing matches")
    check(Match.anyPossibleMove(a), "fillInitial must have at least one possible move")
    // A few more seeds to be safe.
    for s in UInt64(1)...UInt64(40) {
        let board = Match.fillInitial(seed: s &* 2654435761)
        check(Match.findMatches(board).isEmpty, "fillInitial seed \(s): unexpected match")
        check(Match.anyPossibleMove(board), "fillInitial seed \(s): no possible move")
        // range check
        for row in board { for v in row { check(v >= 0 && v < 6, "gem out of range") } }
    }
}

// MARK: seeded self-play - many valid swaps, invariants hold

do {
    var g = Match.fillInitial(seed: 0xABCDEF)
    var seed: UInt64 = 0x1234_5678
    var turns = 0
    var totalCleared = 0

    func findAMove(_ grid: [[Int]]) -> (Cell, Cell)? {
        for r in 0..<8 {
            for c in 0..<8 {
                if c + 1 < 8, Match.swapWouldMatch(grid, Cell(r: r, c: c), Cell(r: r, c: c + 1)) {
                    return (Cell(r: r, c: c), Cell(r: r, c: c + 1))
                }
                if r + 1 < 8, Match.swapWouldMatch(grid, Cell(r: r, c: c), Cell(r: r + 1, c: c)) {
                    return (Cell(r: r, c: c), Cell(r: r + 1, c: c))
                }
            }
        }
        return nil
    }

    for _ in 0..<300 {
        guard let (a, b) = findAMove(g) else {
            // No move: reshuffle deterministically (as the game would).
            seed = jawNextSeed(seed)
            g = Match.fillInitial(seed: seed)
            continue
        }
        // Perform the swap.
        let tmp = g[a.r][a.c]; g[a.r][a.c] = g[b.r][b.c]; g[b.r][b.c] = tmp
        check(Match.findMatches(g).isEmpty == false, "self-play: swap should create a match")
        seed = jawNextSeed(seed)
        let (ng, cleared, cascades) = Match.fullResolve(g, seed: seed)
        check(cleared >= 3, "self-play: a resolved swap must clear >=3")
        check(cascades >= 1, "self-play: a resolved swap must cascade >=1")
        check(Match.findMatches(ng).isEmpty, "self-play: board must be stable after resolve")
        // Invariant: board size + fully filled + in-range.
        check(ng.count == 8 && ng[0].count == 8, "self-play: board size invariant")
        for r in 0..<8 {
            for c in 0..<8 {
                check(ng[r][c] >= 0 && ng[r][c] < 6, "self-play: gem out of range / empty")
            }
        }
        g = ng
        totalCleared += cleared
        turns += 1
    }
    check(turns >= 50, "self-play: should sustain many turns, got \(turns)")
    check(totalCleared >= 150, "self-play: should clear many gems over the run")
}

// MARK: - Result

if failures.isEmpty {
    print("ALL JAWAHIR TESTS PASSED")
    exit(0)
} else {
    print("FAILURES (\(failures.count)):")
    for f in failures { print("  - \(f)") }
    exit(1)
}
