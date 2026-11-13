import SwiftUI
import PDFKit
import PhotosUI
import VisionKit
import UniformTypeIdentifiers

@main
struct WaraqApp: App {
    @StateObject private var shelf = Shelf()
    var body: some Scene {
        WindowGroup {
            NavigationStack { LibraryView() }
                .environmentObject(shelf)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(WQ.ac)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            WQ.bg
            RadialGradient(colors: [WQ.ac.opacity(0.18), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 460)
        }.ignoresSafeArea()
    }
}

struct LibraryView: View {
    @EnvironmentObject var shelf: Shelf
    @State private var importing = false
    @State private var picks: [PhotosPickerItem] = []
    @State private var scanning = false
    @State private var q = ""
    @State private var open: Doc? = nil
    @State private var renaming: Doc? = nil
    @State private var newName = ""
    @State private var deleting: Doc? = nil
    @State private var merging = false
    @State private var toast = ""
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var list: [Doc] { q.count < 2 ? shelf.docs : shelf.docs.filter { $0.name.localizedCaseInsensitiveContains(q) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ورق").font(rnd(36, .black)).foregroundStyle(Color.white)
                    Text("كلّ أدوات PDF بمكان واحد — وكلّشي يصير على جهازك").font(rnd(13)).foregroundStyle(WQ.tx3)
                }
                HStack(spacing: 10) {
                    action("doc.badge.plus", "ملفّ", "من الملفّات", WQ.ac) { importing = true }
                    PhotosPicker(selection: $picks, maxSelectionCount: 40, matching: .images) { actionLabel("photo.on.rectangle.angled", "صور", "حوّلها PDF", WQ.blue) }.buttonStyle(Press())
                    action("doc.viewfinder", "مسح", "بالكاميرا", WQ.green) { if VNDocumentCameraViewController.isSupported { scanning = true } else { toast = "المسح يحتاج كاميرا الآيفون." } }
                }
                if !toast.isEmpty { Text(toast).font(rnd(13, .bold)).foregroundStyle(WQ.ac2).padding(10).frame(maxWidth: .infinity).background(WQ.ac2.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous)) }

