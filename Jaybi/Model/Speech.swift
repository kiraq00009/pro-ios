import Foundation

/// مسودّة مصروف مفهومة من الكلام أو الكتابة الحرّة
struct Draft: Equatable {
    var amount: Double?
    var cat: String
    var note: String
    var dayOffset: Int
}

/// يفهم الأرقام المكتوبة والمنطوقة بالعربيّ: «خمسة وعشرين ألف»، «ربع مليون»، «ألف ونص»، «25 ألف»
enum Num {
    enum Kind { case small, mult, value, frac }

    private static let raw: [(String, Double, Kind)] = {
        var a: [(String, Double, Kind)] = []
        func s(_ v: Double, _ ws: String...) { for w in ws { a.append((w, v, .small)) } }
        s(1, "واحد", "وحده", "واحده", "وحدة", "واحدة")
        s(2, "اثنين", "اثنان", "ثنين", "ثنتين", "اثنتين", "اتنين")
        s(3, "ثلاث", "ثلاثه", "تلاث", "تلاثه", "ثلاثة")
        s(4, "اربع", "اربعه", "أربعة", "أربع")
        s(5, "خمس", "خمسه", "خمسة")
        s(6, "ست", "سته", "ستة")
        s(7, "سبع", "سبعه", "سبعة")
        s(8, "ثمان", "ثمانيه", "ثمن", "ثمنيه", "تمن", "تمنيه", "ثمانية")
        s(9, "تسع", "تسعه", "تسعة")
        s(10, "عشر", "عشره", "عشرة")
        s(11, "احدعش", "احداعش", "حداش", "احدعشر", "احدى عشر")
        s(12, "اثنعش", "اثناعش", "ثنعش", "اطنعش", "اثناعشر")
        s(13, "ثلطعش", "ثلاثطعش", "تلطعش", "ثلتعش")
        s(14, "اربعطعش", "اربعتعش")
        s(15, "خمسطعش", "خمستعش", "خمسطاش")
        s(16, "ستطعش", "سطعش", "ستاش")
        s(17, "سبعطعش", "سبعتعش", "سبعطاش")
        s(18, "ثمنطعش", "ثمانطعش", "تمنطعش", "ثمنتعش")
        s(19, "تسعطعش", "تسعتعش", "تسعطاش")
        s(20, "عشرين", "عشرون")
        s(30, "ثلاثين", "تلاثين", "ثلاثون")
        s(40, "اربعين", "اربعون")
        s(50, "خمسين", "خمسون")
        s(60, "ستين", "ستون")
        s(70, "سبعين", "سبعون")
        s(80, "ثمانين", "ثمنين", "تمانين", "ثمانون")
        s(90, "تسعين", "تسعون")
        s(100, "مية", "مئة", "مائة", "ميه", "مئه")
        s(200, "ميتين", "مئتين", "مئتان", "ميتان")
        s(300, "ثلاثمية", "ثلثمية", "تلثمية", "ثلاثمئة", "ثلاثمائة", "تلاثمية")
        s(400, "اربعمية", "اربعمئة", "أربعمائة")
        s(500, "خمسمية", "خمسمئة", "خمسمائة")
        s(600, "ستمية", "ستمئة", "ستمائة")
        s(700, "سبعمية", "سبعمئة", "سبعمائة")
        s(800, "ثمانمية", "ثمنمية", "تمنمية", "ثمانمئة", "ثمانمائة")
        s(900, "تسعمية", "تسعمئة", "تسعمائة")
        for w in ["الف", "ألف", "آلاف", "الاف", "تلاف", "تالاف", "الآف"] { a.append((w, 1000, .mult)) }
        for w in ["مليون", "ملايين", "ملاين"] { a.append((w, 1_000_000, .mult)) }
        for w in ["الفين", "ألفين", "الفان"] { a.append((w, 2000, .value)) }
        for w in ["مليونين", "مليونان"] { a.append((w, 2_000_000, .value)) }
        for w in ["نص", "نصف"] { a.append((w, 0.5, .frac)) }
        a.append(("ربع", 0.25, .frac))
        return a
    }()

