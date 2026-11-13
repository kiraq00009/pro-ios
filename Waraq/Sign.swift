import SwiftUI
import PDFKit

// MARK: - التوقيع: اختار توقيع محفوظ أو ارسم جديد، ثمّ حطّه على الصفحة
struct SignView: View {
    let doc: Doc; let pdf: PDFDocument
    let done: (String) -> Void
    @EnvironmentObject var shelf: Shelf
    @Environment(\.dismiss) private var dismiss
    @State private var drawing = false
    @State private var placing: String? = nil

    var body: some View {
        Group {
            if let name = placing, let img = shelf.signature(name) {
                PlaceView(doc: doc, pdf: pdf, sig: img, back: { placing = nil }) { msg in done(msg); dismiss() }
            } else if drawing {
                DrawPad(cancel: { drawing = false }) { img in drawing = false; if let n = shelf.addSignature(img) { placing = n } }
            } else { picker }
        }
        .onAppear { if Shot.name == "place", let n = shelf.sigs.first { placing = n } }
    }

    private var picker: some View {
        ToolPage(title: "توقيع", sub: shelf.sigs.isEmpty ? "ارسم توقيعك مرّة وحدة واستعمله دائمًا" : "اختار توقيع أو ارسم جديد") {
            ScrollView {
                VStack(spacing: 10) {
                    Button { drawing = true } label: {
                        Label("ارسم توقيع جديد", systemImage: "pencil.tip.crop.circle.badge.plus").font(rnd(16, .heavy)).foregroundStyle(WQ.violet).frame(maxWidth: .infinity).frame(height: 56).card(WQ.s1, 18, stroke: WQ.violet.opacity(0.4))
                    }.buttonStyle(Press())
                    ForEach(shelf.sigs, id: \.self) { n in
                        HStack(spacing: 10) {
                            Button { placing = n } label: {
                                Group { if let i = shelf.signature(n) { Image(uiImage: i).resizable().aspectRatio(contentMode: .fit).padding(10) } else { Color.clear } }
                                    .frame(maxWidth: .infinity).frame(height: 96).background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }.buttonStyle(Press())
                            Button { shelf.removeSignature(n) } label: { Image(systemName: "trash").font(.system(size: 14, weight: .bold)).foregroundStyle(WQ.ac).frame(width: 40, height: 40).background(WQ.ac.opacity(0.12), in: Circle()) }.buttonStyle(Press())
                        }
                    }
                }.padding(.horizontal, 20)
            }
        }
    }
}

/// لوحة رسم التوقيع
struct DrawPad: View {
    let cancel: () -> Void
    let save: (UIImage) -> Void
    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    @State private var color = 0
    private let inks: [Color] = [Color(red: 0.05, green: 0.12, blue: 0.45), Color.black, Color(red: 0.7, green: 0.08, blue: 0.1)]

    var body: some View {
        ToolPage(title: "ارسم توقيعك", sub: "وقّع بإصبعك داخل المربّع الأبيض") {
            GeometryReader { g in
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white)
                    Rectangle().fill(Color.black.opacity(0.12)).frame(height: 1).padding(.horizontal, 26).offset(y: g.size.height * 0.2)
                    Canvas { ctx, _ in
                        for s in strokes + [current] { ctx.stroke(path(s), with: .color(inks[color]), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)) }
                    }
                    if strokes.isEmpty && current.isEmpty { Text("وقّع هنا").font(rnd(20, .heavy)).foregroundStyle(Color.black.opacity(0.18)) }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in current.append(v.location) }.onEnded { _ in if current.count > 1 { strokes.append(current) }; current = [] })
                .environment(\.layoutDirection, .leftToRight)
            }
            .frame(height: 250).padding(.horizontal, 20)
            HStack(spacing: 12) {
                ForEach(inks.indices, id: \.self) { i in
                    Button { color = i } label: { Circle().fill(inks[i]).frame(width: 34, height: 34).overlay(Circle().stroke(Color.white, lineWidth: color == i ? 3 : 0)) }.buttonStyle(Press())
                }
                Spacer()
                Button { strokes = []; current = [] } label: { Label("امسح", systemImage: "arrow.counterclockwise").font(rnd(14, .heavy)).foregroundStyle(WQ.tx2).padding(.horizontal, 14).frame(height: 38).background(WQ.s2, in: Capsule()) }.buttonStyle(Press())
            }.padding(.horizontal, 20).padding(.top, 14)
            Spacer()
            VStack(spacing: 8) {
                BigButton(title: "استعمل هالتوقيع", icon: "checkmark", tint: WQ.violet) { if let img = render() { save(img) } }.opacity(strokes.isEmpty ? 0.4 : 1).disabled(strokes.isEmpty)
                Button(action: cancel) { Text("رجوع").font(rnd(14.5, .heavy)).foregroundStyle(WQ.tx3).frame(maxWidth: .infinity).frame(height: 40) }.buttonStyle(.plain)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
    }
    private func path(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let f = pts.first else { return p }
        p.move(to: f)
        for i in 1..<max(1, pts.count) { let m = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2); p.addQuadCurve(to: m, control: pts[i - 1]) }
        if let l = pts.last { p.addLine(to: l) }
        return p
    }
    /// التوقيع كصورة شفّافة مقصوصة على حدوده
    private func render() -> UIImage? {
        let all = strokes.flatMap { $0 }
        guard let minX = all.map({ $0.x }).min(), let maxX = all.map({ $0.x }).max(), let minY = all.map({ $0.y }).min(), let maxY = all.map({ $0.y }).max() else { return nil }
        let pad: CGFloat = 10, sc: CGFloat = 3
        let size = CGSize(width: (maxX - minX + pad * 2) * sc, height: (maxY - minY + pad * 2) * sc)
        guard size.width > 20, size.height > 10 else { return nil }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let ink = UIColor(inks[color])
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            c.cgContext.scaleBy(x: sc, y: sc); c.cgContext.translateBy(x: pad - minX, y: pad - minY)
            ink.setStroke()
            for s in strokes { let b = UIBezierPath(cgPath: path(s).cgPath); b.lineWidth = 4.5; b.lineCapStyle = .round; b.lineJoinStyle = .round; b.stroke() }
        }
    }
}

