import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── runs / rowClues / colClues على بتماب باليد ──────────────────────
check(Nono.runs([true, true, false, true]) == [2, 1], "runs [T,T,F,T] -> [2,1]")
check(Nono.runs([false, false, false, false]) == [0], "all-false -> [0]")
check(Nono.runs([]) == [0], "empty -> [0]")
check(Nono.runs([true, true, true]) == [3], "all-true -> [3]")
check(Nono.runs([true, false, true, false, true]) == [1, 1, 1], "gaps -> [1,1,1]")
check(Nono.runs([false, true, true, false]) == [2], "padded -> [2]")

let hand = Nono.bmp([
    "#.##",
    "....",
    ".##.",
    "#..#",
])
check(Nono.rowClues(hand) == [[1, 2], [0], [2], [1, 1]], "rowClues hand")
check(Nono.colClues(hand) == [[1, 1], [1], [1, 1], [1, 1]], "colClues hand: \(Nono.colClues(hand))")

let full = Nono.bmp(["##", "##"])
check(Nono.rowClues(full) == [[2], [2]], "full rowClues")
check(Nono.colClues(full) == [[2], [2]], "full colClues")

// ── isSolved: صحيح فقط لمّا الملء == الحلّ ──────────────────────────
let sol = Nono.bmp(["#.", ".#"])
check(Nono.isSolved(Nono.bmp(["#.", ".#"]), sol), "isSolved exact match")
check(!Nono.isSolved(Nono.bmp(["..", ".."]), sol), "isSolved rejects empty")
check(!Nono.isSolved(Nono.bmp(["##", ".#"]), sol), "isSolved rejects extra fill")
check(!Nono.isSolved(Nono.bmp(["#.", "#."]), sol), "isSolved rejects wrong shape")
check(!Nono.isSolved([[true]], sol), "isSolved rejects wrong dims")
check(!Nono.isSolved([], []), "isSolved false on empty")
// علامات X تُتجاهل: الملء يحمل المملوء فقط، فالنتيجة هي المساواة
check(Nono.isSolved(sol, sol), "isSolved reflexive")

// ── lineMatchesClue على أمثلة ───────────────────────────────────────
check(Nono.lineMatchesClue([true, true, false, true], [2, 1]), "match [2,1]")
check(!Nono.lineMatchesClue([true, false, true, true], [2, 1]), "no match [2,1] wrong order")
check(Nono.lineMatchesClue([false, false], [0]), "match [0]")
check(!Nono.lineMatchesClue([true, false], [0]), "no match [0] when filled")
check(Nono.lineMatchesClue([true, true, true], [3]), "match [3]")
check(!Nono.lineMatchesClue([true, true], [3]), "no match [3] short")

// ── clueFits (الاتّساق) ─────────────────────────────────────────────
check(Nono.clueFits([0], length: 5), "[0] fits any")
check(Nono.clueFits([2, 1], length: 4), "[2,1] fits 4")
check(!Nono.clueFits([2, 1], length: 3), "[2,1] needs 4 not 3")
check(Nono.clueFits([5], length: 5), "[5] fits 5")
check(!Nono.clueFits([6], length: 5), "[6] too big")
check(!Nono.clueFits([], length: 5), "empty clue invalid")

// ── كلّ ألغاز المكتبة ───────────────────────────────────────────────
let lib = Nono.library()
check(lib.count >= 12, "library count \(lib.count) >= 12")
var ids = Set<String>()
for p in lib {
    check(ids.insert(p.id).inserted, "id unique: \(p.id)")
    let n = p.size.n
    check(p.rows == n && p.cols == n, "\(p.id) dims \(p.rows)x\(p.cols) != \(n)")
    check(p.bitmap.allSatisfy { $0.count == n }, "\(p.id) ragged rows")
    check(p.filledCount >= 1, "\(p.id) has filled cells")
    check(!p.name.isEmpty, "\(p.id) has a name")
    // الأرقام غير فارغة ومتّسقة
    check(p.rowClues.count == n && p.colClues.count == n, "\(p.id) clue counts")
    check(p.rowClues.allSatisfy { !$0.isEmpty }, "\(p.id) row clues non-empty")
    check(p.colClues.allSatisfy { !$0.isEmpty }, "\(p.id) col clues non-empty")
    check(Nono.isConsistent(p), "\(p.id) consistent")
    // الحلّ نفسه يُفحص محلولًا، والفارغ لا
    check(Nono.isSolved(p.bitmap, p.bitmap), "\(p.id) solution solves itself")
    let empty = Array(repeating: Array(repeating: false, count: n), count: n)
    check(!Nono.isSolved(empty, p.bitmap), "\(p.id) empty board not solved")
    // كلّ سطر من الحلّ يطابق أرقامه
    for (i, row) in p.bitmap.enumerated() {
        check(Nono.lineMatchesClue(row, p.rowClues[i]), "\(p.id) row \(i) matches its clue")
    }
}

// توزيع معقول عبر الأحجام
for s in Size.allCases {
    check(Nono.puzzles(s).count >= 3, "size \(s.n) has >= 3 puzzles: \(Nono.puzzles(s).count)")
}

// ثابت (deterministic)
check(Nono.library().map { $0.id } == lib.map { $0.id }, "library deterministic order")
check(Nono.library().map { $0.bitmap } == lib.map { $0.bitmap }, "library deterministic bitmaps")

print("library: \(lib.count) puzzles — small \(Nono.puzzles(.small).count), medium \(Nono.puzzles(.medium).count), large \(Nono.puzzles(.large).count)")
print(failures == 0 ? "ALL BIXEL TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
