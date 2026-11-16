import SwiftUI
import PhotosUI

@MainActor final class StudioModel: ObservableObject {
    @Published var project: Project
    @Published var selected: String?
    @Published private(set) var hist = History<Project>(limit: 80)
    @Published var guideX = false
    @Published var guideY = false
    private var gestureStart: Project?
    let persist: Bool

    init(_ p: Project, persist: Bool) {
        project = p
        self.persist = persist
        selected = p.layers.last(where: { !$0.locked && !$0.isText })?.id ?? p.layers.last?.id
    }

    var sel: Layer? {
        guard let s = selected else { return nil }
        return project.layer(s)
    }
    static func newID() -> String { "L" + String(UUID().uuidString.prefix(10)) }
    private var now: Double { Date().timeIntervalSince1970 }

    func commit(_ f: (inout Project) -> Void) {
        let before = project
        var p = project
        f(&p)
        guard p != before else { return }
        p.modified = now
        hist.record(before)
        project = p
        save()
    }
    func live(_ f: (inout Project) -> Void) {
        var p = project
        f(&p)
        if p != project { project = p }
    }
    func begin() { if gestureStart == nil { gestureStart = project } }
    func end() {
        if let s = gestureStart, s != project {
            hist.record(s)
            project.modified = now
            save()
        }
        gestureStart = nil
        guideX = false
        guideY = false
    }
    func updateSel(_ f: (inout Layer) -> Void) {
        guard let s = selected else { return }
        commit { p in if let i = p.index(of: s) { f(&p.layers[i]) } }
    }
    func liveSel(_ f: (inout Layer) -> Void) {
        guard let s = selected else { return }
        live { p in if let i = p.index(of: s) { f(&p.layers[i]) } }
    }

    func undo() {
        end()
        if let p = hist.undo(project) { project = p; fixSel(); save(); HX.tap() }
    }
    func redo() {
        end()
        if let p = hist.redo(project) { project = p; fixSel(); save(); HX.tap() }
    }
    private func fixSel() { if let s = selected, project.index(of: s) == nil { selected = nil } }

    func save() {
        guard persist else { return }
        try? Bank.shared.store.save(project)
    }
    func close() {
        end()
        guard persist else { return }
        save()
        Bank.shared.saveThumb(project)
    }

    // MARK: أوامر الطبقات

    func addCut(_ image: String, hOverW: Double) {
        var l = Layer.cutout(id: StudioModel.newID(), image: image, hOverW: hOverW, name: "قصّة \(project.cutoutCount + 1)")
        l.xf.scale = Fit.scaleToFit(hOverW: hOverW, maxW: 0.6, maxH: 0.6, canvasRatio: project.aspect.ratio)
        let k = Double(project.layers.count % 4)
        l.xf.cx = 0.5 + (k - 1.5) * 0.03
        l.xf.cy = 0.5 + (k - 1.5) * 0.03
        l.fx.shadow = 0.3
        commit { $0.add(l) }
        selected = l.id
        HX.ok()
    }
    func addText() {
        var l = Layer.text(id: StudioModel.newID(), "اكتب هنا", size: 0.1, color: .white)
        l.xf.cy = 0.18
        l.fx.shadow = 0.4
        commit { $0.add(l) }
        selected = l.id
        HX.tap()
    }
    func duplicate() {
        guard let s = selected else { return }
        let nid = StudioModel.newID()
        commit { $0.duplicate(s, newID: nid) }
        selected = nid
        HX.tap()
    }
    func delete() {
        guard let s = selected else { return }
        commit { $0.remove(s) }
        selected = project.layers.last?.id
        HX.thud()
    }
    func up() { guard let s = selected else { return }; commit { $0.moveUp(s) } }
    func down() { guard let s = selected else { return }; commit { $0.moveDown(s) } }
    func toggleFlip() { updateSel { $0.xf.flip.toggle() } }
    func toggleHide() { updateSel { $0.hidden.toggle() } }
    func toggleLock() { updateSel { $0.locked.toggle() } }
    func recenter() {
        updateSel { l in
            l.xf.cx = 0.5; l.xf.cy = 0.5; l.xf.rot = 0
            if !l.isText { l.xf.scale = Fit.scaleToFit(hOverW: l.hOverW, maxW: 0.7, maxH: 0.7, canvasRatio: project.aspect.ratio) }
        }
    }
    func setAspect(_ a: Aspect) { commit { $0.aspect = a }; HX.tap() }
    func setBkg(_ b: Bkg) { commit { $0.bkg = b }; HX.tap() }
    func applyTemplate(_ t: Template) {
        let n = Templates.restyle(project, with: t, now: now, newID: { StudioModel.newID() })
        commit { $0 = n }
        selected = project.layers.last(where: { !$0.isText })?.id
        HX.ok()
    }
}

