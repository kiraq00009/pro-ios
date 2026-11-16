import SwiftUI

final class SessionModel: ObservableObject {
    enum Phase: Equatable { case intro, countdown, sing, done }

    @Published var phase: Phase = .intro
    @Published var count: Int = 3
    @Published var t: Double = 0
    @Published var trail: [TrailPoint] = []
    @Published var live: Int = 0
    @Published var result: ScoreResult? = nil
    @Published var root: Int { didSet { melody = def.melody(root: root) } }
    @Published private(set) var melody: Melody

    let def: ExerciseDef
    var tolerance: Double = 50
    var octaveFree: Bool = true
    private var timer: Timer?
    private var startedAt = Date()
    private var ticks = 0

    init(def: ExerciseDef, root: Int) {
        self.def = def
        self.root = root
        self.melody = def.melody(root: root)
    }

    func begin(mic: MicPitch, synth: ToneEngine, a4: Double) {
        timer?.invalidate()
        result = nil
        trail = []
        t = 0
        live = 0
        count = 3
        phase = .countdown
        synth.blip(midi: Double(root), a4: a4, seconds: 0.9)
        let tm = Timer(timeInterval: 1, repeats: true) { [weak self, weak mic] _ in
            guard let self = self else { return }
            self.count -= 1
            if self.count <= 0 {
                self.timer?.invalidate()
                if let m = mic { self.sing(mic: m) }
            } else {
                Haptic.tap()
            }
        }
        RunLoop.main.add(tm, forMode: .common)
        timer = tm
    }

    private func sing(mic: MicPitch) {
        phase = .sing
        Haptic.thud()
        startedAt = Date()
        ticks = 0
        let tm = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self, weak mic] _ in
            guard let self = self else { return }
            self.tick(mic?.midi)
        }
        RunLoop.main.add(tm, forMode: .common)
        timer = tm
    }

    private func tick(_ m: Double?) {
        t = Date().timeIntervalSince(startedAt)
        trail.append(TrailPoint(t: t, midi: m))
        ticks += 1
        if ticks % 6 == 0 {
            live = Scorer.score(trail: trail, melody: melody, tolerance: tolerance, octaveFree: octaveFree).percent
        }
        if t >= melody.duration + 0.25 { finish() }
    }

    func finish() {
        timer?.invalidate()
        timer = nil
        let r = Scorer.score(trail: trail, melody: melody, tolerance: tolerance, octaveFree: octaveFree)
        live = r.percent
        result = r
        phase = .done
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    func backToIntro() {
        cancel()
        phase = .intro
    }

    /// بيانات العرض: نصّ تمرين مغنّى بشكل واقعيّ
    func fillDemo(until: Double) {
        var pts: [TrailPoint] = []
        var i = 0
        var prev: Double? = nil
        while Double(i) / 30 < until {
            let tt = Double(i) / 30
            if let g = melody.target(at: tt), let si = melody.segIndex(at: tt) {
                let local = tt - melody.segs[si].start
                var sung = g + 0.16 * sin(tt * 4.3) + 0.07 * sin(tt * 13.1)
                if local < 0.14, let p = prev { sung = p + (g - p) * (local / 0.14) }
                if si == 5 { sung += 0.55 }
                pts.append(TrailPoint(t: tt, midi: (i % 47 == 46) ? nil : sung))
                if local > 0.3 { prev = g }
            }
            i += 1
        }
        trail = pts
        t = until
        phase = .sing
        live = Scorer.score(trail: pts, melody: melody, tolerance: tolerance, octaveFree: octaveFree).percent
    }
}

struct SessionView: View {
    let def: ExerciseDef
    let close: () -> Void

    @EnvironmentObject var store: DozanStore
    @EnvironmentObject var mic: MicPitch
    @EnvironmentObject var synth: ToneEngine
    @StateObject private var model: SessionModel
    @State private var award: AwardInfo? = nil

    init(def: ExerciseDef, root: Int, close: @escaping () -> Void) {
        self.def = def
        self.close = close
        _model = StateObject(wrappedValue: SessionModel(def: def, root: root))
    }