    static let table: [String: (Double, Kind)] = {
        var d: [String: (Double, Kind)] = [:]
        for (w, v, k) in raw {
            let n = AR.norm(w)
            if d[n] == nil { d[n] = (v, k) }
        }
        return d
    }()

    /// رقم مكتوب بالأرقام: «25,000» «2.5» «12٬500»
    static func numeric(_ t: String) -> Double? {
        guard let f = t.first, AR.isDigit(f) else { return nil }
        let s = t.replacingOccurrences(of: ",", with: "")
        return Double(s)
    }

    /// يشيل «و»/«ب» الملتصقة إذا الباقي رقم: «وعشرين» ← «عشرين»
    static func strip(_ t: String) -> String { strip2(t).word }

    /// نفسها + هل كانت البادئة «ب» (يعني رقم جديد: «شاورما وحده بخمسة الاف»)
    static func strip2(_ t: String) -> (word: String, isB: Bool) {
        if table[t] != nil || numeric(t) != nil { return (t, false) }
        for p in ["و", "ب", "بال", "ال"] where t.hasPrefix(p) && t.count > p.count {
            let r = String(t.dropFirst(p.count))
            if table[r] != nil || numeric(r) != nil { return (r, p.hasPrefix("ب")) }
        }
        return (t, false)
    }

    static func isNumberToken(_ t: String) -> Bool {
        let r = strip(t)
        return table[r] != nil || numeric(r) != nil
    }

    /// كلّ المجاميع الرقميّة بالنصّ (النصّ مطبَّع ومقسّم كلمات)
    static func groups(_ toks: [String]) -> [Double] {
        var out: [Double] = []
        var total = 0.0, cur = 0.0, lastMult = 0.0
        var inGroup = false
        var prevSmallUnit = false

        func flush() {
            if inGroup {
                let v = total + cur
                if v > 0 { out.append(v) }
            }
            total = 0; cur = 0; lastMult = 0; inGroup = false; prevSmallUnit = false
        }

        var i = 0
        while i < toks.count {
            let raw = toks[i]
            if raw == "و" {
                i += 1
                continue
            }
            let st = strip2(raw)
            let t = st.word
            if st.isB && inGroup { flush() }
            if let v = numeric(t) {
                if inGroup && cur > 0 && lastMult == 0 && prevSmallUnit == false {
                    flush()
                }
                cur += v
                inGroup = true
                prevSmallUnit = v < 10
            } else if let e = table[t] {
                let v = e.0
                let k = e.1
                switch k {
                case .small:
                    if v == 100 && prevSmallUnit && cur >= 1 && cur <= 9 {
                        cur *= 100
                    } else {
                        cur += v
                    }
                    prevSmallUnit = v < 10
                case .mult:
                    if cur == 0 { cur = 1 }
                    total += cur * v
                    cur = 0
                    lastMult = v
                    prevSmallUnit = false
                case .value:
                    if cur > 0 {
                        total += cur * (v / 2)
                        cur = 0
                    } else {
                        total += v
                    }
                    lastMult = v / 2
                    prevSmallUnit = false
                case .frac:
                    var nextIsMult = false
                    if i + 1 < toks.count, let ne = table[strip(toks[i + 1])], ne.1 == .mult {
                        nextIsMult = true
                    }
                    if nextIsMult {
                        cur += v
                    } else if lastMult > 0 {
                        total += v * lastMult
                    } else if inGroup {
                        cur += v
                    } else {
                        // «نص» لوحدها مو رقم (مثلًا «نص كيلو»)
                        i += 1
                        continue
                    }
                    prevSmallUnit = false
                }
                inGroup = true
            } else {
                flush()
            }
            i += 1
        }
        flush()
        return out
    }
}

