import Foundation
import PDFKit

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── نطاقات الصفحات
check(PDFOps.parseRanges("1-3, 5", count: 10) == [0, 1, 2, 4], "ranges basic")
check(PDFOps.parseRanges("8-", count: 10) == [7, 8, 9], "ranges open end")
check(PDFOps.parseRanges("٢-٣، ٧", count: 10) == [1, 2, 6], "ranges arabic digits: \(PDFOps.parseRanges("٢-٣، ٧", count: 10))")
check(PDFOps.parseRanges("0, 11, 99, x, 3-2", count: 10) == [], "ranges invalid ignored")
check(PDFOps.parseRanges("2,2,1-2", count: 3) == [0, 1], "ranges dedupe")
check(PDFOps.parseRanges("5-50", count: 6) == [4, 5], "ranges clamp")

// ── مستندات تجريبيّة
guard let a = PDFOps.sample(title: "Contract", lines: ["Hello world line", "second line"], pages: 3),
      let b = PDFOps.sample(title: "Invoice", lines: ["Total 100"], pages: 2) else { print("FAIL: sample nil"); exit(1) }
check(a.pageCount == 3 && b.pageCount == 2, "sample page counts")
check(PDFOps.text(a).contains("Hello world"), "sample text extractable: \(PDFOps.text(a).prefix(60))")

// ── دمج / استخراج / حذف / تقسيم
let m = PDFOps.merge([a, b])
check(m.pageCount == 5, "merge count \(m.pageCount)")
check(a.pageCount == 3 && b.pageCount == 2, "merge leaves sources intact")
check(PDFOps.text(m).contains("Total 100") && PDFOps.text(m).contains("Hello world"), "merge keeps text")
let ex = PDFOps.extract(m, pages: [4, 0, 99])
check(ex.pageCount == 2 && (ex.page(at: 0)?.string ?? "").contains("Total"), "extract order + bounds")
check(PDFOps.remove(m, pages: [0, 1]).pageCount == 3, "remove")
let parts = PDFOps.split(m, every: 2)
check(parts.map { $0.pageCount } == [2, 2, 1], "split every 2: \(parts.map { $0.pageCount })")

// ── الدوران
PDFOps.rotate(m, pages: [0], by: 90)
check(m.page(at: 0)?.rotation == 90 && m.page(at: 1)?.rotation == 0, "rotate")
let s0 = PDFOps.size(m.page(at: 0)!), s1 = PDFOps.size(m.page(at: 1)!)
check(abs(s0.width - 842) < 1 && abs(s0.height - 595) < 1 && abs(s1.width - 595) < 1, "rotated size \(s0)")
PDFOps.rotate(m, pages: [0], by: -90)
check(m.page(at: 0)?.rotation == 0, "rotate back")

// ── إعادة الرسم: علامة مائيّة وترقيم (النصّ الأصليّ لازم يبقى نصّ)
if let w = PDFOps.watermark(a, text: "DRAFT") {
    check(w.pageCount == 3, "watermark count")
    check(PDFOps.text(w).contains("Hello world"), "watermark keeps original text")
    check(PDFOps.text(w).contains("DRAFT"), "watermark text present")
    let z = PDFOps.size(w.page(at: 0)!); check(abs(z.width - 595) < 1 && abs(z.height - 842) < 1, "watermark size \(z)")
} else { check(false, "watermark nil") }
if let n = PDFOps.numbered(a) {
    check(n.pageCount == 3 && PDFOps.text(n).contains("2 / 3"), "numbering: \(PDFOps.text(n).suffix(30))")
} else { check(false, "numbered nil") }

// ── صفحة مدوّرة تنعاد كتابتها بمقاسها الظاهر
let rot = PDFOps.extract(a, pages: [0]); PDFOps.rotate(rot, pages: [0], by: 90)
if let rw = PDFOps.numbered(rot) { let z = PDFOps.size(rw.page(at: 0)!); check(abs(z.width - 842) < 1 && abs(z.height - 595) < 1, "rewrite keeps rotated look \(z)") } else { check(false, "rewrite rotated nil") }

// ── رسم صفحة + صور ⇒ PDF + ضغط
if let img = PDFOps.render(a.page(at: 0)!, width: 400) {
    check(img.width == 400 && abs(img.height - 566) <= 1, "render size \(img.width)x\(img.height)")
    check((PDFOps.jpeg(img, quality: 0.6)?.count ?? 0) > 1000, "jpeg encode")
    if let d = PDFOps.fromImages([img, img]) { check(d.pageCount == 2, "images to pdf") } else { check(false, "fromImages nil") }
    if let st = PDFOps.stamp(a, image: img, page: 1, rect: CGRect(x: 0.6, y: 0.8, width: 0.3, height: 0.1)) { check(st.pageCount == 3 && PDFOps.text(st).contains("Hello world"), "stamp") } else { check(false, "stamp nil") }
} else { check(false, "render nil") }
if let c = PDFOps.compress(a, width: 500, quality: 0.4) { check(c.pageCount == 3 && (c.dataRepresentation()?.count ?? 0) > 500, "compress") } else { check(false, "compress nil") }

// ── القفل وفتحه
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("locked-\(UUID().uuidString).pdf")
check(PDFOps.protect(a, password: "1234", to: tmp), "protect write")
if let locked = PDFDocument(url: tmp) {
    check(locked.isLocked, "file is locked")
    check(PDFOps.unlocked(tmp, password: "wrong") == nil, "wrong password rejected")
    if let u = PDFOps.unlocked(tmp, password: "1234") { check(u.pageCount == 3 && !u.isLocked, "unlock ok") } else { check(false, "unlock nil") }
} else { check(false, "locked reopen nil") }
try? FileManager.default.removeItem(at: tmp)

check(PDFOps.bytes(2_097_152) == "2.0 MB" && PDFOps.bytes(2048) == "2 KB", "bytes")

print(failures == 0 ? "ALL WARAQ TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
