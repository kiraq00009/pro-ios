import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── توليد الطوابق: كلّ شي موصول وينوصله
for s in 0..<150 {
    let c = Cave(seed: UInt64(s) &* 7919 &+ 1)
    check(c.tiles.count == Cave.W * Cave.H, "size")
    let d = c.bfs(from: c.hero.pos)
    let exit = c.tiles.firstIndex(of: .exit)
    check(exit != nil && d[exit ?? 0] < 999 && d[exit ?? 0] >= 4, "seed \(s): exit unreachable or too close")
    for (p, _) in c.items { check(c.tiles[p] != .wall && d[p] < 999, "seed \(s): item unreachable") }
    for m in c.mons { check(c.tiles[m.pos] != .wall && d[m.pos] < 999 && m.pos != c.hero.pos, "seed \(s): monster misplaced") }
    check(Set(c.mons.map { $0.pos }).count == c.mons.count, "seed \(s): monsters overlap")
    check(c.mons.count >= 3 && c.lit[c.hero.pos] && c.seen[c.hero.pos], "seed \(s): start state")
    for x in 0..<Cave.W { check(c.tiles[x] == .wall && c.tiles[(Cave.H - 1) * Cave.W + x] == .wall, "border") }
    check(Cave(seed: UInt64(s) &* 7919 &+ 1).tiles == c.tiles, "deterministic")
}

// ── قواعد أساسيّة
var c0 = Cave(seed: 42)
let w = c0.near(c0.hero.pos).firstIndex { c0.tiles[$0] == .wall }
if let w = w { let before = c0.turn; check(!c0.act(w) && c0.turn == before, "walking into a wall does nothing") }
c0.hero.hp = 5
check(c0.drink() && c0.hero.hp > 5 && c0.hero.potions == 0, "potion heals")
check(!c0.drink(), "no potion left")
let copy = try! JSONDecoder().decode(Cave.self, from: JSONEncoder().encode(c0))
check(copy.tiles == c0.tiles && copy.hero == c0.hero && copy.mons == c0.mons, "codable")

