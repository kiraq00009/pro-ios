import SwiftUI

struct SheetHeader: View {
    let title: String
    let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(rnd(30, .black)).foregroundStyle(Color.white)
            Text(sub).font(rnd(13)).foregroundStyle(MD.tx3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

// MARK: المهمّات

struct MissionsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: "مهمّات اليوم", sub: "ثلاث مهمّات جديدة كلّ يوم — كلّ وحدة تنحسب بجولة وحدة")
                summary
                let ms = store.p.missions
                ForEach(0..<ms.count, id: \.self) { i in
                    MissionRow(m: ms[i], progress: i < store.p.bestProgress.count ? store.p.bestProgress[i] : 0, done: store.p.missionsDone.contains(i))
                        .padding(14)
                        .card(MD.s1, 20, stroke: store.p.missionsDone.contains(i) ? MD.green.opacity(0.35) : Color.white.opacity(0.06))
                }
                tips
            }
            .padding(18)
        }
        .background(MD.bg.ignoresSafeArea())
    }

    private var summary: some View {
        let ms = store.p.missions
        let total = ms.reduce(0) { $0 + $1.reward }
        let got = store.p.missionsDone.reduce(0) { acc, i in acc + (i < ms.count ? ms[i].reward : 0) }
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
                Circle().trim(from: 0, to: CGFloat(store.p.missionsDone.count) / 3)
                    .stroke(MD.hero, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(store.p.missionsDone.count)/3").font(rnd(17, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
            }
            .frame(width: 68, height: 68)
            VStack(alignment: .leading, spacing: 4) {
                Text("مكافآت اليوم").font(rnd(16, .black)).foregroundStyle(Color.white)
                Text("أخذت \(got) من \(total) جوهرة").font(rnd(13, .bold)).foregroundStyle(MD.gold)
                Text("تتجدّد بعد \(hoursLeft) ساعة").font(rnd(12)).foregroundStyle(MD.tx3)
            }
            Spacer()
        }
        .padding(14).card(MD.s1, 22, stroke: MD.magenta.opacity(0.25))
    }

    private var hoursLeft: Int {
        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        let next = start.addingTimeInterval(86400)
        return max(1, Int(ceil(next.timeIntervalSince(now) / 3600)))
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("نصايح").font(rnd(16, .black)).foregroundStyle(Color.white)
            tip("scope", MD.gold, "المسكة المثاليّة: خلّي خطّ طيرانك يمسح الحلقة المنقّطة بالضبط بدل ما تدخل للنصّ.")
            tip("flame.fill", MD.magenta, "كلّ مثاليّة ورا الثانية تكبّر المضاعف لحدّ ×5، والمسكة العاديّة تصفّره.")
            tip("tornado", MD.violet, "الثقب الدوديّ يقفزك كوكب كامل ويعطيك ٢٥ نقطة.")
            tip("heart.fill", MD.green, "إذا متّ تگدر تكمّل مرّة وحدة بكلّ جولة بـ ٣٠ جوهرة.")
        }
        .padding(14).card(MD.s1, 20)
    }

    private func tip(_ icon: String, _ c: Color, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(c).frame(width: 22)
            Text(t).font(rnd(13)).foregroundStyle(MD.tx2).lineSpacing(2)
        }
    }
}

// MARK: الإحصائيّات

