import SwiftUI

// MARK: العوالم والمراحل

struct WorldsView: View {
    @EnvironmentObject var prog: Prog
    let close: () -> Void
    @State private var launch: Launch? = nil

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Button(action: close) {
                            Image(systemName: "chevron.right").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                                .frame(width: 42, height: 42).background(SQ.s2, in: Circle())
                        }.buttonStyle(Press())
                        VStack(alignment: .leading, spacing: 1) {
                            Text("الحملة").font(rnd(26, .black)).foregroundStyle(Color.white)
                            Text("6 عوالم · 60 مرحلة").font(rnd(12.5)).foregroundStyle(SQ.tx3)
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: "star.fill").font(.system(size: 14, weight: .black)).foregroundStyle(SQ.gold)
                            Text("\(prog.totalStars)").font(rnd(18, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
                        }.padding(.horizontal, 12).frame(height: 40).background(SQ.s2, in: Capsule())
                    }
                    ForEach(0..<Levels.worldCount, id: \.self) { w in
                        WorldCard(w: w) { id in Haptic.tap(); Synth.shared.start(); launch = Launch(mode: .campaign(id)) }
                    }
                }.padding(18)
            }
        }
        .fullScreenCover(item: $launch) { l in
            PlayHost(mode: l.mode) { launch = nil }.environmentObject(prog)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
    }
}

struct WorldCard: View {
    @EnvironmentObject var prog: Prog
    let w: Int
    let pick: (Int) -> Void

    var body: some View {
        let info = Levels.worlds[w]
        let col = SQ.world(w)
        let open = prog.worldOpen(w)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: open ? info.icon : "lock.fill").font(.system(size: 18, weight: .black)).foregroundStyle(open ? col : SQ.tx3)
                    .frame(width: 46, height: 46).background(col.opacity(open ? 0.15 : 0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("العالم \(w + 1) · \(info.name)").font(rnd(17, .black)).foregroundStyle(Color.white)
                    Text(open ? info.note : "خلّص العالم اللي قبله حتى ينفتح").font(rnd(12)).foregroundStyle(SQ.tx3)
                }
                Spacer()
                Text("\(prog.worldStars(w))/30").font(rnd(13, .black)).foregroundStyle(col).environment(\.layoutDirection, .leftToRight)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(0..<Levels.perWorld, id: \.self) { i in
                    LevelCell(id: w * Levels.perWorld + i, color: col, pick: pick)
                }
            }
        }
        .padding(14).card(SQ.s1, 24, stroke: col.opacity(open ? 0.25 : 0.08))
        .opacity(open ? 1 : 0.7)
    }
}

struct LevelCell: View {
    @EnvironmentObject var prog: Prog
    let id: Int
    let color: Color
    let pick: (Int) -> Void

