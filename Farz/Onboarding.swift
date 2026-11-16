import SwiftUI
import UIKit

// MARK: - الترحيب

struct FZOnboarding: View {
    @EnvironmentObject var lib: FZLibrary
    @State private var page = 0
    @State private var float = false

    private struct Page {
        let icon: String
        let color: Color
        let title: String
        let note: String
    }

    private let pages: [Page] = [
        Page(icon: "sparkles", color: FZ.mint, title: "رجّع مساحتك", note: "فرز يفحص مكتبة صورك ويلقى المكرّر والمشوّش ولقطات الشاشة والفيديوهات الثقيلة — ويقلّك كم غيغا تقدر توفّر."),
        Page(icon: "hand.draw.fill", color: FZ.pink, title: "اسحب وخلّص", note: "يسار للحذف، يمين للإبقاء. مراجعة بطاقات سريعة وممتعة مع عدّاد يورّيك المساحة اللي راح ترجع."),
        Page(icon: "lock.shield.fill", color: FZ.violet, title: "خصوصيّتك أوّلًا", note: "كلّ التحليل على جهازك. ما نرفع ولا صورة، وما نحذف شي بدون نافذة تأكيد النظام."),
    ]

    var body: some View {
        ZStack {
            FZBackdrop()
            VStack(spacing: 20) {
                HStack {
                    Text("فرز").font(rnd(26, .black)).foregroundStyle(FZ.brand)
                    Spacer()
                    if page < pages.count - 1 {
                        Button("تخطّي") { withAnimation { page = pages.count - 1 } }.font(rnd(14, .bold)).foregroundStyle(FZ.tx3)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 10)
                TabView(selection: $page) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        pageView(pages[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                dots
                VStack(spacing: 12) {
                    if page < pages.count - 1 {
                        FZPrimaryButton(title: "التالي", icon: "chevron.left") { withAnimation { page += 1 } }
                    } else {
                        FZPrimaryButton(title: "اسمح بالوصول للصور", icon: "photo.on.rectangle.angled") { lib.requestAccess() }
                        Button { Haptic.tap(); lib.startDemo() } label: {
                            Text("جرّب أوّلًا بمكتبة تجريبيّة").font(rnd(14.5, .heavy)).foregroundStyle(FZ.mint)
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, 18)
            }
        }
        .onAppear { float = true }
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(p.color.opacity(0.12)).frame(width: 230, height: 230).blur(radius: 6)
                Circle().stroke(p.color.opacity(0.25), lineWidth: 1.5).frame(width: 270, height: 270)
                ForEach(0..<5, id: \.self) { k in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(FZ.color(FZCat.allCases[k]).opacity(0.85))
                        .frame(width: 44, height: 56)
                        .rotationEffect(.degrees(Double(k) * 14 - 28))
                        .offset(x: CGFloat(k - 2) * 46, y: (float ? -6 : 6) * (k % 2 == 0 ? 1 : -1) + 96)
                        .animation(.easeInOut(duration: 2 + Double(k) * 0.2).repeatForever(autoreverses: true), value: float)
                }
                Image(systemName: p.icon).font(.system(size: 76, weight: .bold)).foregroundStyle(p.color)
                    .shadow(color: p.color.opacity(0.6), radius: 24)
                    .offset(y: float ? -8 : 4)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: float)
            }
            .frame(height: 300)
            VStack(spacing: 10) {
                Text(p.title).font(rnd(30, .black)).foregroundStyle(Color.white)
                Text(p.note).font(rnd(15.5)).foregroundStyle(FZ.tx2).multilineTextAlignment(.center).lineSpacing(4)
                    .padding(.horizontal, 26)
            }
            Spacer(minLength: 0)
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule().fill(i == page ? FZ.mint : FZ.s3).frame(width: i == page ? 26 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35), value: page)
    }
}

struct FZDenied: View {
    @EnvironmentObject var lib: FZLibrary
    var body: some View {
        ZStack {
            FZBackdrop()
            VStack(spacing: 18) {
                Spacer()
                FZEmpty(icon: "photo.badge.exclamationmark", title: "نحتاج نشوف صورك", note: "حتى يفحص فرز مكتبتك لازم تسمحله بالوصول للصور من الإعدادات. التحليل كلّه على جهازك وما يطلع شي منه.")
                Spacer()
                FZPrimaryButton(title: "افتح الإعدادات", icon: "gearshape.fill") {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }
                FZPrimaryButton(title: "جرّب بمكتبة تجريبيّة", icon: "sparkles", style: 2) { lib.startDemo() }
                Button("حاول مرّة ثانية") { lib.requestAccess() }.font(rnd(14, .bold)).foregroundStyle(FZ.tx3).padding(.bottom, 10)
            }
            .padding(22)
        }
    }
}

// MARK: - الإعدادات

struct FZSettings: View {
    @EnvironmentObject var lib: FZLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var initialSimilarity = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("الإعدادات").font(rnd(28, .black)).foregroundStyle(Color.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color.white)
                            .frame(width: 38, height: 38).background(FZ.s2, in: Circle())
                    }.buttonStyle(Press())
                }.padding(.top, 14)

