import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var live: Live
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sm_onboarded") private var onboarded = false
    @State private var confirmAll = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("الإعدادات").font(rnd(28, .black)).foregroundStyle(Color.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color.white)
                            .frame(width: 40, height: 40).background(SM.s2, in: Circle())
                    }.buttonStyle(Press())
                }
                VStack(spacing: 0) {
                    ToggleRow(icon: "play.circle.fill", title: "ابدأ الاستماع لمّا أفتح التطبيق", on: $store.autoStart)
                    Divider().overlay(SM.line)
                    ToggleRow(icon: "waveform.badge.plus", title: "احفظ مقطع ٦ ثواني مع كلّ تنبيه وحدث نوم", on: $store.saveClips)
                    Divider().overlay(SM.line)
                    ToggleRow(icon: "sun.max.fill", title: "خلّي الشاشة شغّالة بوضع النوم", on: $store.keepAwake)
                }
                .padding(.horizontal, 14).card(SM.s1, 22)

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "معايرة الديسيبل", icon: "tuningfork")
                    Text("كلّ آيفون مايكه يختلف شوي. إذا عندك مقياس صوت، طابق القراءة عليه. الافتراضي ٩٥.").font(rnd(12.5)).foregroundStyle(SM.tx2)
                    HStack {
                        Text("\(Int(store.calib))").font(rnd(20, .black)).foregroundStyle(SM.sonar).frame(width: 46)
                        Slider(value: $store.calib, in: 80...110, step: 1).tint(SM.sonar)
                    }
                    HStack {
                        Text("القراءة الحاليّة").font(rnd(12.5)).foregroundStyle(SM.tx3)
                        Spacer()
                        Text(store.running ? "\(Int(live.db.rounded())) dB" : "—").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                        Button { store.calib = 95; Haptic.tap() } label: {
                            Text("رجّع الافتراضي").font(rnd(12, .heavy)).foregroundStyle(SM.sonar)
                        }.padding(.leading, 10)
                    }
                }
                .padding(16).card(SM.s1, 22)

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "بياناتك", icon: "externaldrive.fill")
                    HStack(spacing: 10) {
                        StatTile(value: "\(store.events.count)", label: "حدث")
                        StatTile(value: "\(store.alerts.count)", label: "تنبيه", color: SM.coral)
                        StatTile(value: "\(store.nights.count)", label: "ليلة", color: SM.moon)
                    }
                    Text("كلّ شي محفوظ على جهازك فقط. سَمَع ما يرفع أيّ صوت لأيّ مكان، والتعرّف يصير بالكامل داخل الآيفون.")
                        .font(rnd(12)).foregroundStyle(SM.tx3)
                    Button { confirmAll = true } label: {
                        Text("امسح كلّ البيانات والمقاطع").font(rnd(14, .heavy)).foregroundStyle(SM.coral)
                            .frame(maxWidth: .infinity).frame(height: 46).background(SM.coral.opacity(0.12), in: Capsule())
                    }.buttonStyle(Press())
                }
                .padding(16).card(SM.s1, 22)

                Button {
                    dismiss()
                    onboarded = false
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("شوف الجولة التعريفيّة من جديد").font(rnd(14, .heavy))
                        Spacer()
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(Color.white).padding(16).card(SM.s1, 20)
                }.buttonStyle(Press())

                Text("سَمَع ١.٠ · يميّز أكثر من ٣٠٠ صوت بدون إنترنت").font(rnd(11.5)).foregroundStyle(SM.tx3).frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .background(Backdrop())
        .confirmationDialog("نمسح كلّشي؟ ما يرجع.", isPresented: $confirmAll, titleVisibility: .visible) {
            Button("امسح الكلّ", role: .destructive) { store.clearAll(); Haptic.thud() }
            Button("لا", role: .cancel) {}
        }
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var on: Bool
    var body: some View {
        Toggle(isOn: $on) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(SM.sonar).frame(width: 26)
                Text(title).font(rnd(14, .bold)).foregroundStyle(Color.white)
            }
        }
        .tint(SM.sonar)
        .padding(.vertical, 12)
    }
}

