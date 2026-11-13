import SwiftUI
import PDFKit

enum WQ {
    static let bg = Color(red: 0.05, green: 0.045, blue: 0.05)
    static let s1 = Color(red: 0.10, green: 0.09, blue: 0.10)
    static let s2 = Color(red: 0.16, green: 0.145, blue: 0.155)
    static let s3 = Color(red: 0.23, green: 0.21, blue: 0.22)
    static let ac = Color(red: 1, green: 0.38, blue: 0.32)          // مرجانيّ
    static let ac2 = Color(red: 1, green: 0.62, blue: 0.25)
    static let blue = Color(red: 0.35, green: 0.62, blue: 1)
    static let green = Color(red: 0.3, green: 0.86, blue: 0.55)
    static let violet = Color(red: 0.66, green: 0.5, blue: 1)
    static let tx2 = Color(white: 1, opacity: 0.72), tx3 = Color(white: 1, opacity: 0.45)
}

struct Doc: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var file: String
    var pages = 0
    var bytes = 0
    var date = Date()
    var locked = false
}

@MainActor
final class Shelf: ObservableObject {
    @Published var docs: [Doc] = []
    @Published var sigs: [String] = []                      // أسماء ملفّات التواقيع المحفوظة (PNG)
    private let ud = UserDefaults.standard
    private let thumbs = NSCache<NSString, UIImage>()

    static let dir: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(Shot.on ? "pdfs-demo" : "pdfs", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static let sigDir: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sigs", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    init() {
        if Shot.on { seedDemo(); return }
        if let d = ud.data(forKey: "wq_docs"), let v = try? JSONDecoder().decode([Doc].self, from: d) { docs = v.filter { FileManager.default.fileExists(atPath: Shelf.dir.appendingPathComponent($0.file).path) } }
        sigs = ((try? FileManager.default.contentsOfDirectory(atPath: Shelf.sigDir.path)) ?? []).filter { $0.hasSuffix(".png") }.sorted(by: >)
    }
    private func save() { guard !Shot.on else { return }; if let d = try? JSONEncoder().encode(docs) { ud.set(d, forKey: "wq_docs") } }

    func url(_ d: Doc) -> URL { Shelf.dir.appendingPathComponent(d.file) }
    func pdf(_ d: Doc) -> PDFDocument? { PDFDocument(url: url(d)) }
    private func meta(_ d: inout Doc) {
        let u = url(d)
        d.bytes = ((try? FileManager.default.attributesOfItem(atPath: u.path))?[.size] as? NSNumber)?.intValue ?? 0
        if let p = PDFDocument(url: u) { d.locked = p.isLocked; d.pages = p.pageCount }
        d.date = Date()
    }
    private func unique(_ name: String) -> String {
        let base = name.trimmingCharacters(in: .whitespaces).isEmpty ? "مستند" : name
        if !docs.contains(where: { $0.name == base }) { return base }
        var i = 2; while docs.contains(where: { $0.name == "\(base) \(i)" }) { i += 1 }
        return "\(base) \(i)"
    }

    /// يضيف مستند جديد من الذاكرة
    @discardableResult func add(_ pdf: PDFDocument, name: String) -> Doc? {
        guard pdf.pageCount > 0, let data = pdf.dataRepresentation() else { return nil }
        var d = Doc(name: unique(name), file: UUID().uuidString + ".pdf")
        do { try data.write(to: url(d), options: .atomic) } catch { return nil }
        meta(&d); docs.insert(d, at: 0); save(); return d
    }
    /// يضيف ملفّ PDF مثل ما هو (حتى لو مقفول)
    @discardableResult func addFile(_ src: URL, name: String) -> Doc? {
        var d = Doc(name: unique(name), file: UUID().uuidString + ".pdf")
        do { try FileManager.default.copyItem(at: src, to: url(d)) } catch { return nil }
        meta(&d); docs.insert(d, at: 0); save(); return d
    }
    /// يبدّل محتوى مستند موجود
    @discardableResult func replace(_ d: Doc, with pdf: PDFDocument) -> Bool {
        guard pdf.pageCount > 0, let data = pdf.dataRepresentation(), let i = docs.firstIndex(where: { $0.id == d.id }) else { return false }
        do { try data.write(to: url(d), options: .atomic) } catch { return false }
        thumbs.removeObject(forKey: d.id.uuidString as NSString)
        meta(&docs[i]); save(); return true
    }
    /// بعد كتابة الملفّ مباشرة على القرص (مثل القفل بكلمة سرّ)
    func touch(_ d: Doc) { if let i = docs.firstIndex(where: { $0.id == d.id }) { thumbs.removeObject(forKey: d.id.uuidString as NSString); meta(&docs[i]); save() } }
    func rename(_ d: Doc, _ name: String) { if let i = docs.firstIndex(where: { $0.id == d.id }), !name.trimmingCharacters(in: .whitespaces).isEmpty { docs[i].name = name; save() } }
    func remove(_ d: Doc) { try? FileManager.default.removeItem(at: url(d)); docs.removeAll { $0.id == d.id }; save() }
    func duplicate(_ d: Doc) { _ = addFile(url(d), name: d.name + " (نسخة)") }
    func current(_ d: Doc) -> Doc { docs.first { $0.id == d.id } ?? d }

