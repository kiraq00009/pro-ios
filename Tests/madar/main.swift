import Foundation

var failures = 0
var passed = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if ok { passed += 1 } else { failures += 1; print("FAIL: " + msg()) } }
func near(_ a: Double, _ b: Double, _ eps: Double = 1e-6) -> Bool { abs(a - b) <= eps }

let dt = 1.0 / 120
func mk(_ id: Int, _ x: Double, _ y: Double, body: Double = 20, ring: Double = 55) -> Planet {
    Planet(id: id, base: V2(x, y), bodyR: body, ringR: ring)
}
/// يشغّل المحاكاة لحدّ ما يصير مسك أو موت
func runFlight(_ s: inout Sim, maxSteps: Int = 3000) -> [SimEvent] {
    var all: [SimEvent] = []
    for _ in 0..<maxSteps {
        let e = s.step(dt)
        all.append(contentsOf: e)
        if !s.alive || s.orbiting != nil { break }
    }
    return all
}
func captureOf(_ ev: [SimEvent]) -> (planet: Int, perfect: Bool, points: Int, combo: Int, fresh: Bool)? {
    for e in ev { if case .capture(let p, let pf, let pts, let c, let f) = e { return (p, pf, pts, c, f) } }
    return nil
}
func deathOf(_ ev: [SimEvent]) -> DeathCause? {
    for e in ev { if case .death(let c) = e { return c } }
    return nil
}

let c0 = V2(180, 100), c1 = V2(220, 420)
func twoPlanets() -> [Planet] { [mk(0, 180, 100, ring: 60), mk(1, 220, 420)] }

// ── المتّجهات والزوايا
check(near(V2(3, 4).len, 5), "vector length")
check(near(V2(1, 0).cross(V2(0, 1)), 1), "cross sign")
check(near(wrapAngle(3 * Double.pi), Double.pi) || near(wrapAngle(3 * Double.pi), -Double.pi), "wrap 3π")
check(near(wrapAngle(-0.5), -0.5), "wrap small")
check(near(Aim.tangent(0, dir: 1).y, 1) && near(Aim.tangent(0, dir: -1).y, -1), "tangent directions")

// ── المولّد العشوائيّ ثابت
var r1 = MRng(seed: 77), r2 = MRng(seed: 77), r3 = MRng(seed: 78)
let a1 = (0..<20).map { _ in r1.next() }, a2 = (0..<20).map { _ in r2.next() }, a3 = (0..<20).map { _ in r3.next() }
check(a1 == a2, "rng deterministic")
check(a1 != a3, "rng differs by seed")
var ru = MRng(seed: 5)
check((0..<2000).allSatisfy { _ in let u = ru.unit(); return u >= 0 && u < 1 }, "unit in [0,1)")
check((0..<500).allSatisfy { _ in let v = ru.int(7); return v >= 0 && v < 7 }, "int range")

// ── زاوية الإطلاق: الخطّ يعبر بالضبط على البعد المطلوب
if let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: c1, offset: 0) {
    let p = c0 + V2.ang(a) * 60
    let u = Aim.tangent(a, dir: 1)
    check(Aim.impact(p, u, c1) < 1e-6, "aim through centre")
    check((c1 - p).dot(u) > 0, "aim moves toward target")
} else { check(false, "aim angle exists") }
if let a = Aim.releaseAngle(center: c0, ringR: 60, dir: -1, target: c1, offset: 55) {
    let p = c0 + V2.ang(a) * 60
    let u = Aim.tangent(a, dir: -1)
    check(near(Aim.impact(p, u, c1), 55), "cw aim offset 55: \(Aim.impact(p, u, c1))")
    check((c1 - p).dot(u) > 0, "cw aim moves toward target")
} else { check(false, "cw aim angle exists") }
check(Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: V2(190, 120), offset: 0) == nil, "target inside ring: no aim")