// MARK: الجولة التعريفيّة

struct OnboardView: View {
    @EnvironmentObject var store: Store
    let done: () -> Void
    @State private var page = 0
    @State private var asking = false

    private let pages: [(String, String, String, Color)] = [
        ("📡", "رادار للأصوات من حولك", "سَمَع يميّز مئات الأصوات لحظة بلحظة: كلام، موسيقى، نباح، جرس، ماء، سيارات… ويعرض أقوى خمسة على رادار حيّ مع نسبة التأكّد.", SM.sonar),
        ("🔔", "ينبّهك على المهمّ", "اختار أصوات مثل بكاء الطفل، جرس الباب، إنذار الدخان أو كسر زجاج — وأوّل ما ينسمع، الشاشة تومض والآيفون يهتزّ بقوّة.", SM.coral),
        ("🌙", "يراقب ليلتك", "بوضع النوم يسجّل الشخير والكحّة والكلام مع وقتها، ويحفظ مقاطع قصيرة تسمعها الصبح، ويعطيك درجة هدوء لكلّ ليلة.", SM.moon),
    ]

    var body: some View {
        let p = pages[page]
        ZStack {
            Backdrop(tint: p.3)
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button { done() } label: { Text("تخطّي").font(rnd(14, .bold)).foregroundStyle(SM.tx3) }
                    }
                }
                .frame(height: 30)
                Spacer()
                OnboardOrb(emoji: p.0, color: p.3).id(page).transition(.scale(scale: 0.6).combined(with: .opacity))
                VStack(spacing: 12) {
                    Text(p.1).font(rnd(28, .black)).foregroundStyle(Color.white).multilineTextAlignment(.center)
                    Text(p.2).font(rnd(15)).foregroundStyle(SM.tx2).multilineTextAlignment(.center).lineSpacing(4)
                }
                .id("t\(page)")
                .transition(.opacity)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule().fill(i == page ? p.3 : SM.s3).frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                if page == pages.count - 1 {
                    Text("🔒 كلّ شي يصير على جهازك. ما نسجّل ولا نرفع شي إلّا المقاطع القصيرة اللي تنحفظ عندك.")
                        .font(rnd(12)).foregroundStyle(SM.tx3).multilineTextAlignment(.center)
                }
                Button { next() } label: {
                    HStack(spacing: 8) {
                        if asking { ProgressView().tint(Color.black) }
                        Text(page < pages.count - 1 ? "التالي" : "اسمح بالمايك وابدأ").font(rnd(18, .black))
                    }
                    .foregroundStyle(Color.black.opacity(0.85)).frame(maxWidth: .infinity).frame(height: 58)
                    .background(p.3, in: Capsule())
                    .shadow(color: p.3.opacity(0.4), radius: 16, y: 6)
                }.buttonStyle(Press())
            }
            .padding(24)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: page)
    }

    private func next() {
        Haptic.tap()
        if page < pages.count - 1 { page += 1; return }
        if asking { return }
        asking = true
        Mic.request { ok in
            Task { @MainActor in
                asking = false
                store.mic = ok ? .granted : .denied
                if ok { store.start() }
                done()
            }
        }
    }
}

struct OnboardOrb: View {
    let emoji: String
    let color: Color
    var body: some View {
        TimelineView(.animation) { ctx in
            let t: Double = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let ph: Double = (t / 2.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Circle().stroke(color.opacity(0.5 * (1 - ph)), lineWidth: 2)
                        .frame(width: 140, height: 140).scaleEffect(CGFloat(0.8 + ph * 1.0))
                }
                Circle().fill(RadialGradient(colors: [color.opacity(0.35), color.opacity(0.05)], center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 150, height: 150)
                Text(emoji).font(.system(size: 76)).offset(y: CGFloat(sin(t * 2) * 4))
            }
            .frame(width: 280, height: 260)
        }
    }
}
