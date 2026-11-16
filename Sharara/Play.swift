import SwiftUI

struct Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Double
    var max: Double
    var size: Double
    var col: RGB
    var streak: Bool
}

struct Floater {
    var x: Double
    var y: Double
    var text: String
    var life: Double
    var col: RGB
    var big: Bool
}

struct Wave {
    var x: Double
    var y: Double
    var r: Double
    var life: Double
    var max: Double
    var col: RGB
}

enum PlayPhase { case aim, running, done }

/// نتيجة جاهزة للعرض
struct Verdict {
    var outcome: Outcome
    var passed: Bool
    var stars: Int
    var coins: Int
    var total: Int        // لبلا نهاية: المجموع
    var newBest: Bool
}

/// كلّ مراحل تتخزّن حتى ما نعيد الحساب
enum LevelCache {
    static var store: [String: Level] = [:]
    static func get(_ r: GameReq) -> Level {
        let key = "\(r.mode.rawValue)-\(r.index)-\(r.runSeed)"
        if let l = store[key] { return l }
        let spec: LevelSpec
        switch r.mode {
        case .campaign: spec = Gen.campaign(r.index)
        case .endless: spec = Gen.endless(round: r.index, runSeed: r.runSeed)
        case .daily: spec = Gen.daily(day: r.index)
        case .perfect: spec = Gen.perfect(r.index)
        }
        let l = Gen.make(spec)
        if store.count > 40 { store.removeAll() }
        store[key] = l
        return l
    }
}

/// محرّك الجولة: يقدّم المحاكاة بخطوة ثابتة، ويحوّل الأحداث لجزيئات وصوت واهتزاز
final class Play: ObservableObject {
    let req: GameReq
    let level: Level
    let skin: SparkSkin
    let back: BackSkin
    let calm: Bool
    private let store: GameStore

    var world: World
    @Published var phase: PlayPhase = .aim
    @Published var net = 0
    @Published var pops = 0
    @Published var verdict: Verdict? = nil
    @Published var hinted = false

    var parts: [Particle] = []
    var floaters: [Floater] = []
    var waves: [Wave] = []
    var shake = 0.0
    var shock = 0.0
    var slow = 0.0
    var tierText = ""
    var tierLife = 0.0
    var chainPulse = 0.0
    var hueTarget = 0.0
    var hueNow = 0.0
    var aim: P? = nil
    var hintTap: P? = nil
    var clock = 0.0
    var frozen = false
    var holdTime = false

    private var last = 0.0
    private var acc = 0.0
    private var endWait = 0.0
    private var hapticGate = 0.0
    private var rng = SRNG(99)
    private var dirty = false
    private var finished = false

    init(req: GameReq, store: GameStore) {
        self.req = req
        self.store = store
        let lv = LevelCache.get(req)
        self.level = lv
        self.world = lv.world
        self.skin = Catalog.spark(store.p.spark)
        self.back = Catalog.back(store.p.back)
        self.calm = store.calmShake
        if Shot.on { prepareShot() }
    }

    var title: String {
        switch req.mode {
        case .campaign:
            let g = req.index / Gen.perGalaxy
            return Gen.galaxyNames[min(g, Gen.galaxyNames.count - 1)] + " · \(req.index % Gen.perGalaxy + 1)"
        case .endless: return "بلا نهاية · الجولة \(req.index + 1)"
        case .daily: return "تحدّي اليوم"
        case .perfect: return "الضربة الكاملة · \(req.index + 1)"
        }
    }

    var subtitle: String {
        switch req.mode {
        case .campaign:
            let k = Gen.galaxyIntro[min(req.index / Gen.perGalaxy, 7)]
            if req.index % Gen.perGalaxy < 2 && k != .normal && req.index >= Gen.perGalaxy { return "جديد: " + k.name + " — " + k.note }
            return "فجّر \(level.target) من \(level.goodTotal)"
        case .endless: return "المجموع \(req.carry) · فجّر \(level.target) حتى تكمل"
        case .daily: return "نفس اللغز لكلّ العالم اليوم"
        case .perfect: return "لازم توصل \(level.target) — أعلى رقم ممكن"
        }
    }

    // MARK: الحلقة

    func tick(_ now: Double) {
        if frozen { return }
        if last == 0 { last = now }
        var dt = now - last
        last = now
        dt = min(max(dt, 0), 1.0 / 20)
        update(dt, now: now)
    }

