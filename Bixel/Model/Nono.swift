import Foundation

// منطق لعبة «بكسل» (Foundation فقط): لغز رسم بالأرقام (Nonogram / Picross).
//
// كلّ لغز يمثّله «بتماب» حلّ: شبكة Bool. نحسب أرقام الصفوف والأعمدة من سلاسل الخانات المملوءة.
// اللاعب يملأ الخانات حتى تطابق الحلّ فتنكشف الصورة. كلّ شي هنا منفصل عن الواجهة ويُفحص آليًّا.

/// لون الكشف (مكوّنات RGB من 0 لـ1) — الواجهة تحوّله للونها
struct Ink: Equatable {
    var r: Double
    var g: Double
    var b: Double
}

/// حجم اللغز: 5×5 أو 10×10 أو 15×15
enum Size: Int, CaseIterable {
    case small = 5
    case medium = 10
    case large = 15
    var n: Int { rawValue }
    var title: String {
        switch self {
        case .small: return "٥×٥ سهل"
        case .medium: return "١٠×١٠ متوسّط"
        case .large: return "١٥×١٥ صعب"
        }
    }
}

struct Puzzle: Identifiable, Equatable {
    let id: String
    let name: String
    let size: Size
    let bitmap: [[Bool]]
    let ink: Ink
    var rows: Int { bitmap.count }
    var cols: Int { bitmap.first?.count ?? 0 }
    var rowClues: [[Int]] { Nono.rowClues(bitmap) }
    var colClues: [[Int]] { Nono.colClues(bitmap) }
    var filledCount: Int { bitmap.reduce(0) { $0 + $1.filter { $0 }.count } }
}

enum Nono {

    // ── الأرقام (الدلالات) ─────────────────────────────────────────

    /// سلاسل الخانات المملوءة في سطر واحد. سطر فارغ = [0].
    static func runs(_ line: [Bool]) -> [Int] {
        var out: [Int] = []
        var c = 0
        for v in line {
            if v {
                c += 1
            } else if c > 0 {
                out.append(c)
                c = 0
            }
        }
        if c > 0 { out.append(c) }
        return out.isEmpty ? [0] : out
    }

    /// أرقام كلّ صفّ
    static func rowClues(_ bitmap: [[Bool]]) -> [[Int]] {
        bitmap.map { runs($0) }
    }

    /// أرقام كلّ عمود
    static func colClues(_ bitmap: [[Bool]]) -> [[Int]] {
        guard let w = bitmap.first?.count, w > 0 else { return [] }
        var out: [[Int]] = []
        out.reserveCapacity(w)
        for j in 0..<w {
            var col: [Bool] = []
            col.reserveCapacity(bitmap.count)
            for row in bitmap { col.append(j < row.count ? row[j] : false) }
            out.append(runs(col))
        }
        return out
    }

    // ── الفحص والتحقّق ────────────────────────────────────────────

    /// اللغز محلول لمّا الملء يساوي الحلّ تمامًا (علامات X تُتجاهل: الملء Bool «مملوء/لا»)
    static func isSolved(_ fill: [[Bool]], _ solution: [[Bool]]) -> Bool {
        guard fill.count == solution.count else { return false }
        for i in 0..<fill.count {
            if fill[i].count != solution[i].count { return false }
            if fill[i] != solution[i] { return false }
        }
        return !solution.isEmpty
    }

    /// سطر الملء يطابق أرقامه
    static func lineMatchesClue(_ line: [Bool], _ clue: [Int]) -> Bool {
        runs(line) == clue
    }

    /// أرقام متّسقة مع طول سطر: مجموعها + الفراغات بينها ≤ الطول، وكلّها موجبة (أو [0])
    static func clueFits(_ clue: [Int], length: Int) -> Bool {
        if clue.isEmpty { return false }
        if clue == [0] { return true }
        guard clue.allSatisfy({ $0 >= 1 }) else { return false }
        let need = clue.reduce(0, +) + (clue.count - 1)
        return need <= length
    }

    /// اللغز متّسق: الأبعاد سليمة، وكلّ أرقام صفّ/عمود تنطبق على طولها
    static func isConsistent(_ p: Puzzle) -> Bool {
        let n = p.size.n
        guard p.rows == n, p.cols == n, n > 0 else { return false }
        guard p.bitmap.allSatisfy({ $0.count == n }) else { return false }
        let rc = p.rowClues
        let cc = p.colClues
        guard rc.count == n, cc.count == n else { return false }
        for c in rc where !clueFits(c, length: n) { return false }
        for c in cc where !clueFits(c, length: n) { return false }
        // تحقّق إضافيّ: الأرقام تنتج فعلًا نفس البتماب
        return rc == runsRows(p.bitmap) && cc == colClues(p.bitmap)
    }

    private static func runsRows(_ b: [[Bool]]) -> [[Int]] { b.map { runs($0) } }

    // ── المكتبة ───────────────────────────────────────────────────

    /// حوّل أسطر نصّيّة ('#' = مملوء) لبتماب
    static func bmp(_ rows: [String]) -> [[Bool]] {
        rows.map { row in row.map { $0 == "#" } }
    }

    private static func ink(_ r: Double, _ g: Double, _ b: Double) -> Ink { Ink(r: r, g: g, b: b) }

