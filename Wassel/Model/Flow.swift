import Foundation

// محرّك «وصّل» — لعبة وصل النقاط المتشابهة بخطوط ما تتقاطع تملأ كامل الشبكة.
// منطق خالص (Foundation فقط) ينفحص آليًّا: المولّد يقطع مسار هاملتوني يملأ كلّ الخانات،
// وكلّ قطعة ياخذ طرفيها لونًا — فيضمن حلًّا كاملًا موجودًا دائمًا.

// ── مولّد أرقام عشوائيّة حتميّ (splitmix64)
struct FRNG: RandomNumberGenerator {
    var s: UInt64
    init(_ seed: UInt64) { s = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func int(_ r: Range<Int>) -> Int { Int.random(in: r, using: &self) }
    mutating func pick<T>(_ a: [T]) -> T { a[Int.random(in: 0..<a.count, using: &self)] }
}

// ── خانة بالشبكة
struct Cell: Hashable, Codable {
    var r: Int
    var c: Int
    init(_ r: Int, _ c: Int) { self.r = r; self.c = c }
}

// ── زوج طرفين بلون واحد
struct Pair: Hashable, Codable {
    var color: Int
    var a: Cell
    var b: Cell
}

// ── مرحلة مولّدة: الأطراف + الحلّ الكامل
struct FlowLevel {
    let seed: UInt64
    let size: Int
    let pairs: Int
    let endpoints: [Pair]        // طرفا كلّ لون
    let solution: [[Cell]]       // مسار الحلّ لكلّ لون (يملأ كامل الشبكة)

    // فهرس خطّيّ للخانة
    func idx(_ cell: Cell) -> Int { cell.r * size + cell.c }
}

// ── مواصفة مرحلة (حجم + عدد أزواج)
struct LevelSpec: Equatable {
    let size: Int
    let pairs: Int
}

enum Flow {

    // جيران خانة بالفهرس داخل شبكة size×size
    static func neighbors(_ i: Int, _ size: Int) -> [Int] {
        let r = i / size, c = i % size
        var out: [Int] = []
        if r > 0 { out.append(i - size) }
        if r < size - 1 { out.append(i + size) }
        if c > 0 { out.append(i - 1) }
        if c < size - 1 { out.append(i + 1) }
        return out
    }

    static func adjacent(_ a: Int, _ b: Int, _ size: Int) -> Bool {
        let ra = a / size, ca = a % size, rb = b / size, cb = b % size
        return (ra == rb && abs(ca - cb) == 1) || (ca == cb && abs(ra - rb) == 1)
    }

    static func cell(_ i: Int, _ size: Int) -> Cell { Cell(i / size, i % size) }

    // ── مسار هاملتوني عشوائيّ يغطّي كلّ الخانات (ثعبان + حركات backbite)
    // يبدأ بثعبان مضمون ثمّ يعشوِش مع الحفاظ على كونه مسارًا هاملتونيًّا
    static func hamiltonian(seed: UInt64, size: Int) -> [Int] {
        let n = size * size
        var path: [Int] = []
        path.reserveCapacity(n)
        for r in 0..<size {
            if r % 2 == 0 {
                for c in 0..<size { path.append(r * size + c) }
            } else {
                for c in stride(from: size - 1, through: 0, by: -1) { path.append(r * size + c) }
            }
        }
        var rng = FRNG(seed)
        // مكان كلّ خانة داخل المسار
        var pos = [Int](repeating: 0, count: n)
        for (k, v) in path.enumerated() { pos[v] = k }

        let iters = n * 8 + 60
        for _ in 0..<iters {
            // اختر طرفًا: الذيل (أو اقلب المسار حتى نعشوِش الرأس أحيانًا)
            if rng.int(0..<2) == 0 {
                path.reverse()
                for (k, v) in path.enumerated() { pos[v] = k }
            }
            let last = n - 1
            let end = path[last]
            // جار للطرف داخل المسار (مو الجار المباشر بالمسار)
            let cand = neighbors(end, size).filter { $0 != path[last - 1] }
            guard !cand.isEmpty else { continue }
            let nb = rng.pick(cand)
            let j = pos[nb]
            if j >= last { continue }
            // اقلب المقطع بعد j حتى يبقى مسارًا
            var lo = j + 1, hi = last
            while lo < hi { path.swapAt(lo, hi); lo += 1; hi -= 1 }
            for k in (j + 1)...last { pos[path[k]] = k }
        }
        return path
    }

    // عدد الأزواج الآمن لحجم معيّن
    static func clampPairs(_ size: Int, _ pairs: Int?) -> Int {
        let n = size * size
        let def = max(3, size - 1)
        let p = pairs ?? def
        return max(2, min(p, n / 2))
    }

