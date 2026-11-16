import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var store: DozanStore
    @EnvironmentObject var synth: ToneEngine
    @State private var mode = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("الأدوات").font(rnd(30, .black)).foregroundStyle(Color.white)
                        Text("نغمة مرجعيّة ومترونوم دقيق").font(rnd(12.5)).foregroundStyle(DZ.tx3)
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    segBtn(0, "المترونوم", "metronome.fill")
                    segBtn(1, "النغمة المرجعيّة", "speaker.wave.3.fill")
                }
                if mode == 0 { MetronomePanel() } else { TonePanel() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .onAppear { if Shot.name == "tone" { mode = 1 } }
        .onDisappear { synth.stopAll() }
    }

    private func segBtn(_ i: Int, _ t: String, _ icon: String) -> some View {
        let on = mode == i
        return Button {
            Haptic.tap()
            withAnimation(.easeOut(duration: 0.2)) { mode = i }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(t).font(rnd(14, .heavy))
            }
            .foregroundStyle(on ? Color.black.opacity(0.85) : Color.white)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(on ? AnyShapeStyle(DZ.grad) : AnyShapeStyle(DZ.s2), in: Capsule())
        }
        .buttonStyle(Press())
    }
}

struct MetronomePanel: View {
    @EnvironmentObject var store: DozanStore
    @EnvironmentObject var synth: ToneEngine
    @State private var taps: [Double] = []
    @State private var shotStart = Date()

    private var running: Bool { synth.metroOn || Shot.on }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                BeatDots(perBar: synth.beatsPerBar, bpm: synth.bpm, running: running, counter: { synth.beatCounter }, shotStart: shotStart)
                    .frame(height: 70)
                    .environment(\.layoutDirection, .leftToRight)
                VStack(spacing: 0) {
                    Text("\(Int(synth.bpm))").font(rnd(86, .black)).monospacedDigit().foregroundStyle(DZ.grad)
                    Text("نبضة بالدقيقة").font(rnd(13, .bold)).foregroundStyle(DZ.tx3)
                    Text(Metronome.tempoName(synth.bpm)).font(rnd(14, .heavy)).foregroundStyle(DZ.violet).padding(.top, 4)
                }
                HStack(spacing: 10) {
                    roundBtn("minus") { synth.setBPM(synth.bpm - 1) }
                    Slider(value: Binding(get: { synth.bpm }, set: { synth.setBPM($0) }), in: 30...240, step: 1)
                        .tint(DZ.mint)
                        .environment(\.layoutDirection, .leftToRight)
                    roundBtn("plus") { synth.setBPM(synth.bpm + 1) }
                }
                HStack(spacing: 8) {
                    ForEach([60, 80, 100, 120, 140], id: \.self) { b in
                        ChipButton(text: "\(b)", on: Int(synth.bpm) == b, color: DZ.violet) { synth.setBPM(Double(b)) }
                    }
                }
            }
            .padding(16)
            .card(DZ.s1, 26)

            VStack(alignment: .leading, spacing: 10) {
                Text("ضربات بالمازورة").font(rnd(13, .bold)).foregroundStyle(DZ.tx3)
                HStack(spacing: 8) {
                    ForEach([2, 3, 4, 6], id: \.self) { n in
                        ChipButton(text: "\(n)/4", on: synth.beatsPerBar == n) { synth.setBeats(n) }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(DZ.s1, 22)

            HStack(spacing: 10) {
                Button {
                    let now = Date().timeIntervalSinceReferenceDate
                    if let last = taps.last, now - last > 2.5 { taps = [] }
                    taps.append(now)
                    if taps.count > 8 { taps.removeFirst() }
                    if let b = Metronome.tapTempo(taps) { synth.setBPM(b) }
                    Haptic.tap()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "hand.tap.fill").font(.system(size: 18, weight: .bold))
                        Text("اضغط مع الإيقاع").font(rnd(12, .heavy))
                    }
                    .foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 64)
                    .background(DZ.s2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(Press())
                Button {
                    Haptic.thud()
                    if synth.metroOn { synth.stopMetro() } else { synth.startMetro() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: running ? "stop.fill" : "play.fill").font(.system(size: 20, weight: .black))
                        Text(running ? "وقّف" : "شغّل").font(rnd(18, .black))
                    }
                    .foregroundStyle(Color.black.opacity(0.85)).frame(maxWidth: .infinity).frame(height: 64)
                    .background(LinearGradient(colors: running ? [DZ.rose, DZ.amber] : [DZ.mint, DZ.sky], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: (running ? DZ.rose : DZ.mint).opacity(0.35), radius: 14, y: 6)
                }
                .buttonStyle(Press())
            }
        }
        .onAppear {
            if Shot.on { synth.setBPM(96); synth.setBeats(4) }
        }
    }

    private func roundBtn(_ s: String, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); act() } label: {
            Image(systemName: s).font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                .frame(width: 44, height: 44).background(DZ.s2, in: Circle())
        }
        .buttonStyle(Press())
    }
}

/// نقاط الضربات تنبض مع المترونوم
struct BeatDots: View {
    let perBar: Int
    let bpm: Double
    let running: Bool
    let counter: () -> Int
    let shotStart: Date

