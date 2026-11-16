import SwiftUI
import PhotosUI

struct HomeView: View {
    @EnvironmentObject var bank: Bank
    @AppStorage("th_seen") private var seen = false
    @State private var projects: [Project] = []
    @State private var flow: FlowLaunch?
    @State private var pick: PhotosPickerItem?
    @State private var loading = false
    @State private var settings = false
    @State private var onboard = false
    @State private var renaming: Project?
    @State private var renameText = ""
    @State private var deleting: Project?
    @State private var stats = Stats()
    @State private var glow = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                heroCard
                inspiration
                statsRow
                gallery
                Text("كلّ شي يصير على جهازك · بدون إنترنت وبدون رفع صور").font(rnd(11.5)).foregroundStyle(TH.tx3)
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }.padding(18)
        }
        .background(Backdrop())
        .overlay { if loading { LoadingVeil(text: "نفتح الصورة…") } }
        .fullScreenCover(item: $flow, onDismiss: reload) { l in
            FlowView(launch: l) { flow = nil }
                .environmentObject(bank)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $settings, onDismiss: reload) {
            SettingsView(onReplayIntro: { settings = false; Task { @MainActor in try? await Task.sleep(nanoseconds: 600_000_000); onboard = true } })
                .environmentObject(bank)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $onboard) {
            OnboardView { seen = true; onboard = false }
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .alert("اسم التصميم", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("الاسم", text: $renameText)
            Button("حفظ") {
                if let p = renaming { try? bank.store.rename(p.id, to: renameText, now: Date().timeIntervalSince1970) }
                renaming = nil
                reload()
            }
            Button("إلغاء", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("نحذف «\(deleting?.name ?? "")»؟", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("احذف نهائيًّا", role: .destructive) {
                if let p = deleting {
                    bank.store.delete(p.id)
                    bank.forgetThumb(p.id)
                    bank.store.cleanOrphans()
                    HX.thud()
                }
                deleting = nil
                reload()
            }
            Button("إلغاء", role: .cancel) { deleting = nil }
        }
        .onChange(of: pick) { v in
            guard let v else { return }
            loading = true
            Task {
                let d = try? await v.loadTransferable(type: Data.self)
                loading = false
                pick = nil
                if let d, let img = UIImage(data: d) {
                    flow = FlowLaunch(start: .cut(CutLaunch(image: img, demo: false)))
                } else { HX.bad() }
            }
        }
        .onAppear { start() }
    }

    private func start() {
        if Shot.on {
            Demo.install(bank)
            projects = Demo.all
            stats = Stats(cuts: 37, exports: 52, stickers: 18, bestLayers: 6)
            switch Shot.name {
            case "cut": flow = FlowLaunch(start: .cut(CutLaunch(image: nil, demo: true)))
            case "templates": flow = FlowLaunch(start: .templates(CutResult(image: Demo.figureID, hOverW: Demo.figureRatio, source: Demo.sceneID)))
            case "studio": flow = FlowLaunch(start: .studio(Demo.poster))
            case "sticker": flow = FlowLaunch(start: .studio(Demo.stickers))
            case "export": flow = FlowLaunch(start: .studio(Demo.product))
            case "onboard": onboard = true
            default: break
            }
            return
        }
        reload()
        if !seen { onboard = true }
    }

    private func reload() {
        if Shot.on { return }
        projects = bank.store.all()
        stats = StatBox.load()
    }

    // MARK: الأقسام

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("ظِلّ").font(rnd(44, .black)).foregroundStyle(TH.grad)
                    Image(systemName: "sparkles").font(.system(size: 20, weight: .bold)).foregroundStyle(TH.gold)
                        .scaleEffect(glow ? 1.15 : 0.9).opacity(glow ? 1 : 0.6)
                }
                Text("قصّ أيّ شي من صورك وسوّي منه تحفة").font(rnd(13.5)).foregroundStyle(TH.tx3)
            }
            Spacer()
            RoundBtn(icon: "gearshape.fill") { settings = true }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true } }
    }

    private var heroCard: some View {
        PhotosPicker(selection: $pick, matching: .images) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(TH.grad)
                HeroArt().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing).padding(.trailing, 6)
                VStack(alignment: .leading, spacing: 6) {
                    Text("قصّة جديدة").font(rnd(27, .black)).foregroundStyle(Color.white)
                    Text("اختار صورة والذكاء يفصل الموضوع").font(rnd(13.5, .semibold)).foregroundStyle(Color.white.opacity(0.85))
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 13, weight: .black))
                        Text("من صورك").font(rnd(14, .black))
                    }
                    .foregroundStyle(TH.magenta).padding(.horizontal, 14).frame(height: 36)
                    .background(Color.white, in: Capsule()).padding(.top, 6)
                }.padding(20)
            }
            .frame(height: 190)
            .shadow(color: TH.magenta.opacity(0.4), radius: 22, y: 10)
        }.buttonStyle(Press())
    }

    private var inspiration: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("شنو تگدر تسوّي").font(rnd(18, .black)).foregroundStyle(Color.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Templates.all) { t in
                        PhotosPicker(selection: $pick, matching: .images) {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: t.symbol).font(.system(size: 20, weight: .bold)).foregroundStyle(TH.grad)
                                    .frame(width: 44, height: 44).background(TH.s2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                Text(t.title).font(rnd(14, .heavy)).foregroundStyle(Color.white)
                                Text(t.note).font(rnd(11)).foregroundStyle(TH.tx3).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            .frame(width: 128, alignment: .leading).padding(12).card(TH.s1, 18)
                        }.buttonStyle(Press())
                    }
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat("\(projects.count)", "تصميم", "square.stack.fill", TH.violet)
            stat("\(stats.cuts)", "قصّة", "scissors", TH.coral)
            stat("\(stats.exports)", "تصدير", "square.and.arrow.up.fill", TH.mint)
        }
    }

    private func stat(_ v: String, _ t: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(22, .black)).foregroundStyle(Color.white)
            Text(t).font(rnd(11.5, .semibold)).foregroundStyle(TH.tx3)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).card(TH.s1, 18)
    }

    @ViewBuilder private var gallery: some View {
        HStack {
            Text("تصاميمي").font(rnd(18, .black)).foregroundStyle(Color.white)
            Spacer()
            if !projects.isEmpty { Text("\(projects.count)").font(rnd(13, .heavy)).foregroundStyle(TH.tx3) }
        }
        if projects.isEmpty {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(TH.s2).frame(width: 88, height: 88)
                    Image(systemName: "person.crop.square.filled.and.at.rectangle").font(.system(size: 34, weight: .bold)).foregroundStyle(TH.grad)
                }
                Text("لسّه ما سوّيت تصميم").font(rnd(16, .heavy)).foregroundStyle(Color.white)
                Text("ابدي بقصّة جديدة — تصاميمك تنحفظ هنا لحالها وتگدر ترجعلها وتعدّلها").font(rnd(13)).foregroundStyle(TH.tx3).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 26).card(TH.s1, 22)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(projects) { p in projectCell(p) }
            }
        }
    }

    private func projectCell(_ p: Project) -> some View {
        Button { HX.tap(); flow = FlowLaunch(start: .studio(p)) } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TH.s2)
                    if !Shot.on, let t = bank.thumb(p.id) {
                        Image(uiImage: t).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)).padding(8)
                    } else {
                        MiniStage(project: p, box: CGSize(width: 140, height: 150), tick: bank.tick)
                    }
                }.frame(height: 170)
                Text(p.name).font(rnd(14, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                HStack(spacing: 5) {
                    Text(p.aspect.title).font(rnd(11, .bold)).foregroundStyle(TH.coral)
                    Text("·").foregroundStyle(TH.tx3)
                    Text(agoText(Date(timeIntervalSince1970: p.modified))).font(rnd(11)).foregroundStyle(TH.tx3)
                }
            }
            .padding(10).card(TH.s1, 20)
        }
        .buttonStyle(Press())
        .contextMenu {
            Button { flow = FlowLaunch(start: .studio(p)) } label: { Label("افتح", systemImage: "pencil") }
            Button {
                if let c = try? bank.store.duplicate(p, newID: "P" + String(UUID().uuidString.prefix(10)), now: Date().timeIntervalSince1970) {
                    if let t = bank.thumb(p.id), let d = t.jpegData(compressionQuality: 0.8) { try? d.write(to: bank.store.thumbURL(c.id)) }
                }
                HX.ok(); reload()
            } label: { Label("كرّر", systemImage: "plus.square.on.square") }
            Button { renameText = p.name; renaming = p } label: { Label("غيّر الاسم", systemImage: "character.cursor.ibeam") }
            Button(role: .destructive) { deleting = p } label: { Label("احذف", systemImage: "trash") }
        }
    }
}

