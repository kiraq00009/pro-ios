import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── المولّد: كلّ مرحلة مولّدة تملأ 100٪ بلا تداخل ولا تقاطع، وأطرافها موصولة
func auditLevel(_ lv: FlowLevel, _ tag: String) {
    let n = lv.size * lv.size
    check(lv.endpoints.count == lv.pairs, "\(tag): pairs count mismatch")
    check(lv.solution.count == lv.pairs, "\(tag): solution count mismatch")

    var cover = [Int](repeating: 0, count: n)
    var allEndpoints = Set<Int>()

    for color in 0..<lv.pairs {
        let path = lv.solution[color]
        check(path.count >= 2, "\(tag) color \(color): path too short")
        // كلّ خطوة مجاورة
        for k in 1..<path.count {
            let a = lv.idx(path[k - 1]), b = lv.idx(path[k])
            check(Flow.adjacent(a, b, lv.size), "\(tag) color \(color): step \(k) not adjacent")
        }
        // بلا تكرار داخل المسار
        check(Set(path).count == path.count, "\(tag) color \(color): path revisits a cell")
        // الطرفان هما بداية ونهاية المسار
        let pair = lv.endpoints[color]
        check(Set([path.first!, path.last!]) == Set([pair.a, pair.b]), "\(tag) color \(color): endpoints != path ends")
        check(pair.a != pair.b, "\(tag) color \(color): endpoints identical")
        for cell in path {
            let i = lv.idx(cell)
            check(i >= 0 && i < n, "\(tag): cell out of bounds")
            cover[i] += 1
        }
        allEndpoints.insert(lv.idx(pair.a))
        allEndpoints.insert(lv.idx(pair.b))
    }

    // ملء كامل 100٪ بلا تداخل
    for i in 0..<n { check(cover[i] == 1, "\(tag): cell \(i) covered \(cover[i]) times (must be exactly 1)") }
    // كلّ الأطراف خانات مختلفة
    check(allEndpoints.count == lv.pairs * 2, "\(tag): endpoints not distinct cells")

    // المدقّق يعتبر الحلّ المولّد فوزًا
    var paths: [Int: [Cell]] = [:]
    for color in 0..<lv.pairs { paths[color] = lv.solution[color] }
    let v = Flow.validate(size: lv.size, endpoints: lv.endpoints, paths: paths)
    check(v.allConnected && v.filledPercent == 100 && !v.anyCross, "\(tag): validator rejects the generator's own solution \(v)")
}

// ── ولّد عبر الأحجام (~20 مرحلة) + فحص السرعة
let t0 = Date()
var generated = 0
for size in [5, 6, 7, 8] {
    for p in [3, 4, 5, 6] {
        let lv = Flow.generate(seed: UInt64(size * 100 + p), size: size, pairs: p)
        auditLevel(lv, "gen s\(size) p\(p)")
        generated += 1
    }
}
check(generated >= 16, "generated enough levels")
let dt = Date().timeIntervalSince(t0)
check(dt < 60, "generation too slow: \(dt)s")

// ── كتاب المراحل كلّه سليم
check(Levels.count >= 40, "book has enough levels (\(Levels.count))")
for i in 0..<Levels.count { auditLevel(Levels.level(i), "book[\(i)]") }

// ── حتميّة: نفس البذرة ⇒ نفس المرحلة
for i in [0, 7, 23, 40] {
    let a = Levels.level(i), b = Levels.level(i)
    check(a.solution == b.solution && a.endpoints == b.endpoints, "book[\(i)] not deterministic")
}
let g1 = Flow.generate(seed: 999, size: 7, pairs: 5)
let g2 = Flow.generate(seed: 999, size: 7, pairs: 5)
check(g1.solution == g2.solution, "generate not deterministic per seed")
let g3 = Flow.generate(seed: 1000, size: 7, pairs: 5)
check(g3.solution != g1.solution, "different seeds give different levels")

// ── لغز اليوم ثابت لنفس التاريخ
let day = Date()
check(Levels.daily(day).solution == Levels.daily(day).solution, "daily deterministic")

// ── المدقّق: حالة ناقصة ليست فوزًا، وحالة متقاطعة ليست فوزًا
do {
    let lv = Flow.generate(seed: 12345, size: 5, pairs: 3)
    // ناقص: احذف آخر خانة من أوّل لون
    var paths: [Int: [Cell]] = [:]
    for color in 0..<lv.pairs { paths[color] = lv.solution[color] }
    var incomplete = paths
    incomplete[0] = Array(lv.solution[0].dropLast())
    let vi = Flow.validate(size: lv.size, endpoints: lv.endpoints, paths: incomplete)
    check(!(vi.allConnected && vi.filledPercent == 100), "incomplete must not be win")
    check(vi.filledPercent < 100, "incomplete fill < 100")
    check(!vi.allConnected, "incomplete: color 0 not connected")

    // تقاطع: ضع خانة لون 1 الأولى داخل مسار لون 0 أيضًا
    var crossing = paths
    let shared = lv.solution[0][1]           // خانة داخليّة من لون 0
    crossing[1] = [lv.endpoints[1].a, shared] // يخلق تداخلًا
    let vc = Flow.validate(size: lv.size, endpoints: lv.endpoints, paths: crossing)
    check(vc.anyCross, "crossing must be detected")
}

