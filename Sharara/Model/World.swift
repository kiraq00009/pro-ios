import Foundation

/// العالم: محاكاة حتميّة بخطوة ثابتة (١/٦٠ ثانية)
struct World {
    var orbs: [Orb]
    var blasts: [Blast] = []
    var sparks: [Spark] = []
    var t: Double = 0
    var steps = 0
    var fired = false
    var fireT: Double = 0
    var baseR: Double
    var sparkMaxR: Double
    var pops = 0
    var good = 0
    var bad = 0
    var score = 0
    var maxGen = 0
    var events: [Ev] = []
    var log = true
    private var nextId = 0

    init(orbs: [Orb], baseR: Double, sparkR: Double) {
        self.orbs = orbs
        self.baseR = baseR
        self.sparkMaxR = sparkR
    }

    var goodTotal: Int { orbs.reduce(0) { $0 + ($1.kind == .bad ? 0 : 1) } }
    var badTotal: Int { orbs.count - goodTotal }
    var net: Int { good - bad }
    var armedCount: Int { orbs.reduce(0) { $0 + ($1.state == .armed ? 1 : 0) } }
    var finished: Bool { fired && blasts.isEmpty && sparks.isEmpty && armedCount == 0 }
    var outcome: Outcome { Outcome(pops: pops, good: good, bad: bad, score: max(0, score), maxGen: maxGen) }

    /// مضاعف السلسلة: يكبر كلّ ٥ حلقات
    static func mult(_ link: Int) -> Int { 1 + max(0, link - 1) / 5 }

    /// إطلاق الشرارة الوحيدة. ترجع false إذا انطلقت قبل
    @discardableResult
    mutating func fire(at p: P) -> Bool {
        if fired { return false }
        fired = true
        fireT = t
        let c = P(min(max(p.x, 0), Tune.W), min(max(p.y, 0), Tune.H))
        addBlast(c, sparkMaxR, gen: 0, source: nil)
        emit(.fire(c))
        return true
    }

    private mutating func emit(_ e: Ev) { if log { events.append(e) } }

    private mutating func addBlast(_ p: P, _ r: Double, gen: Int, source: OrbKind?) {
        blasts.append(Blast(id: nextId, pos: p, maxR: r, gen: gen, source: source))
        nextId += 1
    }

    mutating func drainEvents() -> [Ev] {
        let e = events
        events.removeAll(keepingCapacity: true)
        return e
    }

    // MARK: الخطوة

    mutating func step() {
        let dt = Tune.dt
        t += dt
        steps += 1
        moveOrbs(dt)
        pullMagnets(dt)
        burnFuses(dt)
        for b in blasts.indices { blasts[b].age += dt }
        moveSparks(dt)
        resolveBlasts()
        blasts.removeAll { $0.done }
    }

    /// يكمّل لحدّ ما تخلص السلسلة
    mutating func settle(limit: Int = Tune.maxSteps) {
        var n = 0
        while !finished && n < limit { step(); n += 1 }
    }

    private mutating func moveOrbs(_ dt: Double) {
        for i in orbs.indices {
            if orbs[i].state == .dead { continue }
            if orbs[i].state == .armed && orbs[i].kind == .magnet { continue }
            var o = orbs[i]
            o.pos = o.pos + o.vel * dt
            if o.pos.x < o.r { o.pos.x = o.r; o.vel.x = abs(o.vel.x) }
            if o.pos.x > Tune.W - o.r { o.pos.x = Tune.W - o.r; o.vel.x = -abs(o.vel.x) }
            if o.pos.y < o.r { o.pos.y = o.r; o.vel.y = abs(o.vel.y) }
            if o.pos.y > Tune.H - o.r { o.pos.y = Tune.H - o.r; o.vel.y = -abs(o.vel.y) }
            orbs[i] = o
        }
    }

    private mutating func pullMagnets(_ dt: Double) {
        for m in orbs.indices {
            if !(orbs[m].state == .armed && orbs[m].kind == .magnet) { continue }
            let c = orbs[m].pos
            for i in orbs.indices {
                if i == m || orbs[i].state != .alive { continue }
                let d = c - orbs[i].pos
                let L = d.len
                if L > 4 && L < Tune.magnetRange {
                    let move = min(Tune.magnetPull * dt, L - 4)
                    orbs[i].pos = orbs[i].pos + d * (move / L)
                }
            }
        }
    }

