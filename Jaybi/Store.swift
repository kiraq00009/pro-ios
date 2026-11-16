import SwiftUI

/// الحفظ: ملفّ JSON واحد بمجلّد التطبيق
struct DayGroup: Identifiable {
    var id: Date
    var items: [Expense]
}

@MainActor
final class JStore: ObservableObject {
    @Published var items: [Expense] = []
    @Published var budget: Double = 0
    @Published var currency: String = "د.ع"
    @Published var onboarded: Bool = false

    private struct SaveFile: Codable {
        var items: [Expense]
        var budget: Double
        var currency: String
        var onboarded: Bool
    }

    private var url: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("jaybi.json")
    }

    init() {
        if Shot.on {
            loadDemo()
            return
        }
        load()
    }

    private func load() {
        guard let d = try? Data(contentsOf: url) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let f = try? dec.decode(SaveFile.self, from: d) else { return }
        items = f.items
        budget = f.budget
        currency = f.currency
        onboarded = f.onboarded
    }

    func save() {
        if Shot.on { return }
        let f = SaveFile(items: items, budget: budget, currency: currency, onboarded: onboarded)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        guard let d = try? enc.encode(f) else { return }
        try? d.write(to: url, options: .atomic)
    }

    // ——— تعديل ———
    func add(_ e: Expense) {
        items.append(e)
        save()
    }

    func update(_ e: Expense) {
        if let i = items.firstIndex(where: { $0.id == e.id }) {
            items[i] = e
        } else {
            items.append(e)
        }
        save()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clearAll() {
        items = []
        save()
    }

    // ——— قراءة ———
    var cal: Calendar { JDate.cal }

    func month(_ d: Date) -> [Expense] { Stats.inMonth(items, d, cal) }

    func spent(_ d: Date) -> Double { Stats.sum(month(d)) }

    func today(_ now: Date = Date()) -> Double { Stats.sum(Stats.inDay(items, now, cal)) }

    /// المصاريف مجمّعة حسب اليوم (الأحدث أوّلًا)
    func grouped(limitDays: Int = 60, now: Date = Date()) -> [DayGroup] {
        let start = cal.date(byAdding: .day, value: -limitDays, to: cal.startOfDay(for: now)) ?? now
        let xs = items.filter { $0.date >= start }.sorted { $0.date > $1.date }
        var out: [DayGroup] = []
        for x in xs {
            let d = cal.startOfDay(for: x.date)
            if let last = out.last, last.id == d {
                out[out.count - 1].items.append(x)
            } else {
                out.append(DayGroup(id: d, items: [x]))
            }
        }
        return out
    }

    func csvFile() -> URL? {
        let text = Stats.csv(items, cur: currency)
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("جيبي-مصاريفي.csv")
        do {
            try Data(text.utf8).write(to: u, options: .atomic)
            return u
        } catch {
            return nil
        }
    }

    // ——— بيانات تجريبيّة لصور الشاشات ———
    func loadDemo() {
        budget = 1_000_000
        currency = "د.ع"
        onboarded = true
        let now = Date()
        let c = cal
        func at(_ dayBack: Int, _ h: Int, _ m: Int) -> Date {
            let base = c.date(byAdding: .day, value: -dayBack, to: now) ?? now
            return c.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base
        }
        var xs: [Expense] = [
            Expense(amount: 25000, cat: "food", note: "عشا ويّا الربع", date: at(0, 21, 12), via: .voice),
            Expense(amount: 8000, cat: "transport", note: "تكسي", date: at(0, 18, 40), via: .type),
            Expense(amount: 12500, cat: "market", note: "سوبرماركت النخلة", date: at(0, 16, 5), via: .scan),
            Expense(amount: 10000, cat: "bills", note: "رصيد", date: at(1, 13, 20), via: .voice),
            Expense(amount: 6000, cat: "coffee", note: "قهوة الصبح", date: at(1, 9, 10), via: .voice),
            Expense(amount: 45000, cat: "shopping", note: "تيشيرت", date: at(2, 19, 0), via: .type),
            Expense(amount: 20000, cat: "fuel", note: "بنزين", date: at(2, 8, 30), via: .voice),
            Expense(amount: 18000, cat: "food", note: "غدا شاورما", date: at(3, 14, 15), via: .voice),
            Expense(amount: 32000, cat: "market", note: "أغراض البيت", date: at(4, 17, 45), via: .scan),
            Expense(amount: 15000, cat: "fun", note: "سينما", date: at(5, 22, 0), via: .type),
            Expense(amount: 9000, cat: "health", note: "صيدلية", date: at(6, 11, 0), via: .scan),
        ]
        let fill: [(String, Double, String)] = [
            ("food", 22000, "مطعم"), ("transport", 7000, "كريم"), ("market", 28000, "ماركت"), ("coffee", 5000, "كافيه"),
            ("bills", 60000, "مولّدة"), ("food", 30000, "بيتزا"), ("transport", 9000, "تكسي"), ("gifts", 40000, "هديّة"),
        ]
        let day = c.component(.day, from: now)
        var k = 0
        if day > 8 {
            for d in stride(from: 7, to: day - 1, by: 1) {
                let f = fill[k % fill.count]
                xs.append(Expense(amount: f.1, cat: f.0, note: f.2, date: at(d, 13, 0), via: k % 3 == 0 ? .voice : .type))
                k += 1
            }
        }
        // الشهر الماضي (للمقارنة)
        for d in 0..<26 {
            let f = fill[(d + 3) % fill.count]
            let base = Stats.addMonths(now, -1, c)
            let dt = c.date(byAdding: .day, value: d, to: base) ?? base
            let amount = f.0 == "food" ? f.1 * 0.7 : f.1
            xs.append(Expense(amount: amount, cat: f.0, note: f.2, date: dt.addingTimeInterval(13 * 3600), via: .type))
        }
        items = xs
    }
}