                section("square.on.square", FZ.violet, "دقّة التشابه", "صارم = بس النسخ شبه المتطابقة · واسع = حتى اللقطات القريبة") {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            FZChip(title: FZRules.similarityNames[i], on: lib.rules.similarity == i, color: FZ.violet) { lib.rules.similarity = i }
                        }
                    }
                    if lib.rules.similarity != initialSimilarity {
                        Text("يحتاج فحص جديد حتى ينطبق").font(rnd(11.5, .bold)).foregroundStyle(FZ.amber)
                    }
                }
                section("camera.aperture", FZ.sky, "كشف التشويش", "قويّ = يمسك حتى التشويش الخفيف") {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            FZChip(title: FZRules.blurNames[i], on: lib.rules.blurLevel == i, color: FZ.sky) { lib.rules.blurLevel = i }
                        }
                    }
                }
                section("video.fill", FZ.coral, "الفيديو الكبير من", "الفيديوهات الأكبر من هذا الحجم تظهر بالقسم") {
                    HStack(spacing: 8) {
                        ForEach(FZRules.videoSteps, id: \.self) { v in
                            FZChip(title: "\(v) ميغا", on: lib.rules.bigVideoMB == v, color: FZ.coral) { lib.rules.bigVideoMB = v }
                        }
                    }
                }
                section("arrowshape.turn.up.right.fill", FZ.green, "الصور المُعاد توجيهها", "نعرض بس الأقدم من") {
                    HStack(spacing: 8) {
                        ForEach(FZRules.ageSteps, id: \.self) { d in
                            FZChip(title: ageTitle(d), on: lib.rules.forwardedDays == d, color: FZ.green) { lib.rules.forwardedDays = d }
                        }
                    }
                }
                Toggle(isOn: Binding(get: { lib.rules.protectFavorites }, set: { lib.rules.protectFavorites = $0 })) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("احمِ المفضّلة").font(rnd(15.5, .heavy)).foregroundStyle(Color.white)
                        Text("الصور اللي عليها قلب ما تنعرض للحذف أبدًا").font(rnd(12)).foregroundStyle(FZ.tx3)
                    }
                }
                .tint(FZ.mint)
                .padding(16).card(FZ.s1, 20)

                VStack(spacing: 10) {
                    FZPrimaryButton(title: "أعد الفحص الآن", icon: "arrow.triangle.2.circlepath") {
                        dismiss()
                        lib.startScan()
                    }
                    FZPrimaryButton(title: "صفّر الإحصاءات", icon: "arrow.counterclockwise", style: 2) { confirmReset = true }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("كيف يشتغل فرز؟", systemImage: "info.circle.fill").font(rnd(15, .heavy)).foregroundStyle(FZ.mint)
                    Text("• المتشابهة: بصمة Vision لكلّ صورة، ونقارن الصور القريبة بالوقت ونجمعها، ونختار الأوضح والأكثر وجوهًا.\n• المشوّشة: تباين لابلاس على نسخة رماديّة صغيرة — رقم واطي يعني حواف ناعمة.\n• الحذف دائمًا عبر نافذة النظام، والمحذوف يبقى 30 يوم بـ«المحذوفة مؤخّرًا».")
                        .font(rnd(12.5)).foregroundStyle(FZ.tx2).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
                .padding(16).card(FZ.s1, 20)

                Text("فرز 1.0 · بدون إعلانات وبدون إنترنت").font(rnd(11.5)).foregroundStyle(FZ.tx3).frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .background(FZ.bg.ignoresSafeArea())
        .onAppear { initialSimilarity = lib.rules.similarity }
        .alert("تصفير الإحصاءات؟", isPresented: $confirmReset) {
            Button("صفّر", role: .destructive) { lib.resetLedger(); Haptic.bad() }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("راح تنمسح السلسلة والأوسمة والمساحة اللي وفّرتها. صورك ما تتأثّر.")
        }
    }

    private func ageTitle(_ d: Int) -> String {
        switch d {
        case 30: return "شهر"
        case 60: return "شهرين"
        case 180: return "6 أشهر"
        case 365: return "سنة"
        default: return "\(d) يوم"
        }
    }

    private func section<C: View>(_ icon: String, _ c: Color, _ title: String, _ note: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                FZIconBadge(icon: icon, color: c, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(rnd(15.5, .heavy)).foregroundStyle(Color.white)
                    Text(note).font(rnd(11.5)).foregroundStyle(FZ.tx3).fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .padding(16)
        .card(FZ.s1, 20)
    }
}

