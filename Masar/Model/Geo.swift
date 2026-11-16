import Foundation

// الجغرافيا الأساسيّة: إحداثيّات، مسافة هافرسين، إسقاط محليّ بالمتر، ومضلّعات

struct Coord: Codable, Equatable, Hashable {
    var lat: Double
    var lon: Double
    init(_ lat: Double, _ lon: Double) { self.lat = lat; self.lon = lon }
}

/// نقطة مسطّحة بالمتر (x = شرق، y = شمال)
struct P: Equatable {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    func dist(_ o: P) -> Double { ((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y)).squareRoot() }
}

enum Geo {
    static let R: Double = 6_371_000

    static func rad(_ d: Double) -> Double { d * Double.pi / 180 }
    static func deg(_ r: Double) -> Double { r * 180 / Double.pi }

    /// المسافة الحقيقيّة على سطح الأرض بالمتر
    static func haversine(_ a: Coord, _ b: Coord) -> Double {
        let dLat = rad(b.lat - a.lat), dLon = rad(b.lon - a.lon)
        let s1 = sin(dLat / 2), s2 = sin(dLon / 2)
        let h = s1 * s1 + cos(rad(a.lat)) * cos(rad(b.lat)) * s2 * s2
        return 2 * R * asin(min(1, h.squareRoot()))
    }

    /// الاتّجاه من a إلى b بالدرجات (0 = شمال، 90 = شرق)
    static func bearing(_ a: Coord, _ b: Coord) -> Double {
        let p1 = rad(a.lat), p2 = rad(b.lat), dl = rad(b.lon - a.lon)
        let y = sin(dl) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        let t = deg(atan2(y, x))
        return (t + 360).truncatingRemainder(dividingBy: 360)
    }

    /// إزاحة صغيرة بالمتر شرقًا وشمالًا
    static func moved(_ c: Coord, east: Double, north: Double) -> Coord {
        Coord(c.lat + deg(north / R), c.lon + deg(east / (R * cos(rad(c.lat)))))
    }

    /// مساحة مضلّع (شو‌لاس) بالمتر المربّع
    static func polygonArea(_ p: [P]) -> Double {
        guard p.count >= 3 else { return 0 }
        var s = 0.0
        for i in 0..<p.count {
            let a = p[i], b = p[(i + 1) % p.count]
            s += a.x * b.y - b.x * a.y
        }
        return abs(s) / 2
    }

    /// هل النقطة داخل المضلّع؟ (رمي الشعاع)
    static func contains(_ poly: [P], _ pt: P) -> Bool {
        guard poly.count >= 3 else { return false }
        var inside = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > pt.y) != (b.y > pt.y) {
                let xi = (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x
                if pt.x < xi { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    static func pathLength(_ p: [P]) -> Double {
        guard p.count > 1 else { return 0 }
        var s = 0.0
        for i in 1..<p.count { s += p[i - 1].dist(p[i]) }
        return s
    }

    static func pathLength(_ c: [Coord]) -> Double {
        guard c.count > 1 else { return 0 }
        var s = 0.0
        for i in 1..<c.count { s += haversine(c[i - 1], c[i]) }
        return s
    }
}

/// إسقاط مستطيل متساوي المسافات حول نقطة أصل ثابتة — دقيق جدًّا ضمن مدينة
struct Projection: Codable, Equatable {
    var origin: Coord
    private var k: Double { Geo.R * cos(Geo.rad(origin.lat)) }

    func xy(_ c: Coord) -> P {
        P(Geo.rad(c.lon - origin.lon) * k, Geo.rad(c.lat - origin.lat) * Geo.R)
    }

    func coord(_ p: P) -> Coord {
        Coord(origin.lat + Geo.deg(p.y / Geo.R), origin.lon + Geo.deg(p.x / k))
    }
}