// ── الإطلاق المماسيّ من مدار معروف يصيب الهدف المخطّط — مسكة مثاليّة
do {
    var s = Sim(level: Level(planets: twoPlanets()))
    s.gravity = 0
    check(s.orbiting == 0 && near(s.pos.dist(c0), 60), "starts on ring 0")
    if let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: c1, offset: 55) {
        s.setAngle(a)
        let rel = s.release()
        check(rel == .release(from: 0), "release event")
        check(near(s.vel.len, Sim.flySpeed), "fly speed")
        check(s.release() == nil, "can't release twice mid-flight")
        let ev = runFlight(&s)
        if let c = captureOf(ev) {
            check(c.planet == 1 && c.perfect && c.fresh, "perfect catch on planet 1")
            check(c.points == 20 && c.combo == 1, "perfect scores 20, combo 1: \(c.points) \(c.combo)")
        } else { check(false, "planned shot captured: \(ev)") }
        check(s.dir == 1, "ccw shot keeps ccw orbit")
        check(s.maxPlanet == 1 && s.score.perfects == 1, "progress counted")
        for _ in 0..<90 { _ = s.step(dt) }
        check(s.alive && s.orbiting == 1, "stays in orbit after catch")
        check(near(s.pos.dist(c1), 55, 1e-6), "rides ring 1 exactly: \(s.pos.dist(c1))")
    } else { check(false, "aim exists A") }
}

// ── نفس الشي مع عقارب الساعة
do {
    var s = Sim(level: Level(planets: twoPlanets()))
    s.gravity = 0
    s.dir = -1
    if let a = Aim.releaseAngle(center: c0, ringR: 60, dir: -1, target: c1, offset: 55) {
        s.setAngle(a); s.release()
        let ev = runFlight(&s)
        check(captureOf(ev)?.perfect == true && captureOf(ev)?.planet == 1, "cw perfect catch")
        check(s.dir == -1, "cw shot gives cw orbit")
    } else { check(false, "aim exists cw") }
}

// ── تصويب على المركز: مسكة عاديّة بلا كومبو
do {
    var s = Sim(level: Level(planets: twoPlanets()))
    s.gravity = 0
    if let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: c1, offset: 0) {
        s.setAngle(a); s.release()
        let ev = runFlight(&s)
        if let c = captureOf(ev) {
            check(c.planet == 1 && !c.perfect && c.points == 10 && c.combo == 0, "centre shot = plain catch")
        } else { check(false, "centre shot captured") }
    } else { check(false, "aim exists B") }
}

// ── يفوت الحلقة: يضيع بالفضاء، وبعدين الإكمال يرجّعه
do {
    var s = Sim(level: Level(planets: twoPlanets()))
    s.gravity = 0
    if let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: c1, offset: 90) {
        s.setAngle(a); s.release()
        let ev = runFlight(&s)
        check(captureOf(ev) == nil, "miss: no capture")
        check(deathOf(ev) == .lost && s.cause == .lost && !s.alive, "miss: lost in space")
        check(s.step(dt).isEmpty, "dead sim does nothing")
        s.revive()
        check(s.alive && s.orbiting == 0 && s.cause == nil && s.revived == 1, "revive returns to last orbit")
        check(near(s.pos.dist(c0), 60), "revived on ring")
    } else { check(false, "aim exists C") }
}

// ── الثقب الأسود على الطريق
do {
    let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: c1, offset: 0) ?? 0
    let p = c0 + V2.ang(a) * 60
    let u = Aim.tangent(a, dir: 1)
    let hp = p + u * 120
    var s = Sim(level: Level(planets: twoPlanets(), holes: [BlackHole(pos: hp, pull: 12000, reach: 150, horizon: 13, after: 1)]))
    s.gravity = 0
    s.setAngle(a); s.release()
    let ev = runFlight(&s)
    check(deathOf(ev) == .blackHole, "black hole swallows: \(ev)")
}