struct StatsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: "إحصائيّاتي", sub: "كلّ رحلاتك بالفضاء")
                grid
                chart
                history
            }
            .padding(18)
        }
        .background(MD.bg.ignoresSafeArea())
    }

    private var grid: some View {
        let p = store.p
        let pr: Int = p.totalPlanets > 0 ? Int((Double(p.totalPerfects) / Double(p.totalPlanets) * 100).rounded()) : 0
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                big("\(p.best)", "أفضل نتيجة", "trophy.fill", MD.gold)
                big("\(p.bestPlanets)", "أعلى كوكب", "arrow.up.circle.fill", MD.cyan)
            }
            HStack(spacing: 10) {
                small("\(p.runs)", "جولة", "play.circle.fill", MD.violet)
                small("\(p.average)", "المعدّل", "chart.line.uptrend.xyaxis", MD.green)
                small("×\(Scoring.mult(p.bestCombo))", "أعلى كومبو", "flame.fill", MD.magenta)
            }
            HStack(spacing: 10) {
                small("\(p.totalPerfects)", "مثاليّة", "scope", MD.gold)
                small("\(pr)%", "دقّة", "target", MD.cyan)
                small("\(p.totalGems)", "جواهر جمعتها", "diamond.fill", MD.magenta)
            }
        }
    }

    private func big(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(32, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(12.5)).foregroundStyle(MD.tx3)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .card(MD.s1, 22, stroke: c.opacity(0.3))
    }

    private func small(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(19, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(10.5)).foregroundStyle(MD.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(11).frame(maxWidth: .infinity, alignment: .leading)
        .card(MD.s1, 16, stroke: c.opacity(0.22))
    }

    private var chart: some View {
        let runs = Array(store.p.history.prefix(20).reversed())
        let top = max(1, runs.map { $0.score }.max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("آخر الجولات").font(rnd(16, .black)).foregroundStyle(Color.white)
            if runs.isEmpty {
                Text("بعدك ما لعبت — أوّل جولة تبيّن هنا").font(rnd(13)).foregroundStyle(MD.tx3).frame(maxWidth: .infinity).frame(height: 110)
            } else {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<runs.count, id: \.self) { i in
                        let r = runs[i]
                        let h = CGFloat(r.score) / CGFloat(top)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(r.daily ? AnyShapeStyle(MD.goldGrad) : AnyShapeStyle(MD.hero))
                            .frame(height: max(4, 110 * h))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 112, alignment: .bottom)
                .environment(\.layoutDirection, .leftToRight)
                HStack(spacing: 12) {
                    legend(MD.violet, "جولة عاديّة")
                    legend(MD.gold, "تحدّي اليوم")
                }
            }
        }
        .padding(14).card(MD.s1, 22)
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(t).font(rnd(11.5)).foregroundStyle(MD.tx3)
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("السجلّ").font(rnd(16, .black)).foregroundStyle(Color.white).padding(.bottom, 8)
            ForEach(0..<min(12, store.p.history.count), id: \.self) { i in
                let r = store.p.history[i]
                HStack(spacing: 10) {
                    Image(systemName: r.daily ? "calendar" : "sparkles").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(r.daily ? MD.gold : MD.cyan).frame(width: 30, height: 30)
                        .background(MD.s2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(r.score) نقطة").font(rnd(14.5, .heavy)).foregroundStyle(Color.white)
                        Text("كوكب \(r.planets) · \(r.perfects) مثاليّة").font(rnd(11.5)).foregroundStyle(MD.tx3)
                    }
                    Spacer()
                    Text(agoText(r.when)).font(rnd(11.5)).foregroundStyle(MD.tx3)
                }
                .padding(.vertical, 8)
                if i < min(12, store.p.history.count) - 1 { Divider().overlay(Color.white.opacity(0.06)) }
            }
            if store.p.history.isEmpty {
                Text("ماكو جولات بعد").font(rnd(13)).foregroundStyle(MD.tx3)
            }
        }
        .padding(14).card(MD.s1, 22)
    }
}

// MARK: الإعدادات

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("md_sound") private var sound = true
    @AppStorage("md_haptic") private var haptic = true
    @AppStorage("md_guide") private var guide = true
    @AppStorage("md_seen_how") private var seenHow = true
    @State private var confirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: "الإعدادات", sub: "رتّب اللعبة على ذوقك")
                VStack(spacing: 0) {
                    toggle("speaker.wave.2.fill", MD.cyan, "الأصوات", "نغمات مولّدة لكلّ مسكة وجوهرة", $sound)
                    Divider().overlay(Color.white.opacity(0.06))
                    toggle("iphone.radiowaves.left.and.right", MD.magenta, "الاهتزاز", "تحسّ بكلّ مسكة بإيدك", $haptic)
                    Divider().overlay(Color.white.opacity(0.06))
                    toggle("line.diagonal.arrow", MD.gold, "خطّ التصويب", "يبيّن اتّجاه الإطلاق بأوّل الكواكب", $guide)
                }
                .padding(.horizontal, 14).card(MD.s1, 22)

                Button { FX.tap(); seenHow = false } label: {
                    row("questionmark.circle.fill", MD.violet, "شوف الشرح مرّة ثانية", "يطلع أوّل ما ترجع للشاشة الرئيسيّة")
                }.buttonStyle(Press()).padding(.horizontal, 14).card(MD.s1, 22)

                Button { confirm = true } label: {
                    row("trash.fill", MD.red, "صفّر تقدّمي", "يمسح النتائج والجواهر والمذنّبات")
                }.buttonStyle(Press()).padding(.horizontal, 14).card(MD.s1, 22, stroke: MD.red.opacity(0.25))

                VStack(alignment: .leading, spacing: 6) {
                    Text("عن مدار").font(rnd(15, .black)).foregroundStyle(Color.white)
                    Text("لعبة بضغطة وحدة: مذنّب صغير يدور حول كوكب، تفلته على خطّ المماس حتى يوصل لمدار الكوكب الجاي. كلّ شي يشتغل على جهازك بلا إنترنت وبلا إعلانات.")
                        .font(rnd(12.5)).foregroundStyle(MD.tx2).lineSpacing(3)
                }
                .padding(14).card(MD.s1, 22)
            }
            .padding(18)
        }
        .background(MD.bg.ignoresSafeArea())
        .confirmationDialog("متأكّد؟ ما يرجع", isPresented: $confirm, titleVisibility: .visible) {
            Button("صفّر كلّ شي", role: .destructive) { store.reset(); FX.bad() }
            Button("لا، خلّيه", role: .cancel) {}
        }
    }

    private func toggle(_ icon: String, _ c: Color, _ t: String, _ s: String, _ b: Binding<Bool>) -> some View {
        Toggle(isOn: b) { row(icon, c, t, s) }
            .tint(MD.cyan)
            .onChange(of: b.wrappedValue) { _ in FX.tap() }
    }

    private func row(_ icon: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(c)
                .frame(width: 38, height: 38).background(MD.s2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text(s).font(rnd(12)).foregroundStyle(MD.tx3)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }
}

