import SwiftUI
import PDFKit
import Vision

/// صورة صفحة تنرسم بالخلفيّة
struct PageThumb: View {
    let page: PDFPage; var width: CGFloat = 300
    @State private var img: UIImage? = nil
    var body: some View {
        Group {
            if let i = img { Image(uiImage: i).resizable().aspectRatio(contentMode: .fit) }
            else { Color.white.opacity(0.08).aspectRatio(0.71, contentMode: .fit) }
        }
        .task(id: ObjectIdentifier(page)) {
            let p = page, w = width
            let cg = await Task.detached(priority: .userInitiated) { PDFOps.render(p, width: w) }.value
            if let cg { img = UIImage(cgImage: cg) }
        }
    }
}

// MARK: - ترتيب الصفحات
struct PagesView: View {
    let doc: Doc
    let done: (String) -> Void
    @EnvironmentObject var shelf: Shelf
    @Environment(\.dismiss) private var dismiss
    @State private var work: PDFDocument
    @State private var sel: Set<Int> = []
    @State private var rev = 0
    @State private var changed = false
    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    init(doc: Doc, pdf: PDFDocument, done: @escaping (String) -> Void) {
        self.doc = doc; self.done = done
        _work = State(initialValue: PDFOps.extract(pdf, pages: Array(0..<pdf.pageCount)))
    }

    var body: some View {
        ToolPage(title: "ترتيب الصفحات", sub: sel.isEmpty ? "اضغط على الصفحات حتى تختارها" : "\(sel.count) صفحة مختارة") {
            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(0..<work.pageCount, id: \.self) { i in
                        if let p = work.page(at: i) {
                            Button { Haptic.tap(); if sel.contains(i) { sel.remove(i) } else { sel.insert(i) } } label: {
                                VStack(spacing: 5) {
                                    PageThumb(page: p, width: 220).id("\(rev)-\(i)")
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(sel.contains(i) ? WQ.ac : Color.clear, lineWidth: 3))
                                        .overlay(alignment: .topTrailing) { if sel.contains(i) { Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(WQ.ac).background(Color.white, in: Circle()).padding(5) } }
                                    Text("\(i + 1)").font(rnd(12.5, .heavy)).foregroundStyle(sel.contains(i) ? WQ.ac : WQ.tx3)
                                }
                            }.buttonStyle(Press())
                        }
                    }
                }.padding(.horizontal, 20).padding(.bottom, 12)
            }
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    act("rotate.right.fill", "تدوير") { PDFOps.rotate(work, pages: Array(sel), by: 90); bump() }
                    act("arrow.right", "قدّم", off: sel.count != 1 || sel.first == 0) { move(-1) }
                    act("arrow.left", "أخّر", off: sel.count != 1 || sel.first == work.pageCount - 1) { move(1) }
                    act("doc.on.doc.fill", "استخرج") { if let d = shelf.add(PDFOps.extract(work, pages: sel.sorted()), name: doc.name + " (صفحات)") { done("انحفظت \(d.pages) صفحة بملفّ جديد ✓"); dismiss() } }
                    act("trash.fill", "حذف", tint: WQ.ac, off: sel.isEmpty || sel.count >= work.pageCount) { work = PDFOps.remove(work, pages: Array(sel)); sel = []; bump() }
                }
                BigButton(title: "احفظ التغييرات", icon: "checkmark") { if shelf.replace(doc, with: work) { done("انحفظ ترتيب الصفحات ✓") }; dismiss() }.opacity(changed ? 1 : 0.4).disabled(!changed)
            }.padding(.horizontal, 20).padding(.vertical, 12).background(WQ.s1)
        }
        .onAppear { if Shot.name == "pages" { sel = [1] } }
    }
    private func bump() { rev += 1; changed = true; Haptic.thud() }
    private func move(_ step: Int) {
        guard let i = sel.first, sel.count == 1, i + step >= 0, i + step < work.pageCount else { return }
        work.exchangePage(at: i, withPageAt: i + step); sel = [i + step]; bump()
    }
    private func act(_ icon: String, _ t: String, tint: Color = Color.white, off: Bool? = nil, _ a: @escaping () -> Void) -> some View {
        let disabled = off ?? sel.isEmpty
        return Button(action: a) {
            VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 16, weight: .bold)); Text(t).font(rnd(11, .heavy)) }
                .foregroundStyle(tint).frame(maxWidth: .infinity).frame(height: 54).background(WQ.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }.buttonStyle(Press()).disabled(disabled).opacity(disabled ? 0.35 : 1)
    }
}

