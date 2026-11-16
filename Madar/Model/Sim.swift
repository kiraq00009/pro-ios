import Foundation

enum CometState: Equatable {
    case orbit(Int)
    case fly
}

enum DeathCause: String, Codable {
    case planet, moon, blackHole, lost, swallowed

    var title: String {
        switch self {
        case .planet: return "اصطدمت بكوكب"
        case .moon: return "قمر صدمك"
        case .blackHole: return "الثقب الأسود ابتلعك"
        case .lost: return "ضعت بالفضاء"
        case .swallowed: return "المدار انكمش عليك"
        }
    }
}

enum SimEvent: Equatable {
    case release(from: Int)
    case capture(planet: Int, perfect: Bool, points: Int, combo: Int, fresh: Bool)
    case gem(id: Int, big: Bool)
    case warp(to: Int)
    case death(DeathCause)
}

/// قوانين النقاط والكومبو
struct Scoring: Equatable, Codable {
    var points = 0
    var combo = 0
    var bestCombo = 0
    var perfects = 0
    var catches = 0
    static let base = 10
    static let maxMult = 5
    static func mult(_ combo: Int) -> Int { min(maxMult, 1 + max(0, combo)) }

    /// مسكة جديدة: المثاليّة تكبّر الكومبو، العاديّة تصفّره
    @discardableResult
    mutating func register(perfect: Bool, fresh: Bool) -> Int {
        guard fresh else { return 0 }
        catches += 1
        if perfect {
            combo += 1
            perfects += 1
            bestCombo = max(bestCombo, combo)
        } else {
            combo = 0
        }
        let p = Scoring.base * Scoring.mult(combo)
        points += p
        return p
    }
    mutating func gem(big: Bool) { points += big ? 10 : 2 }
    mutating func warp() { points += 25 }
}

/// المحاكاة الكاملة — خطوة ثابتة وحتميّة
struct Sim {
    static let orbitSpeed = 150.0
    static let flySpeed = 330.0
    static let cometR = 6.0
    static let captureTol = 14.0
    static let perfectTol = 5.0
    static let maxFly = 4.5
    static let gravityK = 420.0

    var level: Level
    var t = 0.0
    var pos = V2.zero
    var vel = V2.zero
    var state: CometState = .orbit(0)
    var angle = -Double.pi / 2
    var dir = 1.0
    var orbitTime = 0.0
    var flyTime = 0.0
    var from = 0
    var alive = true
    var cause: DeathCause? = nil
    var score = Scoring()
    var taken: Set<Int> = []
    var gemsRun = 0
    var maxPlanet = 0
    var warps = 0
    var gravity = 1.0
    var warpCool = 0.0
    var revived = 0

    init(level: Level, start: Int = 0) {
        self.level = level
        state = .orbit(start)
        from = start
        maxPlanet = start
        place()
    }

    init(seed: UInt64) { self.init(level: Level(seed: seed)) }

    var orbiting: Int? {
        if case .orbit(let i) = state { return i }
        return nil
    }

    /// نصف قطر الحلقة الحاليّ (الكواكب المنكمشة تضيق وإنت عليها)
    func ring(_ i: Int) -> Double {
        let p = level.planets[i]
        if orbiting == i && p.shrink > 0 { return max(0, p.ringR - p.shrink * orbitTime) }
        return p.ringR
    }

    /// كم ثانية باقية قبل ما ينطبق المدار
    var shrinkLeft: Double? {
        guard let i = orbiting else { return nil }
        let p = level.planets[i]
        guard p.shrink > 0 else { return nil }
        return max(0, (ring(i) - (p.bodyR + Sim.cometR + 2)) / p.shrink)
    }

    mutating func place() {
        guard let i = orbiting else { return }
        let p = level.planets[i]
        let R = ring(i)
        pos = p.center(t) + V2.ang(angle) * R
        vel = Aim.tangent(angle, dir: dir) * Sim.orbitSpeed
    }

    mutating func setAngle(_ a: Double) { angle = a; place() }

    /// الضغطة: يفلت المذنّب على خطّ المماس
    @discardableResult
    mutating func release() -> SimEvent? {
        guard alive, let i = orbiting else { return nil }
        place()
        vel = Aim.tangent(angle, dir: dir) * Sim.flySpeed
        state = .fly
        from = i
        flyTime = 0
        return .release(from: i)
    }

    mutating func kill(_ c: DeathCause) {
        guard alive else { return }
        alive = false
        cause = c
    }

    /// الإكمال: يرجع للمدار الأخير
    mutating func revive() {
        guard !alive else { return }
        alive = true
        cause = nil
        revived += 1
        state = .orbit(from)
        orbitTime = 0
        flyTime = 0
        warpCool = 0.5
        place()
    }

    private func window() -> ClosedRange<Int> {
        let n = level.planets.count
        let lo = max(0, from - 3)
        let hi = max(lo, min(n - 1, from + 6))
        return lo...hi
    }