// ── الثقب الأسود يحني الطريق حتى لو ما ينضرب
do {
    let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: c1, offset: 0) ?? 0
    let p = c0 + V2.ang(a) * 60
    let u = Aim.tangent(a, dir: 1)
    let side = V2(-u.y, u.x)
    let hp = p + u * 150 + side * 70
    var s = Sim(level: Level(planets: twoPlanets(), holes: [BlackHole(pos: hp, pull: 700000, reach: 150, horizon: 13, after: 1)]))
    s.setAngle(a); s.release()
    for _ in 0..<50 { _ = s.step(dt) }
    let toward = u.cross(s.pos - p)   // موجب ⇒ مال لجهة الثقب
    check(toward > 0.5, "path bends toward black hole: \(toward)")
}

// ── قمر يصطاد المذنّب قبل الحلقة
do {
    let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: c1, offset: 55) ?? 0
    let p = c0 + V2.ang(a) * 60
    let u = Aim.tangent(a, dir: 1)
    let w = p - c1
    let wu = w.dot(u)
    let sq = wu * wu - w.dot(w) + 75 * 75
    let sMoon = -wu - sq.squareRoot()
    let m = p + u * sMoon
    var pl = twoPlanets()
    pl[1].moons = [Moon(dist: 75, r: 7, speed: 0, phase: (m - c1).angle)]
    check(near(pl[1].moonPos(0, 3).dist(m), 0, 1e-6), "moon placed on path")
    var s = Sim(level: Level(planets: pl))
    s.gravity = 0
    s.setAngle(a); s.release()
    let ev = runFlight(&s)
    check(deathOf(ev) == .moon && captureOf(ev) == nil, "moon kills before ring: \(ev)")
}

// ── جوهرة على الطريق
do {
    let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: c1, offset: 55) ?? 0
    let p = c0 + V2.ang(a) * 60
    let u = Aim.tangent(a, dir: 1)
    var s = Sim(level: Level(planets: twoPlanets(), gems: [Gem(id: 7, pos: p + u * 100, big: false), Gem(id: 8, pos: p + u * 160 + V2(-u.y, u.x) * 60, big: true)]))
    s.gravity = 0
    s.setAngle(a); s.release()
    let ev = runFlight(&s)
    check(ev.contains(.gem(id: 7, big: false)), "gem on path collected")
    check(!ev.contains(.gem(id: 8, big: true)), "gem off path stays")
    check(s.gemsRun == 1 && s.taken == [7], "gem counted once")
    check(s.score.points == 22, "gem 2 + perfect 20 = 22: \(s.score.points)")
}

// ── الثقب الدوديّ يقفز للكوكب اللي بعده
do {
    let pl = [mk(0, 180, 100, ring: 60), mk(1, 300, 420), mk(2, 100, 760)]
    let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: V2(300, 420), offset: 0) ?? 0
    let p = c0 + V2.ang(a) * 60
    let u = Aim.tangent(a, dir: 1)
    var s = Sim(level: Level(planets: pl, worms: [Wormhole(a: p + u * 120, b: V2(100, 520), r: 16, target: 2)]))
    s.gravity = 0
    s.setAngle(a); s.release()
    let ev = runFlight(&s)
    check(ev.contains(.warp(to: 2)), "warp happened: \(ev)")
    if let c = captureOf(ev) {
        check(c.planet == 2 && c.fresh, "warp lands on planet 2")
        check(s.score.points == 35, "warp 25 + catch 10 = 35: \(s.score.points)")
    } else { check(false, "captured after warp") }
    check(s.warps == 1, "warp counted")
}

