import SwiftUI
import UIKit

/// بنك الصور: تخزين القصّات على القرص + كاش بالذاكرة + تأثيرات محسوبة بالخلفيّة
@MainActor final class Bank: ObservableObject {
    static let shared = Bank()

    let store: ProjectStore
    @Published var tick = 0
    private var mem: [String: UIImage] = [:]
    private var outlines: [String: Outlined] = [:]
    private var blurs: [String: UIImage] = [:]
    private var thumbs: [String: UIImage] = [:]
    private var pending: Set<String> = []

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        store = ProjectStore(root: docs.appendingPathComponent("Thil", isDirectory: true))
    }

    func image(_ id: String) -> UIImage? {
        if let m = mem[id] { return m }
        guard let d = store.imageData(id), let i = UIImage(data: d) else { return nil }
        mem[id] = i
        return i
    }

    /// يحفظ قصّة (PNG شفّاف) ويرجّع رقمها
    func putPNG(_ img: UIImage) -> String {
        let id = "c" + String(UUID().uuidString.prefix(13))
        if let d = img.pngData() { try? store.saveImage(d, id: id) }
        mem[id] = img
        return id
    }
    /// يحفظ صورة خلفيّة (JPG)
    func putJPEG(_ img: UIImage) -> String {
        let id = "p" + String(UUID().uuidString.prefix(13))
        if let d = img.jpegData(compressionQuality: 0.88) { try? store.saveImage(d, id: id) }
        mem[id] = img
        return id
    }
    func putMemory(_ id: String, _ img: UIImage) { mem[id] = img }

    // MARK: حدّ الملصق

    private func outlineKey(_ image: String, _ stroke: Double, _ color: RGBA) -> String { "o|\(image)|\(Int(stroke * 1000))|\(color.hex)" }

    /// يرجّع الحدّ إذا جاهز، وإلّا يبدي يحسبه ويحدّث الواجهة لمّا يخلص
    func outlined(_ image: String, stroke: Double, color: RGBA) -> Outlined? {
        guard stroke > 0.001 else { return nil }
        let key = outlineKey(image, stroke, color)
        if let o = outlines[key] { return o }
        guard !pending.contains(key), let src = self.image(image) else { return nil }
        pending.insert(key)
        let box = ImgBox(img: src)
        Task.detached(priority: .userInitiated) {
            let out = box.img.flatMap { Engine.outline($0, stroke: stroke, color: color) }
            let res = OutBox(o: out)
            await self.finishOutline(key, res)
        }
        return nil
    }
    private func finishOutline(_ key: String, _ res: OutBox) {
        pending.remove(key)
        if let o = res.o { outlines[key] = o }
        tick += 1
    }
    func outlinedNow(_ image: String, stroke: Double, color: RGBA) -> Outlined? {
        guard stroke > 0.001 else { return nil }
        let key = outlineKey(image, stroke, color)
        if let o = outlines[key] { return o }
        guard let src = self.image(image), let o = Engine.outline(src, stroke: stroke, color: color) else { return nil }
        outlines[key] = o
        return o
    }

    // MARK: الضباب

    func blurred(_ id: String, _ frac: Double) -> UIImage? {
        let key = "b|\(id)|\(Int(frac * 1000))"
        if let b = blurs[key] { return b }
        guard !pending.contains(key), let src = self.image(id) else { return nil }
        pending.insert(key)
        let box = ImgBox(img: src)
        Task.detached(priority: .userInitiated) {
            let out = ImgBox(img: box.img.flatMap { Engine.blurred($0, frac: frac) })
            await self.finishBlur(key, out)
        }
        return nil
    }
    private func finishBlur(_ key: String, _ b: ImgBox) {
        pending.remove(key)
        if let i = b.img { blurs[key] = i }
        tick += 1
    }
    func blurredNow(_ id: String, _ frac: Double) -> UIImage? {
        let key = "b|\(id)|\(Int(frac * 1000))"
        if let b = blurs[key] { return b }
        guard let src = self.image(id), let b = Engine.blurred(src, frac: frac) else { return nil }
        blurs[key] = b
        return b
    }

    /// يجهّز كلّ التأثيرات قبل التصدير
    func prepare(_ p: Project) {
        for l in p.layers {
            if let id = l.imageID, l.fx.stroke > 0.001 { _ = outlinedNow(id, stroke: l.fx.stroke, color: l.fx.strokeColor) }
        }
        if case .blurPhoto(let id, let r) = p.bkg { _ = blurredNow(id, r) }
    }

    // MARK: المصغّرات

    func thumb(_ id: String) -> UIImage? {
        if let t = thumbs[id] { return t }
        guard let d = try? Data(contentsOf: store.thumbURL(id)), let i = UIImage(data: d) else { return nil }
        thumbs[id] = i
        return i
    }
    func saveThumb(_ p: Project) {
        guard let img = Render.image(p, width: 420), let d = img.jpegData(compressionQuality: 0.8) else { return }
        try? d.write(to: store.thumbURL(p.id), options: .atomic)
        thumbs[p.id] = img
    }
    func forgetThumb(_ id: String) { thumbs[id] = nil }
    func clearCaches() { mem.removeAll(); outlines.removeAll(); blurs.removeAll(); thumbs.removeAll() }
}

struct OutBox: @unchecked Sendable { let o: Outlined? }

/// الرسم النهائيّ بـ ImageRenderer (نفس واجهة المعاينة بالضبط)
@MainActor enum Render {
    static func image(_ p: Project, width: CGFloat) -> UIImage? {
        Bank.shared.prepare(p)
        let s = p.aspect.pixelSize(width: Double(width))
        let size = CGSize(width: s.w, height: s.h)
        let view = StageView(project: p, size: size, selected: nil, export: true, tick: Bank.shared.tick)
        let r = ImageRenderer(content: view)
        r.scale = 1
        r.isOpaque = !p.bkg.isClear
        return r.uiImage
    }

    /// ملصق شفّاف لطبقة وحدة (مع الحدّ إذا موجود)
    static func sticker(_ l: Layer) -> UIImage? {
        guard let id = l.imageID else { return nil }
        if l.fx.stroke > 0.001, let o = Bank.shared.outlinedNow(id, stroke: l.fx.stroke, color: l.fx.strokeColor) { return o.img }
        return Bank.shared.image(id)
    }

    static func data(_ img: UIImage, png: Bool) -> Data? { png ? img.pngData() : img.jpegData(compressionQuality: 0.93) }

    static func tempFile(_ data: Data, name: String) -> URL? {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try data.write(to: u, options: .atomic); return u } catch { return nil }
    }
}
