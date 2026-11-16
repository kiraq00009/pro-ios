import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: GameStore
    let go: (Screen) -> Void
    let play: (GameReq) -> Void
    @State private var pickedKind: OrbKind? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                topRow
                TitleMark()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                campaignCard
                modesGrid
                bottomRow
                guideStrip
                Text("يشتغل بلا إنترنت · كلّ الأصوات تتولّد بالجهاز").font(rnd(11.5)).foregroundStyle(ST.tx3)
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(18)
        }
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            CoinPill(coins: store.p.coins)
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.system(size: 12, weight: .black)).foregroundStyle(ST.gold)
                Text("\(store.p.totalStars)").font(rnd(14, .heavy)).foregroundStyle(Color.white)
            }
            .padding(.horizontal, 12).frame(height: 34)
            .background(Color.white.opacity(0.07), in: Capsule())
            Spacer()
            Button { Haptic.tap(); go(.settings) } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(ST.tx2)
                    .frame(width: 38, height: 38).background(Color.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(Press())
        }
    }

    private var campaignCard: some View {
        let cur = store.p.current
        let g = cur / Gen.perGalaxy
        let gc = ST.galaxyColor(g)
        return Button { Haptic.thud(); play(GameReq(mode: .campaign, index: cur)) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("الحملة · المجرّة \(g + 1)").font(rnd(12, .heavy)).foregroundStyle(gc)
                        Text(Gen.galaxyNames[g]).font(rnd(25, .black)).foregroundStyle(Color.white)
                        Text("المرحلة \(cur % Gen.perGalaxy + 1) من ١٠").font(rnd(13, .medium)).foregroundStyle(ST.tx2)
                    }
                    Spacer()
                    OrbIcon(kind: Gen.galaxyIntro[g] == .normal ? .big : Gen.galaxyIntro[g], size: 64)
                }
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 16, weight: .black))
                    Text("العب").font(rnd(19, .black))
                    Spacer()
                    Text("\(store.p.galaxyStars(g))/٣٠").font(rnd(13, .heavy)).opacity(0.85)
                    Image(systemName: "star.fill").font(.system(size: 12, weight: .black))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 18).frame(height: 54)
                .background(ST.hot, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: ST.flame.opacity(0.45), radius: 16, y: 6)
            }
            .padding(18)
            .background(
                ZStack {
                    ST.s1.opacity(0.9)
                    RadialGradient(colors: [gc.opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(gc.opacity(0.35)))
        }
        .buttonStyle(Press())
    }

    private var modesGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            ModeTile(icon: "infinity", title: "بلا نهاية", note: "أحسن: \(store.p.endlessRounds) جولة", color: ST.cyan) {
                play(GameReq(mode: .endless, index: 0, runSeed: UInt64.random(in: 1...UInt64(Int32.max))))
            }
            ModeTile(icon: "calendar", title: "تحدّي اليوم",
                     note: store.dailyDoneToday ? "خلصته ✓ · سلسلة \(store.streak)" : (store.streak > 0 ? "سلسلة \(store.streak) يوم 🔥" : "+١٢٠ كوين"),
                     color: ST.pink, badge: !store.dailyDoneToday) {
                play(GameReq(mode: .daily, index: store.today))
            }
            ModeTile(icon: "scope", title: "الضربة الكاملة", note: "\(store.p.perfectCleared)/\(Gen.perfectCount) تحدّي", color: ST.gold) {
                play(GameReq(mode: .perfect, index: nextPerfect))
            }
            ModeTile(icon: "map.fill", title: "المجرّات", note: "\(store.p.totalStars)/٢٤٠ نجمة", color: ST.violet) {
                go(.levels)
            }
        }
    }

    private var nextPerfect: Int {
        for i in 0..<Gen.perfectCount where !store.p.perfect[i] && store.p.perfectUnlocked(i) { return i }
        return 0
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            WideTile(icon: "sparkles", title: "المتجر", note: "شرارات وخلفيّات", color: ST.spark) { go(.shop) }
            WideTile(icon: "chart.bar.fill", title: "إحصائيّاتي", note: "أطول سلسلة \(store.p.longest)", color: ST.lime) { go(.stats) }
        }
    }

    private var guideStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("دليل الكرات").font(rnd(15, .heavy)).foregroundStyle(Color.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(OrbKind.allCases, id: \.self) { k in
                        Button { Haptic.tap(); withAnimation(.easeOut(duration: 0.2)) { pickedKind = pickedKind == k ? nil : k } } label: {
                            VStack(spacing: 6) {
                                OrbIcon(kind: k, size: 46)
                                Text(k.name).font(rnd(11.5, .heavy)).foregroundStyle(pickedKind == k ? Look.color(k) : ST.tx2)
                            }
                            .frame(width: 74, height: 86)
                            .card(pickedKind == k ? Look.color(k, 0.14) : ST.s1.opacity(0.85), 18, stroke: pickedKind == k ? Look.color(k, 0.5) : Color.white.opacity(0.07))
                        }
                        .buttonStyle(Press())
                    }
                }
            }
            if let k = pickedKind {
                HStack(spacing: 10) {
                    Circle().fill(Look.color(k)).frame(width: 8, height: 8)
                    Text("\(k.name): \(k.note)").font(rnd(13, .medium)).foregroundStyle(ST.tx2)
                }
                .transition(.opacity)
            }
        }
    }
}

