import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: DozanStore
    @State private var confirmReset = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("إنجازاتي").font(rnd(30, .black)).foregroundStyle(Color.white)
                        Text("تقدّمك وإعداداتك بمكان واحد").font(rnd(12.5)).foregroundStyle(DZ.tx3)
                    }
                    Spacer()
                }
                LevelCard()
                statsGrid
                WeekChart(values: store.weekMinutes())
                rangeCard
                historyCard
                settingsCard
                Text("دوزان يشتغل كامل بدون إنترنت · ما نرسل صوتك لأيّ مكان")
                    .font(rnd(11.5)).foregroundStyle(DZ.tx3).frame(maxWidth: .infinity).padding(.bottom, 10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .confirmationDialog("تصفير كلّ التقدّم؟", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("صفّر النقاط والسجلّ", role: .destructive) { store.resetProgress() }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("راح تنمسح النقاط والنجوم والسلسلة والسجلّ. الإعدادات تبقى.")
        }
    }

    private var statsGrid: some View {
        let mins = Int((store.profile.practiceSec / 60).rounded())
        return VStack(spacing: 9) {
            HStack(spacing: 9) {
                StatTile(value: "\(store.streak)", label: "أيّام متتالية", symbol: "flame.fill", color: DZ.amber)
                StatTile(value: "\(store.bestStreak)", label: "أطول سلسلة", symbol: "crown.fill", color: DZ.violet)
                StatTile(value: "\(store.profile.history.count)", label: "تمرين", symbol: "music.mic", color: DZ.mint)
            }
            HStack(spacing: 9) {
                StatTile(value: "\(mins) د", label: "وقت التمرين", symbol: "clock.fill", color: DZ.sky)
                StatTile(value: "\(store.averageScore)%", label: "معدّل الدقّة", symbol: "scope", color: DZ.mint)
                StatTile(value: "\(store.profile.tuneCount)", label: "وتر انضبط", symbol: "tuningfork", color: DZ.rose)
            }
        }
    }

    private var rangeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.and.mic").font(.system(size: 20, weight: .bold)).foregroundStyle(DZ.sky)
                .frame(width: 48, height: 48).background(DZ.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                if let lo = store.profile.low, let hi = store.profile.high {
                    Text("\(VoiceType.classify(low: lo, high: hi).title) · \(NoteMath.name(lo)) – \(NoteMath.name(hi))").font(rnd(15.5, .heavy)).foregroundStyle(Color.white)
                    Text("\(String(format: "%.1f", Double(hi - lo) / 12)) أوكتاف · \(NoteMath.solfegeName(lo)) ← \(NoteMath.solfegeName(hi))").font(rnd(12)).foregroundStyle(DZ.tx3)
                } else {
                    Text("مداك الصوتي بعده ما انقاس").font(rnd(15.5, .heavy)).foregroundStyle(Color.white)
                    Text("قيسه من تبويب «الغناء»").font(rnd(12)).foregroundStyle(DZ.tx3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .card(DZ.s1, 20)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "آخر التمارين")
            if store.profile.history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list").font(.system(size: 30, weight: .bold)).foregroundStyle(DZ.tx3)
                    Text("بعد ما سوّيت أيّ تمرين — ابدأ بإحماء الخمس نغمات").font(rnd(13)).foregroundStyle(DZ.tx3).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                ForEach(Array(store.profile.history.prefix(8))) { r in
                    HistoryRow(rec: r)
                }
            }
        }
        .padding(14)
        .card(DZ.s1, 22)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "الإعدادات")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("نغمة المرجع A4").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                    Spacer()
                    Text("\(Int(store.settings.a4)) Hz").font(rnd(15, .black)).foregroundStyle(DZ.mint).environment(\.layoutDirection, .leftToRight)
                }
                Slider(value: $store.settings.a4, in: 430...450, step: 1)
                    .tint(DZ.mint)
                    .environment(\.layoutDirection, .leftToRight)
                Text("القياسي 440 · بعض الفرق والأوركسترات تستخدم 442 · و432 للّي يحبّونه").font(rnd(11.5)).foregroundStyle(DZ.tx3)
            }
            optionRow("أسماء النغمات") {
                ChipButton(text: "الاثنين", on: store.settings.naming == 0) { store.settings.naming = 0 }
                ChipButton(text: "C D E", on: store.settings.naming == 1) { store.settings.naming = 1 }
                ChipButton(text: "دو ري مي", on: store.settings.naming == 2) { store.settings.naming = 2 }
            }
            optionRow("دقّة «مضبوط» بالموالف") {
                ForEach([2.0, 3.0, 5.0], id: \.self) { v in
                    ChipButton(text: "±\(Int(v)) سنت", on: store.settings.tolerance == v, color: DZ.violet) { store.settings.tolerance = v }
                }
            }
            optionRow("سماح الغناء") {
                ForEach([35.0, 50.0, 70.0], id: \.self) { v in
                    ChipButton(text: v == 35 ? "صارم" : (v == 50 ? "عادي" : "مريح"), on: store.settings.singTolerance == v, color: DZ.sky) { store.settings.singTolerance = v }
                }
            }
            Toggle(isOn: $store.settings.octaveFree) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("تجاهل فرق الأوكتاف").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                    Text("تگدر تغنّي أوطى أو أعلى بأوكتاف وتنحسب صحّ").font(rnd(11.5)).foregroundStyle(DZ.tx3)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: DZ.mint))
            Toggle(isOn: $store.settings.haptics) {
                Text("اهتزاز عند الضبط والنتائج").font(rnd(14, .heavy)).foregroundStyle(Color.white)
            }
            .toggleStyle(SwitchToggleStyle(tint: DZ.mint))
            Button { confirmReset = true } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("تصفير التقدّم").font(rnd(14, .heavy))
                }
                .foregroundStyle(DZ.rose).frame(maxWidth: .infinity).frame(height: 46)
                .background(DZ.rose.opacity(0.12), in: Capsule())
            }
            .buttonStyle(Press())
        }
        .padding(14)
        .card(DZ.s1, 22)
    }

    private func optionRow<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(rnd(14, .heavy)).foregroundStyle(Color.white)
            HStack(spacing: 8) { content() }
        }
    }
}

