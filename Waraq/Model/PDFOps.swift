import Foundation
import PDFKit
import CoreGraphics
import CoreText
import ImageIO

// عمليّات PDF — بلا واجهة (PDFKit + CoreGraphics) حتى تنفحص باختبارات آليّة على ماك البناء

enum PDFOps {
    // MARK: نطاقات الصفحات

    /// «1-3, 5, 8-» ⇒ أرقام صفحات (من 0) ضمن عدد الصفحات، مرتّبة وبلا تكرار
    static func parseRanges(_ text: String, count: Int) -> [Int] {
        var out = Set<Int>()
        let digits = text.map { ch -> Character in
            if let v = ch.wholeNumberValue, ch.isNumber { return Character(String(v)) }      // أرقام عربيّة ⇒ لاتينيّة
            return ch == "،" ? "," : (ch == "–" || ch == "—" ? "-" : ch)
        }
        for part in String(digits).split(separator: ",") {
            let p = part.trimmingCharacters(in: .whitespaces)
            if p.isEmpty { continue }
            if let dash = p.firstIndex(of: "-") {
                let a = Int(p[..<dash].trimmingCharacters(in: .whitespaces)) ?? 1
                let rest = p[p.index(after: dash)...].trimmingCharacters(in: .whitespaces)
                let b = rest.isEmpty ? count : (Int(rest) ?? count)
                let lo = max(1, a), hi = min(count, b)
                if lo <= hi { for i in lo...hi { out.insert(i - 1) } }
            } else if let n = Int(p), n >= 1, n <= count { out.insert(n - 1) }
        }
        return out.sorted()
    }

    // MARK: ترتيب الصفحات

    static func merge(_ docs: [PDFDocument]) -> PDFDocument {
        let out = PDFDocument()
        for d in docs { for i in 0..<d.pageCount { if let p = d.page(at: i)?.copy() as? PDFPage { out.insert(p, at: out.pageCount) } } }
        return out
    }
    static func extract(_ doc: PDFDocument, pages: [Int]) -> PDFDocument {
        let out = PDFDocument()
        for i in pages where i >= 0 && i < doc.pageCount { if let p = doc.page(at: i)?.copy() as? PDFPage { out.insert(p, at: out.pageCount) } }
        return out
    }
    static func remove(_ doc: PDFDocument, pages: [Int]) -> PDFDocument {
        let drop = Set(pages)
        return extract(doc, pages: (0..<doc.pageCount).filter { !drop.contains($0) })
    }
    static func rotate(_ doc: PDFDocument, pages: [Int], by degrees: Int) {
        for i in pages { if let p = doc.page(at: i) { p.rotation = ((p.rotation + degrees) % 360 + 360) % 360 } }
    }
    /// كلّ صفحة بملفّ، أو كلّ `every` صفحات بملفّ
    static func split(_ doc: PDFDocument, every: Int) -> [PDFDocument] {
        let n = max(1, every)
        return stride(from: 0, to: doc.pageCount, by: n).map { s in extract(doc, pages: Array(s..<min(doc.pageCount, s + n))) }
    }

    // MARK: إعادة رسم الصفحات (للعلامة المائيّة، الترقيم، التوقيع، الضغط)

    /// حجم الصفحة مثل ما تنشاف (بعد الدوران)
    static func size(_ p: PDFPage) -> CGSize {
        let b = p.bounds(for: .mediaBox)
        return p.rotation % 180 == 0 ? b.size : CGSize(width: b.height, height: b.width)
    }

