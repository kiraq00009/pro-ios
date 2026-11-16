import Foundation
import AVFoundation

/// مركّب أصوات بسيط: نوتات تتصاعد مع السلسلة — كلّها تتولّد بالكود بلا ملفّات
final class Synth {
    static let shared = Synth()
    var enabled = true

    private let engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var notes: [AVAudioPCMBuffer] = []
    private var fireBuf: AVAudioPCMBuffer?
    private var boomBuf: AVAudioPCMBuffer?
    private var clinkBuf: AVAudioPCMBuffer?
    private var badBuf: AVAudioPCMBuffer?
    private var winBuf: AVAudioPCMBuffer?
    private var loseBuf: AVAudioPCMBuffer?
    private var tickBuf: AVAudioPCMBuffer?
    private var idx = 0
    private var ready = false
    private let sr = 44100.0
    private var lastNote = 0.0

    func start() {
        if ready || Shot.on { return }
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1) else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        for _ in 0..<12 {
            let n = AVAudioPlayerNode()
            engine.attach(n)
            engine.connect(n, to: engine.mainMixerNode, format: fmt)
            nodes.append(n)
        }
        // سلّم خماسيّ يصعد ٤ أوكتافات
        let scale = [0, 2, 4, 7, 9]
        for i in 0..<22 {
            let semis = Double(scale[i % 5] + 12 * (i / 5))
            let f = 196.0 * pow(2, semis / 12)
            if let b = tone(fmt, dur: 0.7, { t in Synth.pluck(t, f) }) { notes.append(b) }
        }
        fireBuf = tone(fmt, dur: 0.45) { t in
            let f = 900 * exp(-t * 7) + 120
            return sin(2 * Double.pi * f * t) * exp(-t * 7) * 0.5 + Synth.noise(t) * exp(-t * 22) * 0.25
        }
        boomBuf = tone(fmt, dur: 0.6) { t in
            let f = 90 * exp(-t * 3) + 40
            return sin(2 * Double.pi * f * t) * exp(-t * 5) * 0.7 + Synth.noise(t) * exp(-t * 12) * 0.2
        }
        clinkBuf = tone(fmt, dur: 0.35) { t in
            (sin(2 * Double.pi * 2400 * t) * 0.5 + sin(2 * Double.pi * 3170 * t) * 0.3) * exp(-t * 16) * 0.5
        }
        badBuf = tone(fmt, dur: 0.5) { t in
            let f = 180 - 90 * t
            return (sin(2 * Double.pi * f * t) + 0.5 * sin(2 * Double.pi * f * 1.06 * t)) * exp(-t * 5) * 0.4
        }
        tickBuf = tone(fmt, dur: 0.08) { t in sin(2 * Double.pi * 1800 * t) * exp(-t * 60) * 0.4 }
        winBuf = tone(fmt, dur: 1.3) { t in
            let fs = [523.25, 659.25, 783.99, 1046.5]
            var v = 0.0
            for (k, f) in fs.enumerated() {
                let st = Double(k) * 0.11
                if t > st { v += Synth.pluck(t - st, f) * 0.6 }
            }
            return v
        }
        loseBuf = tone(fmt, dur: 1.0) { t in
            let fs = [392.0, 329.63, 261.63]
            var v = 0.0
            for (k, f) in fs.enumerated() {
                let st = Double(k) * 0.16
                if t > st { v += Synth.pluck(t - st, f) * 0.5 }
            }
            return v
        }
        engine.mainMixerNode.outputVolume = 0.85
        do {
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
    }

    static func pluck(_ t: Double, _ f: Double) -> Double {
        let att = min(1, t * 300)
        let a = sin(2 * Double.pi * f * t) * exp(-t * 5)
        let b = sin(2 * Double.pi * f * 2 * t) * exp(-t * 9) * 0.35
        let c = sin(2 * Double.pi * f * 3 * t) * exp(-t * 15) * 0.15
        return (a + b + c) * att * 0.33
    }

    static func noise(_ t: Double) -> Double {
        let x = sin(t * 12_989.8 + 78.233) * 43_758.5453
        return (x - x.rounded(.down)) * 2 - 1
    }

    private func tone(_ fmt: AVAudioFormat, dur: Double, _ f: (Double) -> Double) -> AVAudioPCMBuffer? {
        let n = AVAudioFrameCount(sr * dur)
        guard let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n), let ch = b.floatChannelData else { return nil }
        b.frameLength = n
        let p = ch[0]
        let count = Int(n)
        for i in 0..<count {
            let t = Double(i) / sr
            let fadeOut = min(1, Double(count - i) / 400)
            p[i] = Float(f(t) * fadeOut)
        }
        return b
    }

    private func play(_ b: AVAudioPCMBuffer?, _ vol: Float) {
        guard enabled, ready, let b = b, !nodes.isEmpty else { return }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        let n = nodes[idx % nodes.count]
        idx += 1
        n.volume = vol
        n.scheduleBuffer(b, at: nil, options: .interrupts, completionHandler: nil)
        if !n.isPlaying { n.play() }
    }

    /// نوتة الحلقة رقم link — تصعد مع السلسلة
    func note(_ link: Int, now: Double) {
        if notes.isEmpty { return }
        if now - lastNote < 0.035 { return }
        lastNote = now
        let i = min(max(0, link - 1), notes.count - 1)
        play(notes[i], 0.75)
    }
    func fire() { play(fireBuf, 0.8) }
    func boom() { play(boomBuf, 0.9) }
    func clink() { play(clinkBuf, 0.6) }
    func bad() { play(badBuf, 0.8) }
    func tick() { play(tickBuf, 0.5) }
    func win() { play(winBuf, 0.8) }
    func lose() { play(loseBuf, 0.7) }
}
