import Foundation

var failures = 0

func check(_ cond: Bool, _ msg: String) {
    if cond {
        print("PASS: \(msg)")
    } else {
        print("FAIL: \(msg)")
        failures += 1
    }
}

func eq(_ a: [Int], _ b: [Int]) -> Bool { a == b }
func coordKey(_ c: [(Int, Int)]) -> Set<String> { Set(c.map { "\($0.0),\($0.1)" }) }
func isPow2(_ v: Int) -> Bool { v > 0 && (v & (v - 1)) == 0 }

// MARK: - collapse exact merge rules

do {
    let a = Grid.collapse([2, 2, 0, 0])
    check(eq(a.out, [4, 0, 0, 0]) && a.score == 4 && a.mergedIdx == [0],
          "[2,2,0,0] -> [4,0,0,0] score 4")

    let b = Grid.collapse([2, 2, 2, 0])
    check(eq(b.out, [4, 2, 0, 0]) && b.score == 4,
          "[2,2,2,0] -> [4,2,0,0]")

    let c = Grid.collapse([2, 2, 2, 2])
    check(eq(c.out, [4, 4, 0, 0]) && c.score == 8 && c.mergedIdx == [0, 1],
          "[2,2,2,2] -> [4,4,0,0] score 8")

    let d = Grid.collapse([4, 4, 8, 0])
    check(eq(d.out, [8, 8, 0, 0]) && d.score == 8,
          "[4,4,8,0] -> [8,8,0,0] score 8")
}

// MARK: - no double merge (a merged tile does not merge again this move)

do {
    // [4,4,4,4] -> 8,8 (NOT 16). The two 8s must not chain.
    let a = Grid.collapse([4, 4, 4, 4])
    check(eq(a.out, [8, 8, 0, 0]) && a.score == 16, "no double merge: [4,4,4,4] -> [8,8,0,0]")

    // [2,2,4,0] -> 4,4 (the fresh 4 must not merge with the existing 4)
    let b = Grid.collapse([2, 2, 4, 0])
    check(eq(b.out, [4, 4, 0, 0]) && b.score == 4, "no chain: [2,2,4,0] -> [4,4,0,0]")

    // compaction with a gap
    let e = Grid.collapse([2, 0, 2, 0])
    check(eq(e.out, [4, 0, 0, 0]) && e.score == 4, "gap compaction: [2,0,2,0] -> [4,0,0,0]")
}

// MARK: - all four directions consistent (via slide on a real grid)

do {
    // A column that should collapse upward / downward.
    var g = Grid.empty(4)
    g[0][1] = 2; g[1][1] = 2; g[2][1] = 4
    let up = Grid.slide(g, .up)
    check(up.grid[0][1] == 4 && up.grid[1][1] == 4 && up.grid[2][1] == 0 && up.gained == 4,
          "up collapses column toward top")

    let down = Grid.slide(g, .down)
    check(down.grid[3][1] == 4 && down.grid[2][1] == 4 && down.grid[1][1] == 0 && down.gained == 4,
          "down collapses column toward bottom")

    var h = Grid.empty(4)
    h[2][0] = 2; h[2][1] = 2; h[2][3] = 8
    let left = Grid.slide(h, .left)
    check(eq(left.grid[2], [4, 8, 0, 0]) && left.gained == 4, "left collapses row toward left")

    let right = Grid.slide(h, .right)
    check(eq(right.grid[2], [0, 0, 4, 8]) && right.gained == 4, "right collapses row toward right")

    // merged coord reported correctly for a left move
    check(coordKey(left.merged) == Set(["2,0"]), "merged coord reported for left move")
}

// MARK: - moved flag

do {
    var g = Grid.empty(4)
    g[0][0] = 4; g[0][1] = 2   // already packed left, no merge
    check(Grid.slide(g, .left).moved == false, "left on already-packed row does not move")
    check(Grid.slide(g, .right).moved == true, "right on that row moves")
}

// MARK: - spawn: only into empty cells, deterministic with seed