    /// يعيد كتابة المستند: يرسم كلّ صفحة مثل ما هي (نصّها يبقى نصّ)، ثمّ ينادي `overlay` حتى يرسم فوقها
    static func rewrite(_ doc: PDFDocument, overlay: (CGContext, Int, CGSize) -> Void) -> PDFDocument? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData), let ctx = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }
        for i in 0..<doc.pageCount {
            guard let p = doc.page(at: i) else { continue }
            let s = size(p)
            var box = CGRect(origin: .zero, size: s)
            ctx.beginPage(mediaBox: &box)
            ctx.saveGState()
            p.draw(with: .mediaBox, to: ctx)
            ctx.restoreGState()
            ctx.saveGState()
            overlay(ctx, i, s)
            ctx.restoreGState()
            ctx.endPage()
        }
        ctx.closePDF()
        return PDFDocument(data: data as Data)
    }

    private static func line(_ text: String, size: CGFloat, color: CGColor, bold: Bool = true) -> CTLine {
        let font = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, "ar" as CFString) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    }

    /// علامة مائيّة مايلة بنصّ الصفحة
    static func watermark(_ doc: PDFDocument, text: String, opacity: CGFloat = 0.18) -> PDFDocument? {
        rewrite(doc) { ctx, _, s in
            let fs = min(s.width, s.height) / CGFloat(max(4, min(18, text.count))) * 1.5
            let l = line(text, size: fs, color: CGColor(gray: 0.35, alpha: opacity))
            let b = CTLineGetBoundsWithOptions(l, [])
            ctx.translateBy(x: s.width / 2, y: s.height / 2)
            ctx.rotate(by: .pi / 5)
            ctx.textPosition = CGPoint(x: -b.width / 2 - b.minX, y: -b.height / 2 - b.minY)
            CTLineDraw(l, ctx)
        }
    }
    /// ترقيم الصفحات بأسفل الوسط
    static func numbered(_ doc: PDFDocument, start: Int = 1) -> PDFDocument? {
        let total = doc.pageCount
        return rewrite(doc) { ctx, i, s in
            let l = line("\(i + start) / \(total + start - 1)", size: max(9, s.width / 55), color: CGColor(gray: 0.25, alpha: 1), bold: false)
            let b = CTLineGetBoundsWithOptions(l, [])
            ctx.textPosition = CGPoint(x: (s.width - b.width) / 2, y: max(14, s.height * 0.025))
            CTLineDraw(l, ctx)
        }
    }
    /// يحطّ صورة (توقيع أو ختم) على صفحة — `rect` بنسب ٠…١ من الصفحة والأصل فوق يسار
    static func stamp(_ doc: PDFDocument, image: CGImage, page: Int, rect: CGRect) -> PDFDocument? {
        rewrite(doc) { ctx, i, s in
            guard i == page else { return }
            let r = CGRect(x: rect.minX * s.width, y: (1 - rect.maxY) * s.height, width: rect.width * s.width, height: rect.height * s.height)
            ctx.draw(image, in: r)
        }
    }

    /// صورة لصفحة بعرض محدّد
    static func render(_ p: PDFPage, width: CGFloat, background: CGFloat = 1) -> CGImage? {
        let s = size(p)
        guard s.width > 0, s.height > 0 else { return nil }
        let sc = width / s.width
        let w = Int(width.rounded()), h = Int((s.height * sc).rounded())
        guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(gray: background, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: sc, y: sc)
        p.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()
    }
    static func jpeg(_ img: CGImage, quality: CGFloat) -> Data? {
        let d = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(d as CFMutableData, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? d as Data : nil
    }

    /// صور ⇒ PDF (كلّ صورة صفحة بمقاسها، بحدّ أقصى للعرض بالنقاط)
    static func fromImages(_ images: [CGImage], maxWidth: CGFloat = 595, quality: CGFloat = 0.8) -> PDFDocument? {
        let data = NSMutableData()
        guard !images.isEmpty, let consumer = CGDataConsumer(data: data as CFMutableData), let ctx = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }
        for img in images {
            let w = min(maxWidth, CGFloat(img.width)), h = w * CGFloat(img.height) / CGFloat(max(1, img.width))
            var box = CGRect(x: 0, y: 0, width: w, height: h)
            ctx.beginPage(mediaBox: &box)
            // نمرّر الصورة مضغوطة JPEG حتى ما يتضخّم الملفّ
            if let j = jpeg(img, quality: quality), let src = CGImageSourceCreateWithData(j as CFData, nil), let small = CGImageSourceCreateImageAtIndex(src, 0, nil) { ctx.draw(small, in: box) }
            else { ctx.draw(img, in: box) }
            ctx.endPage()
        }
        ctx.closePDF()
        return PDFDocument(data: data as Data)
    }

    /// ضغط: كلّ صفحة تتحوّل لصورة JPEG (النصّ يصير صورة) — يفيد للملفّات الممسوحة الكبيرة
    static func compress(_ doc: PDFDocument, width: CGFloat = 1100, quality: CGFloat = 0.55) -> PDFDocument? {
        var imgs: [CGImage] = []
        for i in 0..<doc.pageCount { if let p = doc.page(at: i), let im = render(p, width: width) { imgs.append(im) } }
        return fromImages(imgs, maxWidth: 595, quality: quality)
    }

    // MARK: القفل

    static func protect(_ doc: PDFDocument, password: String, to url: URL) -> Bool {
        doc.write(to: url, withOptions: [PDFDocumentWriteOption.userPasswordOption: password, PDFDocumentWriteOption.ownerPasswordOption: password])
    }
    /// يفتح ملفّ مقفول ويرجّع نسخة بلا قفل
    static func unlocked(_ url: URL, password: String) -> PDFDocument? {
        guard let d = PDFDocument(url: url) else { return nil }
        if d.isLocked && !d.unlock(withPassword: password) { return nil }
        return extract(d, pages: Array(0..<d.pageCount))
    }

    // MARK: نصّ

    static func text(_ doc: PDFDocument) -> String {
        var out = ""
        for i in 0..<doc.pageCount { if let s = doc.page(at: i)?.string, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out += s + "\n\n" } }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// مستند تجريبيّ: عنوان + سطور نصّ (للاختبارات ولصور الشاشات)
    static func sample(title: String, lines: [String], pages: Int = 1, size: CGSize = CGSize(width: 595, height: 842)) -> PDFDocument? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData), let ctx = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }
        for pg in 0..<max(1, pages) {
            var box = CGRect(origin: .zero, size: size)
            ctx.beginPage(mediaBox: &box)
            ctx.setFillColor(gray: 1, alpha: 1); ctx.fill(box)
            ctx.setFillColor(red: 0.16, green: 0.36, blue: 0.85, alpha: 1); ctx.fill(CGRect(x: 0, y: size.height - 70, width: size.width, height: 70))
            let t = line(title, size: 24, color: CGColor(gray: 1, alpha: 1))
            let tb = CTLineGetBoundsWithOptions(t, [])
            ctx.textPosition = CGPoint(x: size.width - 40 - tb.width, y: size.height - 46); CTLineDraw(t, ctx)
            var y = size.height - 120
            for (i, s) in lines.enumerated() {
                let l = line(s, size: i == 0 ? 15 : 12.5, color: CGColor(gray: 0.15, alpha: 1), bold: i == 0)
                let b = CTLineGetBoundsWithOptions(l, [])
                ctx.textPosition = CGPoint(x: size.width - 40 - b.width, y: y); CTLineDraw(l, ctx)
                y -= i == 0 ? 34 : 24
                if y < 80 { break }
            }
            let n = line("\(pg + 1)", size: 10, color: CGColor(gray: 0.5, alpha: 1), bold: false)
            ctx.textPosition = CGPoint(x: size.width / 2, y: 30); CTLineDraw(n, ctx)
            ctx.endPage()
        }
        ctx.closePDF()
        return PDFDocument(data: data as Data)
    }

    static func bytes(_ n: Int) -> String {
        n >= 1_048_576 ? String(format: "%.1f MB", Double(n) / 1_048_576) : String(format: "%.0f KB", max(1, Double(n) / 1024))
    }
}