// ── المدار المنكمش
do {
    var pl = [mk(0, 180, 100, ring: 60), mk(1, 220, 420)]
    pl[0].shrink = 20
    var s = Sim(level: Level(planets: pl))
    check(near(s.shrinkLeft ?? -1, 1.6), "shrink countdown 1.6s")
    for _ in 0..<180 { _ = s.step(dt) }
    check(s.alive, "still alive at 1.5s")
    check(near(s.ring(0), 30, 1e-6), "ring shrank to 30: \(s.ring(0))")
    check(near(s.pos.dist(c0), 30, 1e-6), "comet rides shrinking ring")
    var ev: [SimEvent] = []
    for _ in 0..<24 { ev += s.step(dt) }
    check(!s.alive && deathOf(ev) == .swallowed, "swallowed by shrinking orbit")
    check(Sim(level: Level(planets: twoPlanets())).shrinkLeft == nil, "normal orbit no countdown")
}

// ── حركة المدار ثابتة
do {
    var s = Sim(level: Level(planets: twoPlanets()))
    for _ in 0..<120 { _ = s.step(dt) }
    let expect = wrapAngle(-Double.pi / 2 + 150.0 / 60.0 * 1.0)
    check(abs(wrapAngle(s.angle - expect)) < 1e-6, "angular speed = v/R")
    check(near(s.pos.dist(c0), 60, 1e-9), "orbit radius kept")
    check(near(s.t, 1, 1e-9), "time advanced")
}

// ── الكوكب المتحرّك يسحب المذنّب وياه
do {
    var pl = twoPlanets()
    pl[0].amp = 40; pl[0].freq = 1; pl[0].phase = 0
    var s = Sim(level: Level(planets: pl))
    for _ in 0..<60 { _ = s.step(dt) }
    let c = pl[0].center(s.t)
    check(near(c.x, 180 + 40 * sin(0.5), 1e-9), "mover centre formula")
    check(near(s.pos.dist(c), 60, 1e-9), "rides moving planet")
}

// ── الجاذبيّة تحني بس ما تغيّر السرعة
do {
    let pl = [mk(0, 180, 100, ring: 60), mk(1, 220, 420), mk(2, 100, 260, body: 25)]
    let a = Aim.releaseAngle(center: c0, ringR: 60, dir: 1, target: c1, offset: 0) ?? 0
    var g0 = Sim(level: Level(planets: pl)); g0.gravity = 0
    var g1 = Sim(level: Level(planets: pl)); g1.gravity = 1
    g0.setAngle(a); g0.release(); g1.setAngle(a); g1.release()
    for _ in 0..<60 { _ = g0.step(dt); _ = g1.step(dt) }
    check(g1.pos.dist(g0.pos) > 0.5, "gravity bends path: \(g1.pos.dist(g0.pos))")
    check(near(g1.vel.len, Sim.flySpeed, 1e-6), "speed constant under gravity")
    let ev = runFlight(&g1)
    check(captureOf(ev)?.planet == 1, "gravity shot still lands: \(ev)")
}

// ── الطيران على جسم كوكب مباشرة = مسكة قبل الاصطدام (الحلقة أعرض من الخطوة)
do {
    var s = Sim(level: Level(planets: twoPlanets()))
    s.gravity = 0
    s.state = .fly
    s.from = 0
    s.pos = V2(220, 300)
    s.vel = V2(0, Sim.flySpeed)
    let ev = runFlight(&s)
    check(captureOf(ev)?.planet == 1 && deathOf(ev) == nil, "head-on dive is caught by the ring")
}

// ── توليد الكون: نفس البذرة ⇒ نفس الكواكب
do {
    var la = Level(seed: 42); la.ensure(80)
    var lb = Level(seed: 42); lb.ensure(80)
    var lc = Level(seed: 43); lc.ensure(80)
    check(la.planets == lb.planets && la.holes == lb.holes && la.worms == lb.worms && la.gems == lb.gems, "same seed same universe")
    check(la.planets != lc.planets, "different seed different universe")
    var lz = Level(seed: 9); lz.ensure(15); lz.ensure(40)
    var ly = Level(seed: 9); ly.ensure(40)
    check(lz.planets == ly.planets && lz.gems == ly.gems, "lazy generation is stable")
    check(Level(seed: 1).planets.count >= 12, "pre-generates planets")
    check(Level(seed: 1).planets[0] == Level(seed: 999).planets[0], "same friendly start planet")
}

