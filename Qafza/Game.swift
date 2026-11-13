import SwiftUI

struct GameView: View {
    let stage: Stage
    let go: (Stage?) -> Void
    @EnvironmentObject var prog: Saved
    @State private var level: Level? = nil
    @State private var path: [Int] = []
    @State private var undos = 0
    @State private var hints = 0
    @State private var hint: Int? = nil
    @State private var shake = 0
    @State private var won = false
    @State private var note = ""

    private var index: Int? { if case .level(let i) = stage { return i }; return nil }
    private var title: String { index.map { "المرحلة \($0 + 1)" } ?? "لغز اليوم" }
    private var stars: Int { hints > 0 ? 1 : (undos > 0 ? 2 : 3) }

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 14) {
                HStack {
                    Button { go(nil) } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color.white).frame(width: 42, height: 42).background(QF.s2, in: Circle()) }.buttonStyle(Press())
                    Spacer()
                    VStack(spacing: 1) {
                        Text(title).font(rnd(19, .black)).foregroundStyle(Color.white)
                        if let l = level { Text("\(path.count) / \(l.count)").font(rnd(12.5, .heavy)).foregroundStyle(QF.tx3).environment(\.layoutDirection, .leftToRight) }
                    }
                    Spacer()
                    HStack(spacing: 2) { ForEach(0..<3, id: \.self) { k in Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(k < stars ? QF.gold : QF.s3) } }.frame(width: 42, height: 42)
                }.padding(.horizontal, 18).padding(.top, 8)

                if let l = level {
                    Spacer(minLength: 0)
                    Board(level: l, path: path, hint: hint, tap: tap)
                        .modifier(Shake(amount: CGFloat(shake)))
                        .padding(.horizontal, 18)
                    Text(note.isEmpty ? " " : note).font(rnd(14.5, .heavy)).foregroundStyle(QF.gold).frame(height: 22)
                    Spacer(minLength: 0)
                    HStack(spacing: 10) {
                        tool("arrow.uturn.backward", "ارجع", path.count > 1) { undo() }
                        tool("arrow.counterclockwise", "من الأوّل", path.count > 1) { restart(l) }
                        tool("lightbulb.fill", "تلميح", true, tint: QF.gold) { showHint(l) }
                    }.padding(.horizontal, 18).padding(.bottom, 10)
                } else {
                    Spacer()
                    ProgressView().tint(QF.ac).scaleEffect(1.4)
                    Text("دا نجهّز المرحلة…").font(rnd(14)).foregroundStyle(QF.tx3)
                    Spacer()
                }
            }
            if won, let l = level { WinOverlay(stars: stars, title: title, moves: l.count, last: index == Hops.total - 1 || index == nil) { next() } home: { go(nil) } again: { restart(l) } }
        }
        .task(id: stage) { await load() }
    }

    private func load() async {
        level = nil; won = false; note = ""
        let l: Level
        if let i = index { l = await prog.level(i) } else { l = await prog.daily() }
        level = l; path = [l.start]; undos = 0; hints = 0; hint = nil
        guard Shot.on else { return }
        // لقطات الشاشة: نمشي جزء من الحلّ
        if Shot.name == "game" { path = Array(l.solution.prefix(7)) }
        if Shot.name == "hint" { path = Array(l.solution.prefix(5)); hint = l.solution[5]; hints = 1 }
        if Shot.name == "stuck" { path = Array(l.solution.prefix(4)); wander(l) }
        if Shot.name == "win" { path = l.solution; won = true }
    }
    /// (للّقطة فقط) نمشي حركات غلط لحدّ ما ننحصر
    private func wander(_ l: Level) {
        for _ in 0..<40 {
            var v = [Bool](repeating: false, count: l.count); for p in path { v[p] = true }
            let m = Hops.moves(l, visited: v, at: path.last!)
            guard let n = m.first(where: { !l.solution.contains($0) || l.solution.firstIndex(of: $0)! != path.count }) ?? m.first else { break }
            path.append(n)
            if Hops.complete(l, path: path) == nil { break }
        }
        var v = [Bool](repeating: false, count: l.count); for p in path { v[p] = true }
        if Hops.moves(l, visited: v, at: path.last!).isEmpty { note = "ماكو قفزة من هنا — ارجع خطوة" }
    }

    private func visited(_ l: Level) -> [Bool] { var v = [Bool](repeating: false, count: l.count); for p in path { v[p] = true }; return v }

    private func tap(_ cell: Int) {
        guard let l = level, !won, let cur = path.last else { return }
        if path.count >= 2, cell == path[path.count - 2] { undo(); return }            // ضغطة على المربّع السابق = رجوع
        guard Hops.moves(l, visited: visited(l), at: cur).contains(cell) else { Haptic.bad(); withAnimation(.default) { shake += 1 }; return }
        Haptic.thud(); hint = nil; note = ""
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { path.append(cell) }
        if path.count == l.count {
            Haptic.ok()
            if let i = index { prog.win(i, stars) } else { prog.winDaily() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { won = true } }
        } else if Hops.moves(l, visited: visited(l), at: cell).isEmpty {
            note = l.nums[cell] == 0 ? "وصلت النجمة قبل ما تخلّص — ارجع خطوة" : "ماكو قفزة من هنا — ارجع خطوة"
        }
    }
    private func undo() {
        guard path.count > 1 else { return }
        Haptic.tap(); undos += 1; hint = nil; note = ""
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { path.removeLast() }
    }
    private func restart(_ l: Level) {
        Haptic.tap(); hint = nil; note = ""; won = false
        if path.count > 1 { undos += 1 }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { path = [l.start] }
    }
    private func showHint(_ l: Level) {
        hints += 1; Haptic.tap()
        if let rest = Hops.complete(l, path: path), let n = rest.first { withAnimation { hint = n }; note = "اقفز على المربّع المضوّي" }
        else { hint = nil; note = "طريقك مسدود — ارجع خطوة وجرّب اتّجاه ثاني" }
    }
    private func next() {
        if let i = index, i + 1 < Hops.total { go(.level(i + 1)) } else { go(nil) }
    }
    private func tool(_ icon: String, _ t: String, _ on: Bool, tint: Color = Color.white, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 18, weight: .bold)); Text(t).font(rnd(12, .heavy)) }
                .foregroundStyle(tint).frame(maxWidth: .infinity).frame(height: 60).background(QF.s2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(Press()).disabled(!on).opacity(on ? 1 : 0.35)
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform { ProjectionTransform(CGAffineTransform(translationX: sin(amount * .pi * 4) * 8, y: 0)) }
}

