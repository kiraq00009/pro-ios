import Foundation
import UIKit
import Photos
import Vision
import CoreLocation

struct FZScanReport {
    var progress: Double
    var stage: String
    var done: Int
    var total: Int
    var found: Int64
    var groups: Int
}

/// صندوق صغير لنتيجة طلب متزامن
final class FZImageBox {
    var image: UIImage? = nil
}

final class FZDataBox {
    var data = Data()
}

final class FZOnce {
    private var done = false
    private let lock = NSLock()
    func fire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

// MARK: - التحليل على الجهاز

enum FZVision {
    /// صورة رماديّة صغيرة (أطول ضلع maxSide)
    static func gray(_ cg: CGImage, maxSide: Int = 256) -> (px: [UInt8], w: Int, h: Int)? {
        let W = cg.width, H = cg.height
        guard W > 0, H > 0 else { return nil }
        let s = min(1.0, Double(maxSide) / Double(max(W, H)))
        let w = max(3, Int(Double(W) * s))
        let h = max(3, Int(Double(H) * s))
        var buf = [UInt8](repeating: 0, count: w * h)
        let ok: Bool = buf.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? (buf, w, h) : nil
    }

    static func blur(_ cg: CGImage) -> FZBlur.Reading? {
        guard let g = gray(cg) else { return nil }
        return FZBlur.read(g.px, width: g.w, height: g.h)
    }

    /// بصمة الصورة من Vision كمتّجه مُطبّع
    static func featurePrint(_ cg: CGImage) -> [Float]? {
        let req = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do { try handler.perform([req]) } catch { return nil }
        guard let obs = req.results?.first else { return nil }
        let count = obs.elementCount
        guard count > 0 else { return nil }
        var out = [Float](repeating: 0, count: count)
        let data = obs.data
        switch obs.elementType {
        case .float:
            data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                let fp = raw.bindMemory(to: Float.self)
                let n = min(count, fp.count)
                for k in 0..<n { out[k] = fp[k] }
            }
        case .double:
            data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                let dp = raw.bindMemory(to: Double.self)
                let n = min(count, dp.count)
                for k in 0..<n { out[k] = Float(dp[k]) }
            }
        default:
            return nil
        }
        return FZVec.normalized(out)
    }

    /// عدد الوجوه ومجموع مساحاتها
    static func faces(_ cg: CGImage) -> (Int, Double) {
        let req = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do { try handler.perform([req]) } catch { return (0, 0) }
        let obs = req.results ?? []
        var area = 0.0
        for o in obs { area += Double(o.boundingBox.width * o.boundingBox.height) }
        return (obs.count, area)
    }
}

// MARK: - الفاحص (يشتغل بالخلفيّة)

final class FZScanner {
    private let lock = NSLock()
    private var stop = false

