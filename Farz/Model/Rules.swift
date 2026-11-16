import Foundation

// MARK: - اختيار أفضل لقطة

struct FZShotMetrics: Equatable {
    var sharpness: Double
    var faces: Int = 0
    var faceArea: Double = 0      // مجموع مساحات الوجوه (نسبة من الصورة 0…1)
    var pixels: Int = 0
    var isFavorite: Bool = false
}

enum FZBest {
    /// درجة كلّ لقطة داخل مجموعتها (نسبيّة للمجموعة)
    static func scores(_ m: [FZShotMetrics]) -> [Double] {
        guard !m.isEmpty else { return [] }
        let maxS = max(1e-9, m.map { log1p(max(0, $0.sharpness)) }.max() ?? 0)
        let maxF = m.map { $0.faces }.max() ?? 0
        let maxA = m.map { $0.faceArea }.max() ?? 0
        let maxP = Double(m.map { $0.pixels }.max() ?? 0)
        return m.map { (x: FZShotMetrics) -> Double in
            let sh = log1p(max(0, x.sharpness)) / maxS
            var s: Double
            if maxF > 0 {
                let f = Double(x.faces) / Double(maxF)
                let a = maxA > 0 ? x.faceArea / maxA : 0
                s = sh * 0.55 + f * 0.25 + a * 0.10
            } else {
                s = sh * 0.90
            }
            if maxP > 0 { s += Double(x.pixels) / maxP * 0.10 }
            if x.isFavorite { s += 1 }
            return s
        }
    }

    static func pick(_ m: [FZShotMetrics]) -> Int? {
        let sc = scores(m)
        guard !sc.isEmpty else { return nil }
        var best = 0
        for i in 1..<sc.count where sc[i] > sc[best] { best = i }
        return best
    }
}

// MARK: - قواعد التصنيف

enum FZClassify {
    struct Summary: Equatable {
        var count: Int = 0
        var bytes: Int64 = 0
    }

    /// أبعاد شاشات آيفون الشائعة (بالبكسل، القصير × الطويل)
    static let screenSizes: [[Int]] = [
        [640, 1136], [750, 1334], [828, 1792], [1080, 1920], [1125, 2436], [1170, 2532],
        [1179, 2556], [1206, 2622], [1242, 2208], [1242, 2688], [1284, 2778], [1290, 2796], [1320, 2868],
    ]

    static func isScreenSize(_ w: Int, _ h: Int) -> Bool {
        let a = min(w, h), b = max(w, h)
        return screenSizes.contains { $0[0] == a && $0[1] == b }
    }

    static func isScreenshotLike(_ a: FZAsset) -> Bool {
        if a.kind == .video { return false }
        if a.isScreenshot { return true }
        let n = a.fileName.lowercased()
        if n.hasPrefix("screenshot") || n.contains("screen shot") { return true }
        return n.hasSuffix(".png") && isScreenSize(a.width, a.height)
    }

    /// أسماء مثل IMG-20230105-WA0012.jpg أو "WhatsApp Image …"
    static func looksForwardedName(_ name: String) -> Bool {
        let u = name.uppercased()
        if u.contains("WHATSAPP") { return true }
        guard let r = u.range(of: "-WA") else { return false }
        let digits = u[r.upperBound...].prefix(4)
        return digits.count == 4 && digits.allSatisfy { $0 >= "0" && $0 <= "9" }
    }

    static func ageDays(_ a: FZAsset, now: Double) -> Double { (now - a.created) / 86400 }

    static func isForwardedLike(_ a: FZAsset, rules: FZRules, now: Double) -> Bool {
        guard a.kind == .photo, !isScreenshotLike(a) else { return false }
        guard ageDays(a, now: now) >= Double(rules.forwardedDays) else { return false }
        if looksForwardedName(a.fileName) { return true }
        let side = max(a.width, a.height)
        guard side >= 320, side <= 1600 else { return false }
        let bpp = Double(a.bytes) / Double(max(1, a.pixels))
        return a.bytes <= 700_000 && bpp < 0.6
    }

    static func isBlurry(_ a: FZAsset, rules: FZRules) -> Bool {
        guard a.kind != .video, !isScreenshotLike(a), let s = a.sharpness else { return false }
        let r = FZBlur.Reading(variance: s, brightness: a.brightness ?? 128)
        return FZBlur.isBlurry(r, threshold: rules.blurThreshold)
    }

    static func isBigVideo(_ a: FZAsset, rules: FZRules) -> Bool {
        a.kind == .video && a.bytes >= rules.bigVideoBytes
    }

    static func cats(_ a: FZAsset, rules: FZRules, now: Double) -> Set<FZCat> {
        var s = Set<FZCat>()
        if rules.protectFavorites && a.isFavorite { return s }
        if a.group != nil && !a.isBest { s.insert(.similar) }
        if isBlurry(a, rules: rules) { s.insert(.blurry) }
        if isScreenshotLike(a) { s.insert(.screenshots) }
        if isBigVideo(a, rules: rules) { s.insert(.videos) }
        if a.kind == .live && a.pairedBytes > 0 { s.insert(.live) }
        if isForwardedLike(a, rules: rules, now: now) { s.insert(.forwarded) }
        return s
    }