    func update(_ dt: Double, now: Double) {
        clock += dt
        let scale = slow > 0 ? 0.3 : 1.0
        slow = max(0, slow - dt)
        let sdt = dt * scale
        if !(holdTime && phase == .aim) {
            acc += sdt
            var n = 0
            while acc >= Tune.dt && n < 8 {
                world.step()
                acc -= Tune.dt
                n += 1
            }
            if n >= 8 { acc = 0 }
        }
        handle(world.drainEvents(), now: now)
        // جزيئات
        if !parts.isEmpty {
            for i in parts.indices {
                parts[i].x += parts[i].vx * sdt
                parts[i].y += parts[i].vy * sdt
                parts[i].vx *= (1 - 2.2 * sdt)
                parts[i].vy *= (1 - 2.2 * sdt)
                parts[i].vy += 40 * sdt
                parts[i].life -= sdt
            }
            parts.removeAll { $0.life <= 0 }
        }
        if !floaters.isEmpty {
            for i in floaters.indices {
                floaters[i].y -= 34 * sdt
                floaters[i].life -= sdt
            }
            floaters.removeAll { $0.life <= 0 }
        }
        if !waves.isEmpty {
            for i in waves.indices { waves[i].life -= sdt }
            waves.removeAll { $0.life <= 0 }
        }
        shake *= exp(-dt * 8)
        shock *= exp(-dt * 6)
        chainPulse *= exp(-dt * 7)
        tierLife = max(0, tierLife - dt)
        hueNow += (hueTarget - hueNow) * min(1, dt * 2.5)
        if dirty {
            dirty = false
            let p = world.pops, n = world.net
            DispatchQueue.main.async { self.pops = p; self.net = n }
        }
        if phase == .running && world.finished && !finished {
            endWait += dt
            if endWait > 0.75 { finish() }
        }
    }

    // MARK: اللاعب

    func setAim(_ p: P?) {
        guard phase == .aim else { return }
        aim = p
    }

    func shoot(_ p: P) {
        guard phase == .aim, p.x >= -20, p.x <= Tune.W + 20, p.y >= -20, p.y <= Tune.H + 20 else { aim = nil; return }
        aim = nil
        hintTap = nil
        holdTime = false
        if world.fire(at: p) {
            phase = .running
        }
    }

    /// تلميح: يوقّف الزمن ويبيّن أحسن نقطة هسه
    func useHint() -> Bool {
        guard phase == .aim, !hinted else { return false }
        let cost = 40
        if !Shot.on {
            if store.p.coins < cost { return false }
            store.p.coins -= cost
        }
        hinted = true
        holdTime = true
        hintTap = Gen.probe(world).tap
        return true
    }

    // MARK: الأحداث

    private func burst(_ p: P, _ n: Int, _ col: RGB, speed: Double, size: Double, streak: Bool) {
        if parts.count > 900 { return }
        for _ in 0..<n {
            let a = rng.range(0, 2 * Double.pi)
            let v = speed * rng.range(0.35, 1.0)
            let life = rng.range(0.35, 0.9)
            parts.append(Particle(x: p.x, y: p.y, vx: cos(a) * v, vy: sin(a) * v, life: life, max: life,
                                  size: size * rng.range(0.6, 1.3), col: col, streak: streak))
        }
    }

