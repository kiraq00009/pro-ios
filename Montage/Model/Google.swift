import Foundation

/// طريق احتياطيّ: إذا سيرفرنا محجوب (مثل بإيران بلا VPN) نترجم مباشرةً من الموبايل
enum Direct {
    static func code(_ l: Lang) -> String { l == .ku ? "ckb" : l.rawValue }

    static func url(_ text: String, from: Lang?, to: Lang) -> URL {
        var c = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        c.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: from.map(code) ?? "auto"),
            URLQueryItem(name: "tl", value: code(to)),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text),
        ]
        return c.url!
    }

    /// يفكّ ردّ gtx: [[["مترجم","أصل",...],...],null,"ar",...]
    static func parse(_ d: Data) -> (text: String, detected: String?)? {
        guard let root = try? JSONSerialization.jsonObject(with: d) as? [Any], let parts = root.first as? [Any] else { return nil }
        var out = ""
        for p in parts {
            if let a = p as? [Any], let s = a.first as? String { out += s }
        }
        let det = root.count > 2 ? root[2] as? String : nil
        return out.isEmpty ? nil : (out, det)
    }

    static func translate(_ text: String, from: Lang?, to: Lang) async throws -> (text: String, detected: Lang?) {
        var r = URLRequest(url: url(text, from: from, to: to))
        r.timeoutInterval = 20
        r.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (d, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200, let p = parse(d) else { throw Api.Fail.offline }
        let det = p.detected.flatMap { $0 == "ckb" ? Lang.ku : Lang(rawValue: $0) }
        return (p.text, det)
    }

    /// يترجم سطر سطر (يحافظ على عدد الأسطر) — يقسّم النصوص الطويلة لدفعات
    static func lines(_ lines: [String], from: Lang, to: Lang) async throws -> [String] {
        var res: [String] = []
        var batch: [String] = []
        var size = 0
        func flush() async throws {
            guard !batch.isEmpty else { return }
            let r = try await translate(batch.joined(separator: "\n"), from: from, to: to)
            let out = r.text.components(separatedBy: "\n")
            if out.count == batch.count { res += out }
            else {
                for l in batch {
                    if l.trimmingCharacters(in: .whitespaces).isEmpty { res.append(""); continue }
                    res.append(try await translate(l, from: from, to: to).text)
                }
            }
            batch = []; size = 0
        }
        for l in lines {
            let clean = l.replacingOccurrences(of: "\n", with: " ")
            if size + clean.count > 1200 { try await flush() }
            batch.append(clean); size += clean.count + 1
        }
        try await flush()
        return res
    }

    /// نطق عربيّ/إنكليزيّ/تركيّ مباشر (الفارسيّ ماكو هنا — مدمج بالتطبيق أو من سيرفرنا)
    static func ttsURL(_ text: String, lang: Lang) -> URL? {
        guard lang != .fa && lang != .ku else { return nil }
        var c = URLComponents(string: "https://translate.googleapis.com/translate_tts")!
        c.queryItems = [URLQueryItem(name: "client", value: "gtx"), URLQueryItem(name: "ie", value: "UTF-8"),
                        URLQueryItem(name: "tl", value: lang.rawValue), URLQueryItem(name: "q", value: String(text.prefix(190)))]
        return c.url
    }
}
