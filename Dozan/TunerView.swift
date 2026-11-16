import SwiftUI

/// قراءة الموالف الجاهزة للعرض
struct TunerDisplay: Equatable {
    var midi: Int
    var cents: Double
    var freq: Double
    var stringIndex: Int?
}

struct TunerView: View {
    @EnvironmentObject var store: DozanStore
    @EnvironmentObject var mic: MicPitch
    @EnvironmentObject var synth: ToneEngine

    @State private var display: TunerDisplay? = nil
    @State private var lastDisplay: TunerDisplay? = nil
    @State private var manualString: Int? = nil
    @State private var lock = InTuneLock()
    @State private var locked = false
    @State private var tuned: Set<Int> = []
    @State private var lastTick = Date()
    @State private var pulse = false
    @State private var acquired = false

    private var tol: Double { store.settings.tolerance }
    private var notes: [Int] { store.tuning?.notes ?? [] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                header
                MicBanner()
                InstrumentStrip()
                heroCard
                if !store.instrument.isChromatic { stringsCard }
                tipsRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .onAppear {
            lock = InTuneLock(tolerance: tol, holdTime: 0.6)
            if Shot.on { setupShot() } else if store.profile.onboarded { mic.acquire(); acquired = true }
        }
        .onDisappear { if acquired { mic.release(); acquired = false } }
        .onChange(of: store.profile.onboarded) { v in
            if v && !acquired && !Shot.on { mic.acquire(); acquired = true }
        }
        .onChange(of: mic.midi) { m in update(m) }
        .onChange(of: store.settings.tuning) { _ in tuned = []; manualString = nil; lock.reset(); locked = false }
        .onChange(of: store.settings.tolerance) { v in lock = InTuneLock(tolerance: v, holdTime: 0.6) }
    }

