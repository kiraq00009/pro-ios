import Foundation
import AVFoundation
import SoundAnalysis

/// يستلم نتائج المصنّف ويحوّلها لـ Hit
final class ResultsSink: NSObject, SNResultsObserving {
    var onHits: (([Hit]) -> Void)?

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let r = result as? SNClassificationResult else { return }
        var hits: [Hit] = []
        hits.reserveCapacity(r.classifications.count)
        for c in r.classifications { hits.append(Hit(id: c.identifier, conf: c.confidence)) }
        hits.sort { $0.conf > $1.conf }
        onHits?(Array(hits.prefix(12)))
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {}
    func requestDidComplete(_ request: SNRequest) {}
}

/// المايك + المصنّف + مخزن آخر ١٠ ثواني (للمقاطع). كلّ الشغل على طابور الصوت
final class AudioCore {
    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private let sink = ResultsSink()
    private let q = DispatchQueue(label: "samaa.audio", qos: .userInitiated)
    private var ring = Ring<Float>(capacity: 1, fill: 0)
    private(set) var sampleRate: Double = 48000
    private(set) var active = false

    /// تُستدعى على طابور الصوت
    var onHits: (([Hit]) -> Void)?
    /// rms + مدّة الدفعة بالثواني
    var onLevel: ((Double, Double) -> Void)?

    static let ringSeconds = 10.0

    func start() throws {
        if active { return }
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
        try s.setActive(true)
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0, fmt.channelCount > 0 else {
            throw NSError(domain: "samaa", code: 1, userInfo: [NSLocalizedDescriptionKey: "ماكو مايك متاح"])
        }
        sampleRate = fmt.sampleRate
        let cap = Int(fmt.sampleRate * AudioCore.ringSeconds)
        q.sync { self.ring = Ring<Float>(capacity: cap, fill: 0) }

        let a = SNAudioStreamAnalyzer(format: fmt)
        let req = try SNClassifySoundRequest(classifierIdentifier: .version1)
        req.overlapFactor = 0.5
        sink.onHits = { [weak self] h in self?.onHits?(h) }
        try a.add(req, withObserver: sink)
        analyzer = a

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { [weak self] buf, when in
            self?.ingest(buf, when.sampleTime)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            analyzer = nil
            throw error
        }
        active = true
    }

    func stop() {
        guard active else { return }
        active = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let a = analyzer
        analyzer = nil
        q.async { a?.removeAllRequests() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func ingest(_ buf: AVAudioPCMBuffer, _ pos: AVAudioFramePosition) {
        let n = Int(buf.frameLength)
        guard n > 0, let ch = buf.floatChannelData else { return }
        let samples = Array(UnsafeBufferPointer(start: ch[0], count: n))
        let dt = Double(n) / max(1, buf.format.sampleRate)
        q.async { [weak self] in
            guard let self = self else { return }
            self.ring.append(contentsOf: samples)
            self.analyzer?.analyze(buf, atAudioFramePosition: pos)
            self.onLevel?(Level.rms(samples), dt)
        }
    }

    /// يحفظ آخر `seconds` ثانية بعد `delay` ثانية (حتى يشمل اللي صار قبل وبعد الحدث)
    func saveClip(to url: URL, seconds: Double, delay: Double, done: @escaping (Bool) -> Void) {
        q.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { done(false); return }
            let n = Int(self.sampleRate * seconds)
            let raw = self.ring.last(n)
            let f = ClipMath.factor(sampleRate: self.sampleRate)
            let small = ClipMath.normalize(ClipMath.decimate(raw, factor: f))
            let ok = AudioCore.write(small, rate: self.sampleRate / Double(f), url: url)
            done(ok)
        }
    }

    static func write(_ s: [Float], rate: Double, url: URL) -> Bool {
        guard !s.isEmpty,
              let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(s.count)),
              let ch = buf.floatChannelData else { return false }
        buf.frameLength = AVAudioFrameCount(s.count)
        let p = ch[0]
        for i in 0..<s.count { p[i] = s[i] }
        do {
            try? FileManager.default.removeItem(at: url)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: rate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ]
            let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buf)
            return true
        } catch {
            return false
        }
    }
}

/// تشغيل المقاطع المحفوظة
@MainActor
final class ClipPlayer: NSObject, ObservableObject {
    @Published var playing: String? = nil
    @Published var progress: Double = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?

    nonisolated static let dir: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    nonisolated static func url(_ name: String) -> URL { dir.appendingPathComponent(name) }
    nonisolated static func exists(_ name: String?) -> Bool {
        guard let n = name else { return false }
        return FileManager.default.fileExists(atPath: url(n).path)
    }

    func toggle(_ name: String) {
        if playing == name { stop(); return }
        stop()
        guard ClipPlayer.exists(name) else { Haptic.bad(); return }
        let s = AVAudioSession.sharedInstance()
        if s.category != .playAndRecord {
            try? s.setCategory(.playback, mode: .default)
        }
        try? s.setActive(true)
        guard let p = try? AVAudioPlayer(contentsOf: ClipPlayer.url(name)) else { Haptic.bad(); return }
        p.delegate = self
        p.volume = 1
        p.play()
        player = p
        playing = name
        progress = 0
        Haptic.tap()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let p = player, p.duration > 0 else { return }
        progress = min(1, p.currentTime / p.duration)
    }

    func stop() {
        timer?.invalidate(); timer = nil
        player?.stop(); player = nil
        playing = nil
        progress = 0
    }
}

extension ClipPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}

enum Mic {
    static var state: MicState {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .unknown
        @unknown default: return .unknown
        }
    }

    static func request(_ done: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { ok in done(ok) }
    }
}

enum MicState { case unknown, granted, denied }