    var body: some View {
        let st = prog.d.stars[id]
        let ok = prog.unlocked(id)
        let current = ok && st == 0
        return Button { if ok { pick(id) } else { Haptic.bad() } } label: {
            VStack(spacing: 3) {
                if ok {
                    Text("\(id % Levels.perWorld + 1)").font(rnd(18, .black)).foregroundStyle(current ? Color.black.opacity(0.8) : Color.white)
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { k in
                            Image(systemName: "star.fill").font(.system(size: 7, weight: .black))
                                .foregroundStyle(k < st ? SQ.gold : (current ? Color.black.opacity(0.25) : Color.white.opacity(0.15)))
                        }
                    }
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(SQ.tx3)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(current ? AnyShapeStyle(color) : AnyShapeStyle(Color.white.opacity(ok ? 0.07 : 0.03)), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(id % 10 == 9 ? color.opacity(0.6) : Color.clear, lineWidth: 1.5))
            .shadow(color: current ? color.opacity(0.5) : Color.clear, radius: 10)
        }.buttonStyle(Press())
    }
}

// MARK: المتجر

struct ShopView: View {
    @EnvironmentObject var prog: Prog
    let close: () -> Void
    @State private var tab = 0
    @State private var note = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("المتجر").font(rnd(28, .black)).foregroundStyle(Color.white)
                        Text("اجمع العملات من المراحل والتحدّيات").font(rnd(12.5)).foregroundStyle(SQ.tx3)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        CoinDot(size: 22)
                        Text("\(prog.d.coins)").font(rnd(19, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
                    }.padding(.horizontal, 12).frame(height: 44).background(SQ.s2, in: Capsule())
                }.padding(.top, 20)
                Picker("", selection: $tab) {
                    Text("الشفرات").tag(0)
                    Text("الألوان").tag(1)
                }.pickerStyle(.segmented)
                if !note.isEmpty {
                    Text(note).font(rnd(13, .bold)).foregroundStyle(SQ.amber).frame(maxWidth: .infinity)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    if tab == 0 {
                        ForEach(0..<Catalog.blades.count, id: \.self) { i in bladeItem(i) }
                    } else {
                        ForEach(0..<Catalog.skins.count, id: \.self) { i in skinItem(i) }
                    }
                }
                Button(action: close) {
                    Text("تمّ").font(rnd(17, .black)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 52).background(SQ.s2, in: Capsule())
                }.buttonStyle(Press()).padding(.top, 4)
            }.padding(18)
        }
        .background(Backdrop())
    }

    private func bladeItem(_ i: Int) -> some View {
        let b = Catalog.blade(i)
        let owned = prog.d.blades.contains(i), sel = prog.d.blade == i
        return Button {
            if prog.buyBlade(i) { Haptic.ok(); Synth.shared.play(owned ? "tap" : "coin"); note = "" }
            else { Haptic.bad(); note = "تحتاج \(b.price - prog.d.coins) عملة زيادة" }
        } label: {
            itemCard(name: b.name, price: b.price, owned: owned, sel: sel) {
                BladePreview(blade: b).frame(height: 70)
            }
        }.buttonStyle(Press())
    }

    private func skinItem(_ i: Int) -> some View {
        let s = Catalog.skin(i)
        let owned = prog.d.skins.contains(i), sel = prog.d.skin == i
        return Button {
            if prog.buySkin(i) { Haptic.ok(); Synth.shared.play(owned ? "tap" : "coin"); note = "" }
            else { Haptic.bad(); note = "تحتاج \(s.price - prog.d.coins) عملة زيادة" }
        } label: {
            itemCard(name: s.name, price: s.price, owned: owned, sel: sel) {
                SkinPreview(skin: s).frame(height: 70)
            }
        }.buttonStyle(Press())
    }

    private func itemCard<V: View>(name: String, price: Int, owned: Bool, sel: Bool, @ViewBuilder preview: () -> V) -> some View {
        VStack(spacing: 10) {
            preview()
            Text(name).font(rnd(15, .black)).foregroundStyle(Color.white)
            Group {
                if sel {
                    Label("مستعمل", systemImage: "checkmark.circle.fill").foregroundStyle(SQ.mint)
                } else if owned {
                    Text("استعمل").foregroundStyle(SQ.tx2)
                } else {
                    HStack(spacing: 4) {
                        CoinDot(size: 14)
                        Text("\(price)").environment(\.layoutDirection, .leftToRight)
                    }.foregroundStyle(SQ.gold)
                }
            }
            .font(rnd(12.5, .heavy)).frame(height: 28).padding(.horizontal, 10)
            .background(Color.white.opacity(0.06), in: Capsule())
        }
        .padding(12).frame(maxWidth: .infinity)
        .card(SQ.s1, 20, stroke: sel ? SQ.mint.opacity(0.6) : Color.white.opacity(0.07))
    }
}