struct HistoryRow: View {
    let rec: SessionRecord
    var body: some View {
        HStack(spacing: 11) {
            Text("\(rec.percent)%")
                .font(rnd(15, .black)).foregroundStyle(Color.black.opacity(0.85))
                .frame(width: 54, height: 40)
                .background(DZ.pitchColor(Double(100 - rec.percent) / 2, tol: 7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .environment(\.layoutDirection, .leftToRight)
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.title).font(rnd(14.5, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                Text(agoText(rec.date) + " · +\(rec.xp) نقطة").font(rnd(11.5)).foregroundStyle(DZ.tx3)
            }
            Spacer(minLength: 0)
            StarsRow(count: rec.stars, size: 10)
        }
    }
}

/// دقائق التمرين لآخر أسبوع
struct WeekChart: View {
    let values: [Double]
    private let labels = ["قبل ٦", "قبل ٥", "قبل ٤", "قبل ٣", "قبل يومين", "البارحة", "اليوم"]

    var body: some View {
        let mx = max(1, values.max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: "هذا الأسبوع")
                Text(String(format: "%.0f د", values.reduce(0, +))).font(rnd(15, .black)).foregroundStyle(DZ.mint)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<values.count, id: \.self) { i in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(i == values.count - 1 ? AnyShapeStyle(DZ.grad) : AnyShapeStyle(DZ.violet.opacity(0.55)))
                            .frame(height: max(6, CGFloat(values[i] / mx) * 96))
                        Text(i < labels.count ? labels[i] : "").font(rnd(8.5, .bold)).foregroundStyle(DZ.tx3).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120, alignment: .bottom)
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(14)
        .card(DZ.s1, 22)
    }
}

struct OnboardingView: View {
    let done: () -> Void
    @EnvironmentObject var store: DozanStore
    @EnvironmentObject var mic: MicPitch
    @State private var page = 0

    private let pages: [(String, String, String, Color)] = [
        ("tuningfork", "موالف احترافي", "إبرة دقيقة وشريط ستروب، أسماء غربيّة وعربيّة، وقوالب جاهزة للجيتار والباص والعود والكمان واليوكوليلي.", DZ.mint),
        ("music.mic", "درّب صوتك", "غنّي فوق خطّ اللحن وشوف صوتك يرسم بالألوان لحظة بلحظة، وخذ تقييم دقيق بعد كلّ تمرين.", DZ.sky),
        ("chart.line.uptrend.xyaxis", "تقدّم كلّ يوم", "مستويات ونجوم وسلسلة أيّام، ومكتشف مداك الصوتي يختار نغمة البداية المناسبة إلك.", DZ.violet),
    ]

    var body: some View {
        ZStack {
            DZBackdrop(accent: pages[page].3)
            VStack(spacing: 22) {
                Spacer()
                ZStack {
                    Circle().fill(pages[page].3.opacity(0.16)).frame(width: 190, height: 190)
                    Circle().stroke(pages[page].3.opacity(0.45), lineWidth: 2).frame(width: 150, height: 150)
                    Image(systemName: pages[page].0).font(.system(size: 66, weight: .bold)).foregroundStyle(pages[page].3)
                        .shadow(color: pages[page].3.opacity(0.7), radius: 22)
                }
                .id(page)
                .transition(.scale.combined(with: .opacity))
                Text(pages[page].1).font(rnd(32, .black)).foregroundStyle(Color.white)
                Text(pages[page].2).font(rnd(16)).foregroundStyle(DZ.tx2).multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 26)
                HStack(spacing: 7) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule().fill(i == page ? pages[page].3 : DZ.s3).frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                Spacer()
                GlowButton(title: page < pages.count - 1 ? "التالي" : "اسمح بالمايك وابدأ", symbol: page < pages.count - 1 ? "chevron.left" : "mic.fill") {
                    Haptic.tap()
                    if page < pages.count - 1 {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { page += 1 }
                    } else {
                        finish()
                    }
                }
                .padding(.horizontal, 22)
                Button("تخطّي") { finish() }
                    .font(rnd(14, .heavy)).foregroundStyle(DZ.tx3)
                    .padding(.bottom, 20)
            }
        }
    }

    private func finish() {
        if Shot.on { done(); return }
        mic.requestPermission { _ in
            store.profile.onboarded = true
            done()
        }
    }
}
