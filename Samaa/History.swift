import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject var store: Store
    @State private var range = 0
    @State private var confirmClear = false
    @State private var filter: String? = nil

    private var ranged: [SoundEvent] {
        let now = nowT()
        switch range {
        case 0:
            let s = Stats.dayStart(now, tz: localTZ)
            return Stats.within(store.events, from: s, to: s + 86400)
        case 1:
            let s = Stats.dayStart(now, tz: localTZ) - 6 * 86400
            return Stats.within(store.events, from: s, to: now + 1)
        default:
            return store.events
        }
    }

    var body: some View {
        let evs: [SoundEvent] = ranged
        let shown: [SoundEvent] = filter == nil ? evs : evs.filter { $0.sound == filter }
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "السجلّ", sub: "كلّ صوت سمعته، متى وكم مرّة") {
                    Menu {
                        Button(role: .destructive) { confirmClear = true } label: { Label("امسح السجلّ", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 16, weight: .black)).foregroundStyle(Color.white)
                            .frame(width: 42, height: 42).background(SM.s2, in: Circle())
                    }
                }
                HStack(spacing: 8) {
                    Chip(text: "اليوم", on: range == 0) { range = 0; filter = nil }
                    Chip(text: "٧ أيام", on: range == 1) { range = 1; filter = nil }
                    Chip(text: "الكلّ", on: range == 2) { range = 2; filter = nil }
                    Spacer()
                }
                if evs.isEmpty {
                    EmptyCard(emoji: "📭", title: "السجلّ فارغ", note: "شغّل الاستماع من الرادار، وكلّ صوت واضح راح ينحفظ هنا مع وقته ومدّته.")
                } else {
                    SummaryTiles(events: evs)
                    HourlyChart(events: shown, title: filter == nil ? "حسب الساعة" : "\(Catalog.ar(filter ?? "")) حسب الساعة")
                    if range == 1 { DailyChart(events: shown) }
                    SoundBreakdown(events: evs, filter: $filter)
                    RecentEvents(events: shown)
                }
            }
            .padding(18)
        }
        .background(Backdrop(tint: SM.violet))
        .confirmationDialog("نمسح كلّ السجلّ والتنبيهات؟", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("امسح", role: .destructive) { store.clearHistory(); Haptic.thud() }
            Button("لا، رجوع", role: .cancel) {}
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var emoji: String = ""
    var color: Color = SM.sonar
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if !emoji.isEmpty { Text(emoji).font(.system(size: 16)) }
                Text(value).font(rnd(20, .black)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(label).font(rnd(11.5, .bold)).foregroundStyle(SM.tx3).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).card(SM.s1, 18)
    }
}

struct SummaryTiles: View {
    let events: [SoundEvent]
    var body: some View {
        let counts = Stats.counts(events)
        let hours = Stats.hourly(events, tz: localTZ)
        let busy = Stats.busiestHour(hours)
        let topSound = counts.first?.sound
        HStack(spacing: 10) {
            StatTile(value: "\(events.count)", label: "حدث صوتي")
            StatTile(value: topSound.map { Catalog.ar($0) } ?? "—", label: "الأكثر", emoji: topSound.map { Catalog.emoji($0) } ?? "", color: SM.amber)
            StatTile(value: busy.map { hourLabel($0) } ?? "—", label: "أنشط ساعة", color: SM.violet)
        }
    }
}

func hourLabel(_ h: Int) -> String {
    let hh = h % 12 == 0 ? 12 : h % 12
    return "\(hh) \(h < 12 ? "ص" : "م")"
}

struct HourlyChart: View {
    let events: [SoundEvent]
    let title: String
    var body: some View {
        let b = Stats.hourly(events, tz: localTZ)
        let mx = max(1, b.max() ?? 1)
        let nowH = Stats.hourOf(nowT(), tz: localTZ)
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: title, icon: "chart.bar.fill")
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { h in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(h == nowH ? AnyShapeStyle(SM.grad) : AnyShapeStyle(SM.violet.opacity(b[h] == 0 ? 0.15 : 0.75)))
                            .frame(height: max(4, CGFloat(b[h]) / CGFloat(mx) * 110))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 112, alignment: .bottom)
            .environment(\.layoutDirection, .leftToRight)
            HStack {
                ForEach([0, 6, 12, 18, 23], id: \.self) { h in
                    Text(hourLabel(h)).font(rnd(10, .bold)).foregroundStyle(SM.tx3)
                    if h != 23 { Spacer() }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16).card(SM.s1, 22)
    }
}

