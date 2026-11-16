import SwiftUI
import PhotosUI
import Vision
import VisionKit

/// يقرا النصّ من صورة الوصل ويرجّعه أسطر مرتّبة من فوق لجوّه
enum JOCR {
    static func lines(from img: UIImage, done: @escaping ([String]) -> Void) {
        guard let cg = img.cgImage else {
            done([])
            return
        }
        let orient = cgOrientation(img.imageOrientation)
        let req = VNRecognizeTextRequest { r, _ in
            let obs = (r.results as? [VNRecognizedTextObservation]) ?? []
            var parts: [JOCR.OCRPart] = []
            for o in obs {
                if let c = o.topCandidates(1).first {
                    let b = o.boundingBox
                    parts.append(JOCR.OCRPart(y: b.midY, x: b.minX, h: b.height, s: c.string))
                }
            }
            let out = JOCR.group(parts)
            DispatchQueue.main.async { done(out) }
        }
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.revision = VNRecognizeTextRequestRevision3
        req.automaticallyDetectsLanguage = true
        var langs = ["en-US"]
        if let sup = try? req.supportedRecognitionLanguages() {
            if sup.contains("ar-SA") { langs = ["ar-SA", "en-US"] }
        }
        req.recognitionLanguages = langs
        DispatchQueue.global(qos: .userInitiated).async {
            let h = VNImageRequestHandler(cgImage: cg, orientation: orient, options: [:])
            do {
                try h.perform([req])
            } catch {
                DispatchQueue.main.async { done([]) }
            }
        }
    }

    struct OCRPart {
        var y: CGFloat
        var x: CGFloat
        var h: CGFloat
        var s: String
    }

    /// يجمع القطع اللي بنفس الارتفاع بسطر واحد
    static func group(_ input: [OCRPart]) -> [String] {
        let parts = input.sorted { $0.y > $1.y }
        var lines: [[OCRPart]] = []
        var ys: [CGFloat] = []
        for p in parts {
            if let ly = ys.last, abs(ly - p.y) < max(0.006, p.h * 0.55) {
                lines[lines.count - 1].append(p)
            } else {
                lines.append([p])
                ys.append(p.y)
            }
        }
        return lines.map { ln in ln.sorted { $0.x < $1.x }.map { $0.s }.joined(separator: " ") }
    }

    static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

/// كاميرا المستندات من آبل (تقصّ الوصل وتعدّله تلقائيًّا)
struct JDocCamera: UIViewControllerRepresentable {
    var onDone: (UIImage?) -> Void

