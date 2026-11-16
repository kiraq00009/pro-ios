import SwiftUI
import UIKit

enum TH {
    static let bg = Color(red: 0.045, green: 0.035, blue: 0.075)
    static let s1 = Color(red: 0.090, green: 0.075, blue: 0.135)
    static let s2 = Color(red: 0.140, green: 0.120, blue: 0.200)
    static let s3 = Color(red: 0.205, green: 0.175, blue: 0.285)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.36)
    static let magenta = Color(red: 0.93, green: 0.30, blue: 0.62)
    static let violet = Color(red: 0.55, green: 0.42, blue: 1.0)
    static let mint = Color(red: 0.40, green: 0.98, blue: 0.80)
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.40)
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.45)

    static var grad: LinearGradient {
        LinearGradient(colors: [coral, magenta, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let swatches: [RGBA] = [
        .white, RGBA(0.08, 0.08, 0.1), RGBA(0.96, 0.95, 0.93), RGBA(1, 0.42, 0.36), RGBA(0.93, 0.3, 0.62),
        RGBA(0.55, 0.42, 1), RGBA(0.4, 0.98, 0.8), RGBA(1, 0.82, 0.2), RGBA(0.25, 0.6, 1), RGBA(0.13, 0.75, 0.45),
        RGBA(0.98, 0.6, 0.2), RGBA(0.6, 0.2, 0.25), RGBA(0.12, 0.2, 0.38), RGBA(0.85, 0.8, 0.72),
    ]
    static let gradients: [(RGBA, RGBA, Double)] = [
        (RGBA(0.09, 0.05, 0.2), RGBA(0.95, 0.36, 0.33), 90),
        (RGBA(0.36, 0.25, 0.95), RGBA(0.98, 0.45, 0.6), 135),
        (RGBA(0.05, 0.3, 0.45), RGBA(0.4, 0.98, 0.8), 60),
        (RGBA(1, 0.6, 0.3), RGBA(1, 0.25, 0.45), 120),
        (RGBA(0.06, 0.06, 0.1), RGBA(0.3, 0.3, 0.42), 90),
        (RGBA(0.98, 0.9, 0.75), RGBA(0.9, 0.65, 0.55), 45),
        (RGBA(0.2, 0.45, 0.85), RGBA(0.75, 0.55, 0.95), 70),
        (RGBA(0.1, 0.4, 0.2), RGBA(0.9, 0.95, 0.5), 100),
    ]
    static let floors: [(RGBA, RGBA)] = [
        (RGBA(0.93, 0.93, 0.95), RGBA(1, 1, 1)),
        (RGBA(0.15, 0.15, 0.18), RGBA(0.06, 0.06, 0.08)),
        (RGBA(0.98, 0.88, 0.8), RGBA(0.95, 0.8, 0.7)),
        (RGBA(0.8, 0.88, 0.98), RGBA(0.92, 0.95, 1)),
        (RGBA(0.85, 0.95, 0.88), RGBA(0.95, 1, 0.96)),
    ]
    static let fontTitles = ["عريض", "كلاسيك", "حديث", "نسخ", "مغربي", "فرح", "رشيق"]
    static let fontNames = ["", "", "GeezaPro-Bold", "DecoTypeNaskh", "DiwanMishafi", "Farah", "AlNile-Bold"]

    static func font(_ i: Int, size: CGFloat) -> Font {
        switch i {
        case 0: return .system(size: size, weight: .black, design: .rounded)
        case 1: return .system(size: size, weight: .bold, design: .serif)
        default:
            let n = fontNames[min(fontNames.count - 1, max(0, i))]
            return .custom(n, size: size)
        }
    }
}

extension RGBA {
    var color: Color { Color(red: r, green: g, blue: b, opacity: a) }
    var ui: UIColor { UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a)) }
}

/// اهتزاز يحترم الإعداد
enum HX {
    static var on: Bool { UserDefaults.standard.object(forKey: "th_hx") as? Bool ?? true }
    static func tap() { if on { Haptic.tap() } }
    static func thud() { if on { Haptic.thud() } }
    static func ok() { if on { Haptic.ok() } }
    static func bad() { if on { Haptic.bad() } }
}

