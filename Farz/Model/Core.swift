import Foundation

// MARK: - الأنواع الأساسيّة (Foundation فقط — تنبني وتنفحص لوحدها)

enum FZKind: Int, Codable, Equatable {
    case photo = 0, video = 1, live = 2
}

enum FZCat: String, CaseIterable, Codable, Identifiable {
    case similar, blurry, screenshots, videos, live, forwarded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .similar: return "صور متشابهة"
        case .blurry: return "صور مشوّشة"
        case .screenshots: return "لقطات الشاشة"
        case .videos: return "فيديوهات كبيرة"
        case .live: return "صور حيّة"
        case .forwarded: return "صور مُعاد توجيهها"
        }
    }

    var short: String {
        switch self {
        case .similar: return "متشابهة"
        case .blurry: return "مشوّشة"
        case .screenshots: return "لقطات شاشة"
        case .videos: return "فيديو كبير"
        case .live: return "صورة حيّة"
        case .forwarded: return "مُعاد توجيهها"
        }
    }

    var explain: String {
        switch self {
        case .similar: return "لقطات متتالية شبه متطابقة. اخترنا لك أوضح لقطة بكلّ مجموعة، والباقي جاهز للحذف."
        case .blurry: return "صور مهزوزة أو خارج التركيز، كشفناها بتحليل حدّة الحواف على جهازك."
        case .screenshots: return "لقطات شاشة قديمة غالبًا ما تحتاجها بعد ما أدّت غرضها."
        case .videos: return "أكبر الفيديوهات مرتّبة من الأثقل. فيديو واحد ممكن يساوي مئات الصور."
        case .live: return "الصورة الحيّة فيها مقطع فيديو قصير. حوّلها لصورة عاديّة ووفّر حجم المقطع."
        case .forwarded: return "صور قديمة وصلتك من تطبيقات المحادثة: صغيرة الأبعاد ومضغوطة."
        }
    }

    var icon: String {
        switch self {
        case .similar: return "square.on.square"
        case .blurry: return "camera.aperture"
        case .screenshots: return "iphone"
        case .videos: return "video.fill"
        case .live: return "livephoto"
        case .forwarded: return "arrowshape.turn.up.right.fill"
        }
    }
}

struct FZAsset: Codable, Equatable, Identifiable {
    var id: String
    var kind: FZKind
    var bytes: Int64
    var pairedBytes: Int64 = 0
    var width: Int
    var height: Int
    var created: Double
    var duration: Double = 0
    var isScreenshot: Bool = false
    var isFavorite: Bool = false
    var fileName: String = ""
    var sharpness: Double? = nil
    var brightness: Double? = nil
    var group: Int? = nil
    var isBest: Bool = false
    var faces: Int = 0

    var pixels: Int { max(0, width) * max(0, height) }
}

/// إعدادات الفرز (يغيّرها المستخدم)
struct FZRules: Codable, Equatable {
    var similarity: Int = 1       // 0 صارم · 1 متوازن · 2 واسع
    var blurLevel: Int = 1        // 0 خفيف · 1 متوسّط · 2 قويّ
    var bigVideoMB: Int = 50
    var forwardedDays: Int = 60
    var protectFavorites: Bool = true
    var maxGap: Double = 240      // أقصى فرق بالثواني بين لقطتين حتى تنحسب متشابهة

    static let similarityNames = ["صارم", "متوازن", "واسع"]
    static let blurNames = ["خفيف", "متوسّط", "قويّ"]
    static let videoSteps = [25, 50, 100, 250]
    static let ageSteps = [30, 60, 180, 365]

    /// المسافة بين بصمتين مُطبّعتين (0…2)
    var similarDistance: Double { [0.30, 0.42, 0.55][max(0, min(2, similarity))] }
    /// تباين لابلاس تحت هذا الحدّ = مشوّشة
    var blurThreshold: Double { [45.0, 75.0, 115.0][max(0, min(2, blurLevel))] }
    var bigVideoBytes: Int64 { Int64(max(1, bigVideoMB)) * 1_000_000 }
}

// MARK: - الأيّام والتقدّم

enum FZDay {
    /// رقم اليوم المحلّي (offset بالثواني عن UTC)
    static func of(_ t: Double, offset: Int = 0) -> Int { Int(floor((t + Double(offset)) / 86400)) }
}

enum FZProgress {
    /// أوزان مراحل الفحص: قراءة المكتبة · تحليل الصور · اختيار الأفضل
    static let weights: [Double] = [0.12, 0.80, 0.08]

    static func overall(phase: Int, fraction: Double) -> Double {
        let p = max(0, min(weights.count - 1, phase))
        let done = weights.prefix(p).reduce(0, +)
        let f = max(0, min(1, fraction))
        return min(1, done + weights[p] * f)
    }
}

// MARK: - الحلقة

struct FZArc: Equatable {
    var start: Double
    var end: Double
    var length: Double { end - start }
}

enum FZRing {
    /// يقسّم الحلقة لأقواس متتالية بنسبة كلّ قيمة من المجموع. إذا زاد المجموع على total يتقلّص ليملأ الحلقة.
    static func segments(_ values: [Double], total: Double, gap: Double = 0) -> [FZArc] {
        let sum = values.reduce(0) { $0 + max(0, $1) }
        let t = max(total, sum)
        guard t > 0 else { return values.map { _ in FZArc(start: 0, end: 0) } }
        var cursor = 0.0
        var out: [FZArc] = []
        for v in values {
            let f = max(0, v) / t
            if f <= 0 {
                out.append(FZArc(start: cursor, end: cursor))
                continue
            }
            let half = min(gap / 2, f / 4)
            let s = cursor + half
            let e = max(s, cursor + f - half)
            out.append(FZArc(start: s, end: e))
            cursor += f
        }
        return out
    }
}
