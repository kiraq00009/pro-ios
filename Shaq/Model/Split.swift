import Foundation

/// نتيجة شقّ شكل بخطّ: القطع يسار الخطّ (plus) ويمينه (minus)
struct CutResult {
    var plus: [Shape]
    var minus: [Shape]
    var pieces: [Shape] { plus + minus }
    var plusArea: Double { plus.reduce(0.0) { $0 + $1.area } }
    var minusArea: Double { minus.reduce(0.0) { $0 + $1.area } }
    /// الخطّ فعلًا قسم الشكل (أكو شي بالجهتين)
    var crossed: Bool { !plus.isEmpty && !minus.isEmpty }
}

enum Cutter {
    static let eps = 1e-9
    /// أصغر مساحة نعتبرها قطعة
    static let minPiece = 1e-9

    private struct X {
        let ring: Int
        let edge: Int
        let pt: P
        let t: Double
        let tb: Double      // كسر التعادل لمّا يمرّ الخطّ برأس بالضبط
        let toPlus: Bool
    }

    /// يشقّ شكلًا (مقعّرًا أو بثقوب) بخطّ لا نهائيّ ويرجّع كلّ القطع المنفصلة.
    /// الفكرة: نقطّع كلّ حلقة عند نقاط التقاطع إلى سلاسل بكلّ جهة، ونرتّب نقاط التقاطع على الخطّ؛
    /// كلّ نقطتين متتاليتين = مقطع من الخطّ داخل الشكل، فنربط آخر السلسلة بشريكتها ونكمل لحدّ ما تنغلق القطعة.
    static func split(_ s: Shape, by L: Line) -> CutResult {
        let rings: [Ring] = [Poly.ccw(s.outer)] + s.holes.map { Poly.cw($0) }
        var xs: [X] = []
        var signs: [[Bool]] = []
        var ringX: [[Int]] = []
        for (ri, r) in rings.enumerated() {
            let d: [Double] = r.map { L.side($0) }
            let sg: [Bool] = d.map { $0 >= -eps }      // النقطة على الخطّ تنحسب يسار
            signs.append(sg)
            var mine: [Int] = []
            let n = r.count
            if n >= 3 {
                for i in 0..<n {
                    let j = (i + 1) % n
                    if sg[i] != sg[j] {
                        let di = d[i], dj = d[j]
                        var u = di / (di - dj)
                        if !u.isFinite { u = 0.5 }
                        u = min(1, max(0, u))
                        let p = r[i] + (r[j] - r[i]) * u
                        let pp = sg[i] ? r[i] : r[j], mm = sg[i] ? r[j] : r[i]
                        let tb = (mm - pp).dot(L.dir) / max(1e-12, abs(L.side(mm) - L.side(pp)))
                        xs.append(X(ring: ri, edge: i, pt: p, t: L.param(p), tb: tb, toPlus: sg[j]))
                        mine.append(xs.count - 1)
                    }
                }
            }
            ringX.append(mine)
        }
        var partner = [Int](repeating: -1, count: xs.count)
        let order: [Int] = xs.indices.sorted { i, j in
            let a = xs[i], b = xs[j]
            if abs(a.t - b.t) > 1e-9 { return a.t < b.t }
            if a.tb != b.tb { return a.tb < b.tb }
            return i < j
        }
        var k = 0
        while k + 1 < order.count {
            partner[order[k]] = order[k + 1]
            partner[order[k + 1]] = order[k]
            k += 2
        }
        let plus = assemble(true, rings, signs, xs, ringX, partner)
        let minus = assemble(false, rings, signs, xs, ringX, partner)
        return CutResult(plus: plus, minus: minus)
    }

