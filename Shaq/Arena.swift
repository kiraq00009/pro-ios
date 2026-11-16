import SwiftUI

enum PlayMode: Hashable {
    case campaign(Int), endless, daily, zen

    var title: String {
        switch self {
        case .campaign(let id): return "المرحلة \(id + 1)"
        case .endless: return "بلا نهاية"
        case .daily: return "تحدّي اليوم"
        case .zen: return "زِن"
        }
    }
    var key: String {
        switch self {
        case .campaign(let id): return "c\(id)"
        case .endless: return "e"
        case .daily: return "d"
        case .zen: return "z"
        }
    }
}

struct Finish: Identifiable {
    let id = UUID()
    var mode: PlayMode
    var stars: Int
    var score: Int
    var perfects: Int
    var avg: Double
    var rounds: Int
    var bestCombo: Int
    var errors: [Double]
    var coins = 0
    var newBest = false
}

struct Verdict: Equatable {
    var main: String
    var sub: String
    var grade: Grade
    var points: Int
}

struct Spark {
    var p: CGPoint
    var v: CGVector
    var age: Double
    var life: Double
    var size: CGFloat
    var color: Color
}

/// قطعة بعد الشقّ: الشكل بإحداثيّات النموذج + إزاحة ودوران حول مركزها
struct Flyer {
    var shape: Shape
    var pivot: P
    var off = P.zero
    var vel = P.zero
    var rot = 0.0
    var spin = 0.0
    var fall = false
    var alpha = 1.0
    var born = 0.0
    var label: String? = nil
    var good = true

    init(_ s: Shape, vel: P = .zero, spin: Double = 0, fall: Bool = false, born: Double = 0) {
        shape = s; pivot = s.centroid; self.vel = vel; self.spin = spin; self.fall = fall; self.born = born
    }
    func map(_ p: P) -> P { (p - pivot).rotated(rot) + pivot + off }
    var world: Shape { shape.mapped { self.map($0) } }
    var center: P { pivot + off }
}

struct Popup {
    var text: String
    var color: Color
    var born: Double
    var y: CGFloat
    var size: CGFloat
}

struct TrailPt {
    var p: CGPoint
    var t: Double
}

struct Flash {
    var a: CGPoint
    var b: CGPoint
    var born: Double
}

/// محرّك اللعبة: الجولات، الشقّ، الفيزياء البصريّة، النقاط
final class Arena: ObservableObject {
    enum Phase { case aim, settle }

    let mode: PlayMode
    let level: Level?
    let seed: UInt64

    @Published var roundIndex = 0
    @Published var score = 0
    @Published var combo = 0
    @Published var lives = 3
    @Published var cutsLeft = 1
    @Published var verdict: Verdict? = nil
    @Published var finish: Finish? = nil
    @Published var paused = false
    @Published var hint = ""
    @Published var goalText = ""

    private(set) var round: Round
    private(set) var base: Shape
    var phase: Phase = .aim
    var errors: [Double] = []
    var perfects = 0
    var maxCombo = 0
    var haptics = true
    var onRound: ((Double, Grade) -> Void)? = nil

    // المحاكاة
    var simT = 0.0
    var roundT0 = 0.0
    private var lastReal: Double? = nil
    var slowUntil = 0.0
    var shake = 0.0
    var cutDone = false
    var flyers: [Flyer] = []
    var sparks: [Spark] = []
    var popups: [Popup] = []
    var trail: [TrailPt] = []
    var flash: Flash? = nil
    var size = CGSize(width: 390, height: 700)
    var freezeAt: Double? = nil
    /// ساعة ثابتة للّقطات (حتى الأثر والنصوص ما تختفي)
    var shotClock: Double? = nil
    private var timedOut = false
    private var lastTick = -1
    private var swishPlayed = false
    private var rng = SRng(1)

    init(mode: PlayMode, seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        self.mode = mode
        self.seed = seed
        var lv: Level? = nil
        var r0: Round
        switch mode {
        case .campaign(let id):
            let l = Levels.level(id); lv = l; r0 = l.rounds[0]
        case .daily:
            let t = Prog.today
            let l = Levels.daily(t.0, t.1, t.2); lv = l; r0 = l.rounds[0]
        case .endless:
            r0 = Levels.endless(0, seed: seed)
        case .zen:
            r0 = Levels.zen(0, seed: seed)
        }
        level = lv
        round = r0
        base = r0.shape
        rng = SRng(seed &+ 17)
        start(r0)
    }

