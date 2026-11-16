import SwiftUI
import PhotosUI

struct ToolPanel: View {
    @ObservedObject var m: StudioModel
    let tab: Tool
    @Binding var cutItem: PhotosPickerItem?
    @Binding var bgItem: PhotosPickerItem?

    var body: some View {
        Group {
            switch tab {
            case .layers: LayersPanel(m: m, cutItem: $cutItem)
            case .bkg: BkgPanel(m: m, bgItem: $bgItem)
            case .fx: FxPanel(m: m)
            case .text: TextPanel(m: m)
            case .size: SizePanel(m: m)
            case .look: LookPanel(m: m)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.opacity)
    }
}

/// زرّ أداة صغير بأيقونة وعنوان
struct ToolChip: View {
    let icon: String
    let title: String
    var on = false
    var enabled = true
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold))
                .frame(width: 50, height: 44)
                .background(on ? TH.coral.opacity(0.25) : TH.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? TH.coral : Color.clear, lineWidth: 1.5))
            Text(title).font(rnd(10.5, .bold)).lineLimit(1)
        }
        .foregroundStyle(on ? TH.coral : Color.white)
        .opacity(enabled ? 1 : 0.35)
    }
}

struct ToolButton: View {
    let icon: String
    let title: String
    var on = false
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: { HX.tap(); action() }) { ToolChip(icon: icon, title: title, on: on, enabled: enabled) }
            .buttonStyle(Press()).disabled(!enabled)
    }
}

struct PanelHint: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(TH.coral)
            Text(text).font(rnd(13.5, .semibold)).foregroundStyle(TH.tx2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SwatchRow: View {
    let colors: [RGBA]
    let current: RGBA?
    let pick: (RGBA) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(0..<colors.count, id: \.self) { i in
                    let c = colors[i]
                    Button { HX.tap(); pick(c) } label: {
                        Circle().fill(c.color).frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .overlay(Circle().stroke(current == c ? TH.coral : Color.clear, lineWidth: 3).padding(-4))
                    }.buttonStyle(Press())
                }
            }.padding(.horizontal, 16).padding(.vertical, 6)
        }
    }
}

struct FxSlider: View {
    let title: String
    let icon: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    let edit: (Bool) -> Void
    private var percent: Int {
        let span: Double = max(0.0001, range.upperBound - range.lowerBound)
        let f: Double = (value - range.lowerBound) / span
        return Int((f * 100).rounded())
    }
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(TH.coral).frame(width: 22)
            Text(title).font(rnd(13, .bold)).foregroundStyle(Color.white).frame(width: 74, alignment: .leading)
            Slider(value: $value, in: range, onEditingChanged: edit).tint(TH.coral)
            Text("\(percent)")
                .font(rnd(12, .heavy)).foregroundStyle(TH.tx3).frame(width: 30)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - الطبقات

struct LayersPanel: View {
    @ObservedObject var m: StudioModel
    @Binding var cutItem: PhotosPickerItem?
    @EnvironmentObject var bank: Bank

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $cutItem, matching: .images) { ToolChip(icon: "person.crop.rectangle.badge.plus", title: "قصّة") }
                    ToolButton(icon: "character.textbox", title: "نصّ") { m.addText() }
                    let has = m.sel != nil
                    ToolButton(icon: "plus.square.on.square", title: "تكرار", enabled: has) { m.duplicate() }
                    ToolButton(icon: "arrow.up.square", title: "لفوق", enabled: has) { m.up() }
                    ToolButton(icon: "arrow.down.square", title: "لجوّه", enabled: has) { m.down() }
                    ToolButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", title: "اقلب", on: m.sel?.xf.flip == true, enabled: has && m.sel?.isText == false) { m.toggleFlip() }
                    ToolButton(icon: "scope", title: "وسّط", enabled: has) { m.recenter() }
                    ToolButton(icon: m.sel?.hidden == true ? "eye.slash" : "eye", title: "إخفاء", on: m.sel?.hidden == true, enabled: has) { m.toggleHide() }
                    ToolButton(icon: m.sel?.locked == true ? "lock.fill" : "lock.open", title: "قفل", on: m.sel?.locked == true, enabled: has) { m.toggleLock() }
                    ToolButton(icon: "trash", title: "احذف", enabled: has) { m.delete() }
                }.padding(.horizontal, 16)
            }.padding(.top, 12)
            if m.project.layers.isEmpty {
                PanelHint(icon: "sparkles", text: "أضف قصّة من صورك أو نصّ حتى تبدي")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(m.project.layers.reversed())) { l in layerChip(l) }
                    }.padding(.horizontal, 16)
                }
            }
        }
    }

    private func layerChip(_ l: Layer) -> some View {
        let on = m.selected == l.id
        return Button {
            HX.tap()
            withAnimation(.easeOut(duration: 0.15)) { m.selected = l.id }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(TH.s3)
                    if let id = l.imageID, let img = bank.image(id) {
                        Image(uiImage: img).resizable().scaledToFit().padding(4)
                    } else {
                        Text("أ").font(rnd(18, .black)).foregroundStyle(Color.white)
                    }
                }.frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.textSpec.map { String($0.text.prefix(10)) } ?? l.name).font(rnd(12, .bold)).foregroundStyle(Color.white).lineLimit(1)
                    HStack(spacing: 4) {
                        if l.hidden { Image(systemName: "eye.slash").font(.system(size: 9, weight: .bold)) }
                        if l.locked { Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)) }
                        Text(l.isText ? "نصّ" : "قصّة").font(rnd(10))
                    }.foregroundStyle(TH.tx3)
                }
            }
            .padding(6).padding(.trailing, 6)
            .background(on ? TH.coral.opacity(0.2) : TH.s2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(on ? TH.coral : Color.clear, lineWidth: 1.5))
        }.buttonStyle(Press())
    }
}