// MARK: - دمج
struct MergeView: View {
    let base: Doc?
    let done: (Doc) -> Void
    @EnvironmentObject var shelf: Shelf
    @State private var order: [UUID] = []
    var body: some View {
        ToolPage(title: "دمج ملفّات", sub: "اختارهم بالترتيب اللي تريده — \(order.count) مختار") {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(shelf.docs.filter { !$0.locked }) { d in
                        let idx = order.firstIndex(of: d.id)
                        Button { Haptic.tap(); if let i = idx { order.remove(at: i) } else { order.append(d.id) } } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(idx != nil ? WQ.ac : WQ.s3).frame(width: 30, height: 30)
                                    if let i = idx { Text("\(i + 1)").font(rnd(14, .black)).foregroundStyle(Color.white) }
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(d.name).font(rnd(15.5, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                                    Text("\(d.pages) صفحة · \(PDFOps.bytes(d.bytes))").font(rnd(12)).foregroundStyle(WQ.tx3)
                                }
                                Spacer(minLength: 0)
                            }.padding(12).card(WQ.s1, 16, stroke: idx != nil ? WQ.ac.opacity(0.5) : Color(white: 1, opacity: 0.07))
                        }.buttonStyle(Press())
                    }
                }.padding(.horizontal, 20).padding(.bottom, 12)
            }
            BigButton(title: "ادمج \(order.count) ملفّات", icon: "square.on.square") {
                let pdfs = order.compactMap { id in shelf.docs.first { $0.id == id } }.compactMap { shelf.pdf($0) }
                if let d = shelf.add(PDFOps.merge(pdfs), name: "مدموج") { Haptic.ok(); done(d) }
            }.opacity(order.count >= 2 ? 1 : 0.4).disabled(order.count < 2).padding(.horizontal, 20).padding(.vertical, 12)
        }
        .onAppear { if let b = base, order.isEmpty { order = [b.id] }; if Shot.name == "merge" { order = shelf.docs.prefix(2).map { $0.id } } }
    }
}

