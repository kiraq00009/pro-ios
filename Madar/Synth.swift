import Foundation
import AVFoundation

/// أصوات مولَّدة بالكود (بدون ملفّات): نغمات قصيرة عبر AVAudioEngine
final class Synth {
    static let shared = Synth()

    enum Wave { case sine, square, tri, noise }
    struct Seg {
        var f0: Double
        var f1: Double
        var dur: Double
        var vol: Double
        var wave: Wave
    }

    private let engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var bufs: [String: AVAudioPCMBuffer] = [:]
    private var idx = 0
    private var ready = false
    private var built = false
    private let rate = 44100.0
    private var format: AVAudioFormat? = nil

    private init() {}

    /// يشغّل المحرّك أوّل مرّة نحتاجه
    func warm() {
        guard !Shot.on, !built else { return }
        built = true
        format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
        guard let f = format else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        for _ in 0..<6 {
            let n = AVAudioPlayerNode()
            engine.attach(n)
            engine.connect(n, to: engine.mainMixerNode, format: f)
            nodes.append(n)
        }
        engine.mainMixerNode.outputVolume = 0.6
        buildAll()
        start()
    }

    private func start() {
        do {
            try engine.start()
            for n in nodes { n.play() }
            ready = true
        } catch {
            ready = false
        }
    }

    func play(_ name: String) {
        guard FX.sound else { return }
        warm()
        guard let b = bufs[name], !nodes.isEmpty else { return }
        if !engine.isRunning { start() }
        guard ready else { return }
        let n = nodes[idx % nodes.count]
        idx += 1
        if !n.isPlaying { n.play() }
        n.scheduleBuffer(b, at: nil, options: .interrupts, completionHandler: nil)
    }

    func perfect(_ combo: Int) { play("perfect\(min(5, max(1, combo)))") }

    private func buildAll() {
        bufs["release"] = make([Seg(f0: 260, f1: 720, dur: 0.12, vol: 0.32, wave: .tri), Seg(f0: 0, f1: 0, dur: 0.06, vol: 0.10, wave: .noise)])
        bufs["catch"] = make([Seg(f0: 520, f1: 540, dur: 0.07, vol: 0.4, wave: .sine), Seg(f0: 780, f1: 800, dur: 0.12, vol: 0.32, wave: .sine)])
        for k in 1...5 {
            let base = 523.25 * pow(2, Double(k - 1) * 2 / 12)
            bufs["perfect\(k)"] = make([
                Seg(f0: base, f1: base, dur: 0.07, vol: 0.34, wave: .tri),
                Seg(f0: base * 1.26, f1: base * 1.26, dur: 0.07, vol: 0.34, wave: .tri),
                Seg(f0: base * 1.5, f1: base * 1.5, dur: 0.08, vol: 0.34, wave: .tri),
                Seg(f0: base * 2, f1: base * 2.02, dur: 0.26, vol: 0.3, wave: .sine),
            ])
        }
        bufs["gem"] = make([Seg(f0: 1320, f1: 1400, dur: 0.05, vol: 0.25, wave: .sine), Seg(f0: 1760, f1: 1900, dur: 0.11, vol: 0.22, wave: .sine)])
        bufs["biggem"] = make([Seg(f0: 990, f1: 990, dur: 0.06, vol: 0.25, wave: .tri), Seg(f0: 1320, f1: 1320, dur: 0.06, vol: 0.25, wave: .tri), Seg(f0: 1980, f1: 2100, dur: 0.18, vol: 0.22, wave: .sine)])
        bufs["warp"] = make([Seg(f0: 180, f1: 1400, dur: 0.38, vol: 0.3, wave: .tri), Seg(f0: 1400, f1: 900, dur: 0.12, vol: 0.2, wave: .sine)])
        bufs["death"] = make([Seg(f0: 0, f1: 0, dur: 0.35, vol: 0.42, wave: .noise), Seg(f0: 140, f1: 38, dur: 0.45, vol: 0.4, wave: .square)])
        bufs["click"] = make([Seg(f0: 900, f1: 1000, dur: 0.035, vol: 0.18, wave: .sine)])
        bufs["zone"] = make([Seg(f0: 392, f1: 392, dur: 0.14, vol: 0.28, wave: .tri), Seg(f0: 587, f1: 587, dur: 0.14, vol: 0.28, wave: .tri), Seg(f0: 784, f1: 790, dur: 0.4, vol: 0.26, wave: .sine)])
        bufs["buy"] = make([Seg(f0: 660, f1: 660, dur: 0.06, vol: 0.25, wave: .tri), Seg(f0: 990, f1: 1000, dur: 0.16, vol: 0.25, wave: .sine)])
        bufs["revive"] = make([Seg(f0: 300, f1: 900, dur: 0.3, vol: 0.3, wave: .sine)])
    }

    private func make(_ segs: [Seg]) -> AVAudioPCMBuffer? {
        guard let f = format else { return nil }
        let total = segs.reduce(0.0) { $0 + $1.dur }
        let n = Int(total * rate) + 1
        guard let buf = AVAudioPCMBuffer(pcmFormat: f, frameCapacity: AVAudioFrameCount(n)) else { return nil }
        guard let ch = buf.floatChannelData?[0] else { return nil }
        var i = 0
        var phase = 0.0
        var seed: UInt32 = 12345
        for s in segs {
            let len = Int(s.dur * rate)
            for k in 0..<len {
                guard i < n else { break }
                let u = Double(k) / Double(max(1, len))
                let fr = s.f0 + (s.f1 - s.f0) * u
                phase += 2 * Double.pi * fr / rate
                var v: Double
                switch s.wave {
                case .sine: v = sin(phase)
                case .square: v = sin(phase) >= 0 ? 0.6 : -0.6
                case .tri: v = 2 / Double.pi * asin(sin(phase))
                case .noise:
                    seed = seed &* 1_103_515_245 &+ 12345
                    v = Double(seed >> 9) / Double(1 << 23) * 2 - 1
                }
                let attack = min(1, Double(k) / (0.004 * rate))
                let decay = exp(-3.2 * u)
                ch[i] = Float(v * s.vol * attack * decay)
                i += 1
            }
        }
        while i < n { ch[i] = 0; i += 1 }
        buf.frameLength = AVAudioFrameCount(n)
        return buf
    }
}
