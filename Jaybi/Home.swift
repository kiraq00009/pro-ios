import SwiftUI

enum JSheet: Identifiable {
    case add(Expense?, Draft?, Via)
    case voice
    case scan
    case report
    case settings

    var id: String {
        switch self {
        case .add(let e, _, let v): return "add-" + (e?.id.uuidString ?? v.rawValue)
        case .voice: return "voice"
        case .scan: return "scan"
        case .report: return "report"
        case .settings: return "settings"
        }
    }
}

struct JHome: View {
    @EnvironmentObject var store: JStore
    @State private var sheet: JSheet?
    @State private var toast: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            JB.bg.ignoresSafeArea()
            List {
                Section {
                    JHeader(onReport: { sheet = .report }, onSettings: { sheet = .settings })
                        .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                    JBudgetCard()
                        .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
                        .onTapGesture { sheet = .report }
                    JChips()
                        .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 4, trailing: 18))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                let groups = store.grouped()
                if groups.isEmpty {
                    JEmpty()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 24, leading: 18, bottom: 0, trailing: 18))
                }
                ForEach(groups) { g in
                    Section {
                        ForEach(g.items) { e in
                            JRow(e: e)
                                .contentShape(Rectangle())
                                .onTapGesture { sheet = .add(e, nil, e.via) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Haptic.thud()
                                        withAnimation { store.delete(e.id) }
                                    } label: { Label("امسح", systemImage: "trash") }
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        JDayHeader(day: g.id, total: Stats.sum(g.items))
                    }
                }
                Color.clear.frame(height: 110)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            JDock(onType: { sheet = .add(nil, nil, .type) }, onVoice: { sheet = .voice }, onScan: { sheet = .scan })

            if let t = toast {
                JToast(text: t)
                    .padding(.bottom, 108)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $sheet) { s in
            sheetView(s)
        }
    }

    @ViewBuilder
    private func sheetView(_ s: JSheet) -> some View {
        switch s {
        case .add(let e, let d, let v):
            JEditor(existing: e, draft: d, via: v, onSaved: saved)
                .environmentObject(store)
        case .voice:
            JVoiceView(onSaved: saved)
                .environmentObject(store)
        case .scan:
            JScanView(onSaved: saved)
                .environmentObject(store)
        case .report:
            JReport()
                .environmentObject(store)
        case .settings:
            JSettings()
                .environmentObject(store)
        }
    }

    private func saved(_ e: Expense) {
        Haptic.ok()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            toast = "انحفظ " + Money.s(e.amount) + " " + store.currency + " · " + Cats.get(e.cat).name
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { toast = nil }
        }
    }
}

struct JHeader: View {
    var onReport: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("جيبي").font(rnd(26, .bold)).foregroundColor(JB.tx)
                Text(JDate.monthYear(Date())).font(rnd(13)).foregroundColor(JB.tx2)
            }
            Spacer()
            JIconButton(system: "chart.pie.fill", action: onReport)
            JIconButton(system: "gearshape.fill", action: onSettings)
        }
    }
}

struct JIconButton: View {
    var system: String
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(JB.tx)
                .frame(width: 44, height: 44)
                .card(JB.card, 15)
        }
        .buttonStyle(Press())
    }
}

struct JBudgetCard: View {
    @EnvironmentObject var store: JStore

    var body: some View {
        let spent = store.spent(Date())
        let budget = store.budget
        let left = budget - spent
        let frac = budget > 0 ? min(1, max(0, spent / budget)) : 0
        let over = budget > 0 && left < 0
        VStack(alignment: .leading, spacing: 0) {
            Text(budget > 0 ? (over ? "تجاوزت ميزانيّة " + JDate.month(Date()) + " بـ" : "باقي من ميزانيّة " + JDate.month(Date())) : "صرفت هالشهر")
                .font(rnd(14)).foregroundColor(JB.tx2)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Money.s(budget > 0 ? abs(left) : spent))
                    .font(rnd(42, .bold))
                    .foregroundColor(over ? JB.coral : JB.tx)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(store.currency).font(rnd(16, .medium)).foregroundColor(JB.tx2)
            }
            .padding(.top, 2)
            if budget > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(JB.card2)
                        Capsule()
                            .fill(over ? AnyShapeStyle(JB.coral) : AnyShapeStyle(LinearGradient(colors: [JB.mint, Color(red: 0.56, green: 0.94, blue: 0.77)], startPoint: .leading, endPoint: .trailing)))
                            .frame(width: max(10, geo.size.width * (1 - frac)))
                    }
                }
                .frame(height: 10)
                .padding(.top, 12)
                HStack {
                    Text("صرفت " + Money.s(spent)).font(rnd(12.5)).foregroundColor(JB.tx2)
                    Spacer()
                    Text("من " + Money.short(budget)).font(rnd(12.5)).foregroundColor(JB.tx2)
                }
                .padding(.top, 6)
            }
        }
        .padding(.vertical, 6)
    }
}

