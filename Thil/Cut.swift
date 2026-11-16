import SwiftUI
import UIKit

struct CutLaunch { let image: UIImage?; let demo: Bool }
struct CutResult { let image: String; let hOverW: Double; let source: String? }

struct SessionBox: @unchecked Sendable { let s: SubjectSession? }

/// شاشة القصّ: الذكاء يلقط المواضيع، والمستخدم ينقر ليختار أيّ عنصر
struct CutView: View {
    let launch: CutLaunch
    let title: String
    let onDone: (CutResult?) -> Void
    @EnvironmentObject var bank: Bank
    @State private var session: SubjectSession?
    @State private var phase = 0          // 0 تحليل · 1 جاهز · 2 فشل
    @State private var sel: Set<Int> = []
    @State private var count = 0
    @State private var preview: UIImage?
    @State private var original: UIImage?
    @State private var working = false
    @State private var scan = false
    @State private var reveal = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RoundBtn(icon: "xmark") { onDone(nil) }
                Spacer()
                Text(title).font(rnd(16, .heavy)).foregroundStyle(Color.white)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }.padding(.horizontal, 14).padding(.top, 6)

            GeometryReader { geo in imageArea(geo.size) }
                .padding(14)

            bottom
        }
        .background(Backdrop())
        .task { await analyze() }
    }

    // MARK: الصورة

    private func shownRect(_ box: CGSize) -> TRect {
        let s = original?.size ?? CGSize(width: 3, height: 4)
        return Fit.fit(TSize(Double(s.width), Double(s.height)), in: TRect(0, 0, Double(box.width), Double(box.height)))
    }

    @ViewBuilder private func imageArea(_ box: CGSize) -> some View {
        let r = shownRect(box)
        let w = CGFloat(r.w), h = CGFloat(r.h)
        ZStack {
            if let o = original {
                Image(uiImage: o).resizable().frame(width: w, height: h)
                    .saturation(phase == 1 ? 0.2 : 1)
                    .brightness(phase == 1 ? -0.35 : 0)
                    .animation(.easeOut(duration: 0.5), value: phase)
            } else {
                RoundedRectangle(cornerRadius: 18).fill(TH.s1).frame(width: w, height: h)
            }
            if phase == 1, let p = preview {
                Image(uiImage: p).resizable().frame(width: w, height: h)
                    .shadow(color: TH.mint.opacity(0.9), radius: 3)
                    .shadow(color: TH.mint.opacity(0.6), radius: 14)
                    .scaleEffect(reveal ? 1 : 0.97)
                    .opacity(reveal ? 1 : 0)
                    .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { reveal = true } }
            }
            if phase == 0 {
                LinearGradient(colors: [Color.clear, TH.mint.opacity(0.55), Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: 90)
                    .offset(y: scan ? h / 2 : -h / 2)
                    .frame(width: w, height: h).clipped()
                    .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { scan = true } }
            }
            if working { ProgressView().tint(Color.white).scaleEffect(1.4) }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { p in tapped(p, w, h) }
        .position(x: CGFloat(r.midX), y: CGFloat(r.midY))
    }

    // MARK: الأسفل

    private var bottom: some View {
        VStack(spacing: 12) {
            switch phase {
            case 0:
                HStack(spacing: 10) {
                    ProgressView().tint(TH.mint)
                    Text("الذكاء يدوّر على المواضيع…").font(rnd(15, .bold)).foregroundStyle(TH.tx2)
                }.frame(height: 110)
            case 2:
                VStack(spacing: 10) {
                    Image(systemName: "eye.trianglebadge.exclamationmark").font(.system(size: 26, weight: .bold)).foregroundStyle(TH.coral)
                    Text("ما لگينا موضوع واضح بهالصورة").font(rnd(16, .heavy)).foregroundStyle(Color.white)
                    Text("جرّب صورة الموضوع بيها واضح وقريب، أو خلفيّة أبسط").font(rnd(13)).foregroundStyle(TH.tx3)
                    GradBtn(title: "اختار صورة ثانية", icon: "photo") { onDone(nil) }.padding(.horizontal, 30)
                }.padding(.bottom, 12)
            default:
                readyControls
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
    }

    private var readyControls: some View {
        VStack(spacing: 12) {
            if count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("الكلّ", sel.count == count) { sel = Set(1...count); refresh() }
                        ForEach(1...count, id: \.self) { i in
                            chip("عنصر \(i)", sel.contains(i)) { toggle(i) }
                        }
                    }.padding(.horizontal, 2)
                }
                Text("انقر على أيّ عنصر بالصورة حتى تضيفه أو تشيله").font(rnd(12.5)).foregroundStyle(TH.tx3)
            } else if session?.personOnly == true {
                Text("على هالجهاز نقصّ الأشخاص · iOS 17 يقصّ أيّ شي").font(rnd(12.5)).foregroundStyle(TH.tx3)
            } else {
                Text("لگينا الموضوع ✓ — تگدر تعدّل كلّشي بالاستوديو").font(rnd(12.5)).foregroundStyle(TH.tx3)
            }
            GradBtn(title: "قصّ وكمّل", icon: "scissors") { confirm() }
                .disabled(sel.isEmpty || working).opacity(sel.isEmpty ? 0.4 : 1)
        }
    }

    private func chip(_ t: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
        Button { HX.tap(); act() } label: {
            Text(t).font(rnd(13, .bold)).foregroundStyle(on ? Color.black.opacity(0.85) : Color.white)
                .padding(.horizontal, 14).frame(height: 34)
                .background(on ? AnyShapeStyle(TH.mint) : AnyShapeStyle(TH.s2), in: Capsule())
        }.buttonStyle(Press())
    }

    // MARK: المنطق

    private func analyze() async {
        if launch.demo {
            original = Demo.scene(bg: true, which: [1, 2])
            try? await Task.sleep(nanoseconds: 300_000_000)
            count = 2
            sel = [1]
            preview = Demo.scene(bg: false, which: [1])
            phase = 1
            return
        }
        guard let img = launch.image else { phase = 2; return }
        original = Engine.normalized(img, maxSide: 1400)
        let box: SessionBox = await Task.detached(priority: .userInitiated) { () -> SessionBox in
            guard let s = SubjectSession(image: img), s.analyze() else { return SessionBox(s: nil) }
            return SessionBox(s: s)
        }.value
        guard let s = box.s else { phase = 2; HX.bad(); return }
        session = s
        original = s.image
        count = s.personOnly ? 1 : s.count
        sel = Set(1...max(1, count))
        await computePreview()
        phase = preview == nil ? 2 : 1
        if phase == 1 { HX.ok() } else { HX.bad() }
    }

    private func computePreview() async {
        if launch.demo {
            preview = Demo.scene(bg: false, which: sel)
            return
        }
        guard let s = session else { return }
        let chosen = sel
        let b: ImgBox = await Task.detached(priority: .userInitiated) { () -> ImgBox in ImgBox(img: s.preview(chosen)) }.value
        preview = b.img
    }

    private func refresh() {
        reveal = true
        Task { await computePreview() }
    }

    private func toggle(_ i: Int) {
        if sel.contains(i) { sel.remove(i) } else { sel.insert(i) }
        refresh()
    }

    private func tapped(_ p: CGPoint, _ w: CGFloat, _ h: CGFloat) {
        guard phase == 1, w > 0, h > 0 else { return }
        let nx = Double(p.x / w), ny = Double(p.y / h)
        if launch.demo {
            let pt = CGPoint(x: nx, y: ny)
            if Demo.figureRect.contains(pt) { toggle(1); HX.tap() } else if Demo.plantRect.contains(pt) { toggle(2); HX.tap() }
            return
        }
        guard let s = session, !s.personOnly, let i = s.instance(atX: nx, y: ny) else { return }
        HX.tap()
        toggle(i)
    }

    private func confirm() {
        guard !sel.isEmpty else { return }
        if launch.demo {
            onDone(CutResult(image: Demo.figureID, hOverW: Demo.figureRatio, source: Demo.sceneID))
            return
        }
        guard let s = session else { return }
        working = true
        let chosen = sel
        Task {
            let b: ImgBox = await Task.detached(priority: .userInitiated) { () -> ImgBox in ImgBox(img: s.cutout(chosen)) }.value
            working = false
            guard let img = b.img, img.size.width > 2 else { HX.bad(); return }
            let id = bank.putPNG(img)
            let src = bank.putJPEG(s.image)
            StatBox.update { $0.cuts += 1 }
            HX.ok()
            onDone(CutResult(image: id, hOverW: Double(img.size.height / img.size.width), source: src))
        }
    }
}

