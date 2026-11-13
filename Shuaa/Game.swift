import SwiftUI

struct GameView: View {
    let stage: Stage
    let go: (Stage?) -> Void
    @EnvironmentObject var prog: Saved
    @State private var base: BeamLevel? = nil          // المرحلة مثل ما بدت
    @State private var level: BeamLevel? = nil         // وضعها الحاليّ
    @State private var taps = 0
    @State private var hints = 0
    @State private var hint: Int? = nil
    @State private var won = false

    private var index: Int? { if case .level(let i) = stage { return i }; return nil }
    private var title: String { index.map { "المرحلة \($0 + 1)" } ?? "لغز اليوم" }
    private var stars: Int {
        guard let b = base else { return 3 }
        if hints > 0 { return 1 }
        return taps <= b.par ? 3 : (taps <= b.par + 2 ? 2 : 1)
    }

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 14) {
                HStack {
                    Button { go(nil) } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color.white).frame(width: 42, height: 42).background(SU.s2, in: Circle()) }.buttonStyle(Press())
                    Spacer()
                    VStack(spacing: 1) {
                        Text(title).font(rnd(19, .black)).foregroundStyle(Color.white)
                        if let b = base { Text("الضغطات \(taps) · الأفضل \(b.par)").font(rnd(12.5, .heavy)).foregroundStyle(SU.tx3) }
                    }
                    Spacer()
                    HStack(spacing: 2) { ForEach(0..<3, id: \.self) { k in Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(k < stars ? SU.gold : SU.s3) } }.frame(width: 42, height: 42)
                }.padding(.horizontal, 18).padding(.top, 8)

                if let l = level {
                    let tr = Beam.trace(l)
                    Spacer(minLength: 0)
                    BeamBoard(level: l, trace: tr, hint: hint, tap: tap).padding(.horizontal, 18)
                    HStack(spacing: 8) {
                        ForEach(0..<Beam.targets(l), id: \.self) { k in Circle().fill(k < tr.lit.count ? SU.pink : SU.s3).frame(width: 12, height: 12).shadow(color: k < tr.lit.count ? SU.pink : .clear, radius: 6) }
                        Text("\(tr.lit.count) / \(Beam.targets(l)) هدف").font(rnd(14, .heavy)).foregroundStyle(SU.tx2)
                    }.frame(height: 24)
                    Spacer(minLength: 0)
                    HStack(spacing: 10) {
                        tool("arrow.counterclockwise", "من الأوّل", taps > 0) { restart() }
                        tool("lightbulb.fill", "تلميح", true, tint: SU.gold) { showHint(l) }
                    }.padding(.horizontal, 18).padding(.bottom, 10)
                } else {
                    Spacer()
                    ProgressView().tint(SU.beam).scaleEffect(1.4)
                    Text("دا نجهّز المرحلة…").font(rnd(14)).foregroundStyle(SU.tx3)
                    Spacer()
                }
            }
            if won { WinOverlay(stars: stars, title: title, taps: taps, par: base?.par ?? 0, last: index == Beam.total - 1 || index == nil) { next() } home: { go(nil) } again: { restart() } }
        }
        .task(id: stage) { await load() }
    }

    private func load() async {
        level = nil; base = nil; won = false
        let l: BeamLevel
        if let i = index { l = await prog.level(i) } else { l = await prog.daily() }
        base = l; level = l; taps = 0; hints = 0; hint = nil
        guard Shot.on else { return }
        if Shot.name == "hint", let s = Beam.solve(l) { hint = s.which.first; hints = 1 }
        if Shot.name == "win", let s = Beam.solve(l) { var c = l; for m in s.which { c = Beam.flipped(c, at: m) }; level = c; taps = s.flips; won = true }
    }
    private func tap(_ i: Int) {
        guard let l = level, !won else { return }
        guard Beam.movable(l.tiles[i]) else { if Beam.isMirror(l.tiles[i]) { Haptic.bad() }; return }
        Haptic.thud(); hint = nil; taps += 1
        let n = Beam.flipped(l, at: i)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { level = n }
        if Beam.solved(n) {
            Haptic.ok()
            if let idx = index { prog.win(idx, stars) } else { prog.winDaily() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { won = true } }
        }
    }
    private func restart() { Haptic.tap(); withAnimation { level = base }; taps = 0; hint = nil; won = false }
    private func showHint(_ l: BeamLevel) {
        hints += 1; Haptic.tap()
        if let s = Beam.solve(l), let m = s.which.first { withAnimation { hint = m } }
    }
    private func next() { if let i = index, i + 1 < Beam.total { go(.level(i + 1)) } else { go(nil) } }
    private func tool(_ icon: String, _ t: String, _ on: Bool, tint: Color = Color.white, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 18, weight: .bold)); Text(t).font(rnd(12, .heavy)) }
                .foregroundStyle(tint).frame(maxWidth: .infinity).frame(height: 60).background(SU.s2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(Press()).disabled(!on).opacity(on ? 1 : 0.35)
    }
}

