import Foundation
import AVFoundation

enum DZAudioSession {
    private static var configured = false

    static func configure() {
        if configured || Shot.on { return }
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
            try s.setActive(true)
            configured = true
        } catch {
            configured = false
        }
    }
}

/// يجمع عيّنات المايك ويشغّل YIN على خيط خلفيّ
final class PitchAnalyzer {
    private let queue = DispatchQueue(label: "dozan.pitch", qos: .userInteractive)
    private var ring: [Float] = []
    private var fresh = 0
    private var yin = YIN(sampleRate: 44100)
    let window = 4096
    let hop = 1536
    var onResult: ((PitchReading?, Double) -> Void)?

    func setSampleRate(_ sr: Double) {
        queue.async { self.yin = YIN(sampleRate: sr); self.ring.removeAll(); self.fresh = 0 }
    }

    func ingest(_ samples: [Float]) {
        queue.async {
            self.ring.append(contentsOf: samples)
            self.fresh += samples.count
            if self.ring.count > self.window { self.ring.removeFirst(self.ring.count - self.window) }
            guard self.ring.count >= self.window, self.fresh >= self.hop else { return }
            self.fresh = 0
            let frame = self.ring
            let level = YIN.rms(frame)
            let r = self.yin.detect(frame)
            let cb = self.onResult
            DispatchQueue.main.async { cb?(r, level) }
        }
    }
}

/// المايك + كشف الطبقة. يشتغل لمّا شاشة تحتاجه (عدّاد مستخدمين)
final class MicPitch: ObservableObject {
    @Published var midi: Double? = nil
    @Published var freq: Double? = nil
    @Published var confidence: Double = 0
    @Published var level: Double = 0
    @Published var running = false
    @Published var denied = false
    @Published var failed = false

    var a4: Double = 440 {
        didSet { tracker.a4 = a4; tracker.reset() }
    }

    private var tracker = PitchTracker()
    private let engine = AVAudioEngine()
    private let analyzer = PitchAnalyzer()
    private var users = 0
    private var demoTimer: Timer?
    private var demoT: Double = 0
    private var demoFn: ((Double) -> Double?)?

    init() {
        analyzer.onResult = { [weak self] r, lvl in self?.apply(r, lvl) }
    }

    var permissionGranted: Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func requestPermission(_ done: @escaping (Bool) -> Void) {
        if Shot.on { done(true); return }
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
            DispatchQueue.main.async {
                self.denied = !ok
                done(ok)
            }
        }
    }

    func acquire() {
        users += 1
        if users == 1 { start() }
    }

    func release() {
        users = max(0, users - 1)
        if users == 0 { stop() }
    }

    private func start() {
        if Shot.on { return }
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            begin()
        case .denied:
            denied = true
        case .undetermined:
            requestPermission { [weak self] ok in
                guard let self = self else { return }
                if ok && self.users > 0 { self.begin() }
            }
        @unknown default:
            denied = true
        }
    }

    private func begin() {
        guard !engine.isRunning else { running = true; return }
        DZAudioSession.configure()
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0, fmt.channelCount > 0 else { failed = true; return }
        analyzer.setSampleRate(fmt.sampleRate)
        input.removeTap(onBus: 0)
        let an = analyzer
        input.installTap(onBus: 0, bufferSize: 2048, format: fmt) { buf, _ in
            guard let ch = buf.floatChannelData else { return }
            let n = Int(buf.frameLength)
            if n <= 0 { return }
            let arr = Array(UnsafeBufferPointer(start: ch[0], count: n))
            an.ingest(arr)
        }
        engine.prepare()
        do {
            try engine.start()
            running = true
            failed = false
            denied = false
        } catch {
            input.removeTap(onBus: 0)
            failed = true
            running = false
        }
    }

    private func stop() {
        demoTimer?.invalidate()
        demoTimer = nil
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        running = false
        tracker.reset()
        midi = nil
        freq = nil
        level = 0
    }

    private func apply(_ r: PitchReading?, _ lvl: Double) {
        guard running else { return }
        level = level * 0.5 + min(1, lvl * 6) * 0.5
        let m = tracker.push(r)
        if midi != m { midi = m }
        freq = m.map { NoteMath.freq(midi: $0, a4: a4) }
        confidence = r?.confidence ?? 0
    }

    // MARK: وضع العرض: تيّار نغمات مُحاكى
    func startDemo(_ fn: @escaping (Double) -> Double?) {
        demoFn = fn
        demoT = 0
        running = true
        demoTimer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.demoTick() }
        RunLoop.main.add(t, forMode: .common)
        demoTimer = t
        demoTick()
    }

    private func demoTick() {
        demoT += 1.0 / 30
        let m = demoFn?(demoT)
        midi = m
        freq = m.map { NoteMath.freq(midi: $0, a4: a4) }
        confidence = m == nil ? 0 : 0.96
        level = m == nil ? 0.05 : 0.55 + 0.25 * sin(demoT * 7)
    }
}

