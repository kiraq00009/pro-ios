import SwiftUI
import UIKit

enum FZ {
    static let bg = Color(red: 0.035, green: 0.03, blue: 0.075)
    static let s1 = Color(red: 0.075, green: 0.066, blue: 0.14)
    static let s2 = Color(red: 0.12, green: 0.106, blue: 0.21)
    static let s3 = Color(red: 0.17, green: 0.15, blue: 0.29)
    static let mint = Color(red: 0.22, green: 0.98, blue: 0.78)
    static let sky = Color(red: 0.32, green: 0.66, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.33, blue: 0.62)
    static let violet = Color(red: 0.62, green: 0.46, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.3)
    static let coral = Color(red: 1.0, green: 0.43, blue: 0.4)
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.36)
    static let green = Color(red: 0.32, green: 0.9, blue: 0.5)
    static let danger = Color(red: 1.0, green: 0.32, blue: 0.4)
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.45)

    static func color(_ c: FZCat) -> Color {
        switch c {
        case .similar: return violet
        case .blurry: return sky
        case .screenshots: return amber
        case .videos: return coral
        case .live: return lime
        case .forwarded: return green
        }
    }

    static var brand: LinearGradient {
        LinearGradient(colors: [mint, sky], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var hot: LinearGradient {
        LinearGradient(colors: [pink, coral], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

@main
struct FarzApp: App {
    @StateObject private var lib = FZLibrary()
    var body: some Scene {
        WindowGroup {
            FZRoot().environmentObject(lib)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(FZ.mint)
        }
    }
}

struct FZBackdrop: View {
    var body: some View {
        ZStack {
            FZ.bg
            RadialGradient(colors: [FZ.violet.opacity(0.32), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [FZ.mint.opacity(0.13), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }
}

struct FZRoot: View {
    @EnvironmentObject var lib: FZLibrary
    var body: some View {
        ZStack {
            switch lib.phase {
            case .onboarding:
                FZOnboarding().transition(.opacity)
            case .denied:
                FZDenied().transition(.opacity)
            case .main:
                FZMain().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: lib.phase)
        .onAppear { lib.boot() }
    }
}

enum FZRoute: Hashable {
    case cat(FZCat)
    case stats
}

struct FZMain: View {
    @EnvironmentObject var lib: FZLibrary
    @State private var path: [FZRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            FZHome(path: $path)
                .navigationDestination(for: FZRoute.self) { r in
                    destination(r)
                }
        }
        .overlay(alignment: .top) { FZToastView() }
        .overlay { FZCelebrationLayer() }
        .fullScreenCover(isPresented: scanBinding) {
            FZScanView().environmentObject(lib)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $lib.deck) { req in
            FZSwipeView(req: req).environmentObject(lib)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .onAppear {
            if Shot.name == "similar" { path = [.cat(.similar)] }
            else if Shot.name == "videos" { path = [.cat(.videos)] }
            else if Shot.name == "stats" { path = [.stats] }
            else if Shot.name == "swipe" { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { lib.startQuickDeck() } }
        }
    }

    private var scanBinding: Binding<Bool> {
        Binding(get: { lib.isScanning }, set: { _ in })
    }

    @ViewBuilder
    private func destination(_ r: FZRoute) -> some View {
        switch r {
        case .cat(let c):
            if c == .similar { FZSimilarView() } else { FZGridView(cat: c) }
        case .stats:
            FZStatsView()
        }
    }
}

// MARK: - عناصر مشتركة

struct FZToastView: View {
    @EnvironmentObject var lib: FZLibrary
    var body: some View {
        Group {
            if let t = lib.toast {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(FZ.mint)
                    Text(t).font(rnd(14, .bold)).foregroundStyle(Color.white).multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(FZ.s2, in: Capsule())
                .overlay(Capsule().stroke(FZ.mint.opacity(0.3)))
                .shadow(color: Color.black.opacity(0.4), radius: 14, y: 6)
                .padding(.top, 8).padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { lib.toast = nil }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: lib.toast)
    }
}

struct FZPrimaryButton: View {
    let title: String
    var icon: String = ""
    var style: Int = 0      // 0 مُنعش · 1 حذف · 2 هادئ
    var busy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.thud(); action() }) {
            HStack(spacing: 9) {
                if busy {
                    ProgressView().tint(style == 2 ? Color.white : Color.black)
                } else if !icon.isEmpty {
                    Image(systemName: icon).font(.system(size: 16, weight: .black))
                }
                Text(title).font(rnd(17, .black)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(style == 2 ? Color.white : Color.black.opacity(0.85))
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(bg, in: Capsule())
            .shadow(color: glow.opacity(style == 2 ? 0 : 0.45), radius: 16, y: 6)
        }
        .buttonStyle(Press())
        .disabled(busy)
    }

    private var bg: AnyShapeStyle {
        switch style {
        case 1: return AnyShapeStyle(FZ.hot)
        case 2: return AnyShapeStyle(FZ.s2)
        default: return AnyShapeStyle(FZ.brand)
        }
    }
    private var glow: Color { style == 1 ? FZ.pink : FZ.mint }
}

struct FZChip: View {
    let title: String
    let on: Bool
    var color: Color = FZ.mint
    let action: () -> Void
    var body: some View {
        Button { Haptic.tap(); action() } label: {
            Text(title).font(rnd(13.5, .heavy))
                .foregroundStyle(on ? Color.black.opacity(0.85) : Color.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 12).frame(maxWidth: .infinity).frame(height: 40)
                .background(on ? color : FZ.s2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }.buttonStyle(Press())
    }
}

struct FZIconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: icon).font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

/// رقم الحجم الكبير بوحدته
struct FZSizeText: View {
    let bytes: Int64
    var size: CGFloat = 40
    var color: Color = .white
    var body: some View {
        let p = FZFormat.sizeParts(bytes)
        return HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(p.0).font(rnd(size, .black)).foregroundStyle(color)
            Text(p.1).font(rnd(size * 0.42, .heavy)).foregroundStyle(color.opacity(0.75))
        }
        .lineLimit(1).minimumScaleFactor(0.5)
    }
}

/// بطاقة فارغة لطيفة
struct FZEmpty: View {
    let icon: String
    let title: String
    let note: String
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(FZ.mint.opacity(0.1)).frame(width: 120, height: 120)
                Circle().stroke(FZ.mint.opacity(0.25), lineWidth: 1.5).frame(width: 150, height: 150)
                Image(systemName: icon).font(.system(size: 46, weight: .bold)).foregroundStyle(FZ.brand)
            }
            Text(title).font(rnd(22, .black)).foregroundStyle(Color.white)
            Text(note).font(rnd(14)).foregroundStyle(FZ.tx2).multilineTextAlignment(.center).lineSpacing(3)
        }
        .padding(.vertical, 40).padding(.horizontal, 24).frame(maxWidth: .infinity)
    }
}

extension Date {
    var fzShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: self)
    }
}

extension FZAsset {
    var date: Date { Date(timeIntervalSince1970: created) }
}