    // ── توليد مرحلة قابلة للحلّ بملء كامل مضمون
    static func generate(seed: UInt64, size: Int, pairs: Int? = nil) -> FlowLevel {
        let n = size * size
        let p = clampPairs(size, pairs)
        let path = hamiltonian(seed: seed, size: size)

        // اقطع المسار إلى p قطع، كلّ قطعة طولها ≥ 2
        var sizes = [Int](repeating: 2, count: p)
        var rem = n - 2 * p
        var rng = FRNG(seed ^ 0xD1B54A32D192ED03)
        while rem > 0 {
            sizes[rng.int(0..<p)] += 1
            rem -= 1
        }

        var endpoints: [Pair] = []
        var solution: [[Cell]] = []
        var start = 0
        for color in 0..<p {
            let len = sizes[color]
            let seg = Array(path[start..<(start + len)])
            start += len
            let cells = seg.map { cell($0, size) }
            solution.append(cells)
            endpoints.append(Pair(color: color, a: cells.first!, b: cells.last!))
        }
        return FlowLevel(seed: seed, size: size, pairs: p, endpoints: endpoints, solution: solution)
    }

    // ── مدقّق حالة اللوح: (كلّ الأزواج موصولة, نسبة الملء, أيّ تقاطع؟)
    // paths: لون → خانات المسار المرسوم (مرتّبة، تتضمّن الطرفين)
    static func validate(size: Int, endpoints: [Pair], paths: [Int: [Cell]]) -> (allConnected: Bool, filledPercent: Int, anyCross: Bool) {
        let n = size * size
        var occ = [Int](repeating: 0, count: n)       // كم لون يحتلّ كلّ خانة
        var filledSet = Set<Int>()
        var anyCross = false

        for (_, cells) in paths {
            for cell in cells {
                let i = cell.r * size + cell.c
                guard i >= 0 && i < n else { continue }
                occ[i] += 1
                if occ[i] > 1 { anyCross = true }
                filledSet.insert(i)
            }
        }

        var allConnected = true
        for pair in endpoints {
            guard let cells = paths[pair.color], cells.count >= 2 else { allConnected = false; continue }
            // تلاصق متتابع
            var ok = true
            for k in 1..<cells.count {
                let a = cells[k - 1].r * size + cells[k - 1].c
                let b = cells[k].r * size + cells[k].c
                if !adjacent(a, b, size) { ok = false; break }
            }
            // بلا تكرار خانة داخل نفس المسار
            if Set(cells).count != cells.count { ok = false }
            let ends = Set([cells.first!, cells.last!])
            if ends != Set([pair.a, pair.b]) { ok = false }
            if !ok { allConnected = false }
        }

        let filled = filledSet.count * 100 / n
        return (allConnected, filled, anyCross)
    }
}

// ── نموذج اللوح التفاعليّ (المسارات المرسومة حاليًّا) — منطق خالص يُستعمل بالواجهة والفحص
struct Board {
    let size: Int
    let pairs: Int
    let ea: [Int]          // فهرس الطرف A لكلّ لون
    let eb: [Int]          // فهرس الطرف B لكلّ لون
    var paths: [[Int]]     // فهارس مرتّبة لكلّ لون (فارغ = ما رُسم)
    private let level: FlowLevel

    init(_ level: FlowLevel) {
        self.level = level
        self.size = level.size
        self.pairs = level.pairs
        self.ea = level.endpoints.map { $0.a.r * level.size + $0.a.c }
        self.eb = level.endpoints.map { $0.b.r * level.size + $0.b.c }
        self.paths = Array(repeating: [], count: level.pairs)
    }

    // اللون الذي يملك هذا الطرف (نقطة)، إن وُجد
    func endpointColor(_ i: Int) -> Int? {
        for c in 0..<pairs where ea[c] == i || eb[c] == i { return c }
        return nil
    }

    // اللون الذي يحتلّ الخانة بمساره المرسوم
    func owner(_ i: Int) -> Int? {
        for c in 0..<pairs where paths[c].contains(i) { return c }
        return nil
    }

    func head(_ color: Int) -> Int? { paths[color].last }

    // الطرف الآخر لنفس اللون بالنسبة لنقطة البداية
    func otherEnd(_ color: Int, from i: Int) -> Int { ea[color] == i ? eb[color] : ea[color] }

    // هل اللون موصول بالكامل (طرف لطرف)؟
    func connected(_ color: Int) -> Bool {
        let p = paths[color]
        guard p.count >= 2 else { return false }
        let ends = Set([p.first!, p.last!])
        return ends == Set([ea[color], eb[color]])
    }

