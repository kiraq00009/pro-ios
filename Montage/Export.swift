import UIKit
import AVFoundation
import QuartzCore

/// يحرق الترجمة على الفيديو بالموبايل نفسه (بلا رفع الفيديو لأيّ مكان)
enum Burner {
    struct Fail: LocalizedError { let msg: String; var errorDescription: String? { msg } }

    static func uiColor(_ hex: Int, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }

    static func font(_ size: CGFloat, _ look: Look) -> UIFont {
        switch look {
        case .cinema: return UIFont.systemFont(ofSize: size, weight: .semibold)
        case .classic: return UIFont.systemFont(ofSize: size, weight: .bold)
        default: return UIFont.systemFont(ofSize: size, weight: .heavy)
        }
    }

    /// نصّ منسّق: لون + حدّ أسود + ظلّ حسب الستايل، وكلمة مميّزة اختياريًّا
    static func attributed(_ text: String, style: Style, size: CGFloat, highlight: Int? = nil, dim: Bool = false) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        p.baseWritingDirection = .natural
        p.lineBreakMode = .byWordWrapping
        let base = uiColor(style.color, dim ? 0.78 : 1)
        var attrs: [NSAttributedString.Key: Any] = [.font: font(size, style.look), .foregroundColor: base, .paragraphStyle: p]
        switch style.look {
        case .tiktok, .classic:
            attrs[.strokeColor] = UIColor.black
            attrs[.strokeWidth] = style.look == .tiktok ? -7.0 : -4.0
        case .neon:
            attrs[.foregroundColor] = UIColor.white
            let sh = NSShadow(); sh.shadowColor = uiColor(style.accent); sh.shadowBlurRadius = size * 0.45; sh.shadowOffset = .zero
            attrs[.shadow] = sh
        case .cinema:
            let sh = NSShadow(); sh.shadowColor = UIColor.black.withAlphaComponent(0.9); sh.shadowBlurRadius = size * 0.18; sh.shadowOffset = CGSize(width: 0, height: size * 0.05)
            attrs[.shadow] = sh
        case .box:
            break
        }
        let s = NSMutableAttributedString(string: text, attributes: attrs)
        if let h = highlight {
            let words = text.split(separator: " ", omittingEmptySubsequences: false)
            var loc = 0
            for (i, w) in words.enumerated() {
                let len = (String(w) as NSString).length
                if i == h { s.addAttribute(.foregroundColor, value: uiColor(style.accent), range: NSRange(location: loc, length: len)) }
                loc += len + 1
            }
        }
        return s
    }

    static func measure(_ s: NSAttributedString, width: CGFloat) -> CGSize {
        let r = s.boundingRect(with: CGSize(width: width, height: 10_000), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return CGSize(width: ceil(r.width) + 8, height: ceil(r.height) + 6)
    }

    /// طبقة نصّ واحدة تظهر من s إلى e
    static func layer(_ s: NSAttributedString, style: Style, render: CGSize, centerY: CGFloat, from: Double, to: Double, pop: Bool) -> CALayer {
        let maxW = render.width * 0.86
        let sz = measure(s, width: maxW)
        let holder = CALayer()
        let pad: CGFloat = style.look == .box ? render.width * 0.025 : 0
        // centerY محسوب من فوق، وطبقات الفيديو أصلها من جوّا ⇒ نقلبه
        let top = centerY - sz.height / 2 - pad / 2
        holder.frame = CGRect(x: (render.width - sz.width) / 2 - pad, y: render.height - top - (sz.height + pad), width: sz.width + pad * 2, height: sz.height + pad)
        if style.look == .box {
            holder.backgroundColor = UIColor.black.withAlphaComponent(0.62).cgColor
            holder.cornerRadius = render.width * 0.02
        }
        let t = CATextLayer()
        t.string = s
        t.isWrapped = true
        t.alignmentMode = .center
        t.contentsScale = 2
        t.frame = CGRect(x: pad, y: pad / 2, width: sz.width, height: sz.height)
        holder.addSublayer(t)
        holder.opacity = 0

        let show = CABasicAnimation(keyPath: "opacity")
        show.fromValue = 1; show.toValue = 1
        show.beginTime = AVCoreAnimationBeginTimeAtZero + max(0.001, from)
        show.duration = max(0.05, to - from)
        show.isRemovedOnCompletion = true
        show.fillMode = .removed
        holder.add(show, forKey: "show")

        if pop {
            let sc = CAKeyframeAnimation(keyPath: "transform.scale")
            sc.values = [0.72, 1.08, 1.0]
            sc.keyTimes = [0, 0.6, 1]
            sc.beginTime = AVCoreAnimationBeginTimeAtZero + max(0.001, from)
            sc.duration = min(0.18, max(0.05, to - from))
            sc.isRemovedOnCompletion = true
            holder.add(sc, forKey: "pop")
        }
        return holder
    }

    /// كلّ طبقات الترجمة للفيديو
    static func overlay(cues: [Cue], style: Style, render: CGSize) -> CALayer {
        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: render)
        let fs = CGFloat(style.fontSize(videoWidth: Double(render.width)))
        let cy = render.height * CGFloat(style.place.y)
        for c in cues {
            switch style.look {
            case .tiktok:
                let translated = style.mode != .original
                for ch in Subs.chunks(c, per: style.wordsPerChunk, translated: translated) {
                    let text = ch.words.joined(separator: " ")
                    // كلّ كلمة لمّا تنلفظ تتلوّن
                    for (i, st) in ch.starts.enumerated() {
                        let end = i + 1 < ch.starts.count ? ch.starts[i + 1] : ch.e
                        let a = attributed(text, style: style, size: fs, highlight: i)
                        root.addSublayer(layer(a, style: style, render: render, centerY: cy, from: st, to: end, pop: i == 0))
                    }
                }
                if style.mode == .both && !c.tr.isEmpty {
                    let small = attributed(Subs.wrap(c.text, max: 34).joined(separator: "\n"), style: style, size: fs * 0.48, dim: true)
                    root.addSublayer(layer(small, style: style, render: render, centerY: cy + fs * 1.05, from: c.s, to: c.e, pop: false))
                }
            default:
                let main = Subs.wrap(c.shown(style.mode), max: style.look == .cinema ? 38 : 28).joined(separator: "\n")
                let a = attributed(main, style: style, size: fs)
                let sz = measure(a, width: render.width * 0.86)
                let mainY = style.mode == .both && !c.tr.isEmpty ? cy - fs * 0.4 : cy
                root.addSublayer(layer(a, style: style, render: render, centerY: mainY, from: c.s, to: c.e, pop: false))
                if style.mode == .both && !c.tr.isEmpty {
                    let small = attributed(Subs.wrap(c.text, max: 40).joined(separator: "\n"), style: style, size: fs * 0.62, dim: true)
                    root.addSublayer(layer(small, style: style, render: render, centerY: mainY + sz.height / 2 + fs * 0.55, from: c.s, to: c.e, pop: false))
                }
            }
        }
        if !style.watermark.isEmpty {
            var wm = style; wm.look = .cinema; wm.color = 0xFFFFFF
            let a = attributed(style.watermark, style: wm, size: fs * 0.42, dim: true)
            let sz = measure(a, width: render.width * 0.6)
            let t = CATextLayer()
            t.string = a; t.contentsScale = 2; t.alignmentMode = .center; t.opacity = 0.8
            t.frame = CGRect(x: render.width - sz.width - render.width * 0.04, y: render.height * 0.95 - sz.height, width: sz.width, height: sz.height)
            root.addSublayer(t)
        }
        return root
    }

    /// التصدير: يرجّع رابط ملفّ mp4 جاهز
    static func export(video: URL, cues: [Cue], style: Style, progress: @escaping (Double) -> Void) async throws -> URL {
        let asset = AVURLAsset(url: video)
        let comp = AVMutableComposition()
        guard let vt = try await asset.loadTracks(withMediaType: .video).first else { throw Fail(msg: "الفيديو ما بيه صورة") }
        let dur = try await asset.load(.duration)
        let range = CMTimeRange(start: .zero, duration: dur)
        guard let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw Fail(msg: "ما گدرت أجهّز الفيديو") }
        try cv.insertTimeRange(range, of: vt, at: .zero)
        for at in try await asset.loadTracks(withMediaType: .audio) {
            if let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? ca.insertTimeRange(range, of: at, at: .zero)
            }
        }
        let natural = try await vt.load(.naturalSize)
        let transform = try await vt.load(.preferredTransform)
        let fps = try await vt.load(.nominalFrameRate)
        let rect = CGRect(origin: .zero, size: natural).applying(transform)
        var render = CGSize(width: abs(rect.width), height: abs(rect.height))
        // نحصر الدقّة ١٠٨٠ حتى ما يطوّل التصدير
        let scale = min(1, 1080 / min(render.width, render.height))
        render = CGSize(width: (render.width * scale / 2).rounded() * 2, height: (render.height * scale / 2).rounded() * 2)

        let ins = AVMutableVideoCompositionInstruction()
        ins.timeRange = range
        let li = AVMutableVideoCompositionLayerInstruction(assetTrack: cv)
        var t = transform
        if rect.origin.x != 0 || rect.origin.y != 0 { t = t.concatenating(CGAffineTransform(translationX: -rect.origin.x, y: -rect.origin.y)) }
        li.setTransform(t.concatenating(CGAffineTransform(scaleX: scale, y: scale)), at: .zero)
        ins.layerInstructions = [li]

        let vc = AVMutableVideoComposition()
        vc.renderSize = render
        vc.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps > 1 ? min(fps, 60).rounded() : 30))
        vc.instructions = [ins]

        let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: render)
        let vlayer = CALayer(); vlayer.frame = parent.frame
        parent.addSublayer(vlayer)
        parent.addSublayer(overlay(cues: cues, style: style, render: render))
        vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: vlayer, in: parent)

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("montage-\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: out)
        guard let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { throw Fail(msg: "التصدير ما اشتغل") }
        ex.videoComposition = vc
        ex.outputURL = out
        ex.outputFileType = .mp4
        ex.shouldOptimizeForNetworkUse = true

        let timer = Task {
            while !Task.isCancelled {
                progress(Double(ex.progress))
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        await ex.export()
        timer.cancel()
        progress(1)
        if ex.status != .completed { throw Fail(msg: ex.error?.localizedDescription ?? "التصدير فشل") }
        return out
    }

    /// صوت الفيديو ← m4a صغير للتفريغ (ما نرفع الفيديو نفسه)
    static func audio(of video: URL) async throws -> URL {
        let asset = AVURLAsset(url: video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw Fail(msg: "الفيديو بلا صوت") }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("mt-audio-\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: out)
        guard let ex = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { throw Fail(msg: "ما گدرت أطلّع الصوت") }
        ex.outputURL = out
        ex.outputFileType = .m4a
        await ex.export()
        if ex.status != .completed { throw Fail(msg: ex.error?.localizedDescription ?? "ما گدرت أطلّع الصوت") }
        return out
    }
}
