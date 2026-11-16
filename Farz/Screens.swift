import SwiftUI
import UIKit

// MARK: - شاشة الفحص

struct FZScanView: View {
    @EnvironmentObject var lib: FZLibrary
    @State private var spin = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            FZBackdrop()
            VStack(spacing: 24) {
                Spacer(minLength: 10)
                ring
                VStack(spacing: 8) {
                    Text("نفحص مكتبتك").font(rnd(28, .black)).foregroundStyle(Color.white)
                    Text(lib.stage).font(rnd(14.5, .bold)).foregroundStyle(FZ.tx2).multilineTextAlignment(.center)
                        .animation(.easeInOut, value: lib.stage)
                }
                stats
                tips
                Spacer(minLength: 10)
                FZPrimaryButton(title: "أوقف الفحص", icon: "stop.fill", style: 2) { lib.cancelScan() }
                Text("خلّي التطبيق مفتوح لحدّ ما يخلص الفحص — الشاشة ما تنطفي").font(rnd(11.5)).foregroundStyle(FZ.tx3)
            }
            .padding(22)
        }
        .onAppear { spin = true; breathe = true }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(FZ.s2, lineWidth: 18)
            Circle().fill(FZ.mint.opacity(breathe ? 0.10 : 0.03)).frame(width: 190, height: 190).blur(radius: 10)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: breathe)
            FZArcShape(start: 0, end: max(0.002, lib.progress))
                .stroke(FZ.brand, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .shadow(color: FZ.mint.opacity(0.6), radius: 12)
                .animation(.easeOut(duration: 0.4), value: lib.progress)
            ForEach(0..<3, id: \.self) { k in
                Circle().fill(FZCat.allCases.map { FZ.color($0) }[k * 2]).frame(width: 9, height: 9)
                    .offset(y: -146)
                    .rotationEffect(.degrees(spin ? 360 + Double(k) * 120 : Double(k) * 120))
                    .animation(.linear(duration: 3.2 + Double(k)).repeatForever(autoreverses: false), value: spin)
            }
            VStack(spacing: 0) {
                Text(FZFormat.percent(lib.progress)).font(rnd(54, .black)).foregroundStyle(Color.white)
                    .contentTransition(.numericText())
                Text(FZFormat.thousands(lib.scanned) + " / " + FZFormat.thousands(lib.total)).font(rnd(13, .bold)).foregroundStyle(FZ.tx3)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .frame(width: 250, height: 250)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("externaldrive.fill.badge.minus", FZ.mint, FZFormat.size(lib.foundBytes), "لقينا لحدّ الآن")
            stat("square.on.square.fill", FZ.violet, "\(lib.foundGroups)", "مجموعات متشابهة")
        }
    }

    private func stat(_ icon: String, _ c: Color, _ v: String, _ l: String) -> some View {
        HStack(spacing: 10) {
            FZIconBadge(icon: icon, color: c, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(v).font(rnd(18, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(l).font(rnd(11)).foregroundStyle(FZ.tx3).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity).card(FZ.s1, 18, stroke: c.opacity(0.22))
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            tip("eye.fill", "نقارن بصمة كلّ صورة بجاراتها بالوقت لنلقى اللقطات المتكرّرة")
            tip("camera.aperture", "نقيس حدّة الحواف حتى نكشف المهزوز والمشوّش")
            tip("lock.shield.fill", "كلّه على جهازك — ولا صورة تطلع منه")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(FZ.s1, 22)
    }

    private func tip(_ icon: String, _ t: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(FZ.mint).frame(width: 22)
            Text(t).font(rnd(12.5)).foregroundStyle(FZ.tx2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - الإحصاءات والإنجازات

struct FZStatsView: View {
    @EnvironmentObject var lib: FZLibrary
    @State private var appear = false

    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                streakCard
                badges
                composition
                history
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 30)
        }
        .background(FZBackdrop())
        .navigationTitle("إنجازاتك")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FZ.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { withAnimation(.spring(response: 1.1, dampingFraction: 0.8).delay(0.1)) { appear = true } }
    }

    private var hero: some View {
        let l = lib.ledger
        let lvl = FZLevel.index(l.freed)
        return HStack(spacing: 18) {
            ZStack {
                Circle().stroke(FZ.s2, lineWidth: 12)
                FZArcShape(start: 0, end: appear ? max(0.01, FZLevel.progress(l.freed)) : 0)
                    .stroke(LinearGradient(colors: [FZ.violet, FZ.pink], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                VStack(spacing: 0) {
                    Text("\(lvl + 1)").font(rnd(34, .black)).foregroundStyle(Color.white)
                    Text("المستوى").font(rnd(10.5, .bold)).foregroundStyle(FZ.tx3)
                }
            }
            .frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 6) {
                Text(FZLevel.names[lvl]).font(rnd(22, .black)).foregroundStyle(FZ.violet)
                FZSizeText(bytes: l.freed, size: 30)
                Text("وفّرتها من \(FZFormat.items(l.items)) بـ\(l.sessions) جلسة").font(rnd(12.5)).foregroundStyle(FZ.tx2)
                if FZLevel.remaining(l.freed) > 0 {
                    Text("باقي \(FZFormat.size(FZLevel.remaining(l.freed))) لـ«\(FZLevel.names[min(FZLevel.names.count - 1, lvl + 1)])»").font(rnd(11.5)).foregroundStyle(FZ.tx3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .card(FZ.s1, 26, stroke: FZ.violet.opacity(0.25))
    }

    private var streakCard: some View {
        let l = lib.ledger
        let wk = l.week(today: lib.today)
        let maxV = Double(max(1, wk.max() ?? 1))
        let names = weekdayNames()
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "flame.fill").font(.system(size: 22, weight: .black)).foregroundStyle(FZ.hot)
                Text("سلسلة \(FZFormat.days(l.liveStreak(today: lib.today)))").font(rnd(18, .black)).foregroundStyle(Color.white)
                Spacer()
                Text("أطول سلسلة: \(l.best)").font(rnd(12.5, .bold)).foregroundStyle(FZ.tx3)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { k in
                    VStack(spacing: 6) {
                        Text(wk[k] > 0 ? FZFormat.sizeParts(wk[k]).0 : "").font(rnd(9.5, .bold)).foregroundStyle(FZ.tx3).lineLimit(1).minimumScaleFactor(0.6)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(wk[k] > 0 ? AnyShapeStyle(LinearGradient(colors: [FZ.pink, FZ.coral], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(FZ.s2))
                            .frame(height: appear ? max(8, 92 * CGFloat(Double(wk[k]) / maxV)) : 8)
                        Text(names[k]).font(rnd(10, .bold)).foregroundStyle(k == 6 ? Color.white : FZ.tx3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130, alignment: .bottom)
            Text("نظّف شي صغير كلّ يوم حتى ما تنقطع السلسلة 🔥").font(rnd(12)).foregroundStyle(FZ.tx3)
        }
        .padding(16)
        .card(FZ.s1, 24, stroke: FZ.pink.opacity(0.2))
    }

    private func weekdayNames() -> [String] {
        let all = ["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"]
        let wd = Calendar.current.component(.weekday, from: Date()) - 1   // 0 = الأحد
        return (0..<7).map { k in all[((wd - 6 + k) % 7 + 7) % 7] }
    }

    private var badges: some View {
        let list = FZBadges.all(lib.ledger)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("الأوسمة").font(rnd(18, .black)).foregroundStyle(Color.white)
                Spacer()
                Text("\(list.filter { $0.unlocked }.count) / \(list.count)").font(rnd(13, .heavy)).foregroundStyle(FZ.amber)
                    .environment(\.layoutDirection, .leftToRight)
            }
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(list) { b in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(b.unlocked ? FZ.amber.opacity(0.18) : FZ.s2).frame(width: 52, height: 52)
                            Image(systemName: b.unlocked ? b.icon : "lock.fill").font(.system(size: 20, weight: .bold))
                                .foregroundStyle(b.unlocked ? FZ.amber : FZ.tx3)
                        }
                        Text(b.title).font(rnd(12, .heavy)).foregroundStyle(b.unlocked ? Color.white : FZ.tx3).lineLimit(1).minimumScaleFactor(0.7)
                        Text(b.detail).font(rnd(10)).foregroundStyle(FZ.tx3).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.vertical, 12).frame(maxWidth: .infinity)
                    .card(FZ.s1, 18, stroke: b.unlocked ? FZ.amber.opacity(0.3) : Color.white.opacity(0.05))
                }
            }
        }
    }

    private var composition: some View {
        let maxB = Double(max(1, FZCat.allCases.map { lib.sum($0).bytes }.max() ?? 1))
        return VStack(alignment: .leading, spacing: 12) {
            Text("وين المساحة؟").font(rnd(18, .black)).foregroundStyle(Color.white)
            ForEach(FZCat.allCases) { c in
                let s = lib.sum(c)
                HStack(spacing: 10) {
                    Image(systemName: c.icon).font(.system(size: 13, weight: .bold)).foregroundStyle(FZ.color(c)).frame(width: 22)
                    Text(c.title).font(rnd(13, .bold)).foregroundStyle(FZ.tx2).frame(width: 112, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(FZ.s2)
                            Capsule().fill(FZ.color(c)).frame(width: max(4, geo.size.width * CGFloat(appear ? Double(s.bytes) / maxB : 0)))
                        }
                    }.frame(height: 8)
                    Text(FZFormat.size(s.bytes)).font(rnd(12, .heavy)).foregroundStyle(Color.white).frame(width: 66, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .card(FZ.s1, 24)
    }

    private var history: some View {
        let h = Array(lib.ledger.history.suffix(8).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            Text("آخر الجلسات").font(rnd(18, .black)).foregroundStyle(Color.white)
            if h.isEmpty {
                Text("ما نظّفت شي بعد — ابدأ بالمراجعة السريعة").font(rnd(13)).foregroundStyle(FZ.tx3)
            }
            ForEach(Array(h.enumerated()), id: \.offset) { _, e in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(FZ.green)
                    Text(dayText(e.day)).font(rnd(13.5, .bold)).foregroundStyle(Color.white)
                    Text("· " + FZFormat.items(e.count)).font(rnd(12.5)).foregroundStyle(FZ.tx3)
                    Spacer()
                    Text(FZFormat.size(e.bytes)).font(rnd(14, .black)).foregroundStyle(FZ.mint)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(FZ.s1, 24)
    }

    private func dayText(_ d: Int) -> String {
        let diff = lib.today - d
        if diff == 0 { return "اليوم" }
        if diff == 1 { return "أمس" }
        return "قبل \(FZFormat.days(diff))"
    }
}