    mutating func step(_ dt: Double) -> [SimEvent] {
        guard alive else { return [] }
        var ev: [SimEvent] = []
        t += dt
        level.ensure(max(from, maxPlanet) + 6)
        if warpCool > 0 { warpCool -= dt }

        if let i = orbiting {
            orbitTime += dt
            let p = level.planets[i]
            let R = ring(i)
            if R <= p.bodyR + Sim.cometR + 2 {
                kill(.swallowed)
                ev.append(.death(.swallowed))
                return ev
            }
            angle = wrapAngle(angle + dir * (Sim.orbitSpeed / max(R, 1)) * dt)
            place()
            return ev
        }

        // الطيران
        flyTime += dt
        let win = window()
        var acc = V2.zero
        if gravity > 0 {
            for j in win where j != from {
                let p = level.planets[j]
                let d = p.center(t) - pos
                let l = d.len
                if l < 230 && l > 1 {
                    acc += d.norm * (gravity * Sim.gravityK * p.bodyR * p.bodyR / max(l * l, 900))
                }
            }
            for h in level.holes where abs(h.pos.y - pos.y) < h.reach + 10 {
                let d = h.pos - pos
                let l = d.len
                if l < h.reach && l > 1 { acc += d.norm * (gravity * h.pull / max(l * l, 400)) }
            }
        }
        vel = (vel + acc * dt).norm * Sim.flySpeed
        pos += vel * dt

        // الثقب الدودي
        if warpCool <= 0 {
            for w in level.worms where w.a.dist(pos) < w.r + Sim.cometR {
                if w.target < level.planets.count {
                    let tc = level.planets[w.target].center(t)
                    pos = w.b
                    vel = (tc - w.b).norm * Sim.flySpeed
                    warpCool = 0.6
                    warps += 1
                    flyTime = 0
                    score.warp()
                    from = max(from, w.target - 1)
                    ev.append(.warp(to: w.target))
                }
                break
            }
        }

        // الجواهر
        for g in level.gems where !taken.contains(g.id) && abs(g.pos.y - pos.y) < 30 {
            if g.pos.dist(pos) < (g.big ? 18 : 14) {
                taken.insert(g.id)
                gemsRun += g.big ? 5 : 1
                score.gem(big: g.big)
                ev.append(.gem(id: g.id, big: g.big))
            }
        }

        // الأقمار والثقوب السوداء
        for j in win {
            let p = level.planets[j]
            for k in 0..<p.moons.count where p.moonPos(k, t).dist(pos) < p.moons[k].r + Sim.cometR {
                kill(.moon)
                ev.append(.death(.moon))
                return ev
            }
        }
        for h in level.holes where h.pos.dist(pos) < h.horizon + Sim.cometR * 0.5 {
            kill(.blackHole)
            ev.append(.death(.blackHole))
            return ev
        }

        // المسكة: دخول حلقة كوكب ثاني
        for j in win where j != from {
            let p = level.planets[j]
            let c = p.center(t)
            let rel = pos - c
            let d = rel.len
            if d <= p.ringR + Sim.captureTol && d > p.bodyR + Sim.cometR {
                let b = abs(rel.cross(vel.norm))
                let perfect = abs(b - p.ringR) <= Sim.perfectTol
                let fresh = j > maxPlanet
                let pts = score.register(perfect: perfect, fresh: fresh)
                if fresh { maxPlanet = j }
                state = .orbit(j)
                from = j
                angle = rel.angle
                dir = rel.cross(vel) >= 0 ? 1 : -1
                orbitTime = 0
                flyTime = 0
                place()
                ev.append(.capture(planet: j, perfect: perfect, points: pts, combo: score.combo, fresh: fresh))
                return ev
            }
        }

        // الاصطدام بجسم كوكب
        for j in win {
            let p = level.planets[j]
            if p.center(t).dist(pos) < p.bodyR + Sim.cometR {
                kill(.planet)
                ev.append(.death(.planet))
                return ev
            }
        }

        // الضياع
        let home = level.planets[min(from, level.planets.count - 1)]
        if flyTime > Sim.maxFly || pos.x < -70 || pos.x > Level.width + 70 || pos.y < home.base.y - 280 {
            kill(.lost)
            ev.append(.death(.lost))
        }
        return ev
    }

    /// الزاوية المثاليّة للإطلاق نحو الكوكب الجاي (مع توقّع حركته) — للتلميح والطيّار الآليّ
    func plannedAngle(target j: Int, offsetScale: Double = 1) -> Double? {
        guard let i = orbiting, j < level.planets.count else { return nil }
        let p = level.planets[i]
        let q = level.planets[j]
        let c = p.center(t)
        var tc = q.center(t)
        var a: Double? = nil
        for _ in 0..<3 {
            a = Aim.releaseAngle(center: c, ringR: ring(i), dir: dir, target: tc, offset: q.ringR * offsetScale)
            let eta = (tc - c).len / Sim.flySpeed
            tc = q.center(t + eta)
        }
        return a
    }
}