// MARK: - الخلفيّة

struct BkgPanel: View {
    @ObservedObject var m: StudioModel
    @Binding var bgItem: PhotosPickerItem?
    @State private var mode = 0
    private let modes = ["لون", "تدرّج", "ضباب", "صورة", "أرضيّة", "شفّاف"]

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(0..<modes.count, id: \.self) { i in
                        Button { HX.tap(); mode = i; if i == 5 { m.setBkg(.clear) } } label: {
                            Text(modes[i]).font(rnd(13, .bold)).foregroundStyle(mode == i ? Color.black.opacity(0.85) : Color.white)
                                .padding(.horizontal, 14).frame(height: 32)
                                .background(mode == i ? AnyShapeStyle(TH.grad) : AnyShapeStyle(TH.s2), in: Capsule())
                        }.buttonStyle(Press())
                    }
                }.padding(.horizontal, 16)
            }.padding(.top, 12)
            content.frame(maxHeight: .infinity)
        }
        .onAppear { mode = BkgPanel.modeOf(m.project.bkg) }
    }

    static func modeOf(_ b: Bkg) -> Int {
        switch b {
        case .solid: return 0
        case .gradient: return 1
        case .blurPhoto: return 2
        case .photo: return 3
        case .floor: return 4
        case .clear: return 5
        }
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case 0:
            SwatchRow(colors: TH.swatches, current: currentSolid) { c in m.setBkg(.solid(c)) }
        case 1:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<TH.gradients.count, id: \.self) { i in
                        let g = TH.gradients[i]
                        let pts = Bkg.gradientPoints(g.2)
                        Button { m.setBkg(.gradient(g.0, g.1, g.2)) } label: {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [g.0.color, g.1.color], startPoint: UnitPoint(x: pts.0.x, y: pts.0.y), endPoint: UnitPoint(x: pts.1.x, y: pts.1.y)))
                                .frame(width: 54, height: 54)
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.15)))
                        }.buttonStyle(Press())
                    }
                }.padding(.horizontal, 16)
            }
        case 2:
            blurContent
        case 3:
            PhotosPicker(selection: $bgItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 16, weight: .bold))
                    Text("اختار صورة للخلفيّة").font(rnd(15, .heavy))
                }
                .foregroundStyle(Color.white).padding(.horizontal, 20).frame(height: 48).background(TH.s2, in: Capsule())
            }
        case 4:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<TH.floors.count, id: \.self) { i in
                        let f = TH.floors[i]
                        Button { m.setBkg(.floor(f.0, f.1, 0.7)) } label: {
                            VStack(spacing: 0) { f.0.color.frame(height: 36); f.1.color.frame(height: 18) }
                                .frame(width: 54).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.15)))
                        }.buttonStyle(Press())
                    }
                }.padding(.horizontal, 16)
            }
        default:
            PanelHint(icon: "checkerboard.rectangle", text: "خلفيّة شفّافة — مثاليّة للملصقات (صدّر PNG)")
        }
    }

    private var currentSolid: RGBA? { if case .solid(let c) = m.project.bkg { return c }; return nil }
    private var isBlur: Bool { if case .blurPhoto = m.project.bkg { return true }; return false }

    @ViewBuilder private var blurContent: some View {
        if let src = m.project.source {
            VStack(spacing: 6) {
                FxSlider(title: "الضباب", icon: "drop.fill", value: Binding(
                    get: { if case .blurPhoto(_, let r) = m.project.bkg { return r }; return 0.05 },
                    set: { v in m.live { $0.bkg = .blurPhoto(src, v) } }), range: 0.005...0.12) { e in if e { m.begin() } else { m.end() } }
                if !isBlur {
                    Button { m.setBkg(.blurPhoto(src, 0.05)) } label: {
                        Text("استعمل الصورة الأصليّة مضبّبة").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                            .padding(.horizontal, 18).frame(height: 40).background(TH.s2, in: Capsule())
                    }.buttonStyle(Press())
                }
            }
        } else {
            PanelHint(icon: "photo", text: "هالتصميم ما بيه صورة أصليّة — جرّب «صورة»")
        }
    }
}