/// شعار «شرارة» بتوهّج متحرّك
struct TitleMark: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: Shot.on)) { tl in
            let t = Shot.on ? 1.2 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
            ZStack {
                Canvas { g, size in
                    var add = g
                    add.blendMode = .plusLighter
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    for k in 0..<3 {
                        let f = (t * 0.45 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                        let r = CGFloat(30 + f * 120)
                        add.stroke(Painter.circle(c, r), with: .color(ST.spark.opacity(0.45 * (1 - f))), lineWidth: CGFloat(3 * (1 - f) + 0.5))
                    }
                    Painter.glow(add, c, 120, ST.flame, 0.35)
                    Painter.glow(add, c, 50, Color.white, 0.25)
                }
                VStack(spacing: 4) {
                    Text("شرارة").font(rnd(64, .black)).foregroundStyle(ST.hot)
                        .shadow(color: ST.flame.opacity(0.7), radius: 18)
                    Text("شرارة وحدة… وسلسلة ما تخلص").font(rnd(14, .heavy)).foregroundStyle(ST.tx2)
                }
            }
            .frame(height: 170)
        }
    }
}

struct CoinPill: View {
    let coins: Int
    var body: some View {
        HStack(spacing: 6) {
            CoinView(size: 18)
            Text("\(coins)").font(rnd(14, .heavy)).foregroundStyle(Color.white)
        }
        .padding(.horizontal, 12).frame(height: 34)
        .background(Color.white.opacity(0.07), in: Capsule())
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct ModeTile: View {
    let icon: String
    let title: String
    let note: String
    let color: Color
    var badge = false
    let action: () -> Void

    var body: some View {
        Button { Haptic.tap(); action() } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon).font(.system(size: 19, weight: .black)).foregroundStyle(color)
                        .frame(width: 44, height: 44)
                        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Spacer()
                    if badge { Circle().fill(ST.pink).frame(width: 9, height: 9).shadow(color: ST.pink, radius: 5) }
                }
                Text(title).font(rnd(16.5, .heavy)).foregroundStyle(Color.white)
                Text(note).font(rnd(12, .medium)).foregroundStyle(ST.tx3).lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(ST.s1.opacity(0.88), 22)
        }
        .buttonStyle(Press())
    }
}

struct WideTile: View {
    let icon: String
    let title: String
    let note: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button { Haptic.tap(); action() } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 16, weight: .black)).foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(rnd(14.5, .heavy)).foregroundStyle(Color.white)
                    Text(note).font(rnd(11, .medium)).foregroundStyle(ST.tx3).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .card(ST.s1.opacity(0.88), 20)
        }
        .buttonStyle(Press())
    }
}

/// رأس الشاشات الفرعيّة
struct SubHeader: View {
    let title: String
    let back: () -> Void
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button { Haptic.tap(); back() } label: {
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 40, height: 40).background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(Press())
            Text(title).font(rnd(26, .black)).foregroundStyle(Color.white)
            Spacer()
            if let t = trailing { t }
        }
    }
}