    var body: some View {
        TimelineView(.animation) { tl in
            let info = beatInfo(tl.date)
            HStack(spacing: 10) {
                ForEach(0..<max(1, perBar), id: \.self) { i in
                    let on = running && info.beat == i
                    let accent = i == 0
                    Circle()
                        .fill(on ? (accent ? DZ.amber : DZ.mint) : DZ.s2)
                        .frame(width: accent ? 34 : 26, height: accent ? 34 : 26)
                        .scaleEffect(on ? 1.0 + 0.35 * info.decay : 1)
                        .shadow(color: on ? (accent ? DZ.amber : DZ.mint).opacity(0.8 * info.decay) : Color.clear, radius: 14)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func beatInfo(_ d: Date) -> (beat: Int, decay: Double) {
        guard running else { return (-1, 0) }
        if Shot.on {
            let t = d.timeIntervalSince(shotStart)
            let beats = t * bpm / 60
            let b = Int(beats.rounded(.down))
            let frac = beats - Double(b)
            return (b % max(1, perBar), max(0, 1 - frac * 2.2))
        }
        let c = counter()
        guard c > 0 else { return (-1, 0) }
        return ((c - 1) % max(1, perBar), 0.6)
    }
}

struct TonePanel: View {
    @EnvironmentObject var store: DozanStore
    @EnvironmentObject var synth: ToneEngine
    @State private var pc = 9
    @State private var octave = 4

    private var midi: Int { (octave + 1) * 12 + pc }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(NoteMath.western(midi) + "\(octave)")
                    .font(rnd(72, .black)).foregroundStyle(synth.tonePlaying ? AnyShapeStyle(DZ.grad) : AnyShapeStyle(Color.white))
                    .environment(\.layoutDirection, .leftToRight)
                    .shadow(color: synth.tonePlaying ? DZ.mint.opacity(0.6) : Color.clear, radius: 20)
                Text(NoteMath.solfege(midi)).font(rnd(22, .heavy)).foregroundStyle(DZ.tx2)
                Text(String(format: "%.2f هيرتز · A4 = %.0f", NoteMath.freq(midi: Double(midi), a4: store.settings.a4), store.settings.a4))
                    .font(rnd(13, .bold)).foregroundStyle(DZ.tx3)
                WaveView(active: synth.tonePlaying, freq: NoteMath.freq(midi: Double(midi), a4: store.settings.a4))
                    .frame(height: 60)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .card(DZ.s1, 26)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(0..<12, id: \.self) { i in
                    noteKey(i)
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            HStack(spacing: 10) {
                Text("الأوكتاف").font(rnd(14, .heavy)).foregroundStyle(DZ.tx2)
                Spacer()
                ForEach(2...5, id: \.self) { o in
                    ChipButton(text: "\(o)", on: octave == o, color: DZ.violet) { octave = o; retune() }
                }
            }
            .padding(12).card(DZ.s1, 18)

            HStack(spacing: 8) {
                Text("لون الصوت").font(rnd(14, .heavy)).foregroundStyle(DZ.tx2)
                Spacer()
                ForEach(0..<3, id: \.self) { i in
                    ChipButton(text: ["نقي", "دافئ", "مجوّف"][i], on: store.settings.timbre == i, color: DZ.sky) {
                        store.settings.timbre = i
                        synth.setTimbre(i)
                    }
                }
            }
            .padding(12).card(DZ.s1, 18)

            GlowButton(title: synth.tonePlaying ? "وقّف النغمة" : "شغّل النغمة", symbol: synth.tonePlaying ? "stop.fill" : "play.fill", colors: synth.tonePlaying ? [DZ.rose, DZ.amber] : [DZ.mint, DZ.sky]) {
                Haptic.thud()
                if synth.tonePlaying { synth.stopTone() } else { synth.setTimbre(store.settings.timbre); synth.playTone(midi: Double(midi), a4: store.settings.a4) }
            }
        }
        .onChange(of: store.settings.a4) { _ in retune() }
    }

    private func retune() {
        if synth.tonePlaying { synth.playTone(midi: Double(midi), a4: store.settings.a4) }
    }

    private func noteKey(_ i: Int) -> some View {
        let on = pc == i
        let sharp = NoteMath.isSharp(i)
        return Button {
            Haptic.tap()
            pc = i
            retune()
        } label: {
            VStack(spacing: 1) {
                Text(NoteMath.wNames[i]).font(rnd(15, .black))
                Text(NoteMath.sNames[i]).font(rnd(10, .bold)).opacity(0.7)
            }
            .foregroundStyle(on ? Color.black.opacity(0.85) : Color.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(on ? AnyShapeStyle(DZ.grad) : AnyShapeStyle(sharp ? DZ.ink : DZ.s2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06)))
        }
        .buttonStyle(Press())
    }
}

/// موجة جيبيّة متحرّكة للزينة
struct WaveView: View {
    let active: Bool
    let freq: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !active)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let cycles = max(1.5, min(9, freq / 70))
                var p = Path()
                let steps = 120
                for s in 0...steps {
                    let fx = Double(s) / Double(steps)
                    let env = sin(fx * Double.pi)
                    let amp = active ? 0.42 : 0.06
                    let v = sin((fx * cycles - t * 1.6) * 2 * Double.pi) * amp * env
                    let pt = CGPoint(x: CGFloat(fx) * size.width, y: size.height / 2 - CGFloat(v) * size.height)
                    if s == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                ctx.stroke(p, with: .linearGradient(Gradient(colors: [DZ.mint, DZ.sky, DZ.violet]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }
}
