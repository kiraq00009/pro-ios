import SwiftUI

/// رسم ساحة اللعب على Canvas: الأشكال، القطع، الشفرة، الشرر، النصوص
enum Painter {
    static func path(_ s: Shape, _ f: (P) -> CGPoint) -> Path {
        var p = Path()
        var rings: [Ring] = [s.outer]
        rings.append(contentsOf: s.holes)
        for ring in rings {
            guard let first = ring.first else { continue }
            p.move(to: f(first))
            for q in ring.dropFirst() { p.addLine(to: f(q)) }
            p.closeSubpath()
        }
        return p
    }

    static func frac(_ x: Double) -> Double { x - floor(x) }

    static func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ A: Arena, _ skin: Skin, _ blade: Blade, _ now: Double) {
        let clock = A.shotClock ?? now
        ambient(&ctx, size, skin, clock)
        var g = ctx
        if A.shake > 0.05 {
            let k = CGFloat(A.shake)
            g.translateBy(x: k * CGFloat(sin(clock * 91)), y: k * CGFloat(cos(clock * 77)))
        }
        timer(&g, A)
        nails(&g, A, clock)
        if !A.cutDone {
            shape(&g, A.placedNow(), A, skin, alpha: 1, dim: false)
        } else {
            for f in A.flyers { shape(&g, f.world, A, skin, alpha: f.alpha, dim: !f.good) }
            for f in A.flyers { if let l = f.label { label(&g, l, A.toView(f.center), alpha: f.alpha, good: f.good) } }
        }
        flash(&g, A, clock)
        trail(&g, A, blade, clock)
        sparks(&g, A)
        popups(&g, A, clock)
    }

    // خلفيّة: ذرّات تطفو ببطء + حلقة الهدف
    private static func ambient(_ ctx: inout GraphicsContext, _ size: CGSize, _ skin: Skin, _ t: Double) {
        var g = ctx
        g.blendMode = .plusLighter
        for i in 0..<34 {
            let fi = Double(i)
            let x = frac(sin(fi * 12.9898) * 43758.5453) * Double(size.width)
            let sp = 6 + frac(sin(fi * 78.233) * 12543.1) * 14
            let y = Double(size.height) - frac(frac(sin(fi * 4.123) * 9631.7) + t * sp / Double(max(1, size.height))) * Double(size.height)
            let r = 0.8 + frac(sin(fi * 3.7) * 311.3) * 1.8
            let a = 0.10 + 0.12 * (0.5 + 0.5 * sin(t * 1.3 + fi))
            let col = i % 3 == 0 ? skin.a : (i % 3 == 1 ? skin.b : Color.white)
            g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(col.opacity(a)))
        }
    }

    private static func timer(_ ctx: inout GraphicsContext, _ A: Arena) {
        guard let lim = A.round.time, lim > 0, let rem = A.remaining, A.phase == .aim, !A.cutDone || A.cutsLeft > 0 else { return }
        let f = rem / lim
        let c = A.center
        let r = A.R * 1.3
        var track = Path()
        track.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.stroke(track, with: .color(Color.white.opacity(0.06)), lineWidth: 5)
        var arc = Path()
        arc.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * f), clockwise: false)
        let col: Color = f > 0.5 ? SQ.mint : (f > 0.25 ? SQ.amber : SQ.red)
        var g = ctx
        g.addFilter(.shadow(color: col.opacity(0.7), radius: 8))
        g.stroke(arc, with: .color(col), style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }

    private static func nails(_ ctx: inout GraphicsContext, _ A: Arena, _ t: Double) {
        for (i, n) in A.round.nails.enumerated() {
            let c = A.toView(n.p)
            let r = CGFloat(n.r) * A.R
            let pulse = CGFloat(0.5 + 0.5 * sin(t * 4 + Double(i)))
            let rr = r * (1.7 + 0.3 * pulse)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(SQ.red.opacity(0.18 + 0.15 * Double(pulse))), lineWidth: 1.5)
            var g = ctx
            g.addFilter(.shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 2))
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            g.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [Color.white, Color(white: 0.62), Color(white: 0.28)]), center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.35), startRadius: 0, endRadius: r * 1.4))
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.35)), lineWidth: 1)
        }
    }

    private static func shape(_ ctx: inout GraphicsContext, _ s: Shape, _ A: Arena, _ skin: Skin, alpha: Double, dim: Bool) {
        guard alpha > 0.01 else { return }
        let p = path(s) { A.toView($0) }
        let c = A.toView(s.centroid)
        let R = A.R
        var g = ctx
        g.opacity = alpha
        var glow = g
        glow.addFilter(.shadow(color: skin.a.opacity(dim ? 0.25 : 0.55), radius: dim ? 10 : 24))
        let grad = Gradient(colors: dim ? [skin.a.opacity(0.75), skin.b.opacity(0.55)] : [skin.a, skin.b])
        glow.fill(p, with: .linearGradient(grad, startPoint: CGPoint(x: c.x - R, y: c.y - R), endPoint: CGPoint(x: c.x + R, y: c.y + R)), style: FillStyle(eoFill: true))
        // حافّة داخليّة مضيئة
        var inner = g
        inner.clip(to: p, style: FillStyle(eoFill: true))
        inner.stroke(p, with: .color(Color.white.opacity(0.22)), lineWidth: 9)
        inner.fill(Path(ellipseIn: CGRect(x: c.x - R * 0.9, y: c.y - R * 1.05, width: R * 1.2, height: R * 0.8)), with: .color(Color.white.opacity(0.06)))
        g.stroke(p, with: .color(Color.white.opacity(0.75)), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
    }

    private static func label(_ ctx: inout GraphicsContext, _ text: String, _ at: CGPoint, alpha: Double, good: Bool) {
        guard alpha > 0.05 else { return }
        var g = ctx
        g.opacity = alpha
        let t = g.resolve(Text(text).font(rnd(15, .black)).foregroundColor(Color.white))
        let sz = t.measure(in: CGSize(width: 220, height: 60))
        let rect = CGRect(x: at.x - sz.width / 2 - 10, y: at.y - sz.height / 2 - 5, width: sz.width + 20, height: sz.height + 10)
        g.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(Color.black.opacity(0.55)))
        g.stroke(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color((good ? Color.white : SQ.red).opacity(0.35)), lineWidth: 1)
        g.draw(t, at: at)
    }

    private static func flash(_ ctx: inout GraphicsContext, _ A: Arena, _ t: Double) {
        guard let f = A.flash else { return }
        let age = t - f.born
        guard age >= 0, age < 0.5 else { return }
        let a = 1 - age / 0.5
        var p = Path()
        p.move(to: f.a); p.addLine(to: f.b)
        var g = ctx
        g.blendMode = .plusLighter
        g.addFilter(.blur(radius: 6))
        g.stroke(p, with: .color(SQ.coral.opacity(0.55 * a)), lineWidth: 10)
        ctx.stroke(p, with: .color(Color.white.opacity(0.85 * a)), lineWidth: 1.6)
    }

    private static func trail(_ ctx: inout GraphicsContext, _ A: Arena, _ blade: Blade, _ t: Double) {
        let pts = A.trail
        guard pts.count >= 2, let last = pts.last else { return }
        let fade = max(0, min(1, 1 - (t - last.t) / 0.24))
        guard fade > 0.01 else { return }
        let n = pts.count
        var glow = ctx
        glow.blendMode = .plusLighter
        glow.addFilter(.blur(radius: 7))
        for i in 1..<n {
            let u = Double(i) / Double(n - 1)
            let age = t - pts[i].t
            let a = max(0, min(1, 1 - age / 0.24)) * fade
            guard a > 0.01 else { continue }
            var seg = Path()
            seg.move(to: pts[i - 1].p); seg.addLine(to: pts[i].p)
            let col: Color = blade.rainbow ? Color(hue: frac(t * 0.5 + u * 0.6), saturation: 0.85, brightness: 1) : (u > 0.5 ? blade.a : blade.b)
            let w = blade.width * CGFloat(0.25 + 0.75 * u)
            glow.stroke(seg, with: .color(col.opacity(0.7 * a)), style: StrokeStyle(lineWidth: w * 2.4, lineCap: .round))
            ctx.stroke(seg, with: .color(col.opacity(a)), style: StrokeStyle(lineWidth: w, lineCap: .round))
            ctx.stroke(seg, with: .color(Color.white.opacity(0.9 * a * u)), style: StrokeStyle(lineWidth: max(1, w * 0.3), lineCap: .round))
        }
    }

    private static func sparks(_ ctx: inout GraphicsContext, _ A: Arena) {
        guard !A.sparks.isEmpty else { return }
        var g = ctx
        g.blendMode = .plusLighter
        for s in A.sparks {
            let a = max(0, 1 - s.age / s.life)
            let r = s.size * CGFloat(0.5 + 0.5 * a)
            var streak = Path()
            streak.move(to: s.p)
            streak.addLine(to: CGPoint(x: s.p.x - s.v.dx * 0.025, y: s.p.y - s.v.dy * 0.025))
            g.stroke(streak, with: .color(s.color.opacity(a * 0.8)), style: StrokeStyle(lineWidth: r, lineCap: .round))
        }
    }

    private static func popups(_ ctx: inout GraphicsContext, _ A: Arena, _ t: Double) {
        for p in A.popups {
            let age = t - p.born
            guard age >= 0 else { continue }
            let s: CGFloat = age < 0.14 ? CGFloat(0.5 + age / 0.14 * 0.65) : CGFloat(1 + 0.15 * max(0, 1 - (age - 0.14) * 6))
            let a = age > 1.0 ? max(0, 1 - (age - 1.0) * 2) : 1
            guard a > 0.01 else { continue }
            var g = ctx
            g.opacity = a
            g.translateBy(x: A.center.x, y: A.center.y + A.R * p.y - CGFloat(age) * 18)
            g.scaleBy(x: s, y: s)
            g.addFilter(.shadow(color: p.color.opacity(0.85), radius: 16))
            g.draw(Text(p.text).font(rnd(p.size, .black)).foregroundColor(p.color), at: .zero)
        }
    }
}
