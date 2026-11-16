import Foundation

// MARK: - سجلّ التنظيف + السلسلة + المستويات

struct FZEntry: Codable, Equatable {
    var day: Int
    var bytes: Int64
    var count: Int
}

struct FZLedger: Codable, Equatable {
    var freed: Int64 = 0
    var items: Int = 0
    var streak: Int = 0
    var best: Int = 0
    var lastDay: Int? = nil
    var sessions: Int = 0
    var converted: Int = 0
    var history: [FZEntry] = []

    mutating func record(bytes: Int64, count: Int, day: Int, converted conv: Int = 0) {
        guard count > 0 else { return }
        freed += max(0, bytes)
        items += count
        sessions += 1
        converted += max(0, conv)
        if let l = lastDay {
            if day == l { streak = max(streak, 1) }
            else if day == l + 1 { streak += 1 }
            else { streak = 1 }
        } else {
            streak = 1
        }
        lastDay = day
        best = max(best, streak)
        if let i = history.lastIndex(where: { $0.day == day }) {
            history[i].bytes += max(0, bytes)
            history[i].count += count
        } else {
            history.append(FZEntry(day: day, bytes: max(0, bytes), count: count))
        }
        if history.count > 120 { history.removeFirst(history.count - 120) }
    }

    /// السلسلة الحاليّة فعلًا: تنقطع إذا فات يوم كامل بدون تنظيف
    func liveStreak(today: Int) -> Int {
        guard let l = lastDay else { return 0 }
        let gap = today - l
        return (gap >= 0 && gap <= 1) ? streak : 0
    }

    /// آخر 7 أيّام (الأقدم أوّلًا، اليوم آخرًا)
    func week(today: Int) -> [Int64] {
        (0..<7).map { k -> Int64 in
            let d = today - 6 + k
            return history.first { $0.day == d }?.bytes ?? 0
        }
    }
}

enum FZLevel {
    static let names = ["مبتدئ", "مرتّب", "منظّم", "خبير الفرز", "سيّد المساحة", "أسطورة"]
    static let marks: [Int64] = [0, 100_000_000, 1_000_000_000, 5_000_000_000, 20_000_000_000, 50_000_000_000]

    static func index(_ b: Int64) -> Int {
        var i = 0
        for k in 0..<marks.count where b >= marks[k] { i = k }
        return i
    }

    static func name(_ b: Int64) -> String { names[index(b)] }

    /// التقدّم نحو المستوى التالي 0…1
    static func progress(_ b: Int64) -> Double {
        let i = index(b)
        if i >= marks.count - 1 { return 1 }
        let span = Double(marks[i + 1] - marks[i])
        return max(0, min(1, Double(b - marks[i]) / span))
    }

    static func remaining(_ b: Int64) -> Int64 {
        let i = index(b)
        if i >= marks.count - 1 { return 0 }
        return marks[i + 1] - b
    }
}

struct FZBadge: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let unlocked: Bool
}

enum FZBadges {
    static func all(_ l: FZLedger) -> [FZBadge] {
        [
            FZBadge(id: "first", title: "أوّل خطوة", detail: "أوّل تنظيف", icon: "sparkles", unlocked: l.items > 0),
            FZBadge(id: "hundred", title: "مئة", detail: "احذف 100 عنصر", icon: "number", unlocked: l.items >= 100),
            FZBadge(id: "thousand", title: "ألف", detail: "احذف 1000 عنصر", icon: "flame.fill", unlocked: l.items >= 1000),
            FZBadge(id: "gb1", title: "غيغا كاملة", detail: "وفّر 1 غيغا", icon: "externaldrive.fill", unlocked: l.freed >= 1_000_000_000),
            FZBadge(id: "gb10", title: "عشرة غيغا", detail: "وفّر 10 غيغا", icon: "externaldrive.badge.checkmark", unlocked: l.freed >= 10_000_000_000),
            FZBadge(id: "streak3", title: "ثلاثة أيّام", detail: "سلسلة 3 أيّام", icon: "calendar", unlocked: l.best >= 3),
            FZBadge(id: "streak7", title: "أسبوع كامل", detail: "سلسلة 7 أيّام", icon: "calendar.badge.clock", unlocked: l.best >= 7),
            FZBadge(id: "live", title: "محوّل", detail: "حوّل 10 صور حيّة", icon: "livephoto", unlocked: l.converted >= 10),
            FZBadge(id: "sessions", title: "مواظب", detail: "10 جلسات تنظيف", icon: "checkmark.seal.fill", unlocked: l.sessions >= 10),
        ]
    }

    static func unlockedCount(_ l: FZLedger) -> Int { all(l).filter { $0.unlocked }.count }
}

// MARK: - رزمة السحب (يسار = حذف، يمين = إبقاء)

enum FZChoice: Int, Codable, Equatable {
    case keep = 0, trash = 1
}

struct FZDeck: Equatable {
    let ids: [String]
    let sizes: [Int64]
    private(set) var choices: [FZChoice] = []

    init(ids: [String], sizes: [Int64]) {
        self.ids = ids
        var s = sizes
        if s.count < ids.count { s += [Int64](repeating: 0, count: ids.count - s.count) }
        self.sizes = Array(s.prefix(ids.count))
    }

    var position: Int { choices.count }
    var isDone: Bool { position >= ids.count }
    var currentID: String? { isDone ? nil : ids[position] }
    var remaining: Int { max(0, ids.count - position) }
    var fraction: Double { ids.isEmpty ? 1 : Double(position) / Double(ids.count) }

    @discardableResult
    mutating func choose(_ c: FZChoice) -> Bool {
        guard !isDone else { return false }
        choices.append(c)
        return true
    }

    @discardableResult
    mutating func undo() -> FZChoice? { choices.popLast() }

    /// تعديل قرار سابق من شاشة الخلاصة
    mutating func set(_ i: Int, _ c: FZChoice) {
        guard i >= 0, i < choices.count else { return }
        choices[i] = c
    }

    mutating func restart() { choices = [] }

    var trashIndices: [Int] { choices.indices.filter { choices[$0] == .trash } }
    var trashIDs: [String] { trashIndices.map { ids[$0] } }
    var trashBytes: Int64 { trashIndices.reduce(Int64(0)) { $0 + sizes[$1] } }
    var keepCount: Int { choices.filter { $0 == .keep }.count }
    var trashCount: Int { choices.filter { $0 == .trash }.count }
}