/// رسمة البطاقة الرئيسيّة: موضوع مقصوص يطلع من إطار صورة
struct HeroArt: View {
    @State private var float = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.18))
                .frame(width: 104, height: 128).rotationEffect(.degrees(-8)).offset(x: -14, y: 10)
            RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .frame(width: 104, height: 128).rotationEffect(.degrees(6))
            Image(systemName: "figure.wave").font(.system(size: 78, weight: .black)).foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.25), radius: 10, y: 8)
                .offset(y: float ? -8 : 2)
            Image(systemName: "scissors").font(.system(size: 20, weight: .black)).foregroundStyle(Color.white)
                .padding(9).background(TH.magenta, in: Circle()).offset(x: 50, y: 58)
        }
        .frame(width: 150, height: 170)
        .onAppear { withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { float = true } }
    }
}

// MARK: - الإعدادات

struct SettingsView: View {
    let onReplayIntro: () -> Void
    @EnvironmentObject var bank: Bank
    @Environment(\.dismiss) private var dismiss
    @AppStorage("th_hx") private var haptics = true
    @AppStorage("th_res") private var res = 1080
    @State private var confirmWipe = false
    @State private var cleaned: Int?
    @State private var stats = Stats()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("الإعدادات").font(rnd(26, .black)).foregroundStyle(Color.white)
                    Spacer()
                    RoundBtn(icon: "xmark") { dismiss() }
                }.padding(.top, 10)

                section("التصدير") {
                    HStack {
                        Text("الدقّة الافتراضيّة").font(rnd(14.5, .bold)).foregroundStyle(Color.white)
                        Spacer()
                        Picker("", selection: $res) {
                            Text("1080").tag(1080)
                            Text("1440").tag(1440)
                            Text("4K").tag(2160)
                        }.pickerStyle(.segmented).frame(width: 190)
                    }
                }
                section("الإحساس") {
                    Toggle(isOn: $haptics) { Text("اهتزاز خفيف مع اللمس").font(rnd(14.5, .bold)).foregroundStyle(Color.white) }.tint(TH.coral)
                }
                section("إحصاءاتك") {
                    row("قصّات سوّيتها", "\(stats.cuts)")
                    row("مرّات التصدير", "\(stats.exports)")
                    row("ملصقات طلّعتها", "\(stats.stickers)")
                    row("أكثر طبقات بتصميم", "\(stats.bestLayers)")
                }
                section("التخزين") {
                    Button {
                        let n = bank.store.cleanOrphans()
                        bank.clearCaches()
                        cleaned = n
                        HX.ok()
                    } label: {
                        rowLabel("نظّف الصور غير المستعملة", cleaned.map { "انمسحت \($0)" } ?? "", "sparkles")
                    }
                    Button { confirmWipe = true } label: { rowLabel("احذف كلّ التصاميم", "", "trash", tint: TH.coral) }
                }
                section("عن ظِلّ") {
                    Button { onReplayIntro() } label: { rowLabel("شوف الشرح مرّة ثانية", "", "play.circle") }
                    Text("ظِلّ يقصّ المواضيع بذكاء الجهاز نفسه (Vision) — صورك ما تطلع من تلفونك أبدًا.")
                        .font(rnd(12.5)).foregroundStyle(TH.tx3)
                }
            }.padding(18)
        }
        .background(Backdrop())
        .onAppear { stats = StatBox.load() }
        .confirmationDialog("كلّ التصاميم والقصّات راح تنمسح ومستحيل ترجع", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("امسح كلّشي", role: .destructive) { bank.store.deleteAll(); bank.clearCaches(); HX.thud(); dismiss() }
            Button("إلغاء", role: .cancel) {}
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(rnd(12.5, .heavy)).foregroundStyle(TH.tx3)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(TH.s1, 20)
    }
    private func row(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t).font(rnd(14.5, .semibold)).foregroundStyle(TH.tx2)
            Spacer()
            Text(v).font(rnd(16, .black)).foregroundStyle(Color.white)
        }
    }
    private func rowLabel(_ t: String, _ v: String, _ icon: String, tint: Color = .white) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(tint == .white ? TH.coral : tint).frame(width: 22)
            Text(t).font(rnd(14.5, .bold)).foregroundStyle(tint)
            Spacer()
            Text(v).font(rnd(12.5)).foregroundStyle(TH.mint)
        }
    }
}
