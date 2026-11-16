import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// صندوق لنقل الصور بين المهامّ
struct ImgBox: @unchecked Sendable { let img: UIImage? }

struct Outlined { let img: UIImage; let kx: CGFloat; let ky: CGFloat }

enum Engine {
    static let ctx = CIContext(options: nil)

    /// يعيد رسم الصورة بالاتّجاه الصحيح وبحجم معقول
    static func normalized(_ img: UIImage, maxSide: CGFloat = 2048) -> UIImage {
        let s = img.size
        guard s.width > 0, s.height > 0 else { return img }
        let k = min(1, maxSide / max(s.width, s.height))
        let ns = CGSize(width: floor(s.width * k), height: floor(s.height * k))
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        fmt.opaque = false
        return UIGraphicsImageRenderer(size: ns, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: ns)) }
    }

    static func downscaled(_ cg: CGImage, max m: Int) -> CGImage {
        let w = cg.width, h = cg.height
        let big = Swift.max(w, h)
        guard big > m else { return cg }
        let k = Double(m) / Double(big)
        let nw = Swift.max(1, Int(Double(w) * k)), nh = Swift.max(1, Int(Double(h) * k))
        guard let c = CGContext(data: nil, width: nw, height: nh, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return cg }
        c.interpolationQuality = .high
        c.draw(cg, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        return c.makeImage() ?? cg
    }

    /// يقصّ الفراغ الشفّاف حول الموضوع. nil = ما بيه شي
    static func trim(_ cg: CGImage) -> CGImage? {
        let sw = Swift.min(256, cg.width)
        guard sw > 0 else { return nil }
        let k = Double(sw) / Double(cg.width)
        let sh = Swift.max(1, Int((Double(cg.height) * k).rounded()))
        var buf = [UInt8](repeating: 0, count: sw * sh * 4)
        let ok: Bool = buf.withUnsafeMutableBytes { raw -> Bool in
            guard let c = CGContext(data: raw.baseAddress, width: sw, height: sh, bitsPerComponent: 8, bytesPerRow: sw * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.draw(cg, in: CGRect(x: 0, y: 0, width: sw, height: sh))
            return true
        }
        guard ok else { return cg }
        var alpha = [UInt8](repeating: 0, count: sw * sh)
        for i in 0..<(sw * sh) { alpha[i] = buf[i * 4 + 3] }
        guard let b = Fit.alphaBounds(alpha, width: sw, height: sh) else { return nil }
        let full = Fit.scaled(b, by: 1 / k)
        let p = Fit.padded(full, frac: 0.02, bounds: TSize(Double(cg.width), Double(cg.height)))
        let r = CGRect(x: floor(p.x), y: floor(p.y), width: ceil(p.w), height: ceil(p.h))
        return cg.cropping(to: r) ?? cg
    }

    /// حدّ الملصق: نوسّع القناع بـ CIMorphologyMaximum ونلوّنه ونحطّ الموضوع فوقه
    static func outline(_ img: UIImage, stroke: Double, color: RGBA) -> Outlined? {
        guard let cg0 = img.cgImage else { return nil }
        let cg = downscaled(cg0, max: 1400)
        let r = CGFloat(Swift.max(1, Swift.min(60, stroke * Double(cg.width))))
        let pad = ceil(r) + 4
        let W = CGFloat(cg.width) + 2 * pad, H = CGFloat(cg.height) + 2 * pad
        let ext = CGRect(x: 0, y: 0, width: W, height: H)
        let src = CIImage(cgImage: cg).transformed(by: CGAffineTransform(translationX: pad, y: pad))
        let clear = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: ext)
        let based = src.composited(over: clear)
        let dil = CIFilter.morphologyMaximum()
        dil.inputImage = based
        dil.radius = Float(r)
        guard let grown = dil.outputImage?.cropped(to: ext) else { return nil }
        let soft = CIFilter.gaussianBlur()
        soft.inputImage = grown
        soft.radius = Float(Swift.max(0.6, r * 0.08))
        let edge = soft.outputImage?.cropped(to: ext) ?? grown
        let solid = CIImage(color: CIColor(red: CGFloat(color.r), green: CGFloat(color.g), blue: CGFloat(color.b), alpha: 1)).cropped(to: ext)
        let m = CIFilter.blendWithAlphaMask()
        m.inputImage = solid
        m.backgroundImage = clear
        m.maskImage = edge
        guard let ring = m.outputImage else { return nil }
        let out = src.composited(over: ring).cropped(to: ext)
        guard let o = ctx.createCGImage(out, from: ext) else { return nil }
        return Outlined(img: UIImage(cgImage: o), kx: W / CGFloat(cg.width), ky: H / CGFloat(cg.height))
    }

    static func blurred(_ img: UIImage, frac: Double) -> UIImage? {
        guard let cg0 = img.cgImage else { return nil }
        let cg = downscaled(cg0, max: 1200)
        let src = CIImage(cgImage: cg)
        let ext = src.extent
        let f = CIFilter.gaussianBlur()
        f.inputImage = src.clampedToExtent()
        f.radius = Float(Swift.max(2, frac * Double(cg.width)))
        guard let o = f.outputImage?.cropped(to: ext), let c = ctx.createCGImage(o, from: ext) else { return nil }
        return UIImage(cgImage: c)
    }

    /// يدمج الصورة مع القناع: الموضوع يبقى والباقي شفّاف (CIBlendWithMask)
    static func blend(_ cg: CGImage, mask: CIImage) -> CGImage? {
        let img = CIImage(cgImage: cg)
        let ext = img.extent
        let sx = ext.width / Swift.max(1, mask.extent.width), sy = ext.height / Swift.max(1, mask.extent.height)
        let m = mask.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        let f = CIFilter.blendWithMask()
        f.inputImage = img
        f.backgroundImage = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: ext)
        f.maskImage = m
        guard let out = f.outputImage?.cropped(to: ext) else { return nil }
        return ctx.createCGImage(out, from: ext)
    }
}

