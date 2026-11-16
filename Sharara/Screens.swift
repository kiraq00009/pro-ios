import SwiftUI

// MARK: المجرّات والمراحل

struct LevelsView: View {
    @EnvironmentObject var store: GameStore
    let back: () -> Void
    let play: (GameReq) -> Void
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 14) {
            SubHeader(title: "المجرّات", back: back, trailing: AnyView(starBadge))
            TabSwitch(items: ["الحملة", "الضربة الكاملة"], sel: $tab)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if tab == 0 {
                        ForEach(0..<Gen.galaxyCount, id: \.self) { g in
                            GalaxyCard(g: g, play: play)
                        }
                    } else {
                        PerfectGrid(play: play)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var starBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").font(.system(size: 12, weight: .black)).foregroundStyle(ST.gold)
            Text("\(store.p.totalStars)/٢٤٠").font(rnd(13, .heavy)).foregroundStyle(Color.white)
        }
        .padding(.horizontal, 12).frame(height: 34)
        .background(Color.white.opacity(0.07), in: Capsule())
    }
}

struct TabSwitch: View {
    let items: [String]
    @Binding var sel: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<items.count, id: \.self) { i in
                Button { Haptic.tap(); withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { sel = i } } label: {
                    Text(items[i]).font(rnd(14, .heavy)).foregroundStyle(sel == i ? Color.white : ST.tx3)
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(sel == i ? AnyShapeStyle(ST.hot) : AnyShapeStyle(Color.clear), in: Capsule())
                }
                .buttonStyle(Press())
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: Capsule())
    }
}

struct GalaxyCard: View {
    @EnvironmentObject var store: GameStore
    let g: Int
    let play: (GameReq) -> Void

    var body: some View {
        let gc = ST.galaxyColor(g)
        let open = store.p.unlocked(g * Gen.perGalaxy)
        let intro = Gen.galaxyIntro[g]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                OrbIcon(kind: intro == .normal ? .splitter : intro, size: 46, live: open)
                VStack(alignment: .leading, spacing: 2) {
                    Text("المجرّة \(g + 1)").font(rnd(11.5, .heavy)).foregroundStyle(gc)
                    Text(Gen.galaxyNames[g]).font(rnd(19, .black)).foregroundStyle(Color.white)
                    Text(intro == .normal ? "كلّ الأنواع سوا" : "جديد: " + intro.name).font(rnd(11.5, .medium)).foregroundStyle(ST.tx3)
                }
                Spacer()
                HStack(spacing: 3) {
                    Text("\(store.p.galaxyStars(g))/٣٠").font(rnd(13, .heavy)).foregroundStyle(Color.white)
                    Image(systemName: "star.fill").font(.system(size: 11, weight: .black)).foregroundStyle(ST.gold)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
                ForEach(0..<Gen.perGalaxy, id: \.self) { k in
                    LevelNode(i: g * Gen.perGalaxy + k, color: gc, play: play)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                ST.s1.opacity(0.88)
                RadialGradient(colors: [gc.opacity(open ? 0.22 : 0.06), .clear], center: .topLeading, startRadius: 0, endRadius: 280)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(gc.opacity(open ? 0.3 : 0.08)))
        .opacity(open ? 1 : 0.6)
    }
}

struct LevelNode: View {
    @EnvironmentObject var store: GameStore
    let i: Int
    let color: Color
    let play: (GameReq) -> Void

