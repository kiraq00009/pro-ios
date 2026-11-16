import SwiftUI
import UIKit

/// رسم التصميم كامل بحجم معيّن — نفس الكود للمعاينة والتصدير
struct StageView: View {
    let project: Project
    let size: CGSize
    var selected: String? = nil
    var export: Bool = false
    var tick: Int = 0
    var guideX = false
    var guideY = false

    var body: some View {
        ZStack {
            BkgView(bkg: project.bkg, size: size, export: export, tick: tick)
            ForEach(project.layers) { l in
                if !l.hidden {
                    LayerView(layer: l, W: size.width, H: size.height, tick: tick)
                }
            }
            if !export {
                GuideLines(size: size, x: guideX, y: guideY)
                if let s = selected, let l = project.layer(s) {
                    SelBox(layer: l, W: size.width, H: size.height)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct GuideLines: View {
    let size: CGSize
    let x: Bool
    let y: Bool
    var body: some View {
        ZStack {
            if x { Rectangle().fill(TH.mint).frame(width: 1.5, height: size.height).position(x: size.width / 2, y: size.height / 2) }
            if y { Rectangle().fill(TH.mint).frame(width: size.width, height: 1.5).position(x: size.width / 2, y: size.height / 2) }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

struct Checker: View {
    var body: some View {
        Canvas { ctx, sz in
            let s: CGFloat = 14
            let cols = Int(ceil(sz.width / s)), rows = Int(ceil(sz.height / s))
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(Color(white: 0.82)))
            for r in 0..<rows {
                for c in 0..<cols where (r + c) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s, height: s)), with: .color(Color(white: 0.67)))
                }
            }
        }
    }
}

struct BkgView: View {
    let bkg: Bkg
    let size: CGSize
    let export: Bool
    let tick: Int

    var body: some View {
        switch bkg {
        case .clear:
            if export { Color.clear } else { Checker() }
        case .solid(let c):
            c.color
        case .gradient(let a, let b, let deg):
            gradient(a, b, deg)
        case .blurPhoto(let id, let r):
            photo(Bank.shared.blurred(id, r) ?? Bank.shared.image(id), dim: 0.12)
        case .photo(let id):
            photo(Bank.shared.image(id), dim: 0)
        case .floor(let wall, let fl, let hz):
            floorView(wall, fl, hz)
        }
    }

    private func gradient(_ a: RGBA, _ b: RGBA, _ deg: Double) -> some View {
        let pts = Bkg.gradientPoints(deg)
        return LinearGradient(colors: [a.color, b.color], startPoint: UnitPoint(x: pts.0.x, y: pts.0.y), endPoint: UnitPoint(x: pts.1.x, y: pts.1.y))
    }

    @ViewBuilder private func photo(_ img: UIImage?, dim: Double) -> some View {
        if let img {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .overlay(Color.black.opacity(dim))
        } else {
            TH.s2
        }
    }

    private func floorView(_ wall: RGBA, _ fl: RGBA, _ hz: Double) -> some View {
        let h1 = size.height * CGFloat(Fit.clamp(hz, 0.1, 0.95))
        return VStack(spacing: 0) {
            LinearGradient(colors: [wall.mix(.white, 0.25).color, wall.color], startPoint: .top, endPoint: .bottom).frame(height: h1)
            ZStack(alignment: .top) {
                LinearGradient(colors: [fl.color, fl.mix(.black, 0.08).color], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [Color.black.opacity(0.10), Color.clear], startPoint: .top, endPoint: .bottom).frame(height: size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

struct LayerView: View {
    let layer: Layer
    let W: CGFloat
    let H: CGFloat
    let tick: Int

    var body: some View {
        let w = CGFloat(layer.xf.scale) * W
        let h = w * CGFloat(layer.hOverW)
        content(w: w, h: h)
            .rotationEffect(.radians(layer.xf.rot))
            .opacity(layer.fx.opacity)
            .position(x: CGFloat(layer.xf.cx) * W, y: CGFloat(layer.xf.cy) * H)
    }

    @ViewBuilder private func content(w: CGFloat, h: CGFloat) -> some View {
        switch layer.kind {
        case .cutout(let id):
            CutoutView(image: id, fx: layer.fx, w: w, h: h, flip: layer.xf.flip, tick: tick)
        case .text(let t):
            TextLayerView(spec: t, fx: layer.fx, w: w, h: h, W: W)
        }
    }
}

struct CutoutView: View {
    let image: String
    let fx: Effects
    let w: CGFloat
    let h: CGFloat
    let flip: Bool
    let tick: Int

    var body: some View {
        ZStack {
            if fx.reflect {
                pic.scaleEffect(x: 1, y: -1)
                    .mask { LinearGradient(colors: [Color.white.opacity(0.55), Color.clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)) }
                    .opacity(0.6)
                    .offset(y: h * 0.985)
            }
            pic
                .shadow(color: fx.glow > 0.01 ? fx.glowColor.color.opacity(min(1, fx.glow)) : Color.clear, radius: CGFloat(fx.glow) * w * 0.09)
                .shadow(color: fx.glow > 0.01 ? fx.glowColor.color.opacity(min(1, fx.glow * 0.8)) : Color.clear, radius: CGFloat(fx.glow) * w * 0.025)
                .shadow(color: fx.shadow > 0.01 ? Color.black.opacity(0.7 * fx.shadow) : Color.clear,
                        radius: w * 0.03 * CGFloat(0.4 + fx.shadow), x: 0, y: w * CGFloat(fx.shadowDY) * CGFloat(0.4 + fx.shadow))
        }
        .frame(width: w, height: h)
        .scaleEffect(x: flip ? -1 : 1, y: 1)
    }

    @ViewBuilder private var pic: some View {
        let bank = Bank.shared
        if let ol = bank.outlined(image, stroke: fx.stroke, color: fx.strokeColor) {
            Image(uiImage: ol.img).resizable().frame(width: w * ol.kx, height: h * ol.ky).frame(width: w, height: h)
        } else if let base = bank.image(image) {
            Image(uiImage: base).resizable().frame(width: w, height: h)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)).frame(width: w, height: h)
        }
    }
}

struct TextLayerView: View {
    let spec: TextSpec
    let fx: Effects
    let w: CGFloat
    let h: CGFloat
    let W: CGFloat

    var body: some View {
        let fs = CGFloat(spec.size) * W
        Text(spec.text.isEmpty ? " " : spec.text)
            .font(TH.font(spec.font, size: fs))
            .foregroundColor(spec.color.color)
            .multilineTextAlignment(.center)
            .lineLimit(6)
            .minimumScaleFactor(0.2)
            .padding(.horizontal, spec.pill ? fs * 0.55 : 0)
            .padding(.vertical, spec.pill ? fs * 0.12 : 0)
            .background(Capsule().fill(spec.pill ? spec.pillColor.color : Color.clear))
            .frame(width: w, height: h)
            .shadow(color: fx.glow > 0.01 ? fx.glowColor.color.opacity(min(1, fx.glow)) : Color.clear, radius: CGFloat(fx.glow) * fs * 0.5)
            .shadow(color: fx.shadow > 0.01 ? Color.black.opacity(0.6 * fx.shadow) : Color.clear, radius: fs * 0.08, x: 0, y: fs * 0.06)
    }
}

/// إطار التحديد حول الطبقة المختارة
struct SelBox: View {
    let layer: Layer
    let W: CGFloat
    let H: CGFloat
    var body: some View {
        let w = CGFloat(layer.xf.scale) * W + 10
        let h = CGFloat(layer.xf.scale) * W * CGFloat(layer.hOverW) + 10
        ZStack {
            RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            RoundedRectangle(cornerRadius: 6).stroke(TH.coral.opacity(0.5), lineWidth: 4).blur(radius: 3)
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(Color.white).frame(width: 11, height: 11)
                    .overlay(Circle().stroke(TH.coral, lineWidth: 2))
                    .position(x: i % 2 == 0 ? 0 : w, y: i < 2 ? 0 : h)
            }
            if layer.locked {
                Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white)
                    .padding(6).background(Color.black.opacity(0.6), in: Circle())
            }
        }
        .frame(width: w, height: h)
        .rotationEffect(.radians(layer.xf.rot))
        .position(x: CGFloat(layer.xf.cx) * W, y: CGFloat(layer.xf.cy) * H)
        .allowsHitTesting(false)
    }
}

/// معاينة مصغّرة لمشروع داخل صندوق
struct MiniStage: View {
    let project: Project
    let box: CGSize
    var tick: Int = 0
    var body: some View {
        let r = Fit.fit(TSize(project.aspect.ratio, 1), in: TRect(0, 0, Double(box.width), Double(box.height)))
        StageView(project: project, size: CGSize(width: r.w, height: r.h), export: false, tick: tick)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(width: box.width, height: box.height)
    }
}