do {
    var holes = 0, worms = 0, movers = 0, shrinkers = 0, mooned = 0
    var allOk = true, boundsOk = true, holeOk = true, wormOk = true, idsOk = true, calmStart = true
    for seed in UInt64(1)...UInt64(6) {
        var l = Level(seed: seed); l.ensure(200)
        let ps = l.planets
        for i in 1..<ps.count {
            let p = ps[i], q = ps[i - 1]
            if p.base.y - q.base.y < 200 || p.ringR - p.bodyR < 21.9 || p.bodyR < 11.9 { allOk = false }
            if p.base.x - p.amp - p.reach < 7.99 || p.base.x + p.amp + p.reach > Level.width - 7.99 { boundsOk = false }
            if p.moving { movers += 1 }
            if p.shrinking { shrinkers += 1 }
            if !p.moons.isEmpty { mooned += 1 }
            if i <= 3 && (p.moving || p.shrinking || !p.moons.isEmpty) { calmStart = false }
            for m in p.moons where m.dist <= p.ringR + Sim.captureTol { allOk = false }
        }
        for h in l.holes {
            holes += 1
            for p in [ps[h.after], ps[h.after - 1]] {
                let dx = max(0, abs(h.pos.x - p.base.x) - p.amp), dy = h.pos.y - p.base.y
                if (dx * dx + dy * dy).squareRoot() < p.reach + 40 - 1e-9 { holeOk = false }
            }
            if h.after < 10 { holeOk = false }
        }
        for w in l.worms {
            worms += 1
            if w.target > ps.count || w.b.y <= ps[w.target - 1].base.y || w.target - 1 < 14 { wormOk = false }
        }
        if Set(l.gems.map { $0.id }).count != l.gems.count { idsOk = false }
    }
    check(allOk, "planet spacing/ring/moon rules")
    check(boundsOk, "planets stay inside the screen")
    check(holeOk, "black holes keep clear of rings")
    check(wormOk, "wormholes point to the planet above")
    check(idsOk, "gem ids unique")
    check(calmStart, "first three planets are calm")
    check(holes > 0 && worms > 0 && movers > 0 && shrinkers > 0 && mooned > 0, "all hazard kinds appear: h\(holes) w\(worms) m\(movers) s\(shrinkers) moon\(mooned)")
}

// ── منحنى الصعوبة
do {
    var l = Level(seed: 7); l.ensure(110)
    let early = (1...10).map { l.planets[$0].ringR - l.planets[$0].bodyR }.reduce(0, +) / 10
    let late = (60...100).map { l.planets[$0].ringR - l.planets[$0].bodyR }.reduce(0, +) / 41
    check(early > late + 5, "rings get tighter: \(early) vs \(late)")
    check(Level.difficulty(0) == 0 && Level.difficulty(25) == 0.5 && Level.difficulty(500) == 1, "difficulty ramp")
    check(Level.zone(0) == 0 && Level.zone(9) == 0 && Level.zone(10) == 1 && Level.zone(35) == 3, "zones every 10")
    var hard = 0, easy = 0
    for seed in UInt64(20)...UInt64(29) {
        var lv = Level(seed: seed); lv.ensure(110)
        easy += (1...20).filter { lv.planets[$0].moving || !lv.planets[$0].moons.isEmpty }.count
        hard += (80...99).filter { lv.planets[$0].moving || !lv.planets[$0].moons.isEmpty }.count
    }
    check(hard > easy, "more hazards higher up: \(easy) → \(hard)")
}

