import Foundation

/// نقطة/متّجه بسيط — بلا CoreGraphics حتى ينبني المنطق لحاله
struct P: Equatable {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    static func + (a: P, b: P) -> P { P(a.x + b.x, a.y + b.y) }
    static func - (a: P, b: P) -> P { P(a.x - b.x, a.y - b.y) }
    static func * (a: P, k: Double) -> P { P(a.x * k, a.y * k) }
    var len: Double { (x * x + y * y).squareRoot() }
    func dist(_ o: P) -> Double { (self - o).len }
    static let zero = P(0, 0)
}

/// مولّد أرقام ببذرة (SplitMix64) — نفس البذرة = نفس المرحلة بكلّ جهاز
struct SRNG {
    private var s: UInt64
    init(_ seed: UInt64) { s = seed ^ 0x5DEECE66D }
    mutating func next() -> UInt64 {
        s = s &+ 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / 9007199254740992.0 }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
    mutating func int(_ n: Int) -> Int { n <= 0 ? 0 : Int(next() % UInt64(n)) }
    mutating func shuffle<T>(_ a: inout [T]) {
        if a.count < 2 { return }
        var i = a.count - 1
        while i > 0 {
            let j = int(i + 1)
            a.swapAt(i, j)
            i -= 1
        }
    }
}

/// أنواع الكرات
enum OrbKind: Int, CaseIterable {
    case normal = 0, big, bouncer, shield, splitter, magnet, timer, bad

    var radius: Double {
        switch self {
        case .normal: return 12
        case .big: return 18
        case .bouncer: return 10
        case .shield: return 13
        case .splitter: return 12
        case .magnet: return 14
        case .timer: return 13
        case .bad: return 13
        }
    }
    /// مضاعف السرعة
    var speedMul: Double {
        switch self {
        case .bouncer: return 2.3
        case .big: return 0.6
        case .magnet: return 0.7
        case .normal, .shield, .splitter, .timer, .bad: return 1
        }
    }
    var points: Int {
        switch self {
        case .normal: return 10
        case .big, .bouncer: return 15
        case .splitter, .magnet, .timer: return 20
        case .shield: return 25
        case .bad: return -60
        }
    }
    var name: String {
        switch self {
        case .normal: return "كرة ضوء"
        case .big: return "عملاقة"
        case .bouncer: return "نطّاطة"
        case .shield: return "مدرّعة"
        case .splitter: return "مشطورة"
        case .magnet: return "مغناطيس"
        case .timer: return "مؤقّتة"
        case .bad: return "مظلمة"
        }
    }
    var note: String {
        switch self {
        case .normal: return "تنفجر وتولّع اللي يمّها"
        case .big: return "انفجارها أكبر بكثير"
        case .bouncer: return "سريعة وتنطّ من الحيطان"
        case .shield: return "تحتاج ضربتين من انفجارين"
        case .splitter: return "تطلق ٣ شرارات طايرة"
        case .magnet: return "تسحب الكرات صوبها قبل ما تنفجر"
        case .timer: return "تنفجر متأخّرة شويّة"
        case .bad: return "إذا فجّرتها تنقص من رصيدك"
        }
    }
}

enum OrbState { case alive, armed, dead }

struct Orb {
    var id: Int
    var kind: OrbKind
    var pos: P
    var vel: P
    var r: Double
    var hp: Int
    var shieldBy: Int = -1
    var phase: Double
    var state: OrbState = .alive
    var fuse: Double = 0
    var gen: Int = 0

    init(id: Int, kind: OrbKind, pos: P, vel: P = .zero, phase: Double = 0) {
        self.id = id; self.kind = kind; self.pos = pos; self.vel = vel
        self.r = kind.radius
        self.hp = kind == .shield ? 2 : 1
        self.phase = phase
    }
}

/// ثوابت المحاكاة
enum Tune {
    static let W = 400.0
    static let H = 720.0
    static let dt = 1.0 / 60.0
    static let growT = 0.34
    static let holdT = 0.26
    static let fadeT = 0.32
    static let sparkSpeed = 280.0
    static let sparkLife = 0.85
    static let sparkR = 5.0
    static let magnetT = 0.75
    static let magnetPull = 150.0
    static let magnetRange = 230.0
    static let timerT = 1.4
    static let tierEvery = 8
    static let maxSteps = 60 * 25
}

/// انفجار: حلقة تكبر ثمّ تثبت ثمّ تخفت
struct Blast {
    var id: Int
    var pos: P
    var maxR: Double
    var age: Double = 0
    var gen: Int
    var source: OrbKind?

    var r: Double {
        if age < Tune.growT {
            let t = age / Tune.growT
            let u = 1 - t
            return maxR * (1 - u * u * u)
        }
        if age < Tune.growT + Tune.holdT { return maxR }
        let t = min(1, (age - Tune.growT - Tune.holdT) / Tune.fadeT)
        return maxR * (1 + 0.18 * t)
    }
    /// يضرب الكرات بس وهو حامي
    var hot: Bool { age < Tune.growT + Tune.holdT }
    var done: Bool { age >= Tune.growT + Tune.holdT + Tune.fadeT }
    /// شفافيّة للرسم 0…1
    var alpha: Double {
        if hot { return 1 }
        return max(0, 1 - (age - Tune.growT - Tune.holdT) / Tune.fadeT)
    }
}

/// شرارة طايرة من الكرة المشطورة
struct Spark {
    var pos: P
    var vel: P
    var life: Double
    var gen: Int
    var alive = true
}

/// أحداث تقرأها الواجهة للصوت والجزيئات والاهتزاز
enum Ev {
    case fire(P)
    case pop(P, OrbKind, Int, Int)   // المكان، النوع، رقم الحلقة، الجيل
    case shield(P)
    case arm(P, OrbKind)
    case split(P)
    case tier(Int)
}

/// نتيجة ضربة كاملة
struct Outcome: Equatable {
    var pops: Int
    var good: Int
    var bad: Int
    var score: Int
    var maxGen: Int
    var net: Int { good - bad }
}
