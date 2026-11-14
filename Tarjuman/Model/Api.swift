import Foundation

/// خدمة الترجمة على سيرفرنا (Whisper للصوت + NLLB للترجمة + نطق طبيعيّ + قراءة صور)
/// ما نعتمد على Google ولا أيّ مزوّد برّا — كلّه على سيرفر دورلي
enum Api {
    static let bases = ["https://dawwirli.watch/proapi", "https://premium.dawwirli.watch/proapi"]
    static let key = "pk_tj_8f3a61c2d94e"
    static var base: String = bases[0]

    struct Word: Codable, Hashable { let s: Double; let e: Double; let w: String }
    struct Segment: Codable, Hashable { let s: Double; let e: Double; let text: String; var words: [Word]? }
    struct Heard: Codable { let lang: String; let text: String; let segments: [Segment]; let secs: Double? }
    struct Translated: Codable { let lines: [String]; let engine: String? }
    struct Talk: Codable { let lang: String; let heard: String; let translated: String; let engine: String? }
    struct Ocr: Codable { let text: String; let lines: [String] }
    struct Ping: Codable { let ok: Bool; let engines: [String: Bool]? }

    enum Fail: LocalizedError {
        case offline, server(Int, String), empty
        var errorDescription: String? {
            switch self {
            case .offline: return "ماكو اتّصال بالسيرفر — جرّب نت ثاني أو شغّل الـVPN"
            case .server(let c, let m): return m.isEmpty ? "السيرفر ردّ بخطأ \(c)" : m
            case .empty: return "ما انسمع شي واضح — قرّب الموبايل وحجي مرّة ثانية"
            }
        }
    }

    static func request(_ path: String, query: [String: String] = [:], body: Data, type: String, base: String) -> URLRequest {
        var c = URLComponents(string: base + path)!
        if !query.isEmpty { c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var r = URLRequest(url: c.url!)
        r.httpMethod = "POST"
        r.httpBody = body
        r.timeoutInterval = 45
        r.setValue(type, forHTTPHeaderField: "Content-Type")
        r.setValue(key, forHTTPHeaderField: "X-Key")
        return r
    }

    /// يرسل ويجرّب الدومين الثاني إذا الأوّل ما ردّ
    /// إذا السيرفر ما ردّ، ما نضيّع وقت عليه ١٠ دقايق ونروح للطريق المباشر فورًا
    static var downUntil: Date = .distantPast
    static var serverDown: Bool { Date() < downUntil }

    static func send(_ path: String, query: [String: String] = [:], body: Data, type: String) async throws -> Data {
        if serverDown && path != "/ping" { throw Fail.offline }
        do { return try await sendRaw(path, query: query, body: body, type: type) }
        catch let e as Fail {
            if case .offline = e { downUntil = Date().addingTimeInterval(600) }
            throw e
        }
    }

    private static func sendRaw(_ path: String, query: [String: String], body: Data, type: String) async throws -> Data {
        var lastErr: Error = Fail.offline
        let order = [base] + bases.filter { $0 != base }
        for b in order {
            do {
                let (d, resp) = try await URLSession.shared.data(for: request(path, query: query, body: body, type: type, base: b))
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 { base = b; return d }
                let msg = (try? JSONDecoder().decode([String: String].self, from: d))?["error"] ?? ""
                lastErr = Fail.server(code, msg)
                if code >= 400 && code < 500 { throw lastErr }
            } catch let e as Fail { throw e }
            catch { lastErr = Fail.offline }
        }
        throw lastErr
    }

    static func json<T: Encodable>(_ v: T) -> Data { (try? JSONEncoder().encode(v)) ?? Data() }

    // MARK: نداءات

    static func talk(audio: Data, from: Lang?, to: Lang, pair: (Lang, Lang)) async throws -> Talk {
        var q = ["to": to.rawValue, "pair": "\(pair.0.rawValue),\(pair.1.rawValue)"]
        if let f = from { q["from"] = f.rawValue }
        let d = try await send("/talk", query: q, body: audio, type: "audio/mp4")
        let t = try JSONDecoder().decode(Talk.self, from: d)
        if t.heard.trimmingCharacters(in: .whitespaces).isEmpty { throw Fail.empty }
        return t
    }

    static func transcribe(audio: Data, lang: Lang?, words: Bool, type: String = "audio/mp4") async throws -> Heard {
        var q: [String: String] = words ? ["words": "1"] : [:]
        if let l = lang { q["lang"] = l.rawValue }
        let d = try await send("/stt", query: q, body: audio, type: type)
        return try JSONDecoder().decode(Heard.self, from: d)
    }

    struct TrBody: Codable { let lines: [String]; let from: String; let to: String }
    static func translate(_ lines: [String], from: Lang, to: Lang) async throws -> [String] {
        if from == to { return lines }
        let clean = lines.map { Script.normalize($0, as: from) }
        do {
            let d = try await send("/tr", body: json(TrBody(lines: clean, from: from.rawValue, to: to.rawValue)), type: "application/json")
            let r = try JSONDecoder().decode(Translated.self, from: d)
            return r.lines.map { Script.normalize($0, as: to) }
        } catch let e as Fail {
            guard case .offline = e else { throw e }
            return try await Direct.lines(clean, from: from, to: to).map { Script.normalize($0, as: to) }
        }
    }

    struct TtsBody: Codable { let text: String; let lang: String; let male: Bool }
    static func speech(_ text: String, lang: Lang, male: Bool) async throws -> Data {
        try await send("/tts", body: json(TtsBody(text: text, lang: lang.rawValue, male: male)), type: "application/json")
    }

    static func ocr(jpeg: Data, lang: Lang) async throws -> Ocr {
        let d = try await send("/ocr", query: ["lang": lang.rawValue], body: jpeg, type: "image/jpeg")
        return try JSONDecoder().decode(Ocr.self, from: d)
    }
}

/// سجلّ المحادثة — يتخزّن بالجهاز
struct Turn: Identifiable, Codable, Hashable {
    let id: UUID
    let from: Lang
    let to: Lang
    let heard: String
    let translated: String
    let date: Date
    /// true = الطرف الأوّل (أنا)، false = الطرف الثاني
    let mine: Bool
}

enum Convo {
    /// يختار لغة الهدف: إذا السيرفر سمع لغة الطرف الثاني نترجم للأوّل والعكس
    static func target(heard: Lang, pair: (Lang, Lang)) -> Lang {
        heard == pair.1 ? pair.0 : pair.1
    }

    /// نصّ قابل للمشاركة للمحادثة كلّها
    static func transcript(_ turns: [Turn]) -> String {
        turns.map { t in
            "\(t.from.flag) \(t.heard)\n\(t.to.flag) \(t.translated)"
        }.joined(separator: "\n\n")
    }
}