    func makeCoordinator() -> Coord { Coord(onDone: onDone) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coord: NSObject, VNDocumentCameraViewControllerDelegate {
        let onDone: (UIImage?) -> Void
        init(onDone: @escaping (UIImage?) -> Void) { self.onDone = onDone }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onDone(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onDone(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onDone(nil)
        }
    }
}

/// شاشة «صوّر»
struct JScanView: View {
    @EnvironmentObject var store: JStore
    @Environment(\.dismiss) private var dismiss
    var onSaved: (Expense) -> Void

    enum Phase { case pick, reading, result }

    @State private var phase: Phase = .pick
    @State private var image: UIImage?
    @State private var result: ReceiptResult?
    @State private var showCam = false
    @State private var pick: PhotosPickerItem?
    @State private var editing = false

    var body: some View {
        if editing {
            JEditor(existing: nil, draft: draftFromResult(), via: .scan, onSaved: onSaved)
                .environmentObject(store)
        } else {
            main
        }
    }

    private var main: some View {
        ZStack {
            JB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("إلغاء") { dismiss() }
                        .font(rnd(16, .medium)).foregroundColor(JB.tx2)
                    Spacer()
                    Text("صوّر الوصل").font(rnd(17, .bold)).foregroundColor(JB.tx)
                    Spacer()
                    Text("إلغاء").font(rnd(16, .medium)).opacity(0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                switch phase {
                case .pick: pickView
                case .reading: readingView
                case .result: resultView
                }
            }
        }
        .fullScreenCover(isPresented: $showCam) {
            JDocCamera { img in
                showCam = false
                if let img = img { process(img) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pick) { item in
            guard let item = item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    process(img)
                }
            }
        }
        .onAppear {
            if Shot.on {
                result = JScanView.demoResult
                phase = .result
            }
        }
    }

    static let demoResult = Receipt.parse([
        "سوبرماركت النخلة", "حليب x2 ........ 3,000", "خبز ............ 1,000", "رز 5 كغ ........ 6,500",
        "بيض ............ 2,000", "المجموع ...... 12,500", "نقدا 15,000",
    ])

    private var pickView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(JB.mintGrad)
            Text("صوّر أيّ وصل أو فاتورة").font(rnd(20, .bold)).foregroundColor(JB.tx)
            Text("جيبي يلگى المجموع واسم المحلّ لحاله،\nوإنت بس تأكّد.")
                .font(rnd(14.5)).foregroundColor(JB.tx2).multilineTextAlignment(.center).lineSpacing(4)
            Spacer()
            VStack(spacing: 10) {
                if VNDocumentCameraViewController.isSupported {
                    JMintButton(title: "صوّر بالكاميرا", system: "camera.fill") { showCam = true }
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    Label("اختار صورة من الألبوم", systemImage: "photo.on.rectangle")
                        .font(rnd(16, .bold))
                        .foregroundColor(JB.tx)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(JB.card2, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var readingView: some View {
        VStack(spacing: 18) {
            Spacer()
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(JScanSweep())
                    .padding(.horizontal, 40)
            }
            ProgressView().tint(JB.mint)
            Text("ديقرا الوصل…").font(rnd(16, .semibold)).foregroundColor(JB.tx2)
            Spacer()
        }
    }

    @ViewBuilder
    private var resultView: some View {
        let r = result ?? ReceiptResult(merchant: "", total: nil, items: [], cat: "other")
        ScrollView {
            VStack(spacing: 14) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    JReceiptMock()
                }
                VStack(spacing: 0) {
                    HStack {
                        Text(Cats.get(r.cat).emoji + " " + (r.merchant.isEmpty ? "وصل" : r.merchant))
                            .font(rnd(17, .bold)).foregroundColor(JB.tx).lineLimit(1)
                        Spacer()
                        Text(r.total.map { Money.s($0) } ?? "؟")
                            .font(rnd(24, .bold)).foregroundColor(JB.mint)
                    }
                    Text(summary(r))
                        .font(rnd(13)).foregroundColor(JB.tx2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    if !r.items.isEmpty {
                        Rectangle().fill(JB.line).frame(height: 1).padding(.vertical, 10)
                        ForEach(Array(r.items.prefix(6).enumerated()), id: \.offset) { it in
                            HStack {
                                Text(it.element.name).font(rnd(14)).foregroundColor(JB.tx).lineLimit(1)
                                Spacer()
                                Text(Money.s(it.element.price)).font(rnd(14, .semibold)).foregroundColor(JB.tx2)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .padding(16)
                .card(JB.card, 22)
            }
            .padding(.horizontal, 18)
        }
        HStack(spacing: 10) {
            JPlainButton(title: "عدّل", system: "pencil") { editing = true }
            if r.total != nil {
                JMintButton(title: "احفظ", system: "checkmark") { saveResult(r) }
            } else {
                JPlainButton(title: "صوّر ثاني", system: "camera") { phase = .pick }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func summary(_ r: ReceiptResult) -> String {
        if r.total == nil { return "ما گدرت ألگى المجموع — اضغط «عدّل» واكتبه" }
        var s = "لگيت المجموع"
        if !r.items.isEmpty { s += " و" + String(r.items.count) + " مواد" }
        return s + " · الصنف: " + Cats.get(r.cat).name
    }

    private func process(_ img: UIImage) {
        image = img
        phase = .reading
        JOCR.lines(from: img) { lines in
            let r = Receipt.parse(lines)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                result = r
                phase = .result
            }
            if r.total != nil { Haptic.ok() } else { Haptic.bad() }
        }
    }

    private func draftFromResult() -> Draft {
        let r = result ?? ReceiptResult(merchant: "", total: nil, items: [], cat: "other")
        let note = r.merchant.isEmpty ? Cats.get(r.cat).name : r.merchant
        return Draft(amount: r.total, cat: r.cat, note: note, dayOffset: 0)
    }

    private func saveResult(_ r: ReceiptResult) {
        guard let t = r.total, t > 0 else { return }
        let note = r.merchant.isEmpty ? Cats.get(r.cat).name : r.merchant
        let e = Expense(amount: t, cat: r.cat, note: note, date: Date(), via: .scan)
        store.add(e)
        onSaved(e)
        dismiss()
    }
}

/// خطّ مسح يتحرّك فوق الصورة أثناء القراءة
struct JScanSweep: View {
    @State private var down = false

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(colors: [JB.mint.opacity(0), JB.mint.opacity(0.55), JB.mint.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(height: 46)
                .offset(y: down ? geo.size.height - 46 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { down = true }
                }
        }
        .allowsHitTesting(false)
    }
}

/// وصل مرسوم (لصور الشاشات)
struct JReceiptMock: View {
    private let rows: [(String, String)] = [("حليب ×2", "3,000"), ("خبز", "1,000"), ("رز 5 كغ", "6,500"), ("بيض", "2,000")]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("سوبرماركت النخلة").font(rnd(14, .bold))
            Rectangle().fill(Color.black.opacity(0.2)).frame(height: 1)
            ForEach(0..<rows.count, id: \.self) { i in
                HStack {
                    Text(rows[i].0)
                    Spacer()
                    Text(rows[i].1)
                }
                .font(rnd(12.5))
            }
            Rectangle().fill(Color.black.opacity(0.2)).frame(height: 1)
            HStack {
                Text("المجموع").bold()
                Spacer()
                Text("12,500").bold()
            }
            .font(rnd(14))
            .padding(4)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(JB.mint, lineWidth: 2.5))
        }
        .foregroundColor(Color(white: 0.2))
        .padding(16)
        .background(Color(red: 0.953, green: 0.945, blue: 0.918), in: RoundedRectangle(cornerRadius: 8))
        .rotationEffect(.degrees(-2))
        .padding(.horizontal, 40)
        .padding(.vertical, 10)
    }
}