struct BladePreview: View {
    let blade: Blade
    var body: some View {
        Canvas { ctx, sz in
            var p = Path()
            let n = 24
            for i in 0...n {
                let u = CGFloat(i) / CGFloat(n)
                let pt = CGPoint(x: 10 + (sz.width - 20) * u, y: sz.height * 0.75 - (sz.height * 0.5) * u + sin(u * 6) * 4)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            var glow = ctx
            glow.addFilter(.blur(radius: 6))
            if blade.rainbow {
                let g = Gradient(colors: [Color.red, Color.orange, Color.yellow, Color.green, Color.cyan, Color.blue, Color.purple])
                let sh = GraphicsContext.Shading.linearGradient(g, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: sz.width, y: 0))
                glow.stroke(p, with: sh, style: StrokeStyle(lineWidth: blade.width * 2, lineCap: .round))
                ctx.stroke(p, with: sh, style: StrokeStyle(lineWidth: blade.width, lineCap: .round))
            } else {
                let sh = GraphicsContext.Shading.linearGradient(Gradient(colors: [blade.b.opacity(0.2), blade.a]), startPoint: CGPoint(x: 0, y: sz.height), endPoint: CGPoint(x: sz.width, y: 0))
                glow.stroke(p, with: sh, style: StrokeStyle(lineWidth: blade.width * 2, lineCap: .round))
                ctx.stroke(p, with: sh, style: StrokeStyle(lineWidth: blade.width, lineCap: .round))
            }
            ctx.stroke(p, with: .color(Color.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct SkinPreview: View {
    static let star = ShapeLib.make(.star, seed: 3, vary: false)
    let skin: Skin
    var body: some View {
        Canvas { ctx, sz in
            let bg = Path(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: 14)
            ctx.fill(bg, with: .linearGradient(Gradient(colors: [skin.bg0, skin.bg1]), startPoint: .zero, endPoint: CGPoint(x: 0, y: sz.height)))
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2), R = min(sz.width, sz.height) * 0.4
            let p = Painter.path(SkinPreview.star) { q in CGPoint(x: c.x + CGFloat(q.x) * R, y: c.y + CGFloat(q.y) * R) }
            var g = ctx
            g.addFilter(.shadow(color: skin.a.opacity(0.6), radius: 10))
            g.fill(p, with: .linearGradient(Gradient(colors: [skin.a, skin.b]), startPoint: CGPoint(x: c.x - R, y: c.y - R), endPoint: CGPoint(x: c.x + R, y: c.y + R)))
            ctx.stroke(p, with: .color(Color.white.opacity(0.7)), lineWidth: 1.2)
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: الإحصائيّات

struct StatsView: View {
    @EnvironmentObject var prog: Prog
    let close: () -> Void

    var body: some View {
        let d = prog.d
        let rate = d.rounds > 0 ? Int((Double(d.perfects) / Double(d.rounds) * 100).rounded()) : 0
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("دقّتك").font(rnd(28, .black)).foregroundStyle(Color.white).padding(.top, 20)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile(String(format: "±%.1f%%", prog.avgError), "معدّل الخطأ", "scope", SQ.cyan)
                    tile("\(rate)%", "نسبة «مثالي»", "sparkles", SQ.gold)
                    tile("\(d.cuts)", "عدد القطعات", "scissors", SQ.coral)
                    tile("×\(d.bestCombo)", "أعلى كومبو", "flame.fill", SQ.amber)
                    tile("\(d.bestEndless)", "أفضل بلا نهاية", "infinity", SQ.violet)
                    tile("\(prog.totalStars)/180", "النجوم", "star.fill", SQ.mint)
                }
                recentChart(d.recent)
                worldBars
                Button(action: close) {
                    Text("تمّ").font(rnd(17, .black)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 52).background(SQ.s2, in: Capsule())
                }.buttonStyle(Press())
            }.padding(18)
        }
        .background(Backdrop())
    }

    private func tile(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(24, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(11.5)).foregroundStyle(SQ.tx3)
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading).card(SQ.s1, 18, stroke: c.opacity(0.2))
    }

    private func recentChart(_ r: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("آخر القطعات").font(rnd(16, .black)).foregroundStyle(Color.white)
                Spacer()
                Text("أطول = أدقّ").font(rnd(11)).foregroundStyle(SQ.tx3)
            }
            if r.isEmpty {
                Text("العب كم جولة حتى تشوف دقّتك هنا").font(rnd(13)).foregroundStyle(SQ.tx3).frame(maxWidth: .infinity).frame(height: 90)
            } else {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<r.count, id: \.self) { i in
                        let e = r[i]
                        let h = CGFloat(max(0.06, (12 - min(12, e)) / 12))
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(SQ.grade(Grade.of(e)))
                            .frame(maxWidth: .infinity).frame(height: 90 * h)
                    }
                }.frame(height: 90, alignment: .bottom).environment(\.layoutDirection, .leftToRight)
            }
        }.padding(14).card(SQ.s1, 20)
    }

    private var worldBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("العوالم").font(rnd(16, .black)).foregroundStyle(Color.white)
            ForEach(0..<Levels.worldCount, id: \.self) { w in
                let st = prog.worldStars(w)
                HStack(spacing: 10) {
                    Text(Levels.worlds[w].name).font(rnd(12.5, .bold)).foregroundStyle(SQ.tx2).frame(width: 74, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule().fill(SQ.world(w)).frame(width: max(6, g.size.width * CGFloat(st) / 30))
                        }
                    }.frame(height: 8).environment(\.layoutDirection, .leftToRight)
                    Text("\(st)").font(rnd(12.5, .black)).foregroundStyle(SQ.world(w)).frame(width: 24)
                }
            }
        }.padding(14).card(SQ.s1, 20)
    }
}

// MARK: الإعدادات

