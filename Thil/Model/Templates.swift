import Foundation

// القوالب: كلّ قالب يبني مشروعًا كاملًا من القصّات (خلفيّة + تموضع + تأثيرات + نصوص)

struct Template: Identifiable, Equatable {
    let id: String
    let title: String
    let note: String
    let symbol: String
    let aspect: Aspect
    let maxCuts: Int
}

enum Templates {
    static let all: [Template] = [
        Template(id: "poster", title: "بوستر", note: "إضاءة سينمائيّة وعنوان عريض", symbol: "film.fill", aspect: .story, maxCuts: 1),
        Template(id: "sticker", title: "ملصقات", note: "حدّ أبيض وظلّ — جاهزة للمحادثات", symbol: "seal.fill", aspect: .square, maxCuts: 6),
        Template(id: "product", title: "صورة منتج", note: "أرضيّة بيضاء وانعكاس ناعم", symbol: "shippingbox.fill", aspect: .square, maxCuts: 1),
        Template(id: "pop", title: "غلاف مجلّة", note: "كلمة ضخمة ورا الموضوع", symbol: "textformat.size", aspect: .portrait, maxCuts: 1),
        Template(id: "collage", title: "كولاج", note: "اجمع أكثر من قصّة بلوحة وحدة", symbol: "square.stack.3d.up.fill", aspect: .portrait, maxCuts: 4),
        Template(id: "dream", title: "حلم", note: "الأصل مضبّب وراك وتوهّج ناعم", symbol: "sparkles", aspect: .story, maxCuts: 1),
        Template(id: "clean", title: "بسيط", note: "خلفيّة صافية وظلّ خفيف", symbol: "circle.dashed", aspect: .portrait, maxCuts: 1),
    ]

    static func find(_ id: String) -> Template? { all.first { $0.id == id } }

    /// مراكز الملصقات بشبكة متوازنة داخل مربّع (الصفّ الأخير بالوسط)
    static func gridSlots(_ n: Int) -> [TP] {
        guard n > 0 else { return [] }
        if n == 1 { return [TP(0.5, 0.5)] }
        let cols = Int(ceil(sqrt(Double(n))))
        let rows = Int(ceil(Double(n) / Double(cols)))
        let m = 0.08, span = 0.84
        var out: [TP] = []
        for i in 0..<n {
            let r = i / cols, c = i % cols
            let inRow = r == rows - 1 ? n - cols * (rows - 1) : cols
            let shift = Double(cols - inRow) / 2
            let x = m + span * ((Double(c) + 0.5 + shift) / Double(cols))
            let y = m + span * ((Double(r) + 0.5) / Double(rows))
            out.append(TP(x, y))
        }
        return out
    }