    var body: some View {
        let open = store.p.unlocked(i)
        let st = store.p.stars[i]
        let isCur = i == store.p.current
        return Button {
            if open { Haptic.thud(); play(GameReq(mode: .campaign, index: i)) } else { Haptic.bad() }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(open ? (st > 0 ? color.opacity(0.28) : Color.white.opacity(0.08)) : Color.white.opacity(0.04))
                    Circle().stroke(isCur ? color : Color.white.opacity(open ? 0.15 : 0.05), lineWidth: isCur ? 2.5 : 1)
                    if open {
                        Text("\(i % Gen.perGalaxy + 1)").font(rnd(17, .black)).foregroundStyle(Color.white)
                    } else {
                        Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(ST.tx3)
                    }
                }
                .frame(width: 48, height: 48)
                .shadow(color: isCur ? color.opacity(0.7) : .clear, radius: 10)
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { s in
                        Image(systemName: "star.fill").font(.system(size: 8.5, weight: .black))
                            .foregroundStyle(s < st ? ST.gold : Color.white.opacity(0.15))
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .buttonStyle(Press())
    }
}

struct PerfectGrid: View {
    @EnvironmentObject var store: GameStore
    let play: (GameReq) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "scope").font(.system(size: 20, weight: .black)).foregroundStyle(ST.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ضربة وحدة… ولازم تكون كاملة").font(rnd(16, .heavy)).foregroundStyle(Color.white)
                    Text("كلّ تحدّي إله رقم واحد: أعلى سلسلة ممكنة. لا أقلّ.").font(rnd(12, .medium)).foregroundStyle(ST.tx3)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(0..<Gen.perfectCount, id: \.self) { i in
                    perfectCell(i)
                }
            }
        }
        .padding(16)
        .card(ST.s1.opacity(0.88), 24)
    }

    private func perfectCell(_ i: Int) -> some View {
        let open = store.p.perfectUnlocked(i)
        let done = store.p.perfect[i]
        return Button {
            if open { Haptic.thud(); play(GameReq(mode: .perfect, index: i)) } else { Haptic.bad() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: done ? "checkmark.seal.fill" : (open ? "scope" : "lock.fill"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(done ? ST.gold : (open ? Color.white : ST.tx3))
                Text("\(i + 1)").font(rnd(13, .heavy)).foregroundStyle(open ? ST.tx2 : ST.tx3)
            }
            .frame(maxWidth: .infinity).frame(height: 64)
            .card(done ? ST.gold.opacity(0.12) : Color.white.opacity(open ? 0.06 : 0.02), 16, stroke: done ? ST.gold.opacity(0.4) : Color.white.opacity(0.07))
        }
        .buttonStyle(Press())
    }
}

// MARK: المتجر

struct ShopView: View {
    @EnvironmentObject var store: GameStore
    let back: () -> Void
    @State private var tab = 0
    @State private var short: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            SubHeader(title: "المتجر", back: back, trailing: AnyView(CoinPill(coins: store.p.coins)))
            TabSwitch(items: ["الشرارات", "الخلفيّات"], sel: $tab)
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    if tab == 0 {
                        ForEach(Catalog.sparks, id: \.id) { s in
                            ShopItem(id: s.id, name: s.name, price: s.price, owned: store.p.owns(s.id), selected: store.p.spark == s.id, action: { tapItem(s.id) }) {
                                SparkPreview(skin: s)
                            }
                        }
                    } else {
                        ForEach(Catalog.backs, id: \.id) { b in
                            ShopItem(id: b.id, name: b.name, price: b.price, owned: store.p.owns(b.id), selected: store.p.back == b.id, action: { tapItem(b.id) }) {
                                BackPreview(back: b)
                            }
                        }
                    }
                }
                .padding(.bottom, 30)
                Text("الكوينز تجيك من النجوم، تحدّي اليوم، الضربة الكاملة، وجولات بلا نهاية.")
                    .font(rnd(12)).foregroundStyle(ST.tx3).multilineTextAlignment(.center).padding(.bottom, 30)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .alert("الكوينز ما تكفي", isPresented: Binding(get: { short != nil }, set: { if !$0 { short = nil } })) {
            Button("تمام", role: .cancel) {}
        } message: {
            Text(short ?? "")
        }
    }

    private func tapItem(_ id: String) {
        if store.p.owns(id) {
            if store.p.select(id) { Haptic.tap() }
            return
        }
        let price = Catalog.price(id) ?? 0
        if store.p.buy(id) {
            _ = store.p.select(id)
            Haptic.ok()
            Synth.shared.win()
        } else {
            Haptic.bad()
            short = "تحتاج \(price - store.p.coins) كوين بعد. العب مراحل وتحدّيات حتى تجمعها."
        }
    }
}

