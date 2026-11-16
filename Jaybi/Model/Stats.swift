import Foundation

struct CatSum: Equatable {
    var cat: String
    var total: Double
}

struct Insight: Equatable {
    var cat: String
    var pct: Int      // نسبة الزيادة
}

/// حسابات الشهر: المجموع، حسب الصنف، المعدّل، متى تخلص الميزانيّة، والمقارنة بالشهر الماضي
enum Stats {
    static func monthStart(_ d: Date, _ cal: Calendar) -> Date {
        let c = cal.dateComponents([.year, .month], from: d)
        return cal.date(from: c) ?? d
    }

    static func addMonths(_ d: Date, _ n: Int, _ cal: Calendar) -> Date {
        cal.date(byAdding: .month, value: n, to: monthStart(d, cal)) ?? d
    }

    static func daysInMonth(_ d: Date, _ cal: Calendar) -> Int {
        cal.range(of: .day, in: .month, for: d)?.count ?? 30
    }

    static func inMonth(_ xs: [Expense], _ d: Date, _ cal: Calendar) -> [Expense] {
        let a = monthStart(d, cal)
        let b = addMonths(d, 1, cal)
        return xs.filter { $0.date >= a && $0.date < b }
    }

    static func inDay(_ xs: [Expense], _ d: Date, _ cal: Calendar) -> [Expense] {
        xs.filter { cal.isDate($0.date, inSameDayAs: d) }
    }

    static func sum(_ xs: [Expense]) -> Double {
        xs.reduce(0) { $0 + $1.amount }
    }

    static func byCat(_ xs: [Expense]) -> [CatSum] {
        var d: [String: Double] = [:]
        for x in xs { d[x.cat, default: 0] += x.amount }
        return d.map { CatSum(cat: $0.key, total: $0.value) }
            .sorted { $0.total == $1.total ? $0.cat < $1.cat : $0.total > $1.total }
    }

    /// مجموع كلّ يوم بالشهر (index 0 = يوم 1)
    static func daily(_ xs: [Expense], _ d: Date, _ cal: Calendar) -> [Double] {
        var out = [Double](repeating: 0, count: daysInMonth(d, cal))
        for x in inMonth(xs, d, cal) {
            let day = cal.component(.day, from: x.date)
            if day >= 1 && day <= out.count { out[day - 1] += x.amount }
        }
        return out
    }

    static func dailyAvg(spent: Double, day: Int) -> Double {
        day > 0 ? spent / Double(day) : 0
    }

    /// إذا يكمل بنفس المعدّل، بأيّ يوم من الشهر تخلص الميزانيّة؟ nil = ما تخلص هالشهر
    static func runOutDay(budget: Double, spent: Double, day: Int, daysInMonth: Int) -> Int? {
        guard budget > 0, day > 0 else { return nil }
        if spent >= budget { return day }
        let avg = spent / Double(day)
        guard avg > 0 else { return nil }
        let left = budget - spent
        let more = Int((left / avg).rounded(.down))
        let d = day + more
        return d < daysInMonth ? max(d, day) : nil
    }

    /// أكبر صنف زاد صرفه مقارنةً بنفس الفترة من الشهر الماضي (أوّل N يوم)
    static func biggestRise(_ xs: [Expense], now: Date, _ cal: Calendar, minBase: Double) -> Insight? {
        let day = cal.component(.day, from: now)
        let cur = inMonth(xs, now, cal).filter { cal.component(.day, from: $0.date) <= day }
        let prevMonth = addMonths(now, -1, cal)
        let prevDays = daysInMonth(prevMonth, cal)
        let prev = inMonth(xs, prevMonth, cal).filter { cal.component(.day, from: $0.date) <= min(day, prevDays) }
        let c = Dictionary(byCat(cur).map { ($0.cat, $0.total) }, uniquingKeysWith: +)
        let p = Dictionary(byCat(prev).map { ($0.cat, $0.total) }, uniquingKeysWith: +)
        var best: Insight?
        var bestDelta = 0.0
        for (cat, v) in c {
            let base = p[cat] ?? 0
            guard base >= minBase, v > base else { continue }
            let pct = Int(((v - base) / base * 100).rounded())
            let delta = v - base
            if pct >= 15 && delta > bestDelta {
                bestDelta = delta
                best = Insight(cat: cat, pct: pct)
            }
        }
        return best
    }

    /// نصّ CSV للتصدير
    static func csv(_ xs: [Expense], cur: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        func q(_ s: String) -> String {
            if s.contains(",") || s.contains("\"") || s.contains("\n") { return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
            return s
        }
        var rows = ["التاريخ,المبلغ,العملة,الصنف,الملاحظة,الطريقة"]
        for x in xs.sorted(by: { $0.date < $1.date }) {
            let via: String
            switch x.via {
            case .type: via = "كتابة"
            case .voice: via = "صوت"
            case .scan: via = "تصوير"
            }
            let amt = x.amount == x.amount.rounded() ? String(Int(x.amount)) : String(format: "%.2f", x.amount)
            rows.append([f.string(from: x.date), amt, q(cur), q(Cats.get(x.cat).name), q(x.note), via].joined(separator: ","))
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }
}