/// حالة المولّد تُقرأ من خيط الصوت (محميّة بقفل غير حاجز)
final class SynthState {
    let lock = NSLock()
    var sampleRate: Double = 44100
    var volume: Double = 0.8
    var timbre: Int = 1
    // نغمة مرجعيّة
    var toneTarget: Double = 0
    var toneFreq: Double = 440
    var amp: Double = 0
    var phase: Double = 0
    // لحن
    var melody: [TargetSeg] = []
    var melodyA4: Double = 440
    var melodyEnd: Double = 0
    var melodyClock: Int = -1
    // مترونوم
    var metroOn = false
    var metroInterval: Int = 29400
    var metroCount: Int = 0
    var beatsPerBar: Int = 4
    var beatCounter: Int = 0
    var clickEnv: Double = 0
    var clickPhase: Double = 0
    var clickFreq: Double = 1500
    var clickGain: Double = 1

    private func voice(_ p: Double) -> Double {
        switch timbre {
        case 0: return sin(p)
        case 2: return (sin(p) + sin(3 * p) / 3 + sin(5 * p) / 5) * 0.8
        default: return sin(p) * 0.74 + sin(2 * p) * 0.2 + sin(3 * p) * 0.06
        }
    }

    func render(_ n: Int, _ out: UnsafeMutablePointer<Float>) {
        guard lock.try() else {
            for i in 0..<n { out[i] = 0 }
            return
        }
        defer { lock.unlock() }
        let sr = sampleRate
        let twoPi = 2 * Double.pi
        for i in 0..<n {
            var target = toneTarget
            var f = toneFreq
            if melodyClock >= 0 {
                let t = Double(melodyClock) / sr
                melodyClock += 1
                var found = false
                for s in melody where t >= s.start && t < s.end {
                    f = melodyA4 * pow(2, (s.midi(at: t) - 69) / 12)
                    found = true
                    break
                }
                target = found ? 0.34 : 0
                if t > melodyEnd + 0.4 { melodyClock = -1 }
            }
            amp += (target - amp) * 0.0016
            var v = 0.0
            if amp > 0.0001 {
                phase += twoPi * f / sr
                if phase > twoPi { phase -= twoPi }
                v = voice(phase) * amp
            }
            if metroOn {
                if metroCount <= 0 {
                    let accent = beatCounter % max(1, beatsPerBar) == 0
                    clickFreq = accent ? 1760 : 1180
                    clickGain = accent ? 0.9 : 0.55
                    clickEnv = 1
                    clickPhase = 0
                    beatCounter += 1
                    metroCount = metroInterval
                }
                metroCount -= 1
            }
            if clickEnv > 0.0005 {
                clickPhase += twoPi * clickFreq / sr
                v += sin(clickPhase) * clickEnv * clickGain * 0.6
                clickEnv *= 0.9982
            }
            let s = max(-1, min(1, v * volume))
            out[i] = Float(s)
        }
    }
}

/// مولّد النغمات + اللحن المرشد + المترونوم (AVAudioSourceNode)
final class ToneEngine: ObservableObject {
    @Published var tonePlaying = false
    @Published var melodyPlaying = false
    @Published var metroOn = false
    @Published var bpm: Double = 90
    @Published var beatsPerBar: Int = 4

