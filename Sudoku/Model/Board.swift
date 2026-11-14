import Foundation

// ── منطق سودوكو خالص — بلا SwiftUI. قابل لإعادة التوليد بنفس البذرة حتى تگدر الاختبارات تعيده.

/// مستويات الصعوبة — تختلف بعدد الخانات المعطاة (الأرقام الظاهرة من البداية).
enum Difficulty: Int, CaseIterable, Identifiable {
    case easy = 0
    case medium = 1
    case hard = 2
    case expert = 3

    var id: Int { rawValue }

    /// عدد الخانات المعطاة لكلّ مستوى.
    var givens: Int {
        switch self {
        case .easy: return 46
        case .medium: return 38
        case .hard: return 32
        case .expert: return 28
        }
    }

    var title: String {
        switch self {
        case .easy: return "سهل"
        case .medium: return "متوسّط"
        case .hard: return "صعب"
        case .expert: return "خبير"
        }
    }

    var note: String {
        switch self {
        case .easy: return "مريح للبداية والاسترخاء"
        case .medium: return "يحتاج شويّة تركيز"
        case .hard: return "يبيله تفكير ومنطق"
        case .expert: return "تحدّي حقيقيّ للمحترفين"
        }
    }
}

/// مولّد أرقام عشوائيّة حتميّ (xorshift64) حتى نفس البذرة تعطي نفس النتيجة دائمًا.
struct SudRNG: RandomNumberGenerator {
    private var state: UInt64
    init(_ seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }
    mutating func next() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }
}

/// فضاء أسماء لكلّ دوال منطق سودوكو. الشبكة = مصفوفة ٨١ عنصرًا (٠ = فارغ)، الفهرس = صفّ*٩ + عمود.
enum Sudoku {

    static let allBits = 0b11_1111_1110   // بتّات ١..٩

    static func box(ofRow r: Int, col c: Int) -> Int { (r / 3) * 3 + (c / 3) }
    static func box(ofIndex i: Int) -> Int { box(ofRow: i / 9, col: i % 9) }

    // ── تحقّق الصحّة والاكتمال ───────────────────────────────────────────────

    /// هل نگدر نحطّ `val` بالخانة (row,col) بلا تعارض ويّا باقي الأرقام الموجودة؟ (يتجاهل الخانة نفسها)
    static func isValid(_ grid: [Int], row: Int, col: Int, val: Int) -> Bool {
        if val < 1 || val > 9 { return false }
        for c in 0..<9 {
            if c != col && grid[row * 9 + c] == val { return false }
        }
        for r in 0..<9 {
            if r != row && grid[r * 9 + col] == val { return false }
        }
        let br = (row / 3) * 3
        let bc = (col / 3) * 3
        for r in br..<(br + 3) {
            for c in bc..<(bc + 3) {
                let idx = r * 9 + c
                if idx != row * 9 + col && grid[idx] == val { return false }
            }
        }
        return true
    }

    /// كلّ الخانات مملوءة؟
    static func isComplete(_ grid: [Int]) -> Bool {
        for v in grid where v == 0 { return false }
        return true
    }

    /// شبكة مكتملة وصحيحة: كلّ صفّ وعمود ومربّع تبديلة للأرقام ١..٩.
    static func isSolved(_ grid: [Int]) -> Bool {
        if grid.count != 81 { return false }
        if !isComplete(grid) { return false }
        func unit(_ idxs: [Int]) -> Bool {
            var seen = 0
            for i in idxs {
                let v = grid[i]
                if v < 1 || v > 9 { return false }
                let b = 1 << v
                if seen & b != 0 { return false }
                seen |= b
            }
            return seen == allBits
        }
        for r in 0..<9 {
            var row: [Int] = []
            for c in 0..<9 { row.append(r * 9 + c) }
            if !unit(row) { return false }
        }
        for c in 0..<9 {
            var colv: [Int] = []
            for r in 0..<9 { colv.append(r * 9 + c) }
            if !unit(colv) { return false }
        }
        for b in 0..<9 {
            let br = (b / 3) * 3
            let bc = (b % 3) * 3
            var box: [Int] = []
            for r in br..<(br + 3) {
                for c in bc..<(bc + 3) { box.append(r * 9 + c) }
            }
            if !unit(box) { return false }
        }
        return true
    }

    /// مجموعة فهارس الخانات المتعارضة (الأرقام المكرّرة بنفس الصفّ/العمود/المربّع).
    static func conflicts(_ grid: [Int]) -> Set<Int> {
        var bad = Set<Int>()
        func scan(_ idxs: [Int]) {
            var first = [Int](repeating: -1, count: 10)
            for i in idxs {
                let v = grid[i]
                if v < 1 || v > 9 { continue }
                if first[v] >= 0 {
                    bad.insert(i)
                    bad.insert(first[v])
                } else {
                    first[v] = i
                }
            }
        }
        for r in 0..<9 {
            var row: [Int] = []
            for c in 0..<9 { row.append(r * 9 + c) }
            scan(row)
        }
        for c in 0..<9 {
            var colv: [Int] = []
            for r in 0..<9 { colv.append(r * 9 + c) }
            scan(colv)
        }
        for b in 0..<9 {
            let br = (b / 3) * 3
            let bc = (b % 3) * 3
            var box: [Int] = []
            for r in br..<(br + 3) {
                for c in bc..<(bc + 3) { box.append(r * 9 + c) }
            }
            scan(box)
        }
        return bad
    }

    // ── الحلّال (backtracking مع اختيار أقلّ المرشّحات MRV + بتّات) ──────────