// ── بوت يلعب: القواعد ما تنكسر واللعبة تخلص
var stuckRuns = 0
func fullStep(_ c: Cave, to target: Int) -> Int? {
    guard target >= 0, target < c.tiles.count, c.tiles[target] != .wall else { return nil }
    var d = [Int](repeating: 999, count: c.tiles.count)
    d[target] = 0
    var q = [target], h = 0
    while h < q.count { let p = q[h]; h += 1; for n in c.near(p) where c.tiles[n] != .wall && d[n] == 999 { d[n] = d[p] + 1; q.append(n) } }
    let ns = c.near(c.hero.pos); var best = -1, bd = d[c.hero.pos]
    for k in 0..<4 where ns[k] >= 0 && ns[k] < c.tiles.count && d[ns[k]] < bd { bd = d[ns[k]]; best = k }
    return best >= 0 ? best : nil
}
func bot(_ seed: UInt64, smart: Bool) -> Cave {
    var c = Cave(seed: seed)
    var n = 0
    var lastShop = -1
    var visited = Set<Int>(), vFloor = 0
    var cur = -1, curFloor = 0
    var stuck = 0, lastFloor = 0, gaveUp = false
    while !c.over && n < 6000 {
        n += 1
        check(c.hero.hp > 0 && c.hero.hp <= c.hero.maxHp, "hp out of range")
        if c.floor != lastFloor { lastFloor = c.floor; stuck = 0 } else { stuck += 1 }
        if stuck > 50 {
            var dir: Int? = nil
            if let b = c.mons.first(where: { Bestiary.all[$0.kind].boss }) {
                dir = c.near(c.hero.pos).firstIndex(of: b.pos) ?? fullStep(c, to: b.pos)
            } else if let e = c.tiles.firstIndex(of: .exit) {
                dir = fullStep(c, to: e)
            }
            if dir == nil {
                let dirs = (0..<4).filter { let t = c.near(c.hero.pos)[$0]; return t >= 0 && t < c.tiles.count && c.tiles[t] != .wall }
                dir = dirs.randomElement()
            }
            if let d = dir { if !c.act(d) { c.rest() } } else { c.rest() }
            if stuck > 1200 { gaveUp = true; break }
            continue
        }
        let ns = c.near(c.hero.pos)
        var target = -1, low = 9999
        for k in 0..<4 { if let mi = c.monAt(ns[k]), c.mons[mi].hp < low { low = c.mons[mi].hp; target = k } }
        let around = c.mons.filter { c.lit[$0.pos] && abs($0.pos % Cave.W - c.hero.pos % Cave.W) <= 2 && abs($0.pos / Cave.W - c.hero.pos / Cave.W) <= 2 }
        if smart && c.hero.bombs > 0 && (around.count >= 3 || around.contains { Bestiary.all[$0.kind].boss }) { c.bomb(); continue }
        if target >= 0 { c.act(target); continue }
        // لو وحش ظاهر وصاحي: انتظره (يجي إلنا) بدل ما نمشي إله
        // مسافات عبر الخانات المعروفة بس (نفس اللي يگدر اللاعب يمشيه)
        var d = [Int](repeating: 999, count: c.tiles.count)
        d[c.hero.pos] = 0
        var q = [c.hero.pos], qh = 0
        while qh < q.count {
            let p = q[qh]; qh += 1
            for n2 in c.near(p) where c.seen[n2] && c.tiles[n2] != .wall && d[n2] == 999 { d[n2] = d[p] + 1; q.append(n2) }
        }
        var goal = -1, gd = 999
        // يثبت على هدفه لحدّ ما يوصله (حتى ما يتذبذب بين هدفين)
        if cur >= 0 && cur != c.hero.pos && c.floor == curFloor && c.step(toward: cur) != nil {
            if let dir = c.step(toward: cur) { if !c.act(dir) { c.rest() } }
            continue
        }
        for (p, _) in c.items where c.seen[p] && d[p] < gd { gd = d[p]; goal = p }
        if smart && goal < 0 && c.floor % 3 == 0 && lastShop != c.floor && c.hero.gold >= 60, let s = c.tiles.firstIndex(of: .shop), c.seen[s], d[s] < 999 { goal = s }
        if goal < 0 {
            for p in 0..<c.tiles.count where c.seen[p] && c.tiles[p] != .wall && d[p] < gd && !visited.contains(p) {
                if c.near(p).contains(where: { !c.seen[$0] }) { gd = d[p]; goal = p }
            }
        }
        if goal < 0, let e = c.tiles.firstIndex(of: .exit), c.seen[e] {
            if c.floor % 4 == 0 && c.bossAlive, let b = c.mons.first(where: { Bestiary.all[$0.kind].boss }) {
                goal = c.near(b.pos).filter { c.tiles[$0] != .wall && c.seen[$0] }.min { d[$0] < d[$1] } ?? -1
            } else { goal = e }
        }
        cur = goal; curFloor = c.floor
        if goal >= 0, let dir = c.step(toward: goal) { if !c.act(dir) { c.rest() } } else { c.rest() }
    }
    check(c.over || gaveUp, "run did not finish (seed \(seed), floor \(c.floor), turn \(c.turn))")
    stuckRuns += gaveUp ? 1 : 0
    return c
}

let t0 = Date()
for (label, smart) in [("careless", false), ("smart", true)] {
    var floors = [Int](repeating: 0, count: 14), wins = 0, sum = 0
    let N = 300
    for s in 0..<N {
        let c = bot(UInt64(s) &* 104729 &+ 5, smart: smart)
        floors[min(13, c.floor)] += 1; sum += c.floor
        if c.won { wins += 1 }
    }
    print("\(label) bot: avg floor \(String(format: "%.1f", Double(sum) / Double(N))), wins \(wins)/\(N), floors \(floors[1...12].map { String($0) }.joined(separator: " "))")
    if smart {
        check(Double(sum) / Double(N) >= 3.0, "game too hard: smart bot dies too early")
        check(wins * 100 / N <= 90, "game too easy")
        check(wins >= 6, "game impossible: smart bot never wins")
        check(floors[1] * 100 / N <= 12, "first floor kills too often")
    }
}
check(stuckRuns <= 8, "too many stuck runs: \(stuckRuns)")
print("stuck runs \(stuckRuns)")
print("time \(String(format: "%.1f", Date().timeIntervalSince(t0)))s")
print(failures == 0 ? "ALL MAGHARA TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
