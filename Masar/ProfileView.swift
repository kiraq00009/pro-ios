import SwiftUI

/// إنجازاتي: المستوى والرتبة، هدف الأسبوع، المجاميع، الشارات، والأرقام القياسيّة
struct ProfileView: View {
    @EnvironmentObject var store: MasarStore
    @EnvironmentObject var tracker: Tracker
    @State private var settings = false
    @State private var picked: Badge? = nil
    @State private var animate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                LevelCard(animate: animate)
                WeekCard(animate: animate)
                totals
                badges
                RecordsCard()
            }
            .padding(18)
        }
        .background(MBackdrop())
        .sheet(isPresented: $settings) {
            SettingsView { settings = false }
                .environmentObject(store).environmentObject(tracker)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .sheet(item: $picked) { b in
            BadgeSheet(badge: b, earned: store.earnedIDs.contains(b.id))
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
                .presentationDetents([.medium])
        }
        .onAppear {
            if Shot.on { animate = true } else { withAnimation(.easeOut(duration: 1.1).delay(0.15)) { animate = true } }
            if Shot.name == "settings" { settings = true }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("إنجازاتي").font(rnd(34, .black)).foregroundStyle(Color.white)
                Text("\(store.sessions.count) جولة · سلسلة \(store.streak.current) يوم 🔥").font(rnd(13)).foregroundStyle(MT.tx3)
            }
            Spacer()
            Button { Haptic.tap(); settings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.white)
                    .frame(width: 44, height: 44).background(MT.s2, in: Circle())
            }.buttonStyle(Press())
        }.padding(.top, 8)
    }

    private var totals: some View {
        let cols = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
        let hours = store.totalTime / 3600
        return LazyVGrid(columns: cols, spacing: 9) {
            StatTile(value: Fmt.km1(store.totalDistance), label: "كم بالمجموع", icon: "point.topleft.down.curvedto.point.bottomright.up", color: MT.mint)
            StatTile(value: String(format: "%.1f", hours), label: "ساعة حركة", icon: "timer", color: MT.cyan)
            StatTile(value: Fmt.int(store.totalCalories), label: "سعرة", icon: "flame.fill", color: MT.coral)
            StatTile(value: "\(store.streak.best)", label: "أطول سلسلة", icon: "flame", color: MT.gold)
            StatTile(value: Fmt.area(store.areaKm2), label: "كم² منطقة", icon: "crown.fill", color: MT.violet)
            StatTile(value: "\(store.sessions.reduce(0) { $0 + $1.loops })", label: "دائرة مقفولة", icon: "lasso", color: MT.mint)
        }
    }

    private var badges: some View {
        let earned = store.earnedIDs
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: "الشارات", icon: "seal.fill")
                Text("\(earned.count)/\(Badges.all.count)").font(rnd(14, .black)).foregroundStyle(MT.gold).environment(\.layoutDirection, .leftToRight)
            }
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(Badges.all) { b in
                    Button { Haptic.tap(); picked = b } label: {
                        VStack(spacing: 6) {
                            BadgeIcon(badge: b, earned: earned.contains(b.id), size: 60)
                            Text(b.title).font(rnd(10.5, .heavy)).foregroundStyle(earned.contains(b.id) ? Color.white : MT.tx3)
                                .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8).frame(height: 28)
                        }
                    }.buttonStyle(Press())
                }
            }
        }.padding(16).card(MT.s1, 22)
    }
}

struct LevelCard: View {
    @EnvironmentObject var store: MasarStore
    let animate: Bool

