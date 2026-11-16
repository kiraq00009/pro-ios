import SwiftUI

struct Particle {
    var p: V2
    var v: V2
    var life: Double
    var max: Double
    var size: Double
    var c: RGB
    var drag: Double
}

struct FloatText {
    var text: String
    var p: V2
    var age: Double
    var c: RGB
    var size: Double
}

struct Ripple {
    var p: V2
    var r0: Double
    var age: Double
    var c: RGB
    var width: Double
}

struct StarDot {
    var x: Double
    var y: Double
    var size: Double
    var layer: Int
    var tw: Double
}

/// محرّك اللعبة: المحاكاة + المؤثّرات + الكاميرا. الرسم بـ Render.swift
final class Engine: ObservableObject {
    enum Phase { case ready, playing, dying, over }

    @Published var phase: Phase = .ready
    @Published var score = 0
    @Published var combo = 0
    @Published var gemsRun = 0
    @Published var height = 0
    @Published var paused = false
    @Published var banner: String? = nil
    @Published var stats: RunStats? = nil
    @Published var preview: Profile.Outcome? = nil
    @Published var usedContinue = false
    @Published var committed = false

    let store: Store
    let daily: Bool
    private(set) var seed: UInt64
    var sim: Sim
    var comet: CometSkin
    var trail: TrailSkin
    var parts: [Particle] = []
    var texts: [FloatText] = []
    var ripples: [Ripple] = []
    var trailPts: [V2] = []
    var stars: [StarDot] = []
    var camY = 0.0
    var viewH = 780.0
    var shake = 0.0
    var flash = 0.0
    var flashColor = RGB(1, 1, 1)
    var slow = 0.0
    var clock = 0.0
    var guide = true
    var frozen = false
    var skyA = MD.zoneSky[0].0
    var skyB = MD.zoneSky[0].1
    var skyN = MD.zoneSky[0].2
    var lastZone = 0
    var deadTimer = 0.0
    var bannerTimer = 0.0
    private var last: Date? = nil
    private var acc = 0.0
    private var fxr = MRng(seed: 4242)
    private var shotCaps = 0
    static let dt = 1.0 / 120

    init(store: Store, daily: Bool) {
        self.store = store
        self.daily = daily
        let sd: UInt64 = daily ? Daily.seed(Store.today) : (Shot.on ? 7 : UInt64.random(in: 1...UInt64.max))
        seed = sd
        sim = Sim(seed: sd)
        comet = Catalog.comet(store.p.wallet.comet)
        trail = Catalog.trail(store.p.wallet.trail)
        guide = FX.guide
        makeStars()
        camY = sim.level.planets[0].base.y - viewH * 0.3
        if Shot.on { prewarm(Shot.name) }
    }

    private func makeStars() {
        var r = MRng(seed: 777)
        stars = (0..<170).map { k in
            StarDot(x: r.unit(), y: r.unit(), size: k % 3 == 0 ? r.range(1.2, 2.2) : r.range(0.5, 1.3), layer: k % 3, tw: r.range(0, 6.28))
        }
    }

    // MARK: التحكّم

    func tap() {
        guard !paused, !frozen else { return }
        switch phase {
        case .ready:
            phase = .playing
            doRelease()
        case .playing:
            doRelease()
        case .dying, .over:
            break
        }
    }

    private func doRelease() {
        guard sim.orbiting != nil, let e = sim.release() else { return }
        handle([e])
    }

    func restart() {
        commit()
        seed = daily ? Daily.seed(Store.today) : UInt64.random(in: 1...UInt64.max)
        sim = Sim(seed: seed)
        comet = Catalog.comet(store.p.wallet.comet)
        trail = Catalog.trail(store.p.wallet.trail)
        parts = []; texts = []; ripples = []; trailPts = []
        shake = 0; flash = 0; slow = 0; lastZone = 0
        camY = sim.level.planets[0].base.y - viewH * 0.3
        score = 0; combo = 0; gemsRun = 0; height = 0
        stats = nil; preview = nil; usedContinue = false; committed = false
        phase = .ready
        paused = false
        Synth.shared.play("click")
    }

