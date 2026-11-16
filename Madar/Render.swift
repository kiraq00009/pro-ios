import SwiftUI

/// تحويل إحداثيّات العالم للشاشة
struct View2D {
    let k: CGFloat
    let H: CGFloat
    let camY: Double
    let ox: CGFloat
    let oy: CGFloat
    func pt(_ w: V2) -> CGPoint {
        CGPoint(x: CGFloat(w.x) * k + ox, y: H - CGFloat(w.y - camY) * k + oy)
    }
    func s(_ d: Double) -> CGFloat { CGFloat(d) * k }
    func visible(_ y: Double, _ r: Double) -> Bool {
        let sy = H - CGFloat(y - camY) * k
        let rr = CGFloat(r) * k + 40
        return sy > -rr && sy < H + rr
    }
}

func circlePath(_ c: CGPoint, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}

func starPath(_ c: CGPoint, _ r: CGFloat, points: Int, inner: CGFloat, rot: Double) -> Path {
    var p = Path()
    let n = points * 2
    for i in 0..<n {
        let a = rot + Double(i) / Double(n) * 2 * Double.pi - Double.pi / 2
        let rr: CGFloat = i % 2 == 0 ? r : r * inner
        let q = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
    }
    p.closeSubpath()
    return p
}

func heartPath(_ c: CGPoint, _ r: CGFloat) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: c.x, y: c.y + r * 0.95))
    p.addCurve(to: CGPoint(x: c.x - r, y: c.y - r * 0.2), control1: CGPoint(x: c.x - r * 0.5, y: c.y + r * 0.6), control2: CGPoint(x: c.x - r, y: c.y + r * 0.25))
    p.addArc(center: CGPoint(x: c.x - r * 0.5, y: c.y - r * 0.25), radius: r * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
    p.addArc(center: CGPoint(x: c.x + r * 0.5, y: c.y - r * 0.25), radius: r * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
    p.addCurve(to: CGPoint(x: c.x, y: c.y + r * 0.95), control1: CGPoint(x: c.x + r, y: c.y + r * 0.25), control2: CGPoint(x: c.x + r * 0.5, y: c.y + r * 0.6))
    p.closeSubpath()
    return p
}

/// رسم المذنّب حسب الشكل — نستعمله باللعبة والمتجر
func drawComet(_ ctx: inout GraphicsContext, _ skin: CometSkin, at c: CGPoint, r: CGFloat, rot: Double, glow: Bool = true) {
    let core = col(skin.core)
    let gl = col(skin.glow)
    if glow {
        ctx.fill(circlePath(c, r * 3.4), with: .radialGradient(Gradient(colors: [gl.opacity(0.55), gl.opacity(0.18), gl.opacity(0)]), center: c, startRadius: 0, endRadius: r * 3.4))
    }
    let fillG = GraphicsContext.Shading.radialGradient(Gradient(colors: [Color.white, core, gl]), center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.5)
    switch skin.shape {
    case .orb:
        ctx.fill(circlePath(c, r), with: fillG)
    case .star:
        ctx.fill(starPath(c, r * 1.35, points: 5, inner: 0.48, rot: rot), with: fillG)
    case .diamond:
        ctx.fill(starPath(c, r * 1.3, points: 2, inner: 0.62, rot: rot * 0.5), with: fillG)
    case .ringed:
        ctx.fill(circlePath(c, r * 0.9), with: fillG)
        var e = Path(ellipseIn: CGRect(x: -r * 1.9, y: -r * 0.55, width: r * 3.8, height: r * 1.1))
        e = e.applying(CGAffineTransform(rotationAngle: CGFloat(-0.4)).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
        ctx.stroke(e, with: .color(gl), lineWidth: max(1.2, r * 0.32))
    case .spark:
        ctx.fill(starPath(c, r * 1.7, points: 4, inner: 0.3, rot: rot), with: fillG)
        ctx.fill(circlePath(c, r * 0.55), with: .color(Color.white))
    case .heart:
        ctx.fill(heartPath(c, r * 1.15), with: fillG)
    case .crescent:
        ctx.drawLayer { l in
            l.fill(circlePath(c, r * 1.1), with: fillG)
            l.blendMode = .destinationOut
            let off = CGPoint(x: c.x + CGFloat(cos(rot)) * r * 0.55, y: c.y + CGFloat(sin(rot)) * r * 0.55)
            l.fill(circlePath(off, r * 0.85), with: .color(Color.black))
        }
    case .cube:
        ctx.fill(starPath(c, r * 1.25, points: 4, inner: 0.7071, rot: rot + Double.pi / 4), with: fillG)
    }
}

extension Engine {
    func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let W = size.width, H = size.height
        let k = W / CGFloat(Level.width)
        let sx: CGFloat = shake > 0 ? CGFloat(sin(clock * 83) * shake * 9) : 0
        let sy: CGFloat = shake > 0 ? CGFloat(cos(clock * 71) * shake * 9) : 0
        let v = View2D(k: k, H: H, camY: camY, ox: sx, oy: sy)
        drawSky(&ctx, W, H)
        drawStars(&ctx, W, H, sx, sy)
        drawHoles(&ctx, v)
        drawWorms(&ctx, v)
        drawPlanets(&ctx, v)
        drawGems(&ctx, v)
        drawGuide(&ctx, v)
        drawTrail(&ctx, v)
        drawRipples(&ctx, v)
        drawParticles(&ctx, v)
        if sim.alive {
            let r = v.s(Sim.cometR) * 1.05
            drawComet(&ctx, comet, at: v.pt(sim.pos), r: r, rot: clock * 2.2)
        }
        drawTexts(&ctx, v)
        if flash > 0 {
            ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .color(col(flashColor, min(0.55, flash * 0.5))))
        }
        let vg = Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0), Color.black.opacity(0.5)])
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .radialGradient(vg, center: CGPoint(x: W / 2, y: H / 2), startRadius: 0, endRadius: max(W, H) * 0.75))
    }

    private func drawSky(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat) {
        let rect = Path(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.fill(rect, with: .linearGradient(Gradient(colors: [col(skyA), col(skyB)]), startPoint: CGPoint(x: W / 2, y: 0), endPoint: CGPoint(x: W / 2, y: H)))
        let neb = col(skyN)
        let span = H * 1.8
        for i in 0..<3 {
            let fi = CGFloat(i)
            let base = fi * span / 3
            var y = (base + CGFloat(camY) * W / CGFloat(Level.width) * 0.12).truncatingRemainder(dividingBy: span)
            if y < 0 { y += span }
            y -= H * 0.4
            let x = W * (i == 1 ? 0.15 : (i == 2 ? 0.85 : 0.55)) + CGFloat(sin(clock * 0.1 + Double(i))) * 20
            let r = W * (0.55 + 0.12 * fi)
            let c = CGPoint(x: x, y: y)
            ctx.fill(circlePath(c, r), with: .radialGradient(Gradient(colors: [neb.opacity(0.17 - 0.03 * Double(i)), neb.opacity(0)]), center: c, startRadius: 0, endRadius: r))
        }
    }

    private func drawStars(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ sx: CGFloat, _ sy: CGFloat) {
        let tile = H + 40
        let k = W / CGFloat(Level.width)
        let factors: [CGFloat] = [0.05, 0.14, 0.3]
        for s in stars {
            let f = factors[s.layer]
            var y = (CGFloat(s.y) * tile + CGFloat(camY) * k * f).truncatingRemainder(dividingBy: tile)
            if y < 0 { y += tile }
            y -= 20
            let x = CGFloat(s.x) * W + sx * f
            let tw = 0.35 + 0.65 * abs(sin(clock * (0.8 + Double(s.layer) * 0.5) + s.tw))
            let r = CGFloat(s.size) * (1 + CGFloat(s.layer) * 0.25)
            ctx.fill(circlePath(CGPoint(x: x, y: y + sy * f), r), with: .color(Color.white.opacity(tw * (0.45 + 0.2 * Double(s.layer)))))
        }
    }

    private func drawPlanets(_ ctx: inout GraphicsContext, _ v: View2D) {
        let ps = sim.level.planets
        let lo = max(0, sim.from - 4)
        let hi = min(ps.count - 1, sim.from + 8)
        guard lo <= hi else { return }
        for i in lo...hi {
            let p = ps[i]
            guard v.visible(p.base.y, p.reach + p.amp) else { continue }
            drawPlanet(&ctx, v, p, i)
        }
    }

    private func drawPlanet(_ ctx: inout GraphicsContext, _ v: View2D, _ p: Planet, _ i: Int) {
        let t = sim.t
        let c = v.pt(p.center(t))
        let isOrbit = sim.orbiting == i
        let R = v.s(isOrbit ? sim.ring(i) : p.ringR)
        let body = v.s(p.bodyR)
        let hue = Color(hue: p.hue, saturation: 0.6, brightness: 1)
        let passed = i < sim.from || (i == sim.from && !isOrbit)
        let fade: Double = passed ? 0.45 : 1

        if p.moving {
            let y = c.y
            var track = Path()
            track.move(to: CGPoint(x: v.s(p.base.x - p.amp) + v.ox, y: y))
            track.addLine(to: CGPoint(x: v.s(p.base.x + p.amp) + v.ox, y: y))
            ctx.stroke(track, with: .color(Color.white.opacity(0.07)), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
        }
        // منطقة المسك
        let band = v.s(p.ringR + Sim.captureTol)
        if !passed {
            ctx.fill(circlePath(c, band), with: .radialGradient(Gradient(stops: [
                .init(color: hue.opacity(0), location: 0),
                .init(color: hue.opacity(0), location: 0.62),
                .init(color: hue.opacity(0.09), location: 0.86),
                .init(color: hue.opacity(0), location: 1),
            ]), center: c, startRadius: 0, endRadius: band))
        }
        // الحلقة
        let danger = p.shrinking
        let ringCol: Color = danger ? Color(red: 1, green: 0.5, blue: 0.35) : (isOrbit ? MD.cyan : Color.white)
        let ringOp: Double = isOrbit ? 0.85 : 0.38
        ctx.stroke(circlePath(c, R), with: .color(ringCol.opacity(ringOp * fade)), style: StrokeStyle(lineWidth: isOrbit ? 2.2 : 1.5, lineCap: .round, dash: [5, 7], dashPhase: CGFloat(clock * 16 * p.spin)))
        if isOrbit, let left = sim.shrinkLeft {
            let full = max(0.01, (p.ringR - p.bodyR - Sim.cometR - 2) / max(0.01, p.shrink))
            let frac = max(0, min(1, left / full))
            var arc = Path()
            arc.addArc(center: c, radius: R + 7, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * frac), clockwise: false)
            let pulse = left < 1.2 ? 0.55 + 0.45 * abs(sin(clock * 12)) : 0.8
            ctx.stroke(arc, with: .color(MD.red.opacity(pulse)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        // هالة
        ctx.fill(circlePath(c, body * 2.7), with: .radialGradient(Gradient(colors: [hue.opacity(0.32 * fade), hue.opacity(0)]), center: c, startRadius: body * 0.6, endRadius: body * 2.7))
        // الجسم
        let light = Color(hue: p.hue, saturation: 0.35, brightness: 1)
        let mid = Color(hue: p.hue, saturation: 0.7, brightness: 0.78)
        let dark = Color(hue: p.hue, saturation: 0.9, brightness: 0.25)
        ctx.fill(circlePath(c, body), with: .radialGradient(Gradient(colors: [light, mid, dark]), center: CGPoint(x: c.x - body * 0.35, y: c.y - body * 0.4), startRadius: 0, endRadius: body * 1.55))
        if p.id % 3 == 2 {
            for q in 0..<3 {
                let a = Double(q) * 2.1 + Double(p.id)
                let cc = CGPoint(x: c.x + CGFloat(cos(a)) * body * 0.5, y: c.y + CGFloat(sin(a)) * body * 0.45)
                ctx.fill(circlePath(cc, body * (0.16 + 0.05 * CGFloat(q))), with: .color(Color.black.opacity(0.18)))
            }
        } else if p.id % 3 == 0 && p.id > 0 {
            var bands = Path()
            bands.addRect(CGRect(x: c.x - body, y: c.y - body * 0.18, width: body * 2, height: body * 0.16))
            bands.addRect(CGRect(x: c.x - body, y: c.y + body * 0.25, width: body * 2, height: body * 0.1))
            ctx.drawLayer { l in
                l.clip(to: circlePath(c, body))
                l.fill(bands, with: .color(Color.white.opacity(0.14)))
            }
        }
        if p.id % 3 == 1 {
            var e = Path(ellipseIn: CGRect(x: -body * 1.75, y: -body * 0.42, width: body * 3.5, height: body * 0.84))
            e = e.applying(CGAffineTransform(rotationAngle: CGFloat(-0.35)).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
            ctx.stroke(e, with: .color(light.opacity(0.55 * fade)), lineWidth: max(1.5, body * 0.14))
        }
        // الأقمار
        for m in 0..<p.moons.count {
            let mp = v.pt(p.moonPos(m, t))
            let mr = v.s(p.moons[m].r)
            ctx.stroke(circlePath(c, v.s(p.moons[m].dist)), with: .color(MD.red.opacity(0.07)), lineWidth: 1)
            ctx.fill(circlePath(mp, mr * 2.6), with: .radialGradient(Gradient(colors: [MD.red.opacity(0.4), MD.red.opacity(0)]), center: mp, startRadius: 0, endRadius: mr * 2.6))
            ctx.fill(circlePath(mp, mr), with: .radialGradient(Gradient(colors: [Color(white: 0.95), Color(white: 0.55), Color(white: 0.2)]), center: CGPoint(x: mp.x - mr * 0.3, y: mp.y - mr * 0.3), startRadius: 0, endRadius: mr * 1.4))
        }
    }

    private func drawHoles(_ ctx: inout GraphicsContext, _ v: View2D) {
        for h in sim.level.holes where v.visible(h.pos.y, h.reach) {
            let c = v.pt(h.pos)
            let r = v.s(h.horizon)
            let reach = v.s(h.reach)
            ctx.stroke(circlePath(c, reach), with: .color(MD.violet.opacity(0.06)), style: StrokeStyle(lineWidth: 1, dash: [3, 8], dashPhase: CGFloat(-clock * 10)))
            ctx.fill(circlePath(c, r * 7), with: .radialGradient(Gradient(stops: [
                .init(color: Color.black, location: 0),
                .init(color: Color.black.opacity(0.9), location: 0.16),
                .init(color: MD.violet.opacity(0.28), location: 0.24),
                .init(color: MD.magenta.opacity(0.08), location: 0.5),
                .init(color: Color.clear, location: 1),
            ]), center: c, startRadius: 0, endRadius: r * 7))
            let disc = Gradient(colors: [Color(red: 1, green: 0.7, blue: 0.3), MD.magenta, Color.clear, Color(red: 1, green: 0.7, blue: 0.3).opacity(0.6), Color.clear, Color(red: 1, green: 0.7, blue: 0.3)])
            var e = Path(ellipseIn: CGRect(x: -r * 2.3, y: -r * 0.75, width: r * 4.6, height: r * 1.5))
            e = e.applying(CGAffineTransform(rotationAngle: CGFloat(0.3)).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
            ctx.stroke(e, with: .conicGradient(disc, center: c, angle: .radians(clock * 2.4)), lineWidth: r * 0.55)
            ctx.stroke(circlePath(c, r * 1.25), with: .conicGradient(disc, center: c, angle: .radians(-clock * 3)), lineWidth: r * 0.3)
            ctx.fill(circlePath(c, r), with: .color(Color.black))
        }
    }

    private func drawWorms(_ ctx: inout GraphicsContext, _ v: View2D) {
        for w in sim.level.worms {
            if v.visible(w.a.y, w.r * 3) {
                let c = v.pt(w.a)
                let r = v.s(w.r)
                ctx.fill(circlePath(c, r * 2.6), with: .radialGradient(Gradient(colors: [MD.violet.opacity(0.45), MD.cyan.opacity(0.12), Color.clear]), center: c, startRadius: 0, endRadius: r * 2.6))
                let g = Gradient(colors: [MD.cyan, MD.violet, MD.magenta, Color.clear, MD.cyan])
                for q in 0..<3 {
                    let fr = 1 - CGFloat(q) * 0.28
                    ctx.stroke(circlePath(c, r * fr), with: .conicGradient(g, center: c, angle: .radians(clock * (2 + Double(q)) * (q % 2 == 0 ? 1 : -1))), lineWidth: 2.4 - CGFloat(q) * 0.5)
                }
                ctx.fill(circlePath(c, r * 0.3), with: .color(Color.white.opacity(0.9)))
            }
            if v.visible(w.b.y, w.r * 3) {
                let c = v.pt(w.b)
                let r = v.s(w.r) * 0.8
                ctx.fill(circlePath(c, r * 2), with: .radialGradient(Gradient(colors: [MD.cyan.opacity(0.3), Color.clear]), center: c, startRadius: 0, endRadius: r * 2))
                ctx.stroke(circlePath(c, r), with: .color(MD.cyan.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4], dashPhase: CGFloat(clock * 12)))
            }
        }
    }

    private func drawGems(_ ctx: inout GraphicsContext, _ v: View2D) {
        for g in sim.level.gems where !sim.taken.contains(g.id) && v.visible(g.pos.y, 20) {
            let bob = sin(clock * 3 + Double(g.id)) * 2.5
            let c = v.pt(g.pos + V2(0, bob))
            let r = v.s(g.big ? 9 : 6)
            let base: Color = g.big ? MD.cyan : MD.gold
            ctx.fill(circlePath(c, r * 2.4), with: .radialGradient(Gradient(colors: [base.opacity(0.45), base.opacity(0)]), center: c, startRadius: 0, endRadius: r * 2.4))
            let d = starPath(c, r, points: 2, inner: 0.62, rot: sin(clock * 2 + Double(g.id)) * 0.3)
            ctx.fill(d, with: .linearGradient(Gradient(colors: [Color.white, base]), startPoint: CGPoint(x: c.x, y: c.y - r), endPoint: CGPoint(x: c.x, y: c.y + r)))
            ctx.stroke(d, with: .color(Color.white.opacity(0.7)), lineWidth: 0.8)
        }
    }

    private func drawGuide(_ ctx: inout GraphicsContext, _ v: View2D) {
        guard guide, sim.alive, sim.orbiting != nil, phase != .over, sim.maxPlanet < 6 || phase == .ready else { return }
        let u = Aim.tangent(sim.angle, dir: sim.dir)
        let a = v.pt(sim.pos)
        let b = v.pt(sim.pos + u * 150)
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        ctx.stroke(path, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0)]), startPoint: a, endPoint: b), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))
    }

    private func drawTrail(_ ctx: inout GraphicsContext, _ v: View2D) {
        let n = trailPts.count
        guard n > 2, sim.alive else { return }
        let w0 = v.s(Sim.cometR) * 1.7
        let cs = trail.colors
        ctx.drawLayer { l in
            l.blendMode = .plusLighter
            for i in 1..<n {
                let f = CGFloat(i) / CGFloat(n)
                var seg = Path()
                seg.move(to: v.pt(trailPts[i - 1]))
                seg.addLine(to: v.pt(trailPts[i]))
                let ci = ((n - i) / 7 + Int(clock * 6)) % max(1, cs.count)
                l.stroke(seg, with: .color(col(cs[ci], Double(f) * 0.85)), style: StrokeStyle(lineWidth: max(0.6, w0 * f), lineCap: .round))
            }
        }
    }

    private func drawRipples(_ ctx: inout GraphicsContext, _ v: View2D) {
        for r in ripples {
            let c = v.pt(r.p)
            let rr = v.s(r.r0 + r.age * 70)
            ctx.stroke(circlePath(c, rr), with: .color(col(r.c, max(0, 1 - r.age / 0.8) * 0.8)), lineWidth: CGFloat(r.width * (1 - r.age / 0.8)) + 0.5)
        }
    }

    private func drawParticles(_ ctx: inout GraphicsContext, _ v: View2D) {
        guard !parts.isEmpty else { return }
        ctx.drawLayer { l in
            l.blendMode = .plusLighter
            for p in parts {
                let a = max(0, 1 - p.life / p.max)
                let r = CGFloat(p.size) * (0.5 + 0.5 * CGFloat(a)) * v.k
                l.fill(circlePath(v.pt(p.p), r), with: .color(col(p.c, a)))
            }
        }
    }

    private func drawTexts(_ ctx: inout GraphicsContext, _ v: View2D) {
        for t in texts {
            let a = t.age < 0.9 ? 1 : max(0, 1 - (t.age - 0.9) / 0.4)
            let pop: Double = t.age < 0.12 ? 0.7 + t.age / 0.12 * 0.45 : (t.age < 0.22 ? 1.15 - (t.age - 0.12) / 0.1 * 0.15 : 1)
            let txt = Text(t.text).font(rnd(CGFloat(t.size * pop), .black)).foregroundColor(col(t.c, a))
            let p = v.pt(t.p)
            ctx.draw(Text(t.text).font(rnd(CGFloat(t.size * pop), .black)).foregroundColor(Color.black.opacity(0.45 * a)), at: CGPoint(x: p.x + 1.5, y: p.y + 2), anchor: .center)
            ctx.draw(txt, at: p, anchor: .center)
        }
    }
}
