import SwiftUI

@main
struct ShaqApp: App {
    @StateObject private var prog = Prog()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(prog)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(SQ.coral)
        }
    }
}

struct Launch: Identifiable {
    let id = UUID()
    let mode: PlayMode
}

enum HomeSheet: String, Identifiable {
    case shop, stats, settings, intro
    var id: String { rawValue }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            SQ.bg
            RadialGradient(colors: [SQ.coral.opacity(0.22), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [SQ.violet.opacity(0.16), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 480)
        }.ignoresSafeArea()
    }
}

/// شعار متحرّك: شكل منشقّ نصّين يتباعدون ويرجعون، والشفرة تلمع بينهم
struct LogoSplit: View {
    static let halves: CutResult = Cutter.split(ShapeLib.make(.hexagon, seed: 1, vary: false).placed(scale: 1, angle: 0.3, offset: .zero), by: Line(angle: -0.45, offset: 0.16))
    let size: CGFloat

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, sz in
                let t = Shot.on ? 1.0 : tl.date.timeIntervalSinceReferenceDate
                draw(&ctx, sz, t)
            }
        }
        .frame(width: size, height: size)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func draw(_ ctx: inout GraphicsContext, _ sz: CGSize, _ t: Double) {
        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
        let R = min(sz.width, sz.height) * 0.36
        let L = Line(angle: -0.45, offset: 0.16)
        let sep = 0.07 + 0.06 * (0.5 + 0.5 * sin(t * 1.7))
        let sides: [(shapes: [Shape], k: Double, a: Color, b: Color)] = [
            (shapes: LogoSplit.halves.plus, k: 1, a: SQ.coral, b: SQ.amber),
            (shapes: LogoSplit.halves.minus, k: -1, a: SQ.amber, b: SQ.coral),
        ]
        for side in sides {
            let d = L.normal * (sep * side.k)
            for s in side.shapes {
                let p = Painter.path(s) { q in CGPoint(x: c.x + CGFloat(q.x + d.x) * R, y: c.y + CGFloat(q.y + d.y) * R) }
                var g = ctx
                g.addFilter(.shadow(color: side.a.opacity(0.6), radius: 18))
                g.fill(p, with: .linearGradient(Gradient(colors: [side.a, side.b]), startPoint: CGPoint(x: c.x - R, y: c.y - R), endPoint: CGPoint(x: c.x + R, y: c.y + R)))
                ctx.stroke(p, with: .color(Color.white.opacity(0.7)), lineWidth: 1.5)
            }
        }
        let a = L.at(-1.5), b = L.at(1.5)
        var line = Path()
        line.move(to: CGPoint(x: c.x + CGFloat(a.x) * R, y: c.y + CGFloat(a.y) * R))
        line.addLine(to: CGPoint(x: c.x + CGFloat(b.x) * R, y: c.y + CGFloat(b.y) * R))
        var glow = ctx
        glow.blendMode = .plusLighter
        glow.addFilter(.blur(radius: 5))
        let shine = 0.45 + 0.4 * (0.5 + 0.5 * sin(t * 1.7 + 1.5))
        glow.stroke(line, with: .color(Color.white.opacity(shine)), lineWidth: 6)
        ctx.stroke(line, with: .color(Color.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [6, 5]))
    }
}
