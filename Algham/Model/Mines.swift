import Foundation

// محرّك «ألغام» (كنس الألغام) — منطق خالص بلا أيّ SwiftUI، ينفحص آليًّا.
// الخانة = فهرس واحد idx = صفّ*أعمدة + عمود. كلّ الدوال نقيّة وقابلة للفحص.

/// مولّد أرقام عشوائيّ ببذرة ثابتة (splitmix64) — نفس البذرة = نفس اللوح.
struct RNG: RandomNumberGenerator, Codable, Hashable {
    var s: UInt64
    init(_ seed: UInt64) { s = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// مستوى الصعوبة — (الأعمدة، الصفوف، عدد الألغام).
struct Diff: Hashable {
    let cols: Int
    let rows: Int
    let mines: Int
    let key: String
    let name: String
    var count: Int { cols * rows }
}

enum Diffs {
    static let easy = Diff(cols: 9, rows: 9, mines: 10, key: "e", name: "سهل")
    static let medium = Diff(cols: 12, rows: 14, mines: 26, key: "m", name: "متوسّط")
    static let hard = Diff(cols: 14, rows: 18, mines: 44, key: "h", name: "صعب")
    static let all: [Diff] = [easy, medium, hard]
    static func byKey(_ k: String) -> Diff { all.first(where: { $0.key == k }) ?? easy }
}

/// اللوح — قابل للترميز حتى نحفظ اللعبة الجارية.
struct Board: Codable {
    var rows: Int
    var cols: Int
    var mines: Int          // عدد الألغام الفعليّ على اللوح
    var mine: [Bool]        // هل الخانة لغم
    var adj: [Int]          // عدد الألغام المجاورة لكلّ خانة (0..8)
    var revealed: [Bool]    // مكشوفة
    var flagged: [Bool]     // عليها علم
    var seed: UInt64
    var started: Bool       // انزرعت الألغام (بعد أوّل نقرة)
    var dead: Bool          // انضغط لغم
    var boom: Int           // فهرس اللغم اللي انفجر (-1 لا شيء)

    var size: Int { rows * cols }

    /// لوح فاضي قبل أوّل نقرة — بلا ألغام (تنزرع بعد النقرة الأولى لضمان أمانها).
    static func empty(rows: Int, cols: Int, mines: Int, seed: UInt64) -> Board {
        let n = rows * cols
        return Board(rows: rows, cols: cols, mines: mines,
                     mine: Array(repeating: false, count: n),
                     adj: Array(repeating: 0, count: n),
                     revealed: Array(repeating: false, count: n),
                     flagged: Array(repeating: false, count: n),
                     seed: seed, started: false, dead: false, boom: -1)
    }
}

/// جيران الخانة الثمانية ضمن حدود اللوح (بلا تجاوز للحوافّ والزوايا).
func neighbors(_ idx: Int, _ rows: Int, _ cols: Int) -> [Int] {
    guard idx >= 0, idx < rows * cols, cols > 0 else { return [] }
    let r = idx / cols
    let c = idx % cols
    var out: [Int] = []
    var dr = -1
    while dr <= 1 {
        var dc = -1
        while dc <= 1 {
            if !(dr == 0 && dc == 0) {
                let nr = r + dr
                let nc = c + dc
                if nr >= 0 && nr < rows && nc >= 0 && nc < cols {
                    out.append(nr * cols + nc)
                }
            }
            dc += 1
        }
        dr += 1
    }
    return out
}

/// عدد الألغام المجاورة لخانة — يُحسب من حقل mine مباشرة (ما يعتمد على adj).
func neighborCount(_ b: Board, _ idx: Int) -> Int {
    var c = 0
    for n in neighbors(idx, b.rows, b.cols) where b.mine[n] { c += 1 }
    return c
}

/// يزرع الألغام مبتعدًا عن الخانة الأولى + جيرانها (أوّل نقرة آمنة دائمًا)، ثمّ يحسب الأرقام.
func layout(rows: Int, cols: Int, mines: Int, safe: Int, seed: UInt64) -> Board {
    let n = rows * cols
    var b = Board.empty(rows: rows, cols: cols, mines: 0, seed: seed)
    b.started = true

    var blocked = Set<Int>()
    if safe >= 0 && safe < n {
        blocked.insert(safe)
        for x in neighbors(safe, rows, cols) { blocked.insert(x) }
    }

    var pool = (0..<n).filter { !blocked.contains($0) }
    var rng = RNG(seed)
    pool.shuffle(using: &rng)

    let m = max(0, min(mines, pool.count))
    var k = 0
    while k < m {
        b.mine[pool[k]] = true
        k += 1
    }
    b.mines = m
    var i = 0
    while i < n {
        b.adj[i] = neighborCount(b, i)
        i += 1
    }
    return b
}

/// يكشف خانة. يرجع مجموعة الخانات المكشوفة حديثًا.
/// - خانة مكشوفة أو معلّمة: ما يصير شي.
/// - لغم: dead=true و boom=idx.
/// - خانة صفريّة: ينتشر الكشف (flood fill) ليشمل المنطقة الصفريّة وحوافّها المرقّمة.
@discardableResult
func reveal(_ b: inout Board, at start: Int) -> Set<Int> {
    guard start >= 0, start < b.size else { return [] }
    guard !b.revealed[start], !b.flagged[start] else { return [] }
    if b.mine[start] {
        b.revealed[start] = true
        b.dead = true
        b.boom = start
        return [start]
    }
    var out = Set<Int>()
    var stack: [Int] = [start]
    while let i = stack.popLast() {
        if b.revealed[i] || b.flagged[i] || b.mine[i] { continue }
        b.revealed[i] = true
        out.insert(i)
        if b.adj[i] == 0 {
            for nb in neighbors(i, b.rows, b.cols) where !b.revealed[nb] && !b.mine[nb] {
                stack.append(nb)
            }
        }
    }
    return out
}

/// يقلب علم خانة (ما يعلّم خانة مكشوفة).
func toggleFlag(_ b: inout Board, at idx: Int) {
    guard idx >= 0, idx < b.size, !b.revealed[idx] else { return }
    b.flagged[idx].toggle()
}

/// فوز = ما مات وكلّ الخانات غير الملغومة مكشوفة.
func isWin(_ b: Board) -> Bool {
    if b.dead { return false }
    var i = 0
    while i < b.size {
        if !b.mine[i] && !b.revealed[i] { return false }
        i += 1
    }
    return true
}

/// عدّادات: الألغام، الأعلام، المتبقّي (ألغام ناقص أعلام)، المكشوف.
func counts(_ b: Board) -> (mines: Int, flags: Int, remaining: Int, revealed: Int) {
    var flags = 0
    var rev = 0
    var i = 0
    while i < b.size {
        if b.flagged[i] { flags += 1 }
        if b.revealed[i] { rev += 1 }
        i += 1
    }
    return (b.mines, flags, b.mines - flags, rev)
}