// MARK: - تقسيم
struct SplitView: View {
    let doc: Doc; let pdf: PDFDocument
    let done: (String) -> Void
    @EnvironmentObject var shelf: Shelf
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var every = 2
    @State private var ranges = ""
    private var picked: [Int] { PDFOps.parseRanges(ranges, count: pdf.pageCount) }
    private var result: String {
        switch mode {
        case 0: return "\(pdf.pageCount) ملفّ — كلّ صفحة بملفّ"
        case 1: return "\((pdf.pageCount + every - 1) / every) ملفّ — كلّ \(every) صفحات بملفّ"
        default: return picked.isEmpty ? "اكتب أرقام الصفحات" : "ملفّ واحد بيه \(picked.count) صفحة"
        }
    }
    var body: some View {
        ToolPage(title: "تقسيم", sub: "المستند بيه \(pdf.pageCount) صفحة") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    opt(0, "doc.on.doc", "كلّ صفحة بملفّ", "يطلّع \(pdf.pageCount) ملفّ")
                    opt(1, "rectangle.split.3x1", "كلّ عدد صفحات بملفّ", "قسّمه لأجزاء متساوية")
                    if mode == 1 { Stepper(value: $every, in: 2...max(2, pdf.pageCount)) { Text("كلّ \(every) صفحات").font(rnd(15, .heavy)).foregroundStyle(Color.white) }.padding(14).card(WQ.s1, 16) }
                    opt(2, "text.cursor", "صفحات أختارها", "مثل: 1-3, 5, 8-")
                    if mode == 2 {
                        TextField("", text: $ranges, prompt: Text("1-3, 5, 8-").foregroundColor(WQ.tx3)).font(rnd(18, .heavy)).foregroundStyle(Color.white).keyboardType(.numbersAndPunctuation)
                            .padding(.horizontal, 16).frame(height: 54).background(WQ.s2, in: RoundedRectangle(cornerRadius: 15, style: .continuous)).environment(\.layoutDirection, .leftToRight)
                    }
                    HStack(spacing: 8) { Image(systemName: "info.circle.fill").foregroundStyle(WQ.blue); Text(result).font(rnd(14, .heavy)).foregroundStyle(Color.white) }.padding(14).frame(maxWidth: .infinity, alignment: .leading).card(WQ.s1, 16, stroke: WQ.blue.opacity(0.3))
                    Text("الملفّ الأصليّ يبقى مثل ما هو.").font(rnd(12)).foregroundStyle(WQ.tx3)
                }.padding(.horizontal, 20)
            }
            BigButton(title: "قسّم", icon: "scissors") { run() }.opacity(mode == 2 && picked.isEmpty ? 0.4 : 1).disabled(mode == 2 && picked.isEmpty).padding(.horizontal, 20).padding(.vertical, 12)
        }
        .onAppear { if Shot.name == "split" { mode = 2; ranges = "1-2, 4" } }
    }
    private func opt(_ m: Int, _ icon: String, _ t: String, _ s: String) -> some View {
        Button { Haptic.tap(); withAnimation { mode = m } } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(mode == m ? Color.white : WQ.ac2).frame(width: 44, height: 44).background(mode == m ? WQ.ac2 : WQ.ac2.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 1) { Text(t).font(rnd(16, .heavy)).foregroundStyle(Color.white); Text(s).font(rnd(12)).foregroundStyle(WQ.tx3).environment(\.layoutDirection, .leftToRight) }
                Spacer(minLength: 0)
                Image(systemName: mode == m ? "checkmark.circle.fill" : "circle").font(.system(size: 20)).foregroundStyle(mode == m ? WQ.ac2 : WQ.s3)
            }.padding(12).card(WQ.s1, 18, stroke: mode == m ? WQ.ac2.opacity(0.55) : Color(white: 1, opacity: 0.07))
        }.buttonStyle(Press())
    }
    private func run() {
        var n = 0
        if mode == 2 { if shelf.add(PDFOps.extract(pdf, pages: picked), name: doc.name + " (جزء)") != nil { n = 1 } }
        else { for (i, part) in PDFOps.split(pdf, every: mode == 0 ? 1 : every).enumerated().reversed() { if shelf.add(part, name: "\(doc.name) — \(i + 1)") != nil { n += 1 } } }
        Haptic.ok(); done("انحفظ \(n) ملفّ بمستنداتك ✓"); dismiss()
    }
}

// MARK: - ضغط
struct CompressView: View {
    let doc: Doc; let pdf: PDFDocument
    let done: (String) -> Void
    @EnvironmentObject var shelf: Shelf
    @Environment(\.dismiss) private var dismiss
    @State private var level = 1
    @State private var out: PDFDocument? = nil
    @State private var size = 0
    @State private var busy = false
    private let presets: [(String, String, CGFloat, CGFloat)] = [("خفيف", "جودة عالية", 1500, 0.72), ("وسط", "توازن", 1150, 0.55), ("قويّ", "أصغر حجم", 850, 0.38)]

