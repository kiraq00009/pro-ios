import Foundation

/// مولّد أرقام عشوائيّة ثابت البذرة (نفس النتيجة كلّ مرّة)
struct FZRand {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
    mutating func int(_ a: Int, _ b: Int) -> Int { a + Int(next() % UInt64(max(1, b - a + 1))) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
}

/// مكتبة تجريبيّة كاملة (لوضع التصوير والتجربة بدون صلاحيّة)
enum FZDemoLib {
    static func make(seed: UInt64 = 7, now: Double) -> [FZAsset] {
        var r = FZRand(seed)
        var out: [FZAsset] = []
        var n = 0
        func nextID() -> String { n += 1; return "demo-\(n)" }
        let day = 86400.0

        // صور عاديّة
        for _ in 0..<46 {
            let t = now - r.range(2, 900) * day
            out.append(FZAsset(id: nextID(), kind: .photo, bytes: Int64(r.range(1.8e6, 4.6e6)), width: 4032, height: 3024,
                               created: t, isFavorite: r.chance(0.12), fileName: "IMG_\(r.int(1000, 9999)).HEIC",
                               sharpness: r.range(180, 1400), brightness: r.range(60, 190)))
        }
        // مجموعات متشابهة
        for g in 1...9 {
            let base = now - r.range(5, 700) * day
            let count = r.int(3, 6)
            for k in 0..<count {
                out.append(FZAsset(id: nextID(), kind: .photo, bytes: Int64(r.range(2.2e6, 4.2e6)), width: 4032, height: 3024,
                                   created: base + Double(k) * r.range(0.6, 5), fileName: "IMG_\(r.int(1000, 9999)).HEIC",
                                   sharpness: r.range(90, 1200), brightness: r.range(70, 180), group: g, faces: g % 3 == 0 ? r.int(1, 3) : 0))
            }
        }
        // مشوّشة
        for _ in 0..<15 {
            out.append(FZAsset(id: nextID(), kind: .photo, bytes: Int64(r.range(1.4e6, 3.6e6)), width: 4032, height: 3024,
                               created: now - r.range(3, 800) * day, fileName: "IMG_\(r.int(1000, 9999)).HEIC",
                               sharpness: r.range(6, 40), brightness: r.range(50, 200)))
        }
        // لقطات شاشة
        for _ in 0..<24 {
            out.append(FZAsset(id: nextID(), kind: .photo, bytes: Int64(r.range(0.4e6, 2.6e6)), width: 1179, height: 2556,
                               created: now - r.range(1, 600) * day, isScreenshot: true, fileName: "IMG_\(r.int(1000, 9999)).PNG",
                               sharpness: r.range(400, 3000), brightness: r.range(30, 230)))
        }
        // فيديوهات كبيرة وصغيرة
        let bigSizes: [Double] = [2.4e9, 1.6e9, 1.1e9, 820e6, 610e6, 450e6, 300e6, 210e6, 140e6, 96e6, 72e6]
        for b in bigSizes {
            let dur = b / 9.5e6 + r.range(0, 20)
            out.append(FZAsset(id: nextID(), kind: .video, bytes: Int64(b * r.range(0.95, 1.05)), width: 3840, height: 2160,
                               created: now - r.range(4, 900) * day, duration: dur, fileName: "IMG_\(r.int(1000, 9999)).MOV"))
        }
        for _ in 0..<6 {
            out.append(FZAsset(id: nextID(), kind: .video, bytes: Int64(r.range(4e6, 30e6)), width: 1920, height: 1080,
                               created: now - r.range(1, 300) * day, duration: r.range(4, 25), fileName: "IMG_\(r.int(1000, 9999)).MOV"))
        }
        // صور حيّة
        for _ in 0..<18 {
            let paired = Int64(r.range(1.6e6, 3.8e6))
            out.append(FZAsset(id: nextID(), kind: .live, bytes: Int64(r.range(2.4e6, 4.0e6)) + paired, pairedBytes: paired,
                               width: 4032, height: 3024, created: now - r.range(2, 500) * day, fileName: "IMG_\(r.int(1000, 9999)).HEIC",
                               sharpness: r.range(200, 1100), brightness: r.range(70, 180)))
        }
        // مُعاد توجيهها
        for k in 0..<20 {
            let t = now - r.range(90, 900) * day
            let wide = r.chance(0.5)
            out.append(FZAsset(id: nextID(), kind: .photo, bytes: Int64(r.range(90e3, 420e3)), width: wide ? 1600 : 1200, height: wide ? 1200 : 1600,
                               created: t, fileName: String(format: "IMG-2024%02d%02d-WA%04d.jpg", r.int(1, 12), r.int(1, 28), k + 1),
                               sharpness: r.range(150, 700), brightness: r.range(60, 200)))
        }

        FZClassify.markBest(&out)
        return out.sorted { $0.created < $1.created }
    }

    /// سجلّ تجريبيّ لطيف
    static func ledger(today: Int) -> FZLedger {
        var l = FZLedger()
        let plan: [(Int, Int64, Int)] = [(-9, 850_000_000, 64), (-6, 320_000_000, 21), (-4, 1_400_000_000, 37), (-3, 260_000_000, 18), (-2, 540_000_000, 44), (-1, 2_100_000_000, 12), (0, 690_000_000, 31)]
        for p in plan { l.record(bytes: p.1, count: p.2, day: today + p.0) }
        l.converted = 14
        return l
    }
}