    private struct Engine {
        var g: [Int]
        var rows: [Int]
        var cols: [Int]
        var boxs: [Int]
        var count = 0
        var cap = 2
        var wantFirst = false
        var first: [Int]? = nil

        init(_ grid: [Int], cap: Int, wantFirst: Bool) {
            g = grid
            rows = [Int](repeating: 0, count: 9)
            cols = [Int](repeating: 0, count: 9)
            boxs = [Int](repeating: 0, count: 9)
            self.cap = cap
            self.wantFirst = wantFirst
            for i in 0..<81 {
                let v = g[i]
                if v != 0 {
                    let b = 1 << v
                    rows[i / 9] |= b
                    cols[i % 9] |= b
                    boxs[Sudoku.box(ofIndex: i)] |= b
                }
            }
        }

        mutating func run() {
            var best = -1
            var bestCount = 99
            var bestMask = 0
            var i = 0
            while i < 81 {
                if g[i] == 0 {
                    let used = rows[i / 9] | cols[i % 9] | boxs[Sudoku.box(ofIndex: i)]
                    let avail = (~used) & Sudoku.allBits
                    let c = avail.nonzeroBitCount
                    if c < bestCount {
                        bestCount = c
                        best = i
                        bestMask = avail
                        if c == 0 { return }
                        if c == 1 { break }
                    }
                }
                i += 1
            }
            if best == -1 {
                count += 1
                if wantFirst && first == nil { first = g }
                return
            }
            let r = best / 9
            let cc = best % 9
            let bx = Sudoku.box(ofIndex: best)
            var m = bestMask
            while m != 0 {
                let low = m & (0 &- m)
                let d = low.trailingZeroBitCount
                g[best] = d
                rows[r] |= low
                cols[cc] |= low
                boxs[bx] |= low
                run()
                g[best] = 0
                rows[r] &= ~low
                cols[cc] &= ~low
                boxs[bx] &= ~low
                m &= m - 1
                if count >= cap { return }
                if wantFirst && first != nil { return }
            }
        }
    }

    /// يحلّ الشبكة ويرجّع أوّل حلّ، أو nil إذا ما أكو حلّ.
    static func solve(_ grid: [Int]) -> [Int]? {
        var e = Engine(grid, cap: 1, wantFirst: true)
        e.run()
        return e.first
    }

    /// يعدّ الحلول لحدّ السقف `cap` (الافتراضيّ ٢ حتى نتأكّد من الوحدانيّة بسرعة).
    static func countSolutions(_ grid: [Int], cap: Int = 2) -> Int {
        var e = Engine(grid, cap: cap, wantFirst: false)
        e.run()
        return e.count
    }

    // ── التوليد ──────────────────────────────────────────────────────────────

    /// يبني شبكة مكتملة صحيحة من نمط أساس + تبديلات محفوظة بالبذرة.
    private static func fullSolution(_ rng: inout SudRNG) -> [Int] {
        func pattern(_ r: Int, _ c: Int) -> Int { (3 * (r % 3) + r / 3 + c) % 9 }
        var digits = Array(1...9)
        digits.shuffle(using: &rng)
        func lines(_ rng: inout SudRNG) -> [Int] {
            var bands = [0, 1, 2]
            bands.shuffle(using: &rng)
            var out: [Int] = []
            for b in bands {
                var inner = [0, 1, 2]
                inner.shuffle(using: &rng)
                for i in inner { out.append(b * 3 + i) }
            }
            return out
        }
        let rowOrder = lines(&rng)
        let colOrder = lines(&rng)
        var g = [Int](repeating: 0, count: 81)
        for r in 0..<9 {
            for c in 0..<9 {
                g[rowOrder[r] * 9 + colOrder[c]] = digits[pattern(r, c)]
            }
        }
        if Bool.random(using: &rng) {
            var t = [Int](repeating: 0, count: 81)
            for r in 0..<9 {
                for c in 0..<9 { t[c * 9 + r] = g[r * 9 + c] }
            }
            g = t
        }
        return g
    }

    /// يولّد أحجيّة بحلّ وحيد عند مستوى الصعوبة المطلوب.
    /// يرجّع: (الأحجيّة، الحلّ الكامل، قناع الخانات المعطاة).
    static func generate(seed: UInt64, difficulty: Difficulty) -> (puzzle: [Int], solution: [Int], givens: [Bool]) {
        var rng = SudRNG(seed)
        let solution = fullSolution(&rng)
        var puzzle = solution
        let target = difficulty.givens
        let toRemove = 81 - target
        var removed = 0
        var order = Array(0..<81)
        order.shuffle(using: &rng)

        for idx in order {
            if removed >= toRemove { break }
            let backup = puzzle[idx]
            puzzle[idx] = 0
            if countSolutions(puzzle, cap: 2) == 1 {
                removed += 1
            } else {
                puzzle[idx] = backup
            }
        }

        // تمريرات إضافيّة إذا ما وصلنا للعدد المطلوب (نادر).
        var pass = 0
        while removed < toRemove && pass < 8 {
            pass += 1
            order.shuffle(using: &rng)
            var removedThisPass = 0
            for idx in order {
                if removed >= toRemove { break }
                if puzzle[idx] == 0 { continue }
                let backup = puzzle[idx]
                puzzle[idx] = 0
                if countSolutions(puzzle, cap: 2) == 1 {
                    removed += 1
                    removedThisPass += 1
                } else {
                    puzzle[idx] = backup
                }
            }
            if removedThisPass == 0 { break }
        }

        var givens = [Bool](repeating: false, count: 81)
        for i in 0..<81 { givens[i] = puzzle[i] != 0 }
        return (puzzle, solution, givens)
    }
}