    private func handle(_ evs: [Ev], now: Double) {
        if evs.isEmpty { return }
        for e in evs {
            switch e {
            case .fire(let p):
                waves.append(Wave(x: p.x, y: p.y, r: world.sparkMaxR * 1.4, life: 0.6, max: 0.6, col: skin.glow))
                burst(p, 30, skin.core, speed: 320, size: 2.6, streak: true)
                burst(p, 16, skin.glow, speed: 160, size: 4, streak: false)
                shake += 4
                shock = 1
                Synth.shared.fire()
                store.buzz(1)
            case .pop(let p, let k, let link, _):
                dirty = true
                let col = Look.rgb(k)
                let big = k == .big || k == .magnet
                burst(p, big ? 34 : 16, col, speed: big ? 340 : 230, size: 2.2, streak: true)
                burst(p, big ? 14 : 7, RGB(1, 1, 1), speed: 120, size: 3, streak: false)
                waves.append(Wave(x: p.x, y: p.y, r: world.baseR * (big ? 1.6 : 1), life: 0.45, max: 0.45, col: col))
                if k == .bad {
                    floaters.append(Floater(x: p.x, y: p.y - 14, text: "\(k.points)", life: 1.1, col: RGB(1, 0.3, 0.35), big: true))
                    Synth.shared.bad()
                    store.buzz(3)
                    shake += 5
                } else {
                    let pts = k.points * World.mult(link)
                    floaters.append(Floater(x: p.x, y: p.y - 14, text: "+\(pts)", life: 0.9, col: World.mult(link) > 1 ? RGB(1, 0.83, 0.32) : RGB(1, 1, 1), big: World.mult(link) > 2))
                    Synth.shared.note(link, now: now)
                    if now - hapticGate > 0.05 { hapticGate = now; store.buzz(0) }
                    shake += big ? 5 : 1.4
                }
                if big { Synth.shared.boom(); shock = max(shock, 0.9) } else { shock = max(shock, 0.3) }
                chainPulse = 1
            case .shield(let p):
                burst(p, 12, RGB(0.8, 0.9, 1), speed: 200, size: 2, streak: true)
                floaters.append(Floater(x: p.x, y: p.y - 18, text: "انكسر الدرع", life: 0.9, col: RGB(0.8, 0.92, 1), big: false))
                Synth.shared.clink()
            case .arm(let p, let k):
                floaters.append(Floater(x: p.x, y: p.y - 20, text: k == .magnet ? "يسحب!" : "انتظر…", life: 0.9, col: Look.rgb(k), big: false))
                Synth.shared.tick()
            case .split(let p):
                burst(p, 10, Look.rgb(.splitter), speed: 260, size: 2, streak: true)
            case .tier(let n):
                tierText = ChainWords.tier(n)
                tierLife = 1.6
                slow = 0.85
                hueTarget += 0.11
                shake += 6
                store.buzz(1)
            }
        }
        shake = min(shake, 14)
    }

    // MARK: النهاية

    private func finish() {
        finished = true
        let o = world.outcome
        let lv = level
        let r = req
        let st = store
        DispatchQueue.main.async {
            var v = Verdict(outcome: o, passed: lv.passed(o.net), stars: 0, coins: 0, total: o.score, newBest: false)
            switch r.mode {
            case .campaign:
                v.stars = lv.stars(o.net)
                let prevBest = st.p.best[min(r.index, st.p.best.count - 1)]
                v.newBest = v.passed && o.score > prevBest
                v.coins = st.p.finishCampaign(r.index, stars: v.stars, outcome: o)
            case .endless:
                v.total = r.carry + o.score
                v.newBest = v.total > st.p.endlessScore
                v.coins = st.p.finishEndless(rounds: v.passed ? r.index + 1 : r.index, score: v.total, outcome: o, passed: v.passed)
            case .daily:
                v.stars = lv.stars(o.net)
                v.newBest = o.score > (st.p.dailyBest[r.index] ?? 0)
                v.coins = st.p.finishDaily(day: r.index, outcome: o, passed: v.passed)
            case .perfect:
                v.stars = v.passed ? 3 : 0
                v.coins = st.p.finishPerfect(r.index, outcome: o, passed: v.passed)
            }
            if v.passed { Synth.shared.win(); st.buzz(2) } else { Synth.shared.lose(); st.buzz(3) }
            self.pops = o.pops
            self.net = o.net
            self.verdict = v
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { self.phase = .done }
        }
    }

    // MARK: لقطات الشاشة

    private func prepareShot() {
        let step = 1.0 / 60
        var now = 1.0
        for _ in 0..<70 { update(step, now: now); now += step }
        let tap = Gen.probe(world).tap
        switch Shot.name {
        case "play":
            aim = tap
        case "chain":
            world.fire(at: tap)
            phase = .running
            let goal = max(9, level.best * 6 / 10)
            var n = 0
            while world.pops < goal && !world.finished && n < 900 { update(step, now: now); now += step; n += 1 }
            for _ in 0..<5 { update(step, now: now); now += step }
            tierLife = max(tierLife, 1.1)
            if tierText.isEmpty { tierText = ChainWords.tier(1) }
            pops = world.pops
            net = world.net
        case "result":
            world.fire(at: tap)
            phase = .running
            world.settle()
            _ = world.drainEvents()
            let o = world.outcome
            finished = true
            let stars = level.stars(o.net)
            verdict = Verdict(outcome: o, passed: level.passed(o.net), stars: max(stars, 2), coins: 64, total: o.score, newBest: true)
            pops = o.pops
            net = o.net
            phase = .done
        default:
            break
        }
        frozen = true
    }
}
