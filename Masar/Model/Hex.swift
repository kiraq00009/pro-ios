import Foundation

// شبكة سداسيّة (رأس للأعلى) بإحداثيّات محوريّة q,r — كلّ خليّة عرضها ≈ 70 م

struct Hex: Hashable, Codable {
    var q: Int
    var r: Int
    init(_ q: Int, _ r: Int) { self.q = q; self.r = r }
    var s: Int { -q - r }

    static let dirs: [Hex] = [Hex(1, 0), Hex(1, -1), Hex(0, -1), Hex(-1, 0), Hex(-1, 1), Hex(0, 1)]

    var neighbours: [Hex] { Hex.dirs.map { Hex(q + $0.q, r + $0.r) } }

    func distance(_ o: Hex) -> Int { (abs(q - o.q) + abs(r - o.r) + abs(s - o.s)) / 2 }

    var key: String { "\(q),\(r)" }

    /// تقريب مكعّبيّ لأقرب خليّة
    static func round(_ qf: Double, _ rf: Double) -> Hex {
        let sf = -qf - rf
        var rq = qf.rounded(), rr = rf.rounded()
        let rs = sf.rounded()
        let dq = abs(rq - qf), dr = abs(rr - rf), ds = abs(rs - sf)
        if dq > dr && dq > ds { rq = -rr - rs } else if dr > ds { rr = -rq - rs }
        return Hex(Int(rq), Int(rr))
    }
}

struct HexGrid {
    var proj: Projection
    /// نصف القطر (المركز → الزاوية) بالمتر؛ العرض = √3 × size ≈ 69 م
    var size: Double = 40

    private static let s3 = 3.0.squareRoot()

    var cellArea: Double { 3 * HexGrid.s3 / 2 * size * size }
    var width: Double { HexGrid.s3 * size }

    func hex(at p: P) -> Hex {
        let qf = (HexGrid.s3 / 3 * p.x - p.y / 3) / size
        let rf = (2.0 / 3 * p.y) / size
        return Hex.round(qf, rf)
    }

    func hex(_ c: Coord) -> Hex { hex(at: proj.xy(c)) }

    func center(_ h: Hex) -> P {
        P(size * HexGrid.s3 * (Double(h.q) + Double(h.r) / 2), size * 1.5 * Double(h.r))
    }

    func centerCoord(_ h: Hex) -> Coord { proj.coord(center(h)) }

    func corners(_ h: Hex) -> [P] {
        let c = center(h)
        return (0..<6).map { (i: Int) -> P in
            let a = Geo.rad(60 * Double(i) - 30)
            return P(c.x + size * cos(a), c.y + size * sin(a))
        }
    }

    func cornerCoords(_ h: Hex) -> [Coord] { corners(h).map { proj.coord($0) } }

    /// خطّ الخلايا بين خليّتين (استيفاء مكعّبيّ) — كلّ خليّة جارة للّي قبلها
    func line(_ a: Hex, _ b: Hex) -> [Hex] {
        let n = a.distance(b)
        if n == 0 { return [a] }
        var out: [Hex] = []
        out.reserveCapacity(n + 1)
        let aq = Double(a.q) + 1e-6, ar = Double(a.r) + 1e-6
        let bq = Double(b.q) + 1e-6, br = Double(b.r) + 1e-6
        for i in 0...n {
            let t = Double(i) / Double(n)
            out.append(Hex.round(aq + (bq - aq) * t, ar + (br - ar) * t))
        }
        return out
    }

    /// كلّ الخلايا اللي يعبرها المقطع من a إلى b بالترتيب، بلا تكرار متتالي وبلا فجوات
    func cells(from a: P, to b: P) -> [Hex] {
        var out: [Hex] = [hex(at: a)]
        let d = a.dist(b)
        let steps = max(1, Int((d / (size * 0.25)).rounded(.up)))
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let h = hex(at: P(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t))
            guard let last = out.last, h != last else { continue }
            if last.distance(h) > 1 {
                for g in line(last, h).dropFirst() { out.append(g) }
            } else {
                out.append(h)
            }
        }
        return out
    }

    /// الخلايا اللي مركزها داخل المضلّع (تعبئة الدائرة المقفولة)
    func cellsInside(_ poly: [P]) -> [Hex] {
        guard poly.count >= 3 else { return [] }
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        for p in poly { minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y) }
        let r0 = Int((2.0 / 3 * minY / size).rounded(.down)) - 1
        let r1 = Int((2.0 / 3 * maxY / size).rounded(.up)) + 1
        var out: [Hex] = []
        let w = size * HexGrid.s3
        for r in r0...r1 {
            let q0 = Int((minX / w - Double(r) / 2).rounded(.down)) - 1
            let q1 = Int((maxX / w - Double(r) / 2).rounded(.up)) + 1
            for q in q0...q1 {
                let h = Hex(q, r)
                if Geo.contains(poly, center(h)) { out.append(h) }
            }
        }
        return out
    }
}