    /// يبني مشروعًا. الأقدم بالقصّات يكون الأسفل.
    static func build(_ t: Template, cuts: [CutRef], source: String?, id: String, name: String, now: Double, newID: () -> String) -> Project {
        var p = Project(id: id, name: name, now: now, aspect: t.aspect)
        p.source = source
        p.template = t.id
        let ratio = t.aspect.ratio
        let use = Array(cuts.prefix(max(1, t.maxCuts)))

        func place(_ c: CutRef, _ lid: String, cx: Double, bottom: Double? = nil, cy: Double = 0.5, maxW: Double, maxH: Double) -> Layer {
            var l = Layer.cutout(id: lid, image: c.image, hOverW: c.hOverW, name: "قصّة")
            l.xf.scale = Fit.scaleToFit(hOverW: c.hOverW, maxW: maxW, maxH: maxH, canvasRatio: ratio)
            l.xf.cx = cx
            let hFrac = l.xf.scale * c.hOverW * ratio
            l.xf.cy = bottom.map { $0 - hFrac / 2 } ?? cy
            return l
        }

        switch t.id {
        case "poster":
            p.bkg = .gradient(RGBA(0.09, 0.05, 0.20), RGBA(0.95, 0.36, 0.33), 90)
            if let c = use.first {
                var l = place(c, newID(), cx: 0.5, bottom: 1.0, maxW: 0.95, maxH: 0.72)
                l.fx.glow = 0.55; l.fx.glowColor = RGBA(1, 0.55, 0.45); l.fx.shadow = 0.4
                p.add(l)
            }
            var title = Layer.text(id: newID(), "عنوانك هنا", size: 0.13, color: .white, font: 0)
            title.xf.cy = 0.12
            title.refitText()
            p.add(title)
            var sub = Layer.text(id: newID(), "قريبًا · ٢٠٢٧", size: 0.045, color: RGBA(1, 0.85, 0.78), font: 0)
            sub.xf.cy = 0.205
            sub.refitText()
            p.add(sub)
        case "sticker":
            p.bkg = .clear
            let slots = gridSlots(use.count)
            let cols = Double(Int(ceil(sqrt(Double(max(1, use.count))))))
            let rows = Double(Int(ceil(Double(max(1, use.count)) / cols)))
            let cell = use.count == 1 ? 0.78 : min(0.84 / cols, 0.84 / rows) * 0.86
            for (i, c) in use.enumerated() {
                let s = slots[i]
                var l = place(c, newID(), cx: s.x, cy: s.y, maxW: cell, maxH: cell)
                l.fx.stroke = 0.045; l.fx.strokeColor = .white; l.fx.shadow = 0.5; l.fx.shadowDY = 0.02
                l.xf.rot = use.count == 1 ? 0 : (i % 2 == 0 ? -0.09 : 0.08)
                p.add(l)
            }
        case "product":
            p.bkg = .floor(RGBA(0.93, 0.93, 0.95), RGBA(1, 1, 1), 0.7)
            if let c = use.first {
                var l = place(c, newID(), cx: 0.5, bottom: 0.76, maxW: 0.62, maxH: 0.6)
                l.fx.reflect = true; l.fx.shadow = 0.35; l.fx.shadowDY = 0.04
                p.add(l)
            }
        case "pop":
            p.bkg = .solid(RGBA(1, 0.82, 0.2))
            var big = Layer.text(id: newID(), "ظِلّ", size: 0.42, color: RGBA(0.95, 0.25, 0.35), font: 0)
            big.xf.cy = 0.26; big.xf.scale = 0.96
            big.refitText()
            p.add(big)
            if let c = use.first {
                var l = place(c, newID(), cx: 0.5, bottom: 1.0, maxW: 0.92, maxH: 0.78)
                l.fx.shadow = 0.45
                p.add(l)
            }
            var tag = Layer.text(id: newID(), "عدد خاصّ", size: 0.05, color: .white, font: 0)
            tag.kind = .text(TextSpec(text: "عدد خاصّ", font: 0, size: 0.05, color: .white, pill: true, pillColor: RGBA(0.1, 0.1, 0.12, 0.85)))
            tag.xf.cy = 0.06; tag.xf.scale = 0.4
            tag.refitText()
            p.add(tag)
        case "collage":
            p.bkg = .gradient(RGBA(0.36, 0.25, 0.95), RGBA(0.98, 0.45, 0.6), 135)
            let n = use.count
            for (i, c) in use.enumerated() {
                let step = n <= 1 ? 0 : 0.56 / Double(n - 1)
                let cx = n <= 1 ? 0.5 : 0.22 + step * Double(i)
                let maxW = n <= 1 ? 0.8 : min(0.6, 1.4 / Double(n))
                var l = place(c, newID(), cx: cx, bottom: 0.88 - (i % 2 == 0 ? 0 : 0.05), maxW: maxW, maxH: 0.68)
                l.fx.stroke = 0.025; l.fx.shadow = 0.45
                l.xf.rot = n <= 1 ? 0 : (i % 2 == 0 ? -0.05 : 0.05)
                p.add(l)
            }
            var cap = Layer.text(id: newID(), "أحلى لحظاتنا", size: 0.085, color: .white, font: 0)
            cap.xf.cy = 0.1
            cap.refitText()
            p.add(cap)
        case "dream":
            if let s = source { p.bkg = .blurPhoto(s, 0.05) } else { p.bkg = .gradient(RGBA(0.2, 0.45, 0.85), RGBA(0.75, 0.55, 0.95), 70) }
            if let c = use.first {
                var l = place(c, newID(), cx: 0.5, cy: 0.52, maxW: 0.86, maxH: 0.66)
                l.fx.glow = 0.7; l.fx.glowColor = .white; l.fx.shadow = 0.2
                p.add(l)
            }
        default:
            p.bkg = .solid(RGBA(0.96, 0.95, 0.93))
            if let c = use.first {
                var l = place(c, newID(), cx: 0.5, cy: 0.5, maxW: 0.8, maxH: 0.8)
                l.fx.shadow = 0.3
                p.add(l)
            }
        }
        return p
    }

    /// يطبّق قالبًا على مشروع موجود ويحتفظ بهويّته واسمه وتاريخه
    static func restyle(_ p: Project, with t: Template, now: Double, newID: () -> String) -> Project {
        var n = build(t, cuts: p.cutouts, source: p.source, id: p.id, name: p.name, now: now, newID: newID)
        n.created = p.created
        return n
    }
}