struct DailyChart: View {
    let events: [SoundEvent]
    var body: some View {
        let now = nowT()
        let d = Stats.daily(events, days: 7, now: now, tz: localTZ)
        let mx = max(1, d.max() ?? 1)
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "آخر ٧ أيام", icon: "calendar")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 6) {
                        Text("\(d[i])").font(rnd(10.5, .bold)).foregroundStyle(SM.tx3)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(i == 6 ? AnyShapeStyle(SM.grad) : AnyShapeStyle(SM.sonar.opacity(0.45)))
                            .frame(height: max(6, CGFloat(d[i]) / CGFloat(mx) * 90))
                        Text(weekday(now - Double(6 - i) * 86400)).font(rnd(10, .bold)).foregroundStyle(i == 6 ? SM.sonar : SM.tx3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130, alignment: .bottom)
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16).card(SM.s1, 22)
    }

    func weekday(_ t: Double) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "EEE"
        return f.string(from: Date(timeIntervalSince1970: t))
    }
}

struct SoundBreakdown: View {
    let events: [SoundEvent]
    @Binding var filter: String?
    var body: some View {
        let counts = Array(Stats.counts(events).prefix(12))
        let mx = max(1, counts.first?.count ?? 1)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: "حسب الصوت", icon: "waveform")
                if filter != nil {
                    Button { filter = nil; Haptic.tap() } label: {
                        Text("الكلّ").font(rnd(12, .heavy)).foregroundStyle(SM.sonar)
                    }
                }
            }
            ForEach(counts, id: \.sound) { c in
                Button {
                    filter = filter == c.sound ? nil : c.sound
                    Haptic.tap()
                } label: {
                    CountRow(c: c, mx: mx, on: filter == c.sound)
                }.buttonStyle(Press())
            }
        }
        .padding(16).card(SM.s1, 22)
    }
}

struct CountRow: View {
    let c: SoundCount
    let mx: Int
    let on: Bool
    var body: some View {
        let col = SM.color(c.sound)
        HStack(spacing: 10) {
            Text(Catalog.emoji(c.sound)).font(.system(size: 20)).frame(width: 38, height: 38)
                .background(col.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(Catalog.ar(c.sound)).font(rnd(14, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                    Spacer()
                    Text("\(c.count) مرّة").font(rnd(12.5, .black)).foregroundStyle(col)
                    Text("· \(Stats.durationText(c.seconds))").font(rnd(11.5)).foregroundStyle(SM.tx3)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(SM.s3)
                        Capsule().fill(col).frame(width: max(5, g.size.width * CGFloat(c.count) / CGFloat(mx)))
                    }
                }.frame(height: 5)
            }
        }
        .padding(8)
        .background(on ? col.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct RecentEvents: View {
    let events: [SoundEvent]
    var body: some View {
        let list: [SoundEvent] = Array(events.suffix(40).reversed())
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "آخر الأحداث", icon: "list.bullet")
            VStack(spacing: 0) {
                ForEach(list) { e in
                    EventRow(e: e)
                    if e.id != list.last?.id { Divider().overlay(SM.line).padding(.leading, 56) }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 4).card(SM.s1, 22)
        }
    }
}

struct EventRow: View {
    let e: SoundEvent
    var body: some View {
        let col = SM.color(e.sound)
        HStack(spacing: 12) {
            Text(Catalog.emoji(e.sound)).font(.system(size: 20))
                .frame(width: 40, height: 40).background(col.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(Catalog.ar(e.sound)).font(rnd(14, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                Text("\(dayText(e.start)) · \(clockText(e.start)) · \(Stats.durationText(max(1, e.duration)))").font(rnd(11.5)).foregroundStyle(SM.tx3)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(pct(e.peak)).font(rnd(12.5, .black)).foregroundStyle(col)
                Text("\(Int(e.db.rounded())) dB").font(rnd(10.5, .bold)).foregroundStyle(SM.tx3)
            }
            ClipButton(name: e.clip, color: col)
        }
        .padding(.vertical, 8)
    }
}