/// جلسة القصّ لصورة وحدة: نحلّلها مرّة ونستخرج أيّ مجموعة عناصر
final class SubjectSession: @unchecked Sendable {
    let image: UIImage
    let cg: CGImage
    private let handler: VNImageRequestHandler
    private var obsAny: AnyObject?
    private var personMask: CIImage?
    private var labels: [UInt8] = []
    private var lw = 0
    private var lh = 0
    private(set) var count = 0
    private(set) var personOnly = false

    init?(image: UIImage) {
        let n = Engine.normalized(image)
        guard let c = n.cgImage else { return nil }
        self.image = n
        self.cg = c
        self.handler = VNImageRequestHandler(cgImage: c, options: [:])
    }

    /// يشغّل الذكاء: iOS 17 أيّ موضوع (عدّة عناصر)، وإلّا فصل الأشخاص
    func analyze() -> Bool {
        if #available(iOS 17.0, *) {
            let req = VNGenerateForegroundInstanceMaskRequest()
            do {
                try handler.perform([req])
                if let o = req.results?.first {
                    obsAny = o
                    count = o.allInstances.count
                    readLabels(o.instanceMask)
                    if count > 0 { return true }
                }
            } catch {}
        }
        let req = VNGeneratePersonSegmentationRequest()
        req.qualityLevel = .accurate
        req.outputPixelFormat = kCVPixelFormatType_OneComponent8
        do {
            try handler.perform([req])
            if let o = req.results?.first {
                personMask = CIImage(cvPixelBuffer: o.pixelBuffer)
                personOnly = true
                count = 1
                return true
            }
        } catch {}
        return false
    }

    private func readLabels(_ pb: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard CVPixelBufferGetPixelFormatType(pb) == kCVPixelFormatType_OneComponent8, let base = CVPixelBufferGetBaseAddress(pb) else { return }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb), bpr = CVPixelBufferGetBytesPerRow(pb)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        var arr = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w { arr[y * w + x] = ptr[y * bpr + x] } }
        labels = arr; lw = w; lh = h
    }

    /// رقم العنصر تحت نقطة طبيعيّة (0…1، الأعلى = 0). nil = خلفيّة
    func instance(atX nx: Double, y ny: Double) -> Int? {
        guard lw > 0, lh > 0, !labels.isEmpty else { return personOnly ? 1 : nil }
        let x = Swift.min(lw - 1, Swift.max(0, Int(nx * Double(lw))))
        let y = Swift.min(lh - 1, Swift.max(0, Int(ny * Double(lh))))
        let v = Int(labels[y * lw + x])
        return v == 0 ? nil : v
    }

    private func mask(_ sel: Set<Int>) -> CIImage? {
        if #available(iOS 17.0, *), !personOnly, let o = obsAny as? VNInstanceMaskObservation {
            var ix = IndexSet()
            for i in sel where o.allInstances.contains(i) { ix.insert(i) }
            if ix.isEmpty { ix = o.allInstances }
            guard let pb = try? o.generateScaledMaskForImage(forInstances: ix, from: handler) else { return nil }
            return CIImage(cvPixelBuffer: pb)
        }
        return personMask
    }

    /// معاينة بحجم الصورة الكامل (بدون قصّ الفراغ) حتى تنطبق فوق الأصل
    func preview(_ sel: Set<Int>) -> UIImage? {
        guard let m = mask(sel), let out = Engine.blend(Engine.downscaled(cg, max: 1100), mask: m) else { return nil }
        return UIImage(cgImage: out)
    }

    /// القصّة النهائيّة مقصوصة على حدود الموضوع
    func cutout(_ sel: Set<Int>) -> UIImage? {
        guard let m = mask(sel), let out = Engine.blend(cg, mask: m), let t = Engine.trim(out) else { return nil }
        return UIImage(cgImage: t)
    }
}