struct ShopItem<Preview: View>: View {
    let id: String
    let name: String
    let price: Int
    let owned: Bool
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let preview: () -> Preview

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                preview()
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                HStack {
                    Text(name).font(rnd(14.5, .heavy)).foregroundStyle(Color.white)
                    Spacer()
                    status
                }
            }
            .padding(10)
            .card(selected ? ST.spark.opacity(0.12) : ST.s1.opacity(0.9), 20, stroke: selected ? ST.spark.opacity(0.7) : Color.white.opacity(0.07))
        }
        .buttonStyle(Press())
    }

    @ViewBuilder private var status: some View {
        if selected {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(ST.spark)
        } else if owned {
            Text("اختار").font(rnd(12, .heavy)).foregroundStyle(ST.tx2)
        } else {
            HStack(spacing: 3) {
                CoinView(size: 14)
                Text("\(price)").font(rnd(12.5, .heavy)).foregroundStyle(ST.gold)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

struct SparkPreview: View {
    let skin: SparkSkin
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: Shot.on)) { tl in
            Canvas { g, size in
                let t = Shot.on ? 0.42 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
                g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.03, green: 0.02, blue: 0.08)))
                var add = g
                add.blendMode = .plusLighter
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let f = (t * 0.7).truncatingRemainder(dividingBy: 1)
                let col: Color = skin.rainbow ? Color(hue: (t * 0.3).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 1) : ST.c(skin.glow)
                let r = CGFloat(10 + f * 46)
                add.fill(Painter.circle(c, r), with: .radialGradient(Gradient(colors: [col.opacity(0.05), col.opacity(0.3 * (1 - f))]), center: c, startRadius: 0, endRadius: r))
                add.stroke(Painter.circle(c, r), with: .color(col.opacity(1 - f)), lineWidth: 3)
                Painter.glow(add, c, 30, ST.c(skin.core), 0.9)
                for k in 0..<10 {
                    let a = Double(k) * 0.628 + t
                    let d = CGFloat(f) * 50
                    add.fill(Painter.circle(CGPoint(x: c.x + CGFloat(cos(a)) * d, y: c.y + CGFloat(sin(a)) * d), 2), with: .color(ST.c(skin.core, 1 - f)))
                }
            }
        }
    }
}

struct BackPreview: View {
    let back: BackSkin
    var body: some View {
        Canvas { g, size in
            Painter.background(g, size, back, t: 3, shift: 0)
            var add = g
            add.blendMode = .plusLighter
            let pts: [(OrbKind, CGFloat, CGFloat)] = [(.normal, 0.3, 0.4), (.big, 0.65, 0.6), (.splitter, 0.45, 0.75), (.timer, 0.78, 0.3)]
            for p in pts {
                let c = CGPoint(x: size.width * p.1, y: size.height * p.2)
                Painter.glow(add, c, 22, Look.color(p.0), 0.5)
                g.fill(Painter.circle(c, 6), with: .color(Look.color(p.0)))
            }
        }
    }
}

// MARK: الإحصائيّات

struct StatsView: View {
    @EnvironmentObject var store: GameStore
    let back: () -> Void