    func cancel() { lock.lock(); stop = true; lock.unlock() }
    private var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stop }

    static func info(_ a: PHAsset) -> FZAsset {
        let res = PHAssetResource.assetResources(for: a)
        var bytes: Int64 = 0, paired: Int64 = 0
        var name = ""
        for r in res {
            let sz = (r.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
            if r.type == .pairedVideo || r.type == .fullSizePairedVideo { paired += sz }
            bytes += sz
            if name.isEmpty && (r.type == .photo || r.type == .video) { name = r.originalFilename }
        }
        let isLive = a.mediaSubtypes.contains(.photoLive)
        let kind: FZKind = a.mediaType == .video ? .video : (isLive ? .live : .photo)
        return FZAsset(id: a.localIdentifier, kind: kind, bytes: bytes, pairedBytes: isLive ? paired : 0,
                       width: a.pixelWidth, height: a.pixelHeight,
                       created: (a.creationDate ?? Date()).timeIntervalSince1970, duration: a.duration,
                       isScreenshot: a.mediaSubtypes.contains(.photoScreenshot), isFavorite: a.isFavorite, fileName: name)
    }

    private func requestCG(_ manager: PHImageManager, _ a: PHAsset, side: CGFloat) -> CGImage? {
        let o = PHImageRequestOptions()
        o.isSynchronous = true
        o.deliveryMode = .highQualityFormat
        o.resizeMode = .fast
        o.isNetworkAccessAllowed = false
        let box = FZImageBox()
        manager.requestImage(for: a, targetSize: CGSize(width: side, height: side), contentMode: .aspectFit, options: o) { img, _ in
            box.image = img
        }
        return box.image?.cgImage
    }

    func run(rules: FZRules, report: @escaping (FZScanReport) -> Void) -> [FZAsset]? {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetch = PHAsset.fetchAssets(with: opts)
        let n = fetch.count
        let now = Date().timeIntervalSince1970
        var list: [FZAsset] = []
        list.reserveCapacity(n)
        var phs: [PHAsset] = []
        phs.reserveCapacity(n)
        var found: Int64 = 0

        // ١) القراءة والأحجام
        for i in 0..<n {
            if cancelled { return nil }
            let a = fetch.object(at: i)
            let info = FZScanner.info(a)
            list.append(info)
            phs.append(a)
            let c = FZClassify.cats(info, rules: rules, now: now)
            if c.contains(.videos) || c.contains(.screenshots) || c.contains(.forwarded) { found += info.bytes }
            else if c.contains(.live) { found += info.pairedBytes }
            if i % 60 == 0 || i == n - 1 {
                report(FZScanReport(progress: FZProgress.overall(phase: 0, fraction: Double(i + 1) / Double(max(1, n))),
                                    stage: "نقرأ أحجام المكتبة…", done: i + 1, total: n, found: found, groups: 0))
            }
        }

        // ٢) الحدّة + البصمات + التجميع المتدفّق
        let manager = PHImageManager.default()
        var stream = FZStreamCluster(threshold: rules.similarDistance, maxGap: rules.maxGap, window: 14)
        var streamMap: [Int] = []
        var done = 0
        for i in 0..<n {
            if cancelled { return nil }
            done += 1
            if list[i].kind == .video { continue }
            autoreleasepool {
                guard let cg = requestCG(manager, phs[i], side: 320) else { return }
                if let r = FZVision.blur(cg) {
                    list[i].sharpness = r.variance
                    list[i].brightness = r.brightness
                }
                var vec: [Float]? = nil
                if !FZClassify.isScreenshotLike(list[i]) { vec = FZVision.featurePrint(cg) }
                stream.add(time: list[i].created, vector: vec)
                streamMap.append(i)
                if FZClassify.isBlurry(list[i], rules: rules) && !(rules.protectFavorites && list[i].isFavorite) { found += list[i].bytes }
            }
            if done % 20 == 0 {
                report(FZScanReport(progress: FZProgress.overall(phase: 1, fraction: Double(done) / Double(max(1, n))),
                                    stage: "نحلّل الحدّة ونستخرج البصمات…", done: done, total: n, found: found, groups: 0))
            }
        }

        // ٣) أفضل لقطة بكلّ مجموعة
        let raw = stream.groups()
        var groups: [[Int]] = []
        for g in raw {
            let mapped = g.compactMap { $0 < streamMap.count ? streamMap[$0] : nil }
            if mapped.count >= 2 { groups.append(mapped) }
        }
        for (gi, g) in groups.enumerated() {
            if cancelled { return nil }
            var metrics: [FZShotMetrics] = []
            for i in g {
                list[i].group = gi + 1
                var faces = 0
                var area = 0.0
                autoreleasepool {
                    if let cg = requestCG(manager, phs[i], side: 480) {
                        let f = FZVision.faces(cg)
                        faces = f.0
                        area = f.1
                    }
                }
                list[i].faces = faces
                metrics.append(FZShotMetrics(sharpness: list[i].sharpness ?? 0, faces: faces, faceArea: area, pixels: list[i].pixels, isFavorite: list[i].isFavorite))
            }
            if let b = FZBest.pick(metrics) {
                list[g[b]].isBest = true
                for (k, i) in g.enumerated() where k != b && !list[i].isFavorite { found += list[i].bytes }
            }
            report(FZScanReport(progress: FZProgress.overall(phase: 2, fraction: Double(gi + 1) / Double(max(1, groups.count))),
                                stage: "نختار أفضل لقطة بكلّ مجموعة…", done: n, total: n, found: found, groups: gi + 1))
        }
        return list
    }
}