// ── اللوح التفاعليّ: إعادة رسم الحلّ ⇒ فوز
do {
    let lv = Levels.level(2)
    var bd = Board(lv)
    check(!bd.won, "fresh board not won")
    check(bd.filledPercent < 100, "fresh board not full")
    for color in 0..<lv.pairs {
        let path = lv.solution[color].map { lv.idx($0) }
        bd.start(color, at: path.first!)
        for k in 1..<path.count {
            let moved = bd.extend(color, to: path[k])
            check(moved, "replay color \(color) step \(k) blocked")
        }
        check(bd.connected(color), "color \(color) should be connected after replay")
    }
    check(bd.won, "board should be won after replaying full solution")
    check(bd.filledPercent == 100, "replayed board 100% filled")
    check(bd.connectedCount == lv.pairs, "all pairs connected")
}

// ── لوح مرسوم باليد لفحص الميكانيكا بدقّة (5×5)
func handLevel() -> FlowLevel {
    // لون 0: الصفّ العلويّ كاملًا. لون 1: ثلاث خانات بالصفّ الثاني.
    let row0 = (0..<5).map { Cell(0, $0) }
    let row1 = [Cell(1, 0), Cell(1, 1), Cell(1, 2)]
    let eps = [Pair(color: 0, a: Cell(0, 0), b: Cell(0, 4)),
               Pair(color: 1, a: Cell(1, 0), b: Cell(1, 2))]
    return FlowLevel(seed: 1, size: 5, pairs: 2, endpoints: eps, solution: [row0, row1])
}

// ── اللوح: ممنوع الدخول على طرف لون آخر
do {
    let lv = handLevel()
    var bd = Board(lv)
    bd.start(0, at: 0)                       // (0,0)
    let moved = bd.extend(0, to: 5)          // (1,0) = طرف لون 1
    check(!moved, "must not step onto another color's endpoint")
    check(bd.paths[0] == [0], "blocked move left path unchanged")
}

// ── اللوح: السحب فوق أنبوب لون آخر يقطعه
do {
    let lv = handLevel()
    var bd = Board(lv)
    // ارسم لون 0 كاملًا عبر الصفّ العلويّ
    bd.start(0, at: 0)
    for j in [1, 2, 3, 4] { check(bd.extend(0, to: j), "draw color0 step \(j)") }
    check(bd.paths[0].count == 5, "color 0 fully drawn")
    // لون 1 يتحرّك ثمّ يصعد على خانة داخليّة من لون 0 فيقطعها
    bd.start(1, at: 5)                       // (1,0)
    check(bd.extend(1, to: 6), "color1 to (1,1)")     // (1,1)
    check(bd.extend(1, to: 1), "color1 up cuts color0") // (0,1) داخل لون 0
    check(bd.paths[0] == [0], "color 0 cut back to its start")
    check(bd.owner(1) == 1, "cut cell now owned by color 1")
    check(bd.paths[1] == [5, 6, 1], "color 1 extended onto cut cell")
}

// ── اللوح: التراجع والالتفاف على نفس المسار (لون واحد بمساحة فارغة)
do {
    // size 5، لون واحد طرفاه (0,0) و(2,0)، باقي الشبكة فارغ للسحب الحرّ
    let lv = FlowLevel(seed: 2, size: 5, pairs: 1,
                       endpoints: [Pair(color: 0, a: Cell(0, 0), b: Cell(2, 0))],
                       solution: [[Cell(0, 0), Cell(1, 0), Cell(2, 0)]])
    var bd = Board(lv)
    bd.start(0, at: 0)                         // (0,0)
    bd.extend(0, to: 1)                        // (0,1)
    bd.extend(0, to: 2)                        // (0,2)
    check(bd.extend(0, to: 1), "backtrack to previous cell")   // تراجع خطوة
    check(bd.paths[0] == [0, 1], "backtracked one step")
    // ارسم حلقة L ثمّ ارجع على خانة سابقة غير مجاورة بالمسار
    bd.extend(0, to: 6)                        // (1,1)
    bd.extend(0, to: 5)                        // (1,0)  head
    check(bd.paths[0] == [0, 1, 6, 5], "L-shape drawn")
    check(bd.extend(0, to: 0), "loop back onto own earlier cell truncates") // (0,0) مجاور لـ(1,0)
    check(bd.paths[0] == [0], "truncated to the revisited cell")
}

// ── Codable للخانات والأزواج
do {
    let lv = Levels.level(5)
    let enc = try! JSONEncoder().encode(lv.endpoints)
    let dec = try! JSONDecoder().decode([Pair].self, from: enc)
    check(dec == lv.endpoints, "Pair codable round-trip")
}

if failures == 0 {
    print("ALL WASSEL TESTS PASSED")
    exit(0)
} else {
    print("\(failures) FAILURES")
    exit(1)
}
