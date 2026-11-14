import Foundation

/// سطر ترجمة على الفيديو
struct Cue: Identifiable, Codable, Hashable {
    var id = UUID()
    var s: Double
    var e: Double
    var text: String          // الكلام الأصليّ
    var tr: String = ""       // الترجمة
    var words: [Api.Word] = []

    func shown(_ mode: TextMode) -> String {
        switch mode {
        case .original: return text
        case .translation: return tr.isEmpty ? text : tr
        case .both: return tr.isEmpty ? text : tr
        }
    }
}

enum TextMode: String, Codable, CaseIterable, Identifiable {
    case translation, original, both
    var id: String { rawValue }
    var name: String {
        switch self {
        case .translation: return "الترجمة"
        case .original: return "الأصل"
        case .both: return "الاثنين"
        }
    }
}

enum Look: String, Codable, CaseIterable, Identifiable {
    case tiktok, classic, box, neon, cinema
    var id: String { rawValue }
    var name: String {
        switch self {
        case .tiktok: return "تيك توك"
        case .classic: return "كلاسيك"
        case .box: return "صندوق"
        case .neon: return "نيون"
        case .cinema: return "سينما"
        }
    }
}

enum Place: String, Codable, CaseIterable, Identifiable {
    case top, middle, bottom
    var id: String { rawValue }
    var name: String { self == .top ? "فوق" : (self == .middle ? "وسط" : "جوّا") }
    /// موضع مركز النصّ كنسبة من ارتفاع الفيديو (من فوق)
    var y: Double { self == .top ? 0.16 : (self == .middle ? 0.52 : 0.80) }
}

struct Style: Codable, Equatable {
    var look: Look = .tiktok
    var place: Place = .bottom
    var mode: TextMode = .translation
    var size: Double = 1.0              // مضاعف الحجم
    var color: Int = 0xFFFFFF
    var accent: Int = 0xFFD400          // لون الكلمة الحاليّة (تيك توك) / النيون
    var wordsPerChunk: Int = 3          // تيك توك: كم كلمة تطلع مرّة وحدة
    var watermark: String = ""

    static let palette: [Int] = [0xFFFFFF, 0xFFD400, 0x39FF88, 0x4FC3FF, 0xFF4FA3, 0xFF7A1A]

    /// حجم الخطّ بالبكسل حسب عرض الفيديو
    func fontSize(videoWidth w: Double) -> Double {
        let base: Double
        switch look {
        case .tiktok: base = 0.070
        case .cinema: base = 0.042
        case .classic: base = 0.048
        case .box: base = 0.050
        case .neon: base = 0.060
        }
        return (w * base * size).rounded()
    }
}

enum Subs {
    /// مقاطع السيرفر ← أسطر قصيرة مريحة للقراءة (≤ ٤٢ حرف، ≤ ٦ ثواني)
    static func cues(from segs: [Api.Segment]) -> [Cue] {
        var out: [Cue] = []
        for s in segs {
            let text = s.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            let words = s.words ?? []
            if text.count <= 42 && s.e - s.s <= 6.5 || words.count < 2 {
                out.append(Cue(s: s.s, e: max(s.e, s.s + 0.8), text: text, tr: s.tr ?? "", words: words))
                continue
            }
            // نقسّم على الكلمات حسب التوقيت
            var cur: [Api.Word] = []
            var len = 0
            for w in words {
                if !cur.isEmpty && (len + w.w.count > 38 || w.e - cur[0].s > 5.5) {
                    out.append(Cue(s: cur[0].s, e: cur.last!.e, text: cur.map(\.w).joined(separator: " "), words: cur))
                    cur = []; len = 0
                }
                cur.append(w); len += w.w.count + 1
            }
            if !cur.isEmpty { out.append(Cue(s: cur[0].s, e: cur.last!.e, text: cur.map(\.w).joined(separator: " "), words: cur)) }
        }
        return fixOverlaps(out)
    }

    static func fixOverlaps(_ c: [Cue]) -> [Cue] {
        var a = c.sorted { $0.s < $1.s }
        for i in a.indices.dropLast() where a[i].e > a[i + 1].s - 0.04 {
            a[i].e = max(a[i].s + 0.3, a[i + 1].s - 0.04)
        }
        return a
    }

