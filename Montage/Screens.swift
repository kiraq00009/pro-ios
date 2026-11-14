import SwiftUI
import AVKit
import PhotosUI

struct HomeView: View {
    @EnvironmentObject var studio: Studio
    @State private var pick: PhotosPickerItem?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            ZStack {
                MT.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("مونتاج").font(rnd(32, .heavy)).foregroundStyle(.white)
                            Text("ترجمة محروقة على أيّ فيديو — بثواني ومن موبايلك").font(rnd(14, .medium)).foregroundStyle(MT.tx3)
                        }.padding(.top, 8)
                        hero
                        if !studio.projects.isEmpty {
                            Text("شغلك").font(rnd(16, .heavy)).foregroundStyle(MT.tx2)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(studio.projects) { p in
                                    NavigationLink(value: p.id) { ProjectCard(p: p) }.buttonStyle(Press())
                                        .contextMenu { Button(role: .destructive) { studio.remove(p.id) } label: { Label("احذف", systemImage: "trash") } }
                                }
                            }
                        }
                        features
                    }
                    .padding(.horizontal, 16).padding(.bottom, 30)
                }
                if loading { Color.black.opacity(0.5).ignoresSafeArea(); ProgressView("أجهّز الفيديو…").tint(.white).foregroundStyle(.white) }
            }
            .navigationDestination(for: UUID.self) { EditorView(id: $0) }
            .navigationDestination(isPresented: Binding(get: { studio.open != nil }, set: { if !$0 { studio.open = nil } })) {
                if let id = studio.open { EditorView(id: id) }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: pick) { item in
            guard let item else { return }
            loading = true
            Task {
                if let m = try? await item.loadTransferable(type: Movie.self) { studio.add(m) }
                loading = false; pick = nil
            }
        }
    }

    private var hero: some View {
        PhotosPicker(selection: $pick, matching: .videos) {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(MT.hot).frame(width: 74, height: 74).shadow(color: MT.hot.opacity(0.6), radius: 24)
                    Image(systemName: "plus").font(.system(size: 32, weight: .heavy)).foregroundStyle(.white)
                }
                Text("اختار فيديو").font(rnd(20, .heavy)).foregroundStyle(.white)
                Text("إنكليزي، فارسي، تركي… يطلع مترجم عربي ومحروق بالستايل اللي تحبّه").font(rnd(13)).foregroundStyle(MT.tx2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 30).padding(.horizontal, 20)
            .background(LinearGradient(colors: [MT.hot.opacity(0.22), MT.cyan.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(MT.hot.opacity(0.35)))
        }.buttonStyle(Press())
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("waveform", "يسمع الفيديو ويطلّع كلّ كلمة بتوقيتها")
            row("character.bubble", "يترجم للعربي أو أيّ لغة، وتگدر تعدّل أيّ سطر")
            row("sparkles", "٥ ستايلات: تيك توك (الكلمة تنوّر)، صندوق، نيون، سينما، كلاسيك")
            row("lock.shield", "الفيديو ما يطلع من موبايلك — بس الصوت ينرسل للتفريغ")
        }
        .padding(16).card(MT.s1, 20)
    }
    private func row(_ i: String, _ t: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: i).font(rnd(15, .bold)).foregroundStyle(MT.cyan).frame(width: 26)
            Text(t).font(rnd(14)).foregroundStyle(MT.tx2)
        }
    }
}

struct ProjectCard: View {
    @EnvironmentObject var studio: Studio
    let p: Project
    @State private var thumb: UIImage?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let thumb { Image(uiImage: thumb).resizable().scaledToFill() }
                else { LinearGradient(colors: [MT.s3, MT.s2], startPoint: .top, endPoint: .bottom) }
                if p.phase == .listening || p.phase == .translating { Color.black.opacity(0.45); ProgressView().tint(.white) }
                if let c = p.cues.first, p.phase == .ready {
                    Text(c.shown(p.style.mode)).font(rnd(13, .heavy)).foregroundStyle(MT.hex(p.style.accent))
                        .shadow(color: .black, radius: 2).multilineTextAlignment(.center).padding(6)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack {
                Text(statusText).font(rnd(12, .bold)).foregroundStyle(p.phase == .failed ? MT.hot : MT.tx2)
                Spacer()
                Text(String(format: "%d:%02d", Int(p.duration) / 60, Int(p.duration) % 60)).font(rnd(11, .semibold)).foregroundStyle(MT.tx3)
            }
        }
        .task { if !Shot.on { thumb = await Thumbs.make(studio.url(p)) } }
    }
    var statusText: String {
        switch p.phase {
        case .new, .listening: return "يسمع…"
        case .translating: return "يترجم…"
        case .ready: return "\(p.lang?.flag ?? "") \(p.cues.count) سطر"
        case .failed: return "ما نجح"
        }
    }
}