// MARK: - الاحتفال بعد التنظيف

struct FZCelebrationLayer: View {
    @EnvironmentObject var lib: FZLibrary
    var body: some View {
        ZStack {
            if let c = lib.celebration {
                FZCelebrationView(c: c) { lib.celebration = nil }
                    .id(c.id)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: lib.celebration)
        .allowsHitTesting(lib.celebration != nil)
    }
}

struct FZCelebrationView: View {
    let c: FZCelebration
    let done: () -> Void
    @State private var start = Date()
    @State private var pop = false

    private struct Bit {
        let x: Double, vx: Double, vy: Double, spin: Double, size: Double, hue: Int
    }

    private let bits: [Bit] = {
        var r = FZRand(UInt64(Int.random(in: 1...9999)))
        return (0..<90).map { _ in
            Bit(x: r.range(0.1, 0.9), vx: r.range(-0.35, 0.35), vy: r.range(-1.35, -0.7), spin: r.range(-6, 6), size: r.range(6, 13), hue: r.int(0, 5))
        }
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(start)
                    for b in bits {
                        let px = (b.x + b.vx * t) * Double(size.width)
                        let py = Double(size.height) * (0.62 + b.vy * t + 0.55 * t * t)
                        let rect = CGRect(x: px, y: py, width: b.size, height: b.size * 0.55)
                        var cx = ctx
                        cx.translateBy(x: rect.midX, y: rect.midY)
                        cx.rotate(by: .radians(b.spin * t))
                        cx.fill(Path(roundedRect: CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height), cornerRadius: 2),
                                with: .color(FZ.color(FZCat.allCases[b.hue])))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            VStack(spacing: 10) {
                Image(systemName: c.converted ? "livephoto.slash" : "sparkles").font(.system(size: 54, weight: .black)).foregroundStyle(FZ.brand)
                Text(c.converted ? "تحوّلت!" : "تمّ التنظيف!").font(rnd(30, .black)).foregroundStyle(Color.white)
                FZSizeText(bytes: c.bytes, size: 50, color: FZ.mint)
                Text("رجعت لجهازك من \(FZFormat.items(c.count))").font(rnd(14, .bold)).foregroundStyle(FZ.tx2)
                Button { done() } label: {
                    Text("حلو!").font(rnd(17, .black)).foregroundStyle(Color.black.opacity(0.85))
                        .padding(.horizontal, 40).frame(height: 50).background(FZ.brand, in: Capsule())
                }.buttonStyle(Press()).padding(.top, 8)
            }
            .padding(28)
            .background(FZ.s1, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(FZ.mint.opacity(0.3)))
            .shadow(color: FZ.mint.opacity(0.25), radius: 30)
            .scaleEffect(pop ? 1 : 0.7)
            .opacity(pop ? 1 : 0)
        }
        .onAppear {
            start = Date()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { pop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { done() }
        }
    }
}
