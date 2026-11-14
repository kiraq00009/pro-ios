import Foundation

// فحص منطق «ألغام» — يستعمل رموز Algham/Model + Foundation فقط.

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if !cond { failures += 1; print("FAIL: \(msg)") }
}

let sizes: [(Int, Int, Int)] = [
    (9, 9, 10),
    (12, 14, 26),
    (14, 18, 44),
    (5, 5, 5),
    (3, 3, 1),
    (8, 10, 20)
]
let seeds: [UInt64] = [1, 2, 7, 42, 100, 999, 123456, 0xDEADBEEF]

// ---- 1) عدد الألغام مضبوط + أوّل خانة وجيرانها أبدًا ما تكون ألغام ----
for (cols, rows, mines) in sizes {
    for seed in seeds {
        let safe = (rows / 2) * cols + (cols / 2)
        let b = layout(rows: rows, cols: cols, mines: mines, safe: safe, seed: seed)

        let actual = b.mine.filter { $0 }.count
        check(actual == b.mines, "mines field matches actual placed (\(cols)x\(rows) seed \(seed))")

        let n = rows * cols
        var blocked = Set<Int>([safe])
        for x in neighbors(safe, rows, cols) { blocked.insert(x) }
        let available = n - blocked.count
        check(b.mines == min(mines, available), "mine count exact = min(req, available) (\(cols)x\(rows))")

        check(!b.mine[safe], "first cell is never a mine (\(cols)x\(rows) seed \(seed))")
        for nb in neighbors(safe, rows, cols) {
            check(!b.mine[nb], "first cell neighbor \(nb) is never a mine (\(cols)x\(rows) seed \(seed))")
        }
    }
}

// ---- 2) أرقام الجيران صحيحة: أعد الحساب بالقوّة الغاشمة وقارن بـ adj ----
for (cols, rows, mines) in sizes {
    let b = layout(rows: rows, cols: cols, mines: mines, safe: 0, seed: 55)
    for i in 0..<(rows * cols) {
        var expect = 0
        for nb in neighbors(i, rows, cols) where b.mine[nb] { expect += 1 }
        check(b.adj[i] == expect, "adj[\(i)] correct (\(cols)x\(rows))")
        check(b.adj[i] >= 0 && b.adj[i] <= 8, "adj[\(i)] in 0..8")
    }
}

// ---- 2b) لوح باليد 3x3: لغم بالزاوية 0 ----
do {
    var h = Board.empty(rows: 3, cols: 3, mines: 1, seed: 1)
    h.mine[0] = true
    h.started = true
    for i in 0..<9 { h.adj[i] = neighborCount(h, i) }
    // الجيران المباشرون للزاوية 0 هم 1,3,4 → عدّهم 1، الباقي 0
    check(h.adj[0] == 0, "hand board: mine cell adj 0")
    check(h.adj[1] == 1, "hand board: cell 1 adj 1")
    check(h.adj[3] == 1, "hand board: cell 3 adj 1")
    check(h.adj[4] == 1, "hand board: cell 4 adj 1")
    check(h.adj[2] == 0, "hand board: cell 2 adj 0")
    check(h.adj[5] == 0, "hand board: cell 5 adj 0")
    check(h.adj[8] == 0, "hand board: cell 8 adj 0")
}

// ---- 2c) جيران الزوايا والحوافّ: لا تجاوز للحدود، العدد الصحيح ----
do {
    let rows = 4, cols = 5
    check(Set(neighbors(0, rows, cols)) == Set([1, 5, 6]), "corner top-left neighbors")
    check(neighbors(cols - 1, rows, cols).count == 3, "corner top-right has 3 neighbors")
    check(neighbors(rows * cols - 1, rows, cols).count == 3, "corner bottom-right has 3 neighbors")
    check(neighbors(2, rows, cols).count == 5, "top edge has 5 neighbors")
    check(neighbors(cols + 1, rows, cols).count == 8, "interior cell has 8 neighbors")
    for i in 0..<(rows * cols) {
        for nb in neighbors(i, rows, cols) {
            check(nb >= 0 && nb < rows * cols, "neighbor in range for \(i)")
        }
    }
}

