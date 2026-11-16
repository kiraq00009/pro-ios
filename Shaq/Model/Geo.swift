import Foundation

/// نقطة بالمستوى (منطق صافي، بلا CoreGraphics)
struct P: Equatable, Codable {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    static let zero = P(0, 0)
    static func + (a: P, b: P) -> P { P(a.x + b.x, a.y + b.y) }
    static func - (a: P, b: P) -> P { P(a.x - b.x, a.y - b.y) }
    static func * (a: P, k: Double) -> P { P(a.x * k, a.y * k) }
    func dot(_ b: P) -> Double { x * b.x + y * b.y }
    func cross(_ b: P) -> Double { x * b.y - y * b.x }
    var len: Double { (x * x + y * y).squareRoot() }
    var unit: P { let l = len; return l > 1e-12 ? P(x / l, y / l) : P(1, 0) }
    func rotated(_ a: Double) -> P { let c = cos(a), s = sin(a); return P(x * c - y * s, x * s + y * c) }
    func dist(_ b: P) -> Double { (self - b).len }
}

typealias Ring = [P]

enum Poly {
    /// مساحة بإشارة (صيغة رباط الحذاء): موجبة = عكس عقارب الساعة
    static func signedArea(_ r: Ring) -> Double {
        let n = r.count
        guard n >= 3 else { return 0 }
        var s = 0.0
        for i in 0..<n {
            let a = r[i], b = r[(i + 1) % n]
            s += a.x * b.y - b.x * a.y
        }
        return s / 2
    }
    static func area(_ r: Ring) -> Double { abs(signedArea(r)) }

    static func centroid(_ r: Ring) -> P {
        let n = r.count
        let A = signedArea(r)
        if n == 0 { return .zero }
        if abs(A) < 1e-14 {
            var sx = 0.0, sy = 0.0
            for p in r { sx += p.x; sy += p.y }
            return P(sx / Double(n), sy / Double(n))
        }
        var cx = 0.0, cy = 0.0
        for i in 0..<n {
            let a = r[i], b = r[(i + 1) % n]
            let f = a.x * b.y - b.x * a.y
            cx += (a.x + b.x) * f
            cy += (a.y + b.y) * f
        }
        return P(cx / (6 * A), cy / (6 * A))
    }

    static func ccw(_ r: Ring) -> Ring { signedArea(r) < 0 ? Array(r.reversed()) : r }
    static func cw(_ r: Ring) -> Ring { signedArea(r) > 0 ? Array(r.reversed()) : r }

    /// نقطة داخل مضلّع (رمي شعاع)
    static func contains(_ r: Ring, _ p: P) -> Bool {
        let n = r.count
        guard n >= 3 else { return false }
        var inside = false
        var j = n - 1
        for i in 0..<n {
            let a = r[i], b = r[j]
            if (a.y > p.y) != (b.y > p.y) {
                let x = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
                if p.x < x { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    static func perimeter(_ r: Ring) -> Double {
        let n = r.count
        guard n >= 2 else { return 0 }
        var s = 0.0
        for i in 0..<n { s += r[i].dist(r[(i + 1) % n]) }
        return s
    }

    /// يشيل النقاط المكرّرة المتتالية
    static func dedupe(_ r: Ring, _ eps: Double = 1e-10) -> Ring {
        var out: Ring = []
        for p in r {
            if let l = out.last, l.dist(p) < eps { continue }
            out.append(p)
        }
        while out.count > 1, let f = out.first, let l = out.last, f.dist(l) < eps { out.removeLast() }
        return out
    }
}

/// شكل = حدّ خارجيّ + فتحات (ثقوب) داخله
struct Shape: Equatable, Codable {
    var outer: Ring
    var holes: [Ring]

    init(_ outer: Ring, holes: [Ring] = []) { self.outer = outer; self.holes = holes }

    var area: Double { max(0, Poly.area(outer) - holes.reduce(0.0) { $0 + Poly.area($1) }) }

    var centroid: P {
        let A = Poly.area(outer)
        let co = Poly.centroid(outer)
        var sx = co.x * A, sy = co.y * A, tot = A
        for h in holes {
            let a = Poly.area(h), c = Poly.centroid(h)
            sx -= c.x * a; sy -= c.y * a; tot -= a
        }
        guard tot > 1e-14 else { return co }
        return P(sx / tot, sy / tot)
    }

    func contains(_ p: P) -> Bool {
        guard Poly.contains(outer, p) else { return false }
        for h in holes where Poly.contains(h, p) { return false }
        return true
    }

    func mapped(_ f: (P) -> P) -> Shape { Shape(outer.map(f), holes: holes.map { $0.map(f) }) }

    /// تدوير حول الأصل ثمّ تكبير ثمّ إزاحة
    func placed(scale: Double, angle: Double, offset: P) -> Shape {
        mapped { $0.rotated(angle) * scale + offset }
    }
    func moved(_ d: P) -> Shape { mapped { $0 + d } }

    var radius: Double { outer.map { $0.len }.max() ?? 0 }

    /// مركز الكتلة على الأصل، أبعد نقطة = 1، اتّجاهات الحلقات مضبوطة
    func normalized() -> Shape {
        let c = centroid
        let m = mapped { $0 - c }
        let R = m.radius
        guard R > 1e-12 else { return m }
        let s = m.mapped { $0 * (1 / R) }
        return Shape(Poly.ccw(Poly.dedupe(s.outer)), holes: s.holes.map { Poly.cw(Poly.dedupe($0)) })
    }

    var vertexCount: Int { outer.count + holes.reduce(0) { $0 + $1.count } }
}

/// خطّ لا نهائيّ: نقطة + اتّجاه
struct Line: Equatable {
    var a: P
    var dir: P

    init(_ p: P, _ q: P) { a = p; dir = (q - p).unit }
    init(point: P, dir d: P) { a = point; dir = d.unit }
    /// خطّ بزاوية، يبعد عن الأصل بمقدار offset على العموديّ
    init(angle: Double, offset: Double) {
        dir = P(cos(angle), sin(angle))
        a = P(-dir.y, dir.x) * offset
    }

    var normal: P { P(-dir.y, dir.x) }
    /// موجب = يسار الاتّجاه
    func side(_ p: P) -> Double { dir.cross(p - a) }
    func param(_ p: P) -> Double { (p - a).dot(dir) }
    func dist(_ p: P) -> Double { abs(side(p)) }
    func at(_ t: Double) -> P { a + dir * t }
    func shifted(_ d: Double) -> Line { Line(point: a + normal * d, dir: dir) }
}
