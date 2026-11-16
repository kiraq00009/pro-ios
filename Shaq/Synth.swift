import Foundation
import AVFoundation

/// أصوات مركّبة بالكود (بلا ملفّات): شفرة، قطع، مثالي، فشل، عملة…
final class Synth {
    static let shared = Synth()
    var enabled = true

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private let format: AVAudioFormat?
    private var started = false
    private let rate = 44100.0

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
    }

    func start() {
        guard !started, !Shot.on, let f = format else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: f)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.8
        do {
            try engine.start()
            started = true
        } catch {
            started = false
            return
        }
        build()
        for p in players { p.play() }
    }

    func play(_ name: String, _ volume: Float = 1) {
        guard enabled, started, !players.isEmpty, let b = buffers[name] else { return }
        let p = players[next % players.count]
        next += 1
        p.volume = volume
        p.stop()
        p.scheduleBuffer(b, at: nil, options: [], completionHandler: nil)
        p.play()
    }

    // MARK: التركيب

    private func make(_ dur: Double, _ f: (Double, Double) -> Double) -> AVAudioPCMBuffer? {
        guard let fm = format else { return nil }
        let n = AVAudioFrameCount(max(1, dur * rate))
        guard let b = AVAudioPCMBuffer(pcmFormat: fm, frameCapacity: n), let ch = b.floatChannelData else { return nil }
        b.frameLength = n
        let out = ch[0]
        for i in 0..<Int(n) {
            let t = Double(i) / rate
            let v = f(t, t / dur)
            out[i] = Float(max(-1, min(1, v)))
        }
        return b
    }

    private func tone(_ f: Double, _ t: Double) -> Double { sin(2 * Double.pi * f * t) }
    /// نغمة تنزلق من f0 إلى f1 خلال dur
    private func glide(_ f0: Double, _ f1: Double, _ t: Double, _ dur: Double) -> Double {
        sin(2 * Double.pi * (f0 * t + (f1 - f0) * t * t / (2 * dur)))
    }

    private func build() {
        var seed: UInt64 = 0x1234567
        func noise() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(Int64(bitPattern: seed >> 1) % 2000) / 1000 - 1
        }
        // نفخة الشفرة: ضوضاء مفلترة بغلاف صاعد نازل
        var lp = 0.0
        buffers["swish"] = make(0.2) { t, u in
            let env = sin(Double.pi * u) * (1 - u * 0.4)
            let a = 0.12 + 0.5 * u
            lp += a * (noise() - lp)
            return lp * env * 0.9
        }
        // القطع: صفير معدنيّ نازل + طقّة
        buffers["slice"] = make(0.22) { t, u in
            let click = t < 0.004 ? noise() * 0.8 : 0
            return click + self.glide(2400, 900, t, 0.22) * pow(1 - u, 3) * 0.45
        }
        buffers["good"] = make(0.32) { t, u in
            let e = pow(1 - u, 2)
            let f = t < 0.1 ? 784.0 : 1046.5
            return self.tone(f, t) * e * 0.35 + self.tone(f * 2, t) * e * 0.08
        }
        // مثالي: أربيجيو لامع
        buffers["perfect"] = make(0.9) { t, u in
            let notes: [Double] = [1046.5, 1318.5, 1568.0, 2093.0]
            var v = 0.0
            for (k, f) in notes.enumerated() {
                let st = Double(k) * 0.07
                if t >= st {
                    let tt = t - st
                    v += self.tone(f, tt) * exp(-tt * 5) * 0.22 + self.tone(f * 3, tt) * exp(-tt * 9) * 0.04
                }
            }
            return v * (1 - u * 0.3)
        }
        buffers["miss"] = make(0.4) { t, u in
            self.glide(180, 60, t, 0.4) * pow(1 - u, 2) * 0.7 + noise() * exp(-t * 30) * 0.2
        }
        buffers["nail"] = make(0.5) { t, u in
            let e = exp(-t * 9)
            return (self.tone(420, t) * 0.4 + self.tone(1130, t) * 0.3 + self.tone(2710, t) * 0.15) * e + noise() * exp(-t * 60) * 0.4
        }
        buffers["coin"] = make(0.35) { t, u in
            let f = t < 0.08 ? 1318.5 : 1760.0
            return self.tone(f, t) * exp(-t * 7) * 0.4
        }
        buffers["tick"] = make(0.05) { t, u in self.tone(1250, t) * (1 - u) * 0.3 }
        buffers["tap"] = make(0.06) { t, u in self.tone(620, t) * pow(1 - u, 2) * 0.25 }
        buffers["combo"] = make(0.5) { t, u in
            let f = 660 * pow(2, floor(t / 0.08) / 6)
            return self.tone(f, t) * (1 - u) * 0.28
        }
        buffers["win"] = make(1.2) { t, u in
            let notes: [Double] = [523.25, 659.25, 783.99, 1046.5, 1318.5]
            var v = 0.0
            for (k, f) in notes.enumerated() {
                let st = Double(k) * 0.12
                if t >= st { let tt = t - st; v += self.tone(f, tt) * exp(-tt * 3.2) * 0.18 }
            }
            return v
        }
    }
}