    var body: some View {
        let lv = store.level
        let p = Double(lv.into) / Double(max(1, lv.need))
        return HStack(spacing: 18) {
            ZStack {
                MRing(progress: animate ? p : 0, width: 11, colors: [MT.mint, MT.cyan, MT.violet, MT.mint])
                VStack(spacing: -2) {
                    Text("\(lv.level)").font(.system(size: 38, weight: .black, design: .rounded)).foregroundStyle(Color.white)
                    Text("مستوى").font(rnd(11, .bold)).foregroundStyle(MT.tx3)
                }
            }.frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 6) {
                Text(Levels.rank(lv.level)).font(rnd(22, .black)).foregroundStyle(MT.brand)
                Text("\(lv.into) / \(lv.need) نقطة للمستوى الجاي").font(rnd(12.5, .bold)).foregroundStyle(MT.tx2)
                    .environment(\.layoutDirection, .rightToLeft)
                Text("كلّ كم = 10 نقاط · كلّ خليّة جديدة = 2 · كلّ دائرة = 25").font(rnd(11)).foregroundStyle(MT.tx3).lineSpacing(2)
                let next = Levels.ranks.firstIndex(of: Levels.rank(lv.level)).map { $0 + 1 } ?? 0
                if next < Levels.ranks.count {
                    Text("الرتبة الجاية: \(Levels.ranks[next]) (مستوى \(next * 5 + 1))").font(rnd(11.5, .heavy)).foregroundStyle(MT.gold)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [MT.mint.opacity(0.14), MT.violet.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(MT.mint.opacity(0.25)))
    }
}

struct WeekCard: View {
    @EnvironmentObject var store: MasarStore
    let animate: Bool
    private let names = ["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"]

    var body: some View {
        let days = store.weekDays
        let km = store.weekKm
        let goal = max(1, store.weeklyGoal)
        let mx = max(1, days.max() ?? 1)
        let todayIdx = store.today - Days.weekStart(store.today, firstWeekday: store.firstWeekday)
        return HStack(spacing: 16) {
            ZStack {
                MRing(progress: animate ? km / goal : 0, width: 10, colors: [MT.gold, MT.coral, MT.gold])
                VStack(spacing: 0) {
                    Text(String(format: "%.1f", km)).font(rnd(22, .black)).foregroundStyle(Color.white)
                    Text("من \(Int(goal)) كم").font(rnd(10.5, .bold)).foregroundStyle(MT.tx3)
                }
            }.frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("هدف الأسبوع").font(rnd(16, .black)).foregroundStyle(Color.white)
                    Spacer()
                    if km >= goal { Text("تحقّق ✓").font(rnd(12, .black)).foregroundStyle(MT.gold) }
                }
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        bar(i, days[i], mx, i == todayIdx)
                    }
                }.frame(height: 62)
            }
        }
        .padding(16).card(MT.s1, 24, stroke: MT.gold.opacity(0.2))
    }

    private func bar(_ i: Int, _ v: Double, _ mx: Double, _ today: Bool) -> some View {
        let wd = (store.firstWeekday + i) % 7
        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(v > 0 ? AnyShapeStyle(MT.hot) : AnyShapeStyle(Color.white.opacity(0.08)))
                .frame(height: max(4, CGFloat(animate ? v / mx : 0) * 44))
            Text(String(names[wd].prefix(1))).font(rnd(10, today ? .black : .bold)).foregroundStyle(today ? MT.gold : MT.tx3)
        }.frame(maxWidth: .infinity)
    }
}

struct RecordsCard: View {
    @EnvironmentObject var store: MasarStore
    var body: some View {
        let r = store.records
        return VStack(alignment: .leading, spacing: 4) {
            SectionTitle(text: "أرقامك القياسيّة", icon: "trophy.fill").padding(.bottom, 6)
            row("ruler", "أطول جولة", r.longest > 0 ? "\(Fmt.km(r.longest)) كم" : "—")
            row("timer", "أطول وقت", r.longestTime > 0 ? Stats.durationText(r.longestTime) : "—")
            row("hare.fill", "أسرع كيلو", r.best1k.map { Stats.paceText($0) } ?? "—")
            row("5.circle", "أسرع 5 كم", r.best5k.map { Stats.durationText($0) } ?? "—")
            row("bicycle", "أعلى معدّل درّاجة", r.fastestKmh > 0 ? String(format: "%.1f كم/س", r.fastestKmh) : "—")
            row("hexagon.fill", "أكثر خلايا بجولة", r.mostCells > 0 ? "\(r.mostCells)" : "—")
            row("lasso", "أكبر دائرة", r.biggestLoop > 0 ? String(format: "%.2f كم²", r.biggestLoop / 1e6) : "—")
        }.padding(16).card(MT.s1, 22)
    }

    private func row(_ icon: String, _ t: String, _ v: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(MT.mint).frame(width: 24)
            Text(t).font(rnd(14, .bold)).foregroundStyle(MT.tx2)
            Spacer()
            Text(v).font(rnd(15, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
        }.padding(.vertical, 7)
    }
}

struct BadgeIcon: View {
    let badge: Badge
    let earned: Bool
    var size: CGFloat = 60

    var body: some View {
        let c = MT.tone(badge.tone)
        return ZStack {
            HexShape().fill(earned ? AnyShapeStyle(LinearGradient(colors: [c, c.opacity(0.55)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(MT.s2))
            HexShape().stroke(earned ? Color.white.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1.5)
            Image(systemName: earned ? badge.icon : "lock.fill").font(.system(size: size * 0.34, weight: .black))
                .foregroundStyle(earned ? MT.ink : MT.tx3)
        }
        .frame(width: size, height: size * 1.1)
        .shadow(color: earned ? c.opacity(0.5) : Color.clear, radius: 10)
    }
}

struct BadgeSheet: View {
    let badge: Badge
    let earned: Bool
    var body: some View {
        VStack(spacing: 16) {
            BadgeIcon(badge: badge, earned: earned, size: 110).padding(.top, 30)
            Text(badge.title).font(rnd(26, .black)).foregroundStyle(Color.white)
            Text(badge.desc).font(rnd(15)).foregroundStyle(MT.tx2).multilineTextAlignment(.center)
            Text(earned ? "حصلت عليها ✓" : "ما زالت مقفلة — تقدر عليها!").font(rnd(14, .black)).foregroundStyle(earned ? MT.mint : MT.gold)
                .padding(.horizontal, 16).frame(height: 36).background(MT.s2, in: Capsule())
            Spacer()
        }.frame(maxWidth: .infinity).padding(20).background(MBackdrop())
    }
}
