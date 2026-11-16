import SwiftUI

struct HomeView: View {
    @EnvironmentObject var prog: Prog
    @State private var launch: Launch? = nil
    @State private var sheet: HomeSheet? = nil
    @State private var worlds = false

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    hero
                    campaignCard
                    HStack(spacing: 12) {
                        modeCard("بلا نهاية", "3 قلوب ووقت يقصر", "infinity", SQ.cyan, prog.d.bestEndless > 0 ? "أفضل \(prog.d.bestEndless)" : "جديد") { start(.endless) }
                        modeCard("تحدّي اليوم", "5 جولات — نفسها للكلّ", "calendar", SQ.gold, prog.dailyToday.map { "اليوم \($0)" } ?? "جاهز!") { start(.daily) }
                    }
                    zenCard
                    HStack(spacing: 12) {
                        smallTile("المتجر", "شفرات وألوان", "paintpalette.fill", SQ.violet) { sheet = .shop }
                        smallTile("إحصائيّاتك", "دقّتك بالأرقام", "chart.bar.fill", SQ.mint) { sheet = .stats }
                    }
                    Text("يشتغل كامل بلا إنترنت · تقدّمك ينحفظ لحاله").font(rnd(11.5)).foregroundStyle(SQ.tx3).frame(maxWidth: .infinity).padding(.top, 4)
                }
                .padding(18)
            }
            .fullScreenCover(isPresented: $worlds) {
                WorldsView { worlds = false }.environmentObject(prog)
                    .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
            }
        }
        .fullScreenCover(item: $launch) { l in
            PlayHost(mode: l.mode) { launch = nil }.environmentObject(prog)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .sheet(item: $sheet) { s in
            sheetView(s).environmentObject(prog)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .onAppear {
            Synth.shared.enabled = prog.d.sound
            switch Shot.name {
            case "play": launch = Launch(mode: .campaign(30))
            case "perfect": launch = Launch(mode: .campaign(14))
            case "result": launch = Launch(mode: .campaign(8))
            case "worlds": worlds = true
            case "shop": sheet = .shop
            case "stats": sheet = .stats
            default:
                if !Shot.on && !prog.d.seenIntro { sheet = .intro }
            }
        }
    }

    @ViewBuilder private func sheetView(_ s: HomeSheet) -> some View {
        switch s {
        case .shop: ShopView { sheet = nil }
        case .stats: StatsView { sheet = nil }
        case .settings: SettingsView(intro: { sheet = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { sheet = .intro } }) { sheet = nil }
        case .intro: IntroView { var d = prog.d; d.seenIntro = true; prog.d = d; sheet = nil }
        }
    }

    private func start(_ m: PlayMode) {
        Haptic.tap()
        Synth.shared.start()
        launch = Launch(mode: m)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("شقّ").font(rnd(46, .black)).foregroundStyle(SQ.hot)
                    .shadow(color: SQ.coral.opacity(0.45), radius: 18)
                Text("قطعة وحدة. نسبة بالضبط.").font(rnd(13.5, .bold)).foregroundStyle(SQ.tx2)
            }
            Spacer()
            Button { sheet = .shop } label: {
                HStack(spacing: 6) {
                    CoinDot(size: 20)
                    Text("\(prog.d.coins)").font(rnd(16, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, 12).frame(height: 42).background(SQ.s2, in: Capsule())
            }.buttonStyle(Press())
            Button { sheet = .settings } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.white)
                    .frame(width: 42, height: 42).background(SQ.s2, in: Circle())
            }.buttonStyle(Press())
        }
    }

    private var hero: some View {
        ZStack {
            LogoSplit(size: 210)
            VStack {
                HStack {
                    Spacer()
                    Text("37.0%").font(rnd(15, .black)).foregroundStyle(SQ.gold).environment(\.layoutDirection, .leftToRight)
                        .padding(.horizontal, 10).frame(height: 30).background(Color.black.opacity(0.4), in: Capsule())
                        .overlay(Capsule().stroke(SQ.gold.opacity(0.4)))
                }
                Spacer()
                HStack {
                    Text("مثالي!").font(rnd(20, .black)).foregroundStyle(SQ.gold).shadow(color: SQ.gold.opacity(0.7), radius: 10)
                    Spacer()
                }
            }.padding(.horizontal, 30).padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity).frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [SQ.s1, Color(red: 0.06, green: 0.04, blue: 0.11)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(SQ.coral.opacity(0.18)))
        .allowsHitTesting(false)
    }

    private var campaignCard: some View {
        let nx = prog.nextLevel
        let w = nx / Levels.perWorld
        let info = Levels.worlds[max(0, min(Levels.worldCount - 1, w))]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "map.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(SQ.coral)
                Text("الحملة").font(rnd(20, .black)).foregroundStyle(Color.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 12, weight: .black)).foregroundStyle(SQ.gold)
                    Text("\(prog.totalStars)/\(Levels.total * 3)").font(rnd(13.5, .black)).foregroundStyle(SQ.tx2).environment(\.layoutDirection, .leftToRight)
                }
            }
            HStack(spacing: 6) {
                ForEach(0..<Levels.worldCount, id: \.self) { i in
                    let st = prog.worldStars(i)
                    VStack(spacing: 4) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                            .overlay(alignment: .leading) {
                                GeometryReader { g in
                                    Capsule().fill(SQ.world(i)).frame(width: g.size.width * CGFloat(st) / 30)
                                }
                            }
                            .environment(\.layoutDirection, .leftToRight)
                        Image(systemName: prog.worldOpen(i) ? Levels.worlds[i].icon : "lock.fill").font(.system(size: 10, weight: .bold))
                            .foregroundStyle(prog.worldOpen(i) ? SQ.world(i) : SQ.tx3)
                    }
                }
            }
            Text("العالم \(w + 1) · \(info.name) — \(info.note)").font(rnd(12.5)).foregroundStyle(SQ.tx3)
            HStack(spacing: 10) {
                Button { start(.campaign(nx)) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill").font(.system(size: 15, weight: .black))
                        Text("كمّل · المرحلة \(nx + 1)").font(rnd(17, .black))
                    }
                    .foregroundStyle(Color.black.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 54)
                    .background(SQ.hot, in: Capsule()).shadow(color: SQ.coral.opacity(0.35), radius: 14, y: 6)
                }.buttonStyle(Press())
                Button { Haptic.tap(); worlds = true } label: {
                    Image(systemName: "square.grid.3x3.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.white)
                        .frame(width: 54, height: 54).background(SQ.s2, in: Circle())
                }.buttonStyle(Press())
            }
        }
        .padding(16).card(SQ.s1, 26, stroke: SQ.coral.opacity(0.2))
    }

    private func modeCard(_ t: String, _ s: String, _ icon: String, _ c: Color, _ badge: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.system(size: 18, weight: .black)).foregroundStyle(c)
                        .frame(width: 42, height: 42).background(c.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Spacer()
                    Text(badge).font(rnd(11, .black)).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 8).frame(height: 24).background(c.opacity(0.12), in: Capsule())
                }
                Text(t).font(rnd(17, .black)).foregroundStyle(Color.white)
                Text(s).font(rnd(11.5)).foregroundStyle(SQ.tx3).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(SQ.s1, 22, stroke: c.opacity(0.22))
        }.buttonStyle(Press())
    }

    private var zenCard: some View {
        Button { start(.zen) } label: {
            HStack(spacing: 14) {
                Image(systemName: "leaf.fill").font(.system(size: 19, weight: .bold)).foregroundStyle(SQ.mint)
                    .frame(width: 48, height: 48).background(SQ.mint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("زِن").font(rnd(17, .black)).foregroundStyle(Color.white)
                    Text("بلا وقت ولا نقاط — بس أنت والشفرة").font(rnd(12)).foregroundStyle(SQ.tx3)
                }
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .black)).foregroundStyle(SQ.tx3)
            }.padding(14).card(SQ.s1, 22, stroke: SQ.mint.opacity(0.18))
        }.buttonStyle(Press())
    }

    private func smallTile(_ t: String, _ s: String, _ icon: String, _ c: Color, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); act() } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(c)
                VStack(alignment: .leading, spacing: 1) {
                    Text(t).font(rnd(14.5, .heavy)).foregroundStyle(Color.white)
                    Text(s).font(rnd(10.5)).foregroundStyle(SQ.tx3)
                }
                Spacer(minLength: 0)
            }.padding(13).frame(maxWidth: .infinity).card(SQ.s1, 18, stroke: c.opacity(0.18))
        }.buttonStyle(Press())
    }
}