// MARK: - عمليّات المكتبة (الحذف دائمًا عبر نافذة النظام)

struct FZConverted {
    let oldID: String
    let newID: String
}

enum FZPhotoOps {
    static func delete(_ ids: [String]) async -> Bool {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard fetch.count > 0 else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(fetch)
            }
            return true
        } catch {
            return false
        }
    }

    private static func data(_ r: PHAssetResource) async -> Data? {
        await withCheckedContinuation { (c: CheckedContinuation<Data?, Never>) in
            let box = FZDataBox()
            let o = PHAssetResourceRequestOptions()
            o.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().requestData(for: r, options: o, dataReceivedHandler: { d in
                box.data.append(d)
            }, completionHandler: { err in
                c.resume(returning: err == nil && !box.data.isEmpty ? box.data : nil)
            })
        }
    }

    /// ينشئ نسخة ثابتة لكلّ صورة حيّة ويحذف الأصل ضمن تغيير واحد (النظام يطلب التأكيد)
    static func convertLive(_ ids: [String]) async -> [FZConverted] {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var originals: [PHAsset] = []
        fetch.enumerateObjects { a, _, _ in originals.append(a) }
        var pairs: [(PHAsset, Data)] = []
        for a in originals {
            let res = PHAssetResource.assetResources(for: a)
            let pick: PHAssetResource? = res.first(where: { $0.type == .fullSizePhoto }) ?? res.first(where: { $0.type == .photo })
            guard let r = pick, let d = await data(r) else { continue }
            pairs.append((a, d))
        }
        guard !pairs.isEmpty else { return [] }
        let idBox = FZIDBox()
        let work: [(PHAsset, Data)] = pairs
        let toDelete: [PHAsset] = pairs.map { $0.0 }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for (a, d) in work {
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, data: d, options: nil)
                    req.creationDate = a.creationDate
                    req.location = a.location
                    req.isFavorite = a.isFavorite
                    if let ph = req.placeholderForCreatedAsset {
                        idBox.pairs.append(FZConverted(oldID: a.localIdentifier, newID: ph.localIdentifier))
                    }
                }
                PHAssetChangeRequest.deleteAssets(toDelete as NSArray)
            }
            return idBox.pairs
        } catch {
            return []
        }
    }
}

final class FZIDBox {
    var pairs: [FZConverted] = []
}

// MARK: - المصغّرات

final class FZThumbs {
    static let shared = FZThumbs()
    private let cache = NSCache<NSString, UIImage>()
    private let manager = PHCachingImageManager()

    init() { cache.countLimit = 400 }

    func cached(_ id: String, px: CGFloat) -> UIImage? {
        cache.object(forKey: "\(id)#\(Int(px))" as NSString)
    }

    func load(_ a: FZAsset, px: CGFloat, demo: Bool) async -> UIImage? {
        let key = "\(a.id)#\(Int(px))" as NSString
        if let c = cache.object(forKey: key) { return c }
        let img: UIImage?
        if demo { img = FZDemoArt.image(a, px: px) } else { img = await real(a.id, px) }
        if let img { cache.setObject(img, forKey: key) }
        return img
    }

    private func real(_ id: String, _ px: CGFloat) async -> UIImage? {
        guard let ph = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let m = manager
        return await withCheckedContinuation { (c: CheckedContinuation<UIImage?, Never>) in
            let o = PHImageRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.resizeMode = .fast
            o.isNetworkAccessAllowed = true
            let once = FZOnce()
            m.requestImage(for: ph, targetSize: CGSize(width: px, height: px), contentMode: .aspectFill, options: o) { img, _ in
                if once.fire() { c.resume(returning: img) }
            }
        }
    }
}

// MARK: - رسم المكتبة التجريبيّة

enum FZDemoArt {
    static func num(_ id: String) -> Int { Int(id.split(separator: "-").last ?? "") ?? 0 }

