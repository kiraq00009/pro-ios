import Foundation

/// اتّصال بسيرفرنا (Whisper للتفريغ + Gemini/موديلنا للتلخيص). إذا محجوب نشتغل على الجهاز.
enum Api {
    static let bases = ["https://dawwirli.watch/proapi", "https://premium.dawwirli.watch/proapi"]
    static var key = "pk_mt_c92d5e17a8b4"
    static var base: String = bases[0]
    static var downUntil: Date = .distantPast
    static var serverDown: Bool { Date() < downUntil }

    struct Word: Codable, Hashable { let s: Double; let e: Double; let w: String }
    struct Segment: Codable, Hashable { var s: Double; var e: Double; var text: String; var words: [Word]? = nil; var tr: String? = nil }
    struct Heard: Codable { let lang: String; let text: String; let segments: [Segment]; let secs: Double? }
    struct Translated: Codable { let lines: [String]; let engine: String? }
    struct Summary: Codable, Hashable { var title: String; var summary: String; var points: [String]; var actions: [String]; var engine: String? }
    struct Subs: Codable { let lang: String; let segments: [Segment]; let secs: Double? }

    enum Fail: LocalizedError {
        case offline, server(Int, String), empty
        var errorDescription: String? {
            switch self {
            case .offline: return "سيرفرنا ما يوصل من هالشبكة — جرّبت الطريق الاحتياطيّ على الموبايل"
            case .server(let c, let m): return m.isEmpty ? "السيرفر ردّ بخطأ \(c)" : m
            case .empty: return "ما انسمع كلام واضح بالملفّ"
            }
        }
    }

    static func request(_ path: String, query: [String: String] = [:], body: Data, type: String, base: String, timeout: Double) -> URLRequest {
        var c = URLComponents(string: base + path)!
        if !query.isEmpty { c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var r = URLRequest(url: c.url!)
        r.httpMethod = "POST"; r.httpBody = body; r.timeoutInterval = timeout
        r.setValue(type, forHTTPHeaderField: "Content-Type")
        r.setValue(key, forHTTPHeaderField: "X-Key")
        return r
    }

    static func send(_ path: String, query: [String: String] = [:], body: Data, type: String, timeout: Double = 300) async throws -> Data {
        if serverDown { throw Fail.offline }
        var lastErr: Fail = .offline
        for b in [base] + bases.filter({ $0 != base }) {
            do {
                let (d, resp) = try await URLSession.shared.data(for: request(path, query: query, body: body, type: type, base: b, timeout: timeout))
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 { base = b; return d }
                let msg = (try? JSONDecoder().decode([String: String].self, from: d))?["error"] ?? ""
                lastErr = .server(code, msg)
                if code >= 400 && code < 500 { throw lastErr }
            } catch let e as Fail { throw e }
            catch { lastErr = .offline }
        }
        if case .offline = lastErr { downUntil = Date().addingTimeInterval(600) }
        throw lastErr
    }

    static func transcribe(audio: Data, lang: Lang?, words: Bool = false) async throws -> Heard {
        var q: [String: String] = words ? ["words": "1"] : [:]
        if let l = lang { q["lang"] = l.rawValue }
        return try JSONDecoder().decode(Heard.self, from: try await send("/stt", query: q, body: audio, type: "audio/mp4"))
    }

    static func subs(audio: Data, lang: Lang?, to: Lang?) async throws -> Subs {
        var q: [String: String] = [:]
        if let l = lang { q["lang"] = l.rawValue }
        if let t = to { q["to"] = t.rawValue }
        return try JSONDecoder().decode(Subs.self, from: try await send("/subs", query: q, body: audio, type: "audio/mp4", timeout: 900))
    }

    struct SumBody: Codable { let text: String; let lang: String }
    static func summarize(_ text: String, lang: Lang) async throws -> Summary {
        let d = try await send("/sum", body: (try? JSONEncoder().encode(SumBody(text: text, lang: lang.rawValue))) ?? Data(), type: "application/json", timeout: 120)
        return try JSONDecoder().decode(Summary.self, from: d)
    }

    struct TrBody: Codable { let lines: [String]; let from: String; let to: String }
    static func translate(_ lines: [String], from: Lang, to: Lang) async throws -> [String] {
        if from == to { return lines }
        do {
            let d = try await send("/tr", body: (try? JSONEncoder().encode(TrBody(lines: lines, from: from.rawValue, to: to.rawValue))) ?? Data(), type: "application/json", timeout: 120)
            return try JSONDecoder().decode(Translated.self, from: d).lines
        } catch let e as Fail {
            guard case .offline = e else { throw e }
            return try await Direct.lines(lines, from: from, to: to)
        }
    }
}