// ── كلّ كوكب ينوصل من اللي قبله (خطّ المماس موجود)
do {
    var l = Level(seed: 11); l.ensure(120)
    var ok = true
    for i in 1..<120 {
        let p = l.planets[i - 1], q = l.planets[i]
        if Aim.releaseAngle(center: p.base, ringR: p.ringR, dir: 1, target: q.base, offset: q.ringR) == nil { ok = false }
        if Aim.releaseAngle(center: p.base, ringR: p.ringR, dir: -1, target: q.base, offset: q.ringR) == nil { ok = false }
    }
    check(ok, "every planet reachable by a tangent shot")
}

// ── الطيّار الآليّ يصعد أوّل ثلاث كواكب بمسكات مثاليّة
var autoSim = Sim(seed: 2024)
do {
    autoSim.gravity = 0
    var ok = true
    for i in 0..<3 {
        guard autoSim.orbiting == i, let a = autoSim.plannedAngle(target: i + 1) else { ok = false; break }
        autoSim.setAngle(a); autoSim.release()
        let ev = runFlight(&autoSim)
        if captureOf(ev)?.planet != i + 1 || captureOf(ev)?.perfect != true { ok = false; print("auto step \(i): \(ev)") }
    }
    check(ok, "autopilot perfect chain")
    check(autoSim.score.combo == 3 && autoSim.score.perfects == 3 && autoSim.maxPlanet == 3, "combo 3 after 3 perfects")
    check(autoSim.score.points >= 90, "points at least 20+30+40: \(autoSim.score.points)")
}

// ── النقاط والكومبو
do {
    var sc = Scoring()
    let seq = [true, true, true, false, true].map { sc.register(perfect: $0, fresh: true) }
    check(seq == [20, 30, 40, 10, 20], "combo scoring: \(seq)")
    check(sc.points == 120 && sc.bestCombo == 3 && sc.combo == 1 && sc.perfects == 4 && sc.catches == 5, "scoring totals")
    check(sc.register(perfect: true, fresh: false) == 0 && sc.combo == 1 && sc.catches == 5, "going back scores nothing")
    var cap = Scoring()
    let s6 = (0..<7).map { _ in cap.register(perfect: true, fresh: true) }
    check(s6 == [20, 30, 40, 50, 50, 50, 50], "multiplier capped at ×5: \(s6)")
    check(Scoring.mult(0) == 1 && Scoring.mult(2) == 3 && Scoring.mult(99) == 5, "mult table")
    var g = Scoring(); g.gem(big: false); g.gem(big: true); g.warp()
    check(g.points == 37, "gem/warp bonus")
}

// ── المتجر والمحفظة
do {
    check(Catalog.comets.count >= 10 && Catalog.trails.count >= 10, "10+ skins each")
    let ids = Catalog.comets.map { $0.id } + Catalog.trails.map { $0.id }
    check(Set(ids).count == ids.count, "skin ids unique")
    check(Catalog.comets[0].price == 0 && Catalog.trails[0].price == 0, "starter skins free")
    check(zip(Catalog.comets, Catalog.comets.dropFirst()).allSatisfy { $0.price <= $1.price }, "comet prices ascend")
    check(zip(Catalog.trails, Catalog.trails.dropFirst()).allSatisfy { $0.price <= $1.price }, "trail prices ascend")
    check(Catalog.comet("nope").id == "c0" && Catalog.trail("t5").name == "شفق", "catalog lookup")
    var w = Wallet(); w.gems = 100
    check(w.buy("c1") == .bought && w.gems == 40, "buy comet")
    check(w.buy("c1") == .owned && w.gems == 40, "already owned")
    check(w.buy("c2") == .poor && w.gems == 40, "too poor")
    check(w.buy("zz") == .unknown, "unknown item")
    check(!w.equip("c2") && w.comet == "c0", "can't equip unowned")
    check(w.equip("c1") && w.comet == "c1", "equip comet")
    check(w.equip("t0") && w.trail == "t0", "equip trail")
    check(w.spend(Wallet.continueCost) && w.gems == 10, "continue spends 30")
    check(!w.spend(Wallet.continueCost) && w.gems == 10, "can't continue when poor")
    if let d = try? JSONEncoder().encode(w), let back = try? JSONDecoder().decode(Wallet.self, from: d) {
        check(back == w, "wallet codable")
    } else { check(false, "wallet encodes") }
}

