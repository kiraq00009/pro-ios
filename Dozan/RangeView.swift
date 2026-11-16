import SwiftUI

/// مكتشف المدى الصوتيّ: أوطى نغمة ← أعلى نغمة ← نوع الصوت
struct RangeView: View {
    let close: () -> Void

    enum Step: Int { case low, high, result }

    @EnvironmentObject var store: DozanStore
    @EnvironmentObject var mic: MicPitch
    @EnvironmentObject var synth: ToneEngine
    @State private var step: Step = .low
    @State private var lowT = RangeTracker()
    @State private var highT = RangeTracker()
    @State private var lastTick = Date()
    @State private var flash: Int? = nil

    private var low: Int? { lowT.low }
    private var high: Int? { highT.high }

    var body: some View {
        ZStack {
            DZBackdrop(accent: DZ.sky)
            VStack(spacing: 14) {
                bar
                steps
                switch step {
                case .low, .high: listenBody
                case .result: resultBody
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .onAppear {
            if Shot.on {
                for _ in 0..<4 { _ = lowT.push(midi: 43.1, dt: 0.15) }
                for _ in 0..<4 { _ = highT.push(midi: 67, dt: 0.15) }
                for _ in 0..<4 { _ = highT.push(midi: 62.2, dt: 0.15) }
                step = .high
                mic.startDemo { t in 66.9 + 0.08 * sin(t * 5) }
            } else {
                mic.acquire()
            }
        }
        .onDisappear { if !Shot.on { mic.release() } }
        .onChange(of: mic.midi) { m in feed(m) }
    }

    private var bar: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 42, height: 42).background(DZ.s2, in: Circle())
            }
            .buttonStyle(Press())
            VStack(alignment: .leading, spacing: 1) {
                Text("مداك الصوتي").font(rnd(20, .black)).foregroundStyle(Color.white)
                Text("نكتشف أوطى وأعلى نغمة تثبّتها براحة").font(rnd(11.5)).foregroundStyle(DZ.tx3)
            }
            Spacer()
        }
    }

    private var steps: some View {
        HStack(spacing: 6) {
            stepDot(0, "الأوطى")
            stepDot(1, "الأعلى")
            stepDot(2, "النتيجة")
        }
    }

    private func stepDot(_ i: Int, _ t: String) -> some View {
        let on = step.rawValue >= i
        return HStack(spacing: 6) {
            Text("\(i + 1)").font(rnd(12, .black)).foregroundStyle(on ? Color.black.opacity(0.85) : DZ.tx3)
                .frame(width: 24, height: 24).background(on ? DZ.mint : DZ.s2, in: Circle())
            Text(t).font(rnd(12.5, .heavy)).foregroundStyle(on ? Color.white : DZ.tx3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(DZ.s1, in: Capsule())
    }

    private var listenBody: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text(step == .low ? "غنّي «آآآ» ونزّل صوتك شويّة شويّة لأوطى نغمة مريحة" : "هسه اطلع لأعلى نغمة تگدر تثبّتها بدون صراخ")
                    .font(rnd(15, .heavy)).foregroundStyle(DZ.tx2).multilineTextAlignment(.center)
                Text(mic.midi.map { store.noteLabel(Int($0.rounded())) } ?? "…")
                    .font(rnd(44, .black)).foregroundStyle(mic.midi == nil ? DZ.tx3 : Color.white)
                    .shadow(color: DZ.sky.opacity(mic.midi == nil ? 0 : 0.6), radius: 16)
                    .animation(.easeOut(duration: 0.15), value: mic.midi.map { Int($0.rounded()) })
                Text("ثبّت النغمة نصّ ثانية حتى تنحسب").font(rnd(12)).foregroundStyle(DZ.tx3)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .card(DZ.s1, 24)
            RangeKeyboard(low: low, high: high, current: mic.midi.map { Int($0.rounded()) }, flash: flash)
                .frame(height: 230)
                .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 10) {
                StatTile(value: low.map { NoteMath.name($0) } ?? "—", label: "أوطى نغمة", symbol: "arrow.down", color: DZ.sky)
                StatTile(value: high.map { NoteMath.name($0) } ?? "—", label: "أعلى نغمة", symbol: "arrow.up", color: DZ.violet)
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button {
                    Haptic.tap()
                    if step == .low { lowT.reset() } else { highT.reset() }
                } label: {
                    Text("صفّر").font(rnd(15, .heavy)).foregroundStyle(Color.white)
                        .frame(width: 100).frame(height: 56).background(DZ.s2, in: Capsule())
                }
                .buttonStyle(Press())
                GlowButton(title: step == .low ? "التالي" : "شوف النتيجة", symbol: "chevron.left") {
                    Haptic.tap()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        step = step == .low ? .high : .result
                    }
                }
                .disabled(step == .low ? low == nil : high == nil)
                .opacity((step == .low ? low == nil : high == nil) ? 0.5 : 1)
            }
            .padding(.bottom, 10)
        }
    }

    private var resultBody: some View {
        let lo = min(low ?? 48, high ?? 60)
        let hi = max(low ?? 48, high ?? 60)
        let vt = VoiceType.classify(low: lo, high: hi)
        return VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text("نوع صوتك التقريبي").font(rnd(13, .bold)).foregroundStyle(DZ.tx3)
                Text(vt.title).font(rnd(40, .black)).foregroundStyle(DZ.grad)
                Text(vt.note).font(rnd(14)).foregroundStyle(DZ.tx2)
                Text("\(NoteMath.name(lo)) ← \(NoteMath.name(hi)) · \(hi - lo) نصف درجة (\(String(format: "%.1f", Double(hi - lo) / 12)) أوكتاف)")
                    .font(rnd(13, .heavy)).foregroundStyle(Color.white).padding(.top, 4)
            }
            .padding(18).frame(maxWidth: .infinity).card(DZ.s1, 24, stroke: DZ.mint.opacity(0.3))
            RangeKeyboard(low: lo, high: hi, current: nil, flash: nil)
                .frame(height: 200)
                .environment(\.layoutDirection, .leftToRight)
            Text("نستخدم مداك حتى نختار نغمة البداية لكلّ تمرين بنصّ صوتك. تگدر تعيد القياس بأيّ وقت.")
                .font(rnd(12.5)).foregroundStyle(DZ.tx3).multilineTextAlignment(.center)
            Spacer(minLength: 0)
            GlowButton(title: "احفظ مداي", symbol: "checkmark") {
                store.saveRange(low: lo, high: hi)
                if store.settings.haptics { Haptic.ok() }
                close()
            }
            .padding(.bottom, 10)
        }
    }

    private func feed(_ m: Double?) {
        let now = Date()
        let dt = min(0.2, max(0, now.timeIntervalSince(lastTick)))
        lastTick = now
        if Shot.on { return }
        var hit: Int? = nil
        switch step {
        case .low: hit = lowT.push(midi: m, dt: dt)
        case .high: hit = highT.push(midi: m, dt: dt)
        case .result: break
        }
        if let h = hit, h != flash {
            flash = h
        }
    }
}