/// إحصاءات محفوظة
enum StatBox {
    static func load() -> Stats {
        guard let d = UserDefaults.standard.data(forKey: "th_stats"), let s = try? JSONDecoder().decode(Stats.self, from: d) else { return Stats() }
        return s
    }
    static func update(_ f: (inout Stats) -> Void) {
        var s = load()
        f(&s)
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: "th_stats") }
    }
}

@main
struct ThilApp: App {
    @StateObject private var bank = Bank.shared
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(bank)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(TH.coral)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            TH.bg
            RadialGradient(colors: [TH.violet.opacity(0.30), Color.clear], center: .topLeading, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [TH.coral.opacity(0.18), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }
}

/// زرّ دائريّ صغير للأشرطة
struct RoundBtn: View {
    let icon: String
    var enabled = true
    var tint: Color = .white
    let action: () -> Void
    var body: some View {
        Button(action: { HX.tap(); action() }) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
                .frame(width: 40, height: 40).background(TH.s2, in: Circle())
        }.buttonStyle(Press()).disabled(!enabled).opacity(enabled ? 1 : 0.35)
    }
}

/// زرّ التدرّج الرئيسيّ
struct GradBtn: View {
    let title: String
    let icon: String
    var height: CGFloat = 54
    let action: () -> Void
    var body: some View {
        Button(action: { HX.thud(); action() }) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 16, weight: .black))
                Text(title).font(rnd(17, .black))
            }
            .foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: height)
            .background(TH.grad, in: Capsule())
            .shadow(color: TH.magenta.opacity(0.45), radius: 16, y: 6)
        }.buttonStyle(Press())
    }
}

// MARK: - الشرح الأوّلي

struct OnboardView: View {
    let done: () -> Void
    @State private var page = 0
    private let pages: [(String, String, String)] = [
        ("scissors", "قصّ بلمسة", "اختار صورة، والذكاء يلقط الشخص أو الحيوان أو أيّ غرض ويفصله عن الخلفيّة بثواني — وتگدر تختار أيّ عنصر بنقرة."),
        ("square.stack.3d.up.fill", "استوديو كامل بجيبك", "خلفيّات وتدرّجات وظلال وتوهّج وحدّ ملصق، وطبقات تحرّكها وتكبّرها وتدوّرها بأصابعك، ونصوص عربيّة بخطوط حلوة."),
        ("seal.fill", "ملصقات وبوسترات", "صدّر لصورك أو شارك مباشرة، أو طلّع ملصق شفّاف جاهز للمحادثات. كلّ شي على جهازك وبدون إنترنت."),
    ]
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(0..<pages.count, id: \.self) { i in
                    OnboardPage(icon: pages[i].0, title: pages[i].1, text: pages[i].2).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 7) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule().fill(i == page ? TH.coral : Color.white.opacity(0.2)).frame(width: i == page ? 22 : 7, height: 7)
                }
            }.animation(.spring(response: 0.35), value: page).padding(.bottom, 20)
            GradBtn(title: page == pages.count - 1 ? "يلّا نبدي" : "التالي", icon: page == pages.count - 1 ? "sparkles" : "chevron.left") {
                if page < pages.count - 1 { withAnimation { page += 1 } } else { done() }
            }.padding(.horizontal, 24).padding(.bottom, 26)
        }
        .background(Backdrop())
    }
}

struct OnboardPage: View {
    let icon: String
    let title: String
    let text: String
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(TH.grad).frame(width: 170, height: 170).blur(radius: 40).opacity(0.7).scaleEffect(pulse ? 1.12 : 0.92)
                Circle().fill(TH.s1).frame(width: 150, height: 150).overlay(Circle().stroke(TH.grad, lineWidth: 2))
                Image(systemName: icon).font(.system(size: 58, weight: .black)).foregroundStyle(TH.grad)
            }
            .onAppear { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true } }
            Text(title).font(rnd(30, .black)).foregroundStyle(Color.white)
            Text(text).font(rnd(16)).foregroundStyle(TH.tx2).multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 30)
            Spacer()
        }
    }
}