// ── التحدّي اليوميّ
do {
    let k = Daily.key(year: 2026, month: 11, day: 16)
    check(k == 20261116, "day key")
    check(Daily.seed(k) == Daily.seed(20261116), "daily seed stable")
    check(Daily.seed(k) != Daily.seed(20261117), "next day different")
    let la = Level(seed: Daily.seed(k)), lb = Level(seed: Daily.seed(k))
    check(la.planets == lb.planets, "everyone gets same daily level")
}

// ── المهمّات
do {
    let m1 = Missions.forDay(20261116), m2 = Missions.forDay(20261116)
    check(m1.count == 3 && m1 == m2, "3 stable missions per day")
    check(Set(m1.map { $0.kind }).count == 3, "mission kinds distinct")
    var differs = false
    for d in 20261101...20261110 where Missions.forDay(d) != m1 { differs = true }
    check(differs, "missions rotate by day")
    let mp = Mission(kind: .perfects, target: 5, reward: 25)
    var rs = RunStats(); rs.perfects = 4
    check(!mp.done(rs), "4/5 not done")
    rs.perfects = 5
    check(mp.done(rs) && mp.value(rs) == 5, "5/5 done")
    check(Mission(kind: .combo, target: 3, reward: 1).title.contains("×4"), "combo title shows multiplier")
    check(MKind.allCases.allSatisfy { !Missions.make($0, 1).title.isEmpty && Missions.make($0, 2).target >= Missions.make($0, 0).target }, "mission tiers")
}

// ── الملفّ الشخصيّ: الأرقام القياسيّة والمكافآت
do {
    var p = Profile()
    p.wallet.gems = 0
    let key = 20261116
    var big = RunStats()
    big.score = 10000; big.perfects = 50; big.gems = 100; big.planets = 100; big.bestCombo = 10; big.warps = 5
    let o1 = p.record(big, key: key)
    let total = p.missions.reduce(0) { $0 + $1.reward }
    check(o1.newBest && o1.completed.count == 3 && o1.reward == total, "first run completes all missions")
    check(p.wallet.gems == 100 + total, "gems + rewards banked: \(p.wallet.gems)")
    let o2 = p.record(big, key: key)
    check(!o2.newBest && o2.completed.isEmpty && o2.reward == 0, "missions pay once")
    check(p.wallet.gems == 200 + total && p.runs == 2 && p.best == 10000, "second run")
    var small = RunStats(); small.score = 50; small.daily = true
    let o3 = p.record(small, key: key)
    check(o3.newDailyBest && p.dailyBest == 50 && p.dailyRuns == 1, "daily best tracked")
    _ = p.record(small, key: key + 1)
    check(p.missionKey == key + 1 && p.dailyBest == 50 && p.dailyRuns == 1, "new day resets daily")
    check(p.missionsDone.isEmpty || p.missionsDone.allSatisfy { p.missions[$0].done(small) }, "new day resets missions")
    for _ in 0..<40 { _ = p.record(small, key: key + 1) }
    check(p.history.count == Profile.historyCap, "history capped")
    check(p.history[0].score == 50 && p.best == 10000 && p.bestPlanets == 100, "history newest first")
    check(p.average > 0, "average computed")
    if let d = try? JSONEncoder().encode(p), let back = try? JSONDecoder().decode(Profile.self, from: d) {
        check(back == p, "profile codable")
    } else { check(false, "profile encodes") }
    let fromSim = RunStats(sim: autoSim, daily: false, when: Date(timeIntervalSince1970: 0))
    check(fromSim.planets == 3 && fromSim.perfects == 3 && fromSim.bestCombo == 3, "run stats from sim")
}

print("Madar tests: \(passed) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
