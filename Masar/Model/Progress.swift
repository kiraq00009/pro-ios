import Foundation

// التقدّم: المستويات والرتب، الشارات، السلاسل اليوميّة، هدف الأسبوع، والأرقام القياسيّة

enum Levels {
    static let ranks = ["مستكشف", "عدّاء الأحياء", "حارس الشوارع", "سيّد الخلايا", "فاتح المدن", "إمبراطور الخريطة"]

    static func xp(_ s: Session) -> Int {
        Int((s.distance / 1000 * 10).rounded()) + s.newCells * 2 + s.loops * 25
    }

    static func xp(_ all: [Session]) -> Int { all.reduce(0) { $0 + xp($1) } }

    /// النقاط المطلوبة للانتقال من مستوى l إلى l+1
    static func need(_ l: Int) -> Int { 100 + 60 * (l - 1) }

    static func level(_ xp: Int) -> (level: Int, into: Int, need: Int) {
        var l = 1, rem = max(0, xp)
        while rem >= need(l) { rem -= need(l); l += 1 }
        return (l, rem, need(l))
    }

    static func rank(_ level: Int) -> String { ranks[min(ranks.count - 1, max(0, (level - 1) / 5))] }
}

enum Days {
    static func index(_ t: Double, tz: Double) -> Int { Int(((t + tz) / 86400).rounded(.down)) }

    /// يوم الأسبوع: 0 = أحد … 6 = سبت (1970-01-01 كان خميس)
    static func weekday(_ day: Int) -> Int { ((day + 4) % 7 + 7) % 7 }

    /// أوّل يوم من الأسبوع اللي بيه اليوم
    static func weekStart(_ day: Int, firstWeekday: Int) -> Int { day - ((weekday(day) - firstWeekday + 7) % 7) }

    static func hour(_ t: Double, tz: Double) -> Int {
        let s = (t + tz).truncatingRemainder(dividingBy: 86400)
        return Int(((s < 0 ? s + 86400 : s) / 3600).rounded(.down))
    }

    /// السلسلة الحاليّة (تنحسب إذا تحرّكت اليوم أو البارحة) وأطول سلسلة
    static func streak(_ days: Set<Int>, today: Int) -> (current: Int, best: Int) {
        var cur = 0
        var d = days.contains(today) ? today : today - 1
        while days.contains(d) { cur += 1; d -= 1 }
        var best = 0, run = 0
        var prev: Int? = nil
        for x in days.sorted() {
            if let p = prev, x == p + 1 { run += 1 } else { run = 1 }
            best = max(best, run)
            prev = x
        }
        return (cur, best)
    }
}

struct Badge: Identifiable, Equatable {
    let id: String
    let title: String
    let desc: String
    let icon: String
    let tone: Int      // 0 نعناعي 1 سماوي 2 بنفسجي 3 ذهبي 4 مرجاني
}

struct BadgeContext {
    var sessions: [Session]
    var areaKm2: Double
    var everCells: Int
    var bestStreak: Int
    var tz: Double
}