    // MARK: الأجزاء

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("دوزان").font(rnd(34, .black)).foregroundStyle(DZ.grad)
                Text("موالف دقيق لكلّ آلة وصوت").font(rnd(12.5)).foregroundStyle(DZ.tx3)
            }
            Spacer()
            A4Badge()
        }
    }

    private var heroCard: some View {
        let d = display ?? lastDisplay
        let active = display != nil
        let c = d?.cents ?? 0
        let color = active ? DZ.tuneColor(c, tol: tol) : DZ.tx3
        return VStack(spacing: 10) {
            NoteHero(display: d, active: active, color: color, naming: store.settings.naming, locked: locked)
            GaugeDial(cents: active ? c : 0, active: active, color: color, tol: tol)
                .frame(height: 170)
                .environment(\.layoutDirection, .leftToRight)
            StrobeBand(cents: c, active: active, color: color)
                .frame(height: 40)
                .environment(\.layoutDirection, .leftToRight)
            readout(d, active: active, color: color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DZ.s1)
                .shadow(color: locked ? DZ.mint.opacity(0.55) : Color.clear, radius: locked ? 26 : 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(locked ? DZ.mint.opacity(0.8) : Color.white.opacity(0.07), lineWidth: locked ? 2 : 1)
        )
        .animation(.easeOut(duration: 0.25), value: locked)
    }

    private func readout(_ d: TunerDisplay?, active: Bool, color: Color) -> some View {
        HStack(spacing: 10) {
            pill(d.map { String(format: "%+.1f", $0.cents) } ?? "—", "سنت", color)
            pill(d.map { String(format: "%.2f", $0.freq) } ?? "—", "هيرتز", DZ.sky)
            pill(d.map { String(format: "%.2f", NoteMath.freq(midi: Double($0.midi), a4: store.settings.a4)) } ?? "—", "الهدف", DZ.violet)
        }
        .overlay(alignment: .top) {
            if active, let d = d {
                Text(StringFinder.advice(cents: d.cents, tolerance: tol))
                    .font(rnd(13, .heavy)).foregroundStyle(color)
                    .offset(y: -26)
                    .transition(.opacity)
            }
        }
        .padding(.top, 22)
    }

    private func pill(_ v: String, _ label: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(rnd(17, .black)).monospacedDigit().foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6)
                .environment(\.layoutDirection, .leftToRight)
            Text(label).font(rnd(10.5, .bold)).foregroundStyle(c)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 9)
        .background(DZ.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var stringsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.tuning?.name ?? "").font(rnd(15, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                Spacer()
                Toggle(isOn: Binding(get: { store.settings.autoString && manualString == nil }, set: { v in
                    store.settings.autoString = v
                    if v { manualString = nil }
                })) {
                    Text("كشف تلقائي").font(rnd(12.5, .bold)).foregroundStyle(DZ.tx2)
                }
                .toggleStyle(SwitchToggleStyle(tint: DZ.mint))
                .fixedSize()
            }
            StringsRow(notes: notes, active: display?.stringIndex ?? lastDisplay?.stringIndex, manual: manualString, tuned: tuned, naming: store.settings.naming) { i in
                Haptic.tap()
                if manualString == i { manualString = nil } else { manualString = i; store.settings.autoString = false }
                synth.blip(midi: Double(notes[i]), a4: store.settings.a4)
            }
            .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(DZ.mint)
                Text(tuned.count == notes.count && !notes.isEmpty ? "كلّ الأوتار مضبوطة — يلّا اعزف!" : "انضبط \(tuned.count) من \(notes.count) · اضغط وتر حتى تسمع نغمته")
                    .font(rnd(12)).foregroundStyle(DZ.tx3)
            }
        }
        .padding(14)
        .card(DZ.s1, 22)
    }

    private var tipsRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill").foregroundStyle(DZ.amber)
            Text("اعزف الوتر وحده وخلّيه يرنّ — الإبرة بالنصّ والشريط واقف يعني مضبوط.")
                .font(rnd(12)).foregroundStyle(DZ.tx2)
            Spacer(minLength: 0)
        }
        .padding(12)
        .card(DZ.s1.opacity(0.7), 16)
        .padding(.bottom, 10)
    }

    // MARK: المنطق

    private func update(_ m: Double?) {
        let now = Date()
        let dt = min(0.2, max(0, now.timeIntervalSince(lastTick)))
        lastTick = now
        guard let m = m else {
            display = nil
            _ = lock.update(cents: nil, dt: dt)
            if !lock.locked { locked = false }
            return
        }
        let a4 = store.settings.a4
        let f = NoteMath.freq(midi: m, a4: a4)
        var d: TunerDisplay
        if store.instrument.isChromatic || notes.isEmpty {
            let r = NoteMath.reading(freq: f, a4: a4)
            d = TunerDisplay(midi: r.midi, cents: r.cents, freq: f, stringIndex: nil)
        } else if let i = manualString, i < notes.count {
            let target = notes[i]
            d = TunerDisplay(midi: target, cents: (m - Double(target)) * 100, freq: f, stringIndex: i)
        } else if let c = StringFinder.closest(freq: f, notes: notes, a4: a4), abs(c.cents) < 450 {
            d = TunerDisplay(midi: notes[c.index], cents: c.cents, freq: f, stringIndex: c.index)
        } else {
            let r = NoteMath.reading(freq: f, a4: a4)
            d = TunerDisplay(midi: r.midi, cents: r.cents, freq: f, stringIndex: nil)
        }
        display = d
        lastDisplay = d
        let fired = lock.update(cents: d.cents, dt: dt)
        if fired {
            if store.settings.haptics { Haptic.ok() }
            if let i = d.stringIndex { tuned.insert(i) }
            if !Shot.on { store.addTuned() }
        }
        locked = lock.locked
    }

    private func setupShot() {
        tuned = [0, 2]
        let base = 45.0
        mic.startDemo { t in base + 0.012 + 0.006 * sin(t * 2.3) }
    }
}

struct A4Badge: View {
    @EnvironmentObject var store: DozanStore
    var body: some View {
        Menu {
            ForEach([430, 432, 435, 438, 440, 441, 442, 443, 444, 446, 448, 450], id: \.self) { v in
                Button { store.settings.a4 = Double(v) } label: {
                    Text("A4 = \(v) Hz" + (v == 440 ? " (قياسي)" : ""))
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "tuningfork").font(.system(size: 12, weight: .black))
                Text("A4 \(Int(store.settings.a4))").font(rnd(14, .black)).environment(\.layoutDirection, .leftToRight)
            }
            .foregroundStyle(DZ.mint)
            .padding(.horizontal, 12).frame(height: 36)
            .background(DZ.s2, in: Capsule())
            .overlay(Capsule().stroke(DZ.mint.opacity(0.3)))
        }
    }
}