/// بيانو عموديّ صغير يلوّن المدى المكتشف
struct RangeKeyboard: View {
    let low: Int?
    let high: Int?
    let current: Int?
    let flash: Int?

    var body: some View {
        Canvas { ctx, size in
            let first = 36, last = 84
            let whites = (first...last).filter { !NoteMath.isSharp($0) }
            let ww = size.width / CGFloat(whites.count)
            var xs: [Int: CGFloat] = [:]
            for (i, n) in whites.enumerated() { xs[n] = CGFloat(i) * ww }
            let keyH = size.height - 26
            func inRange(_ n: Int) -> Bool {
                guard let l = low, let h = high else {
                    if let l = low { return n == l }
                    if let h = high { return n == h }
                    return false
                }
                return n >= l && n <= h
            }
            for n in whites {
                let x = xs[n] ?? 0
                let r = CGRect(x: x + 1, y: 0, width: ww - 2, height: keyH)
                var col: Color = Color.white.opacity(0.85)
                if inRange(n) { col = DZ.mint }
                if n == current { col = DZ.sky }
                ctx.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(col))
                if NoteMath.pitchClass(n) == 0 {
                    ctx.draw(Text("C\(NoteMath.octave(n))").font(rnd(9, .bold)).foregroundColor(DZ.tx3), at: CGPoint(x: x + ww / 2, y: keyH + 12), anchor: .center)
                }
            }
            for n in first...last where NoteMath.isSharp(n) {
                let x = (xs[n - 1] ?? 0) + ww * 0.68
                let r = CGRect(x: x, y: 0, width: ww * 0.64, height: keyH * 0.6)
                var col: Color = DZ.ink
                if inRange(n) { col = Color(red: 0.12, green: 0.55, blue: 0.42) }
                if n == current { col = DZ.sky }
                ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(col))
            }
        }
    }
}