// MARK: الشرح (أوّل مرّة)

struct HowView: View {
    let done: () -> Void
    @State private var page = 0

    private let pages: [(String, Color, String, String)] = [
        ("hand.tap.fill", MD.cyan, "ضغطة وحدة", "المذنّب يدور حول الكوكب. اضغط بأيّ مكان حتى ينفلت ويطير على خطّ المماس."),
        ("scope", MD.gold, "امسك المدار الجاي", "لازم يدخل حلقة الكوكب اللي فوق. إذا مسح الحلقة المنقّطة بالضبط = مسكة مثاليّة، كومبو، ولحظة بطيئة."),
        ("exclamationmark.triangle.fill", MD.red, "انتبه بالطريق", "الأقمار تقتل، الثقب الأسود يحني طريقك ويبلعك، وبعض المدارات تنكمش وإنت عليها — لا تتأخّر."),
        ("diamond.fill", MD.magenta, "اجمع وافتح", "الجواهر تفتح مذنّبات وذيول جديدة، والمهمّات اليوميّة تعطيك أكثر. كلّ يوم تحدّي بنفس الكون لكلّ اللاعبين."),
    ]

    var body: some View {
        ZStack {
            MD.bg.ignoresSafeArea()
            HomeHero(skin: Catalog.comets[0], trail: Catalog.trails[0]).frame(height: 320).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                TabView(selection: $page) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        card(pages[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 300)
                HStack(spacing: 7) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule().fill(i == page ? MD.cyan : Color.white.opacity(0.2)).frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.3), value: page)
                BigButton(title: page == pages.count - 1 ? "يلّا نطير" : "بعدين", icon: page == pages.count - 1 ? "paperplane.fill" : "chevron.left", grad: MD.hero) {
                    FX.tap()
                    if page < pages.count - 1 { withAnimation { page += 1 } } else { done() }
                }
                .padding(.horizontal, 24)
                Button("تخطّى") { done() }.font(rnd(14, .heavy)).foregroundStyle(MD.tx3)
                    .opacity(page == pages.count - 1 ? 0 : 1)
            }
            .padding(.bottom, 24)
        }
    }

    private func card(_ p: (String, Color, String, String)) -> some View {
        VStack(spacing: 14) {
            Image(systemName: p.0).font(.system(size: 38, weight: .black)).foregroundStyle(p.1)
                .frame(width: 84, height: 84).background(MD.s2, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: p.1.opacity(0.4), radius: 18)
            Text(p.2).font(rnd(26, .black)).foregroundStyle(Color.white)
            Text(p.3).font(rnd(15)).foregroundStyle(MD.tx2).multilineTextAlignment(.center).lineSpacing(4)
        }
        .padding(22).frame(maxWidth: .infinity)
        .card(MD.s1.opacity(0.92), 28, stroke: p.1.opacity(0.25))
        .padding(.horizontal, 24)
    }
}
