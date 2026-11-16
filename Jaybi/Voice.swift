import SwiftUI
import Speech
import AVFoundation

/// يسمع الكلام ويحوّله نصّ (تعرّف آبل على الكلام بالعربيّ)
@MainActor
final class JListener: ObservableObject {
    enum St: Equatable { case idle, listening, done, denied, unavailable }

    @Published var text = ""
    @Published var levels: [CGFloat] = Array(repeating: 0.06, count: 26)
    @Published var state: St = .idle

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    private var lastChange = Date()
    private var started = Date()
    private var timer: Timer?

    func start() {
        SFSpeechRecognizer.requestAuthorization { st in
            DispatchQueue.main.async {
                guard st == .authorized else {
                    self.state = .denied
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    DispatchQueue.main.async {
                        if ok { self.begin() } else { self.state = .denied }
                    }
                }
            }
        }
    }

    private func begin() {
        guard let rec = recognizer, rec.isAvailable else {
            state = .unavailable
            return
        }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.record, mode: .measurement, options: .duckOthers)
            try s.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .unavailable
            return
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = false
        request = req

        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            req.append(buf)
            let lvl = JListener.level(buf)
            DispatchQueue.main.async { self?.push(lvl) }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            state = .unavailable
            return
        }
        text = ""
        state = .listening
        lastChange = Date()
        started = Date()

        task = rec.recognitionTask(with: req) { [weak self] res, err in
            let t = res?.bestTranscription.formattedString
            let final = res?.isFinal ?? false
            let failed = err != nil
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let t = t, t != self.text {
                    self.text = t
                    self.lastChange = Date()
                }
                if final || failed { self.finish() }
            }
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.tick() }
        }
    }

    private func tick() {
        guard state == .listening else { return }
        let quiet = Date().timeIntervalSince(lastChange)
        let total = Date().timeIntervalSince(started)
        if (!text.isEmpty && quiet > 1.7) || total > 20 || (text.isEmpty && total > 8) {
            finish()
        }
    }

    private func push(_ l: CGFloat) {
        guard state == .listening else { return }
        levels.removeFirst()
        levels.append(l)
    }

    func finish() {
        guard state == .listening else { return }
        timer?.invalidate()
        timer = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        state = .done
        Haptic.tap()
    }

    func stop() {
        if state == .listening { finish() }
    }

    nonisolated static func level(_ b: AVAudioPCMBuffer) -> CGFloat {
        guard let ch = b.floatChannelData?[0] else { return 0 }
        let n = Int(b.frameLength)
        if n == 0 { return 0 }
        var s: Float = 0
        for i in 0..<n { s += ch[i] * ch[i] }
        let rms = sqrt(s / Float(n))
        let db = 20 * log10(max(rms, 0.000_001))
        let v = (db + 52) / 46
        return CGFloat(min(1, max(0.04, v)))
    }
}

/// شاشة «احچي»
struct JVoiceView: View {
    @EnvironmentObject var store: JStore
    @Environment(\.dismiss) private var dismiss
    var onSaved: (Expense) -> Void

    @StateObject private var mic = JListener()
    @State private var editing = false
    @State private var demoText = ""

    private var spoken: String { Shot.on ? demoText : mic.text }
    private var isDone: Bool { Shot.on ? true : mic.state == .done }
    private var draft: Draft { SpeechParse.parse(spoken) }

    var body: some View {
        if editing {
            JEditor(existing: nil, draft: draft, via: .voice, onSaved: onSaved)
                .environmentObject(store)
        } else {
            main
        }
    }

