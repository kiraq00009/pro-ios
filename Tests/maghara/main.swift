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
var dumped = 0
func bot(_ seed: UInt64, smart: Bool) -> Cave {
    var c = Cave(seed: seed)
    var n = 0
    var lastShop = -1
    var visited = Set<Int>(), vFloor = 0
    var cur = -1, curFloor = 0
    while !c.over && n < 6000 {
        n += 1
        check(c.hero.hp > 0 && c.hero.hp <= c.hero.maxHp, "hp out of range")
        check(c.monAt(c.hero.pos) == nil, "monster on hero")
        if vFloor != c.floor { vFloor = c.floor; visited = [] }
        visited.insert(c.hero.pos)
        if !c.perks.isEmpty {
            let pref = smart ? [0, 1, 2, 3, 4, 8, 5, 9, 6, 7] : c.perks
            c.choose(pref.first { c.perks.contains($0) } ?? c.perks[0]); continue
        }
        if c.atShop {
            if smart { for i in [2, 3, 0, 4] { while c.hero.gold >= c.price(i) && (i != 0 || c.hero.potions < 3) { c.buy(i) } } }
            lastShop = c.floor; c.leave(); continue
        }
        if c.atShrine { if smart && c.hero.hp * 10 > c.hero.maxHp * 8 { c.pray() }; c.leave(); continue }
        if smart && c.hero.hp * 100 < c.hero.maxHp * 45 && c.hero.potions > 0 { c.drink(); continue }
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
    check(c.over, "run did not finish (seed \(seed), floor \(c.floor), turn \(c.turn))")
    if !c.over && dumped < 3 {
        dumped += 1
        print("DUMP seed \(seed) smart \(smart) hero \(c.hero.pos) hp \(c.hero.hp)/\(c.hero.maxHp) cur \(cur) busy \(c.busy) perks \(c.perks) owed \(c.owed) shop \(c.atShop) shrine \(c.atShrine) items \(c.items.keys.sorted()) log \(c.log.suffix(3))")
        for m in c.mons { print("  mon \(Bestiary.all[m.kind].name) pos \(m.pos) hp \(m.hp) awake \(m.awake) lit \(c.lit[m.pos])") }
        for y in 0..<Cave.H {
            var line = ""
            for x in 0..<Cave.W {
                let p = y * Cave.W + x
                if p == c.hero.pos { line += "@" } else if c.monAt(p) != nil { line += "M" } else if c.items[p] != nil { line += "i" }
                else { switch c.tiles[p] { case .wall: line += c.seen[p] ? "#" : "%"; case .floor: line += c.seen[p] ? "." : "?"; case .exit: line += "E"; case .trap: line += "^"; case .shop: line += "$"; case .shrine: line += "+" } }
            }
            print("  " + line)
        }
    }
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
        check(wins * 100 / N <= 60, "game too easy: smart bot wins too often")
        check(wins >= 6, "game impossible: smart bot never wins")
        check(floors[1] * 100 / N <= 12, "first floor kills too often")
    }
}
print("time \(String(format: "%.1f", Date().timeIntervalSince(t0)))s")
print(failures == 0 ? "ALL MAGHARA TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
