import Foundation

struct ReceiptItem: Equatable {
    var name: String
    var price: Double
}

struct ReceiptResult: Equatable {
    var merchant: String
    var total: Double?
    var items: [ReceiptItem]
    var cat: String
}

/// يقرا نصّ الوصل (أسطر من التعرّف على النصّ) ويطلّع المجموع والمحلّ والمواد
enum Receipt {
    static let totalWords: [String] = ["المجموع", "مجموع", "الاجمالي", "اجمالي", "الإجمالي", "إجمالي", "الصافي", "صافي",
                                       "المطلوب", "المبلغ الكلي", "الكلي", "المستحق", "total", "grand", "amount due", "net", "to pay", "sum"]
    static let skipWords: [String] = ["نقدا", "نقدي", "نقد", "كاش", "cash", "change", "الباقي", "باقي", "المدفوع", "مدفوع", "paid",
                                      "ضريبه", "ضريبة", "vat", "tax", "خصم", "discount", "subtotal", "sub total", "sub-total", "tip", "visa", "card"]
    static let headWords: [String] = ["فاتوره", "فاتورة", "invoice", "receipt", "وصل", "رقم", "tel", "هاتف", "date", "تاريخ", "التاريخ",
                                      "time", "الوقت", "cashier", "كاشير", "www", "http", "@", "order", "طلب"]

    /// الأرقام بالسطر: «12,500» ← 12500، «12.500» ← 12500، «3.75» ← 3.75؛ يتجاهل الطويلة (باركود/تلفون)
    static func numbers(in line: String) -> [Double] {
        let s = Array(AR.norm(line))
        var out: [Double] = []
        var i = 0
        while i < s.count {
            if AR.isDigit(s[i]) {
                var j = i
                while j < s.count && (AR.isDigit(s[j]) || s[j] == "," || s[j] == ".") { j += 1 }
                var run = String(s[i..<j])
                while let l = run.last, l == "," || l == "." { run.removeLast() }
                if let v = parseRun(run) { out.append(v) }
                i = j
            } else {
                i += 1
            }
        }
        return out
    }

    static func parseRun(_ run: String) -> Double? {
        let digits = run.filter { AR.isDigit($0) }
        if digits.isEmpty || digits.count > 9 { return nil }
        let hasComma = run.contains(",")
        let hasDot = run.contains(".")
        var clean = run
        if hasComma && hasDot {
            // الأخير هو الفاصلة العشريّة
            let lastComma = run.lastIndex(of: ",") ?? run.startIndex
            let lastDot = run.lastIndex(of: ".") ?? run.startIndex
            if lastDot > lastComma {
                clean = run.replacingOccurrences(of: ",", with: "")
            } else {
                clean = run.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            }
        } else if hasComma || hasDot {
            let sep: Character = hasComma ? "," : "."
            let parts = run.split(separator: sep, omittingEmptySubsequences: false)
            let thousands = parts.count >= 2 && parts.dropFirst().allSatisfy { $0.count == 3 } && (parts.first?.count ?? 0) <= 3
            if thousands {
                clean = run.replacingOccurrences(of: String(sep), with: "")
            } else if parts.count == 2 {
                clean = String(parts[0]) + "." + String(parts[1])
            } else {
                return nil
            }
        }
        return Double(clean)
    }

    static func has(_ line: String, _ words: [String]) -> Bool {
        let n = AR.norm(line)
        for w in words {
            let nw = AR.norm(w)
            if nw.count <= 3 {
                // كلمة قصيرة: لازم تكون كلمة كاملة
                let toks = n.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "@" }).map(String.init)
                if toks.contains(nw) { return true }
            } else if n.contains(nw) {
                return true
            }
        }
        return false
    }

    static func letterCount(_ s: String) -> Int { s.filter { $0.isLetter }.count }

    static func parse(_ lines: [String]) -> ReceiptResult {
        let ls = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        // المجموع: آخر سطر بيه كلمة مجموع (ومو نقدًا/باقي/ضريبة)
        var total: Double?
        var totalIdx: Int?
        for (i, l) in ls.enumerated() where has(l, totalWords) && !has(l, skipWords) {
            var nums = numbers(in: l)
            if nums.isEmpty, i + 1 < ls.count, letterCount(ls[i + 1]) <= 3 {
                nums = numbers(in: ls[i + 1])
            }
            if let m = nums.max(), m > 0 {
                total = m
                totalIdx = i
            }
        }
        if total == nil {
            var best = 0.0
            for l in ls where !has(l, skipWords) && !has(l, headWords) {
                for v in numbers(in: l) where v > best { best = v }
            }
            if best > 0 { total = best }
        }

        // المحلّ: أوّل سطر نصّيّ بالبداية بلا أرقام
        var merchant = ""
        for l in ls.prefix(5) {
            let digits = AR.norm(l).filter { AR.isDigit($0) }.count
            if letterCount(l) >= 3 && digits == 0 && !has(l, headWords) && !has(l, totalWords) {
                merchant = l
                break
            }
        }

        // المواد: سطر بيه اسم + سعر
        var items: [ReceiptItem] = []
        for (i, l) in ls.enumerated() {
            if i == totalIdx || has(l, totalWords) || has(l, skipWords) || has(l, headWords) { continue }
            if l == merchant { continue }
            let nums = numbers(in: l)
            guard let price = nums.last, price > 0 else { continue }
            if let t = total, price >= t { continue }
            let name = String(l.filter { $0.isLetter || $0 == " " }).trimmingCharacters(in: .whitespaces)
            if letterCount(name) < 2 { continue }
            items.append(ReceiptItem(name: name, price: price))
        }

        var words: [String] = []
        words.append(contentsOf: SpeechParse.tokens(merchant).norm)
        for it in items { words.append(contentsOf: SpeechParse.tokens(it.name).norm) }
        var cat = SpeechParse.guessCat(words) ?? (items.count >= 2 ? "market" : "other")
        if cat == "other" && items.count >= 2 { cat = "market" }
        return ReceiptResult(merchant: merchant, total: total, items: items, cat: cat)
    }
}