// MARK: - اختيار القالب بعد القصّ

struct TemplatePicker: View {
    let cut: CutResult
    let onBack: () -> Void
    let onPick: (Project) -> Void
    @EnvironmentObject var bank: Bank
    @State private var pid = "P" + String(UUID().uuidString.prefix(10))
    @State private var appear = false

    private func build(_ t: Template, name: String = "تصميم") -> Project {
        var n = 0
        let gen: () -> String = { n += 1; return "L\(n)-" + String(UUID().uuidString.prefix(6)) }
        return Templates.build(t, cuts: [CutRef(cut.image, cut.hOverW)], source: cut.source, id: pid, name: name, now: Date().timeIntervalSince1970, newID: gen)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RoundBtn(icon: "xmark") { onBack() }
                Spacer()
                VStack(spacing: 2) {
                    Text("اختار شكل التصميم").font(rnd(17, .heavy)).foregroundStyle(Color.white)
                    Text("تگدر تغيّره بعدين من «القوالب»").font(rnd(11.5)).foregroundStyle(TH.tx3)
                }
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }.padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 8)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(Templates.all.enumerated()), id: \.element.id) { i, t in
                        TemplateCell(t: t, project: build(t), tick: bank.tick) { HX.ok(); onPick(build(t, name: ProjectStore.nextName(bank.store.all().map { $0.name }))) }
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 24)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(i) * 0.05), value: appear)
                    }
                }.padding(.horizontal, 14).padding(.bottom, 24)
            }
        }
        .background(Backdrop())
        .onAppear { appear = true }
    }
}