struct SettingsView: View {
    @EnvironmentObject var prog: Prog
    let intro: () -> Void
    let close: () -> Void
    @State private var confirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("الإعدادات").font(rnd(28, .black)).foregroundStyle(Color.white).padding(.top, 20)
                VStack(spacing: 0) {
                    toggle("الأصوات", "speaker.wave.2.fill", SQ.cyan, Binding(get: { prog.d.sound }, set: { v in var d = prog.d; d.sound = v; prog.d = d; Synth.shared.enabled = v }))
                    Divider().overlay(Color.white.opacity(0.06))
                    toggle("الاهتزاز", "iphone.radiowaves.left.and.right", SQ.violet, Binding(get: { prog.d.haptics }, set: { v in var d = prog.d; d.haptics = v; prog.d = d; if v { Haptic.thud() } }))
                }.padding(.horizontal, 14).card(SQ.s1, 20)
                row("شلون ألعب؟", "questionmark.circle.fill", SQ.amber, action: intro)
                row("صفّر التقدّم", "trash.fill", SQ.red) { confirm = true }
                VStack(alignment: .leading, spacing: 6) {
                    Text("عن شقّ").font(rnd(15, .black)).foregroundStyle(Color.white)
                    Text("لعبة دقّة: كلّ شكل يطلب نسبة، وأنت عندك قطعة وحدة. الأشكال تدور وتتحرّك وتنبض، وبعضها مثقوب أو محاط بمسامير. كلّشي يشتغل على جهازك بلا إنترنت.")
                        .font(rnd(12.5)).foregroundStyle(SQ.tx2).lineSpacing(3)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).card(SQ.s1, 20)
                Button(action: close) {
                    Text("تمّ").font(rnd(17, .black)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 52).background(SQ.s2, in: Capsule())
                }.buttonStyle(Press())
            }.padding(18)
        }
        .background(Backdrop())
        .confirmationDialog("تمسح كلّ النجوم والعملات والمشتريات؟", isPresented: $confirm, titleVisibility: .visible) {
            Button("امسح كلّشي", role: .destructive) { prog.reset(); Haptic.bad() }
            Button("لا، رجّعني", role: .cancel) {}
        }
    }

    private func toggle(_ t: String, _ icon: String, _ c: Color, _ b: Binding<Bool>) -> some View {
        Toggle(isOn: b) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(c).frame(width: 30)
                Text(t).font(rnd(15.5, .bold)).foregroundStyle(Color.white)
            }
        }.tint(SQ.coral).frame(height: 56)
    }

    private func row(_ t: String, _ icon: String, _ c: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(c).frame(width: 30)
                Text(t).font(rnd(15.5, .bold)).foregroundStyle(Color.white)
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .black)).foregroundStyle(SQ.tx3)
            }.padding(.horizontal, 14).frame(height: 56).card(SQ.s1, 20)
        }.buttonStyle(Press())
    }
}

// MARK: الترحيب

struct IntroView: View {
    let done: () -> Void
    @State private var page = 0

    let pages: [(icon: String, color: Color, title: String, text: String)] = [
        (icon: "hand.draw.fill", color: SQ.coral, title: "قطعة وحدة", text: "اسحب إصبعك بخطّ مستقيم عبر الشكل. الشكل ينشقّ نصّين والقطعة الصغيرة تطيح."),
        (icon: "percent", color: SQ.amber, title: "الهدف نسبة", text: "كلّ جولة تطلب نسبة، مثل «اقطع 37%». النسبة = حجم القطعة الأصغر من الشكل كلّه."),
        (icon: "sparkles", color: SQ.gold, title: "±1% = مثالي!", text: "كلّ ما قرّبت أكثر تاخذ نقاط أكثر. سلسلة قطعات دقيقة = كومبو ومضاعف وعملات."),
        (icon: "square.split.2x2.fill", color: SQ.mint, title: "وبعدين يصعب", text: "أشكال تدور وتتحرّك، حروف مقعّرة، ثقوب، قطعتان لقطع متساوية، مسامير لازم تعبر من بينها، ووقت يقصر."),
    ]

    var body: some View {
        VStack(spacing: 18) {
            TabView(selection: $page) {
                ForEach(0..<pages.count, id: \.self) { i in
                    let p = pages[i]
                    VStack(spacing: 18) {
                        Spacer()
                        ZStack {
                            Circle().fill(p.color.opacity(0.14)).frame(width: 150, height: 150)
                            Circle().stroke(p.color.opacity(0.35), lineWidth: 2).frame(width: 150, height: 150)
                            Image(systemName: p.icon).font(.system(size: 58, weight: .bold)).foregroundStyle(p.color)
                        }.shadow(color: p.color.opacity(0.4), radius: 24)
                        Text(p.title).font(rnd(30, .black)).foregroundStyle(Color.white)
                        Text(p.text).font(rnd(15.5)).foregroundStyle(SQ.tx2).multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 26)
                        Spacer()
                    }.tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Button {
                Haptic.tap()
                if page < pages.count - 1 { withAnimation { page += 1 } } else { done() }
            } label: {
                Text(page < pages.count - 1 ? "التالي" : "يلّا نقطع").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.82))
                    .frame(maxWidth: .infinity).frame(height: 56).background(SQ.hot, in: Capsule())
            }.buttonStyle(Press()).padding(.horizontal, 22).padding(.bottom, 18)
        }
        .background(Backdrop())
    }
}
