import SwiftUI
import PDFKit

struct PDFBox: UIViewRepresentable {
    let doc: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true; v.displayMode = .singlePageContinuous; v.displayDirection = .vertical
        v.backgroundColor = UIColor(WQ.bg); v.pageShadowsEnabled = true
        v.document = doc
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) { if v.document !== doc { v.document = doc } }
}

enum Tool: String, Identifiable { case pages, sign, merge, split, compress, protect, watermark, text, images; var id: String { rawValue } }

struct DocView: View {
    let doc: Doc
    @EnvironmentObject var shelf: Shelf
    @Environment(\.dismiss) private var dismiss
    @State private var pdf: PDFDocument? = nil
    @State private var tools = false
    @State private var tool: Tool? = nil
    @State private var askPass = false
    @State private var pass = ""
    @State private var wrong = false
    @State private var toast = ""
    @State private var numbering = false

    private var live: Doc { shelf.current(doc) }

    var body: some View {
        ZStack {
            WQ.bg.ignoresSafeArea()
            if let p = pdf, !p.isLocked { PDFBox(doc: p).ignoresSafeArea(edges: .bottom) }
            else if live.locked { lockedView }
            else { ProgressView().tint(WQ.ac) }
            VStack {
                if !toast.isEmpty { Text(toast).font(rnd(13.5, .heavy)).foregroundStyle(Color.white).padding(.horizontal, 16).frame(height: 40).background(WQ.green.opacity(0.9), in: Capsule()).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity)) }
                Spacer()
                if pdf != nil && !(pdf?.isLocked ?? true) { bar }
            }
        }
        .navigationTitle(live.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { ShareLink(item: shelf.url(live)) { Image(systemName: "square.and.arrow.up") } } }
        .onAppear { if pdf == nil { reload() }; shot() }
        .sheet(isPresented: $tools) { ToolsSheet(locked: live.locked) { t in tools = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pick(t) } }.environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark).presentationDetents([.large]) }
        .sheet(item: $tool, onDismiss: reload) { t in sheet(t).environmentObject(shelf).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .alert("كلمة سرّ الملفّ", isPresented: $askPass) {
            SecureField("كلمة السرّ", text: $pass)
            Button("افتح") { unlock() }
            Button("إلغاء", role: .cancel) {}
        } message: { Text(wrong ? "كلمة السرّ غلط، جرّب مرّة ثانية." : "هالملفّ مقفول.") }
        .alert("ترقّم الصفحات؟", isPresented: $numbering) {
            Button("رقّم") { if let p = pdf, let n = PDFOps.numbered(p), shelf.replace(live, with: n) { reload(); say("انضافت أرقام الصفحات ✓") } }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("ينضاف رقم بأسفل كلّ صفحة (مثل 2 / 10).") }
    }

    private func reload() {
        let p = shelf.pdf(live)
        if let p, p.isLocked, !pass.isEmpty { _ = p.unlock(withPassword: pass) }
        pdf = p
    }
    private func unlock() {
        guard let p = shelf.pdf(live) else { return }
        if p.unlock(withPassword: pass) { pdf = p; wrong = false } else { wrong = true; pass = ""; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { askPass = true } }
    }
    private func say(_ t: String) { withAnimation { toast = t }; DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { toast = "" } } }
    private func pick(_ t: String) {
        if t == "number" { numbering = true } else { tool = Tool(rawValue: t) }
    }
    private func shot() {
        guard Shot.on else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            switch Shot.name {
            case "tools": tools = true
            case "pages", "sign", "place", "split", "compress", "protect", "watermark", "text": tool = Tool(rawValue: Shot.name == "place" ? "sign" : Shot.name)
            default: break
            }
        }
    }

    @ViewBuilder private func sheet(_ t: Tool) -> some View {
        if let p = pdf {
            switch t {
            case .pages: PagesView(doc: live, pdf: p) { say($0) }
            case .sign: SignView(doc: live, pdf: p) { say($0) }
            case .merge: MergeView(base: live) { _ in tool = nil; say("انحفظ الملفّ المدموج بمستنداتك ✓") }
            case .split: SplitView(doc: live, pdf: p) { say($0) }
            case .compress: CompressView(doc: live, pdf: p) { say($0) }
            case .protect: ProtectView(doc: live, pdf: p, password: pass) { msg, newPass in pass = newPass; say(msg) }
            case .watermark: WatermarkView(doc: live, pdf: p) { say($0) }
            case .text: TextSheet(pdf: p)
            case .images: ImagesSheet(doc: live, pdf: p)
            }
        }
    }

    private var bar: some View {
        HStack(spacing: 8) {
            barBtn("square.grid.2x2.fill", "الصفحات") { tool = .pages }
            barBtn("signature", "توقيع") { tool = .sign }
            barBtn("wand.and.stars", "كلّ الأدوات", primary: true) { tools = true }
        }
        .padding(8).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(white: 1, opacity: 0.1)))
        .padding(.horizontal, 14).padding(.bottom, 6)
    }
    private func barBtn(_ icon: String, _ t: String, primary: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 6) { Image(systemName: icon).font(.system(size: 15, weight: .bold)); Text(t).font(rnd(14, .heavy)) }
                .foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 46).background(primary ? WQ.ac : WQ.s3.opacity(0.7), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }.buttonStyle(Press())
    }
    private var lockedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill").font(.system(size: 50)).foregroundStyle(WQ.ac2)
            Text("الملفّ مقفول بكلمة سرّ").font(rnd(20, .black)).foregroundStyle(Color.white)
            BigButton(title: "اكتب كلمة السرّ", icon: "key.fill", tint: WQ.ac2) { askPass = true }.frame(width: 240)
        }
    }
}

