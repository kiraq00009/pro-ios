import SwiftUI
import UIKit

/// بيانات وضع التصوير: مواضيع مرسومة بالكود (ما أكو صور بالمحاكي)
enum Demo {
    static let figureID = "demo-figure", plantID = "demo-plant", bottleID = "demo-bottle", sceneID = "demo-scene"
    static let figureRatio = 900.0 / 600.0, plantRatio = 700.0 / 500.0, bottleRatio = 760.0 / 420.0
    /// مكان العناصر بالمشهد (نسب) — للنقر بوضع التجربة
    static let figureRect = CGRect(x: 0.1, y: 0.22, width: 0.5, height: 0.75)
    static let plantRect = CGRect(x: 0.6, y: 0.48, width: 0.32, height: 0.46)

    private static func fmt() -> UIGraphicsImageRendererFormat {
        let f = UIGraphicsImageRendererFormat.default()
        f.scale = 1
        f.opaque = false
        return f
    }

    private static func fill(_ path: UIBezierPath, _ g: CGContext, _ a: UIColor, _ b: UIColor, _ from: CGPoint, _ to: CGPoint) {
        g.saveGState()
        path.addClip()
        if let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [a.cgColor, b.cgColor] as CFArray, locations: [0, 1]) {
            g.drawLinearGradient(gr, start: from, end: to, options: [])
        }
        g.restoreGState()
    }
    private static func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }

    /// شخص بهودي وسمّاعات
    static func figure() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 600, height: 900), format: fmt()).image { ctx in
            let g = ctx.cgContext
            let body = UIBezierPath(roundedRect: CGRect(x: 70, y: 470, width: 460, height: 430), byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 200, height: 200))
            fill(body, g, c(1, 0.45, 0.38), c(0.75, 0.2, 0.42), CGPoint(x: 100, y: 470), CGPoint(x: 500, y: 900))
            let hood = UIBezierPath(ovalIn: CGRect(x: 170, y: 430, width: 260, height: 120))
            fill(hood, g, c(0.85, 0.3, 0.38), c(0.7, 0.2, 0.36), CGPoint(x: 300, y: 430), CGPoint(x: 300, y: 550))
            let zip = UIBezierPath(roundedRect: CGRect(x: 294, y: 560, width: 12, height: 340), cornerRadius: 6)
            c(1, 1, 1, 0.35).setFill(); zip.fill()
            let neck = UIBezierPath(roundedRect: CGRect(x: 250, y: 380, width: 100, height: 110), cornerRadius: 30)
            fill(neck, g, c(0.82, 0.6, 0.48), c(0.7, 0.48, 0.38), CGPoint(x: 300, y: 380), CGPoint(x: 300, y: 490))
            let head = UIBezierPath(ovalIn: CGRect(x: 175, y: 120, width: 250, height: 300))
            fill(head, g, c(0.95, 0.74, 0.6), c(0.8, 0.58, 0.46), CGPoint(x: 200, y: 120), CGPoint(x: 420, y: 420))
            let hair = UIBezierPath()
            hair.move(to: CGPoint(x: 168, y: 250))
            hair.addCurve(to: CGPoint(x: 300, y: 80), controlPoint1: CGPoint(x: 150, y: 130), controlPoint2: CGPoint(x: 220, y: 70))
            hair.addCurve(to: CGPoint(x: 432, y: 250), controlPoint1: CGPoint(x: 390, y: 75), controlPoint2: CGPoint(x: 455, y: 140))
            hair.addCurve(to: CGPoint(x: 168, y: 250), controlPoint1: CGPoint(x: 380, y: 170), controlPoint2: CGPoint(x: 230, y: 160))
            hair.close()
            fill(hair, g, c(0.22, 0.14, 0.12), c(0.08, 0.05, 0.05), CGPoint(x: 300, y: 70), CGPoint(x: 300, y: 260))
            let glasses = UIBezierPath(roundedRect: CGRect(x: 195, y: 255, width: 210, height: 58), cornerRadius: 26)
            fill(glasses, g, c(0.12, 0.1, 0.2), c(0.35, 0.25, 0.6), CGPoint(x: 195, y: 255), CGPoint(x: 405, y: 313))
            c(1, 1, 1, 0.5).setFill()
            UIBezierPath(roundedRect: CGRect(x: 215, y: 264, width: 50, height: 10), cornerRadius: 5).fill()
            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: 262, y: 350))
            smile.addQuadCurve(to: CGPoint(x: 338, y: 350), controlPoint: CGPoint(x: 300, y: 380))
            smile.lineWidth = 8; smile.lineCapStyle = .round
            c(0.55, 0.25, 0.22).setStroke(); smile.stroke()
            let band = UIBezierPath()
            band.move(to: CGPoint(x: 160, y: 270))
            band.addCurve(to: CGPoint(x: 440, y: 270), controlPoint1: CGPoint(x: 170, y: 40), controlPoint2: CGPoint(x: 430, y: 40))
            band.lineWidth = 22; band.lineCapStyle = .round
            c(0.4, 0.98, 0.8).setStroke(); band.stroke()
            for x in [138.0, 412.0] {
                let cup = UIBezierPath(roundedRect: CGRect(x: x, y: 225, width: 50, height: 105), cornerRadius: 24)
                fill(cup, g, c(0.45, 1, 0.82), c(0.15, 0.6, 0.55), CGPoint(x: x, y: 225), CGPoint(x: x + 50, y: 330))
            }
        }
    }

    /// نبتة بسندانة
    static func plant() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 500, height: 700), format: fmt()).image { ctx in
            let g = ctx.cgContext
            let leaves: [(CGFloat, CGFloat, CGFloat)] = [(250, 120, 0), (150, 200, -0.7), (350, 200, 0.7), (110, 320, -1.1), (390, 320, 1.1), (200, 280, -0.35), (300, 280, 0.35)]
            for (i, lf) in leaves.enumerated() {
                g.saveGState()
                g.translateBy(x: lf.0, y: lf.1 + 120)
                g.rotate(by: lf.2)
                let p = UIBezierPath(ovalIn: CGRect(x: -48, y: -150, width: 96, height: 230))
                let dark = i % 2 == 0
                fill(p, g, dark ? c(0.3, 0.85, 0.45) : c(0.45, 0.95, 0.55), dark ? c(0.05, 0.42, 0.25) : c(0.1, 0.5, 0.3), CGPoint(x: 0, y: -150), CGPoint(x: 0, y: 80))
                let vein = UIBezierPath()
                vein.move(to: CGPoint(x: 0, y: -130)); vein.addLine(to: CGPoint(x: 0, y: 60))
                vein.lineWidth = 4; c(1, 1, 1, 0.25).setStroke(); vein.stroke()
                g.restoreGState()
            }
            let pot = UIBezierPath()
            pot.move(to: CGPoint(x: 120, y: 470)); pot.addLine(to: CGPoint(x: 380, y: 470))
            pot.addLine(to: CGPoint(x: 345, y: 690)); pot.addLine(to: CGPoint(x: 155, y: 690)); pot.close()
            fill(pot, g, c(0.98, 0.62, 0.35), c(0.75, 0.32, 0.22), CGPoint(x: 120, y: 470), CGPoint(x: 380, y: 690))
            let rim = UIBezierPath(roundedRect: CGRect(x: 100, y: 450, width: 300, height: 52), cornerRadius: 14)
            fill(rim, g, c(1, 0.72, 0.45), c(0.85, 0.42, 0.28), CGPoint(x: 100, y: 450), CGPoint(x: 100, y: 502))
        }
    }

    /// قنينة عطر
    static func bottle() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 420, height: 760), format: fmt()).image { ctx in
            let g = ctx.cgContext
            let glass = UIBezierPath(roundedRect: CGRect(x: 30, y: 250, width: 360, height: 500), cornerRadius: 70)
            fill(glass, g, c(0.6, 0.45, 1, 0.95), c(0.95, 0.35, 0.6, 0.95), CGPoint(x: 30, y: 250), CGPoint(x: 390, y: 750))
            let liquid = UIBezierPath(roundedRect: CGRect(x: 55, y: 420, width: 310, height: 305), cornerRadius: 52)
            fill(liquid, g, c(1, 0.75, 0.45, 0.9), c(1, 0.45, 0.4, 0.95), CGPoint(x: 55, y: 420), CGPoint(x: 365, y: 725))
            c(1, 1, 1, 0.45).setFill()
            UIBezierPath(roundedRect: CGRect(x: 70, y: 285, width: 34, height: 380), cornerRadius: 17).fill()
            let label = UIBezierPath(roundedRect: CGRect(x: 110, y: 470, width: 200, height: 110), cornerRadius: 18)
            c(1, 1, 1, 0.9).setFill(); label.fill()
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 46, weight: .black), .foregroundColor: c(0.35, 0.2, 0.5)]
            let s = NSAttributedString(string: "N°7", attributes: attrs)
            let sz = s.size()
            s.draw(at: CGPoint(x: 210 - sz.width / 2, y: 525 - sz.height / 2))
            let neck = UIBezierPath(roundedRect: CGRect(x: 150, y: 190, width: 120, height: 80), cornerRadius: 14)
            fill(neck, g, c(0.85, 0.8, 0.95), c(0.6, 0.55, 0.75), CGPoint(x: 150, y: 190), CGPoint(x: 270, y: 270))
            let cap = UIBezierPath(roundedRect: CGRect(x: 110, y: 10, width: 200, height: 190), cornerRadius: 40)
            fill(cap, g, c(1, 0.85, 0.45), c(0.8, 0.55, 0.2), CGPoint(x: 110, y: 10), CGPoint(x: 310, y: 200))
            c(1, 1, 1, 0.4).setFill()
            UIBezierPath(roundedRect: CGRect(x: 130, y: 30, width: 26, height: 150), cornerRadius: 13).fill()
        }
    }

    /// صورة كاملة (غرفة + الشخص + النبتة). bg=false ⇒ العناصر المختارة فقط على شفّاف
    static func scene(bg: Bool, which: Set<Int>) -> UIImage {
        let W: CGFloat = 1000, H: CGFloat = 1300
        let fig = figure(), pl = plant()
        return UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: fmt()).image { ctx in
            let g = ctx.cgContext
            if bg {
                fill(UIBezierPath(rect: CGRect(x: 0, y: 0, width: W, height: H * 0.78)), g, c(0.55, 0.62, 0.72), c(0.78, 0.72, 0.66), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: H * 0.78))
                fill(UIBezierPath(rect: CGRect(x: 0, y: H * 0.78, width: W, height: H * 0.22)), g, c(0.5, 0.38, 0.3), c(0.32, 0.22, 0.18), CGPoint(x: 0, y: H * 0.78), CGPoint(x: 0, y: H))
                let win = UIBezierPath(roundedRect: CGRect(x: 600, y: 120, width: 300, height: 380), cornerRadius: 16)
                fill(win, g, c(0.85, 0.93, 1), c(0.6, 0.78, 0.95), CGPoint(x: 600, y: 120), CGPoint(x: 900, y: 500))
                c(0.95, 0.95, 0.97).setStroke(); win.lineWidth = 18; win.stroke()
                let shelf = UIBezierPath(roundedRect: CGRect(x: 60, y: 330, width: 330, height: 24), cornerRadius: 6)
                c(0.42, 0.3, 0.24).setFill(); shelf.fill()
                for (i, x) in [90.0, 150.0, 230.0, 300.0].enumerated() {
                    let bk = UIBezierPath(roundedRect: CGRect(x: x, y: 230 + Double(i % 2) * 20, width: 50, height: 100 - Double(i % 2) * 20), cornerRadius: 6)
                    [c(0.9, 0.45, 0.35), c(0.3, 0.5, 0.75), c(0.95, 0.78, 0.35), c(0.4, 0.7, 0.5)][i].setFill(); bk.fill()
                }
            }
            if which.contains(1) { fig.draw(in: rect(figureRect, W, H)) }
            if which.contains(2) { pl.draw(in: rect(plantRect, W, H)) }
        }
    }
    private static func rect(_ r: CGRect, _ W: CGFloat, _ H: CGFloat) -> CGRect { CGRect(x: r.minX * W, y: r.minY * H, width: r.width * W, height: r.height * H) }

    @MainActor static func install(_ bank: Bank) {
        bank.putMemory(figureID, figure())
        bank.putMemory(plantID, plant())
        bank.putMemory(bottleID, bottle())
        bank.putMemory(sceneID, scene(bg: true, which: [1, 2]))
    }

    static var figureCut: CutRef { CutRef(figureID, figureRatio) }
    static var plantCut: CutRef { CutRef(plantID, plantRatio) }
    static var bottleCut: CutRef { CutRef(bottleID, bottleRatio) }

    static func make(_ tid: String, _ cuts: [CutRef], name: String, hoursAgo: Double) -> Project {
        let now = Date().timeIntervalSince1970 - hoursAgo * 3600
        let t = Templates.find(tid) ?? Templates.all[0]
        var n = 0
        let gen: () -> String = { n += 1; return "\(tid)-\(n)" }
        var p = Templates.build(t, cuts: cuts, source: sceneID, id: "demo-\(tid)", name: name, now: now, newID: gen)
        p.modified = now
        return p
    }

    static var poster: Project {
        var p = make("poster", [figureCut], name: "بوستر الصيف", hoursAgo: 0.2)
        if let i = p.layers.firstIndex(where: { $0.isText }) { p.layers[i].setText { $0.text = "موسم جديد" } }
        return p
    }
    static var stickers: Project { make("sticker", [figureCut, plantCut, bottleCut], name: "ملصقاتي", hoursAgo: 3) }
    static var product: Project { make("product", [bottleCut], name: "عطر N°7", hoursAgo: 26) }
    static var collage: Project { make("collage", [figureCut, plantCut], name: "كولاج البيت", hoursAgo: 50) }
    static var pop: Project { make("pop", [figureCut], name: "غلاف", hoursAgo: 80) }
    static var dream: Project { make("dream", [figureCut], name: "حلم", hoursAgo: 120) }
    static var all: [Project] { [poster, stickers, product, collage, pop, dream] }
}