/// لوحة اللعب: المربّعات + خطّ المسار
struct Board: View {
    let level: Level; let path: [Int]; let hint: Int?
    let tap: (Int) -> Void
    @State private var pulse = false

    var body: some View {
        let visited = Set(path), cur = path.last ?? level.start
        let reach: Set<Int> = {
            var v = [Bool](repeating: false, count: level.count); for p in path { v[p] = true }
            return Set(Hops.moves(level, visited: v, at: cur))
        }()
        GeometryReader { g in
            let gap: CGFloat = 8
            let side = min((g.size.width - gap * CGFloat(level.w - 1)) / CGFloat(level.w), (g.size.height - gap * CGFloat(level.h - 1)) / CGFloat(level.h))
            let bw = side * CGFloat(level.w) + gap * CGFloat(level.w - 1), bh = side * CGFloat(level.h) + gap * CGFloat(level.h - 1)
            let ox = (g.size.width - bw) / 2, oy = (g.size.height - bh) / 2
            ZStack(alignment: .topLeading) {
                ForEach(0..<level.count, id: \.self) { i in
                    let x = ox + CGFloat(i % level.w) * (side + gap), y = oy + CGFloat(i / level.w) * (side + gap)
                    Cell(n: level.nums[i], side: side, visited: visited.contains(i), current: i == cur, reachable: reach.contains(i), hinted: hint == i, order: path.firstIndex(of: i), pulse: pulse)
                        .frame(width: side, height: side).onTapGesture { tap(i) }
                        .position(x: x + side / 2, y: y + side / 2)
                }
                // خطّ المسار فوق المربّعات المزورة
                Canvas { ctx, _ in
                    guard path.count > 1 else { return }
                    var p = Path()
                    for (k, c) in path.enumerated() {
                        let pt = CGPoint(x: ox + CGFloat(c % level.w) * (side + gap) + side / 2, y: oy + CGFloat(c / level.w) * (side + gap) + side / 2)
                        if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                    ctx.stroke(p, with: .color(Color.white.opacity(0.28)), style: StrokeStyle(lineWidth: max(3, side * 0.07), lineCap: .round, lineJoin: .round))
                }.allowsHitTesting(false)
            }
        }
        .aspectRatio(CGFloat(level.w) / CGFloat(level.h), contentMode: .fit)
        .environment(\.layoutDirection, .leftToRight)
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

struct Cell: View {
    let n: Int; let side: CGFloat; let visited: Bool; let current: Bool; let reachable: Bool; let hinted: Bool; let order: Int?; let pulse: Bool
    var body: some View {
        let c = QF.tile(n), r = side * 0.24
        ZStack {
            if visited && !current {
                RoundedRectangle(cornerRadius: r, style: .continuous).fill(QF.s1)
                RoundedRectangle(cornerRadius: r, style: .continuous).stroke(Color(white: 1, opacity: 0.06))
                if let o = order { Text("\(o + 1)").font(rnd(side * 0.2, .heavy)).foregroundStyle(QF.tx3.opacity(0.6)) }
            } else {
                RoundedRectangle(cornerRadius: r, style: .continuous).fill(LinearGradient(colors: [c, c.opacity(0.72)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: c.opacity(current ? 0.7 : 0.25), radius: current ? 14 : 5, y: current ? 0 : 3)
                Text(n == 0 ? "★" : "\(n)").font(rnd(side * (n == 0 ? 0.46 : 0.44), .black)).foregroundStyle(Color.black.opacity(0.72))
                if current { RoundedRectangle(cornerRadius: r, style: .continuous).stroke(Color.white, lineWidth: max(3, side * 0.06)) }
            }
            if reachable { RoundedRectangle(cornerRadius: r, style: .continuous).stroke(Color.white.opacity(pulse ? 0.95 : 0.35), style: StrokeStyle(lineWidth: max(2.5, side * 0.045), dash: [side * 0.12, side * 0.09])) }
            if hinted { RoundedRectangle(cornerRadius: r, style: .continuous).stroke(QF.gold, lineWidth: max(4, side * 0.09)).scaleEffect(pulse ? 1.08 : 0.98) }
        }
        .scaleEffect(current ? 1.06 : (visited ? 0.94 : 1))
        .opacity(!visited && !reachable && !current ? 0.82 : 1)
        .contentShape(Rectangle())
    }
}

struct WinOverlay: View {
    let stars: Int; let title: String; let moves: Int; let last: Bool
    let next: () -> Void
    let home: () -> Void
    let again: () -> Void
    @State private var start = Date()
    @State private var shown = 0
    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(start)
                    for i in 0..<80 {
                        let f = Double(i)
                        let x = abs((sin(f * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1))
                        let y = (t - abs(sin(f * 1.3)) * 2) * (130 + abs(sin(f * 3.7)) * 170)
                        guard y > 0 else { continue }
                        var p = Path(roundedRect: CGRect(x: -4, y: -7, width: 8, height: 14), cornerRadius: 2)
                        p = p.applying(CGAffineTransform(rotationAngle: CGFloat(t * 3 + f)).concatenating(CGAffineTransform(translationX: CGFloat(x) * size.width + CGFloat(sin(t * 2 + f)) * 16, y: CGFloat(y.truncatingRemainder(dividingBy: Double(size.height) + 40)) - 20)))
                        ctx.fill(p, with: .color(QF.tile(1 + i % 5)))
                    }
                }
            }.ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 16) {
                Text(stars == 3 ? "مثاليّ!" : (stars == 2 ? "حلو!" : "خلصت!")).font(rnd(40, .black)).foregroundStyle(Color.white)
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { k in
                        Image(systemName: "star.fill").font(.system(size: 50)).foregroundStyle(k < stars ? QF.gold : QF.s3)
                            .scaleEffect(k < shown ? 1 : 0.2).opacity(k < shown ? 1 : 0).shadow(color: k < stars ? QF.gold.opacity(0.6) : .clear, radius: 14)
                    }
                }.environment(\.layoutDirection, .leftToRight)
                Text(title + " · \(moves) قفزة").font(rnd(14.5, .heavy)).foregroundStyle(QF.tx2)
                if stars < 3 { Text(stars == 2 ? "بلا رجوع تاخذ الثلاث نجوم." : "بلا تلميح وبلا رجوع تاخذ الثلاث نجوم.").font(rnd(12.5)).foregroundStyle(QF.tx3) }
                Button(action: next) {
                    Text(last ? "رجوع للقائمة" : "المرحلة الجاية").font(rnd(18, .black)).foregroundStyle(Color.white).frame(width: 240, height: 56).background(QF.ac, in: Capsule())
                }.buttonStyle(Press()).padding(.top, 6)
                HStack(spacing: 22) {
                    Button(action: again) { Label("عيدها", systemImage: "arrow.counterclockwise").font(rnd(14.5, .heavy)).foregroundStyle(QF.tx2) }.buttonStyle(.plain)
                    if !last { Button(action: home) { Label("القائمة", systemImage: "square.grid.2x2.fill").font(rnd(14.5, .heavy)).foregroundStyle(QF.tx2) }.buttonStyle(.plain) }
                }
            }
        }
        .onAppear {
            if Shot.on { shown = 3; return }
            for k in 1...3 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(k)) { withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { shown = k }; if k <= stars { Haptic.thud() } } }
        }
    }
}