enum Tool: String, CaseIterable, Identifiable {
    case layers, bkg, fx, text, size, look
    var id: String { rawValue }
    var title: String {
        switch self {
        case .layers: return "الطبقات"
        case .bkg: return "الخلفيّة"
        case .fx: return "التأثيرات"
        case .text: return "النصّ"
        case .size: return "المقاس"
        case .look: return "القوالب"
        }
    }
    var icon: String {
        switch self {
        case .layers: return "square.3.layers.3d"
        case .bkg: return "paintpalette.fill"
        case .fx: return "wand.and.stars"
        case .text: return "textformat"
        case .size: return "aspectratio.fill"
        case .look: return "rectangle.grid.2x2.fill"
        }
    }
}

struct CutAdd: Identifiable { let id = UUID(); let launch: CutLaunch }

struct StudioView: View {
    @StateObject private var m: StudioModel
    @EnvironmentObject var bank: Bank
    let onClose: () -> Void
    @State private var tab: Tool = .layers
    @State private var showExport = false
    @State private var cutItem: PhotosPickerItem?
    @State private var bgItem: PhotosPickerItem?
    @State private var cutAdd: CutAdd?
    @State private var loading = false

    init(project: Project, persist: Bool, onClose: @escaping () -> Void) {
        _m = StateObject(wrappedValue: StudioModel(project, persist: persist))
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            StageArea(m: m, tick: bank.tick).frame(maxWidth: .infinity, maxHeight: .infinity)
            ToolPanel(m: m, tab: tab, cutItem: $cutItem, bgItem: $bgItem)
                .frame(height: 186)
                .background(TH.s1.opacity(0.96))
            tabBar
        }
        .background(Backdrop())
        .overlay { if loading { LoadingVeil(text: "نجهّز الصورة…") } }
        .sheet(isPresented: $showExport) {
            ExportView(project: m.project, selectedID: m.selected)
                .environmentObject(bank)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $cutAdd) { a in
            CutView(launch: a.launch, title: "أضف قصّة للتصميم") { r in
                if let r { m.addCut(r.image, hOverW: r.hOverW) }
                cutAdd = nil
            }
            .environmentObject(bank)
            .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .onChange(of: cutItem) { v in
            guard let v else { return }
            loading = true
            Task {
                let d = try? await v.loadTransferable(type: Data.self)
                loading = false
                cutItem = nil
                if let d, let img = UIImage(data: d) { cutAdd = CutAdd(launch: CutLaunch(image: img, demo: false)) } else { HX.bad() }
            }
        }
        .onChange(of: bgItem) { v in
            guard let v else { return }
            loading = true
            Task {
                let d = try? await v.loadTransferable(type: Data.self)
                loading = false
                bgItem = nil
                if let d, let img = UIImage(data: d) {
                    let id = bank.putJPEG(Engine.normalized(img, maxSide: 2400))
                    m.setBkg(.photo(id))
                } else { HX.bad() }
            }
        }
        .onAppear {
            if Shot.name == "export" { Task { try? await Task.sleep(nanoseconds: 900_000_000); showExport = true } }
            if Shot.name == "sticker" { tab = .fx }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            RoundBtn(icon: "xmark") { m.close(); onClose() }
            RoundBtn(icon: "arrow.uturn.backward", enabled: m.hist.canUndo) { m.undo() }
            RoundBtn(icon: "arrow.uturn.forward", enabled: m.hist.canRedo) { m.redo() }
            Spacer()
            VStack(spacing: 1) {
                Text(m.project.name).font(rnd(15, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                Text("\(m.project.aspect.title) · \(m.project.layers.count) طبقات").font(rnd(11)).foregroundStyle(TH.tx3)
            }
            Spacer()
            Button { HX.thud(); m.end(); showExport = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .black))
                    Text("صدّر").font(rnd(15, .black))
                }
                .foregroundStyle(Color.white).padding(.horizontal, 16).frame(height: 40)
                .background(TH.grad, in: Capsule())
                .shadow(color: TH.magenta.opacity(0.4), radius: 10, y: 4)
            }.buttonStyle(Press())
        }
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 4)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tool.allCases) { t in
                Button {
                    HX.tap()
                    m.end()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { tab = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon).font(.system(size: 17, weight: .bold))
                        Text(t.title).font(rnd(10.5, .bold))
                    }
                    .foregroundStyle(tab == t ? TH.coral : TH.tx3)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .overlay(alignment: .top) {
                        Capsule().fill(TH.coral).frame(width: tab == t ? 24 : 0, height: 3).opacity(tab == t ? 1 : 0)
                    }
                }.buttonStyle(Press())
            }
        }
        .background(TH.bg)
    }
}