    private var main: some View {
        ZStack {
            JB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("إلغاء") {
                        mic.stop()
                        dismiss()
                    }
                    .font(rnd(16, .medium)).foregroundColor(JB.tx2)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                Text(statusText).font(rnd(14)).foregroundColor(JB.tx2).padding(.top, 18)

                JWave(levels: Shot.on ? JWave.demo : mic.levels, active: !isDone)
                    .frame(height: 96)
                    .padding(.vertical, 22)

                transcript
                    .padding(.horizontal, 24)

                Spacer(minLength: 12)

                if isDone {
                    resultCard
                        .padding(.horizontal, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if mic.state == .listening {
                    stopButton
                }
                bottomHint
            }
            .padding(.bottom, 14)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isDone)
        .onAppear {
            if Shot.on {
                demoText = "صرفت خمسة وعشرين ألف على العشا ويّا الربع"
            } else {
                mic.start()
            }
        }
        .onDisappear { mic.stop() }
    }

    private var statusText: String {
        if Shot.on { return "تمام، هذا اللي فهمته" }
        switch mic.state {
        case .idle: return "لحظة…"
        case .listening: return "ديسمع… احچي طبيعي"
        case .done: return spoken.isEmpty ? "ما سمعت شي" : "تمام، هذا اللي فهمته"
        case .denied: return "يحتاج إذن المايك والتعرّف على الكلام"
        case .unavailable: return "التعرّف على الكلام مو متوفّر هسه"
        }
    }

    @ViewBuilder
    private var transcript: some View {
        if spoken.isEmpty {
            Text(mic.state == .denied ? "افتح الإعدادات ← جيبي ← فعّل المايك والتعرّف على الكلام." : "گول مثلًا:\n«دفعت ثمن آلاف تكسي»\n«رصيد خمس تالاف»")
                .font(rnd(19, .medium))
                .foregroundColor(JB.tx2.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        } else {
            Text("«" + spoken + "»")
                .font(rnd(24, .semibold))
                .foregroundColor(JB.tx)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .minimumScaleFactor(0.6)
        }
    }

    private var stopButton: some View {
        Button {
            mic.stop()
        } label: {
            ZStack {
                Circle().fill(JB.mint.opacity(0.15)).frame(width: 92, height: 92)
                Circle().fill(JB.mintGrad).frame(width: 70, height: 70)
                RoundedRectangle(cornerRadius: 6).fill(JB.mintInk).frame(width: 22, height: 22)
            }
        }
        .buttonStyle(Press())
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var resultCard: some View {
        let d = draft
        if spoken.isEmpty || d.amount == nil {
            VStack(spacing: 12) {
                Text(spoken.isEmpty ? "ما سمعت شي، جرّب مرّة ثانية" : "فهمت الكلام بس ما لگيت المبلغ")
                    .font(rnd(16, .semibold)).foregroundColor(JB.tx)
                HStack(spacing: 10) {
                    JPlainButton(title: "اكتب بإيدي", system: "keyboard") { editing = true }
                    JMintButton(title: "عيد", system: "mic.fill") { mic.start() }
                }
            }
            .padding(18)
            .card(JB.card, 24)
        } else {
            VStack(spacing: 0) {
                JKV(k: "المبلغ", v: Money.s(d.amount ?? 0) + " " + store.currency, strong: true)
                JKV(k: "الصنف", v: Cats.get(d.cat).emoji + " " + Cats.get(d.cat).name)
                JKV(k: "الوقت", v: d.dayOffset == 0 ? "اليوم، " + JDate.time(Date()) : (d.dayOffset == -1 ? "البارحة" : "قبل يومين"))
                JKV(k: "الملاحظة", v: d.note, last: true)
                HStack(spacing: 10) {
                    JPlainButton(title: "عدّل", system: "pencil") { editing = true }
                    JMintButton(title: "احفظ", system: "checkmark") { saveDraft(d) }
                }
                .padding(.top, 14)
            }
            .padding(18)
            .card(JB.card, 24)
        }
    }

    private var bottomHint: some View {
        Text("الكلام ينفهم على جهاز آبل، وجيبي ما يحفظ صوتك.")
            .font(rnd(11.5)).foregroundColor(JB.tx2.opacity(0.6))
            .padding(.top, 12)
    }

    private func saveDraft(_ d: Draft) {
        guard let a = d.amount, a > 0 else { return }
        var date = Date()
        if d.dayOffset != 0 { date = Calendar.current.date(byAdding: .day, value: d.dayOffset, to: date) ?? date }
        let e = Expense(amount: a, cat: d.cat, note: d.note, date: date, via: .voice)
        store.add(e)
        onSaved(e)
        dismiss()
    }
}

struct JKV: View {
    var k: String
    var v: String
    var strong = false
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(k).font(rnd(14.5)).foregroundColor(JB.tx2)
                Spacer()
                Text(v).font(rnd(strong ? 17 : 15, .bold)).foregroundColor(strong ? JB.mint : JB.tx).lineLimit(1)
            }
            .padding(.vertical, 10)
            if !last { Rectangle().fill(JB.line).frame(height: 1) }
        }
    }
}

struct JMintButton: View {
    var title: String
    var system: String
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            Label(title, systemImage: system)
                .font(rnd(16, .bold))
                .foregroundColor(JB.mintInk)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(JB.mintGrad, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(Press())
    }
}

struct JPlainButton: View {
    var title: String
    var system: String
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            Label(title, systemImage: system)
                .font(rnd(16, .bold))
                .foregroundColor(JB.tx)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(JB.card2, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(Press())
    }
}

/// موجة الصوت
struct JWave: View {
    var levels: [CGFloat]
    var active: Bool

    static let demo: [CGFloat] = [0.2, 0.45, 0.72, 0.4, 0.85, 0.58, 0.32, 0.66, 0.92, 0.5, 0.26, 0.55, 0.36, 0.18, 0.3, 0.62, 0.8, 0.44, 0.7, 0.35, 0.22, 0.48, 0.6, 0.28, 0.14, 0.1]

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(Array(levels.enumerated()), id: \.offset) { item in
                Capsule()
                    .fill(JB.mint.opacity(active ? 1 : 0.55))
                    .frame(width: 6, height: max(6, 92 * item.element))
            }
        }
        .animation(.easeOut(duration: 0.12), value: levels)
        .environment(\.layoutDirection, .leftToRight)
    }
}