    func thumb(_ d: Doc) -> UIImage? {
        let k = d.id.uuidString as NSString
        if let c = thumbs.object(forKey: k) { return c }
        guard let p = pdf(d), !p.isLocked, let page = p.page(at: 0), let cg = PDFOps.render(page, width: 360) else { return nil }
        let img = UIImage(cgImage: cg); thumbs.setObject(img, forKey: k); return img
    }

    // MARK: الاستيراد
    /// ملفّات من «الملفّات»: PDF ينضاف مثل ما هو، والصور تنجمع بمستند واحد
    func importFiles(_ urls: [URL]) -> Int {
        var n = 0
        var images: [CGImage] = []
        for u in urls {
            let scoped = u.startAccessingSecurityScopedResource()
            defer { if scoped { u.stopAccessingSecurityScopedResource() } }
            let name = u.deletingPathExtension().lastPathComponent
            if u.pathExtension.lowercased() == "pdf" { if addFile(u, name: name) != nil { n += 1 } }
            else if let img = UIImage(contentsOfFile: u.path), let cg = Shelf.upright(img) { images.append(cg) }
        }
        if !images.isEmpty, let pdf = PDFOps.fromImages(images), add(pdf, name: "صور") != nil { n += 1 }
        return n
    }
    func importImages(_ imgs: [UIImage], name: String) -> Doc? {
        let cgs = imgs.compactMap { Shelf.upright($0) }
        guard let pdf = PDFOps.fromImages(cgs) else { return nil }
        return add(pdf, name: name)
    }
    /// صورة معتدلة الاتّجاه وبحجم معقول
    static func upright(_ img: UIImage, maxSide: CGFloat = 2200) -> CGImage? {
        let sc = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: (img.size.width * sc).rounded(), height: (img.size.height * sc).rounded())
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }.cgImage
    }

    // MARK: التواقيع
    func addSignature(_ img: UIImage) -> String? {
        guard let d = img.pngData() else { return nil }
        let name = String(format: "%.0f.png", Date().timeIntervalSince1970 * 1000)
        try? d.write(to: Shelf.sigDir.appendingPathComponent(name)); sigs.insert(name, at: 0); return name
    }
    func signature(_ name: String) -> UIImage? { UIImage(contentsOfFile: Shelf.sigDir.appendingPathComponent(name).path) }
    func removeSignature(_ name: String) { try? FileManager.default.removeItem(at: Shelf.sigDir.appendingPathComponent(name)); sigs.removeAll { $0 == name } }

    private func seedDemo() {
        try? FileManager.default.removeItem(at: Shelf.dir); try? FileManager.default.createDirectory(at: Shelf.dir, withIntermediateDirectories: true)
        let contract = ["عقد إيجار شقّة سكنيّة", "الطرف الأوّل (المؤجّر): ...............................", "الطرف الثاني (المستأجر): ............................", "مدّة العقد: سنة واحدة تبدأ من تاريخ التوقيع.",
                        "قيمة الإيجار الشهريّ: ................. تُدفع أوّل كلّ شهر.", "يلتزم المستأجر بالمحافظة على العين المؤجَّرة.", "لا يحقّ للمستأجر التأجير من الباطن بلا موافقة خطّيّة.",
                        "يُجدَّد العقد تلقائيًّا ما لم يُخطر أحد الطرفين الآخر.", "", "توقيع الطرف الأوّل                    توقيع الطرف الثاني"]
        let cv = ["السيرة الذاتيّة", "الاسم: ............................", "المسمّى الوظيفيّ: مصمّم واجهات", "الخبرة: ٦ سنوات بتصميم تطبيقات الموبايل.", "المهارات: تصميم، نماذج أوّليّة، بحث مستخدمين.", "اللغات: العربيّة، الإنكليزيّة."]
        let inv = ["فاتورة رقم 1042", "العميل: شركة النور", "تصميم هويّة ............ 450", "موقع إلكترونيّ ......... 900", "استضافة سنة ........... 120", "المجموع: 1470"]
        if let p = PDFOps.sample(title: "فاتورة", lines: inv, pages: 1) { add(p, name: "فاتورة نوفمبر") }
        if let p = PDFOps.sample(title: "السيرة الذاتيّة", lines: cv, pages: 2) { add(p, name: "السيرة الذاتيّة") }
        if let p = PDFOps.sample(title: "عقد إيجار", lines: contract, pages: 4) { add(p, name: "عقد الإيجار") }
        if Shot.isAny("sign", "place"), let img = Shelf.demoSignature() { let n = "demo.png"; try? img.pngData()?.write(to: Shelf.sigDir.appendingPathComponent(n)); sigs = [n] }
    }
    static func demoSignature() -> UIImage? {
        let size = CGSize(width: 600, height: 240)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            let p = UIBezierPath(); p.move(to: CGPoint(x: 40, y: 150))
            p.addCurve(to: CGPoint(x: 200, y: 90), controlPoint1: CGPoint(x: 80, y: 20), controlPoint2: CGPoint(x: 130, y: 220))
            p.addCurve(to: CGPoint(x: 380, y: 130), controlPoint1: CGPoint(x: 260, y: -20), controlPoint2: CGPoint(x: 300, y: 230))
            p.addCurve(to: CGPoint(x: 560, y: 100), controlPoint1: CGPoint(x: 440, y: 60), controlPoint2: CGPoint(x: 480, y: 190))
            p.lineWidth = 9; p.lineCapStyle = .round; UIColor(red: 0.05, green: 0.15, blue: 0.5, alpha: 1).setStroke(); p.stroke()
        }
    }
}