// MARK: - التأثيرات

struct FxPanel: View {
    @ObservedObject var m: StudioModel
    @State private var colorTarget = 0

    var body: some View {
        if let l = m.sel {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    if !l.isText {
                        FxSlider(title: "حدّ ملصق", icon: "seal", value: bind(\.stroke), range: 0...Effects.maxStroke, edit: edit)
                    }
                    FxSlider(title: "ظلّ", icon: "shadow", value: bind(\.shadow), edit: edit)
                    FxSlider(title: "توهّج", icon: "sun.max.fill", value: bind(\.glow), edit: edit)
                    FxSlider(title: "شفافيّة", icon: "circle.lefthalf.filled", value: bind(\.opacity), range: 0.1...1, edit: edit)
                    HStack(spacing: 8) {
                        ForEach(0..<(l.isText ? 1 : 2), id: \.self) { i in
                            Button { HX.tap(); colorTarget = i } label: {
                                Text(i == 0 ? "لون التوهّج" : "لون الحدّ").font(rnd(12, .bold))
                                    .foregroundStyle(colorTarget == i ? Color.black.opacity(0.85) : Color.white)
                                    .padding(.horizontal, 12).frame(height: 28)
                                    .background(colorTarget == i ? AnyShapeStyle(TH.mint) : AnyShapeStyle(TH.s2), in: Capsule())
                            }.buttonStyle(Press())
                        }
                        Spacer()
                        if !l.isText {
                            Button { m.updateSel { $0.fx.reflect.toggle() } } label: {
                                Label("انعكاس", systemImage: "square.and.line.vertical.and.square").font(rnd(12, .bold))
                                    .foregroundStyle(l.fx.reflect ? Color.black.opacity(0.85) : Color.white)
                                    .padding(.horizontal, 12).frame(height: 28)
                                    .background(l.fx.reflect ? AnyShapeStyle(TH.mint) : AnyShapeStyle(TH.s2), in: Capsule())
                            }.buttonStyle(Press())
                        }
                    }.padding(.horizontal, 16)
                    SwatchRow(colors: TH.swatches, current: colorTarget == 0 || l.isText ? l.fx.glowColor : l.fx.strokeColor) { c in
                        if colorTarget == 0 || l.isText { m.updateSel { $0.fx.glowColor = c } } else { m.updateSel { $0.fx.strokeColor = c; if $0.fx.stroke < 0.005 { $0.fx.stroke = 0.04 } } }
                    }
                    Button { m.updateSel { $0.fx = Effects() } } label: {
                        Text("رجّع التأثيرات").font(rnd(12, .bold)).foregroundStyle(TH.tx3)
                    }.padding(.bottom, 6)
                }.padding(.top, 12)
            }
        } else {
            PanelHint(icon: "hand.tap.fill", text: "انقر على قصّة أو نصّ باللوحة حتى تزيّنه")
        }
    }

    private func edit(_ e: Bool) { if e { m.begin() } else { m.end() } }
    private func bind(_ kp: WritableKeyPath<Effects, Double>) -> Binding<Double> {
        Binding(get: { m.sel?.fx[keyPath: kp] ?? 0 }, set: { v in m.liveSel { $0.fx[keyPath: kp] = v } })
    }
}

// MARK: - النصّ

struct TextPanel: View {
    @ObservedObject var m: StudioModel
    @FocusState private var focused: Bool

