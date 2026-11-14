import Foundation

// ───────────────────────── منطق لعبة البحث عن الكلمات ─────────────────────────
// خالص: Foundation فقط، بلا SwiftUI. يولّد شبكة حروف حتميّة لكلّ بذرة،
// يخبّي كلمات بثمان اتّجاهات، يملأ الباقي بحروف عربيّة عشوائيّة حتميّة،
// ويتأكّد إذا خطّ مستقيم على الشبكة يهجّي كلمة هدف (بالاتّجاهين).

// MARK: - خليّة وموضع

public struct Cell: Equatable, Hashable {
    public let r: Int
    public let c: Int
    public init(_ r: Int, _ c: Int) { self.r = r; self.c = c }
}

public struct Placement: Equatable {
    public let word: String
    public let cells: [Cell]
    public init(word: String, cells: [Cell]) { self.word = word; self.cells = cells }
}

// MARK: - مولّد أرقام عشوائيّة حتميّ (SplitMix64)

public struct RNG {
    private var state: UInt64
    public init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// عدد صحيح في [0, n)
    public mutating func int(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(next() % UInt64(n))
    }
}

// MARK: - الاتّجاهات الثمانية

public enum Dir {
    /// (صف، عمود): أفقيّ، عموديّ، وقطريّ بالاتّجاهين
    public static let all: [(dr: Int, dc: Int)] = [
        (0, 1), (0, -1), (1, 0), (-1, 0),
        (1, 1), (1, -1), (-1, 1), (-1, -1)
    ]
}

// MARK: - المحرّك

public enum Search {

    /// أبجديّة التعبئة: 28 حرفًا عربيًّا بالشكل المعزول.
    public static let alphabet: [Character] = Array("ابتثجحخدذرزسشصضطظعغفقكلمنهوي")

    /// يولّد شبكة مربّعة ويخبّي كلّ الكلمات. حتميّ لكلّ (كلمات، حجم، بذرة).
    /// يرجّع المواضع بترتيب الكلمات المُدخَلة.
    public static func generate(words: [String], size: Int, seed: UInt64)
        -> (grid: [[Character]], placements: [Placement]) {

        var rng = RNG(seed)
        var g = [[Character?]](repeating: [Character?](repeating: nil, count: size), count: size)
        var found: [String: Placement] = [:]

        // الأطول أوّلًا: يحسّن نسبة النجاح بالتعبئة
        let ordered = words.sorted { $0.count > $1.count }
        for w in ordered {
            let chars = Array(w)
            let len = chars.count
            var placed = false
            var tries = 0
            while tries < 4000 && !placed {
                tries += 1
                let d = Dir.all[rng.int(Dir.all.count)]
                let r0 = rng.int(size)
                let c0 = rng.int(size)
                let rEnd = r0 + d.dr * (len - 1)
                let cEnd = c0 + d.dc * (len - 1)
                if rEnd < 0 || rEnd >= size || cEnd < 0 || cEnd >= size { continue }
                if !fits(g, chars, r0, c0, d) { continue }
                var cells: [Cell] = []
                for i in 0..<len {
                    let rr = r0 + d.dr * i
                    let cc = c0 + d.dc * i
                    g[rr][cc] = chars[i]
                    cells.append(Cell(rr, cc))
                }
                found[w] = Placement(word: w, cells: cells)
                placed = true
            }
        }

        // تعبئة الفراغات بحروف حتميّة
        var out = [[Character]](repeating: [Character](repeating: " ", count: size), count: size)
        for r in 0..<size {
            for c in 0..<size {
                if let ch = g[r][c] {
                    out[r][c] = ch
                } else {
                    out[r][c] = alphabet[rng.int(alphabet.count)]
                }
            }
        }

        // رجّع المواضع بترتيب الإدخال
        var placements: [Placement] = []
        for w in words {
            if let p = found[w] { placements.append(p) }
        }
        return (out, placements)
    }

    /// هل تنوضع الكلمة ابتداءً من (r0,c0) بالاتّجاه d بلا تعارض؟
    /// التداخل مسموح فقط على حرف مطابق.
    private static func fits(_ g: [[Character?]], _ chars: [Character], _ r0: Int, _ c0: Int, _ d: (dr: Int, dc: Int)) -> Bool {
        for i in 0..<chars.count {
            let rr = r0 + d.dr * i
            let cc = c0 + d.dc * i
            if let ex = g[rr][cc], ex != chars[i] { return false }
        }
        return true
    }

    // MARK: - مطابقة الخطّ المسحوب

    /// خلايا الخطّ المستقيم من a إلى b، أو nil إذا مو خطًّا بأحد الاتّجاهات الثمانية.
    public static func cellsOnLine(from a: Cell, to b: Cell) -> [Cell]? {
        if a == b { return [a] }
        let dr = b.r - a.r
        let dc = b.c - a.c
        let adr = abs(dr)
        let adc = abs(dc)
        // مستقيم = أفقيّ (dr=0) أو عموديّ (dc=0) أو قطريّ (|dr|=|dc|)
        if !(dr == 0 || dc == 0 || adr == adc) { return nil }
        let steps = max(adr, adc)
        let sr = dr == 0 ? 0 : dr / adr
        let sc = dc == 0 ? 0 : dc / adc
        var cells: [Cell] = []
        cells.reserveCapacity(steps + 1)
        for i in 0...steps { cells.append(Cell(a.r + sr * i, a.c + sc * i)) }
        return cells
    }