/// اللوحة: الخانات + المرايا + الشعاع المضوّي
struct BeamBoard: View {
    let level: BeamLevel; let trace: Trace; let hint: Int?
    let tap: (Int) -> Void
    @State private var pulse = false

    var body: some View {
        GeometryReader { g in
            let gap: CGFloat = 4
            let side = min((g.size.width - gap * CGFloat(level.w - 1)) / CGFloat(level.w), (g.size.height - gap * CGFloat(level.h - 1)) / CGFloat(level.h))
            let bw = side * CGFloat(level.w) + gap * CGFloat(level.w - 1), bh = side * CGFloat(level.h) + gap * CGFloat(level.h - 1)
            let ox = (g.size.width - bw) / 2, oy = (g.size.height - bh) / 2
            ZStack(alignment: .topLeading) {
                ForEach(0..<level.count, id: \.self) { i in
                    let cx = ox + CGFloat(i % level.w) * (side + gap) + side / 2, cy = oy + CGFloat(i / level.w) * (side + gap) + side / 2
                    BeamCell(tile: level.tiles[i], side: side, source: i == level.src, dir: level.dir, lit: trace.lit.contains(i), hinted: hint == i, pulse: pulse)
                        .frame(width: side, height: side).onTapGesture { tap(i) }
                        .position(x: cx, y: cy)
                }
                Canvas { ctx, _ in
                    func center(_ c: Int) -> CGPoint { CGPoint(x: ox + CGFloat(c % level.w) * (side + gap) + side / 2, y: oy + CGFloat(c / level.w) * (side + gap) + side / 2) }
                    var p = Path()
                    for (k, c) in trace.cells.enumerated() { if k == 0 { p.move(to: center(c)) } else { p.addLine(to: center(c)) } }
                    // آخر قطعة: يكمّل لحافّة اللوحة أو للجدار
                    if trace.cells.count >= 1, !trace.loop, let last = trace.cells.last {
                        var d = level.dir
                        if trace.cells.count >= 2 {
                            let a = trace.cells[trace.cells.count - 2]
                            let ddx = last % level.w - a % level.w, ddy = last / level.w - a / level.w
                            d = ddx > 0 ? 0 : (ddx < 0 ? 2 : (ddy > 0 ? 1 : 3))
                            let t = level.tiles[last]
                            if Beam.isMirror(t) { d = Beam.reflect(d, slash: t == .mirrorA || t == .fixedA) }
                        }
                        let c = center(last)
                        p.addLine(to: CGPoint(x: c.x + CGFloat(Beam.dx[d]) * (side / 2 + gap), y: c.y + CGFloat(Beam.dy[d]) * (side / 2 + gap)))
                    }
                    let lw = max(3, side * 0.09)
                    ctx.stroke(p, with: .color(SU.beam.opacity(0.22)), style: StrokeStyle(lineWidth: lw * 3.2, lineCap: .round, lineJoin: .round))
                    ctx.stroke(p, with: .color(SU.beam.opacity(0.55)), style: StrokeStyle(lineWidth: lw * 1.7, lineCap: .round, lineJoin: .round))
                    ctx.stroke(p, with: .color(Color.white), style: StrokeStyle(lineWidth: lw * 0.55, lineCap: .round, lineJoin: .round))
                }.allowsHitTesting(false)
            }
        }
        .aspectRatio(CGFloat(level.w) / CGFloat(level.h), contentMode: .fit)
        .environment(\.layoutDirection, .leftToRight)
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

struct BeamCell: View {
    let tile: Tile; let side: CGFloat; let source: Bool; let dir: Int; let lit: Bool; let hinted: Bool; let pulse: Bool
    var body: some View {
        let r = side * 0.2
        let slash = tile == .mirrorA || tile == .fixedA
        let movable = tile == .mirrorA || tile == .mirrorB
        ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous).fill(tile == .wall ? SU.s3 : SU.s1)
            RoundedRectangle(cornerRadius: r, style: .continuous).stroke(Color(white: 1, opacity: tile == .wall ? 0.16 : 0.05))
            if tile == .wall { Image(systemName: "xmark").font(.system(size: side * 0.3, weight: .black)).foregroundStyle(Color(white: 1, opacity: 0.18)) }
            if tile == .target {
                Circle().stroke(lit ? SU.pink : SU.pink.opacity(0.5), lineWidth: max(2.5, side * 0.07)).frame(width: side * 0.56, height: side * 0.56)
                Circle().fill(lit ? SU.pink : SU.pink.opacity(0.18)).frame(width: side * (lit ? 0.34 : 0.2), height: side * (lit ? 0.34 : 0.2)).shadow(color: lit ? SU.pink : .clear, radius: 10)
            }
            if Beam.isMirror(tile) {
                if movable { RoundedRectangle(cornerRadius: r, style: .continuous).fill(Color.white.opacity(0.06)) }
                Capsule().fill(movable ? Color.white : Color(white: 0.5)).frame(width: side * 0.86, height: max(4, side * 0.12))
                    .shadow(color: movable ? Color.white.opacity(0.5) : .clear, radius: 5)
                    .rotationEffect(.degrees(slash ? -45 : 45))
            }
            if source {
                Circle().fill(SU.beam).frame(width: side * 0.46, height: side * 0.46).shadow(color: SU.beam, radius: 10)
                Image(systemName: "bolt.fill").font(.system(size: side * 0.24, weight: .black)).foregroundStyle(Color.black.opacity(0.75))
            }
            if hinted { RoundedRectangle(cornerRadius: r, style: .continuous).stroke(SU.gold, lineWidth: max(3.5, side * 0.09)).scaleEffect(pulse ? 1.07 : 0.98) }
        }
        .contentShape(Rectangle())
    }
}