    var body: some View {
        if let l = m.sel, let t = l.textSpec {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("اكتب…", text: textBinding, axis: .vertical)
                            .font(rnd(16, .bold)).foregroundStyle(Color.white).lineLimit(1...3)
                            .focused($focused)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(TH.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        if focused {
                            Button { focused = false; m.end() } label: {
                                Text("تمّ").font(rnd(14, .black)).foregroundStyle(Color.white).padding(.horizontal, 14).frame(height: 40).background(TH.grad, in: Capsule())
                            }.buttonStyle(Press())
                        }
                    }.padding(.horizontal, 16)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<TH.fontTitles.count, id: \.self) { i in
                                Button { m.updateSel { $0.setText { $0.font = i } } } label: {
                                    Text(TH.fontTitles[i]).font(TH.font(i, size: 15)).foregroundStyle(t.font == i ? Color.black.opacity(0.85) : Color.white)
                                        .padding(.horizontal, 14).frame(height: 34)
                                        .background(t.font == i ? AnyShapeStyle(TH.grad) : AnyShapeStyle(TH.s2), in: Capsule())
                                }.buttonStyle(Press())
                            }
                        }.padding(.horizontal, 16)
                    }
                    FxSlider(title: "الحجم", icon: "textformat.size", value: sizeBinding, range: 0.03...0.4) { e in if e { m.begin() } else { m.end() } }
                    HStack {
                        Button { m.updateSel { $0.setText { $0.pill.toggle() } } } label: {
                            Label("خلفيّة كبسولة", systemImage: "capsule.fill").font(rnd(12, .bold))
                                .foregroundStyle(t.pill ? Color.black.opacity(0.85) : Color.white)
                                .padding(.horizontal, 12).frame(height: 28)
                                .background(t.pill ? AnyShapeStyle(TH.mint) : AnyShapeStyle(TH.s2), in: Capsule())
                        }.buttonStyle(Press())
                        Spacer()
                    }.padding(.horizontal, 16)
                    SwatchRow(colors: TH.swatches, current: t.color) { c in
                        m.updateSel { l in
                            l.setText { s in
                                if s.pill { s.pillColor = RGBA(c.r, c.g, c.b, 0.85); s.color = c.luma > 0.6 ? RGBA(0.08, 0.08, 0.1) : .white } else { s.color = c }
                            }
                        }
                    }
                }.padding(.top, 12).padding(.bottom, 8)
            }
            .onDisappear { m.end() }
        } else {
            VStack(spacing: 12) {
                Text("النصوص العربيّة بخطوط مختلفة — حطّ عنوان أو تعليق").font(rnd(13.5, .semibold)).foregroundStyle(TH.tx2)
                Button { m.addText() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 15, weight: .black))
                        Text("أضف نصّ").font(rnd(16, .black))
                    }.foregroundStyle(Color.white).padding(.horizontal, 24).frame(height: 46).background(TH.grad, in: Capsule())
                }.buttonStyle(Press())
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var textBinding: Binding<String> {
        Binding(get: { m.sel?.textSpec?.text ?? "" }, set: { v in
            m.begin()
            m.liveSel { $0.setText { $0.text = String(v.prefix(120)) } }
        })
    }
    private var sizeBinding: Binding<Double> {
        Binding(get: { m.sel?.textSpec?.size ?? 0.1 }, set: { v in m.liveSel { $0.setText { $0.size = v } } })
    }
}

// MARK: - المقاس

struct SizePanel: View {
    @ObservedObject var m: StudioModel
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Aspect.allCases, id: \.self) { a in
                let on = m.project.aspect == a
                Button { m.setAspect(a) } label: {
                    VStack(spacing: 8) {
                        let r = Fit.fit(TSize(a.ratio, 1), in: TRect(0, 0, 46, 46))
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(on ? TH.coral : Color.white.opacity(0.6), lineWidth: 2)
                            .frame(width: r.w, height: r.h).frame(width: 50, height: 50)
                        Text(a.title).font(rnd(13, .heavy))
                        Text(a.label).font(rnd(11, .bold)).foregroundStyle(TH.tx3).environment(\.layoutDirection, .leftToRight)
                    }
                    .foregroundStyle(on ? TH.coral : Color.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(on ? TH.coral.opacity(0.14) : TH.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(Press())
            }
        }
        .padding(.horizontal, 16).padding(.top, 14)
    }
}

// MARK: - القوالب داخل الاستوديو

struct LookPanel: View {
    @ObservedObject var m: StudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("طبّق قالب على قصّاتك (تگدر تتراجع)").font(rnd(12, .semibold)).foregroundStyle(TH.tx3).padding(.horizontal, 16).padding(.top, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Templates.all) { t in
                        Button { m.applyTemplate(t) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: t.symbol).font(.system(size: 22, weight: .bold)).foregroundStyle(TH.grad)
                                    .frame(width: 64, height: 64)
                                    .background(TH.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(m.project.template == t.id ? TH.coral : Color.clear, lineWidth: 2))
                                Text(t.title).font(rnd(12, .bold)).foregroundStyle(Color.white)
                                Text(t.aspect.title).font(rnd(10)).foregroundStyle(TH.tx3)
                            }.frame(width: 78)
                        }.buttonStyle(Press())
                    }
                }.padding(.horizontal, 16)
            }
        }
    }
}