    var body: some View {
        ToolPage(title: "ضغط الحجم", sub: "الحجم الحاليّ " + PDFOps.bytes(doc.bytes)) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(presets.indices, id: \.self) { i in
                            Button { level = i; out = nil } label: {
                                VStack(spacing: 2) { Text(presets[i].0).font(rnd(16, .black)); Text(presets[i].1).font(rnd(11)).opacity(0.7) }
                                    .foregroundStyle(level == i ? Color.white : WQ.tx2).frame(maxWidth: .infinity).frame(height: 62).background(level == i ? WQ.ac : WQ.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }.buttonStyle(Press())
                        }
                    }
                    if busy { HStack(spacing: 10) { ProgressView().tint(WQ.ac); Text("دا نضغط الصفحات…").font(rnd(14, .heavy)).foregroundStyle(WQ.tx2) }.frame(maxWidth: .infinity).padding(.vertical, 24) }
                    if out != nil {
                        let saved = doc.bytes > 0 ? max(0, 100 - size * 100 / doc.bytes) : 0
                        HStack(spacing: 0) {
                            box(PDFOps.bytes(doc.bytes), "قبل", WQ.tx2)
                            Image(systemName: "arrow.left").font(.system(size: 16, weight: .black)).foregroundStyle(WQ.tx3)
                            box(PDFOps.bytes(size), "بعد", size < doc.bytes ? WQ.green : WQ.ac)
                        }.padding(.vertical, 6).card(WQ.s1, 18)
                        Text(size < doc.bytes ? "صغر \(saved)٪ ✓" : "الملفّ أصلًا صغير — الضغط ما يفيده.").font(rnd(15, .heavy)).foregroundStyle(size < doc.bytes ? WQ.green : WQ.ac2).frame(maxWidth: .infinity)
                    }
                    Text("الضغط يحوّل كلّ صفحة لصورة، فالنصّ ما يبقى ينتحدّد أو ينبحث بيه. يفيد أكثر شي للملفّات الممسوحة والصور.").font(rnd(12)).foregroundStyle(WQ.tx3).lineSpacing(3)
                }.padding(.horizontal, 20)
            }
            VStack(spacing: 8) {
                if let o = out, size < doc.bytes {
                    BigButton(title: "احفظه كملفّ جديد", icon: "plus.square.on.square") { if shelf.add(o, name: doc.name + " (مضغوط)") != nil { done("انحفظت النسخة المضغوطة ✓") }; dismiss() }
                    Button { if shelf.replace(doc, with: o) { done("انضغط الملفّ ✓") }; dismiss() } label: { Text("بدّل الأصليّ").font(rnd(14.5, .heavy)).foregroundStyle(WQ.tx2).frame(maxWidth: .infinity).frame(height: 44) }.buttonStyle(.plain)
                } else {
                    BigButton(title: "اضغط", icon: "arrow.down.right.and.arrow.up.left") { run() }.opacity(busy ? 0.4 : 1).disabled(busy)
                }
            }.padding(.horizontal, 20).padding(.vertical, 12)
        }
        .onAppear { if Shot.name == "compress" { run() } }
    }
    private func box(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) { Text(v).font(rnd(22, .black)).foregroundStyle(c).environment(\.layoutDirection, .leftToRight); Text(l).font(rnd(12)).foregroundStyle(WQ.tx3) }.frame(maxWidth: .infinity).padding(.vertical, 10)
    }
    private func run() {
        busy = true; out = nil
        let p = pdf, w = presets[level].2, q = presets[level].3
        Task {
            let r = await Task.detached(priority: .userInitiated) { PDFOps.compress(p, width: w, quality: q) }.value
            size = r?.dataRepresentation()?.count ?? 0; out = r; busy = false
        }
    }
}