struct JChips: View {
    @EnvironmentObject var store: JStore

    var body: some View {
        let now = Date()
        let cal = store.cal
        let day = cal.component(.day, from: now)
        let dim = Stats.daysInMonth(now, cal)
        let spent = store.spent(now)
        HStack(spacing: 8) {
            JChip(value: Money.s(store.today(now)), label: "اليوم")
            JChip(value: Money.short(Stats.dailyAvg(spent: spent, day: day)), label: "معدّل اليوم")
            if store.budget > 0 {
                let left = max(0, store.budget - spent)
                let daysLeft = max(1, dim - day + 1)
                JChip(value: Money.short(left / Double(daysLeft)), label: "تگدر تصرف باليوم")
            } else {
                JChip(value: String(dim - day), label: "يوم باقي")
            }
        }
    }
}

struct JChip: View {
    var value: String
    var label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(rnd(15, .bold)).foregroundColor(JB.tx).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(rnd(11)).foregroundColor(JB.tx2).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .padding(.horizontal, 6)
        .card(JB.card, 18)
    }
}

struct JDayHeader: View {
    var day: Date
    var total: Double

    var body: some View {
        HStack {
            Text(JDate.dayTitle(day)).font(rnd(14, .semibold)).foregroundColor(JB.tx2)
            Spacer()
            Text(Money.s(total)).font(rnd(13, .medium)).foregroundColor(JB.tx2.opacity(0.8))
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
        .background(JB.bg)
        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
    }
}

struct JCatIcon: View {
    var cat: String
    var size: CGFloat = 42

    var body: some View {
        Text(Cats.get(cat).emoji)
            .font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background(JB.color(cat).opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

struct JRow: View {
    @EnvironmentObject var store: JStore
    var e: Expense

    var viaIcon: String {
        switch e.via {
        case .voice: return "mic.fill"
        case .scan: return "doc.text.viewfinder"
        case .type: return "keyboard"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            JCatIcon(cat: e.cat)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(e.note).font(rnd(15, .semibold)).foregroundColor(JB.tx).lineLimit(1)
                    Image(systemName: viaIcon).font(.system(size: 10, weight: .semibold)).foregroundColor(JB.tx2)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(JB.card2, in: Capsule())
                }
                Text(Cats.get(e.cat).name + " · " + JDate.time(e.date)).font(rnd(12)).foregroundColor(JB.tx2)
            }
            Spacer(minLength: 6)
            Text(Money.s(e.amount)).font(rnd(16, .bold)).foregroundColor(JB.tx)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .card(JB.card, 18)
    }
}

struct JEmpty: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(JB.mintGrad)
            Text("ولا مصروف بعد").font(rnd(18, .bold)).foregroundColor(JB.tx)
            Text("اضغط «احچي» وگول مثلًا:\n«صرفت عشرة آلاف على الغدا»\nأو صوّر وصل، أو اكتب بإيدك.")
                .font(rnd(14)).foregroundColor(JB.tx2).multilineTextAlignment(.center).lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .card(JB.card, 24)
    }
}

struct JDock: View {
    var onType: () -> Void
    var onVoice: () -> Void
    var onScan: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            JDockButton(title: "اكتب", system: "keyboard", primary: false, action: onType)
            JDockButton(title: "احچي", system: "mic.fill", primary: true, action: onVoice)
                .layoutPriority(1)
            JDockButton(title: "صوّر", system: "doc.text.viewfinder", primary: false, action: onScan)
        }
        .padding(.horizontal, 18)
        .padding(.top, 40)
        .padding(.bottom, 14)
        .background(
            LinearGradient(colors: [JB.bg.opacity(0), JB.bg.opacity(0.92), JB.bg], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        )
    }
}

struct JDockButton: View {
    var title: String
    var system: String
    var primary: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: system).font(.system(size: primary ? 19 : 16, weight: .semibold))
                Text(title).font(rnd(primary ? 16 : 14.5, .bold))
            }
            .foregroundColor(primary ? JB.mintInk : JB.tx)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(primaryBG)
        }
        .buttonStyle(Press())
    }

    @ViewBuilder
    private var primaryBG: some View {
        if primary {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(JB.mintGrad)
                .shadow(color: JB.mint.opacity(0.35), radius: 14, y: 8)
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(JB.card2)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JB.line))
        }
    }
}

struct JToast: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(JB.mint)
            Text(text).font(rnd(14, .semibold)).foregroundColor(JB.tx)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(JB.line))
    }
}