    var totalRounds: Int? { level?.rounds.count }

    // MARK: الإحداثيّات

    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height * 0.5) }
    var R: CGFloat { min(size.width, size.height) * 0.33 }
    func toView(_ p: P) -> CGPoint { CGPoint(x: center.x + CGFloat(p.x) * R, y: center.y + CGFloat(p.y) * R) }
    func toModel(_ c: CGPoint) -> P { P(Double((c.x - center.x) / R), Double((c.y - center.y) / R)) }

    var localT: Double { simT - roundT0 }
    func placedNow() -> Shape {
        let t = localT, m = round.motion
        return base.placed(scale: m.scale(t), angle: m.angle(t), offset: m.offset(t))
    }
    var remaining: Double? {
        guard let lim = round.time else { return nil }
        return max(0, lim - localT)
    }

    // MARK: الجولة

    func start(_ r: Round) {
        round = r
        base = r.shape
        phase = .aim
        cutDone = false
        flyers = []
        timedOut = false
        lastTick = -1
        roundT0 = simT
        cutsLeft = r.goal.cuts
        goalText = r.goal.title
        if !r.nails.isEmpty { hint = "مرّر الشفرة من بين المسامير" }
        else if case .equal = r.goal { hint = "قطعتان — خلّ القطع متساوية" }
        else if mode == .campaign(0) && roundIndex == 0 { hint = "اسحب خطًّا مستقيمًا عبر الشكل" }
        else if r.time != nil { hint = "بسرعة! الوقت يمشي" }
        else { hint = "" }
    }

    private func nextRound() {
        guard finish == nil else { return }
        verdict = nil
        switch mode {
        case .campaign, .daily:
            guard let l = level else { return }
            if roundIndex + 1 >= l.rounds.count { finishGame(); return }
            roundIndex += 1
            start(l.rounds[roundIndex])
        case .endless:
            if lives <= 0 { finishGame(); return }
            roundIndex += 1
            start(Levels.endless(roundIndex, seed: seed))
        case .zen:
            roundIndex += 1
            start(Levels.zen(roundIndex, seed: seed))
        }
    }

    func finishGame() {
        let avg = errors.isEmpty ? 0 : errors.reduce(0, +) / Double(errors.count)
        let st: Int
        switch mode {
        case .campaign: st = Scoring.stars(errors)
        case .daily: st = Scoring.stars(errors)
        case .endless, .zen: st = 0
        }
        if st > 0 || mode == .endless || mode == .daily { Synth.shared.play("win") }
        finish = Finish(mode: mode, stars: st, score: score, perfects: perfects, avg: avg, rounds: errors.count, bestCombo: maxCombo, errors: errors)
    }

    // MARK: الفريم

    func frame(_ now: Double) {
        guard let last = lastReal else { lastReal = now; return }
        var dt = min(1.0 / 20, max(0, now - last))
        lastReal = now
        if paused || finish != nil { dt = 0 }
        let k = now < slowUntil ? 0.22 : 1.0
        var sdt = dt * k
        if let f = freezeAt { sdt = max(0, min(sdt, f - simT)) }
        simT += sdt

        for i in flyers.indices {
            var f = flyers[i]
            f.off = f.off + f.vel * sdt
            if f.fall {
                f.vel = f.vel + P(0, 3.2 * sdt)
                if simT - f.born > 0.55 { f.alpha = max(0, f.alpha - sdt * 1.4) }
            } else {
                f.vel = f.vel * pow(0.02, sdt)
                f.spin = f.spin * pow(0.03, sdt)
            }
            f.rot += f.spin * sdt
            flyers[i] = f
        }
        flyers.removeAll { $0.fall && $0.alpha <= 0 }

        for i in sparks.indices {
            var s = sparks[i]
            s.age += sdt
            s.p.x += s.v.dx * CGFloat(sdt)
            s.p.y += s.v.dy * CGFloat(sdt)
            s.v.dy += 620 * CGFloat(sdt)
            s.v.dx *= CGFloat(pow(0.3, sdt))
            sparks[i] = s
        }
        sparks.removeAll { $0.age >= $0.life }
        shake *= pow(0.002, dt)
        if freezeAt == nil {
            trail.removeAll { now - $0.t > 0.24 }
            popups.removeAll { now - $0.born > 1.5 }
            if let f = flash, now - f.born > 0.5 { flash = nil }
        }

        if phase == .aim, !cutDone || cutsLeft > 0, let lim = round.time, freezeAt == nil, finish == nil, !paused {
            let left = lim - localT
            let sec = Int(ceil(left))
            if left <= 3, sec != lastTick, sec > 0 { lastTick = sec; Synth.shared.play("tick", 0.8) }
            if left <= 0, !timedOut {
                timedOut = true
                DispatchQueue.main.async { [weak self] in self?.timeUp() }
            }
        }
    }

    // MARK: السحب

    func drag(_ p: CGPoint, from s: CGPoint) {
        let now = Date().timeIntervalSinceReferenceDate
        if trail.isEmpty { trail.append(TrailPt(p: s, t: now)) }
        trail.append(TrailPt(p: p, t: now))
        if trail.count > 60 { trail.removeFirst(trail.count - 60) }
        let dx = p.x - s.x, dy = p.y - s.y
        if !swishPlayed && dx * dx + dy * dy > 900 { swishPlayed = true; Synth.shared.play("swish", 0.7) }
    }

    func release(_ a: CGPoint, _ b: CGPoint) {
        swishPlayed = false
        let dx = b.x - a.x, dy = b.y - a.y
        guard dx * dx + dy * dy > 45 * 45 else { return }
        guard phase == .aim, finish == nil, !paused else { return }
        cut(Line(toModel(a), toModel(b)))
    }

    private func buzz(_ k: Int) {
        guard haptics, !Shot.on else { return }
        switch k {
        case 0: Haptic.tap()
        case 1: Haptic.thud()
        case 2: Haptic.ok()
        default: Haptic.bad()
        }
    }

    /// شقّ بخطّ (بإحداثيّات النموذج)
    func cut(_ L: Line) {
        let now = Date().timeIntervalSinceReferenceDate
        let va = toView(L.at(-6)), vb = toView(L.at(6))
        if let ni = Judge.hitsNail(L, round.nails) {
            flash = Flash(a: va, b: vb, born: now)
            nailHit(ni)
            return
        }
        if !cutDone {
            let s = placedNow()
            let r = Cutter.split(s, by: L)
            guard r.crossed else { hint = "الخطّ لازم يعبر الشكل"; buzz(0); return }
            flash = Flash(a: va, b: vb, born: now)
            cutDone = true
            burst(s, L, 34, SQ.amber)
            if round.goal.cuts == 1 {
                resolvePercent(r, L)
            } else {
                var fl: [Flyer] = []
                for p in r.plus { fl.append(Flyer(p, vel: L.normal * 0.24, spin: rng.range(-0.15, 0.15), born: simT)) }
                for p in r.minus { fl.append(Flyer(p, vel: L.normal * -0.24, spin: rng.range(-0.15, 0.15), born: simT)) }
                flyers = fl
                cutsLeft = 1
                hint = "باقي قطعة وحدة"
                Synth.shared.play("slice")
                buzz(1)
                shake = max(shake, 3)
            }
        } else {
            var out: [Flyer] = []
            var any = false
            for f in flyers {
                let w = f.world
                let r = Cutter.split(w, by: L)
                if r.crossed {
                    any = true
                    for p in r.plus { out.append(Flyer(p, vel: L.normal * 0.3, spin: rng.range(-0.3, 0.3), born: simT)) }
                    for p in r.minus { out.append(Flyer(p, vel: L.normal * -0.3, spin: rng.range(-0.3, 0.3), born: simT)) }
                    burst(w, L, 22, SQ.amber)
                } else {
                    out.append(Flyer(w, born: simT))
                }
            }
            guard any else { hint = "الخطّ لازم يعبر القطع"; buzz(0); return }
            flash = Flash(a: va, b: vb, born: now)
            flyers = out
            cutsLeft = 0
            resolveEqual()
        }
    }

    private func resolvePercent(_ r: CutResult, _ L: Line) {
        guard case .percent(let target) = round.goal else { return }
        let pct = Judge.smallerPercent(r)
        let e = Judge.error(percent: pct, target: target)
        let plusSmall = r.plusArea <= r.minusArea
        let n = L.normal
        let small: [Shape] = plusSmall ? r.plus : r.minus
        let bigP: [Shape] = plusSmall ? r.minus : r.plus
        let away = plusSmall ? n : n * -1
        var fl: [Flyer] = []
        for (i, s) in small.enumerated() {
            var f = Flyer(s, vel: away * 0.9 + P(0, -0.9), spin: rng.sign() * rng.range(1.2, 2.6), fall: true, born: simT)
            if i == 0 { f.label = pctText(pct) }
            f.good = false
            fl.append(f)
        }
        let biggest = bigP.indices.max { bigP[$0].area < bigP[$1].area } ?? 0
        for (i, s) in bigP.enumerated() {
            var f = Flyer(s, vel: away * -0.22, spin: rng.range(-0.25, 0.25), born: simT)
            if i == biggest { f.label = pctText(100 - pct) }
            fl.append(f)
        }
        flyers = fl
        let main = pctText(pct)
        conclude(e, main: main, sub: "الهدف \(target)%")
    }

    private func resolveEqual() {
        guard case .equal(let n) = round.goal else { return }
        let shapes = flyers.map { $0.shape }
        let e = Judge.equalError(shapes, n: n)
        let pcts = Judge.percents(shapes)
        let tot = shapes.reduce(0.0) { $0 + $1.area }
        var cx = 0.0, cy = 0.0
        for s in shapes { let c = s.centroid; cx += c.x * s.area; cy += c.y * s.area }
        let mid = tot > 0 ? P(cx / tot, cy / tot) : P.zero
        for i in flyers.indices {
            let dir = (flyers[i].pivot - mid).unit
            flyers[i].vel = flyers[i].vel + dir * 0.45
            flyers[i].label = pctText(pcts[i])
        }
        let main = shapes.count == n ? pcts.map { String(Int($0.rounded())) }.joined(separator: " · ") : "\(shapes.count) قطع!"
        conclude(e, main: main, sub: shapes.count == n ? "أكبر فرق ±\(String(format: "%.1f", e))%" : "المطلوب \(n) قطع")
    }

    private func pctText(_ v: Double) -> String { String(format: "%.1f%%", v) }

    private func nailHit(_ i: Int) {
        guard i < round.nails.count else { return }
        let c = toView(round.nails[i].p)
        for _ in 0..<26 {
            let a = rng.range(0, 2 * Double.pi), sp = rng.range(120, 420)
            sparks.append(Spark(p: c, v: CGVector(dx: CGFloat(cos(a) * sp), dy: CGFloat(sin(a) * sp)), age: 0, life: rng.range(0.3, 0.7), size: CGFloat(rng.range(2, 4.5)), color: Color.white))
        }
        Synth.shared.play("nail")
        shatter()
        conclude(25, main: "لمست مسمار!", sub: "مرّر الشفرة من الفتحة")
    }

    private func timeUp() {
        guard phase == .aim, finish == nil else { return }
        shatter()
        conclude(25, main: "خلص الوقت!", sub: "اقطع أسرع المرّة الجاية")
    }

    private func shatter() {
        let pieces: [Shape] = cutDone ? flyers.map { $0.world } : [placedNow()]
        cutDone = true
        var fl: [Flyer] = []
        for s in pieces {
            var f = Flyer(s, vel: P(rng.range(-0.3, 0.3), -0.5), spin: rng.range(-1.5, 1.5), fall: true, born: simT)
            f.good = false
            fl.append(f)
        }
        flyers = fl
    }

    private func conclude(_ e: Double, main: String, sub: String) {
        let now = Date().timeIntervalSinceReferenceDate
        phase = .settle
        hint = ""
        let g = Grade.of(e)
        errors.append(e)
        onRound?(e, g)
        var pts = 0
        if mode != .zen {
            combo = Scoring.nextCombo(combo, g)
            maxCombo = max(maxCombo, combo)
            pts = Scoring.points(e, combo: combo)
            score += pts
        }
        switch g {
        case .perfect:
            perfects += 1
            slowUntil = now + 0.85
            shake = max(shake, 7)
            Synth.shared.play("perfect")
            buzz(2)
            goldBurst()
        case .great, .good:
            shake = max(shake, 3)
            Synth.shared.play(g == .great ? "good" : "slice")
            buzz(1)
        case .ok:
            Synth.shared.play("slice", 0.7)
            buzz(1)
        case .miss:
            shake = max(shake, 11)
            Synth.shared.play("miss")
            buzz(3)
            if mode == .endless { lives = max(0, lives - 1) }
        }
        popups.append(Popup(text: g.title, color: SQ.grade(g), born: now, y: -0.62, size: g == .perfect ? 46 : 36))
        if mode != .zen, let label = Scoring.comboLabel(combo) {
            popups.append(Popup(text: label, color: SQ.coral, born: now + 0.25, y: -0.40, size: 30))
            Synth.shared.play("combo", 0.8)
        }
        verdict = Verdict(main: main, sub: sub, grade: g, points: pts)
        guard !Shot.on else { return }
        let delay = g == .perfect ? 1.9 : 1.4
        let idx = roundIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.roundIndex == idx, self.phase == .settle else { return }
            if self.paused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.resumeLater(idx) }
                return
            }
            self.nextRound()
        }
    }

    private func resumeLater(_ idx: Int) {
        guard roundIndex == idx, phase == .settle else { return }
        if paused {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.resumeLater(idx) }
            return
        }
        nextRound()
    }

    // MARK: الشرر

    private func burst(_ s: Shape, _ L: Line, _ count: Int, _ color: Color) {
        let pts = Cutter.chord(s, L, samples: 80)
        guard !pts.isEmpty else { return }
        let n = L.normal
        for _ in 0..<count {
            let p = toView(pts[rng.int(pts.count)])
            let side = rng.sign()
            let sp = rng.range(90, 380)
            let jitter = rng.range(-0.5, 0.5)
            let vx = (n.x * side + L.dir.x * jitter) * sp
            let vy = (n.y * side + L.dir.y * jitter) * sp - 60
            sparks.append(Spark(p: p, v: CGVector(dx: CGFloat(vx), dy: CGFloat(vy)), age: 0, life: rng.range(0.35, 0.8), size: CGFloat(rng.range(1.6, 3.6)), color: rng.chance(0.3) ? Color.white : color))
        }
    }

    private func goldBurst() {
        let c = center
        for _ in 0..<70 {
            let a = rng.range(0, 2 * Double.pi), sp = rng.range(160, 560)
            sparks.append(Spark(p: c, v: CGVector(dx: CGFloat(cos(a) * sp), dy: CGFloat(sin(a) * sp)), age: 0, life: rng.range(0.6, 1.2), size: CGFloat(rng.range(2, 5)), color: rng.chance(0.5) ? SQ.gold : Color.white))
        }
    }

    // MARK: لقطات الشاشة

    func prepareShot(_ name: String) {
        size = CGSize(width: 393, height: 852)
        lastReal = nil
        let base = Date().timeIntervalSinceReferenceDate
        shotClock = base
        switch name {
        case "play":
            if let l = level, l.rounds.count > 2 { roundIndex = 2; start(l.rounds[2]) }
            simT = 1.15; roundT0 = 0; freezeAt = 1.15
            score = 1840; combo = 4; maxCombo = 4
            let a = CGPoint(x: 40, y: 330), b = CGPoint(x: 250, y: 470)
            trail = (0...14).map { (i: Int) -> TrailPt in
                let u = CGFloat(i) / 14
                return TrailPt(p: CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u + sin(u * 3) * 6), t: base - 0.012 * Double(14 - i))
            }
        case "perfect":
            score = 2310; combo = 2
            if let l = level, l.rounds.count > 2 { roundIndex = 2; start(l.rounds[2]) }
            simT = 0.9; roundT0 = 0
            let s = placedNow()
            let L = Cutter.solve(s, angle: 2.2, fraction: targetFraction())
            cut(L)
            freezeAt = simT + 0.42
            if let f = flash { flash = Flash(a: f.a, b: f.b, born: base - 0.07) }
            for i in popups.indices { popups[i].born = base - 0.34 + Double(i) * 0.1 }
        case "result":
            score = 1975; perfects = 2; maxCombo = 3
            errors = [0.6, 1.4, 0.9]
            finish = Finish(mode: mode, stars: 3, score: 1975, perfects: 2, avg: 0.97, rounds: 3, bestCombo: 3, errors: errors)
        default:
            break
        }
    }

    private func targetFraction() -> Double {
        if case .percent(let p) = round.goal { return Double(p) / 100 + 0.002 }
        return 0.5
    }
}
