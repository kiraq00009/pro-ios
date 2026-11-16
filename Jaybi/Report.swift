import SwiftUI

/// «وين راحت فلوسي؟» — تقرير الشهر
struct JReport: View {
    @EnvironmentObject var store: JStore
    @Environment(\.dismiss) private var dismiss
    @State private var offset = 0  // 0 = هذا الشهر، -1 = الماضي…

    private var month: Date { Stats.addMonths(Date(), offset, store.cal) }

    var body: some View {
        let xs = store.month(month)
        let sums = Stats.byCat(xs)
        let total = Stats.sum(xs)
        ZStack {
            JB.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if total <= 0 {
                        Text("ما سجّلت مصاريف بهذا الشهر")
                            .font(rnd(16)).foregroundColor(JB.tx2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else {
                        JDonut(sums: sums, total: total)
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        tips(xs: xs, total: total)
                        JLegend(sums: sums, total: total)
                        JDailyBars(values: Stats.daily(store.items, month, store.cal), today: offset == 0 ? store.cal.component(.day, from: Date()) : 0)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                Haptic.tap()
                withAnimation { offset -= 1 }
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundColor(JB.tx)
                    .frame(width: 38, height: 38).card(JB.card, 12)
            }
            .buttonStyle(Press())
            VStack(spacing: 1) {
                Text(JDate.month(month)).font(rnd(21, .bold)).foregroundColor(JB.tx)
                Text(String(store.cal.component(.year, from: month))).font(rnd(12)).foregroundColor(JB.tx2)
            }
            .frame(maxWidth: .infinity)
            Button {
                Haptic.tap()
                withAnimation { offset += 1 }
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold)).foregroundColor(offset < 0 ? JB.tx : JB.tx2.opacity(0.3))
                    .frame(width: 38, height: 38).card(JB.card, 12)
            }
            .buttonStyle(Press())
            .disabled(offset >= 0)
        }
        .padding(.top, 18)
        .overlay(alignment: .top) {
            Capsule().fill(JB.tx2.opacity(0.35)).frame(width: 40, height: 5).offset(y: -2)
        }
    }

    @ViewBuilder
    private func tips(xs: [Expense], total: Double) -> some View {
        let cal = store.cal
        VStack(spacing: 10) {
            if offset == 0 && store.budget > 0 {
                let day = cal.component(.day, from: Date())
                let dim = Stats.daysInMonth(Date(), cal)
                if let d = Stats.runOutDay(budget: store.budget, spent: total, day: day, daysInMonth: dim) {
                    JTip(icon: "exclamationmark.triangle.fill", color: JB.coral,
                         text: total >= store.budget ? "خلصت ميزانيّة هالشهر. حاول تخفّف لحدّ آخر الشهر." : "إذا تكمل بنفس الصرف، الميزانيّة تخلص يوم " + String(d) + ".")
                } else {
                    let left = store.budget - total
                    JTip(icon: "checkmark.seal.fill", color: JB.mint,
                         text: "ماشي زين! بهذا المعدّل يبقى عندك تقريبًا " + Money.short(max(0, left - Stats.dailyAvg(spent: total, day: day) * Double(dim - day))) + " آخر الشهر.")
                }
            }
            if offset == 0, let ins = Stats.biggestRise(store.items, now: Date(), cal, minBase: 1000) {
                JTip(icon: "arrow.up.right.circle.fill", color: JB.sun,
                     text: "صرفك على " + Cats.get(ins.cat).name + " زاد " + String(ins.pct) + "٪ عن نفس الفترة من الشهر الماضي.")
            }
            if let top = Stats.byCat(xs).first, total > 0 {
                let pct = Int((top.total / total * 100).rounded())
                JTip(icon: "chart.pie.fill", color: JB.color(top.cat),
                     text: "أكثر شي صرفت عليه: " + Cats.get(top.cat).name + " (" + String(pct) + "٪ من مصاريفك).")
            }
        }
    }
}

struct JTip: View {
    var icon: String
    var color: Color
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 17)).foregroundColor(color)
            Text(text).font(rnd(14)).foregroundColor(JB.tx).lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(13)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.35)))
    }
}

/// حلقة الأصناف
struct JDonut: View {
    var sums: [CatSum]
    var total: Double
    @State private var shown = false

    var body: some View {
        ZStack {
            ForEach(Array(segments().enumerated()), id: \.offset) { item in
                Circle()
                    .trim(from: item.element.0, to: shown ? item.element.1 : item.element.0)
                    .stroke(JB.color(item.element.2), style: StrokeStyle(lineWidth: 30, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                Text("صرفت").font(rnd(13)).foregroundColor(JB.tx2)
                Text(Money.s(total)).font(rnd(24, .bold)).foregroundColor(JB.tx).minimumScaleFactor(0.5).lineLimit(1)
            }
            .padding(40)
        }
        .padding(16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { shown = true }
        }
    }

    private func segments() -> [(CGFloat, CGFloat, String)] {
        var out: [(CGFloat, CGFloat, String)] = []
        var a: CGFloat = 0
        for s in sums where total > 0 {
            let f = CGFloat(s.total / total)
            let gap: CGFloat = sums.count > 1 ? 0.004 : 0
            out.append((a, max(a, a + f - gap), s.cat))
            a += f
        }
        return out
    }
}

struct JLegend: View {
    var sums: [CatSum]
    var total: Double

    var body: some View {
        VStack(spacing: 0) {
            ForEach(sums, id: \.cat) { s in
                JLegendRow(s: s, total: total)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .card(JB.card, 20)
    }
}

struct JLegendRow: View {
    var s: CatSum
    var total: Double

    var body: some View {
        let f = total > 0 ? s.total / total : 0
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                JCatIcon(cat: s.cat, size: 34)
                Text(Cats.get(s.cat).name).font(rnd(14.5, .semibold)).foregroundColor(JB.tx)
                Spacer()
                Text(String(Int((f * 100).rounded())) + "٪").font(rnd(12.5)).foregroundColor(JB.tx2)
                Text(Money.s(s.total)).font(rnd(15, .bold)).foregroundColor(JB.tx)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(JB.card2)
                    Capsule().fill(JB.color(s.cat)).frame(width: max(4, geo.size.width * f))
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 9)
    }
}

/// أعمدة الصرف اليوميّ
struct JDailyBars: View {
    var values: [Double]
    var today: Int

    var body: some View {
        let mx = max(values.max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 10) {
            Text("الصرف اليوميّ").font(rnd(14, .semibold)).foregroundColor(JB.tx2)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { item in
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(item.offset + 1 == today ? JB.mint : JB.mint.opacity(item.element > 0 ? 0.45 : 0.12))
                        .frame(height: max(3, 90 * CGFloat(item.element / mx)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 92, alignment: .bottom)
            .environment(\.layoutDirection, .leftToRight)
            HStack {
                Text("1").font(rnd(11)).foregroundColor(JB.tx2)
                Spacer()
                Text(String(values.count)).font(rnd(11)).foregroundColor(JB.tx2)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(14)
        .card(JB.card, 20)
    }
}