/// يفهم جملة مصروف كاملة: المبلغ + الصنف + الملاحظة + اليوم
enum SpeechParse {
    static let fillers: Set<String> = {
        let ws = ["صرفت", "صرفنا", "دفعت", "دفعنا", "اشتريت", "شريت", "شرينا", "جبت", "اخذت", "خذيت", "سويت", "عطيت",
                  "انطيت", "على", "عله", "ع", "ب", "في", "من", "حق", "مال", "مالت", "و", "دينار", "دنانير", "الدينار",
                  "دولار", "دولارات", "اليوم", "امس", "البارحه", "البارح", "قبل", "يومين", "اول", "ريال", "درهم", "جنيه",
                  "ليره", "يورو", "تقريبا", "بس", "حوالي", "كلفني", "كلفتني", "كلف", "صار", "صارت", "بيها", "بي", "عليه"]
        return Set(ws.map { AR.norm($0) })
    }()

    /// كلمات الجملة: الأصليّة + المطبَّعة (نفس الطول)
    static func tokens(_ text: String) -> (orig: [String], norm: [String]) {
        let pre = AR.splitDigits(text)
        var orig: [String] = []
        var norm: [String] = []
        let trimSet = CharacterSet(charactersIn: "،,.؟?!:;«»\"'()[]-—")
        for part in pre.split(whereSeparator: { $0.isWhitespace }) {
            let o = String(part)
            var n = AR.norm(o)
            // ما نشيل النقطة/الفاصلة من نصّ رقم
            if !(n.first.map(AR.isDigit) ?? false) {
                n = n.trimmingCharacters(in: trimSet)
            } else {
                n = n.trimmingCharacters(in: CharacterSet(charactersIn: "،.؟?!:;«»\"'()"))
            }
            if n.isEmpty { continue }
            orig.append(o.trimmingCharacters(in: trimSet))
            norm.append(n)
        }
        return (orig, norm)
    }

    /// يشيل البادئات حتى نطابق الكلمات: «بالمطعم» ← «مطعم»
    static func stems(_ t: String) -> [String] {
        var out = [t]
        var cur = t
        for _ in 0..<2 {
            var changed = false
            for p in ["وال", "بال", "لل", "ال", "و", "ب", "ل"] where cur.hasPrefix(p) && cur.count - p.count >= 2 {
                cur = String(cur.dropFirst(p.count))
                out.append(cur)
                changed = true
                break
            }
            if !changed { break }
        }
        return out
    }

    /// يخمّن الصنف من الكلمات (أوّل كلمة معروفة تفوز)
    static func guessCat(_ normToks: [String]) -> String? {
        for t in normToks {
            if Num.isNumberToken(t) { continue }
            let ss = stems(t)
            for (cid, ws) in Cats.normWords {
                for w in ws {
                    if w.contains(" ") { continue }
                    for s in ss where s == w || (w.count >= 4 && s.hasPrefix(w)) {
                        return cid
                    }
                }
            }
        }
        // عبارات من كلمتين
        let joined = " " + normToks.joined(separator: " ") + " "
        for (cid, ws) in Cats.normWords {
            for w in ws where w.contains(" ") && joined.contains(" " + w + " ") {
                return cid
            }
        }
        return nil
    }

    static func dayOffset(_ normToks: [String]) -> Int {
        let j = " " + normToks.joined(separator: " ") + " "
        if j.contains(" اول امس ") || j.contains(" قبل يومين ") || j.contains(" اول البارحه ") { return -2 }
        if j.contains(" امس ") || j.contains(" البارحه ") || j.contains(" البارح ") || j.contains(" مبارح ") { return -1 }
        return 0
    }

    static func parse(_ text: String) -> Draft {
        let (orig, norm) = tokens(text)
        let gs = Num.groups(norm)
        let amount = gs.max()
        let cat = guessCat(norm) ?? "other"
        var noteParts: [String] = []
        for (i, n) in norm.enumerated() {
            if Num.isNumberToken(n) { continue }
            if fillers.contains(n) { continue }
            noteParts.append(orig[i])
        }
        var note = noteParts.joined(separator: " ")
        if note.isEmpty { note = Cats.get(cat).name }
        return Draft(amount: amount, cat: cat, note: note, dayOffset: dayOffset(norm))
    }
}