                if shelf.docs.isEmpty { empty } else {
                    HStack {
                        Text("مستنداتي").font(rnd(18, .heavy)).foregroundStyle(Color.white)
                        Text("\(shelf.docs.count)").font(rnd(12, .heavy)).foregroundStyle(WQ.tx2).padding(.horizontal, 8).padding(.vertical, 2).background(WQ.s2, in: Capsule())
                        Spacer()
                        if shelf.docs.count >= 2 {
                            Button { merging = true } label: { Label("دمج ملفّات", systemImage: "square.on.square").font(rnd(13, .heavy)).foregroundStyle(WQ.ac) }.buttonStyle(Press())
                        }
                    }
                    if shelf.docs.count > 6 { field }
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(list) { d in
                            Button { open = d } label: { DocCard(d: d) }.buttonStyle(Press())
                                .contextMenu {
                                    Button { newName = d.name; renaming = d } label: { Label("غيّر الاسم", systemImage: "pencil") }
                                    Button { shelf.duplicate(d) } label: { Label("نسخة ثانية", systemImage: "plus.square.on.square") }
                                    ShareLink(item: shelf.url(d)) { Label("مشاركة", systemImage: "square.and.arrow.up") }
                                    Button(role: .destructive) { deleting = d } label: { Label("حذف", systemImage: "trash") }
                                }
                        }
                    }
                }
            }.padding(18)
        }
        .background(Backdrop())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: Binding(get: { open != nil }, set: { if !$0 { open = nil } })) { if let d = open { DocView(doc: d) } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r { let n = shelf.importFiles(urls); toast = n > 0 ? "" : "ما گدرنا نفتح الملفّ." }
        }
        .onChange(of: picks) { items in
            guard !items.isEmpty else { return }
            Task {
                var imgs: [UIImage] = []
                for it in items { if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) { imgs.append(img) } }
                picks = []
                if let d = shelf.importImages(imgs, name: "صور") { open = d }
            }
        }
        .fullScreenCover(isPresented: $scanning) { Scanner { imgs in scanning = false; if let d = shelf.importImages(imgs, name: "مسح") { open = d } }.ignoresSafeArea() }
        .sheet(isPresented: $merging) { MergeView(base: nil) { d in merging = false; open = d }.environmentObject(shelf).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .alert("اسم المستند", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("الاسم", text: $newName)
            Button("حفظ") { if let d = renaming { shelf.rename(d, newName) } }
            Button("إلغاء", role: .cancel) {}
        }
        .alert("تحذف «\(deleting?.name ?? "")»؟", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("احذفه", role: .destructive) { if let d = deleting { shelf.remove(d) } }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("ينحذف من التطبيق نهائيًّا.") }
        .onAppear {
            guard Shot.on, Shot.name != "home", let d = shelf.docs.first else { return }
            if Shot.name == "merge" { merging = true } else { open = d }
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .bold)).foregroundStyle(WQ.tx3)
            TextField("", text: $q, prompt: Text("دوّر بمستنداتك…").foregroundColor(WQ.tx3)).font(rnd(15, .bold)).foregroundStyle(Color.white)
        }.padding(.horizontal, 14).frame(height: 44).background(WQ.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    private func action(_ icon: String, _ t: String, _ s: String, _ c: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { actionLabel(icon, t, s, c) }.buttonStyle(Press())
    }
    private func actionLabel(_ icon: String, _ t: String, _ s: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(c)
            Text(t).font(rnd(16, .black)).foregroundStyle(Color.white)
            Text(s).font(rnd(11.5)).foregroundStyle(WQ.tx3)
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading).card(WQ.s1, 20, stroke: c.opacity(0.28))
    }
    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.richtext").font(.system(size: 46)).foregroundStyle(WQ.ac)
            Text("ابدي بأوّل مستند").font(rnd(20, .black)).foregroundStyle(Color.white)
            Text("استورد ملفّ PDF، حوّل صورك لمستند، أو امسح ورقة بالكاميرا.\nبعدها تگدر تدمج، تقسّم، توقّع، تضغط، وتقفل بكلمة سرّ.").font(rnd(13.5)).foregroundStyle(WQ.tx2).multilineTextAlignment(.center).lineSpacing(3)
        }.padding(24).frame(maxWidth: .infinity).card(WQ.s1, 24)
    }
}

struct DocCard: View {
    @EnvironmentObject var shelf: Shelf
    let d: Doc
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.aspectRatio(0.74, contentMode: .fit)
                .overlay {
                    if let t = shelf.thumb(d) { Image(uiImage: t).resizable().aspectRatio(contentMode: .fill) }
                    else { ZStack { WQ.s2; Image(systemName: d.locked ? "lock.fill" : "doc.fill").font(.system(size: 34)).foregroundStyle(d.locked ? WQ.ac2 : WQ.tx3) } }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) { if d.locked { Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white).padding(6).background(WQ.ac2, in: Circle()).padding(7) } }
                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
            Text(d.name).font(rnd(14.5, .heavy)).foregroundStyle(Color.white).lineLimit(1)
            Text("\(d.pages) صفحة · \(PDFOps.bytes(d.bytes))").font(rnd(11.5)).foregroundStyle(WQ.tx3).lineLimit(1)
        }
    }
}

/// ماسح المستندات مال آبل (يقصّ الورقة ويعدّل المنظور لحاله)
struct Scanner: UIViewControllerRepresentable {
    let done: ([UIImage]) -> Void
    func makeCoordinator() -> Co { Co(done) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController { let v = VNDocumentCameraViewController(); v.delegate = context.coordinator; return v }
    func updateUIViewController(_ v: VNDocumentCameraViewController, context: Context) {}
    final class Co: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([UIImage]) -> Void
        init(_ d: @escaping ([UIImage]) -> Void) { done = d }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) { done((0..<scan.pageCount).map { scan.imageOfPage(at: $0) }) }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { done([]) }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError error: Error) { done([]) }
    }
}

struct BigButton: View {
    let title: String; var icon: String = ""; var tint: Color = WQ.ac; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { if !icon.isEmpty { Image(systemName: icon).font(.system(size: 16, weight: .bold)) }; Text(title).font(rnd(17, .heavy)) }
                .foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 54).background(tint, in: Capsule())
        }.buttonStyle(Press())
    }
}