    var body: some View {
        ZStack {
            DZBackdrop(accent: DZ.sky)
            VStack(spacing: 12) {
                topBar
                switch model.phase {
                case .intro: introBody
                case .countdown, .sing: singBody
                case .done: doneBody
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            if model.phase == .countdown {
                Text("\(max(1, model.count))")
                    .font(rnd(120, .black)).foregroundStyle(DZ.grad)
                    .shadow(color: DZ.mint.opacity(0.6), radius: 30)
                    .id(model.count)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: model.count)
            }
        }
        .onAppear {
            model.tolerance = store.settings.singTolerance
            model.octaveFree = store.settings.octaveFree
            if Shot.on {
                model.fillDemo(until: 5.3)
                mic.startDemo { _ in 66.1 }
            } else {
                mic.acquire()
            }
        }
        .onDisappear {
            model.cancel()
            synth.stopMelody()
            if !Shot.on { mic.release() }
        }
        .onChange(of: model.phase) { p in
            if p == .done, let r = model.result {
                award = store.record(def, result: r, seconds: model.melody.duration)
                if store.settings.haptics { if r.stars > 0 { Haptic.ok() } else { Haptic.bad() } }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                model.cancel()
                close()
            } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 42, height: 42).background(DZ.s2, in: Circle())
            }
            .buttonStyle(Press())
            VStack(alignment: .leading, spacing: 1) {
                Text(def.title).font(rnd(18, .black)).foregroundStyle(Color.white).lineLimit(1)
                Text(def.kind.title + " · صعوبة \(def.difficulty)/5").font(rnd(11.5)).foregroundStyle(DZ.tx3)
            }
            Spacer()
            if model.phase == .sing || model.phase == .done {
                Text("\(model.live)%")
                    .font(rnd(22, .black)).monospacedDigit().foregroundStyle(DZ.pitchColor(Double(100 - model.live) / 2, tol: 8))
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.horizontal, 12).frame(height: 42).background(DZ.s2, in: Capsule())
            }
        }
    }

    // MARK: المقدّمة

    private var introBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(def.detail).font(rnd(15, .semibold)).foregroundStyle(DZ.tx2)
                    NotesPreview(melody: model.melody, naming: store.settings.naming)
                        .frame(height: 120)
                        .environment(\.layoutDirection, .leftToRight)
                    HStack(spacing: 8) {
                        infoChip("clock.fill", String(format: "%.0f ث", model.melody.duration.rounded(.up)), DZ.sky)
                        infoChip("music.note", "\(model.melody.distinctNotes.count) نغمات", DZ.violet)
                        infoChip("scope", "±\(Int(store.settings.singTolerance)) سنت", DZ.mint)
                    }
                }
                .padding(14).card(DZ.s1, 22)
                rootPicker
                HStack(spacing: 10) {
                    Button {
                        Haptic.tap()
                        if synth.melodyPlaying { synth.stopMelody() } else { synth.playMelody(model.melody, a4: store.settings.a4) }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: synth.melodyPlaying ? "stop.fill" : "ear.fill")
                            Text(synth.melodyPlaying ? "وقّف" : "اسمع اللحن").font(rnd(15, .heavy))
                        }
                        .foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 56)
                        .background(DZ.s2, in: Capsule())
                    }
                    .buttonStyle(Press())
                    GlowButton(title: "ابدأ", symbol: "mic.fill") {
                        synth.stopMelody()
                        model.begin(mic: mic, synth: synth, a4: store.settings.a4)
                    }
                }
                MicBanner()
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill").foregroundStyle(DZ.sky)
                    Text("الخطّ البنفسجي هو اللحن، وصوتك يرسم خطّ ملوّن: أخضر = مضبوط، أصفر = قريب، أحمر = بعيد. ما يهمّ إذا غنّيت أوكتاف أوطى أو أعلى.")
                        .font(rnd(12.5)).foregroundStyle(DZ.tx2).lineSpacing(2)
                }
                .padding(12).card(DZ.s1.opacity(0.7), 16)
            }
            .padding(.bottom, 20)
        }
    }

    private var rootPicker: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("نغمة البداية").font(rnd(12, .bold)).foregroundStyle(DZ.tx3)
                Text(store.noteLabel(model.root)).font(rnd(19, .black)).foregroundStyle(Color.white)
            }
            Spacer()
            stepBtn("minus") { if model.root > 36 { model.root -= 1 } }
            stepBtn("plus") { if model.root < 76 { model.root += 1 } }
            Button {
                Haptic.tap()
                synth.blip(midi: Double(model.root), a4: store.settings.a4)
            } label: {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(DZ.mint)
                    .frame(width: 42, height: 42).background(DZ.s2, in: Circle())
            }
            .buttonStyle(Press())
        }
        .padding(14).card(DZ.s1, 22)
    }

    private func stepBtn(_ s: String, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); act() } label: {
            Image(systemName: s).font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                .frame(width: 42, height: 42).background(DZ.s2, in: Circle())
        }
        .buttonStyle(Press())
    }

    private func infoChip(_ icon: String, _ text: String, _ c: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(c)
            Text(text).font(rnd(12, .heavy)).foregroundStyle(Color.white)
        }
        .padding(.horizontal, 10).frame(height: 30).background(DZ.s2, in: Capsule())
    }

    // MARK: الغناء

    private var singBody: some View {
        VStack(spacing: 12) {
            progressBar
            PitchTrailGraph(melody: model.melody, trail: model.trail, now: model.t, octaveFree: model.octaveFree, tol: model.tolerance, naming: store.settings.naming)
                .frame(maxHeight: .infinity)
                .background(DZ.s1, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.07)))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .environment(\.layoutDirection, .leftToRight)
            LiveNoteBar(target: model.melody.target(at: model.t), sung: mic.midi, octaveFree: model.octaveFree, tol: model.tolerance, label: { store.noteLabel($0) })
            Button {
                Haptic.tap()
                model.finish()
            } label: {
                Text(model.phase == .countdown ? "استعدّ…" : "إنهاء وتقييم").font(rnd(15, .heavy)).foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity).frame(height: 50).background(DZ.s2, in: Capsule())
            }
            .buttonStyle(Press())
            .disabled(model.phase != .sing)
            .padding(.bottom, 8)
        }
    }

    private var progressBar: some View {
        let dur = max(0.1, model.melody.duration)
        let p = min(1, max(0, model.t / dur))
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(DZ.s2)
                Capsule().fill(DZ.grad).frame(width: max(6, g.size.width * CGFloat(p)))
            }
        }
        .frame(height: 6)
        .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: النتيجة

    private var doneBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let r = model.result {
                    ResultCard(result: r, award: award, tol: model.tolerance)
                    PitchTrailGraph(melody: model.melody, trail: model.trail, now: -1, octaveFree: model.octaveFree, tol: model.tolerance, naming: store.settings.naming, overview: true)
                        .frame(height: 170)
                        .background(DZ.s1, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .environment(\.layoutDirection, .leftToRight)
                    Text(feedback(r)).font(rnd(13.5)).foregroundStyle(DZ.tx2).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).card(DZ.s1.opacity(0.7), 16)
                }
                HStack(spacing: 10) {
                    Button {
                        Haptic.tap()
                        award = nil
                        model.begin(mic: mic, synth: synth, a4: store.settings.a4)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("عيدها").font(rnd(16, .heavy))
                        }
                        .foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 56).background(DZ.s2, in: Capsule())
                    }
                    .buttonStyle(Press())
                    GlowButton(title: "تمام", symbol: "checkmark") { close() }
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func feedback(_ r: ScoreResult) -> String {
        if r.voiced < 0.5 { return "ما سمعنا صوتك أغلب الوقت — قرّب الآيفون وغنّي بصوت أوضح وبنفَس ثابت." }
        if r.percent >= 90 { return "أداء ممتاز! دقّتك عالية جدًّا. جرّب تمرين أصعب أو قلّل حدّ السماح من الإعدادات." }
        if r.percent >= 75 { return "حلو كلّش! معدّل انحرافك \(Int(r.meanCents)) سنت. ركّز على الانتقال بين النغمات بدون انزلاق." }
        if r.percent >= 55 { return "بداية زينة. اسمع اللحن مرّة قبل ما تبدأ، وثبّت كلّ نغمة قبل ما تنتقل للّي بعدها." }
        return "لا تستسلم — اختار نغمة بداية أريح لصوتك من الأسهم، واسمع اللحن أوّل."
    }
}

