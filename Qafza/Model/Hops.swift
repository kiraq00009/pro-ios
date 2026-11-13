import Foundation

// منطق لعبة «قفزة» (Foundation فقط): توليد المراحل، الحركات المسموحة، والحلّال — ينفحص آليًّا
//
// القاعدة: كلّ مربّع بيه رقم. من المربّع اللي إنت عليه تقفز بالضبط «رقمه» مربّعات، بخطّ مستقيم (فوق/جوّه/يمين/يسار)،
// على مربّع ما مرّيت عليه. الهدف: تمرّ على كلّ المربّعات مرّة وحدة. المربّع ★ هو آخر محطّة.

struct Level: Codable, Equatable {
    var w: Int
    var h: Int
    var nums: [Int]          // رقم كلّ مربّع (0 = النجمة، آخر مربّع)
    var start: Int
    var solution: [Int]      // ترتيب المربّعات بالحلّ
    var count: Int { w * h }
}

/// مولّد عشوائيّ ثابت: نفس البذرة ⇒ نفس المرحلة على كلّ الأجهزة
struct SplitMix: RandomNumberGenerator {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum Hops {
    static let total = 60

    /// المربّعات اللي تگدر تقفز عليها من `at` (بالضبط رقمه، وما مزورة)
    static func moves(_ l: Level, visited: [Bool], at: Int) -> [Int] {
        let k = l.nums[at]
        guard k > 0 else { return [] }
        let x = at % l.w, y = at / l.w
        var out: [Int] = []
        for (dx, dy) in [(k, 0), (-k, 0), (0, k), (0, -k)] {
            let nx = x + dx, ny = y + dy
            if nx >= 0, nx < l.w, ny >= 0, ny < l.h, !visited[ny * l.w + nx] { out.append(ny * l.w + nx) }
        }
        return out
    }

    /// يتأكّد إنّ مسار معيّن حلّ صحيح للمرحلة
    static func valid(_ l: Level, path: [Int]) -> Bool {
        guard path.count == l.count, path.first == l.start, Set(path).count == l.count else { return false }
        var visited = [Bool](repeating: false, count: l.count)
        visited[path[0]] = true
        for i in 1..<path.count {
            guard moves(l, visited: visited, at: path[i - 1]).contains(path[i]) else { return false }
            visited[path[i]] = true
        }
        return true
    }

    /// عدد الحلول (يوقف عند `cap`)
    static func solutions(_ l: Level, cap: Int = 2) -> Int {
        var visited = [Bool](repeating: false, count: l.count)
        var found = 0, left = l.count - 1
        visited[l.start] = true
        func go(_ at: Int) {
            if found >= cap { return }
            if left == 0 { found += 1; return }
            for n in moves(l, visited: visited, at: at) {
                visited[n] = true; left -= 1
                go(n)
                visited[n] = false; left += 1
                if found >= cap { return }
            }
        }
        go(l.start)
        return found
    }

    /// يكمّل الحلّ من وضع اللاعب الحاليّ (للتلميح) — nil إذا الوضع مسدود
    static func complete(_ l: Level, path: [Int]) -> [Int]? {
        guard let cur = path.last else { return nil }
        var visited = [Bool](repeating: false, count: l.count)
        for p in path { visited[p] = true }
        var rest: [Int] = []
        var left = l.count - path.count
        func go(_ at: Int) -> Bool {
            if left == 0 { return true }
            for n in moves(l, visited: visited, at: at) {
                visited[n] = true; left -= 1; rest.append(n)
                if go(n) { return true }
                visited[n] = false; left += 1; rest.removeLast()
            }
            return false
        }
        return go(cur) ? rest : nil
    }

    /// يولّد مرحلة: نرسم مسار عشوائيّ يمرّ على كلّ المربّعات (كلّ خطوة بنفس الصفّ أو العمود)، ثمّ رقم كلّ مربّع = مسافته للّي بعده
    static func generate(w: Int, h: Int, seed: UInt64) -> Level? {
        var rng = SplitMix(seed)
        let n = w * h
        var visited = [Bool](repeating: false, count: n)
        var path: [Int] = []
        var budget = 40_000
        func options(_ at: Int) -> [Int] {
            let x = at % w, y = at / w
            var out: [Int] = []
            for i in 0..<w where i != x && !visited[y * w + i] { out.append(y * w + i) }
            for j in 0..<h where j != y && !visited[j * w + x] { out.append(j * w + x) }
            return out
        }
        func go(_ at: Int) -> Bool {
            if path.count == n { return true }
            budget -= 1
            if budget <= 0 { return false }
            var opts = options(at)
            opts.shuffle(using: &rng)
            // الأضيق أوّلًا: نروح للمربّع اللي خياراته أقلّ حتى ما ننحصر
            let scored = opts.map { o -> (Int, Int) in visited[o] = true; let c = options(o).count; visited[o] = false; return (o, c) }.sorted { $0.1 < $1.1 }
            for (o, _) in scored {
                visited[o] = true; path.append(o)
                if go(o) { return true }
                visited[o] = false; path.removeLast()
                if budget <= 0 { return false }
            }
            return false
        }
        let start = Int.random(in: 0..<n, using: &rng)
        visited[start] = true; path = [start]
        guard go(start) else { return nil }
        var nums = [Int](repeating: 0, count: n)
        for i in 0..<(n - 1) {
            let a = path[i], b = path[i + 1]
            nums[a] = abs(a % w - b % w) + abs(a / w - b / w)
        }
        return Level(w: w, h: h, nums: nums, start: start, solution: path)
    }

    /// مقاس كلّ مرحلة: تكبر وتصعب بالتدريج
    static func size(_ index: Int) -> (w: Int, h: Int) {
        switch index {
        case ..<4: return (3, 3)
        case ..<10: return (4, 3)
        case ..<18: return (4, 4)
        case ..<26: return (5, 4)
        case ..<36: return (5, 5)
        case ..<48: return (6, 5)
        default: return (6, 6)
        }
    }

    /// مرحلة رقم `index` (من 0): نجرّب كم بذرة وناخذ اللي حلّها وحيد (أو الأقلّ حلول) — ثابتة لكلّ رقم
    static func level(_ index: Int, salt: UInt64 = 0) -> Level {
        let s = size(index)
        var best: Level? = nil
        var bestCount = Int.max
        for k in 0..<24 {
            guard let l = generate(w: s.w, h: s.h, seed: UInt64(index) &* 7919 &+ UInt64(k) &* 104_729 &+ salt &* 1_000_003 &+ 17) else { continue }
            let c = solutions(l, cap: 4)
            if c >= 1 && c < bestCount { best = l; bestCount = c; if c == 1 { break } }
        }
        // احتياط ما ينوصله عمليًّا: مرحلة ٢×٢ معروفة
        return best ?? Level(w: 2, h: 2, nums: [1, 1, 0, 1], start: 0, solution: [0, 1, 3, 2])
    }

    /// لغز اليوم: نفس اللغز لكلّ الناس بنفس التاريخ
    static func daily(year: Int, month: Int, day: Int) -> Level {
        level(30 + (day % 18), salt: UInt64(year * 10_000 + month * 100 + day))
    }
}