struct InstrumentStrip: View {
    @EnvironmentObject var store: DozanStore
    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Instruments.all) { inst in
                        chip(inst)
                    }
                }
                .padding(.horizontal, 2)
            }
            if !store.instrument.isChromatic {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.instrument.tunings) { t in
                            ChipButton(text: t.name, on: store.tuning?.id == t.id, color: DZ.violet) { store.settings.tuning = t.id }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func chip(_ inst: Instrument) -> some View {
        let on = store.settings.instrument == inst.id
        return Button {
            Haptic.tap()
            store.settings.instrument = inst.id
            store.settings.tuning = inst.tunings.first?.id ?? ""
        } label: {
            HStack(spacing: 6) {
                Image(systemName: inst.symbol).font(.system(size: 13, weight: .bold))
                Text(inst.name).font(rnd(14, .heavy))
            }
            .foregroundStyle(on ? Color.black.opacity(0.85) : Color.white)
            .padding(.horizontal, 14).frame(height: 40)
            .background(on ? AnyShapeStyle(DZ.grad) : AnyShapeStyle(DZ.s2), in: Capsule())
        }
        .buttonStyle(Press())
    }
}

struct NoteHero: View {
    let display: TunerDisplay?
    let active: Bool
    let color: Color
    let naming: Int
    let locked: Bool

    var body: some View {
        let m = display?.midi
        return HStack(alignment: .center, spacing: 18) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(m.map { naming == 2 ? NoteMath.sLetters[NoteMath.pitchClass($0)] : NoteMath.wLetters[NoteMath.pitchClass($0)] } ?? "–")
                        .font(rnd(naming == 2 ? 64 : 84, .black))
                        .foregroundStyle(active ? Color.white : DZ.tx3)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(m.map { NoteMath.isSharp($0) ? "♯" : " " } ?? " ").font(rnd(30, .black)).foregroundStyle(color)
                        Text(m.map { "\(NoteMath.octave($0))" } ?? " ").font(rnd(22, .heavy)).foregroundStyle(DZ.tx3)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .shadow(color: active ? color.opacity(0.55) : Color.clear, radius: 18)
                if naming == 0 {
                    Text(m.map { NoteMath.solfege($0) } ?? "اعزف نغمة")
                        .font(rnd(22, .heavy)).foregroundStyle(active ? color : DZ.tx3)
                } else if naming == 2 {
                    Text(m.map { NoteMath.western($0) } ?? "اعزف نغمة")
                        .font(rnd(18, .heavy)).foregroundStyle(DZ.tx3)
                }
            }
            .frame(minWidth: 150)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: m)
            if locked {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 40, weight: .bold)).foregroundStyle(DZ.mint)
                        .shadow(color: DZ.mint.opacity(0.7), radius: 12)
                    Text("مضبوط").font(rnd(14, .black)).foregroundStyle(DZ.mint)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 132)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: locked)
    }
}

/// إبرة متحرّكة بنعومة (شكل قابل للتحريك)
struct NeedleShape: Shape {
    var angle: Double
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.maxY - 12)
        let r = min(rect.width / 2 - 18, rect.height - 26) - 12
        let rad = CGFloat((angle - 90) * Double.pi / 180)
        let tip = CGPoint(x: c.x + cos(rad) * r, y: c.y + sin(rad) * r)
        let perp = rad + CGFloat.pi / 2
        let w: CGFloat = 5.5
        var p = Path()
        p.move(to: tip)
        p.addLine(to: CGPoint(x: c.x + cos(perp) * w, y: c.y + sin(perp) * w))
        p.addLine(to: CGPoint(x: c.x - cos(perp) * w, y: c.y - sin(perp) * w))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18))
        return p
    }
}

struct GaugeDial: View {
    let cents: Double
    let active: Bool
    let color: Color
    let tol: Double