    /// كم نوفّر من هذا العنصر ضمن فئة معيّنة (الصورة الحيّة: حجم المقطع فقط)
    static func saving(_ a: FZAsset, _ c: FZCat) -> Int64 {
        c == .live ? a.pairedBytes : a.bytes
    }

    /// الحجم الكلّيّ القابل للتوفير بدون عدّ مكرّر: العنصر بأكثر من فئة ينحسب مرّة وحدة
    static func cleanable(_ assets: [FZAsset], rules: FZRules, now: Double) -> Int64 {
        var t: Int64 = 0
        for a in assets {
            let c = cats(a, rules: rules, now: now)
            if c.isEmpty { continue }
            t += (c == [.live]) ? a.pairedBytes : a.bytes
        }
        return t
    }

    static func members(_ c: FZCat, _ assets: [FZAsset], rules: FZRules, now: Double) -> [FZAsset] {
        let list = assets.filter { cats($0, rules: rules, now: now).contains(c) }
        return sortFor(c, list)
    }

    static func sortFor(_ c: FZCat, _ list: [FZAsset]) -> [FZAsset] {
        switch c {
        case .videos:
            return list.sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.id < $1.id }
        case .live:
            return list.sorted { $0.pairedBytes != $1.pairedBytes ? $0.pairedBytes > $1.pairedBytes : $0.id < $1.id }
        case .blurry:
            return list.sorted { ($0.sharpness ?? 0) != ($1.sharpness ?? 0) ? ($0.sharpness ?? 0) < ($1.sharpness ?? 0) : $0.id < $1.id }
        case .similar:
            return list.sorted { ($0.group ?? 0) != ($1.group ?? 0) ? ($0.group ?? 0) < ($1.group ?? 0) : $0.created < $1.created }
        case .screenshots, .forwarded:
            return list.sorted { $0.created != $1.created ? $0.created < $1.created : $0.id < $1.id }
        }
    }

    static func summary(_ assets: [FZAsset], rules: FZRules, now: Double) -> [FZCat: Summary] {
        var d: [FZCat: Summary] = [:]
        for c in FZCat.allCases { d[c] = Summary() }
        for a in assets {
            for c in cats(a, rules: rules, now: now) {
                var s = d[c] ?? Summary()
                s.count += 1
                s.bytes += saving(a, c)
                d[c] = s
            }
        }
        return d
    }

    /// مجموعات المتشابهة (اثنين فأكثر)، مرتّبة من الأكثر توفيرًا
    static func groups(_ assets: [FZAsset]) -> [[FZAsset]] {
        var d: [Int: [FZAsset]] = [:]
        for a in assets { if let g = a.group { d[g, default: []].append(a) } }
        let gs: [[FZAsset]] = d.values.filter { $0.count > 1 }.map { $0.sorted { $0.created < $1.created } }
        return gs.sorted { (x: [FZAsset], y: [FZAsset]) -> Bool in
            let sx = groupSaving(x), sy = groupSaving(y)
            if sx != sy { return sx > sy }
            return (x.first?.created ?? 0) < (y.first?.created ?? 0)
        }
    }

    static func groupSaving(_ g: [FZAsset]) -> Int64 {
        g.filter { !$0.isBest && !$0.isFavorite }.reduce(Int64(0)) { $0 + $1.bytes }
    }

    /// يعيّن أفضل لقطة بكلّ مجموعة حسب المقاييس
    static func markBest(_ assets: inout [FZAsset]) {
        var idxByGroup: [Int: [Int]] = [:]
        for i in 0..<assets.count { if let g = assets[i].group { idxByGroup[g, default: []].append(i) } }
        for (_, idx) in idxByGroup {
            for i in idx { assets[i].isBest = false }
            if idx.count < 2 {
                for i in idx { assets[i].group = nil }
                continue
            }
            let m: [FZShotMetrics] = idx.map { i in
                let a = assets[i]
                return FZShotMetrics(sharpness: a.sharpness ?? 0, faces: a.faces, faceArea: 0, pixels: a.pixels, isFavorite: a.isFavorite)
            }
            if let b = FZBest.pick(m) { assets[idx[b]].isBest = true }
        }
    }

    /// صفّ المراجعة السريعة: أكبر المرشّحين من كلّ الفئات (ما عدا الحيّة لأنّها تحويل لا حذف)
    static func quickQueue(_ assets: [FZAsset], rules: FZRules, now: Double, limit: Int = 60) -> [FZAsset] {
        let pool = assets.filter { a in
            let c = cats(a, rules: rules, now: now)
            return !c.isEmpty && c != [.live]
        }
        let sorted = pool.sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.id < $1.id }
        return Array(sorted.prefix(max(0, limit)))
    }

    /// السبب الأوّل للعرض على البطاقة
    static func mainReason(_ a: FZAsset, rules: FZRules, now: Double) -> FZCat? {
        let c = cats(a, rules: rules, now: now)
        let order: [FZCat] = [.videos, .similar, .blurry, .screenshots, .forwarded, .live]
        return order.first { c.contains($0) }
    }
}