    private mutating func burnFuses(_ dt: Double) {
        for i in orbs.indices {
            if orbs[i].state != .armed { continue }
            orbs[i].fuse -= dt
            if orbs[i].fuse <= 0 { pop(i, gen: orbs[i].gen) }
        }
    }

    private mutating func moveSparks(_ dt: Double) {
        if sparks.isEmpty { return }
        for s in sparks.indices {
            if !sparks[s].alive { continue }
            var k = sparks[s]
            k.pos = k.pos + k.vel * dt
            k.life -= dt
            if k.pos.x < 0 { k.pos.x = 0; k.vel.x = abs(k.vel.x) }
            if k.pos.x > Tune.W { k.pos.x = Tune.W; k.vel.x = -abs(k.vel.x) }
            if k.pos.y < 0 { k.pos.y = 0; k.vel.y = abs(k.vel.y) }
            if k.pos.y > Tune.H { k.pos.y = Tune.H; k.vel.y = -abs(k.vel.y) }
            var touched = false
            for i in orbs.indices {
                if orbs[i].state != .alive { continue }
                if k.pos.dist(orbs[i].pos) <= orbs[i].r + Tune.sparkR { touched = true; break }
            }
            if touched || k.life <= 0 {
                k.alive = false
                addBlast(k.pos, baseR * 0.55, gen: k.gen, source: .splitter)
            }
            sparks[s] = k
        }
        sparks.removeAll { !$0.alive }
    }

    private mutating func resolveBlasts() {
        let count = blasts.count
        var b = 0
        while b < count {
            let bl = blasts[b]
            b += 1
            if !bl.hot { continue }
            let reach = bl.r
            for i in orbs.indices {
                if orbs[i].state != .alive { continue }
                if orbs[i].kind == .shield && orbs[i].shieldBy == bl.id { continue }
                if bl.pos.dist(orbs[i].pos) <= reach + orbs[i].r { hit(i, blast: bl) }
            }
        }
    }

    // MARK: الإصابة والانفجار

    private mutating func hit(_ i: Int, blast: Blast) {
        let g = blast.gen
        switch orbs[i].kind {
        case .shield:
            if orbs[i].hp > 1 {
                orbs[i].hp -= 1
                orbs[i].shieldBy = blast.id
                emit(.shield(orbs[i].pos))
            } else {
                pop(i, gen: g)
            }
        case .magnet:
            orbs[i].state = .armed
            orbs[i].fuse = Tune.magnetT
            orbs[i].gen = g
            emit(.arm(orbs[i].pos, .magnet))
        case .timer:
            orbs[i].state = .armed
            orbs[i].fuse = Tune.timerT
            orbs[i].gen = g
            emit(.arm(orbs[i].pos, .timer))
        case .normal, .big, .bouncer, .splitter, .bad:
            pop(i, gen: g)
        }
    }

    private mutating func pop(_ i: Int, gen: Int) {
        orbs[i].state = .dead
        let k = orbs[i].kind
        let p = orbs[i].pos
        pops += 1
        if k == .bad {
            bad += 1
            score += k.points
        } else {
            good += 1
            score += k.points * World.mult(pops)
        }
        maxGen = max(maxGen, gen)
        emit(.pop(p, k, pops, gen))
        if pops % Tune.tierEvery == 0 { emit(.tier(pops / Tune.tierEvery)) }
        let ng = gen + 1
        switch k {
        case .big:
            addBlast(p, baseR * 1.75, gen: ng, source: k)
        case .splitter:
            addBlast(p, baseR * 0.6, gen: ng, source: k)
            for j in 0..<3 {
                let a = orbs[i].phase + Double(j) * (2 * Double.pi / 3)
                sparks.append(Spark(pos: p, vel: P(cos(a), sin(a)) * Tune.sparkSpeed, life: Tune.sparkLife, gen: ng))
            }
            emit(.split(p))
        case .magnet:
            addBlast(p, baseR * 1.25, gen: ng, source: k)
        case .bad:
            addBlast(p, baseR * 0.9, gen: ng, source: k)
        case .normal, .bouncer, .shield, .timer:
            addBlast(p, baseR, gen: ng, source: k)
        }
    }

    /// يشغّل ضربة كاملة على نسخة من العالم ويرجع النتيجة (للحلّال والاختبارات)
    func simulate(tapAt p: P, after wait: Int = 0) -> Outcome {
        var w = self
        w.log = false
        w.events.removeAll()
        var n = 0
        while n < wait { w.step(); n += 1 }
        w.fire(at: p)
        w.settle()
        return w.outcome
    }
}