    let state = SynthState()
    private var engine: AVAudioEngine?
    private var melodyTimer: Timer?

    private func ensure() -> Bool {
        if Shot.on { return false }
        if let e = engine, e.isRunning { return true }
        DZAudioSession.configure()
        let e = engine ?? AVAudioEngine()
        if engine == nil {
            let outFmt = e.outputNode.outputFormat(forBus: 0)
            let sr = outFmt.sampleRate > 0 ? outFmt.sampleRate : 44100
            state.sampleRate = sr
            let st = state
            let src = AVAudioSourceNode { _, _, frameCount, abl -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(abl)
                let n = Int(frameCount)
                if buffers.count == 0 { return noErr }
                guard let base = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
                st.render(n, base)
                if buffers.count > 1 {
                    for b in 1..<buffers.count {
                        if let d = buffers[b].mData?.assumingMemoryBound(to: Float.self) {
                            for i in 0..<n { d[i] = base[i] }
                        }
                    }
                }
                return noErr
            }
            let fmtOpt: AVAudioFormat? = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)
            guard let fmt = fmtOpt else { return false }
            e.attach(src)
            e.connect(src, to: e.mainMixerNode, format: fmt)
            engine = e
        }
        e.prepare()
        do { try e.start(); return true } catch { return false }
    }

    func setTimbre(_ t: Int) {
        state.lock.lock(); state.timbre = t; state.lock.unlock()
    }

    func playTone(midi: Double, a4: Double) {
        let f = NoteMath.freq(midi: midi, a4: a4)
        state.lock.lock()
        state.melodyClock = -1
        state.toneFreq = f
        state.toneTarget = 0.42
        state.lock.unlock()
        tonePlaying = true
        melodyPlaying = false
        _ = ensure()
    }

    func stopTone() {
        state.lock.lock(); state.toneTarget = 0; state.lock.unlock()
        tonePlaying = false
    }

    /// نغمة قصيرة (مثلًا لمّا تضغط على وتر)
    func blip(midi: Double, a4: Double, seconds: Double = 1.1) {
        let m = Melody(segs: [TargetSeg(start: 0, dur: seconds, from: midi, to: midi)])
        playMelody(m, a4: a4)
    }

    func playMelody(_ m: Melody, a4: Double) {
        state.lock.lock()
        state.toneTarget = 0
        state.melody = m.segs
        state.melodyA4 = a4
        state.melodyEnd = m.duration
        state.melodyClock = 0
        state.lock.unlock()
        tonePlaying = false
        melodyPlaying = true
        _ = ensure()
        melodyTimer?.invalidate()
        let t = Timer(timeInterval: m.duration + 0.3, repeats: false) { [weak self] _ in self?.melodyPlaying = false }
        RunLoop.main.add(t, forMode: .common)
        melodyTimer = t
    }

    func stopMelody() {
        state.lock.lock(); state.melodyClock = -1; state.lock.unlock()
        melodyPlaying = false
    }

    func setBPM(_ b: Double) {
        bpm = min(240, max(30, b.rounded()))
        state.lock.lock()
        state.metroInterval = max(1000, Int(state.sampleRate * Metronome.interval(bpm: bpm)))
        state.lock.unlock()
    }

    func setBeats(_ n: Int) {
        beatsPerBar = n
        state.lock.lock(); state.beatsPerBar = n; state.lock.unlock()
    }

    func startMetro() {
        metroOn = true
        _ = ensure()
        state.lock.lock()
        state.metroInterval = max(1000, Int(state.sampleRate * Metronome.interval(bpm: bpm)))
        state.beatsPerBar = beatsPerBar
        state.beatCounter = 0
        state.metroCount = 0
        state.metroOn = true
        state.lock.unlock()
    }

    func stopMetro() {
        metroOn = false
        state.lock.lock(); state.metroOn = false; state.lock.unlock()
    }

    var beatCounter: Int { state.beatCounter }

    func stopAll() {
        stopTone()
        stopMelody()
        stopMetro()
    }
}
