import SwiftUI

func rnd(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: s, weight: w, design: .rounded) }
func rnd(_ s: CGFloat, weight: Font.Weight) -> Font { .system(size: s, weight: weight, design: .rounded) }

/// وضع التصوير: المحاكي يشغّل التطبيق بمتغيّر SHOT=اسم_الشاشة حتى نصوّر كلّ شاشة ببيانات تجريبيّة
enum Shot {
    static let name: String = ProcessInfo.processInfo.environment["SHOT"] ?? ""
    static var on: Bool { !name.isEmpty }
    static func isAny(_ s: String...) -> Bool { s.contains(name) }
}

enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func thud() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func ok() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func bad() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// زرّ ينضغط بنعومة
struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.965 : 1).opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func card(_ bg: Color, _ r: CGFloat = 20, stroke: Color = Color(white: 1, opacity: 0.07)) -> some View {
        background(bg, in: RoundedRectangle(cornerRadius: r, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(stroke))
    }
    func card(bg: Color, r: CGFloat = 20, stroke: Color = Color(white: 1, opacity: 0.07)) -> some View { card(bg, r, stroke: stroke) }
    func card(_ bg: Color, r: CGFloat, stroke: Color = Color(white: 1, opacity: 0.07)) -> some View { card(bg, r, stroke: stroke) }
}

func agoText(_ d: Date) -> String {
    let s = Int(Date().timeIntervalSince(d))
    if s < 60 { return "هسه" }; if s < 3600 { return "قبل \(s / 60) د" }; if s < 86400 { return "قبل \(s / 3600) س" }
    if s < 86400 * 30 { return "قبل \(s / 86400) يوم" }
    return d.formatted(date: .abbreviated, time: .omitted)
}