do {
    let g = Grid.empty(4)
    let s1 = Grid.spawn(g, seed: 12345)
    let s2 = Grid.spawn(g, seed: 12345)
    check(s1.placed && s1.at != nil, "spawn places on empty grid")
    check(s1.at! == s2.at! && s1.grid == s2.grid && s1.seed == s2.seed,
          "spawn deterministic with same seed")

    // placed value is 2 or 4
    let v = s1.grid[s1.at!.0][s1.at!.1]
    check(v == 2 || v == 4, "spawned value is 2 or 4")

    // full grid -> cannot place
    let full = Array(repeating: Array(repeating: 2, count: 4), count: 4)
    check(Grid.spawn(full, seed: 7).placed == false, "no spawn into full grid")

    // spawn always targets an empty cell of a partial grid
    var p = Grid.empty(4)
    for r in 0..<4 { for c in 0..<4 where !(r == 3 && c == 3) { p[r][c] = 2 } }
    let sp = Grid.spawn(p, seed: 99)
    check(sp.at! == (3, 3), "spawn targets the only empty cell")
}

// MARK: - game over only when no move changes the board

do {
    // checkerboard of 2/4 with no equal neighbours and no empties -> game over
    var dead = Grid.empty(4)
    for r in 0..<4 { for c in 0..<4 { dead[r][c] = ((r + c) % 2 == 0) ? 2 : 4 } }
    check(Grid.isGameOver(dead), "checkerboard with no merges is game over")

    // same but one pair adjacent -> not over
    var alive = dead
    alive[0][0] = 4; alive[0][1] = 4
    check(!Grid.isGameOver(alive), "adjacent equal tiles -> not game over")

    // empty cell -> not over
    var withEmpty = dead
    withEmpty[1][1] = 0
    check(!Grid.isGameOver(withEmpty), "an empty cell -> not game over")
}

// MARK: - win detection at target

do {
    var g = Grid.empty(4)
    check(!Grid.hasWon(g, target: 2048), "fresh grid has not won")
    g[2][2] = 2048
    check(Grid.hasWon(g, target: 2048), "2048 tile -> won")
    g[2][2] = 1024
    check(!Grid.hasWon(g, target: 2048), "1024 has not won at target 2048")
}

// MARK: - long seeded self-play keeps invariants and terminates

do {
    var g = Grid.empty(4)
    var seed: UInt64 = 0xDEADBEEF
    // start with two tiles
    for _ in 0..<2 {
        let s = Grid.spawn(g, seed: seed); g = s.grid; seed = s.seed
    }
    let dirs: [Move] = [.left, .up, .right, .down]
    var ok = true
    var terminated = false
    var prevCount = 0

    func tileCount(_ grid: [[Int]]) -> Int { grid.flatMap { $0 }.filter { $0 != 0 }.count }
    func allPow2(_ grid: [[Int]]) -> Bool { grid.flatMap { $0 }.allSatisfy { $0 == 0 || isPow2($0) } }

    for step in 0..<4000 {
        if Grid.isGameOver(g) { terminated = true; break }
        // pick first direction (rotating) that actually moves
        var applied = false
        for k in 0..<4 {
            let d = dirs[(step + k) % 4]
            let r = Grid.slide(g, d)
            if r.moved {
                let before = tileCount(g)
                g = r.grid
                let afterMove = tileCount(g)
                // a move never increases tile count and keeps grid square
                if afterMove > before || g.count != 4 || g.contains(where: { $0.count != 4 }) { ok = false }
                let sp = Grid.spawn(g, seed: seed)
                g = sp.grid; seed = sp.seed
                let afterSpawn = tileCount(g)
                // spawn adds exactly one tile when a cell was free
                if sp.placed && afterSpawn != afterMove + 1 { ok = false }
                prevCount = afterSpawn
                applied = true
                break
            }
        }
        if !allPow2(g) { ok = false }
        if !ok { break }
        if !applied { terminated = true; break }
    }
    _ = prevCount
    check(ok, "self-play: values stay powers of two, tiles never illegally gained")
    check(terminated, "self-play terminates (reaches game over or no move)")
    check(allPow2(g), "self-play final board is all powers of two")
}

// MARK: - result

if failures == 0 {
    print("ALL DAMJ TESTS PASSED")
    exit(0)
} else {
    print("FAILURES: \(failures)")
    exit(1)
}