enum Thumbs {
    static func make(_ u: URL, at t: Double = 0.5) async -> UIImage? {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: u))
        g.appliesPreferredTrackTransform = true
        g.maximumSize = CGSize(width: 400, height: 400)
        return await withCheckedContinuation { c in
            g.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: t, preferredTimescale: 600))]) { _, img, _, _, _ in
                c.resume(returning: img.map { UIImage(cgImage: $0) })
            }
        }
    }
}

// MARK: - المحرّر

struct EditorView: View {
    @EnvironmentObject var studio: Studio
    let id: UUID
    @State private var player = AVPlayer()
    @State private var time: Double = 0
    @State private var tab = Shot.name == "lines" ? 1 : 0
    @State private var exporting = false
    @State private var progress: Double = Shot.name == "export" ? 0.62 : 0
    @State private var done: URL?
    @State private var saved = false
    @State private var err: String?
    @State private var observer: Any?

    var project: Project? { studio.projects.first { $0.id == id } }

    var body: some View {
        ZStack {
            MT.bg.ignoresSafeArea()
            if let p = project {
                VStack(spacing: 0) {
                    preview(p)
                    if p.phase == .ready {
                        Picker("", selection: $tab) {
                            Text("الستايل").tag(0)
                            Text("الأسطر").tag(1)
                        }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 10)
                        ScrollView {
                            if tab == 0 { StylePanel(id: id) } else { LinesPanel(id: id, time: time) { player.seek(to: CMTime(seconds: $0, preferredTimescale: 600)); player.play() } }
                        }
                        exportBar(p)
                    } else { status(p) }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let p = project, p.phase == .ready {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: Subs.srt(p.cues, mode: p.style.mode)) { Label("SRT", systemImage: "captions.bubble") }
                }
            }
        }
        .onAppear(perform: setup)
        .onDisappear { player.pause(); if let o = observer { player.removeTimeObserver(o) } }
        .sheet(isPresented: Binding(get: { exporting || done != nil || Shot.name == "export" }, set: { if !$0 { done = nil } })) {
            exportSheet.presentationDetents([.medium]).interactiveDismissDisabled(exporting)
        }
    }

    private func setup() {
        guard let p = project, !Shot.on else { time = 1.2; return }
        player.replaceCurrentItem(with: AVPlayerItem(url: studio.url(p)))
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { t in
            time = CMTimeGetSeconds(t)
        }
    }

    private func preview(_ p: Project) -> some View {
        GeometryReader { g in
            ZStack {
                Color.black
                if Shot.on {
                    LinearGradient(colors: [Color(red: 0.25, green: 0.18, blue: 0.3), Color(red: 0.08, green: 0.1, blue: 0.16)], startPoint: .top, endPoint: .bottom)
                    Image(systemName: "figure.wave").font(.system(size: 120)).foregroundStyle(.white.opacity(0.18))
                } else {
                    VideoPlayer(player: player)
                }
                if p.phase == .ready { SubtitleOverlay(cues: p.cues, style: p.style, time: time, width: g.size.width).allowsHitTesting(false) }
            }
        }
        .aspectRatio(p.portrait ? 9 / 16 : 16 / 9, contentMode: .fit)
        .frame(maxHeight: p.portrait ? 380 : 230)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16).padding(.top, 6)
    }

    private func status(_ p: Project) -> some View {
        VStack(spacing: 14) {
            Spacer()
            if p.phase == .failed {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(MT.hot)
                Text(p.error ?? "").font(rnd(15)).foregroundStyle(MT.tx2).multilineTextAlignment(.center).padding(.horizontal, 30)
                Button { studio.process(p.id) } label: {
                    Text("أعد المحاولة").font(rnd(16, .heavy)).foregroundStyle(.white).padding(.horizontal, 24).padding(.vertical, 11).background(MT.hot, in: Capsule())
                }
            } else {
                ProgressView().tint(MT.cyan).scaleEffect(1.4)
                Text(p.phase == .translating ? "أترجم الأسطر…" : "أسمع الفيديو وأكتب كلّ كلمة…").font(rnd(17, .bold)).foregroundStyle(.white)
                Text("الفيديو الطويل ياخذ دقيقة أو دقيقتين").font(rnd(13)).foregroundStyle(MT.tx3)
            }
            Spacer()
        }
    }

    private func exportBar(_ p: Project) -> some View {
        Button { runExport(p) } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.fill")
                Text("احرق الترجمة واحفظ الفيديو").font(rnd(16, .heavy))
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(MT.hot, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: MT.hot.opacity(0.4), radius: 14)
        }
        .buttonStyle(Press()).padding(.horizontal, 16).padding(.bottom, 10).disabled(exporting)
    }

    private var exportSheet: some View {
        VStack(spacing: 18) {
            if let u = done {
                Image(systemName: saved ? "checkmark.circle.fill" : "film.stack").font(.system(size: 54)).foregroundStyle(saved ? MT.cyan : MT.hot)
                Text(saved ? "انحفظ بالألبوم ✓" : "الفيديو جاهز").font(rnd(20, .heavy)).foregroundStyle(.white)
                HStack(spacing: 12) {
                    if !saved {
                        Button { Task { saved = await Studio.saveToPhotos(u); if !saved { err = "اسمح لمونتاج يحفظ بالصور من الإعدادات" } } } label: {
                            Label("احفظ بالصور", systemImage: "photo.on.rectangle").font(rnd(15, .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 18).padding(.vertical, 12).background(MT.hot, in: Capsule())
                        }
                    }
                    ShareLink(item: u) {
                        Label("شارك", systemImage: "square.and.arrow.up").font(rnd(15, .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 12).background(MT.s3, in: Capsule())
                    }
                }
                if let err { Text(err).font(rnd(13)).foregroundStyle(MT.hot) }
            } else {
                Text("أحرق الترجمة على الفيديو…").font(rnd(18, .heavy)).foregroundStyle(.white)
                ProgressView(value: progress).tint(MT.hot).scaleEffect(x: 1, y: 2)
                Text("\(Int(progress * 100))٪ — خلّي التطبيق مفتوح").font(rnd(13, .semibold)).foregroundStyle(MT.tx3)
                if let err { Text(err).font(rnd(13)).foregroundStyle(MT.hot) }
            }
        }
        .padding(26).frame(maxWidth: .infinity, maxHeight: .infinity).background(MT.s1)
    }

    private func runExport(_ p: Project) {
        player.pause()
        exporting = true; progress = 0; saved = false; err = nil
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            do {
                let u = try await Burner.export(video: studio.url(p), cues: p.cues, style: p.style) { v in
                    Task { @MainActor in progress = v }
                }
                done = u
                studio.update(p.id) { $0.exported = u.lastPathComponent }
                studio.rememberStyle(p.style)
                saved = await Studio.saveToPhotos(u)
                Haptic.ok()
            } catch { err = error.localizedDescription; Haptic.bad() }
            exporting = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

/// معاينة الترجمة فوق الفيديو (نفس منطق الحرق)
struct SubtitleOverlay: View {
    let cues: [Cue]
    let style: Style
    let time: Double
    let width: CGFloat

    var body: some View {
        GeometryReader { g in
            let fs = CGFloat(style.fontSize(videoWidth: Double(g.size.width)))
            if let c = Subs.active(cues, at: time) {
                VStack(spacing: fs * 0.25) {
                    if style.look == .tiktok { tiktok(c, fs) } else { line(Subs.wrap(c.shown(style.mode), max: style.look == .cinema ? 38 : 28).joined(separator: "\n"), fs, highlight: nil) }
                    if style.mode == .both && !c.tr.isEmpty {
                        line(c.text, fs * (style.look == .tiktok ? 0.48 : 0.62), highlight: nil, dim: true)
                    }
                }
                .frame(width: g.size.width * 0.9)
                .position(x: g.size.width / 2, y: g.size.height * CGFloat(style.place.y))
                .id(c.id)
                .transition(.opacity)
            }
            if !style.watermark.isEmpty {
                Text(style.watermark).font(.system(size: fs * 0.42, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                    .position(x: g.size.width * 0.82, y: g.size.height * 0.06)
            }
        }
    }

    @ViewBuilder func tiktok(_ c: Cue, _ fs: CGFloat) -> some View {
        let chunks = Subs.chunks(c, per: style.wordsPerChunk, translated: style.mode != .original)
        if let ch = chunks.last(where: { $0.s <= time }) ?? chunks.first {
            let cur = ch.starts.lastIndex(where: { $0 <= time }) ?? 0
            HStack(spacing: fs * 0.22) {
                ForEach(Array(ch.words.enumerated()), id: \.offset) { i, w in
                    styled(Text(w), fs, color: i == cur ? MT.hex(style.accent) : MT.hex(style.color))
                }
            }
            .environment(\.layoutDirection, isRTL(ch.words.joined()) ? .rightToLeft : .leftToRight)
            .id("\(ch.s)")
            .transition(.scale(scale: 0.75).combined(with: .opacity))
        }
    }

    func isRTL(_ s: String) -> Bool { s.unicodeScalars.contains { (0x0590...0x08FF).contains($0.value) } }

    func line(_ t: String, _ fs: CGFloat, highlight: Int?, dim: Bool = false) -> some View {
        styled(Text(t), fs, color: MT.hex(style.color).opacity(dim ? 0.8 : 1))
            .multilineTextAlignment(.center)
            .padding(.horizontal, style.look == .box ? fs * 0.5 : 0).padding(.vertical, style.look == .box ? fs * 0.2 : 0)
            .background(style.look == .box ? Color.black.opacity(0.62) : .clear, in: RoundedRectangle(cornerRadius: fs * 0.3))
    }

    func styled(_ t: Text, _ fs: CGFloat, color: Color) -> some View {
        let w: Font.Weight = style.look == .cinema ? .semibold : (style.look == .classic ? .bold : .heavy)
        let stroke = style.look == .tiktok ? fs * 0.06 : (style.look == .classic ? fs * 0.035 : 0)
        return t.font(.system(size: fs, weight: w))
            .foregroundStyle(style.look == .neon ? .white : color)
            .shadow(color: .black.opacity(stroke > 0 ? 1 : 0), radius: 0, x: stroke, y: stroke)
            .shadow(color: .black.opacity(stroke > 0 ? 1 : 0), radius: 0, x: -stroke, y: -stroke)
            .shadow(color: .black.opacity(stroke > 0 ? 1 : 0), radius: 0, x: stroke, y: -stroke)
            .shadow(color: .black.opacity(stroke > 0 ? 1 : 0), radius: 0, x: -stroke, y: stroke)
            .shadow(color: style.look == .neon ? MT.hex(style.accent) : (style.look == .cinema ? .black.opacity(0.9) : .clear), radius: style.look == .neon ? fs * 0.35 : fs * 0.15)
    }
}

struct StylePanel: View {
    @EnvironmentObject var studio: Studio
    let id: UUID
    var p: Project? { studio.projects.first { $0.id == id } }

    func set(_ f: @escaping (inout Style) -> Void) { studio.update(id) { f(&$0.style) }; Haptic.tap() }

    var body: some View {
        if let p {
            VStack(alignment: .leading, spacing: 16) {
                section("الستايل") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Look.allCases) { l in
                                Button { set { $0.look = l } } label: {
                                    Text(l.name).font(rnd(14, .heavy)).foregroundStyle(p.style.look == l ? .black : .white)
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(p.style.look == l ? MT.yellow : MT.s2, in: Capsule())
                                }.buttonStyle(Press())
                            }
                        }
                    }
                }
                section("شنو يطلع") {
                    Picker("", selection: Binding(get: { p.style.mode }, set: { v in set { $0.mode = v } })) {
                        ForEach(TextMode.allCases) { Text($0.name).tag($0) }
                    }.pickerStyle(.segmented)
                }
                section("المكان") {
                    Picker("", selection: Binding(get: { p.style.place }, set: { v in set { $0.place = v } })) {
                        ForEach(Place.allCases) { Text($0.name).tag($0) }
                    }.pickerStyle(.segmented)
                }
                section("الحجم") {
                    Slider(value: Binding(get: { p.style.size }, set: { v in studio.update(id) { $0.style.size = v } }), in: 0.6...1.6).tint(MT.hot)
                }
                section(p.style.look == .tiktok ? "لون الكلمة الحاليّة" : "اللون") {
                    HStack(spacing: 12) {
                        ForEach(Style.palette, id: \.self) { c in
                            let on = p.style.look == .tiktok || p.style.look == .neon ? p.style.accent == c : p.style.color == c
                            Button { set { if $0.look == .tiktok || $0.look == .neon { $0.accent = c } else { $0.color = c } } } label: {
                                Circle().fill(MT.hex(c)).frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(.white, lineWidth: on ? 3 : 0).padding(-4))
                            }
                        }
                    }
                }
                if p.style.look == .tiktok {
                    section("كلمات بالمرّة") {
                        Stepper("\(p.style.wordsPerChunk) كلمات", value: Binding(get: { p.style.wordsPerChunk }, set: { v in set { $0.wordsPerChunk = v } }), in: 1...5)
                            .font(rnd(15, .semibold))
                    }
                }
                section("لغة الترجمة") {
                    HStack {
                        ForEach([Lang.ar, .en, .fa, .tr, .ku]) { l in
                            Button { studio.retranslate(id, to: l) } label: {
                                Text(l.flag).font(rnd(24)).padding(6)
                                    .background(p.target == l ? MT.cyan.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        Spacer()
                    }
                }
                section("علامتك (اختياري)") {
                    TextField("@حسابك", text: Binding(get: { p.style.watermark }, set: { v in studio.update(id) { $0.style.watermark = String(v.prefix(30)) } }))
                        .font(rnd(15)).padding(10).card(MT.s2, 12)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }

    func section<C: View>(_ t: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t).font(rnd(13, .heavy)).foregroundStyle(MT.tx3)
            c()
        }
    }
}

struct LinesPanel: View {
    @EnvironmentObject var studio: Studio
    let id: UUID
    let time: Double
    var seek: (Double) -> Void
    var p: Project? { studio.projects.first { $0.id == id } }

    var body: some View {
        if let p {
            VStack(spacing: 10) {
                HStack {
                    Text("اضغط الوقت حتى تروح له، وعدّل أيّ سطر").font(rnd(12)).foregroundStyle(MT.tx3)
                    Spacer()
                    Button { studio.update(id) { $0.cues = Subs.shift($0.cues, by: -0.2) } } label: { Text("−٠٫٢ث").font(rnd(12, .bold)) }
                    Button { studio.update(id) { $0.cues = Subs.shift($0.cues, by: 0.2) } } label: { Text("+٠٫٢ث").font(rnd(12, .bold)) }
                }
                ForEach(p.cues) { c in
                    let active = time >= c.s && time <= c.e
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button { seek(c.s) } label: {
                                Text(String(format: "%d:%04.1f", Int(c.s) / 60, c.s.truncatingRemainder(dividingBy: 60))).font(rnd(12, .heavy)).foregroundStyle(active ? MT.yellow : MT.cyan)
                            }
                            Spacer()
                            Button(role: .destructive) { studio.update(id) { $0.cues.removeAll { $0.id == c.id } } } label: { Image(systemName: "trash").font(rnd(12)) }
                        }
                        if !c.tr.isEmpty {
                            TextField("", text: binding(c.id, \.tr), axis: .vertical).font(rnd(16, .bold)).foregroundStyle(.white)
                        }
                        TextField("", text: binding(c.id, \.text), axis: .vertical).font(rnd(c.tr.isEmpty ? 16 : 13)).foregroundStyle(c.tr.isEmpty ? .white : MT.tx3)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .padding(12).background(active ? MT.yellow.opacity(0.08) : MT.s1, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }

    func binding(_ cid: UUID, _ kp: WritableKeyPath<Cue, String>) -> Binding<String> {
        Binding(get: { p?.cues.first { $0.id == cid }?[keyPath: kp] ?? "" },
                set: { v in studio.update(id) { if let i = $0.cues.firstIndex(where: { $0.id == cid }) { $0.cues[i][keyPath: kp] = v } } })
    }
}
