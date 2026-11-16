import SwiftUI

enum MT {
    static let bg = Color(red: 0.025, green: 0.035, blue: 0.065)
    static let s1 = Color(red: 0.06, green: 0.075, blue: 0.12)
    static let s2 = Color(red: 0.10, green: 0.12, blue: 0.18)
    static let s3 = Color(red: 0.15, green: 0.17, blue: 0.25)
    static let mint = Color(red: 0.22, green: 0.98, blue: 0.72)
    static let cyan = Color(red: 0.25, green: 0.80, blue: 1.0)
    static let violet = Color(red: 0.58, green: 0.44, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.48, blue: 0.32)
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.30)
    static let red = Color(red: 1.0, green: 0.33, blue: 0.38)
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.45)
    static let ink = Color(red: 0.02, green: 0.06, blue: 0.06)

    static var brand: LinearGradient { LinearGradient(colors: [mint, cyan], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var hot: LinearGradient { LinearGradient(colors: [gold, coral], startPoint: .topLeading, endPoint: .bottomTrailing) }

    static func tone(_ t: Int) -> Color {
        switch t {
        case 0: return mint
        case 1: return cyan
        case 2: return violet
        case 3: return gold
        default: return coral
        }
    }

    static func freshColor(_ tone: Int) -> Color {
        switch tone {
        case 0: return gold
        case 1: return mint
        case 2: return cyan
        case 3: return Color(red: 0.50, green: 0.48, blue: 1.0)
        default: return violet.opacity(0.6)
        }
    }

    static func color(_ a: Activity) -> Color {
        switch a {
        case .walk: return cyan
        case .run: return mint
        case .cycle: return violet
        }
    }
}

struct MBackdrop: View {
    var body: some View {
        ZStack {
            MT.bg
            RadialGradient(colors: [MT.mint.opacity(0.16), Color.clear], center: .topLeading, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [MT.violet.opacity(0.16), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 520)
            HexPattern().opacity(0.05)
        }.ignoresSafeArea()
    }
}

/// نقشة خلايا خفيفة بالخلفيّة — هويّة التطبيق
struct HexPattern: View {
    var size: CGFloat = 26
    var body: some View {
        Canvas { ctx, sz in
            let w = size * sqrt(3)
            let rows = Int(sz.height / (size * 1.5)) + 2
            let cols = Int(sz.width / w) + 2
            for r in 0..<rows {
                for q in 0..<cols {
                    let cx = CGFloat(q) * w + (r % 2 == 0 ? 0 : w / 2)
                    let cy = CGFloat(r) * size * 1.5
                    ctx.stroke(HexShape.path(center: CGPoint(x: cx, y: cy), r: size * 0.92), with: .color(.white), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct HexShape: Shape {
    static func path(center c: CGPoint, r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<6 {
            let a = (Double(i) * 60 - 30) * Double.pi / 180
            let pt = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
    func path(in rect: CGRect) -> Path {
        HexShape.path(center: CGPoint(x: rect.midX, y: rect.midY), r: min(rect.width / sqrt(3) * 1.0, rect.height / 2))
    }
}

/// حلقة تقدّم متدرّجة
struct MRing: View {
    var progress: Double
    var width: CGFloat = 12
    var colors: [Color] = [MT.mint, MT.cyan, MT.mint]
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: width)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0.001, progress))))
                .stroke(AngularGradient(colors: colors, center: .center), style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: colors[0].opacity(0.5), radius: 8)
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    var color: Color = MT.mint
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            Text(value).font(rnd(20, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.55)
                .environment(\.layoutDirection, .leftToRight)
            Text(label).font(rnd(11)).foregroundStyle(MT.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .card(MT.s1, 16, stroke: color.opacity(0.22))
    }
}

struct SectionTitle: View {
    let text: String
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 7) {
            if let i = icon { Image(systemName: i).font(.system(size: 13, weight: .black)).foregroundStyle(MT.mint) }
            Text(text).font(rnd(17, .black)).foregroundStyle(Color.white)
            Spacer()
        }
    }
}

/// صورة مصغّرة للمسار مرسومة بـ Canvas (بلا شبكة)
struct RouteThumb: View {
    let route: [[Coord]]
    var color: Color = MT.mint
    var line: CGFloat = 2.6
    var body: some View {
        Canvas { ctx, size in
            let all = route.flatMap { $0 }
            guard all.count > 1 else { return }
            var minLat = Double.infinity, maxLat = -Double.infinity, minLon = Double.infinity, maxLon = -Double.infinity
            for c in all { minLat = min(minLat, c.lat); maxLat = max(maxLat, c.lat); minLon = min(minLon, c.lon); maxLon = max(maxLon, c.lon) }
            let k = cos((minLat + maxLat) / 2 * Double.pi / 180)
            let w = max(1e-9, (maxLon - minLon) * k), h = max(1e-9, maxLat - minLat)
            let pad: CGFloat = 8
            let sc = min((Double(size.width) - Double(pad) * 2) / w, (Double(size.height) - Double(pad) * 2) / h)
            let ox = (Double(size.width) - w * sc) / 2, oy = (Double(size.height) - h * sc) / 2
            func pt(_ c: Coord) -> CGPoint {
                CGPoint(x: ox + (c.lon - minLon) * k * sc, y: Double(size.height) - oy - (c.lat - minLat) * sc)
            }
            for seg in route where seg.count > 1 {
                var p = Path()
                p.move(to: pt(seg[0]))
                for c in seg.dropFirst() { p.addLine(to: pt(c)) }
                ctx.stroke(p, with: .color(color.opacity(0.25)), style: StrokeStyle(lineWidth: line * 3.2, lineCap: .round, lineJoin: .round))
                ctx.stroke(p, with: .linearGradient(Gradient(colors: [color, MT.cyan]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)),
                           style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            }
            if let f = all.first, let l = all.last {
                let a = pt(f), b = pt(l)
                ctx.fill(Path(ellipseIn: CGRect(x: a.x - 3.5, y: a.y - 3.5, width: 7, height: 7)), with: .color(MT.gold))
                ctx.fill(Path(ellipseIn: CGRect(x: b.x - 3.5, y: b.y - 3.5, width: 7, height: 7)), with: .color(.white))
            }
        }
    }
}

enum Fmt {
    static func km(_ m: Double) -> String { String(format: "%.2f", m / 1000) }
    static func km1(_ m: Double) -> String { String(format: "%.1f", m / 1000) }
    static func area(_ km2: Double) -> String { km2 >= 10 ? String(format: "%.1f", km2) : String(format: "%.2f", km2) }
    static func int(_ v: Double) -> String { "\(Int(v.rounded()))" }

    private static let dayF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f
    }()
    private static let timeF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.setLocalizedDateFormatFromTemplate("h:mm a")
        return f
    }()
    private static let monthF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f
    }()

    static func day(_ t: Double) -> String { dayF.string(from: Date(timeIntervalSince1970: t)) }
    static func time(_ t: Double) -> String { timeF.string(from: Date(timeIntervalSince1970: t)) }
    static func month(_ t: Double) -> String { monthF.string(from: Date(timeIntervalSince1970: t)) }

    static func relDay(_ t: Double, now: Double, tz: Double) -> String {
        let d = Days.index(now, tz: tz) - Days.index(t, tz: tz)
        if d == 0 { return "اليوم" }
        if d == 1 { return "البارحة" }
        if d < 7 { return "قبل \(d) أيّام" }
        return day(t)
    }

    static func partOfDay(_ t: Double, tz: Double) -> String {
        let h = Days.hour(t, tz: tz)
        if h < 5 { return "جولة آخر الليل" }
        if h < 11 { return "جولة الصبح" }
        if h < 16 { return "جولة الظهر" }
        if h < 20 { return "جولة العصر" }
        return "جولة الليل"
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = MT.brand
    let action: () -> Void
    var body: some View {
        Button { Haptic.tap(); action() } label: {
            HStack(spacing: 8) {
                if let i = icon { Image(systemName: i).font(.system(size: 16, weight: .black)) }
                Text(title).font(rnd(18, .black))
            }
            .foregroundStyle(MT.ink).frame(maxWidth: .infinity).frame(height: 56)
            .background(gradient, in: Capsule())
            .shadow(color: MT.mint.opacity(0.35), radius: 16, y: 6)
        }.buttonStyle(Press())
    }
}

struct EmptyCard: View {
    let icon: String
    let title: String
    let sub: String
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                HexShape().fill(MT.mint.opacity(0.12)).frame(width: 86, height: 96)
                HexShape().stroke(MT.mint.opacity(0.5), lineWidth: 1.5).frame(width: 86, height: 96)
                Image(systemName: icon).font(.system(size: 30, weight: .bold)).foregroundStyle(MT.mint)
            }
            Text(title).font(rnd(19, .black)).foregroundStyle(Color.white)
            Text(sub).font(rnd(13.5)).foregroundStyle(MT.tx2).multilineTextAlignment(.center).lineSpacing(3)
        }
        .padding(26).frame(maxWidth: .infinity).card(MT.s1, 24)
    }
}