    /// السطر الطويل يتقسّم لسطرين متوازنين
    static func wrap(_ t: String, max: Int = 26) -> [String] {
        guard t.count > max else { return [t] }
        let w = t.split(separator: " ").map(String.init)
        guard w.count > 1 else { return [t] }
        var best = 1, bestDiff = Int.max
        for k in 1..<w.count {
            let a = w[..<k].joined(separator: " ").count, b = w[k...].joined(separator: " ").count
            if abs(a - b) < bestDiff { bestDiff = abs(a - b); best = k }
        }
        return [w[..<best].joined(separator: " "), w[best...].joined(separator: " ")]
    }

    /// تيك توك: كلّ ٢-٤ كلمات تطلع وحدها مع توقيتها
    struct Chunk: Equatable { let s: Double; let e: Double; let words: [String]; let starts: [Double] }

    static func chunks(_ c: Cue, per: Int, translated: Bool) -> [Chunk] {
        let per = Swift.max(1, Swift.min(6, per))
        if !translated && c.words.count >= 1 {
            var out: [Chunk] = []
            var i = 0
            while i < c.words.count {
                let g = Array(c.words[i..<Swift.min(i + per, c.words.count)])
                let end = i + per < c.words.count ? c.words[i + per].s : c.e
                out.append(Chunk(s: g[0].s, e: Swift.max(end, g.last!.e), words: g.map(\.w), starts: g.map(\.s)))
                i += per
            }
            return out
        }
        // الترجمة ما عدها توقيت كلمات ⇒ نوزّع الوقت حسب طول الكلمات
        let words = c.shown(translated ? .translation : .original).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        let total = Double(words.reduce(0) { $0 + $1.count + 1 })
        let span = c.e - c.s
        var t = c.s
        var starts: [Double] = []
        for w in words { starts.append(t); t += span * Double(w.count + 1) / total }
        var out: [Chunk] = []
        var i = 0
        while i < words.count {
            let j = Swift.min(i + per, words.count)
            let end = j < words.count ? starts[j] : c.e
            out.append(Chunk(s: starts[i], e: end, words: Array(words[i..<j]), starts: Array(starts[i..<j])))
            i = j
        }
        return out
    }

    // MARK: SRT

    static func stamp(_ t: Double) -> String {
        let ms = Int((t * 1000).rounded())
        return String(format: "%02d:%02d:%02d,%03d", ms / 3_600_000, ms / 60_000 % 60, ms / 1000 % 60, ms % 1000)
    }

    static func srt(_ cues: [Cue], mode: TextMode) -> String {
        cues.enumerated().map { i, c in
            let body: String
            switch mode {
            case .both: body = c.tr.isEmpty ? c.text : c.tr + "\n" + c.text
            default: body = c.shown(mode)
            }
            return "\(i + 1)\n\(stamp(c.s)) --> \(stamp(c.e))\n\(body)\n"
        }.joined(separator: "\n")
    }

    static func parseStamp(_ s: String) -> Double? {
        let p = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard p.count == 3, let h = Double(p[0]), let m = Double(p[1]), let sec = Double(p[2]) else { return nil }
        return h * 3600 + m * 60 + sec
    }

    static func parseSRT(_ s: String) -> [Cue] {
        let blocks = s.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n\n")
        var out: [Cue] = []
        for b in blocks {
            let lines = b.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard let ti = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let parts = lines[ti].components(separatedBy: "-->")
            guard parts.count == 2, let a = parseStamp(parts[0]), let e = parseStamp(parts[1]) else { continue }
            let text = lines[(ti + 1)...].joined(separator: " ")
            out.append(Cue(s: a, e: e, text: text))
        }
        return out
    }

    /// السطر الظاهر بلحظة معيّنة
    static func active(_ cues: [Cue], at t: Double) -> Cue? {
        var lo = 0, hi = cues.count - 1
        while lo <= hi {
            let m = (lo + hi) / 2
            if cues[m].e < t { lo = m + 1 } else if cues[m].s > t { hi = m - 1 } else { return cues[m] }
        }
        return nil
    }

    static func shift(_ cues: [Cue], by d: Double) -> [Cue] {
        cues.map { var c = $0; c.s = max(0, c.s + d); c.e = max(c.s + 0.2, c.e + d)
            c.words = c.words.map { Api.Word(s: max(0, $0.s + d), e: max(0, $0.e + d), w: $0.w) }; return c }
    }
}