    private static func assemble(_ side: Bool, _ rings: [Ring], _ signs: [[Bool]], _ xs: [X], _ ringX: [[Int]], _ partner: [Int]) -> [Shape] {
        // السلاسل: تبدأ بنقطة دخول لهالجهة وتنتهي بنقطة الخروج التالية على نفس الحلقة
        var chains: [Int: (pts: [P], end: Int)] = [:]
        for (ri, r) in rings.enumerated() {
            let list = ringX[ri]
            let m = list.count
            guard m >= 2 else { continue }
            let n = r.count
            for (pos, xi) in list.enumerated() {
                let c = xs[xi]
                guard c.toPlus == side else { continue }
                let nx = list[(pos + 1) % m]
                let e = xs[nx]
                var pts: [P] = [c.pt]
                var v = (c.edge + 1) % n
                var g = 0
                while g <= n {
                    pts.append(r[v])
                    if v == e.edge { break }
                    v = (v + 1) % n
                    g += 1
                }
                pts.append(e.pt)
                chains[xi] = (pts: pts, end: nx)
            }
        }
        var out: [Shape] = []
        var used = Set<Int>()
        for start in chains.keys.sorted() {
            if used.contains(start) { continue }
            var ring: [P] = []
            var cur = start
            var ok = true
            var steps = 0
            while true {
                guard let ch = chains[cur], !used.contains(cur) else { ok = false; break }
                used.insert(cur)
                ring.append(contentsOf: ch.pts)
                let p = partner[ch.end]
                if p < 0 { ok = false; break }
                cur = p
                steps += 1
                if cur == start { break }
                if steps > xs.count + 2 { ok = false; break }
            }
            if ok {
                let cleaned = Poly.dedupe(ring)
                if cleaned.count >= 3 && Poly.area(cleaned) > minPiece { out.append(Shape(Poly.ccw(cleaned))) }
            }
        }
        // حلقات ما لمسها الخطّ: الحدّ الخارجيّ كلّه بجهة وحدة = الشكل كامل، والثقوب تروح للقطعة اللي تحتويها
        var freeHoles: [Ring] = []
        for (ri, r) in rings.enumerated() where ringX[ri].isEmpty && r.count >= 3 {
            guard signs[ri].first == side else { continue }
            if ri == 0 { out.append(Shape(r)) } else { freeHoles.append(r) }
        }
        for h in freeHoles {
            let probe = Poly.centroid(h)
            let inner = h[0] + (probe - h[0]) * 1e-6
            if let idx = out.firstIndex(where: { Poly.contains($0.outer, inner) }) { out[idx].holes.append(h) }
        }
        return out.filter { $0.area > minPiece }
    }

    /// يشقّ مجموعة قطع: كلّ قطعة يقطعها الخطّ تنقسم، والباقي يبقى
    static func splitAll(_ shapes: [Shape], by L: Line) -> (pieces: [Shape], cutCount: Int) {
        var out: [Shape] = []
        var c = 0
        for s in shapes {
            let r = split(s, by: L)
            if r.crossed { out += r.pieces; c += 1 } else { out.append(s) }
        }
        return (out, c)
    }

    // MARK: قصّ نصف المستوى (للتحقّق والحلّ)

    static func clipRing(_ r: Ring, _ L: Line, plus: Bool) -> Ring {
        let n = r.count
        guard n >= 3 else { return [] }
        var out: Ring = []
        for i in 0..<n {
            let a = r[i], b = r[(i + 1) % n]
            let da = plus ? L.side(a) : -L.side(a)
            let db = plus ? L.side(b) : -L.side(b)
            let ina = da >= 0, inb = db >= 0
            if ina { out.append(a) }
            if ina != inb {
                let u = da / (da - db)
                out.append(a + (b - a) * u)
            }
        }
        return out
    }

    /// مساحة الشكل بجهة من الخطّ (دقيقة حتى للمقعّر)
    static func sideArea(_ s: Shape, _ L: Line, plus: Bool) -> Double {
        var a = Poly.area(clipRing(s.outer, L, plus: plus))
        for h in s.holes { a -= Poly.area(clipRing(h, L, plus: plus)) }
        return max(0, a)
    }

    static func plusFraction(_ s: Shape, _ L: Line) -> Double {
        let A = s.area
        guard A > 0 else { return 0 }
        return sideArea(s, L, plus: true) / A
    }

    /// الخطّ بزاوية معيّنة اللي يخلّي يساره = النسبة المطلوبة (تنصيف ثنائيّ)
    static func solve(_ s: Shape, angle: Double, fraction f: Double) -> Line {
        let probe = Line(angle: angle, offset: 0)
        let n = probe.normal
        let proj: [Double] = s.outer.map { $0.dot(n) }
        var lo = (proj.min() ?? -1) - 0.01, hi = (proj.max() ?? 1) + 0.01
        for _ in 0..<70 {
            let mid = (lo + hi) / 2
            if plusFraction(s, Line(angle: angle, offset: mid)) > f { lo = mid } else { hi = mid }
        }
        return Line(angle: angle, offset: (lo + hi) / 2)
    }

    /// النقاط من الخطّ اللي تقع داخل الشكل (لرسم الشرر على مكان القطع)
    static func chord(_ s: Shape, _ L: Line, samples: Int = 60) -> [P] {
        let ts: [Double] = s.outer.map { L.param($0) }
        let lo = ts.min() ?? -1, hi = ts.max() ?? 1
        var out: [P] = []
        guard samples > 1 else { return out }
        for i in 0..<samples {
            let p = L.at(lo + (hi - lo) * Double(i) / Double(samples - 1))
            if s.contains(p) { out.append(p) }
        }
        return out
    }
}
