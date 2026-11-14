import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── RNG حتميّ
var a = RNG(42), b = RNG(42)
check(a.next() == b.next() && a.next() == b.next(), "RNG deterministic for same seed")
var c0 = RNG(1), c1 = RNG(2)
check(c0.next() != c1.next(), "RNG differs by seed")
var ri = RNG(7)
for _ in 0..<200 { let v = ri.int(10); check(v >= 0 && v < 10, "int range") }

// ── cellsOnLine: اتّجاهات مستقيمة فقط
check(Search.cellsOnLine(from: Cell(0, 0), to: Cell(0, 3))?.count == 4, "horizontal line")
check(Search.cellsOnLine(from: Cell(0, 0), to: Cell(3, 0))?.count == 4, "vertical line")
check(Search.cellsOnLine(from: Cell(0, 0), to: Cell(3, 3))?.count == 4, "diagonal down-right")
check(Search.cellsOnLine(from: Cell(3, 0), to: Cell(0, 3))?.count == 4, "diagonal up-right")
check(Search.cellsOnLine(from: Cell(0, 0), to: Cell(0, 0))?.count == 1, "single cell")
check(Search.cellsOnLine(from: Cell(0, 0), to: Cell(2, 3)) == nil, "reject non-straight (knight)")
check(Search.cellsOnLine(from: Cell(0, 0), to: Cell(1, 3)) == nil, "reject shallow slope")
let diagUp = Search.cellsOnLine(from: Cell(2, 0), to: Cell(0, 2))
check(diagUp == [Cell(2, 0), Cell(1, 1), Cell(0, 2)], "diagonal cells exact")

// ── read + lineMatches على شبكة معروفة
let grid: [[Character]] = [
    ["ق", "ط", "ة", "x"],
    ["a", "b", "c", "d"],
    ["e", "f", "g", "h"],
    ["i", "j", "k", "l"]
]
check(Search.read(grid, [Cell(0, 0), Cell(0, 1), Cell(0, 2)]) == "قطة", "read spells word")
check(Search.lineMatches(grid, from: Cell(0, 0), to: Cell(0, 2), target: "قطة"), "match forward")
check(Search.lineMatches(grid, from: Cell(0, 2), to: Cell(0, 0), target: "قطة"), "match reversed")
check(!Search.lineMatches(grid, from: Cell(0, 0), to: Cell(0, 2), target: "كلب"), "reject wrong word")
check(!Search.lineMatches(grid, from: Cell(0, 0), to: Cell(2, 3), target: "قطة"), "reject non-straight line")
check(!Search.lineMatches(grid, from: Cell(0, 0), to: Cell(0, 9), target: "قطة"), "reject out of bounds")
check(Search.matchedWord(grid, from: Cell(0, 2), to: Cell(0, 0), targets: ["كلب", "قطة"]) == "قطة", "matchedWord finds target")
check(Search.matchedWord(grid, from: Cell(0, 0), to: Cell(0, 2), targets: ["كلب"]) == nil, "matchedWord nil when absent")

// ── generate: ثبات حتميّ لنفس البذرة
let words = ["تفاح", "موز", "عنب", "برتقال", "رمان", "فراولة", "مانجو", "خوخ"]
let g1 = Search.generate(words: words, size: 10, seed: 999)
let g2 = Search.generate(words: words, size: 10, seed: 999)
check(g1.grid == g2.grid, "same seed -> same grid")
check(g1.placements == g2.placements, "same seed -> same placements")

// ── كلّ كلمة موجودة فعلًا وتُقرأ صحّ، داخل الحدود، وخطّ مستقيم
func validatePlacements(_ grid: [[Character]], _ placements: [Placement], _ size: Int, _ src: [String]) {
    check(placements.count == src.count, "all words placed (\(placements.count)/\(src.count))")
    for p in placements {
        let chars = Array(p.word)
        check(p.cells.count == chars.count, "cell count matches word \(p.word)")
        // داخل الحدود
        for cl in p.cells {
            check(cl.r >= 0 && cl.r < size && cl.c >= 0 && cl.c < size, "in bounds \(p.word)")
        }
        // تُقرأ صحّ على خلاياها
        check(Search.read(grid, p.cells) == p.word, "reads correctly \(p.word)")
        // خطّ مستقيم بأحد الاتّجاهات الثمانية
        if let first = p.cells.first, let last = p.cells.last {
            check(Search.cellsOnLine(from: first, to: last) == p.cells, "straight line \(p.word)")
        }
    }
}
validatePlacements(g1.grid, g1.placements, 10, words)

// الشبكة ممتلئة بالكامل (بلا خلايا فارغة)
func fullyFilled(_ grid: [[Character]]) -> Bool {
    for row in grid { for ch in row where ch == " " { return false } }
    return true
}
check(fullyFilled(g1.grid), "grid fully filled")
check(g1.grid.count == 10 && g1.grid.allSatisfy { $0.count == 10 }, "grid is 10x10")

// التداخل فقط على حروف متطابقة: لو خليّة مشتركة بين كلمتين، لازم نفس الحرف.
// مضمون ضمنيًّا لأنّ كلّ كلمة تُقرأ صحّ على خلاياها من نفس الشبكة.
var cellLetter: [Cell: Character] = [:]
var overlapOK = true
for p in g1.placements {
    let chars = Array(p.word)
    for (i, cl) in p.cells.enumerated() {
        if let prev = cellLetter[cl], prev != chars[i] { overlapOK = false }
        cellLetter[cl] = chars[i]
    }
}
check(overlapOK, "overlaps only on equal letters")

// ── كلّ ثيمة: >=6 كلمات وتنوضع كلّها ضمن الحجم المختار
for t in Levels.themes {
    check(t.words.count >= 6, "theme \(t.name) has >=6 words")
    check(t.size >= 8 && t.size <= 12, "theme \(t.name) size in 8..12")
    let maxLen = t.words.map { $0.count }.max() ?? 0
    check(maxLen <= t.size, "theme \(t.name) longest word fits size")
    let built = Search.generate(words: t.words, size: t.size, seed: 12345)
    check(built.placements.count == t.words.count, "theme \(t.name) all words fit")
    validatePlacements(built.grid, built.placements, t.size, t.words)
    check(fullyFilled(built.grid), "theme \(t.name) grid filled")
}

// ── توليد عدّة مراحل بسرعة، وكلّها كاملة
check(Levels.count >= 20, "has many levels")
for i in 0..<Levels.count {
    let lvl = Levels.level(i)
    let out = lvl.build()
    check(out.placements.count == lvl.theme.words.count, "level \(i) complete")
    check(out.grid.count == lvl.theme.size, "level \(i) correct size")
}
// نفس الفهرس -> نفس المرحلة (حتميّة)
check(Levels.level(5).seed == Levels.level(5).seed && Levels.level(5).theme == Levels.level(5).theme, "level deterministic")

print(failures == 0 ? "ALL KALIMAT TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