    var canAffordContinue: Bool { store.p.wallet.gems >= Wallet.continueCost }

    func continueRun() {
        guard !usedContinue, phase == .over, store.spendContinue() else { return }
        usedContinue = true
        sim.revive()
        trailPts = []
        stats = nil
        preview = nil
        phase = .ready
        flash = 0.6; flashColor = RGB(0.4, 1, 0.8)
        burst(sim.pos, 40, RGB(0.4, 1, 0.8), 180, 0.9)
        Synth.shared.play("revive")
        FX.ok()
    }

    /// يحفظ الجولة بالملفّ (مرّة وحدة)
    func commit() {
        guard !committed, !Shot.on else { return }
        let live: RunStats? = sim.maxPlanet > 0 ? RunStats(sim: sim, daily: daily, when: Date()) : nil
        guard let s = stats ?? live else { return }
        committed = true
        _ = store.record(s)
    }

    // MARK: الإطار

    func frame(_ now: Date, _ size: CGSize) {
        let k = Double(size.width) / Level.width
        if k > 0 { viewH = Double(size.height) / k }
        let realDt: Double = last.map { min(0.05, max(0, now.timeIntervalSince($0))) } ?? 0
        last = now
        clock += realDt
        if frozen || paused { return }
        advance(realDt)
    }

    private func advance(_ realDt: Double) {
        if slow > 0 { slow -= realDt }
        let scale = slow > 0 ? 0.32 : 1.0
        shake = max(0, shake - realDt * 2.4)
        flash = max(0, flash - realDt * 2.2)
        if bannerTimer > 0 {
            bannerTimer -= realDt
            if bannerTimer <= 0 { ui { self.banner = nil } }
        }
        switch phase {
        case .ready, .playing:
            acc += realDt * scale
            var n = 0
            while acc >= Engine.dt && n < 14 {
                acc -= Engine.dt
                n += 1
                let ev = sim.step(Engine.dt)
                if !ev.isEmpty { handle(ev) }
                afterStep()
                if !sim.alive { break }
            }
        case .dying:
            deadTimer -= realDt
            if deadTimer <= 0 { deadTimer = 1e9; finish() }
        case .over:
            break
        }
        tickFX(realDt * scale)
        camera(realDt)
    }

    private func afterStep() {
        trailPts.append(sim.pos)
        let cap = sim.orbiting == nil ? 70 : 34
        if trailPts.count > cap { trailPts.removeFirst(trailPts.count - cap) }
        if sim.orbiting == nil, Int(sim.t * 120) % 2 == 0 {
            let c = trail.colors[Int(clock * 3) % max(1, trail.colors.count)]
            let back = sim.vel.norm * -1
            parts.append(Particle(p: sim.pos, v: back * fxr.range(20, 60) + V2(fxr.range(-25, 25), fxr.range(-25, 25)), life: 0, max: fxr.range(0.3, 0.6), size: fxr.range(1.2, 2.6), c: c, drag: 2))
            if trail.sparkle && fxr.chance(0.3) {
                parts.append(Particle(p: sim.pos, v: V2(fxr.range(-60, 60), fxr.range(-60, 60)), life: 0, max: 0.5, size: 1.4, c: RGB(1, 1, 1), drag: 3))
            }
        }
    }

    private func tickFX(_ dt: Double) {
        guard dt > 0 else { return }
        var keep: [Particle] = []
        keep.reserveCapacity(parts.count)
        for var p in parts {
            p.life += dt
            if p.life < p.max {
                p.p += p.v * dt
                p.v = p.v * max(0, 1 - p.drag * dt)
                keep.append(p)
            }
        }
        if keep.count > 700 { keep.removeFirst(keep.count - 700) }
        parts = keep
        for i in texts.indices { texts[i].age += dt; texts[i].p.y += 34 * dt }
        texts.removeAll { $0.age > 1.3 }
        for i in ripples.indices { ripples[i].age += dt }
        ripples.removeAll { $0.age > 0.8 }
        // ألوان السماء تتبدّل بهدوء مع المنطقة
        let z = Level.zone(sim.maxPlanet)
        let sky = MD.zoneSky[z % MD.zoneSky.count]
        let t = min(1, dt * 0.8)
        skyA = mixRGB(skyA, sky.0, t); skyB = mixRGB(skyB, sky.1, t); skyN = mixRGB(skyN, sky.2, t)
    }