// MARK: - القفل
struct ProtectView: View {
    let doc: Doc; let pdf: PDFDocument; let password: String
    let done: (String, String) -> Void
    @EnvironmentObject var shelf: Shelf
    @Environment(\.dismiss) private var dismiss
    @State private var p1 = ""
    @State private var p2 = ""
    var body: some View {
        ToolPage(title: doc.locked ? "شيل القفل" : "قفل بكلمة سرّ", sub: doc.locked ? "الملفّ مقفول هسه" : "محّد يفتح الملفّ بلا الكلمة") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: doc.locked ? "lock.open.fill" : "lock.fill").font(.system(size: 44)).foregroundStyle(WQ.ac2).frame(maxWidth: .infinity).padding(.vertical, 10)
                    if doc.locked {
                        Text("راح تنشال كلمة السرّ ويفتح الملفّ لأيّ أحد.").font(rnd(14)).foregroundStyle(WQ.tx2).frame(maxWidth: .infinity)
                    } else {
                        secure("كلمة السرّ", $p1)
                        secure("عيدها مرّة ثانية", $p2)
                        if !p2.isEmpty && p1 != p2 { Text("الكلمتين مو متطابقات").font(rnd(12.5, .bold)).foregroundStyle(WQ.ac) }
                        Text("احفظ الكلمة زين. إذا نسيتها ما أكو أيّ طريقة ترجّع الملفّ.").font(rnd(12)).foregroundStyle(WQ.tx3)
                    }
                }.padding(.horizontal, 20)
            }
            if doc.locked {
                BigButton(title: "شيل القفل", icon: "lock.open.fill", tint: WQ.ac2) {
                    if let u = PDFOps.unlocked(shelf.url(doc), password: password), shelf.replace(doc, with: u) { done("انشال القفل ✓", "") }
                    dismiss()
                }.padding(.horizontal, 20).padding(.vertical, 12)
            } else {
                BigButton(title: "اقفل الملفّ", icon: "lock.fill", tint: WQ.ac2) {
                    if PDFOps.protect(pdf, password: p1, to: shelf.url(doc)) { shelf.touch(doc); Haptic.ok(); done("انقفل الملفّ ✓", p1) }
                    dismiss()
                }.opacity(p1.count >= 3 && p1 == p2 ? 1 : 0.4).disabled(!(p1.count >= 3 && p1 == p2)).padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
        .onAppear { if Shot.name == "protect" { p1 = "123456"; p2 = "123456" } }
    }
    private func secure(_ hint: String, _ t: Binding<String>) -> some View {
        SecureField("", text: t, prompt: Text(hint).foregroundColor(WQ.tx3)).font(rnd(17, .heavy)).foregroundStyle(Color.white)
            .padding(.horizontal, 16).frame(height: 54).background(WQ.s2, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// MARK: - علامة مائيّة
struct WatermarkView: View {
    let doc: Doc; let pdf: PDFDocument
    let done: (String) -> Void
    @EnvironmentObject var shelf: Shelf
    @Environment(\.dismiss) private var dismiss
    @State private var text = "سرّيّ"
    @State private var opacity = 0.2
    @State private var preview: UIImage? = nil
    private let ideas = ["سرّيّ", "مسودّة", "نسخة", "غير صالح للتداول", "CONFIDENTIAL"]
    var body: some View {
        ToolPage(title: "علامة مائيّة", sub: "نصّ شفّاف مايل على كلّ الصفحات") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Group { if let p = preview { Image(uiImage: p).resizable().aspectRatio(contentMode: .fit) } else { Color.white.opacity(0.06).aspectRatio(0.71, contentMode: .fit) } }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).frame(maxHeight: 330).frame(maxWidth: .infinity)
                    TextField("", text: $text, prompt: Text("نصّ العلامة").foregroundColor(WQ.tx3)).font(rnd(17, .heavy)).foregroundStyle(Color.white)
                        .padding(.horizontal, 16).frame(height: 52).background(WQ.s2, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) { ForEach(ideas, id: \.self) { i in Button { text = i } label: { Text(i).font(rnd(13, .heavy)).foregroundStyle(WQ.tx2).padding(.horizontal, 14).frame(height: 34).background(WQ.s2, in: Capsule()) }.buttonStyle(Press()) } }
                    }
                    HStack { Text("الوضوح").font(rnd(14, .heavy)).foregroundStyle(Color.white); Slider(value: $opacity, in: 0.08...0.5).environment(\.layoutDirection, .leftToRight) }
                }.padding(.horizontal, 20)
            }
            BigButton(title: "طبّقها على كلّ الصفحات", icon: "drop.fill", tint: WQ.blue) {
                if let w = PDFOps.watermark(pdf, text: text, opacity: opacity), shelf.replace(doc, with: w) { Haptic.ok(); done("انضافت العلامة المائيّة ✓") }
                dismiss()
            }.opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1).disabled(text.trimmingCharacters(in: .whitespaces).isEmpty).padding(.horizontal, 20).padding(.vertical, 12)
        }
        .task(id: text + String(format: "%.2f", opacity)) {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            let one = PDFOps.extract(pdf, pages: [0]), t = text, o = opacity
            let cg = await Task.detached { () -> CGImage? in
                guard let w = PDFOps.watermark(one, text: t, opacity: o), let pg = w.page(at: 0) else { return nil }
                return PDFOps.render(pg, width: 700)
            }.value
            if let cg { preview = UIImage(cgImage: cg) }
        }
    }
}

