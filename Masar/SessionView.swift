import SwiftUI

/// خلاصة جولة: خريطة المسار والخلايا، الأرقام، أقسام الكيلو، والشارات الجديدة
struct SessionView: View {
    @EnvironmentObject var store: MasarStore
    let session: Session
    var fresh: Bool = false
    let close: () -> Void
    @State private var confirmDelete = false
    @State private var appear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                mapCard
                big
                tiles
                if !session.splits.isEmpty { SplitsCard(splits: session.splits, best: session.splits.min() ?? 0) }
                if fresh && !store.justEarned.isEmpty { earnedCard }
                prCard
                Button { confirmDelete = true } label: {
                    Label("احذف الجولة", systemImage: "trash").font(rnd(14, .heavy)).foregroundStyle(MT.red)
                        .frame(maxWidth: .infinity).frame(height: 48).card(MT.s1, 16, stroke: MT.red.opacity(0.25))
                }.buttonStyle(Press())
            }
            .padding(18)
        }
        .background(MBackdrop())
        .confirmationDialog("نحذف الجولة؟", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("احذف", role: .destructive) { store.delete(session.id); close() }
            Button("لا", role: .cancel) {}
        } message: {
            Text("إذا كانت هذه آخر جولة، ترجع الخلايا التي أخذتها فيها كما كانت.")
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appear = true } }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(fresh ? "أحسنت! 🎉" : Fmt.partOfDay(session.start, tz: store.tz)).font(rnd(28, .black)).foregroundStyle(Color.white)
                Text("\(Fmt.day(session.start)) · \(Fmt.time(session.start))").font(rnd(13)).foregroundStyle(MT.tx3)
            }
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 40, height: 40).background(MT.s2, in: Circle())
            }.buttonStyle(Press())
        }
        .padding(.top, 8)
    }

    private var mapCard: some View {
        MasarMap(routes: session.route.map { seg in seg.map { $0.cl } }, hexes: store.hexes(for: session),
                 hexKey: session.id.hashValue, routeKey: session.id.hashValue, fitKey: 1, interactive: true, bottomPad: 30,
                 fitToRoute: false, fallback: (session.route.first?.first ?? Demo.center).cl)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(MT.mint.opacity(0.25)))
            .overlay(alignment: .topLeading) {
                Label(session.activity.title, systemImage: session.activity.icon)
                    .font(rnd(13, .heavy)).foregroundStyle(MT.ink).padding(.horizontal, 12).frame(height: 32)
                    .background(MT.color(session.activity), in: Capsule()).padding(12)
            }
    }

    private var big: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(Fmt.km(session.distance)).font(.system(size: 64, weight: .black, design: .rounded)).foregroundStyle(MT.brand)
            Text("كم").font(rnd(20, .heavy)).foregroundStyle(MT.tx3)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(session.newCells)").font(rnd(28, .black)).foregroundStyle(MT.gold)
                Text("خليّة جديدة").font(rnd(12, .bold)).foregroundStyle(MT.tx3)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .scaleEffect(appear ? 1 : 0.92).opacity(appear ? 1 : 0)
    }

    private var tiles: some View {
        let cols = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
        return LazyVGrid(columns: cols, spacing: 9) {
            StatTile(value: Stats.durationText(session.active), label: "الوقت", icon: "timer", color: MT.cyan)
            if session.activity == .cycle {
                StatTile(value: String(format: "%.1f", session.kmh), label: "كم/ساعة", icon: "speedometer", color: MT.mint)
            } else {
                StatTile(value: Stats.paceText(session.pace), label: "دقيقة/كم", icon: "speedometer", color: MT.mint)
            }
            StatTile(value: Fmt.int(session.calories), label: "سعرة", icon: "flame.fill", color: MT.coral)
            StatTile(value: Fmt.int(session.elevGain), label: "م صعود", icon: "mountain.2.fill", color: MT.violet)
            StatTile(value: "\(session.loops)", label: "دوائر مقفولة", icon: "lasso", color: MT.gold)
            StatTile(value: "\(session.cells.count)", label: "خليّة عبرتها", icon: "hexagon", color: MT.cyan)
        }
    }

    private var earnedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "شارات جديدة", icon: "sparkles")
            ForEach(store.justEarned) { b in
                HStack(spacing: 12) {
                    BadgeIcon(badge: b, earned: true, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.title).font(rnd(16, .black)).foregroundStyle(Color.white)
                        Text(b.desc).font(rnd(12.5)).foregroundStyle(MT.tx2)
                    }
                    Spacer()
                }
            }
        }.padding(16).card(MT.s1, 22, stroke: MT.gold.opacity(0.35))
    }

    private var prCard: some View {
        let others = store.sessions.filter { $0.id != session.id }
        let r = Records.of(others)
        var items: [(String, String)] = []
        if session.distance > r.longest && !others.isEmpty { items.append(("أطول جولة إلك", "\(Fmt.km1(session.distance)) كم")) }
        if session.activity != .cycle, let b = session.best1k, b < (r.best1k ?? .infinity), !others.isEmpty { items.append(("أسرع كيلو", Stats.paceText(b))) }
        if session.newCells > r.mostCells && !others.isEmpty { items.append(("أكثر خلايا بجولة", "\(session.newCells)")) }
        if session.biggestLoop > r.biggestLoop && session.biggestLoop > 0 && !others.isEmpty { items.append(("أكبر دائرة", String(format: "%.2f كم²", session.biggestLoop / 1e6))) }
        let list = items
        return Group {
            if !list.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "أرقام قياسيّة جديدة", icon: "trophy.fill")
                    ForEach(0..<list.count, id: \.self) { i in
                        HStack {
                            Image(systemName: "star.fill").foregroundStyle(MT.gold)
                            Text(list[i].0).font(rnd(14, .heavy)).foregroundStyle(Color.white)
                            Spacer()
                            Text(list[i].1).font(rnd(15, .black)).foregroundStyle(MT.gold).environment(\.layoutDirection, .leftToRight)
                        }
                    }
                }.padding(16).card(MT.s1, 22, stroke: MT.gold.opacity(0.3))
            }
        }
    }
}

/// أعمدة زمن كلّ كيلو — الأسرع يتوهّج
struct SplitsCard: View {
    let splits: [Double]
    let best: Double

    var body: some View {
        let worst = splits.max() ?? 1
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "كلّ كيلو", icon: "chart.bar.fill")
            ForEach(0..<splits.count, id: \.self) { i in
                row(i, worst)
            }
        }.padding(16).card(MT.s1, 22)
    }

    private func row(_ i: Int, _ worst: Double) -> some View {
        let s = splits[i]
        let isBest = abs(s - best) < 0.001 && splits.count > 1
        let frac = worst > 0 ? CGFloat(0.35 + 0.65 * (best / max(s, 1))) : 1
        return HStack(spacing: 10) {
            Text("\(i + 1)").font(rnd(13, .black)).foregroundStyle(MT.tx3).frame(width: 22)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(isBest ? AnyShapeStyle(MT.hot) : AnyShapeStyle(MT.brand)).frame(width: g.size.width * frac)
                        .shadow(color: (isBest ? MT.gold : MT.mint).opacity(0.4), radius: 6)
                }
            }.frame(height: 14)
            Text(Stats.paceText(s)).font(rnd(14, .black)).foregroundStyle(isBest ? MT.gold : Color.white).frame(width: 52, alignment: .trailing)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}