    static func image(_ a: FZAsset, px: CGFloat) -> UIImage {
        let n = num(a.id)
        let ratio = a.width > 0 && a.height > 0 ? CGFloat(a.height) / CGFloat(a.width) : 0.75
        let w = max(40, px)
        let h = max(40, min(px * 2.2, px * ratio))
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        let r = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: f)
        return r.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(x: 0, y: 0, width: w, height: h)
            if a.kind == .video { drawVideo(cg, rect, n) }
            else if a.isScreenshot { drawScreen(cg, rect, n) }
            else if FZClassify.looksForwardedName(a.fileName) { drawForward(cg, rect, n) }
            else { drawScene(cg, rect, a, n) }
        }
    }

    private static func hue(_ k: Int) -> CGFloat { CGFloat((k * 37) % 100) / 100 }

    private static func fill(_ cg: CGContext, _ rect: CGRect, _ top: UIColor, _ bottom: UIColor) {
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            cg.drawLinearGradient(g, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        }
    }

    private static func drawScene(_ cg: CGContext, _ rect: CGRect, _ a: FZAsset, _ n: Int) {
        let base = a.group.map { hue($0 * 3 + 1) } ?? hue(n)
        let jitter = CGFloat(n % 5) * 0.01
        let blurry = (a.sharpness ?? 500) < 60
        fill(cg, rect, UIColor(hue: base, saturation: 0.55, brightness: 0.95, alpha: 1),
             UIColor(hue: (base + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.45, alpha: 1))
        let W = rect.width, H = rect.height
        // الشمس / القمر
        let sun = CGRect(x: W * (0.62 + jitter), y: H * (0.16 + jitter), width: W * 0.2, height: W * 0.2)
        cg.setFillColor(UIColor(white: 1, alpha: blurry ? 0.35 : 0.85).cgColor)
        cg.fillEllipse(in: sun)
        if blurry {
            for k in 0..<5 {
                let s = W * (0.25 + CGFloat(k) * 0.08)
                cg.setFillColor(UIColor(hue: base, saturation: 0.3, brightness: 1, alpha: 0.10).cgColor)
                cg.fillEllipse(in: CGRect(x: sun.midX - s / 2, y: sun.midY - s / 2, width: s, height: s))
            }
        }
        // جبال
        let layers = 3
        for k in 0..<layers {
            let y0 = H * (0.55 + CGFloat(k) * 0.12)
            cg.beginPath()
            cg.move(to: CGPoint(x: 0, y: H))
            cg.addLine(to: CGPoint(x: 0, y: y0))
            let peaks = 3 + k
            for p in 0...peaks {
                let x = W * CGFloat(p) / CGFloat(peaks)
                let up = (p % 2 == 0) ? -H * (0.10 - CGFloat(k) * 0.02) : H * 0.02
                cg.addLine(to: CGPoint(x: x + jitter * W, y: y0 + up))
            }
            cg.addLine(to: CGPoint(x: W, y: H))
            cg.closePath()
            let b = 0.35 - CGFloat(k) * 0.09
            cg.setFillColor(UIColor(hue: (base + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.45, brightness: max(0.08, b), alpha: blurry ? 0.75 : 1).cgColor)
            cg.fillPath()
        }
        // أشخاص بالمجموعات اللي بيها وجوه
        if a.faces > 0 {
            for k in 0..<min(3, a.faces) {
                let cx = W * (0.3 + CGFloat(k) * 0.2) + jitter * W * 2
                let headR = W * 0.06
                cg.setFillColor(UIColor(white: 0.12, alpha: 0.9).cgColor)
                cg.fillEllipse(in: CGRect(x: cx - headR, y: H * 0.5, width: headR * 2, height: headR * 2))
                cg.fill(CGRect(x: cx - headR * 1.3, y: H * 0.5 + headR * 2.1, width: headR * 2.6, height: H * 0.3))
            }
        }
    }

    private static func drawScreen(_ cg: CGContext, _ rect: CGRect, _ n: Int) {
        let h = hue(n)
        fill(cg, rect, UIColor(hue: h, saturation: 0.25, brightness: 0.16, alpha: 1), UIColor(hue: h, saturation: 0.35, brightness: 0.08, alpha: 1))
        let W = rect.width, H = rect.height
        cg.setFillColor(UIColor(white: 1, alpha: 0.85).cgColor)
        cg.fill(CGRect(x: W * 0.08, y: H * 0.03, width: W * 0.14, height: H * 0.012))
        cg.fill(CGRect(x: W * 0.78, y: H * 0.03, width: W * 0.14, height: H * 0.012))
        // بطاقات واجهة
        for k in 0..<6 {
            let y = H * (0.1 + CGFloat(k) * 0.14)
            let card = CGRect(x: W * 0.07, y: y, width: W * 0.86, height: H * 0.11)
            let path = UIBezierPath(roundedRect: card, cornerRadius: W * 0.04)
            cg.setFillColor(UIColor(white: 1, alpha: 0.08).cgColor)
            cg.addPath(path.cgPath); cg.fillPath()
            cg.setFillColor(UIColor(hue: (h + CGFloat(k) * 0.1).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.95, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: card.minX + W * 0.04, y: card.midY - W * 0.06, width: W * 0.12, height: W * 0.12))
            cg.setFillColor(UIColor(white: 1, alpha: 0.6).cgColor)
            cg.fill(CGRect(x: card.minX + W * 0.22, y: card.midY - H * 0.018, width: W * 0.5, height: H * 0.012))
            cg.setFillColor(UIColor(white: 1, alpha: 0.3).cgColor)
            cg.fill(CGRect(x: card.minX + W * 0.22, y: card.midY + H * 0.008, width: W * 0.32, height: H * 0.01))
        }
    }

    private static func drawVideo(_ cg: CGContext, _ rect: CGRect, _ n: Int) {
        let h = hue(n + 40)
        fill(cg, rect, UIColor(hue: h, saturation: 0.6, brightness: 0.55, alpha: 1), UIColor(hue: (h + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.15, alpha: 1))
        let W = rect.width, H = rect.height
        for k in 0..<4 {
            let s = W * (0.2 + CGFloat(k) * 0.12)
            cg.setFillColor(UIColor(white: 1, alpha: 0.06).cgColor)
            cg.fillEllipse(in: CGRect(x: W * 0.2 - s / 2, y: H * 0.35 - s / 2, width: s, height: s))
        }
        cg.setFillColor(UIColor(white: 0, alpha: 0.35).cgColor)
        cg.fill(CGRect(x: 0, y: H * 0.78, width: W, height: H * 0.22))
    }

    private static func drawForward(_ cg: CGContext, _ rect: CGRect, _ n: Int) {
        let h = hue(n + 13)
        fill(cg, rect, UIColor(hue: h, saturation: 0.35, brightness: 0.85, alpha: 1), UIColor(hue: h, saturation: 0.5, brightness: 0.6, alpha: 1))
        let W = rect.width, H = rect.height
        // نصّ عريض بأسلوب «بطاقة صباح الخير»
        cg.setFillColor(UIColor(white: 1, alpha: 0.9).cgColor)
        for k in 0..<3 {
            let lw = W * (0.7 - CGFloat(k) * 0.15)
            cg.fill(CGRect(x: (W - lw) / 2, y: H * (0.18 + CGFloat(k) * 0.09), width: lw, height: H * 0.05))
        }
        // زهرة
        let c = CGPoint(x: W * 0.5, y: H * 0.68)
        for k in 0..<6 {
            let ang = CGFloat(k) * .pi / 3
            let p = CGPoint(x: c.x + cos(ang) * W * 0.09, y: c.y + sin(ang) * W * 0.09)
            cg.setFillColor(UIColor(hue: (h + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.6, brightness: 1, alpha: 0.9).cgColor)
            cg.fillEllipse(in: CGRect(x: p.x - W * 0.07, y: p.y - W * 0.07, width: W * 0.14, height: W * 0.14))
        }
        cg.setFillColor(UIColor(hue: 0.14, saturation: 0.8, brightness: 1, alpha: 1).cgColor)
        cg.fillEllipse(in: CGRect(x: c.x - W * 0.06, y: c.y - W * 0.06, width: W * 0.12, height: W * 0.12))
    }
}