/// حطّ التوقيع على الصفحة: اسحبه لمكانه وكبّره وصغّره
struct PlaceView: View {
    let doc: Doc; let pdf: PDFDocument; let sig: UIImage
    let back: () -> Void
    let done: (String) -> Void
    @EnvironmentObject var shelf: Shelf
    @State private var page: Int
    @State private var pos = CGPoint(x: 0.68, y: 0.82)          // مركز التوقيع بنسب الصفحة
    @State private var scale = 0.34                              // عرضه نسبةً لعرض الصفحة
    @State private var dragStart: CGPoint? = nil

    init(doc: Doc, pdf: PDFDocument, sig: UIImage, back: @escaping () -> Void, done: @escaping (String) -> Void) {
        self.doc = doc; self.pdf = pdf; self.sig = sig; self.back = back; self.done = done
        _page = State(initialValue: max(0, pdf.pageCount - 1))            // بالعادة التوقيع بآخر صفحة
    }

    var body: some View {
        let ratio = sig.size.height / max(1, sig.size.width)
        ToolPage(title: "حطّ التوقيع", sub: "اسحبه لمكانه — الصفحة \(page + 1) من \(pdf.pageCount)") {
            GeometryReader { g in
                if let p = pdf.page(at: page) {
                    let ps = PDFOps.size(p)
                    let fit = min(g.size.width / ps.width, g.size.height / ps.height)
                    let w = ps.width * fit, h = ps.height * fit
                    ZStack(alignment: .topLeading) {
                        PageThumb(page: p, width: 900).id(page).frame(width: w, height: h)
                        Image(uiImage: sig).resizable().frame(width: w * scale, height: w * scale * ratio)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(WQ.violet, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                            .position(x: pos.x * w, y: pos.y * h)
                            .gesture(DragGesture().onChanged { v in
                                if dragStart == nil { dragStart = pos }
                                let s = dragStart ?? pos
                                pos = CGPoint(x: min(0.98, max(0.02, s.x + v.translation.width / w)), y: min(0.98, max(0.02, s.y + v.translation.height / h)))
                            }.onEnded { _ in dragStart = nil })
                    }
                    .frame(width: w, height: h).clipShape(RoundedRectangle(cornerRadius: 6)).shadow(color: .black.opacity(0.5), radius: 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.layoutDirection, .leftToRight)
                }
            }.padding(.horizontal, 20)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "signature").font(.system(size: 12)).foregroundStyle(WQ.tx3)
                    Slider(value: $scale, in: 0.12...0.8).environment(\.layoutDirection, .leftToRight)
                    Image(systemName: "signature").font(.system(size: 20)).foregroundStyle(WQ.tx3)
                }
                if pdf.pageCount > 1 {
                    HStack(spacing: 10) {
                        Button { if page > 0 { page -= 1 } } label: { Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.white).frame(width: 44, height: 40).background(WQ.s2, in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(Press()).opacity(page > 0 ? 1 : 0.3)
                        Text("الصفحة \(page + 1)").font(rnd(14, .heavy)).foregroundStyle(Color.white).frame(maxWidth: .infinity)
                        Button { if page < pdf.pageCount - 1 { page += 1 } } label: { Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.white).frame(width: 44, height: 40).background(WQ.s2, in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(Press()).opacity(page < pdf.pageCount - 1 ? 1 : 0.3)
                    }
                }
                BigButton(title: "ثبّت التوقيع", icon: "checkmark", tint: WQ.violet) { apply(ratio) }
                Button(action: back) { Text("غيّر التوقيع").font(rnd(14, .heavy)).foregroundStyle(WQ.tx3) }.buttonStyle(.plain)
            }.padding(.horizontal, 20).padding(.vertical, 12).background(WQ.s1)
        }
    }
    private func apply(_ ratio: CGFloat) {
        guard let p = pdf.page(at: page), let cg = sig.cgImage else { return }
        let ps = PDFOps.size(p)
        let hw = scale, hh = scale * ratio * ps.width / ps.height             // ارتفاعه بنسب ارتفاع الصفحة
        let rect = CGRect(x: pos.x - hw / 2, y: pos.y - hh / 2, width: hw, height: hh)
        if let out = PDFOps.stamp(pdf, image: cg, page: page, rect: rect), shelf.replace(doc, with: out) { Haptic.ok(); done("انحطّ التوقيع على الصفحة \(page + 1) ✓") }
    }
}