struct LoadingVeil: View {
    let text: String
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(Color.white).scaleEffect(1.3)
                Text(text).font(rnd(14, .bold)).foregroundStyle(Color.white)
            }.padding(24).card(TH.s1, 20)
        }
    }
}

/// اللوحة + الإيماءات: سحب للتحريك، قرص للتكبير، تدوير بإصبعين، نقرة للاختيار
struct StageArea: View {
    @ObservedObject var m: StudioModel
    let tick: Int
    @State private var dragBase: XForm?
    @State private var pinchBase: XForm?
    @State private var pinchText: Double?

    var body: some View {
        GeometryReader { geo in
            let box = TRect(14, 12, Double(geo.size.width) - 28, Double(geo.size.height) - 24)
            let r = Fit.fit(TSize(m.project.aspect.ratio, 1), in: box)
            let size = CGSize(width: max(1, r.w), height: max(1, r.h))
            StageView(project: m.project, size: size, selected: m.selected, export: false, tick: tick, guideX: m.guideX, guideY: m.guideY)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.black.opacity(0.55), radius: 22, y: 10)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { p in tap(p, size) }
                .gesture(drag(size))
                .simultaneousGesture(pinch())
                .position(x: CGFloat(r.midX), y: CGFloat(r.midY))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: m.project.aspect)
        }
    }

    private func tsize(_ s: CGSize) -> TSize { TSize(Double(s.width), Double(s.height)) }

    private func tap(_ p: CGPoint, _ size: CGSize) {
        let hit = m.project.hitTest(TP(Double(p.x), Double(p.y)), canvas: tsize(size))
        withAnimation(.easeOut(duration: 0.15)) { m.selected = hit }
        if hit != nil { HX.tap() }
    }

    private func drag(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in
                if dragBase == nil {
                    let p = TP(Double(v.startLocation.x), Double(v.startLocation.y))
                    if let hit = m.project.hitTest(p, canvas: tsize(size)) { m.selected = hit }
                    guard let s = m.sel, !s.locked else { return }
                    dragBase = s.xf
                }
                guard let base = dragBase else { return }
                m.begin()
                let moved = base.moved(Double(v.translation.width / size.width), Double(v.translation.height / size.height))
                let sn = moved.snapped()
                if sn.1 != m.guideX || sn.2 != m.guideY { if sn.1 || sn.2 { HX.tap() } }
                m.liveSel { $0.xf.cx = sn.0.cx; $0.xf.cy = sn.0.cy }
                m.guideX = sn.1
                m.guideY = sn.2
            }
            .onEnded { _ in
                if dragBase != nil { m.end() }
                dragBase = nil
            }
    }

    private func pinch() -> some Gesture {
        MagnificationGesture().simultaneously(with: RotationGesture())
            .onChanged { v in
                guard let s = m.sel, !s.locked else { return }
                if pinchBase == nil { pinchBase = s.xf; pinchText = s.textSpec?.size }
                guard let base = pinchBase else { return }
                m.begin()
                var t = base
                if let k = v.first { t = t.scaled(Double(k)) }
                if let a = v.second { t = t.rotated(a.radians) }
                let fin = t
                let ts: Double? = pinchText.flatMap { base in v.first.map { Fit.clamp(base * Double($0), 0.02, 0.6) } }
                m.liveSel { l in
                    l.xf.scale = fin.scale
                    l.xf.rot = fin.rot
                    if let ts { l.setText { $0.size = ts } } else { l.refitText() }
                }
            }
            .onEnded { _ in
                if pinchBase != nil { m.end() }
                pinchBase = nil
                pinchText = nil
            }
    }
}