    // ابدأ رسم لون من أحد طرفيه (يمسح مساره القديم)
    mutating func start(_ color: Int, at i: Int) {
        guard i == ea[color] || i == eb[color] else { return }
        paths[color] = [i]
    }

    mutating func clear(_ color: Int) { paths[color] = [] }

    mutating func clearAll() { for c in 0..<pairs { paths[c] = [] } }

    // امسك أنبوبًا مرسومًا عند الخانة i وكمّل منها (يقصّ ما بعدها)
    mutating func grab(_ color: Int, at i: Int) {
        if let k = paths[color].firstIndex(of: i) { paths[color].removeSubrange((k + 1)...) }
    }

    // ارسم حلّ لون كاملًا (للتلميح) — extend يقصّ أيّ تداخل مع ألوان أخرى
    mutating func solve(_ color: Int, path: [Int]) {
        guard let first = path.first else { return }
        clear(color)
        start(color, at: first)
        for j in path.dropFirst() { extend(color, to: j) }
    }

    // امسح مقطع لون من الخانة i وما بعدها (عند قطع مسار آخر)
    private mutating func cut(_ color: Int, at i: Int) {
        if let k = paths[color].firstIndex(of: i) { paths[color].removeSubrange(k...) }
    }

    // مدّ مسار اللون إلى خانة مجاورة j. يرجّع true إذا تحرّك.
    @discardableResult
    mutating func extend(_ color: Int, to j: Int) -> Bool {
        guard let h = paths[color].last else { return false }
        guard Flow.adjacent(h, j, size) else { return false }
        let cnt = paths[color].count
        // تراجع خطوة
        if cnt >= 2 && paths[color][cnt - 2] == j { paths[color].removeLast(); return true }
        // التفاف على نفس المسار → قصّ لـ j
        if let k = paths[color].firstIndex(of: j) {
            paths[color].removeSubrange((k + 1)...)
            return true
        }
        // لا تدخل طرف لون آخر
        if let ec = endpointColor(j), ec != color { return false }
        // لا تمدّ بعد ما توصل طرفك الآخر
        if h == otherEnd(color, from: paths[color].first ?? h) { return false }
        // اقطع مسار لون آخر يحتلّ j
        if let oc = owner(j), oc != color { cut(oc, at: j) }
        paths[color].append(j)
        return true
    }

    // خانات لون كـ Cell (للواجهة)
    func cells(_ color: Int) -> [Cell] { paths[color].map { Flow.cell($0, size) } }

    var pathsByColor: [Int: [Cell]] {
        var d: [Int: [Cell]] = [:]
        for c in 0..<pairs where !paths[c].isEmpty { d[c] = cells(c) }
        return d
    }

    var status: (allConnected: Bool, filledPercent: Int, anyCross: Bool) {
        Flow.validate(size: size, endpoints: level.endpoints, paths: pathsByColor)
    }

    var connectedCount: Int { (0..<pairs).filter { connected($0) }.count }
    var filledPercent: Int { status.filledPercent }
    var won: Bool {
        let s = status
        return s.allConnected && s.filledPercent == 100 && !s.anyCross
    }
}

// ── كتاب المراحل: تدرّج بالحجم والصعوبة
enum Levels {
    static let book: [LevelSpec] = {
        var b: [LevelSpec] = []
        let plan: [(Int, [Int])] = [
            (5, [3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5]),
            (6, [4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6]),
            (7, [5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 7]),
            (8, [6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 8, 8])
        ]
        for (size, ps) in plan {
            for p in ps { b.append(LevelSpec(size: size, pairs: p)) }
        }
        return b
    }()

    static var count: Int { book.count }

    // بذرة حتميّة لكلّ مرحلة
    static func seed(_ index: Int) -> UInt64 {
        UInt64(bitPattern: Int64(index + 1)) &* 0x9E3779B97F4A7C15 &+ 0x1234_5678
    }

    static func level(_ index: Int) -> FlowLevel {
        let i = max(0, min(index, book.count - 1))
        let spec = book[i]
        return Flow.generate(seed: seed(i), size: spec.size, pairs: spec.pairs)
    }

    // لغز اليوم: ثابت لكلّ الناس حسب التاريخ
    static func dailySeed(_ date: Date = Date()) -> UInt64 {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 2026, m = c.month ?? 1, d = c.day ?? 1
        return UInt64(y * 10000 + m * 100 + d) &* 0x2545F4914F6CDD1D &+ 7
    }

    static func daily(_ date: Date = Date()) -> FlowLevel {
        let c = Calendar.current.dateComponents([.day], from: date)
        let day = c.day ?? 1
        let size = 6 + (day % 3)          // 6..8
        let pairs = 4 + (day % 4)         // 4..7
        return Flow.generate(seed: dailySeed(date), size: size, pairs: pairs)
    }
}
