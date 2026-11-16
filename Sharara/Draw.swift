import SwiftUI

/// ألوان أنواع الكرات
enum Look {
    static func rgb(_ k: OrbKind) -> RGB {
        switch k {
        case .normal: return RGB(0.36, 0.86, 1.0)
        case .big: return RGB(0.70, 0.46, 1.0)
        case .bouncer: return RGB(0.56, 1.0, 0.45)
        case .shield: return RGB(0.78, 0.88, 1.0)
        case .splitter: return RGB(1.0, 0.40, 0.70)
        case .magnet: return RGB(1.0, 0.42, 0.26)
        case .timer: return RGB(1.0, 0.85, 0.30)
        case .bad: return RGB(0.95, 0.12, 0.22)
        }
    }
    static func color(_ k: OrbKind, _ o: Double = 1) -> Color { ST.c(rgb(k), o) }

    /// تدوير اللون على عجلة الألوان (لتغيّر الألوان مع السلسلة الطويلة)
    static func shifted(_ c: RGB, _ shift: Double, _ o: Double = 1) -> Color {
        if abs(shift) < 0.001 { return ST.c(c, o) }
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b)
        let d = mx - mn
        var h = 0.0
        if d > 0.0001 {
            if mx == c.r { h = ((c.g - c.b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == c.g { h = (c.b - c.r) / d + 2 }
            else { h = (c.r - c.g) / d + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        let s = mx <= 0 ? 0 : d / mx
        var nh = (h + shift).truncatingRemainder(dividingBy: 1)
        if nh < 0 { nh += 1 }
        return Color(hue: nh, saturation: s, brightness: mx).opacity(o)
    }
}

/// تحويل إحداثيّات الساحة (٤٠٠×٧٢٠) للشاشة
struct Fit {
    let s: CGFloat
    let ox: CGFloat
    let oy: CGFloat
    init(size: CGSize, top: CGFloat, bottom: CGFloat) {
        let aw = max(10, size.width - 14)
        let ah = max(10, size.height - top - bottom)
        s = min(aw / CGFloat(Tune.W), ah / CGFloat(Tune.H))
        ox = (size.width - CGFloat(Tune.W) * s) / 2
        oy = top + (ah - CGFloat(Tune.H) * s) / 2
    }
    func pt(_ p: P) -> CGPoint { CGPoint(x: ox + CGFloat(p.x) * s, y: oy + CGFloat(p.y) * s) }
    func world(_ c: CGPoint) -> P { P(Double((c.x - ox) / s), Double((c.y - oy) / s)) }
    func len(_ d: Double) -> CGFloat { CGFloat(d) * s }
    var rect: CGRect { CGRect(x: ox, y: oy, width: CGFloat(Tune.W) * s, height: CGFloat(Tune.H) * s) }
}

/// نجمة بالخلفيّة
struct StarDot {
    let x: Double
    let y: Double
    let size: Double
    let tw: Double
}

enum Painter {
    static let starField: [StarDot] = {
        var r = SRNG(4242)
        var out: [StarDot] = []
        for _ in 0..<260 { out.append(StarDot(x: r.unit(), y: r.unit(), size: r.range(0.5, 1.9), tw: r.range(0, 6.28))) }
        return out
    }()

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func glow(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ col: Color, _ o: Double) {
        g.fill(circle(c, r), with: .radialGradient(Gradient(colors: [col.opacity(o), col.opacity(0)]), center: c, startRadius: 0, endRadius: r))
    }

    // MARK: الخلفيّة

    static func background(_ g: GraphicsContext, _ size: CGSize, _ b: BackSkin, t: Double, shift: Double) {
        let full = CGRect(origin: .zero, size: size)
        g.fill(Path(full), with: .linearGradient(Gradient(colors: [ST.c(b.top), ST.c(b.bottom)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let acc = Look.shifted(b.accent, shift)
        let w = size.width, h = size.height
        let a = CGPoint(x: w * (0.25 + 0.06 * CGFloat(sin(t * 0.13))), y: h * 0.22)
        let c2 = CGPoint(x: w * (0.8 + 0.05 * CGFloat(cos(t * 0.11))), y: h * 0.7)
        glow(g, a, w * 0.85, acc, 0.22)
        glow(g, c2, w * 0.7, ST.pink, 0.10)
        if b.id == "aurora" {
            for k in 0..<3 {
                var p = Path()
                let yb = h * (0.18 + 0.1 * CGFloat(k))
                p.move(to: CGPoint(x: 0, y: yb))
                var x: CGFloat = 0
                while x <= w {
                    let yy = yb + 26 * CGFloat(sin(Double(x) / 60 + t * 0.4 + Double(k)))
                    p.addLine(to: CGPoint(x: x, y: yy))
                    x += 12
                }
                g.stroke(p, with: .color(acc.opacity(0.10)), style: StrokeStyle(lineWidth: 34, lineCap: .round))
            }
        }
        if b.id == "synth" {
            let hz = h * 0.78
            for i in 0..<9 {
                let f = CGFloat(i) / 8
                var p = Path()
                p.move(to: CGPoint(x: w * f, y: hz))
                p.addLine(to: CGPoint(x: w * 0.5 + (w * f - w * 0.5) * 3.2, y: h))
                g.stroke(p, with: .color(acc.opacity(0.18)), lineWidth: 1)
            }
            for j in 0..<6 {
                let q = (Double(j) + (t * 0.35).truncatingRemainder(dividingBy: 1)) / 6
                let y = hz + (h - hz) * CGFloat(q * q)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                g.stroke(p, with: .color(acc.opacity(0.16)), lineWidth: 1)
            }
        }
        if b.id == "dusk" {
            glow(g, CGPoint(x: w * 0.5, y: h * 1.02), w * 0.9, ST.c(RGB(1, 0.5, 0.2)), 0.3)
        }
        let n = min(b.stars, starField.count)
        for i in 0..<n {
            let s = starField[i]
            let tw = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 1.3 + s.tw))
            let c = CGPoint(x: CGFloat(s.x) * w, y: CGFloat(s.y) * h)
            g.fill(circle(c, CGFloat(s.size) * 0.8), with: .color(Color.white.opacity(0.55 * tw)))
        }
    }

    // MARK: الكرة

    static func orb(_ g: GraphicsContext, _ o: Orb, at c: CGPoint, s: CGFloat, t: Double) {
        let col = Look.color(o.kind)
        let pulse = 1 + 0.06 * CGFloat(sin(t * 3 + o.phase))
        let r = CGFloat(o.r) * s * pulse
        var add = g
        add.blendMode = .plusLighter
        glow(add, c, r * 2.7, col, o.kind == .bad ? 0.28 : 0.42)
        if o.kind == .bouncer {
            let v = o.vel
            let L = max(1, v.len)
            for k in 1...3 {
                let off = CGFloat(k) * r * 0.55
                let tc = CGPoint(x: c.x - CGFloat(v.x / L) * off, y: c.y - CGFloat(v.y / L) * off)
                add.fill(circle(tc, r * (1 - 0.2 * CGFloat(k))), with: .color(col.opacity(0.16 / Double(k))))
            }
        }
        if o.kind == .bad {
            badBody(g, c, r, t: t)
        } else {
            g.fill(circle(c, r), with: .radialGradient(Gradient(colors: [Color.white, col, col.opacity(0.55)]),
                                                       center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35), startRadius: 0, endRadius: r * 1.25))
        }
        switch o.kind {
        case .normal:
            break
        case .big:
            g.stroke(circle(c, r * 0.62), with: .color(Color.white.opacity(0.55)), lineWidth: max(1, 1.6 * s))
            g.stroke(circle(c, r * 1.18), with: .color(col.opacity(0.6)), lineWidth: max(1, 1.2 * s))
        case .bouncer:
            break
        case .shield:
            if o.hp > 1 {
                g.stroke(hexagon(c, r * 1.42, rot: t * 0.6), with: .color(Color.white.opacity(0.85)), lineWidth: max(1.2, 2.2 * s))
                add.stroke(hexagon(c, r * 1.42, rot: t * 0.6), with: .color(ST.cyan.opacity(0.5)), lineWidth: max(2, 5 * s))
            } else {
                g.stroke(hexagon(c, r * 1.42, rot: t * 0.6), with: .color(Color.white.opacity(0.55)),
                         style: StrokeStyle(lineWidth: max(1, 1.6 * s), dash: [3 * s, 4 * s]))
            }
        case .splitter:
            for j in 0..<3 {
                let a = o.phase + Double(j) * 2.094 + t * 1.4
                let d = r * 1.55
                let p = CGPoint(x: c.x + CGFloat(cos(a)) * d, y: c.y + CGFloat(sin(a)) * d)
                g.fill(circle(p, max(1.2, 2.2 * s)), with: .color(Color.white))
                add.fill(circle(p, 5 * s), with: .color(col.opacity(0.5)))
            }
        case .magnet:
            var p = Path()
            p.addArc(center: c, radius: r * 1.35, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            g.stroke(p, with: .color(Color.white.opacity(0.75)), style: StrokeStyle(lineWidth: max(1.5, 2.4 * s), lineCap: .round))
            var q = Path()
            q.addArc(center: c, radius: r * 1.35, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            g.stroke(q, with: .color(col.opacity(0.9)), style: StrokeStyle(lineWidth: max(1.5, 2.4 * s), lineCap: .round))
            if o.state == .armed {
                for k in 0..<3 {
                    let f = 1 - (t * 1.6 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                    let rr = CGFloat(Tune.magnetRange) * s * CGFloat(f)
                    add.stroke(circle(c, rr), with: .color(col.opacity(0.35 * (1 - f) + 0.05)), lineWidth: max(1, 2 * s))
                }
            }
        case .timer:
            if o.state == .armed {
                let frac = max(0, min(1, o.fuse / Tune.timerT))
                var arc = Path()
                arc.addArc(center: c, radius: r * 1.45, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * frac), clockwise: false)
                g.stroke(arc, with: .color(Color.white), style: StrokeStyle(lineWidth: max(2, 3 * s), lineCap: .round))
                let blink = 0.5 + 0.5 * sin(t * (10 + (1 - frac) * 30))
                add.fill(circle(c, r * 1.6), with: .color(col.opacity(0.25 * blink)))
            } else {
                for k in 0..<4 {
                    let a = Double(k) * Double.pi / 2 + t * 0.8
                    let p1 = CGPoint(x: c.x + CGFloat(cos(a)) * r * 1.25, y: c.y + CGFloat(sin(a)) * r * 1.25)
                    let p2 = CGPoint(x: c.x + CGFloat(cos(a)) * r * 1.55, y: c.y + CGFloat(sin(a)) * r * 1.55)
                    var p = Path(); p.move(to: p1); p.addLine(to: p2)
                    g.stroke(p, with: .color(col.opacity(0.9)), style: StrokeStyle(lineWidth: max(1.2, 2 * s), lineCap: .round))
                }
            }
        case .bad:
            break
        }
    }

    static func hexagon(_ c: CGPoint, _ r: CGFloat, rot: Double) -> Path {
        var p = Path()
        for k in 0..<6 {
            let a = rot + Double(k) * Double.pi / 3
            let q = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            if k == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }

    static func badBody(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, t: Double) {
        var spikes = Path()
        let n = 10
        for k in 0..<(n * 2) {
            let a = t * 0.9 + Double(k) * Double.pi / Double(n)
            let rr = k % 2 == 0 ? r * 1.45 : r * 0.9
            let q = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            if k == 0 { spikes.move(to: q) } else { spikes.addLine(to: q) }
        }
        spikes.closeSubpath()
        g.fill(spikes, with: .color(ST.red.opacity(0.85)))
        g.fill(circle(c, r), with: .radialGradient(Gradient(colors: [Color(red: 0.25, green: 0.02, blue: 0.06), Color.black]),
                                                   center: c, startRadius: 0, endRadius: r))
        g.stroke(circle(c, r * 0.55), with: .color(ST.red.opacity(0.9)), lineWidth: max(1, r * 0.12))
    }

    // MARK: الانفجار

    static func blast(_ g: GraphicsContext, _ b: Blast, fit: Fit, col: Color, s: CGFloat) {
        let c = fit.pt(b.pos)
        let r = fit.len(b.r)
        if r < 0.5 { return }
        let a = b.alpha
        var add = g
        add.blendMode = .plusLighter
        add.fill(circle(c, r), with: .radialGradient(Gradient(colors: [col.opacity(0.05 * a), col.opacity(0.26 * a)]), center: c, startRadius: 0, endRadius: r))
        let lw = max(1.5, 3.2 * s) * CGFloat(0.5 + 0.5 * a)
        add.stroke(circle(CGPoint(x: c.x + 1.6, y: c.y), r), with: .color(Color(red: 1, green: 0.2, blue: 0.3).opacity(0.35 * a)), lineWidth: lw)
        add.stroke(circle(CGPoint(x: c.x - 1.6, y: c.y), r), with: .color(Color(red: 0.2, green: 0.8, blue: 1).opacity(0.35 * a)), lineWidth: lw)
        add.stroke(circle(c, r), with: .color(col.opacity(0.95 * a)), lineWidth: lw)
        add.stroke(circle(c, r), with: .color(Color.white.opacity(0.55 * a)), lineWidth: max(0.8, lw * 0.35))
        if b.age < 0.12 {
            let f = 1 - b.age / 0.12
            glow(add, c, fit.len(b.maxR) * 0.6, Color.white, 0.8 * f)
        }
    }

    // MARK: المشهد الكامل

    static func game(_ g0: GraphicsContext, size: CGSize, play: Play, fit: Fit) {
        var g = g0
        let t = play.clock
        background(g, size, play.back, t: t, shift: play.hueNow)
        if play.shock > 0.01 {
            g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(min(0.08, play.shock * 0.05))))
        }
        // اهتزاز + تموّج
        if play.shake > 0.05 {
            let k = CGFloat(play.calm ? play.shake * 0.3 : play.shake)
            g.translateBy(x: CGFloat(sin(t * 71)) * k, y: CGFloat(cos(t * 57)) * k)
        }
        if play.shock > 0.01 {
            let cx = size.width / 2, cy = size.height / 2
            let z = 1 + CGFloat(play.shock) * 0.012
            g.translateBy(x: cx, y: cy)
            g.scaleBy(x: z, y: z)
            g.translateBy(x: -cx, y: -cy)
        }
        let s = fit.s
        let arena = Path(roundedRect: fit.rect.insetBy(dx: -4, dy: -4), cornerRadius: 22)
        g.stroke(arena, with: .color(Color.white.opacity(0.07)), lineWidth: 1)

        // موجات زينة
        var add = g
        add.blendMode = .plusLighter
        for w in play.waves {
            let f = 1 - w.life / w.max
            let c = fit.pt(P(w.x, w.y))
            add.stroke(circle(c, fit.len(w.r * (0.3 + f * 1.4))), with: .color(ST.c(w.col, 0.5 * (1 - f))), lineWidth: max(1, 6 * s * CGFloat(1 - f)))
        }
        // الانفجارات
        for b in play.world.blasts {
            let base: RGB = b.source.map { Look.rgb($0) } ?? play.skin.glow
            var col = Look.shifted(base, play.hueNow)
            if play.skin.rainbow { col = Color(hue: (Double(b.gen) * 0.13 + t * 0.2).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 1) }
            else if b.source == nil { col = Look.shifted(play.skin.glow, play.hueNow) }
            blast(g, b, fit: fit, col: col, s: s)
        }
        // الكرات
        for o in play.world.orbs where o.state != .dead {
            orb(g, o, at: fit.pt(o.pos), s: s, t: t)
        }
        // الشرارات الطايرة
        for k in play.world.sparks {
            let c = fit.pt(k.pos)
            let tail = CGPoint(x: c.x - CGFloat(k.vel.x) * s * 0.06, y: c.y - CGFloat(k.vel.y) * s * 0.06)
            var p = Path(); p.move(to: tail); p.addLine(to: c)
            add.stroke(p, with: .color(Look.color(.splitter, 0.9)), style: StrokeStyle(lineWidth: 4 * s, lineCap: .round))
            add.fill(circle(c, 3.2 * s), with: .color(Color.white))
            glow(add, c, 14 * s, Look.color(.splitter), 0.7)
        }
        // جزيئات
        for p in play.parts {
            let a = max(0, p.life / p.max)
            let c = fit.pt(P(p.x, p.y))
            if p.streak {
                let tl = CGPoint(x: c.x - CGFloat(p.vx) * s * 0.035, y: c.y - CGFloat(p.vy) * s * 0.035)
                var path = Path(); path.move(to: tl); path.addLine(to: c)
                add.stroke(path, with: .color(ST.c(p.col, a)), style: StrokeStyle(lineWidth: CGFloat(p.size) * s, lineCap: .round))
            } else {
                add.fill(circle(c, CGFloat(p.size * (0.4 + 0.6 * a)) * s), with: .color(ST.c(p.col, a)))
            }
        }
        // التصويب
        if play.phase == .aim {
            if let h = play.hintTap { aimMark(add, fit.pt(h), fit.len(play.world.sparkMaxR), t: t, col: ST.gold) }
            if let a = play.aim { aimMark(add, fit.pt(a), fit.len(play.world.sparkMaxR), t: t, col: ST.c(play.skin.glow)) }
        }
        // نصوص طايرة
        for f in play.floaters {
            let a = min(1, f.life / 0.35)
            let c = fit.pt(P(f.x, f.y))
            var l = g
            l.opacity = a
            let fs: CGFloat = f.big ? 17 : 12.5
            l.draw(Text(f.text).font(rnd(fs, .black)).foregroundColor(ST.c(f.col)), at: c, anchor: .center)
        }
        chainHUD(g0, size: size, play: play, fit: fit)
    }

    static func aimMark(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat, t: Double, col: Color) {
        let pulse = 1 + 0.05 * CGFloat(sin(t * 6))
        g.stroke(circle(c, r * pulse), with: .color(col.opacity(0.85)), style: StrokeStyle(lineWidth: 2, dash: [6, 6], dashPhase: CGFloat(t * 20)))
        glow(g, c, r * 0.6, col, 0.35)
        for k in 0..<4 {
            let a = Double(k) * Double.pi / 2
            let p1 = CGPoint(x: c.x + CGFloat(cos(a)) * 8, y: c.y + CGFloat(sin(a)) * 8)
            let p2 = CGPoint(x: c.x + CGFloat(cos(a)) * 18, y: c.y + CGFloat(sin(a)) * 18)
            var p = Path(); p.move(to: p1); p.addLine(to: p2)
            g.stroke(p, with: .color(Color.white.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    static func chainHUD(_ g: GraphicsContext, size: CGSize, play: Play, fit: Fit) {
        let pops = play.world.pops
        if pops > 0 {
            let y = fit.oy + 54
            let z = 1 + CGFloat(play.chainPulse) * 0.28
            var l = g
            l.translateBy(x: size.width / 2, y: y)
            l.scaleBy(x: z, y: z)
            var gl = l
            gl.blendMode = .plusLighter
            glow(gl, .zero, 70, Look.shifted(play.skin.glow, play.hueNow), 0.35 * (0.4 + play.chainPulse))
            l.draw(Text("\(pops)").font(rnd(58, .black)).foregroundColor(Color.white), at: .zero, anchor: .center)
            let m = World.mult(max(1, pops))
            l.draw(Text("سلسلة  ×\(m)").font(rnd(15, .heavy)).foregroundColor(ST.gold), at: CGPoint(x: 0, y: 40), anchor: .center)
        }
        if play.tierLife > 0 && !play.tierText.isEmpty {
            let a = min(1, play.tierLife / 0.4)
            let k = 1.6 - play.tierLife
            let z = CGFloat(1.35 - min(0.35, k * 1.2))
            var l = g
            l.opacity = a
            l.translateBy(x: size.width / 2, y: size.height * 0.44)
            l.scaleBy(x: z, y: z)
            l.rotate(by: .degrees(-4))
            var gl = l
            gl.blendMode = .plusLighter
            glow(gl, .zero, 150, Look.shifted(RGB(1, 0.5, 0.2), play.hueNow), 0.45)
            l.draw(Text(play.tierText).font(rnd(50, .black)).foregroundColor(ST.gold), at: CGPoint(x: 2, y: 3), anchor: .center)
            l.draw(Text(play.tierText).font(rnd(50, .black)).foregroundColor(Color.white), at: .zero, anchor: .center)
        }
    }
}

/// كرة صغيرة للواجهات (الدليل والقوائم)
struct OrbIcon: View {
    let kind: OrbKind
    var size: CGFloat = 44
    var live = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || Shot.on)) { tl in
            Canvas { g, sz in
                let t = tl.date.timeIntervalSinceReferenceDate
                let s = sz.width / 56
                var o = Orb(id: 0, kind: kind, pos: P(0, 0), vel: P(30, -20), phase: 0.6)
                if kind == .timer { o.state = .alive }
                Painter.orb(g, o, at: CGPoint(x: sz.width / 2, y: sz.height / 2), s: s, t: t)
            }
        }
        .frame(width: size, height: size)
    }
}

/// خلفيّة الفضاء للقوائم
struct SpaceBackdrop: View {
    let back: BackSkin
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: Shot.on)) { tl in
            Canvas { g, size in
                let t = Shot.on ? 10 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10000)
                Painter.background(g, size, back, t: t, shift: 0)
                drift(g, size, t)
            }
        }
        .ignoresSafeArea()
    }

    private func drift(_ g: GraphicsContext, _ size: CGSize, _ t: Double) {
        var add = g
        add.blendMode = .plusLighter
        let kinds: [OrbKind] = [.normal, .big, .splitter, .timer, .normal, .bouncer, .magnet, .normal, .shield]
        for (i, k) in kinds.enumerated() {
            let f = Double(i)
            let x = (0.5 + 0.45 * sin(t * 0.05 * (1 + f * 0.13) + f * 2.1)) * Double(size.width)
            let y = (0.5 + 0.45 * cos(t * 0.04 * (1 + f * 0.09) + f * 1.3)) * Double(size.height)
            let c = CGPoint(x: x, y: y)
            Painter.glow(add, c, 34 + CGFloat(i % 3) * 10, Look.color(k), 0.22)
            add.fill(Painter.circle(c, 3 + CGFloat(i % 3)), with: .color(Look.color(k, 0.55)))
        }
    }
}
