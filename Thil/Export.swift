import SwiftUI
import UIKit
import Photos

struct ShareItem: Identifiable { let id = UUID(); let urls: [URL] }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

enum PhotoSaver {
    /// يطلب إذن «الإضافة فقط» ويحفظ الملفّ بنفس صيغته (PNG يحافظ على الشفافيّة)
    static func save(_ data: Data, done: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { st in
            guard st == .authorized || st == .limited else { DispatchQueue.main.async { done(false) }; return }
            PHPhotoLibrary.shared().performChanges({
                let r = PHAssetCreationRequest.forAsset()
                r.addResource(with: .photo, data: data, options: nil)
            }) { ok, _ in DispatchQueue.main.async { done(ok) } }
        }
    }
}

struct ExportView: View {
    let project: Project
    let selectedID: String?
    @EnvironmentObject var bank: Bank
    @Environment(\.dismiss) private var dismiss
    @AppStorage("th_res") private var res = 1080
    @State private var png = false
    @State private var busy = false
    @State private var toast: String?
    @State private var share: ShareItem?

    private var cutLayers: [Layer] { project.layers.filter { !$0.isText && !$0.hidden } }
    private var pngForced: Bool { project.bkg.isClear }
    private var usePNG: Bool { png || pngForced }

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.white.opacity(0.2)).frame(width: 40, height: 5).padding(.top, 8)
            HStack {
                Text("صدّر تصميمك").font(rnd(22, .black)).foregroundStyle(Color.white)
                Spacer()
                RoundBtn(icon: "xmark") { dismiss() }
            }
            preview
            options
            actions
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .background(Backdrop())
        .overlay(alignment: .top) { toastView }
        .overlay { if busy { LoadingVeil(text: "نرسم بدقّة عالية…") } }
        .sheet(item: $share) { s in ShareSheet(items: s.urls) }
    }

    private var preview: some View {
        GeometryReader { geo in
            let r = Fit.fit(TSize(project.aspect.ratio, 1), in: TRect(0, 0, Double(geo.size.width), Double(geo.size.height)))
            ZStack {
                if project.bkg.isClear { Checker().frame(width: CGFloat(r.w), height: CGFloat(r.h)) }
                StageView(project: project, size: CGSize(width: max(1, r.w), height: max(1, r.h)), export: true, tick: bank.tick)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: TH.magenta.opacity(0.3), radius: 24, y: 10)
            .position(x: CGFloat(r.midX), y: CGFloat(r.midY))
        }
        .frame(height: 290)
    }

    private var options: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("الدقّة").font(rnd(13, .bold)).foregroundStyle(TH.tx3).frame(width: 52, alignment: .leading)
                ForEach([1080, 1440, 2160], id: \.self) { v in
                    seg(v == 2160 ? "4K" : "\(v)", res == v) { res = v }
                }
            }
            HStack(spacing: 8) {
                Text("الصيغة").font(rnd(13, .bold)).foregroundStyle(TH.tx3).frame(width: 52, alignment: .leading)
                seg("JPG", !usePNG) { png = false }.disabled(pngForced).opacity(pngForced ? 0.4 : 1)
                seg("PNG", usePNG) { png = true }
            }
            let px = project.aspect.pixelSize(width: Double(res))
            Text("\(Int(px.w)) × \(Int(px.h)) بكسل · \(usePNG ? "يحافظ على الشفافيّة" : "حجم أصغر")")
                .font(rnd(11.5)).foregroundStyle(TH.tx3).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14).card(TH.s1, 20)
    }

    private func seg(_ t: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
        Button { HX.tap(); act() } label: {
            Text(t).font(rnd(13.5, .heavy)).foregroundStyle(on ? Color.black.opacity(0.85) : Color.white)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(on ? AnyShapeStyle(TH.grad) : AnyShapeStyle(TH.s2), in: Capsule())
        }.buttonStyle(Press())
    }

    private var actions: some View {
        VStack(spacing: 10) {
            GradBtn(title: "احفظ بالصور", icon: "square.and.arrow.down.fill") { saveToPhotos() }
            HStack(spacing: 10) {
                bigBtn("شارك", "square.and.arrow.up") { shareImage() }
                bigBtn(cutLayers.count > 1 ? "ملصقات (\(cutLayers.count))" : "ملصق شفّاف", "seal.fill") { shareStickers() }.disabled(cutLayers.isEmpty).opacity(cutLayers.isEmpty ? 0.4 : 1)
            }
        }
    }

    private func bigBtn(_ t: String, _ icon: String, _ act: @escaping () -> Void) -> some View {
        Button { HX.tap(); act() } label: {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold))
                Text(t).font(rnd(15, .heavy))
            }
            .foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 50)
            .background(TH.s2, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.1)))
        }.buttonStyle(Press())
    }

    @ViewBuilder private var toastView: some View {
        if let t = toast {
            Text(t).font(rnd(14, .heavy)).foregroundStyle(Color.black.opacity(0.85))
                .padding(.horizontal, 18).frame(height: 42).background(TH.mint, in: Capsule())
                .shadow(color: TH.mint.opacity(0.4), radius: 12)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func flash(_ t: String) {
        withAnimation(.spring(response: 0.4)) { toast = t }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation { toast = nil }
        }
    }

    private func render() -> Data? {
        guard let img = Render.image(project, width: CGFloat(res)) else { return nil }
        return Render.data(img, png: usePNG)
    }

    private func saveToPhotos() {
        if Shot.on { flash("انحفظ بالصور ✓"); return }
        busy = true
        Task { @MainActor in
            await Task.yield()
            let d = render()
            guard let d else { busy = false; HX.bad(); flash("ما گدرنا نرسم الصورة"); return }
            PhotoSaver.save(d) { ok in
                busy = false
                if ok {
                    HX.ok(); flash("انحفظ بالصور ✓")
                    StatBox.update { $0.noteExport(layers: project.layers.count, stickers: 0) }
                } else {
                    HX.bad(); flash("نحتاج إذن الصور من الإعدادات")
                }
            }
        }
    }

    private func shareImage() {
        if Shot.on { return }
        busy = true
        Task { @MainActor in
            await Task.yield()
            defer { busy = false }
            guard let d = render(), let u = Render.tempFile(d, name: "thil-\(project.id.prefix(6)).\(usePNG ? "png" : "jpg")") else { HX.bad(); return }
            StatBox.update { $0.noteExport(layers: project.layers.count, stickers: 0) }
            share = ShareItem(urls: [u])
        }
    }

    private func shareStickers() {
        if Shot.on { return }
        busy = true
        Task { @MainActor in
            await Task.yield()
            defer { busy = false }
            var urls: [URL] = []
            let list = selectedID.flatMap { id in cutLayers.first { $0.id == id } }.map { [$0] } ?? cutLayers
            let chosen = cutLayers.count > 1 ? cutLayers : list
            for (i, l) in chosen.enumerated() {
                if let img = Render.sticker(l), let d = img.pngData(), let u = Render.tempFile(d, name: "sticker-\(i + 1).png") { urls.append(u) }
            }
            guard !urls.isEmpty else { HX.bad(); return }
            StatBox.update { $0.noteExport(layers: project.layers.count, stickers: urls.count) }
            HX.ok()
            share = ShareItem(urls: urls)
        }
    }
}
