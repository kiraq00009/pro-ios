import Foundation

/// اتّحاد-إيجاد (Union-Find) مع ضغط المسار والرتبة، ويكبر عند الحاجة
struct FZUnionFind {
    private(set) var parent: [Int]
    private var rank: [Int]

    init(_ n: Int) {
        parent = Array(0..<max(0, n))
        rank = [Int](repeating: 0, count: max(0, n))
    }

    var count: Int { parent.count }

    @discardableResult
    mutating func add() -> Int {
        parent.append(parent.count)
        rank.append(0)
        return parent.count - 1
    }

    mutating func find(_ x: Int) -> Int {
        var r = x
        while parent[r] != r { r = parent[r] }
        var c = x
        while parent[c] != r {
            let next = parent[c]
            parent[c] = r
            c = next
        }
        return r
    }

    @discardableResult
    mutating func union(_ a: Int, _ b: Int) -> Bool {
        let ra = find(a), rb = find(b)
        if ra == rb { return false }
        if rank[ra] < rank[rb] { parent[ra] = rb }
        else if rank[ra] > rank[rb] { parent[rb] = ra }
        else { parent[rb] = ra; rank[ra] += 1 }
        return true
    }

    mutating func same(_ a: Int, _ b: Int) -> Bool { find(a) == find(b) }

    /// المجموعات اللي حجمها ≥ minSize، كلّ مجموعة مرتّبة، والمجموعات مرتّبة بأوّل عنصر
    mutating func groups(minSize: Int = 2) -> [[Int]] {
        var d: [Int: [Int]] = [:]
        for i in 0..<parent.count { d[find(i), default: []].append(i) }
        let gs: [[Int]] = d.values.filter { $0.count >= minSize }.map { $0.sorted() }
        return gs.sorted { ($0.first ?? 0) < ($1.first ?? 0) }
    }
}

enum FZVec {
    static func norm(_ v: [Float]) -> Double {
        var s = 0.0
        for x in v { s += Double(x) * Double(x) }
        return s.squareRoot()
    }

    static func normalized(_ v: [Float]) -> [Float] {
        let n = norm(v)
        guard n > 0 else { return v }
        return v.map { Float(Double($0) / n) }
    }

    /// مسافة إقليديّة. أبعاد مختلفة ⇒ لا نهائيّة
    static func distance(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return .infinity }
        var s = 0.0
        for i in 0..<a.count {
            let d = Double(a[i]) - Double(b[i])
            s += d * d
        }
        return s.squareRoot()
    }
}

enum FZCluster {
    /// تجميع دفعة واحدة: نرتّب بالوقت ونقارن كلّ صورة بآخر `window` صور ضمن `maxGap` ثانية
    static func groups(times: [Double], vectors: [[Float]], threshold: Double, maxGap: Double, window: Int = 12) -> [[Int]] {
        let n = min(times.count, vectors.count)
        guard n > 1 else { return [] }
        let order: [Int] = (0..<n).sorted { (a: Int, b: Int) -> Bool in
            if times[a] != times[b] { return times[a] < times[b] }
            return a < b
        }
        var uf = FZUnionFind(n)
        for k in 0..<n {
            let i = order[k]
            var j = k - 1
            var steps = 0
            while j >= 0 && steps < window {
                let o = order[j]
                if times[i] - times[o] > maxGap { break }
                if FZVec.distance(vectors[i], vectors[o]) <= threshold { uf.union(i, o) }
                j -= 1
                steps += 1
            }
        }
        return uf.groups()
    }

    /// تجميع جشع بمرساة: الصورة تنضمّ لأوّل مجموعة مرساتها قريبة كفاية، وإلّا تبدأ مجموعة جديدة.
    /// ما يسمح بالتسلسل (أ≈ب≈ج بينما أ بعيدة عن ج).
    static func greedy(vectors: [[Float]], threshold: Double) -> [[Int]] {
        var anchors: [Int] = []
        var gs: [[Int]] = []
        for i in 0..<vectors.count {
            var placed = false
            for g in 0..<anchors.count {
                if FZVec.distance(vectors[i], vectors[anchors[g]]) <= threshold {
                    gs[g].append(i)
                    placed = true
                    break
                }
            }
            if !placed {
                anchors.append(i)
                gs.append([i])
            }
        }
        return gs.filter { $0.count >= 2 }
    }
}

/// تجميع متدفّق أثناء الفحص: ما نخزّن بصمات كلّ المكتبة، بس نافذة صغيرة من آخر الصور
struct FZStreamCluster {
    private struct Entry {
        let idx: Int
        let t: Double
        let v: [Float]
    }

    let threshold: Double
    let maxGap: Double
    let window: Int
    private var uf = FZUnionFind(0)
    private var buf: [Entry] = []

    init(threshold: Double, maxGap: Double, window: Int = 12) {
        self.threshold = threshold
        self.maxGap = maxGap
        self.window = max(1, window)
    }

    var count: Int { uf.count }
    var buffered: Int { buf.count }

    /// يرجّع رقم العنصر (تسلسليّ من 0). vector = nil ⇒ عنصر ما يدخل بالتجميع (فيديو، لقطة شاشة…)
    @discardableResult
    mutating func add(time: Double, vector: [Float]?) -> Int {
        let idx = uf.add()
        guard let v = vector else { return idx }
        let gap = maxGap
        buf.removeAll { abs(time - $0.t) > gap }
        for e in buf where FZVec.distance(v, e.v) <= threshold {
            uf.union(idx, e.idx)
        }
        buf.append(Entry(idx: idx, t: time, v: v))
        if buf.count > window { buf.removeFirst(buf.count - window) }
        return idx
    }

    mutating func groups() -> [[Int]] { uf.groups() }
}