enum Badges {
    static let all: [Badge] = [
        Badge(id: "first", title: "أوّل خطوة", desc: "أكمل أوّل جولة", icon: "flag.fill", tone: 0),
        Badge(id: "loop", title: "الدائرة الأولى", desc: "اقفل أوّل دائرة وخذ كلّ اللي داخلها", icon: "lasso", tone: 1),
        Badge(id: "5k", title: "أوّل 5 كم", desc: "جولة وحدة بطول 5 كم أو أكثر", icon: "5.circle.fill", tone: 3),
        Badge(id: "10runs", title: "عشر جولات", desc: "أكمل 10 جولات", icon: "10.circle.fill", tone: 2),
        Badge(id: "night", title: "عدّاء الليل", desc: "جولة تبدأ بعد 10 بالليل", icon: "moon.stars.fill", tone: 2),
        Badge(id: "dawn", title: "طير الفجر", desc: "جولة تبدأ بين 5 و7 الصبح", icon: "sunrise.fill", tone: 3),
        Badge(id: "km2", title: "إمبراطوريّة كيلومتر", desc: "سيطر على 1 كم² حيّة بنفس الوقت", icon: "crown.fill", tone: 3),
        Badge(id: "cells500", title: "500 خليّة", desc: "خذ 500 خليّة مختلفة بالمجموع", icon: "hexagon.fill", tone: 0),
        Badge(id: "streak3", title: "ثلاث أيّام", desc: "تحرّك 3 أيّام متتالية", icon: "flame", tone: 4),
        Badge(id: "streak7", title: "أسبوع نار", desc: "تحرّك 7 أيّام متتالية", icon: "flame.fill", tone: 4),
        Badge(id: "half", title: "نصف ماراثون", desc: "جولة وحدة 21.1 كم", icon: "medal.fill", tone: 3),
        Badge(id: "climb", title: "متسلّق", desc: "صعود 150 م بجولة وحدة", icon: "mountain.2.fill", tone: 1),
        Badge(id: "century", title: "المئة", desc: "100 كم بالمجموع", icon: "infinity", tone: 1),
        Badge(id: "big", title: "دائرة عملاقة", desc: "دائرة وحدة مساحتها نصّ كم²", icon: "circle.dashed", tone: 0)
    ]

    static func badge(_ id: String) -> Badge? { all.first { $0.id == id } }

    static func earned(_ c: BadgeContext) -> Set<String> {
        var e = Set<String>()
        let s = c.sessions
        if !s.isEmpty { e.insert("first") }
        if s.contains(where: { $0.loops > 0 }) { e.insert("loop") }
        if s.contains(where: { $0.distance >= 5000 }) { e.insert("5k") }
        if s.count >= 10 { e.insert("10runs") }
        if s.contains(where: { let h = Days.hour($0.start, tz: c.tz); return h >= 22 || h < 4 }) { e.insert("night") }
        if s.contains(where: { let h = Days.hour($0.start, tz: c.tz); return h >= 5 && h < 7 }) { e.insert("dawn") }
        if c.areaKm2 >= 1 { e.insert("km2") }
        if c.everCells >= 500 { e.insert("cells500") }
        if c.bestStreak >= 3 { e.insert("streak3") }
        if c.bestStreak >= 7 { e.insert("streak7") }
        if s.contains(where: { $0.distance >= 21097 }) { e.insert("half") }
        if s.contains(where: { $0.elevGain >= 150 }) { e.insert("climb") }
        if s.reduce(0, { $0 + $1.distance }) >= 100_000 { e.insert("century") }
        if s.contains(where: { $0.biggestLoop >= 500_000 }) { e.insert("big") }
        return e
    }
}

struct Records: Equatable {
    var longest: Double = 0
    var longestTime: Double = 0
    var best1k: Double? = nil
    var best5k: Double? = nil
    var mostCells = 0
    var biggestLoop = 0.0
    var fastestKmh = 0.0

    static func of(_ s: [Session]) -> Records {
        var r = Records()
        for x in s {
            r.longest = max(r.longest, x.distance)
            r.longestTime = max(r.longestTime, x.active)
            r.mostCells = max(r.mostCells, x.newCells)
            r.biggestLoop = max(r.biggestLoop, x.biggestLoop)
            if x.activity != .cycle {
                if let b = x.best1k { r.best1k = min(r.best1k ?? b, b) }
                if let b = x.best5k { r.best5k = min(r.best5k ?? b, b) }
            }
            if x.activity == .cycle { r.fastestKmh = max(r.fastestKmh, x.kmh) }
        }
        return r
    }
}

enum Week {
    /// مسافة كلّ يوم من أيّام الأسبوع الحالي (7 قيم بالمتر)
    static func days(_ s: [Session], today: Int, firstWeekday: Int, tz: Double) -> [Double] {
        let ws = Days.weekStart(today, firstWeekday: firstWeekday)
        var out = [Double](repeating: 0, count: 7)
        for x in s {
            let d = Days.index(x.start, tz: tz) - ws
            if d >= 0 && d < 7 { out[d] += x.distance }
        }
        return out
    }
}