    /// مكتبة ألغاز مرسومة باليد، مجموعة حسب الحجم (ثابتة)
    static func library() -> [Puzzle] {
        var out: [Puzzle] = []

        // ── ٥×٥ ──
        out.append(Puzzle(id: "heart5", name: "قلب", size: .small, ink: ink(1, 0.34, 0.46), bitmap: bmp([
            ".#.#.",
            "#####",
            "#####",
            ".###.",
            "..#..",
        ])))
        out.append(Puzzle(id: "diamond5", name: "ماسة", size: .small, ink: ink(0.4, 0.82, 1), bitmap: bmp([
            "..#..",
            ".###.",
            "#####",
            ".###.",
            "..#..",
        ])))
        out.append(Puzzle(id: "plus5", name: "زائد", size: .small, ink: ink(0.4, 0.95, 0.6), bitmap: bmp([
            "..#..",
            "..#..",
            "#####",
            "..#..",
            "..#..",
        ])))
        out.append(Puzzle(id: "tree5", name: "شجرة", size: .small, ink: ink(0.46, 0.84, 0.4), bitmap: bmp([
            "..#..",
            ".###.",
            "#####",
            "..#..",
            "..#..",
        ])))
        out.append(Puzzle(id: "arrow5", name: "سهم", size: .small, ink: ink(1, 0.7, 0.28), bitmap: bmp([
            "..#..",
            ".###.",
            "#.#.#",
            "..#..",
            "..#..",
        ])))
        out.append(Puzzle(id: "cup5", name: "كأس", size: .small, ink: ink(0.95, 0.5, 0.85), bitmap: bmp([
            ".....",
            "#####",
            ".###.",
            ".###.",
            ".###.",
        ])))

        // ── ١٠×١٠ ──
        out.append(Puzzle(id: "heart10", name: "قلب كبير", size: .medium, ink: ink(1, 0.34, 0.46), bitmap: bmp([
            ".##....##.",
            "##########",
            "##########",
            "##########",
            "##########",
            ".########.",
            "..######..",
            "...####...",
            "....##....",
            "..........",
        ])))
        out.append(Puzzle(id: "smiley10", name: "وجه", size: .medium, ink: ink(1, 0.82, 0.3), bitmap: bmp([
            "..######..",
            ".########.",
            "##.####.##",
            "##.####.##",
            "##########",
            "##########",
            "#.##..##.#",
            "##.####.##",
            ".########.",
            "..######..",
        ])))
        out.append(Puzzle(id: "fish10", name: "سمكة", size: .medium, ink: ink(0.3, 0.8, 0.95), bitmap: bmp([
            "..........",
            "..####....",
            ".######.#.",
            "#######.##",
            "#######.##",
            ".######.#.",
            "..####....",
            "..........",
            "..........",
            "..........",
        ])))
        out.append(Puzzle(id: "house10", name: "بيت", size: .medium, ink: ink(1, 0.6, 0.35), bitmap: bmp([
            "....##....",
            "...####...",
            "..######..",
            ".########.",
            "##########",
            ".########.",
            ".########.",
            ".###..###.",
            ".###..###.",
            ".###..###.",
        ])))
        out.append(Puzzle(id: "star10", name: "نجمة", size: .medium, ink: ink(1, 0.85, 0.28), bitmap: bmp([
            "....##....",
            "....##....",
            "...####...",
            "##########",
            ".########.",
            "..######..",
            "..######..",
            ".##....##.",
            ".##....##.",
            "##......##",
        ])))
        out.append(Puzzle(id: "anchor10", name: "مرساة", size: .medium, ink: ink(0.6, 0.72, 0.85), bitmap: bmp([
            "....##....",
            "...#..#...",
            "....##....",
            "....##....",
            ".########.",
            "....##....",
            "....##....",
            "#...##...#",
            "#..####..#",
            ".########.",
        ])))

        // ── ١٥×١٥ ──
        out.append(Puzzle(id: "heart15", name: "قلب", size: .large, ink: ink(1, 0.34, 0.46), bitmap: bmp([
            "..###.....###..",
            ".#####...#####.",
            "###############",
            "###############",
            "###############",
            "###############",
            ".#############.",
            "..###########..",
            "...#########...",
            "....#######....",
            ".....#####.....",
            "......###......",
            ".......#.......",
            "...............",
            "...............",
        ])))
        out.append(Puzzle(id: "key15", name: "مفتاح", size: .large, ink: ink(1, 0.82, 0.3), bitmap: bmp([
            "....#####......",
            "...#######.....",
            "..##.....##....",
            "..##.....##....",
            "..##.....##....",
            "...#######.....",
            "....#####......",
            ".....###.......",
            ".....###.......",
            ".....###.......",
            ".....#####.....",
            ".....###.......",
            ".....#####.....",
            ".....###.......",
            "...............",
        ])))
        out.append(Puzzle(id: "mushroom15", name: "فطر", size: .large, ink: ink(1, 0.42, 0.5), bitmap: bmp([
            "....#######....",
            "..###########..",
            ".#############.",
            "###############",
            "###############",
            "###############",
            ".#############.",
            "...#.#####.#...",
            "......###......",
            "......###......",
            "......###......",
            ".....#####.....",
            ".....#####.....",
            "...............",
            "...............",
        ])))
        out.append(Puzzle(id: "rocket15", name: "صاروخ", size: .large, ink: ink(0.6, 0.78, 1), bitmap: bmp([
            ".......#.......",
            "......###......",
            "......###......",
            ".....#####.....",
            ".....#.#.#.....",
            ".....#####.....",
            "....#######....",
            "....#######....",
            "....#######....",
            "...#.#####.#...",
            "..##.#####.##..",
            ".....#####.....",
            "......#.#......",
            ".......#.......",
            "...............",
        ])))

        return out
    }

    /// ألغاز حجم معيّن
    static func puzzles(_ size: Size) -> [Puzzle] {
        library().filter { $0.size == size }
    }
}