    var body: some View {
        let p = store.p
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return VStack(spacing: 14) {
            SubHeader(title: "إحصائيّاتي", back: back)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    LazyVGrid(columns: cols, spacing: 12) {
                        StatCard(icon: "link", title: "أطول سلسلة", value: "\(p.longest)", color: ST.spark)
                        StatCard(icon: "trophy.fill", title: "أعلى نقاط", value: "\(p.topScore)", color: ST.gold)
                        StatCard(icon: "burst.fill", title: "كلّ الانفجارات", value: "\(p.totalPops)", color: ST.pink)
                        StatCard(icon: "arrow.triangle.branch", title: "أعمق جيل", value: "\(p.deepest)", color: ST.cyan)
                        StatCard(icon: "hand.tap.fill", title: "الضربات", value: "\(p.shots)", color: ST.violet)
                        StatCard(icon: "checkmark.seal.fill", title: "نسبة الفوز", value: p.shots > 0 ? "\(p.wins * 100 / p.shots)٪" : "—", color: ST.lime)
                        StatCard(icon: "infinity", title: "أحسن بلا نهاية", value: "\(p.endlessRounds) جولة", color: ST.cyan)
                        StatCard(icon: "flame.fill", title: "سلسلة الأيّام", value: "\(store.streak) يوم", color: ST.flame)
                        StatCard(icon: "scope", title: "ضربات كاملة", value: "\(p.perfectCleared)/\(Gen.perfectCount)", color: ST.gold)
                        StatCard(icon: "circle.slash", title: "مظلمة فجّرتها", value: "\(p.badPops)", color: ST.red)
                    }
                    galaxyBars(p)
                    HStack {
                        CoinView(size: 20)
                        Text("كوينز جمعتها بالمجموع").font(rnd(13, .heavy)).foregroundStyle(ST.tx2)
                        Spacer()
                        Text("\(p.coinsEarned)").font(rnd(18, .black)).foregroundStyle(ST.gold)
                    }
                    .padding(14).card(ST.s1.opacity(0.88), 18)
                }
                .padding(.bottom, 30)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private func galaxyBars(_ p: Career) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("نجوم المجرّات").font(rnd(15, .heavy)).foregroundStyle(Color.white)
            ForEach(0..<Gen.galaxyCount, id: \.self) { g in
                let v = p.galaxyStars(g)
                HStack(spacing: 10) {
                    Text(Gen.galaxyNames[g]).font(rnd(12, .heavy)).foregroundStyle(ST.tx2).frame(width: 96, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule().fill(ST.galaxyColor(g)).frame(width: max(4, geo.size.width * CGFloat(v) / 30))
                        }
                    }
                    .frame(height: 8)
                    .environment(\.layoutDirection, .leftToRight)
                    Text("\(v)").font(rnd(12, .heavy)).foregroundStyle(Color.white).frame(width: 24)
                }
            }
        }
        .padding(16)
        .card(ST.s1.opacity(0.88), 22)
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .black)).foregroundStyle(color)
            Text(value).font(rnd(24, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(rnd(12, .medium)).foregroundStyle(ST.tx3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(ST.s1.opacity(0.88), 20)
    }
}

// MARK: الإعدادات

struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    let back: () -> Void
    let replayIntro: () -> Void
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 14) {
            SubHeader(title: "الإعدادات", back: back)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    VStack(spacing: 0) {
                        toggleRow("speaker.wave.2.fill", "الأصوات", "نوتات تصعد مع كلّ حلقة", $store.sound)
                        Divider().overlay(Color.white.opacity(0.06))
                        toggleRow("iphone.radiowaves.left.and.right", "الاهتزاز", "تحسّ بكلّ انفجار", $store.haptics)
                        Divider().overlay(Color.white.opacity(0.06))
                        toggleRow("waveform.path", "هزّة شاشة هادئة", "تقلّل اهتزاز الشاشة", $store.calmShake)
                    }
                    .card(ST.s1.opacity(0.9), 20)
                    Button { Haptic.tap(); replayIntro() } label: {
                        rowLabel("questionmark.circle.fill", "شلون ألعب؟", ST.cyan)
                    }
                    .buttonStyle(Press())
                    guide
                    Button { confirmReset = true } label: {
                        rowLabel("trash.fill", "صفّر التقدّم", ST.red)
                    }
                    .buttonStyle(Press())
                    Text("شرارة · نسخة 1.0\nكلّ شي محفوظ على جهازك فقط").font(rnd(11.5)).foregroundStyle(ST.tx3)
                        .multilineTextAlignment(.center).padding(.top, 6)
                }
                .padding(.bottom, 30)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .alert("تصفّر كلّ شي؟", isPresented: $confirmReset) {
            Button("صفّر", role: .destructive) { store.reset(); Haptic.thud() }
            Button("لا", role: .cancel) {}
        } message: {
            Text("راح تنمسح النجوم والكوينز والأشكال اللي اشتريتها. ما يرجع.")
        }
    }

    private func toggleRow(_ icon: String, _ t: String, _ n: String, _ b: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(ST.spark).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text(n).font(rnd(11.5)).foregroundStyle(ST.tx3)
            }
            Spacer()
            Toggle("", isOn: b).labelsHidden().tint(ST.spark)
        }
        .padding(14)
    }

    private func rowLabel(_ icon: String, _ t: String, _ c: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(c).frame(width: 30)
            Text(t).font(rnd(15, .heavy)).foregroundStyle(Color.white)
            Spacer()
            Image(systemName: "chevron.left").font(.system(size: 12, weight: .black)).foregroundStyle(ST.tx3)
        }
        .padding(14)
        .card(ST.s1.opacity(0.9), 18)
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("أنواع الكرات").font(rnd(15, .heavy)).foregroundStyle(Color.white)
            ForEach(OrbKind.allCases, id: \.self) { k in
                HStack(spacing: 12) {
                    OrbIcon(kind: k, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.name).font(rnd(14, .heavy)).foregroundStyle(Look.color(k))
                        Text(k.note).font(rnd(12)).foregroundStyle(ST.tx2)
                    }
                    Spacer()
                    Text(k == .bad ? "\(k.points)" : "+\(k.points)").font(rnd(12, .heavy)).foregroundStyle(k == .bad ? ST.red : ST.tx3)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
        .padding(16)
        .card(ST.s1.opacity(0.9), 22)
    }
}

// MARK: التعريف أوّل مرّة

struct OnboardingView: View {
    let done: () -> Void
    @State private var page = 0