struct ResultCard: View {
    let result: ScoreResult
    let award: AwardInfo?
    let tol: Double
    @State private var shown = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(DZ.s2, lineWidth: 14)
                Circle().trim(from: 0, to: shown ? CGFloat(result.percent) / 100 : 0)
                    .stroke(DZ.grad, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: DZ.mint.opacity(0.5), radius: 12)
                VStack(spacing: 0) {
                    Text("\(result.percent)%").font(rnd(46, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
                    StarsRow(count: shown ? result.stars : 0, size: 18)
                }
            }
            .frame(width: 180, height: 180)
            .padding(.top, 6)
            if let a = award {
                HStack(spacing: 8) {
                    badge("+\(a.xp) نقطة", "sparkles", DZ.amber)
                    if a.newStars > 0 { badge("+\(a.newStars) نجمة", "star.fill", DZ.mint) }
                    if a.isBest { badge("رقم قياسي", "trophy.fill", DZ.violet) }
                }
                if a.levelUp {
                    Text("🎉 وصلت المستوى \(a.newLevel) — \(Leveling.title(a.newLevel))")
                        .font(rnd(15, .black)).foregroundStyle(Color.black.opacity(0.85))
                        .padding(.horizontal, 14).frame(height: 40)
                        .background(DZ.grad, in: Capsule())
                }
            }
            HStack(spacing: 10) {
                StatTile(value: "±\(Int(result.meanCents.rounded()))", label: "معدّل الانحراف (سنت)", symbol: "scope", color: DZ.pitchColor(result.meanCents, tol: tol / 2))
                StatTile(value: "\(Int((result.voiced * 100).rounded()))%", label: "وقت مسموع", symbol: "waveform", color: DZ.sky)
            }
        }
        .padding(16)
        .card(DZ.s1, 26, stroke: DZ.mint.opacity(0.25))
        .onAppear { withAnimation(.easeOut(duration: 1.1).delay(0.15)) { shown = true } }
    }

    private func badge(_ t: String, _ icon: String, _ c: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
            Text(t).font(rnd(13, .heavy))
        }
        .foregroundStyle(c)
        .padding(.horizontal, 11).frame(height: 32)
        .background(c.opacity(0.14), in: Capsule())
    }
}