    private func camera(_ dt: Double) {
        let focus: Double
        if let i = sim.orbiting {
            focus = sim.level.planets[i].base.y - viewH * 0.3
        } else {
            let home = sim.level.planets[min(sim.from, sim.level.planets.count - 1)].base.y - viewH * 0.3
            focus = max(home, sim.pos.y - viewH * 0.5)
        }
        camY += (focus - camY) * min(1, dt * 3.2)
    }

    private func finish() {
        let s = RunStats(sim: sim, daily: daily, when: Date())
        let pv = store.preview(s)
        let canCont = !usedContinue && canAffordContinue
        ui {
            self.stats = s
            self.preview = pv
            self.phase = .over
            if !canCont { self.commit() }
        }
    }

    // MARK: الأحداث

    func handle(_ events: [SimEvent]) {
        for e in events {
            switch e {
            case .release:
                Synth.shared.play("release")
                FX.tap()
                burst(sim.pos, 10, comet.glow, 90, 0.4)
            case .capture(let planet, let perfect, let points, let cmb, let fresh):
                onCapture(planet, perfect, points, cmb, fresh)
            case .gem(_, let big):
                burst(sim.pos, big ? 26 : 12, big ? RGB(0.5, 1, 1) : RGB(1, 0.85, 0.35), 130, 0.5)
                addText(big ? "+5 💎" : "+1", sim.pos + V2(0, 18), big ? RGB(0.5, 1, 1) : RGB(1, 0.85, 0.35), big ? 20 : 15)
                Synth.shared.play(big ? "biggem" : "gem")
                FX.tap()
                let s = sim.score.points, g = sim.gemsRun
                ui { self.score = s; self.gemsRun = g }
            case .warp(let to):
                flash = 0.7; flashColor = RGB(0.7, 0.5, 1)
                shake = max(shake, 0.35)
                burst(sim.pos, 40, RGB(0.75, 0.5, 1), 220, 0.7)
                addText("قفزة نجميّة! +25", sim.pos + V2(0, 26), RGB(0.8, 0.6, 1), 20)
                Synth.shared.play("warp")
                FX.thud()
                let s = sim.score.points
                ui { self.score = s; self.height = max(self.height, to - 1) }
            case .death(let c):
                onDeath(c)
            }
        }
    }

    private func onCapture(_ planet: Int, _ perfect: Bool, _ points: Int, _ cmb: Int, _ fresh: Bool) {
        let p = sim.level.planets[planet]
        let c = p.center(sim.t)
        shotCaps += 1
        ripples.append(Ripple(p: c, r0: p.ringR, age: 0, c: perfect ? RGB(1, 0.85, 0.4) : RGB(0.5, 0.9, 1), width: perfect ? 5 : 3))
        if perfect {
            slow = 0.42
            flash = 0.45; flashColor = RGB(1, 0.92, 0.7)
            shake = max(shake, 0.18)
            burst(sim.pos, 46, RGB(1, 0.85, 0.4), 240, 0.8)
            ring(c, p.ringR, 36, RGB(1, 0.95, 0.75))
            let words = ["مثاليّ!", "رهيب!", "خرافي!", "أسطوريّ!", "لا يُوقَف!"]
            addText(words[min(words.count - 1, max(0, cmb - 1))], sim.pos + V2(0, 34), RGB(1, 0.88, 0.45), 30)
            if fresh { addText("+\(points)  ×\(Scoring.mult(cmb))", sim.pos + V2(0, 6), RGB(1, 1, 1), 18) }
            Synth.shared.perfect(cmb)
            FX.ok()
        } else {
            burst(sim.pos, 18, RGB(0.5, 0.9, 1), 140, 0.5)
            if fresh { addText("+\(points)", sim.pos + V2(0, 22), RGB(0.7, 0.95, 1), 18) }
            Synth.shared.play("catch")
            FX.thud()
        }
        let z = Level.zone(planet)
        if fresh && z > lastZone {
            lastZone = z
            let name = MD.zoneName(z)
            bannerTimer = 2.2
            Synth.shared.play("zone")
            ui { self.banner = name }
        }
        let s = sim.score.points, cb = sim.score.combo, h = sim.maxPlanet
        ui { self.score = s; self.combo = cb; self.height = h }
    }

