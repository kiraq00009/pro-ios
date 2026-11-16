import Foundation

// نموذج التصميم: لون، مقاس اللوحة، تحويل الطبقة، التأثيرات، النصّ، الخلفيّة، المشروع

struct RGBA: Codable, Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }

    static let white = RGBA(1, 1, 1)
    static let black = RGBA(0, 0, 0)
    static let clear = RGBA(0, 0, 0, 0)

    var hex: String {
        func c(_ v: Double) -> Int { Int((Fit.clamp(v, 0, 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }
    func mix(_ o: RGBA, _ t: Double) -> RGBA {
        let k = Fit.clamp(t, 0, 1)
        return RGBA(r + (o.r - r) * k, g + (o.g - g) * k, b + (o.b - b) * k, a + (o.a - a) * k)
    }
    /// السطوع المدرَك (0…1) — نختار لون نصّ مقروء فوقه
    var luma: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
}

enum Aspect: String, Codable, CaseIterable {
    case square, story, portrait, landscape
    /// العرض ÷ الارتفاع
    var ratio: Double {
        switch self {
        case .square: return 1
        case .story: return 9.0 / 16.0
        case .portrait: return 4.0 / 5.0
        case .landscape: return 16.0 / 9.0
        }
    }
    var title: String {
        switch self {
        case .square: return "مربّع"
        case .story: return "ستوري"
        case .portrait: return "منشور"
        case .landscape: return "عريض"
        }
    }
    var label: String {
        switch self {
        case .square: return "1:1"
        case .story: return "9:16"
        case .portrait: return "4:5"
        case .landscape: return "16:9"
        }
    }
    func pixelSize(width: Double) -> TSize { TSize(width, (width / ratio).rounded()) }
}

/// تحويل الطبقة: المركز نسبة من اللوحة (0…1)، والحجم = عرض الطبقة ÷ عرض اللوحة
struct XForm: Codable, Equatable {
    var cx: Double = 0.5
    var cy: Double = 0.5
    var scale: Double = 0.6
    var rot: Double = 0
    var flip: Bool = false

    static let minScale = 0.05
    static let maxScale = 3.0

    func box(hOverW: Double, canvas: TSize) -> TSize {
        let w = scale * canvas.w
        return TSize(w, w * hOverW)
    }
    func center(_ canvas: TSize) -> TP { TP(cx * canvas.w, cy * canvas.h) }

    /// هل النقطة (بكسلات اللوحة) داخل الطبقة بعد الدوران؟
    func contains(_ p: TP, hOverW: Double, canvas: TSize, slop: Double = 0) -> Bool {
        let b = box(hOverW: hOverW, canvas: canvas)
        let local = (p - center(canvas)).rotated(-rot)
        return abs(local.x) <= b.w / 2 + slop && abs(local.y) <= b.h / 2 + slop
    }

    /// زوايا الطبقة بعد الدوران (أعلى‑يسار، أعلى‑يمين، أسفل‑يمين، أسفل‑يسار)
    func corners(hOverW: Double, canvas: TSize) -> [TP] {
        let b = box(hOverW: hOverW, canvas: canvas)
        let c = center(canvas)
        let hw = b.w / 2, hh = b.h / 2
        return [TP(-hw, -hh), TP(hw, -hh), TP(hw, hh), TP(-hw, hh)].map { c + $0.rotated(rot) }
    }

    func moved(_ dx: Double, _ dy: Double) -> XForm {
        var t = self
        t.cx = Fit.clamp(cx + dx, -0.25, 1.25)
        t.cy = Fit.clamp(cy + dy, -0.25, 1.25)
        return t
    }
    func scaled(_ f: Double) -> XForm {
        var t = self
        t.scale = Fit.clamp(scale * (f > 0 ? f : 1), XForm.minScale, XForm.maxScale)
        return t
    }
    func rotated(_ a: Double, snap: Double = 0.05) -> XForm {
        var t = self
        t.rot = XForm.snapAngle(XForm.norm(rot + a), snap)
        return t
    }
    /// يلصق المركز على منتصف اللوحة إذا قريب ⇒ (التحويل، لصق أفقي، لصق عمودي)
    func snapped(_ tol: Double = 0.015) -> (XForm, Bool, Bool) {
        var t = self
        let sx = abs(cx - 0.5) < tol, sy = abs(cy - 0.5) < tol
        if sx { t.cx = 0.5 }
        if sy { t.cy = 0.5 }
        return (t, sx, sy)
    }

    /// زاوية بالمدى (‑π، π]
    static func norm(_ a: Double) -> Double {
        var v = a.truncatingRemainder(dividingBy: 2 * Double.pi)
        if v > Double.pi { v -= 2 * Double.pi }
        if v <= -Double.pi { v += 2 * Double.pi }
        return v
    }
    /// يلصق على مضاعفات ٩٠° إذا قريبة
    static func snapAngle(_ a: Double, _ tol: Double) -> Double {
        let q = Double.pi / 2
        let n = (a / q).rounded()
        return abs(a - n * q) < tol ? norm(n * q) : a
    }
}

struct Effects: Codable, Equatable {
    var shadow: Double = 0          // 0…1
    var shadowDY: Double = 0.03     // نسبة من عرض الطبقة
    var glow: Double = 0            // 0…1
    var glowColor: RGBA = RGBA(1, 0.45, 0.4)
    var stroke: Double = 0          // سُمك حدّ الملصق نسبة من عرض الطبقة (0…0.08)
    var strokeColor: RGBA = .white
    var opacity: Double = 1
    var reflect: Bool = false

    static let maxStroke = 0.08
    var isPlain: Bool { shadow < 0.01 && glow < 0.01 && stroke < 0.001 && opacity > 0.99 && !reflect }
}

struct TextSpec: Codable, Equatable {
    var text: String
    var font: Int = 0
    var size: Double = 0.09         // حجم الخطّ نسبة من عرض اللوحة
    var color: RGBA = .white
    var pill: Bool = false
    var pillColor: RGBA = RGBA(0, 0, 0, 0.55)

    var lines: Int { max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count) }
    /// ارتفاع الصندوق ÷ عرضه حسب عدد الأسطر وحجم الخطّ وعرض الطبقة
    func hOverW(scale: Double) -> Double {
        let s = max(0.05, scale)
        let pad = pill ? 0.6 : 0.25
        return max(0.08, (Double(lines) * 1.32 + pad) * size / s)
    }
}

enum LayerKind: Codable, Equatable {
    case cutout(String)
    case text(TextSpec)
}

struct Layer: Codable, Equatable, Identifiable {
    var id: String
    var kind: LayerKind
    var xf = XForm()
    var fx = Effects()
    var hOverW: Double = 1
    var hidden = false
    var locked = false
    var name: String = ""

    var isText: Bool { if case .text = kind { return true }; return false }
    var imageID: String? { if case .cutout(let s) = kind { return s }; return nil }
    var textSpec: TextSpec? { if case .text(let t) = kind { return t }; return nil }

    static func cutout(id: String, image: String, hOverW: Double, name: String = "قصّة") -> Layer {
        Layer(id: id, kind: .cutout(image), xf: XForm(), fx: Effects(), hOverW: max(0.05, hOverW), name: name)
    }
    static func text(id: String, _ s: String, size: Double = 0.09, color: RGBA = .white, font: Int = 0) -> Layer {
        let spec = TextSpec(text: s, font: font, size: size, color: color)
        var l = Layer(id: id, kind: .text(spec), name: "نصّ")
        l.xf.scale = 0.86
        l.hOverW = spec.hOverW(scale: l.xf.scale)
        return l
    }
    /// يعدّل النصّ ويعيد حساب ارتفاع الصندوق
    mutating func setText(_ f: (inout TextSpec) -> Void) {
        guard case .text(var t) = kind else { return }
        f(&t)
        kind = .text(t)
        hOverW = t.hOverW(scale: xf.scale)
    }
    mutating func refitText() {
        if case .text(let t) = kind { hOverW = t.hOverW(scale: xf.scale) }
    }
}

enum Bkg: Codable, Equatable {
    case clear
    case solid(RGBA)
    case gradient(RGBA, RGBA, Double)           // زاوية بالدرجات
    case blurPhoto(String, Double)              // صورة الأصل مضبّبة (نسبة نصف القطر من العرض)
    case photo(String)
    case floor(RGBA, RGBA, Double)              // جدار + أرضيّة + خطّ الأفق (0…1)

    var isClear: Bool { if case .clear = self { return true }; return false }
    var photoID: String? {
        switch self {
        case .blurPhoto(let s, _): return s
        case .photo(let s): return s
        case .clear, .solid, .gradient, .floor: return nil
        }
    }
    /// نقطتا بداية ونهاية التدرّج بإحداثيّات الوحدة
    static func gradientPoints(_ deg: Double) -> (TP, TP) {
        let a = deg * Double.pi / 180
        let dx = cos(a) / 2, dy = sin(a) / 2
        return (TP(0.5 - dx, 0.5 - dy), TP(0.5 + dx, 0.5 + dy))
    }
}

struct Project: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var created: Double
    var modified: Double
    var aspect: Aspect = .portrait
    var bkg: Bkg = .solid(RGBA(0.1, 0.08, 0.16))
    var layers: [Layer] = []              // 0 = الأسفل
    var source: String? = nil             // صورة الأصل (للخلفيّة المضبّبة)
    var template: String? = nil

    init(id: String, name: String, now: Double, aspect: Aspect = .portrait) {
        self.id = id; self.name = name; self.created = now; self.modified = now; self.aspect = aspect
    }

    func canvas(width: Double) -> TSize { aspect.pixelSize(width: width) }
    func index(of id: String) -> Int? { layers.firstIndex { $0.id == id } }
    func layer(_ id: String) -> Layer? { layers.first { $0.id == id } }
    var cutoutCount: Int { layers.filter { !$0.isText }.count }

    mutating func add(_ l: Layer) { layers.append(l) }
    mutating func remove(_ id: String) { layers.removeAll { $0.id == id } }

    @discardableResult mutating func moveUp(_ id: String) -> Bool {
        guard let i = index(of: id), i < layers.count - 1 else { return false }
        layers.swapAt(i, i + 1); return true
    }
    @discardableResult mutating func moveDown(_ id: String) -> Bool {
        guard let i = index(of: id), i > 0 else { return false }
        layers.swapAt(i, i - 1); return true
    }
    mutating func toFront(_ id: String) {
        guard let i = index(of: id) else { return }
        let l = layers.remove(at: i); layers.append(l)
    }
    mutating func toBack(_ id: String) {
        guard let i = index(of: id) else { return }
        let l = layers.remove(at: i); layers.insert(l, at: 0)
    }
    /// نسخة فوق الأصل بإزاحة بسيطة
    @discardableResult mutating func duplicate(_ id: String, newID: String) -> Layer? {
        guard let i = index(of: id) else { return nil }
        var c = layers[i]
        c.id = newID
        c.locked = false
        c.xf = c.xf.moved(0.04, 0.04)
        layers.insert(c, at: i + 1)
        return c
    }

    /// أعلى طبقة ظاهرة وغير مقفولة تحت النقطة (بكسلات اللوحة)
    func hitTest(_ p: TP, canvas: TSize) -> String? {
        for l in layers.reversed() where !l.hidden && !l.locked {
            let slop = l.isText ? canvas.w * 0.02 : 0
            if l.xf.contains(p, hOverW: l.hOverW, canvas: canvas, slop: slop) { return l.id }
        }
        return nil
    }

    /// كلّ الصور اللي يعتمد عليها المشروع (حتى ما ننظّفها)
    var imageIDs: Set<String> {
        var s = Set<String>()
        for l in layers { if let i = l.imageID { s.insert(i) } }
        if let b = bkg.photoID { s.insert(b) }
        if let src = source { s.insert(src) }
        return s
    }
    var cutouts: [CutRef] { layers.compactMap { l in l.imageID.map { CutRef($0, l.hOverW) } } }
}

struct CutRef: Equatable {
    var image: String
    var hOverW: Double
    init(_ image: String, _ hOverW: Double) { self.image = image; self.hOverW = hOverW }
}