struct TemplateCell: View {
    let t: Template
    let project: Project
    let tick: Int
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                MiniStage(project: project, box: CGSize(width: 150, height: 170), tick: tick)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 6) {
                    Image(systemName: t.symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(TH.coral)
                    Text(t.title).font(rnd(15, .heavy)).foregroundStyle(Color.white)
                    Spacer()
                    Text(t.aspect.label).font(rnd(10.5, .bold)).foregroundStyle(TH.tx3).environment(\.layoutDirection, .leftToRight)
                }
                Text(t.note).font(rnd(11.5)).foregroundStyle(TH.tx3).lineLimit(2).multilineTextAlignment(.leading)
            }
            .padding(10).card(TH.s1, 20)
        }.buttonStyle(Press())
    }
}

// MARK: - مسار المشروع الجديد (قصّ ← قالب ← استوديو) بشاشة وحدة

struct FlowLaunch: Identifiable {
    enum Start { case cut(CutLaunch), templates(CutResult), studio(Project) }
    let id = UUID()
    let start: Start
}

struct FlowView: View {
    enum Step { case cut(CutLaunch), templates(CutResult), studio(Project) }
    let onClose: () -> Void
    @EnvironmentObject var bank: Bank
    @State private var step: Step

    init(launch: FlowLaunch, onClose: @escaping () -> Void) {
        self.onClose = onClose
        switch launch.start {
        case .cut(let c): _step = State(initialValue: .cut(c))
        case .templates(let r): _step = State(initialValue: .templates(r))
        case .studio(let p): _step = State(initialValue: .studio(p))
        }
    }

    var body: some View {
        ZStack {
            switch step {
            case .cut(let c):
                CutView(launch: c, title: "قصّة جديدة") { r in
                    if let r { withAnimation(.easeInOut(duration: 0.3)) { step = .templates(r) } } else { onClose() }
                }.transition(.opacity)
            case .templates(let r):
                TemplatePicker(cut: r, onBack: onClose) { p in
                    if !Shot.on { try? bank.store.save(p) }
                    withAnimation(.easeInOut(duration: 0.3)) { step = .studio(p) }
                }.transition(.opacity)
            case .studio(let p):
                StudioView(project: p, persist: !Shot.on, onClose: onClose).transition(.opacity)
            }
        }
    }
}