    private var angle: Double { max(-50, min(50, cents)) / 50 * 60 }

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height - 12)
                let r = min(size.width / 2 - 18, size.height - 26)
                for i in -10...10 {
                    let deg = CGFloat(i) * 6 - 90
                    let rad = deg * CGFloat.pi / 180
                    let major = i % 5 == 0
                    let len: CGFloat = major ? 18 : 9
                    var path = Path()
                    path.move(to: CGPoint(x: c.x + cos(rad) * r, y: c.y + sin(rad) * r))
                    path.addLine(to: CGPoint(x: c.x + cos(rad) * (r - len), y: c.y + sin(rad) * (r - len)))
                    let col: Color = i == 0 ? DZ.mint : Color.white.opacity(major ? 0.55 : 0.22)
                    ctx.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: major ? 3 : 1.5, lineCap: .round))
                }
                let tolDeg = max(1.5, min(50, tol)) / 50 * 60
                var arc = Path()
                arc.addArc(center: c, radius: r + 9, startAngle: .degrees(-90 - tolDeg), endAngle: .degrees(-90 + tolDeg), clockwise: false)
                ctx.stroke(arc, with: .color(DZ.mint.opacity(0.85)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                var flat = Path()
                flat.addArc(center: c, radius: r + 9, startAngle: .degrees(-150), endAngle: .degrees(-90 - tolDeg - 4), clockwise: false)
                ctx.stroke(flat, with: .color(DZ.rose.opacity(0.22)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                var sharp = Path()
                sharp.addArc(center: c, radius: r + 9, startAngle: .degrees(-90 + tolDeg + 4), endAngle: .degrees(-30), clockwise: false)
                ctx.stroke(sharp, with: .color(DZ.rose.opacity(0.22)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
            NeedleShape(angle: angle)
                .fill(active ? color : DZ.tx3)
                .shadow(color: active ? color.opacity(0.8) : Color.clear, radius: 10)
                .animation(.interpolatingSpring(stiffness: 160, damping: 16), value: angle)
            VStack {
                Spacer()
                HStack {
                    Text("♭ واطي").font(rnd(12, .heavy)).foregroundStyle(DZ.tx3)
                    Spacer()
                    Text("عالي ♯").font(rnd(12, .heavy)).foregroundStyle(DZ.tx3)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

final class StrobeClock {
    var phase: Double = 0
    var last: Double = 0
}

/// شريط ستروب: يمشي يمين إذا عالي ويسار إذا واطي، ويوقف لمّا تضبط
struct StrobeBand: View {
    let cents: Double
    let active: Bool
    let color: Color
    @State private var clock = StrobeClock()

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let dt = clock.last == 0 ? 0 : min(0.1, max(0, t - clock.last))
                clock.last = t
                if active { clock.phase += dt * max(-60, min(60, cents)) * 4 }
                let rows: [(CGFloat, CGFloat, Double)] = [(0, 18, 1), (size.height / 2 + 1, 9, 2)]
                for (y, stripe, mult) in rows {
                    let period = Double(stripe * 2)
                    let off = CGFloat((clock.phase * mult).truncatingRemainder(dividingBy: period))
                    var x = -stripe * 4 + off
                    let h = size.height / 2 - 1
                    while x < size.width + stripe * 2 {
                        let rect = CGRect(x: x, y: y, width: stripe, height: h)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(color.opacity(active ? 0.8 : 0.16)))
                        x += stripe * 2
                    }
                }
            }
        }
        .mask(
            LinearGradient(colors: [Color.clear, Color.white, Color.white, Color.clear], startPoint: .leading, endPoint: .trailing)
        )
        .background(DZ.s2.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct StringsRow: View {
    let notes: [Int]
    let active: Int?
    let manual: Int?
    let tuned: Set<Int>
    let naming: Int
    let tap: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(notes.enumerated()), id: \.offset) { pair in
                cell(pair.offset, pair.element)
            }
        }
    }

    private func cell(_ i: Int, _ n: Int) -> some View {
        let isActive = active == i
        let isManual = manual == i
        let ok = tuned.contains(i)
        let ring: Color = isManual ? DZ.violet : (isActive ? DZ.mint : Color.white.opacity(0.08))
        return Button { tap(i) } label: {
            VStack(spacing: 3) {
                Text(naming == 2 ? NoteMath.solfege(n) : NoteMath.western(n))
                    .font(rnd(naming == 2 ? 15 : 19, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6)
                Text("\(NoteMath.octave(n))").font(rnd(11, .bold)).foregroundStyle(DZ.tx3)
                Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(ok ? DZ.mint : DZ.tx3.opacity(0.5))
            }
            .frame(maxWidth: .infinity).frame(height: 76)
            .background(isActive ? DZ.mint.opacity(0.14) : DZ.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ring, lineWidth: isActive || isManual ? 2 : 1))
            .scaleEffect(isActive ? 1.05 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        }
        .buttonStyle(Press())
    }
}