// MARK: - استخراج النصّ (ومن الصور بقراءة الحروف على الجهاز)
struct TextSheet: View {
    let pdf: PDFDocument
    @State private var text = ""
    @State private var busy = false
    @State private var ocrDone = false
    @State private var copied = false
    var body: some View {
        ToolPage(title: "نصّ المستند", sub: text.isEmpty ? "ندوّر على النصّ…" : "\(text.count) حرف") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if busy { HStack(spacing: 10) { ProgressView().tint(WQ.violet); Text("دا نقرا الحروف من الصفحات…").font(rnd(14, .heavy)).foregroundStyle(WQ.tx2) }.frame(maxWidth: .infinity).padding(.vertical, 30) }
                    else if text.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "text.viewfinder").font(.system(size: 40)).foregroundStyle(WQ.violet)
                            Text(ocrDone ? "ما لگينا نصّ ينقرا بهالمستند." : "المستند صور بلا نصّ.").font(rnd(15, .heavy)).foregroundStyle(Color.white)
                            if !ocrDone { Text("نگدر نقرا الحروف من الصور على جهازك.").font(rnd(13)).foregroundStyle(WQ.tx3) }
                        }.frame(maxWidth: .infinity).padding(.vertical, 30)
                    } else {
                        Text(text).font(rnd(14.5)).foregroundStyle(WQ.tx2).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(14).card(WQ.s1, 16)
                    }
                }.padding(.horizontal, 20)
            }
            HStack(spacing: 10) {
                if text.isEmpty && !ocrDone { BigButton(title: "اقرا النصّ من الصور", icon: "text.viewfinder", tint: WQ.violet) { ocr() }.disabled(busy).opacity(busy ? 0.4 : 1) }
                else if !text.isEmpty {
                    BigButton(title: copied ? "انّسخ ✓" : "انسخ", icon: "doc.on.doc", tint: WQ.violet) { UIPasteboard.general.string = text; copied = true; Haptic.ok() }
                    ShareLink(item: text) { Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.white).frame(width: 54, height: 54).background(WQ.s2, in: Circle()) }
                }
            }.padding(.horizontal, 20).padding(.vertical, 12)
        }
        .task { text = PDFOps.text(pdf) }
    }
    private func ocr() {
        busy = true
        let p = pdf
        Task {
            let t = await Task.detached(priority: .userInitiated) { () -> String in
                var out = ""
                let req = VNRecognizeTextRequest(); req.recognitionLevel = .accurate; req.usesLanguageCorrection = true
                let langs = (try? req.supportedRecognitionLanguages()) ?? []
                req.recognitionLanguages = langs.filter { $0.hasPrefix("ar") || $0.hasPrefix("en") }
                for i in 0..<p.pageCount {
                    guard let page = p.page(at: i), let cg = PDFOps.render(page, width: 1600) else { continue }
                    try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
                    let lines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    if !lines.isEmpty { out += lines.joined(separator: "\n") + "\n\n" }
                }
                return out.trimmingCharacters(in: .whitespacesAndNewlines)
            }.value
            text = t; busy = false; ocrDone = true
        }
    }
}

// MARK: - الصفحات ⇠ صور
struct ImagesSheet: View {
    let doc: Doc; let pdf: PDFDocument
    @State private var urls: [URL] = []
    @State private var busy = true
    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    var body: some View {
        ToolPage(title: "الصفحات كصور", sub: busy ? "دا نحوّل…" : "\(urls.count) صورة جاهزة") {
            ScrollView {
                if busy { ProgressView().tint(WQ.ac).padding(.top, 40) }
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(urls, id: \.self) { u in
                        if let img = UIImage(contentsOfFile: u.path) {
                            ShareLink(item: u) { Image(uiImage: img).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)) }
                        }
                    }
                }.padding(.horizontal, 20)
            }
            if !urls.isEmpty {
                ShareLink(items: urls) {
                    Label("شارك كلّ الصور", systemImage: "square.and.arrow.up").font(rnd(17, .heavy)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 54).background(WQ.ac, in: Capsule())
                }.padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
        .task {
            let p = pdf, name = doc.name
            urls = await Task.detached(priority: .userInitiated) { () -> [URL] in
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pages-" + UUID().uuidString, isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                var out: [URL] = []
                for i in 0..<p.pageCount {
                    guard let page = p.page(at: i), let cg = PDFOps.render(page, width: 1600), let d = PDFOps.jpeg(cg, quality: 0.88) else { continue }
                    let u = dir.appendingPathComponent("\(name)-\(i + 1).jpg")
                    if (try? d.write(to: u)) != nil { out.append(u) }
                }
                return out
            }.value
            busy = false
        }
    }
}
