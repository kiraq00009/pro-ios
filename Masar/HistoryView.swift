import SwiftUI

/// السجلّ: كلّ الجولات مع صورة المسار، مجمّعة بالشهر، مع فلتر النشاط
struct HistoryView: View {
    @EnvironmentObject var store: MasarStore
    @State private var filter: Activity? = nil
    @State private var open: Session? = nil

    private var list: [Session] { store.sessions.filter { filter == nil || $0.activity == filter } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("السجلّ").font(rnd(34, .black)).foregroundStyle(Color.white)
                    Text("\(store.sessions.count) جولة · \(Fmt.km1(store.totalDistance)) كم").font(rnd(13)).foregroundStyle(MT.tx3)
                }.padding(.top, 8)
                filters
                if list.isEmpty {
                    EmptyCard(icon: "figure.run", title: store.sessions.isEmpty ? "ما في جولات بعد" : "ما في جولات بهذا النوع",
                              sub: "أوّل جولة تقوم بها تظهر هنا مع خريطتها وأرقامها وكلّ كيلو.")
                } else {
                    ForEach(groups()) { g in
                        Text(g.id).font(rnd(14, .heavy)).foregroundStyle(MT.tx3).padding(.top, 4)
                        ForEach(g.items) { s in
                            Button { Haptic.tap(); open = s } label: { HistoryRow(session: s) }.buttonStyle(Press())
                        }
                    }
                }
            }
            .padding(18)
        }
        .background(MBackdrop())
        .sheet(item: $open) { s in
            SessionView(session: s) { open = nil }
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
    }

    private var filters: some View {
        HStack(spacing: 8) {
            pill("الكلّ", nil)
            ForEach(Activity.allCases) { a in pill(a.title, a) }
        }
    }

    private func pill(_ t: String, _ a: Activity?) -> some View {
        let on = filter == a
        return Button { Haptic.tap(); withAnimation(.easeOut(duration: 0.2)) { filter = a } } label: {
            Text(t).font(rnd(13.5, .heavy)).foregroundStyle(on ? MT.ink : Color.white)
                .padding(.horizontal, 16).frame(height: 36)
                .background(on ? AnyShapeStyle(MT.brand) : AnyShapeStyle(MT.s2), in: Capsule())
        }.buttonStyle(Press())
    }

    private func groups() -> [MonthGroup] {
        var out: [MonthGroup] = []
        for s in list {
            let m = Fmt.month(s.start)
            if let i = out.firstIndex(where: { $0.id == m }) { out[i].items.append(s) } else { out.append(MonthGroup(id: m, items: [s])) }
        }
        return out
    }
}

struct MonthGroup: Identifiable {
    let id: String
    var items: [Session]
}

struct HistoryRow: View {
    @EnvironmentObject var store: MasarStore
    let session: Session

    var body: some View {
        HStack(spacing: 13) {
            RouteThumb(route: session.route, color: MT.color(session.activity))
                .frame(width: 78, height: 78)
                .background(MT.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(HexPattern(size: 9).opacity(0.06).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: session.activity.icon).font(.system(size: 12, weight: .black)).foregroundStyle(MT.color(session.activity))
                    Text(Fmt.relDay(session.start, now: store.now, tz: store.tz)).font(rnd(13, .heavy)).foregroundStyle(MT.tx2)
                    Text("· \(Fmt.time(session.start))").font(rnd(12)).foregroundStyle(MT.tx3)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Fmt.km(session.distance)).font(rnd(24, .black)).foregroundStyle(Color.white)
                    Text("كم").font(rnd(12, .bold)).foregroundStyle(MT.tx3)
                }.environment(\.layoutDirection, .leftToRight)
                HStack(spacing: 10) {
                    tag("timer", Stats.durationText(session.active))
                    tag("speedometer", session.activity == .cycle ? String(format: "%.1f", session.kmh) : Stats.paceText(session.pace))
                    tag("hexagon.fill", "+\(session.newCells)", MT.gold)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.left").font(.system(size: 12, weight: .black)).foregroundStyle(MT.tx3)
        }
        .padding(11).card(MT.s1, 20)
    }

    private func tag(_ icon: String, _ v: String, _ c: Color = MT.mint) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10, weight: .black)).foregroundStyle(c)
            Text(v).font(rnd(12, .heavy)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
        }
    }
}