/// شريط النغمة الحاليّة: شنو تغنّي مقابل شنو المطلوب
struct LiveNoteBar: View {
    let target: Double?
    let sung: Double?
    let octaveFree: Bool
    let tol: Double
    let label: (Int) -> String

    var body: some View {
        let folded: Double? = {
            guard let s = sung else { return nil }
            guard let g = target, octaveFree else { return s }
            return NoteMath.fold(s, near: g)
        }()
        let diff: Double? = {
            guard let f = folded, let g = target else { return nil }
            return (f - g) * 100
        }()
        let col: Color = diff.map { DZ.pitchColor($0, tol: tol) } ?? DZ.tx3
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("المطلوب").font(rnd(11, .bold)).foregroundStyle(DZ.tx3)
                Text(target.map { label(Int($0.rounded())) } ?? "—").font(rnd(17, .black)).foregroundStyle(DZ.violet).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: diff.map { abs($0) <= tol ? "checkmark.circle.fill" : ($0 > 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill") } ?? "mic.circle")
                .font(.system(size: 30, weight: .bold)).foregroundStyle(col)
                .shadow(color: col.opacity(0.5), radius: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("صوتك").font(rnd(11, .bold)).foregroundStyle(DZ.tx3)
                Text(sung.map { label(Int($0.rounded())) } ?? "غنّي…").font(rnd(17, .black)).foregroundStyle(col).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .card(DZ.s1, 18, stroke: col.opacity(0.3))
    }
}

/// معاينة اللحن قبل البدء
struct NotesPreview: View {
    let melody: Melody
    let naming: Int

    var body: some View {
        Canvas { ctx, size in
            let lo = melody.lowest - 1, hi = melody.highest + 1
            let span = max(3, hi - lo)
            let dur = max(0.1, melody.duration)
            func x(_ t: Double) -> CGFloat { 6 + CGFloat(t / dur) * (size.width - 12) }
            func y(_ m: Double) -> CGFloat { size.height - 8 - CGFloat((m - lo) / span) * (size.height - 16) }
            for s in melody.segs {
                var p = Path()
                p.move(to: CGPoint(x: x(s.start) + 2, y: y(s.from)))
                p.addLine(to: CGPoint(x: x(s.end) - 2, y: y(s.to)))
                ctx.stroke(p, with: .color(DZ.violet.opacity(0.3)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                ctx.stroke(p, with: .color(DZ.violet), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            for n in melody.distinctNotes {
                let txt = naming == 2 ? NoteMath.solfege(n) : NoteMath.western(n)
                ctx.draw(Text(txt).font(rnd(9.5, .bold)).foregroundColor(DZ.tx3), at: CGPoint(x: 2, y: y(Double(n)) - 8), anchor: .leading)
            }
        }
    }
}

/// رسم أثر الصوت المتحرّك فوق خطّ اللحن
struct PitchTrailGraph: View {
    let melody: Melody
    let trail: [TrailPoint]
    let now: Double
    let octaveFree: Bool
    let tol: Double
    let naming: Int
    var overview: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let past: Double = overview ? 0 : 2.6
            let future: Double = overview ? max(1, melody.duration) : 4.4
            let pps = size.width / CGFloat(past + future)
            let center = overview ? 0 : now
            let nowX = CGFloat(past) * pps
            let lo = melody.lowest - 2.5
            let hi = melody.highest + 2.5
            let span = max(5, hi - lo)
            func x(_ t: Double) -> CGFloat { nowX + CGFloat(t - center) * pps }
            func y(_ m: Double) -> CGFloat { size.height - CGFloat((m - lo) / span) * size.height }

            // شبكة أنصاف الدرجات
            let names = Set(melody.distinctNotes)
            var mm = Int(lo.rounded(.up))
            while Double(mm) <= hi {
                let yy = y(Double(mm))
                var g = Path()
                g.move(to: CGPoint(x: 0, y: yy))
                g.addLine(to: CGPoint(x: size.width, y: yy))
                let strong = names.contains(mm)
                ctx.stroke(g, with: .color(Color.white.opacity(strong ? 0.09 : 0.035)), lineWidth: 1)
                if strong && !overview {
                    let txt = naming == 2 ? NoteMath.solfege(mm) : NoteMath.name(mm)
                    ctx.draw(Text(txt).font(rnd(10, .bold)).foregroundColor(DZ.tx3), at: CGPoint(x: 8, y: yy - 8), anchor: .leading)
                }
                mm += 1
            }

            // اللحن الهدف
            for s in melody.segs {
                let x0 = x(s.start), x1 = x(s.end)
                if x1 < -20 || x0 > size.width + 20 { continue }
                var p = Path()
                p.move(to: CGPoint(x: x0 + 3, y: y(s.from)))
                p.addLine(to: CGPoint(x: x1 - 3, y: y(s.to)))
                let current = !overview && now >= s.start && now < s.end
                let col: Color = current ? DZ.mint : DZ.violet
                ctx.stroke(p, with: .color(col.opacity(0.22)), style: StrokeStyle(lineWidth: overview ? 9 : 18, lineCap: .round))
                ctx.stroke(p, with: .color(col.opacity(s.end < now && !overview ? 0.55 : 0.95)), style: StrokeStyle(lineWidth: overview ? 4 : 7, lineCap: .round))
            }

            // أثر الصوت
            var prev: CGPoint? = nil
            for pt in trail {
                let px = x(pt.t)
                if px < -10 || px > size.width + 10 { prev = nil; continue }
                guard let m = pt.midi else { prev = nil; continue }
                let target = melody.target(at: pt.t)
                let shown: Double
                if let g = target, octaveFree { shown = NoteMath.fold(m, near: g) } else { shown = m }
                let cp = CGPoint(x: px, y: y(shown))
                let col: Color = target.map { DZ.pitchColor((shown - $0) * 100, tol: tol) } ?? Color.white.opacity(0.6)
                if let pr = prev {
                    var seg = Path()
                    seg.move(to: pr)
                    seg.addLine(to: cp)
                    ctx.stroke(seg, with: .color(col), style: StrokeStyle(lineWidth: overview ? 2.5 : 4, lineCap: .round))
                }
                prev = cp
            }

            if !overview {
                // خطّ الآن
                var nl = Path()
                nl.move(to: CGPoint(x: nowX, y: 0))
                nl.addLine(to: CGPoint(x: nowX, y: size.height))
                ctx.stroke(nl, with: .color(Color.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                if let last = trail.last, let m = last.midi, now - last.t < 0.3 {
                    let target = melody.target(at: last.t)
                    let shown = (target != nil && octaveFree) ? NoteMath.fold(m, near: target ?? m) : m
                    let cy = max(8, min(size.height - 8, y(shown)))
                    let col: Color = target.map { DZ.pitchColor((shown - $0) * 100, tol: tol) } ?? Color.white
                    ctx.fill(Path(ellipseIn: CGRect(x: nowX - 14, y: cy - 14, width: 28, height: 28)), with: .color(col.opacity(0.25)))
                    ctx.fill(Path(ellipseIn: CGRect(x: nowX - 7, y: cy - 7, width: 14, height: 14)), with: .color(col))
                }
            }
        }
    }
}
