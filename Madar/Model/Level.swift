import Foundation

struct Moon: Equatable, Codable {
    var dist: Double
    var r: Double
    var speed: Double
    var phase: Double
}

struct Planet: Equatable, Codable {
    var id: Int
    var base: V2
    var bodyR: Double
    var ringR: Double
    var amp: Double = 0
    var freq: Double = 0
    var phase: Double = 0
    var shrink: Double = 0
    var moons: [Moon] = []
    var hue: Double = 0.6
    var spin: Double = 1

    var moving: Bool { amp > 0.5 }
    var shrinking: Bool { shrink > 0 }

    func center(_ t: Double) -> V2 { V2(base.x + amp * sin(phase + freq * t), base.y) }
    func moonPos(_ k: Int, _ t: Double) -> V2 {
        let m = moons[k]
        return center(t) + V2.ang(m.phase + m.speed * t) * m.dist
    }
    /// أبعد نقطة يوصلها الكوكب أفقيًّا (مع الأقمار)
    var reach: Double {
        var r = ringR
        for m in moons { r = max(r, m.dist + m.r) }
        return r
    }
}

struct BlackHole: Equatable, Codable {
    var pos: V2
    var pull: Double
    var reach: Double
    var horizon: Double
    var after: Int   // يقع بين الكوكب after-1 و after
}

struct Wormhole: Equatable, Codable {
    var a: V2
    var b: V2
    var r: Double
    var target: Int  // الكوكب اللي يوجّهك له المخرج
}

struct Gem: Equatable, Codable {
    var id: Int
    var pos: V2
    var big: Bool
}

/// الكون: كواكب تتولّد بالتسلسل للأعلى من بذرة وحدة
struct Level {
    static let width = 360.0
    let seed: UInt64
    let fixed: Bool
    private(set) var planets: [Planet] = []
    private(set) var holes: [BlackHole] = []
    private(set) var worms: [Wormhole] = []
    private(set) var gems: [Gem] = []

    init(seed: UInt64) {
        self.seed = seed
        fixed = false
        ensure(12)
    }

    /// مرحلة مصمّمة يدويًّا (للاختبارات والتدريب)
    init(planets: [Planet], holes: [BlackHole] = [], worms: [Wormhole] = [], gems: [Gem] = []) {
        seed = 0
        fixed = true
        self.planets = planets
        self.holes = holes
        self.worms = worms
        self.gems = gems
    }

    static func difficulty(_ i: Int) -> Double { min(1, max(0, Double(i) / 50)) }

    /// المنطقة حسب الارتفاع (كلّ 10 كواكب سماء جديدة)
    static func zone(_ i: Int) -> Int { max(0, i) / 10 }

    mutating func ensure(_ n: Int) {
        guard !fixed else { return }
        while planets.count < n { addNext() }
    }

    private mutating func addNext() {
        let i = planets.count
        if i == 0 {
            planets.append(Planet(id: 0, base: V2(180, 140), bodyR: 24, ringR: 64, hue: 0.58, spin: 1))
            return
        }
        var r = MRng(seed: mixSeed(seed, i))
        let prev = planets[i - 1]
        let d = Level.difficulty(i)
        let gap = r.range(200, 238) + 46 * d
        let bodyR = r.range(15, 25) - 3 * d
        let ringR = bodyR + r.range(34, 44) - 12 * d
        var p = Planet(id: i, base: V2(0, prev.base.y + gap), bodyR: bodyR, ringR: ringR)
        p.hue = r.unit()
        p.spin = r.sign()
        if i >= 4 && r.chance(0.15 + 0.35 * d) {
            p.amp = r.range(28, 56 + 30 * d)
            p.freq = r.range(0.55, 1.0 + 0.55 * d)
            p.phase = r.range(0, 2 * Double.pi)
        }
        if i >= 7 && r.chance(0.12 + 0.25 * d) {
            p.shrink = r.range(6, 10 + 8 * d)
        }
        if i >= 5 && r.chance(0.15 + 0.35 * d) {
            let n = (d > 0.5 && r.chance(0.4)) ? 2 : 1
            let sp = r.sign() * r.range(0.8, 1.4 + 0.7 * d)
            let ph = r.range(0, 2 * Double.pi)
            for k in 0..<n {
                p.moons.append(Moon(dist: ringR + r.range(17, 26), r: r.range(5.5, 7.5), speed: sp, phase: ph + Double(k) * Double.pi))
            }
        }
        // الموقع الأفقيّ: داخل الشاشة دائمًا مع حركته وأقماره
        let margin = 8 + p.amp + p.reach
        let lo = margin, hi = Level.width - margin
        var x = r.range(60, 300)
        if abs(x - prev.base.x) < 40 { x += x < 180 ? 70 : -70 }
        if lo <= hi { x = min(hi, max(lo, x)) } else { x = Level.width / 2; p.amp = 0 }
        p.base.x = x
        planets.append(p)

        // مخاطر الطريق بين الكوكب السابق والحالي
        let mid = (prev.base + p.base) / 2
        let seg = p.base - prev.base
        let perp = V2(-seg.y, seg.x).norm
        var holeSide = 0.0
        if i >= 10 && r.chance(0.12 + 0.25 * d) {
            let side = r.sign()
            var hp = mid + perp * (side * r.range(85, 115))
            hp.x = min(Level.width - 22, max(22, hp.x))
            let pull = r.range(600_000, 900_000 + 500_000 * d)
            if clearOf(hp, 40, [prev, p]) {
                holes.append(BlackHole(pos: hp, pull: pull, reach: 150, horizon: 13, after: i))
                holeSide = side
            }
        }
        if i >= 14 && r.chance(0.08) && (worms.last.map { $0.target < i } ?? true) {
            let side = holeSide != 0 ? -holeSide : r.sign()
            var a = mid + perp * (side * r.range(70, 100))
            a.x = min(Level.width - 24, max(24, a.x))
            let b = V2(p.base.x, p.base.y + p.ringR + 62)
            if clearOf(a, 30, [prev, p]) {
                worms.append(Wormhole(a: a, b: b, r: 16, target: i + 1))
            }
        }
        let n = 1 + r.int(3)
        for k in 0..<n {
            let t = 0.32 + 0.36 * (n == 1 ? 0.5 : Double(k) / Double(n - 1))
            let g = prev.base + seg * t + perp * r.range(-26, 26)
            let big = r.chance(0.1)
            if clearOf(g, 12, [prev, p]) {
                gems.append(Gem(id: i * 10 + k, pos: g, big: big))
            }
        }
    }

    /// النقطة بعيدة عن حلقات الكواكب (مع مدى حركتها)؟
    private func clearOf(_ q: V2, _ pad: Double, _ ps: [Planet]) -> Bool {
        for p in ps {
            let dx = max(0, abs(q.x - p.base.x) - p.amp)
            let dy = q.y - p.base.y
            if (dx * dx + dy * dy).squareRoot() < p.reach + pad { return false }
        }
        return true
    }
}
