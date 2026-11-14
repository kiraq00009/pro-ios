import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) {
    if !ok {
        failures += 1
        print("FAIL: " + msg())
    }
}

func parse(_ s: String) -> [Int] {
    var g: [Int] = []
    for ch in s {
        if ch == "." || ch == "0" {
            g.append(0)
        } else if let d = ch.wholeNumberValue, d >= 1 && d <= 9 {
            g.append(d)
        }
    }
    return g
}

func gridIsValidComplete(_ g: [Int]) -> Bool {
    return Sudoku.isSolved(g)
}

// ── الحلّال يحلّ أحجيّة معروفة ─────────────────────────────────────────────
let known = parse("""
53..7....
6..195...
.98....6.
8...6...3
4..8.3..1
7...2...6
.6....28.
...419..5
....8..79
""")
check(known.count == 81, "known puzzle parses to 81 cells: \(known.count)")
let knownSolution = parse("""
534678912
672195348
198342567
859761423
426853791
713924856
961537284
287419635
345286179
""")
if let sol = Sudoku.solve(known) {
    check(gridIsValidComplete(sol), "solved known puzzle is a valid complete sudoku")
    check(sol == knownSolution, "solver reproduces the known solution")
    // الحلّ يحترم كلّ الخانات المعطاة
    var keepsGivens = true
    for i in 0..<81 where known[i] != 0 {
        if sol[i] != known[i] { keepsGivens = false }
    }
    check(keepsGivens, "solution keeps all given clues")
} else {
    check(false, "solver returned nil on a solvable puzzle")
}

// أحجيّة بحلّ وحيد تمامًا
check(Sudoku.countSolutions(known, cap: 5) == 1, "known puzzle has exactly one solution")

// شبكة فارغة: حلول كثيرة (السقف يوقفها)
let emptyGrid = [Int](repeating: 0, count: 81)
check(Sudoku.countSolutions(emptyGrid, cap: 2) == 2, "empty grid hits the solution cap")
check(Sudoku.solve(emptyGrid) != nil, "empty grid is solvable")

// شبكة بلا حلّ: نفرّغ خانة ونخلّي صفّها يطلب رقمًا وعمودها يطلب رقمًا ثانيًا ⇒ بلا مرشّح
var noSol = knownSolution
noSol[0] = 0                  // نفرّغ (٠،٠)
noSol[1] = knownSolution[0]   // صفّها صار يمنع كلّ شي إلّا قيمة العمود ⇒ تعارض ⇒ بلا حلّ
check(Sudoku.solve(noSol) == nil, "unsolvable grid returns nil")
check(Sudoku.countSolutions(noSol, cap: 2) == 0, "unsolvable grid counts zero solutions")

// ── isValid / conflicts ─────────────────────────────────────────────────────
check(Sudoku.isValid(known, row: 0, col: 2, val: 4), "4 is valid at (0,2)")
check(!Sudoku.isValid(known, row: 0, col: 2, val: 5), "5 conflicts in row 0")
check(!Sudoku.isValid(known, row: 0, col: 2, val: 6), "6 conflicts in box 0")
check(Sudoku.isSolved(knownSolution), "known full solution passes isSolved")
check(!Sudoku.isComplete(known), "unsolved puzzle is not complete")

var conflicted = knownSolution
conflicted[1] = conflicted[0]   // نخلّي تكرار بالصفّ الأوّل
let cf = Sudoku.conflicts(conflicted)
check(cf.contains(0) && cf.contains(1), "conflict detected on both duplicate cells")
check(Sudoku.conflicts(knownSolution).isEmpty, "a valid solution has no conflicts")
check(!Sudoku.isSolved(conflicted), "a conflicted full grid is not solved")

// ── التوليد: وحدانيّة + عدد الخانات + احتواء + صحّة + حتميّة ──────────────────
let t0 = Date()
var genCount = 0
for diff in Difficulty.allCases {
    for s in 0..<5 {
        let seed = UInt64(s) &* 1_000_003 &+ UInt64(diff.rawValue) &* 97 &+ 7
        let r = Sudoku.generate(seed: seed, difficulty: diff)
        genCount += 1

        // الحلّ شبكة سودوكو كاملة صحيحة
        check(Sudoku.isSolved(r.solution), "\(diff.title) seed \(s): solution is a valid complete sudoku")

        // عدد الخانات المعطاة يطابق المستوى
        let givenCount = r.givens.filter { $0 }.count
        let filled = r.puzzle.filter { $0 != 0 }.count
        check(givenCount == diff.givens, "\(diff.title) seed \(s): givens mask count \(givenCount) == \(diff.givens)")
        check(filled == diff.givens, "\(diff.title) seed \(s): puzzle filled count \(filled) == \(diff.givens)")

        // قناع الخانات المعطاة يطابق الخانات غير الفارغة
        var maskOK = true
        for i in 0..<81 {
            if (r.puzzle[i] != 0) != r.givens[i] { maskOK = false }
        }
        check(maskOK, "\(diff.title) seed \(s): givens mask matches filled cells")

        // الأحجيّة ⊂ الحلّ
        var subset = true
        for i in 0..<81 where r.puzzle[i] != 0 {
            if r.puzzle[i] != r.solution[i] { subset = false }
        }
        check(subset, "\(diff.title) seed \(s): puzzle is a subset of the solution")

        // حلّ وحيد تمامًا
        check(Sudoku.countSolutions(r.puzzle, cap: 2) == 1, "\(diff.title) seed \(s): puzzle has a unique solution")

        // الحلّال يرجّع نفس الحلّ
        if let got = Sudoku.solve(r.puzzle) {
            check(got == r.solution, "\(diff.title) seed \(s): solver matches generated solution")
        } else {
            check(false, "\(diff.title) seed \(s): generated puzzle should be solvable")
        }

        // حتميّة: نفس البذرة ⇒ نفس الأحجيّة بالضبط
        let again = Sudoku.generate(seed: seed, difficulty: diff)
        check(again.puzzle == r.puzzle && again.solution == r.solution && again.givens == r.givens,
              "\(diff.title) seed \(s): generation is deterministic")
    }
}

// بذرتان مختلفتان ⇒ أحجيّتان مختلفتان (على الأغلب)
let gA = Sudoku.generate(seed: 11, difficulty: .medium)
let gB = Sudoku.generate(seed: 22, difficulty: .medium)
check(gA.puzzle != gB.puzzle, "different seeds give different puzzles")

let elapsed = Date().timeIntervalSince(t0)
print("generated \(genCount) puzzles across difficulties in \(String(format: "%.2f", elapsed))s")
check(elapsed < 60, "generation of ~20 puzzles should finish in reasonable time")

print(failures == 0 ? "ALL SUDOKU TESTS PASSED" : "FAILURES")
exit(failures == 0 ? 0 : 1)