    /// يقرأ الحروف على مجموعة خلايا كنصّ.
    public static func read(_ grid: [[Character]], _ cells: [Cell]) -> String {
        var s = ""
        let n = grid.count
        for cl in cells {
            guard cl.r >= 0, cl.r < n, cl.c >= 0, cl.c < (n > 0 ? grid[cl.r].count : 0) else { return "" }
            s.append(grid[cl.r][cl.c])
        }
        return s
    }

    /// هل الخطّ من a إلى b يهجّي الكلمة الهدف (بالاتّجاهين)؟
    public static func lineMatches(_ grid: [[Character]], from a: Cell, to b: Cell, target: String) -> Bool {
        guard let cells = cellsOnLine(from: a, to: b) else { return false }
        let n = grid.count
        for cl in cells {
            if cl.r < 0 || cl.r >= n || cl.c < 0 || cl.c >= grid[cl.r].count { return false }
        }
        let s = read(grid, cells)
        if s.isEmpty { return false }
        return s == target || String(s.reversed()) == target
    }

    /// يرجّع الكلمة الهدف اللي يطابقها الخطّ من a إلى b، أو nil.
    public static func matchedWord(_ grid: [[Character]], from a: Cell, to b: Cell, targets: [String]) -> String? {
        guard let cells = cellsOnLine(from: a, to: b) else { return nil }
        let n = grid.count
        for cl in cells {
            if cl.r < 0 || cl.r >= n || cl.c < 0 || cl.c >= grid[cl.r].count { return nil }
        }
        let s = read(grid, cells)
        if s.isEmpty { return nil }
        let rev = String(s.reversed())
        for t in targets where s == t || rev == t { return t }
        return nil
    }
}

// MARK: - الثيمات والمراحل

public struct Theme: Equatable {
    public let name: String
    public let emoji: String
    public let words: [String]
    public let size: Int
    public init(name: String, emoji: String, words: [String], size: Int) {
        self.name = name; self.emoji = emoji; self.words = words; self.size = size
    }
}

public struct Level: Equatable {
    public let index: Int
    public let theme: Theme
    public let seed: UInt64
    public init(index: Int, theme: Theme, seed: UInt64) {
        self.index = index; self.theme = theme; self.seed = seed
    }
    /// يولّد شبكة هالمرحلة ومواضعها.
    public func build() -> (grid: [[Character]], placements: [Placement]) {
        Search.generate(words: theme.words, size: theme.size, seed: seed)
    }
}

public enum Levels {

    /// ثيمات عالميّة عامّة (مو محلّيّة): فواكه، حيوانات، بلدان، رياضة...
    public static let themes: [Theme] = [
        Theme(name: "فواكه", emoji: "🍎", words: ["تفاح", "موز", "عنب", "برتقال", "رمان", "فراولة", "مانجو", "خوخ"], size: 10),
        Theme(name: "حيوانات", emoji: "🦁", words: ["اسد", "نمر", "فيل", "زرافة", "حصان", "ارنب", "ثعلب", "غزال"], size: 10),
        Theme(name: "بلدان", emoji: "🌍", words: ["مصر", "فرنسا", "كندا", "الهند", "تركيا", "اليابان", "ايطاليا", "البرازيل"], size: 11),
        Theme(name: "رياضة", emoji: "⚽", words: ["كرة", "سباحة", "تنس", "ملاكمة", "جري", "ركض", "جمباز", "تزلج"], size: 10),
        Theme(name: "الوان", emoji: "🎨", words: ["احمر", "اخضر", "ازرق", "اصفر", "اسود", "ابيض", "وردي", "بني"], size: 9),
        Theme(name: "مهن", emoji: "🧑‍🔧", words: ["طبيب", "معلم", "مهندس", "طيار", "شرطي", "خباز", "نجار", "رسام"], size: 10),
        Theme(name: "فضاء", emoji: "🚀", words: ["نجم", "كوكب", "قمر", "شمس", "مجرة", "صاروخ", "نيزك", "مذنب"], size: 10),
        Theme(name: "بحر", emoji: "🌊", words: ["سمك", "موج", "قارب", "حوت", "سفينة", "مرجان", "صدف", "غواص"], size: 10),
        Theme(name: "طعام", emoji: "🍲", words: ["خبز", "لحم", "دجاج", "جبن", "بيض", "حليب", "عسل", "تمر"], size: 9),
        Theme(name: "طيور", emoji: "🦅", words: ["نسر", "بومة", "صقر", "حمامة", "عصفور", "طاووس", "دجاجة", "بطريق"], size: 10),
        Theme(name: "ادوات", emoji: "🔧", words: ["مفك", "سكين", "مطرقة", "منشار", "مسمار", "ملعقة", "فرشاة", "ميزان"], size: 10),
        Theme(name: "موسيقى", emoji: "🎵", words: ["عود", "ناي", "طبل", "كمان", "بيانو", "جيتار", "مزمار", "قيثارة"], size: 10)
    ]

    /// عدد المراحل الكلّيّ (تدور على الثيمات ببذور مختلفة = تخطيط جديد كلّ مرّة).
    public static let count = 30

    public static func level(_ index: Int) -> Level {
        let t = themes[index % themes.count]
        // بذرة مميّزة لكلّ مرحلة حتى يختلف التخطيط حتّى لنفس الثيمة
        let seed = (UInt64(index) &+ 1) &* 0x9E3779B97F4A7C15 ^ 0xD1B54A32D192ED03
        return Level(index: index, theme: t, seed: seed)
    }

    public static var all: [Level] { (0..<count).map { level($0) } }
}