// ---- 3) انتشار الكشف (flood fill): منطقة صفريّة متّصلة + حوافّها ----
for (cols, rows, mines) in sizes {
    for seed in [UInt64(3), 17, 2024] {
        let safe = (rows / 2) * cols + (cols / 2)
        var b = layout(rows: rows, cols: cols, mines: mines, safe: safe, seed: seed)
        // الخانة الآمنة صفريّة دائمًا (جيرانها خالية من الألغام) → تطلق الانتشار
        check(b.adj[safe] == 0, "safe cell is a zero cell (\(cols)x\(rows) seed \(seed))")
        let got = reveal(&b, at: safe)
        check(got.contains(safe), "flood includes the start cell")
        check(!got.isEmpty, "flood reveals at least one cell")
        for c in got {
            check(!b.mine[c], "flood never reveals a mine")
            check(b.revealed[c], "flood-returned cell is marked revealed")
        }
        // اكتمال المنطقة: كلّ خانة صفريّة مكشوفة لازم كلّ جيرانها مكشوفين
        for i in 0..<(rows * cols) where b.revealed[i] && b.adj[i] == 0 {
            for nb in neighbors(i, rows, cols) {
                check(b.revealed[nb], "zero region closed: neighbor \(nb) of zero \(i) revealed")
            }
        }
        check(!b.dead, "flood from safe cell does not kill")
    }
}

// ---- 3b) الكشف ما يمرّ عبر خانة معلّمة ----
do {
    var b = layout(rows: 9, cols: 9, mines: 10, safe: 40, seed: 5)
    // علّم كلّ جيران الخانة الآمنة → الكشف ما ينتشر
    for nb in neighbors(40, 9, 9) { toggleFlag(&b, at: nb) }
    let got = reveal(&b, at: 40)
    check(got == Set([40]), "flood blocked by flags reveals only the start")
    // كشف خانة معلّمة ما يسوّي شي
    var b2 = layout(rows: 9, cols: 9, mines: 10, safe: 40, seed: 5)
    toggleFlag(&b2, at: 0)
    let before = counts(b2).revealed
    let r2 = reveal(&b2, at: 0)
    check(r2.isEmpty, "revealing a flagged cell returns empty")
    check(counts(b2).revealed == before, "revealing a flagged cell changes nothing")
}

// ---- 4) كشف لغم = خسارة ----
do {
    var b = layout(rows: 9, cols: 9, mines: 10, safe: 40, seed: 9)
    let mineIdx = b.mine.firstIndex(of: true)!
    let got = reveal(&b, at: mineIdx)
    check(b.dead, "revealing a mine sets dead")
    check(b.boom == mineIdx, "boom records the triggered mine")
    check(got == Set([mineIdx]), "revealing a mine returns just that cell")
    check(!isWin(b), "a dead board is never a win")
}

// ---- 5) كشف كلّ الخانات الآمنة = فوز ----
for (cols, rows, mines) in sizes {
    var b = layout(rows: rows, cols: cols, mines: mines, safe: 0, seed: 71)
    check(!isWin(b), "not a win before revealing")
    for i in 0..<(rows * cols) where !b.mine[i] {
        reveal(&b, at: i)
    }
    check(!b.dead, "revealing only safe cells never dies (\(cols)x\(rows))")
    check(isWin(b), "revealing all safe cells is a win (\(cols)x\(rows))")
}

// ---- 5b) لوح 3x3 باليد: الفوز بكشف كلّ غير اللغم ----
do {
    var h = Board.empty(rows: 3, cols: 3, mines: 1, seed: 1)
    h.mine[8] = true
    h.started = true
    for i in 0..<9 { h.adj[i] = neighborCount(h, i) }
    for i in 0..<9 where !h.mine[i] { reveal(&h, at: i) }
    check(isWin(h), "hand 3x3 win when all safe revealed")
    let c = counts(h)
    check(c.mines == 1 && c.revealed == 8, "hand 3x3 counts: 1 mine, 8 revealed")
}