struct WinOverlay: View {
    let stars: Int; let title: String; let taps: Int; let par: Int; let last: Bool
    let next: () -> Void
    let home: () -> Void
    let again: () -> Void
    @State private var shown = 0
    var body: some View {
        ZStack {
            Color.black.opacity(0.74).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(stars == 3 ? "مثاليّ!" : (stars == 2 ? "حلو!" : "خلصت!")).font(rnd(40, .black)).foregroundStyle(Color.white)
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { k in
                        Image(systemName: "star.fill").font(.system(size: 50)).foregroundStyle(k < stars ? SU.gold : SU.s3)
                            .scaleEffect(k < shown ? 1 : 0.2).opacity(k < shown ? 1 : 0).shadow(color: k < stars ? SU.gold.opacity(0.6) : .clear, radius: 14)
                    }
                }.environment(\.layoutDirection, .leftToRight)
                Text(title + " · \(taps) ضغطة (الأفضل \(par))").font(rnd(14.5, .heavy)).foregroundStyle(SU.tx2)
                if stars < 3 { Text("حلّها بـ\(par) ضغطات وبلا تلميح حتى تاخذ الثلاث نجوم.").font(rnd(12.5)).foregroundStyle(SU.tx3) }
                Button(action: next) { Text(last ? "رجوع للقائمة" : "المرحلة الجاية").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.8)).frame(width: 240, height: 56).background(SU.beam, in: Capsule()) }.buttonStyle(Press()).padding(.top, 6)
                HStack(spacing: 22) {
                    Button(action: again) { Label("عيدها", systemImage: "arrow.counterclockwise").font(rnd(14.5, .heavy)).foregroundStyle(SU.tx2) }.buttonStyle(.plain)
                    if !last { Button(action: home) { Label("القائمة", systemImage: "square.grid.2x2.fill").font(rnd(14.5, .heavy)).foregroundStyle(SU.tx2) }.buttonStyle(.plain) }
                }
            }
        }
        .onAppear {
            if Shot.on { shown = 3; return }
            for k in 1...3 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(k)) { withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { shown = k }; if k <= stars { Haptic.thud() } } }
        }
    }
}