    private func onDeath(_ c: DeathCause) {
        shake = 1
        flash = 0.5; flashColor = RGB(1, 0.35, 0.3)
        burst(sim.pos, 70, comet.glow, 320, 1.1)
        burst(sim.pos, 30, RGB(1, 1, 1), 160, 0.6)
        ring(sim.pos, 10, 24, RGB(1, 0.5, 0.4))
        Synth.shared.play("death")
        FX.bad()
        trailPts = []
        deadTimer = 1.0
        ui { self.phase = .dying; self.combo = 0 }
    }

    // MARK: مؤثّرات

    func burst(_ at: V2, _ n: Int, _ c: RGB, _ speed: Double, _ life: Double) {
        for _ in 0..<n {
            let a = fxr.range(0, 6.283)
            let v = V2.ang(a) * (speed * fxr.range(0.25, 1))
            parts.append(Particle(p: at, v: v, life: 0, max: life * fxr.range(0.5, 1.1), size: fxr.range(1.5, 3.6), c: c, drag: 2.2))
        }
    }

    private func ring(_ c: V2, _ r: Double, _ n: Int, _ col: RGB) {
        for k in 0..<n {
            let a = Double(k) / Double(n) * 6.283
            parts.append(Particle(p: c + V2.ang(a) * r, v: V2.ang(a) * 90, life: 0, max: 0.6, size: 2.2, c: col, drag: 2.5))
        }
    }

    private func addText(_ t: String, _ p: V2, _ c: RGB, _ s: Double) {
        texts.append(FloatText(text: t, p: p, age: 0, c: c, size: s))
    }

    private func ui(_ f: @escaping () -> Void) {
        if Shot.on && frozenSetup { f(); return }
        DispatchQueue.main.async(execute: f)
    }
    private var frozenSetup = false

    // MARK: وضع التصوير: نلعب لحالنا لحدّ اللقطة المطلوبة

    private func prewarm(_ name: String) {
        frozenSetup = true
        guide = true
        phase = .playing
        let dt = Engine.dt
        var perfectSeen = -1.0
        var steps = 0
        while steps < 120 * 60 {
            steps += 1
            if let i = sim.orbiting, sim.orbitTime > 0.4, let a = sim.plannedAngle(target: i + 1) {
                sim.setAngle(a)
                if let e = sim.release() { handle([e]) }
            }
            let ev = sim.step(dt)
            if !ev.isEmpty { handle(ev) }
            afterStep()
            if !sim.alive {
                if name == "gameover" { break }
                sim.revive(); phase = .playing; trailPts = []
            }
            tickFX(dt)
            camera(dt)
            shake = max(0, shake - dt * 2.4)
            if slow > 0 { slow -= dt }
            if name == "play" && shotCaps >= 3 && sim.orbiting == nil && sim.flyTime > 0.32 { break }
            if name == "perfect" && shotCaps >= 3 {
                if perfectSeen < 0, ripples.contains(where: { $0.width > 4 && $0.age < 0.02 }) { perfectSeen = sim.t }
                if perfectSeen >= 0 && sim.t - perfectSeen > 0.14 { break }
            }
            if name == "gameover" && shotCaps >= 5 && sim.orbiting == nil && sim.flyTime > 0.2 {
                sim.kill(.moon)
                onDeath(.moon)
                for _ in 0..<40 { tickFX(dt) }
                break
            }
            if !["play", "perfect", "gameover"].contains(name) && steps > 120 * 2 { break }
        }
        flash = min(flash, 0.25)
        shake = 0
        if name == "gameover" {
            let s = RunStats(sim: sim, daily: false, when: Date())
            stats = s
            preview = store.preview(s)
            phase = .over
        }
        frozen = true
        frozenSetup = false
    }
}