// ---- 6) الحتميّة: نفس البذرة = نفس اللوح ----
for (cols, rows, mines) in sizes {
    let a = layout(rows: rows, cols: cols, mines: mines, safe: 3, seed: 314159)
    let b = layout(rows: rows, cols: cols, mines: mines, safe: 3, seed: 314159)
    check(a.mine == b.mine, "same seed -> identical mines (\(cols)x\(rows))")
    check(a.adj == b.adj, "same seed -> identical adj (\(cols)x\(rows))")
}
// بذرتان مختلفتان على لوح كبير -> توزيع مختلف (تصادم شبه مستحيل)
do {
    let a = layout(rows: 18, cols: 14, mines: 44, safe: 100, seed: 1)
    let b = layout(rows: 18, cols: 14, mines: 44, safe: 100, seed: 2)
    check(a.mine != b.mine, "different seeds -> different mines")
}

// ---- 7) العلم: قلب ذهاب وإياب + عدّاد المتبقّي ----
do {
    var b = layout(rows: 9, cols: 9, mines: 10, safe: 40, seed: 11)
    check(counts(b).remaining == 10, "remaining starts at mine count")
    let cell = (0..<81).first(where: { !b.revealed[$0] })!
    toggleFlag(&b, at: cell)
    check(b.flagged[cell], "flag on")
    check(counts(b).flags == 1, "flags counted")
    check(counts(b).remaining == 9, "remaining = mines - flags")
    toggleFlag(&b, at: cell)
    check(!b.flagged[cell], "flag off (toggle)")
    check(counts(b).remaining == 10, "remaining back to mines")
    // ما يعلّم خانة مكشوفة
    reveal(&b, at: 40)
    let revCell = (0..<81).first(where: { b.revealed[$0] })!
    toggleFlag(&b, at: revCell)
    check(!b.flagged[revCell], "cannot flag a revealed cell")
}

// ---- 8) بلا تجاوز فهارس على الحوافّ/الزوايا عبر بذور وأحجام عديدة ----
for (cols, rows, mines) in sizes {
    for seed in seeds {
        var b = layout(rows: rows, cols: cols, mines: mines, safe: 0, seed: seed)
        let n = rows * cols
        // استدعاءات على كلّ خانة بما فيها الزوايا والحوافّ
        for i in 0..<n {
            _ = neighbors(i, rows, cols)
            _ = neighborCount(b, i)
        }
        // أطراف خارج النطاق ما تكسر
        _ = neighbors(-1, rows, cols)
        _ = neighbors(n, rows, cols)
        toggleFlag(&b, at: -1)
        toggleFlag(&b, at: n + 5)
        var copyA = b
        _ = reveal(&copyA, at: -1)
        var copyB = b
        _ = reveal(&copyB, at: n)
        var copyC = b
        _ = reveal(&copyC, at: n - 1)   // الزاوية الأخيرة
        var copyD = b
        _ = reveal(&copyD, at: 0)       // الزاوية الأولى
        _ = counts(b)
        check(true, "no crash on edges/corners (\(cols)x\(rows) seed \(seed))")
    }
}

// ---- 9) جولة كاملة محاكاة على عدّة بذور: كشف تسلسليّ بلا كسر حتى النهاية ----
for seed in seeds {
    var b = layout(rows: 9, cols: 9, mines: 10, safe: 40, seed: seed)
    var died = false
    for i in 0..<81 {
        if b.mine[i] { continue }
        reveal(&b, at: i)
    }
    if b.dead { died = true }
    check(!died, "safe-only playthrough never dies (seed \(seed))")
    check(isWin(b), "safe-only playthrough wins (seed \(seed))")
}

if failures == 0 {
    print("ALL ALGHAM TESTS PASSED")
    exit(0)
} else {
    print("FAILURES: \(failures)")
    exit(1)
}