/// قائمة كلّ الأدوات
struct ToolsSheet: View {
    let locked: Bool
    let pick: (String) -> Void
    private let items: [(String, String, String, String, Color)] = [
        ("pages", "square.grid.2x2.fill", "ترتيب الصفحات", "تدوير، حذف، تبديل الأماكن، واستخراج", WQ.blue),
        ("sign", "signature", "توقيع", "ارسم توقيعك وحطّه على أيّ صفحة", WQ.violet),
        ("merge", "square.on.square", "دمج مع ملفّات ثانية", "اجمع أكثر من مستند بملفّ واحد", WQ.green),
        ("split", "scissors", "تقسيم", "كلّ صفحة ملفّ، أو نطاق تختاره", WQ.ac2),
        ("compress", "arrow.down.right.and.arrow.up.left", "ضغط الحجم", "صغّر الملفّ حتى ينبعث بسهولة", WQ.ac),
        ("protect", "lock.fill", "قفل بكلمة سرّ", "محّد يفتحه بلا الكلمة", WQ.ac2),
        ("watermark", "drop.fill", "علامة مائيّة", "نصّ شفّاف مايل على كلّ الصفحات", WQ.blue),
        ("number", "number", "ترقيم الصفحات", "رقم بأسفل كلّ صفحة", WQ.green),
        ("text", "text.viewfinder", "استخراج النصّ", "انسخ نصّ المستند — حتى من الصور", WQ.violet),
        ("images", "photo.stack.fill", "حوّل الصفحات لصور", "كلّ صفحة صورة تنحفظ أو تنبعث", WQ.ac)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("الأدوات").font(rnd(26, .black)).foregroundStyle(Color.white).padding(.bottom, 4)
                ForEach(items, id: \.0) { it in
                    Button { pick(it.0) } label: {
                        HStack(spacing: 13) {
                            Image(systemName: it.1).font(.system(size: 17, weight: .bold)).foregroundStyle(it.4).frame(width: 46, height: 46).background(it.4.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) { Text(it.2).font(rnd(16, .heavy)).foregroundStyle(Color.white); Text(it.3).font(rnd(12)).foregroundStyle(WQ.tx3).lineLimit(1) }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold)).foregroundStyle(WQ.tx3)
                        }.padding(11).card(WQ.s1, 18)
                    }.buttonStyle(Press())
                }
            }.padding(20)
        }.background(WQ.bg.ignoresSafeArea())
    }
}

/// رأس موحّد لشاشات الأدوات
struct ToolPage<C: View>: View {
    let title: String; let sub: String
    @ViewBuilder let content: () -> C
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) { Text(title).font(rnd(24, .black)).foregroundStyle(Color.white); Text(sub).font(rnd(12.5)).foregroundStyle(WQ.tx3) }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.white).frame(width: 38, height: 38).background(WQ.s2, in: Circle()) }.buttonStyle(Press())
            }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 10)
            content()
        }.background(WQ.bg.ignoresSafeArea())
    }
}