    private let pages: [(String, String)] = [
        ("شرارة وحدة بس", "كلّ مرحلة تعطيك شرارة وحدة. دوس على الشاشة وصوّب، وفلّت حتى تنفجر."),
        ("السلسلة هي اللعبة", "أيّ كرة تلمسها الحلقة تنفجر وتطلق حلقتها. كلّ ما طالت السلسلة يكبر المضاعف ويبطئ الزمن."),
        ("اعرف كراتك", "العملاقة انفجارها أكبر، المدرّعة تحتاج ضربتين، المشطورة تطلق شرارات، والمظلمة تنقص من رصيدك — ابتعد عنها."),
    ]

    var body: some View {
        ZStack {
            SpaceBackdrop(back: Catalog.back("nebula"))
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button("تخطّي") { done() }.font(rnd(14, .heavy)).foregroundStyle(ST.tx3)
                }
                Spacer()
                IntroArt(page: page)
                    .frame(height: 260)
                VStack(spacing: 10) {
                    Text(pages[page].0).font(rnd(30, .black)).foregroundStyle(ST.hot)
                    Text(pages[page].1).font(rnd(16, .medium)).foregroundStyle(ST.tx2)
                        .multilineTextAlignment(.center).lineSpacing(4)
                }
                .id(page)
                .transition(.opacity)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule().fill(i == page ? ST.spark : Color.white.opacity(0.2)).frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                Button {
                    Haptic.tap()
                    if page < pages.count - 1 { withAnimation(.easeOut(duration: 0.25)) { page += 1 } } else { done() }
                } label: {
                    Text(page < pages.count - 1 ? "التالي" : "يلّا نبدي").font(rnd(18, .black)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(ST.hot, in: Capsule())
                        .shadow(color: ST.flame.opacity(0.5), radius: 14, y: 4)
                }
                .buttonStyle(Press())
            }
            .padding(24)
        }
    }
}

/// رسوم متحرّكة للتعريف
struct IntroArt: View {
    let page: Int
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 40, paused: Shot.on)) { tl in
            Canvas { g, size in
                let t = Shot.on ? 0.9 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
                draw(g, size, t)
            }
        }
    }

    private func draw(_ g: GraphicsContext, _ size: CGSize, _ t: Double) {
        var add = g
        add.blendMode = .plusLighter
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        switch page {
        case 0:
            let f = (t * 0.5).truncatingRemainder(dividingBy: 1)
            let r = CGFloat(f) * 110
            add.stroke(Painter.circle(c, r), with: .color(ST.spark.opacity(1 - f)), lineWidth: 3)
            add.fill(Painter.circle(c, r), with: .color(ST.spark.opacity(0.12 * (1 - f))))
            Painter.glow(add, c, 40, Color.white, 0.8)
            let fingerY = c.y + 70 + CGFloat(sin(t * 4)) * 4
            Painter.glow(add, CGPoint(x: c.x + 30, y: fingerY), 24, ST.cyan, 0.5)
            g.draw(Text("👆").font(.system(size: 44)), at: CGPoint(x: c.x + 34, y: fingerY + 6), anchor: .center)
        case 1:
            let f = (t * 0.35).truncatingRemainder(dividingBy: 1)
            for k in 0..<7 {
                let a = Double(k) * 0.9
                let d = CGFloat(18 + k * 16)
                let p = CGPoint(x: c.x + CGFloat(cos(a)) * d, y: c.y + CGFloat(sin(a)) * d * 0.8)
                let start = Double(k) / 8
                if f > start {
                    let lf = min(1, (f - start) * 4)
                    add.stroke(Painter.circle(p, CGFloat(lf) * 34), with: .color(Look.color(.normal, 1 - lf)), lineWidth: 2.5)
                } else {
                    var o = Orb(id: k, kind: .normal, pos: P(0, 0))
                    o.phase = a
                    Painter.orb(g, o, at: p, s: 1.2, t: t)
                }
            }
            let n = min(7, Int(f * 8))
            g.draw(Text("\(n)").font(rnd(48, .black)).foregroundColor(.white), at: CGPoint(x: c.x, y: 26), anchor: .center)
        default:
            let kinds: [OrbKind] = [.big, .shield, .splitter, .magnet, .timer, .bad]
            for (i, k) in kinds.enumerated() {
                let a = Double(i) / 6 * 2 * Double.pi + t * 0.3
                let p = CGPoint(x: c.x + CGFloat(cos(a)) * 95, y: c.y + CGFloat(sin(a)) * 95)
                var o = Orb(id: i, kind: k, pos: P(0, 0), vel: P(30, 10))
                o.phase = a
                Painter.orb(g, o, at: p, s: 1.5, t: t)
            }
            Painter.glow(add, c, 50, ST.spark, 0.5)
        }
    }
}
