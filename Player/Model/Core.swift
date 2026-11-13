import Foundation

// منطق «بلاير» الخالص (Foundation فقط): أنواع البيانات، قارئ M3U، وروابط Xtream — ينفحص باختبارات آليّة

enum SourceKind: String, Codable { case xtream, m3u, demo }

struct Profile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: SourceKind
    var server = ""
    var user = ""
    var pass = ""
    var m3u = ""
    var ua = "VLC/3.0.20 LibVLC/3.0.20"
}

struct Cat: Codable, Identifiable, Hashable { var id: String; var name: String }

struct Channel: Codable, Identifiable, Hashable {
    var id: String; var name: String; var logo = ""; var cat = ""; var url = ""; var epg = ""
}
struct Movie: Codable, Identifiable, Hashable {
    var id: String; var name: String; var poster = ""; var cat = ""; var ext = "mp4"; var rating = 0.0; var year = ""; var url = ""; var added = 0.0
}
struct Show: Codable, Identifiable, Hashable {
    var id: String; var name: String; var poster = ""; var cat = ""; var rating = 0.0; var year = ""; var plot = ""; var added = 0.0
}
struct Episode: Codable, Identifiable, Hashable {
    var id: String; var season: Int; var num: Int; var title = ""; var ext = "mp4"; var url = ""; var mins = 0
}
struct Program: Identifiable, Hashable { var id: String; var title: String; var desc: String; var start: Date; var end: Date }

struct Content: Codable {
    var liveCats: [Cat] = [], vodCats: [Cat] = [], seriesCats: [Cat] = []
    var channels: [Channel] = [], movies: [Movie] = [], shows: [Show] = []
    var episodes: [String: [Episode]] = [:]          // لقوائم M3U: حلقات كلّ مسلسل جاهزة
    var at = 0.0
    var isEmpty: Bool { channels.isEmpty && movies.isEmpty && shows.isEmpty }
}

enum Core {
    // MARK: نصوص

    /// أسماء المزوّدين بيها بادئات ورموز (AR| · EN - · [4K] · السنة بالآخر) — ننظّفها للعرض
    static func clean(_ n: String) -> String {
        var s = n
        for r in ["^\\s*[A-Za-z0-9]{2,4}\\s*[|:]\\s*", "^\\s*[A-Z]{2,3}\\s+-\\s+", "\\[[^\\]]*\\]", "\\((19|20)\\d{2}\\)\\s*$", "\\s+-\\s+(19|20)\\d{2}\\s*$"] {
            s = s.replacingOccurrences(of: r, with: "", options: .regularExpression)
        }
        s = s.trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? n.trimmingCharacters(in: .whitespaces) : s
    }
    static func year(_ n: String) -> String {
        guard let r = n.range(of: "(19|20)\\d{2}(?=\\D*$)", options: .regularExpression) else { return "" }
        return String(n[r])
    }
    static func str(_ v: Any?) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return ""
    }
    static func num(_ v: Any?) -> Double {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s) ?? 0 }
        return 0
    }

    // MARK: Xtream

    /// نرتّب عنوان السيرفر: نضيف http إذا ناقص، ونشيل الشرطة وأيّ مسار ملفّ بالآخر
    static func normalize(server: String) -> String {
        var s = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") { s = "http://" + s }
        if let q = s.firstIndex(of: "?") { s = String(s[..<q]) }
        for tail in ["/player_api.php", "/get.php", "/xmltv.php", "/panel_api.php"] where s.lowercased().hasSuffix(tail) { s = String(s.dropLast(tail.count)) }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
    /// يستخرج (السيرفر، المستخدم، كلمة السرّ) من رابط M3U مال Xtream إذا كان بهالشكل
    static func xtream(fromM3U link: String) -> (server: String, user: String, pass: String)? {
        guard let c = URLComponents(string: link.trimmingCharacters(in: .whitespacesAndNewlines)), let host = c.host, c.path.lowercased().hasSuffix("get.php"),
              let u = c.queryItems?.first(where: { $0.name == "username" })?.value, let p = c.queryItems?.first(where: { $0.name == "password" })?.value, !u.isEmpty else { return nil }
        let port = c.port.map { ":\($0)" } ?? ""
        return ((c.scheme ?? "http") + "://" + host + port, u, p)
    }
    private static func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#&=+"))) ?? s }

    static func api(_ p: Profile, _ action: String = "", _ extra: [String: String] = [:]) -> URL? {
        var s = normalize(server: p.server) + "/player_api.php?username=" + enc(p.user) + "&password=" + enc(p.pass)
        if !action.isEmpty { s += "&action=" + action }
        for (k, v) in extra.sorted(by: { $0.key < $1.key }) { s += "&" + k + "=" + enc(v) }
        return URL(string: s)
    }
    static func liveURL(_ p: Profile, _ id: String) -> String { normalize(server: p.server) + "/live/" + enc(p.user) + "/" + enc(p.pass) + "/" + id + ".m3u8" }
    static func movieURL(_ p: Profile, _ id: String, _ ext: String) -> String { normalize(server: p.server) + "/movie/" + enc(p.user) + "/" + enc(p.pass) + "/" + id + "." + (ext.isEmpty ? "mp4" : ext) }
    static func episodeURL(_ p: Profile, _ id: String, _ ext: String) -> String { normalize(server: p.server) + "/series/" + enc(p.user) + "/" + enc(p.pass) + "/" + id + "." + (ext.isEmpty ? "mp4" : ext) }

    /// الآيفون يشغّل هالصيغ مباشرة؛ الباقي (mkv/avi…) يحتاج مشغّل خارجيّ
    static func playable(_ url: String) -> Bool {
        let path = (URL(string: url)?.path ?? url).lowercased()
        let ext = (path as NSString).pathExtension
        return ext.isEmpty || ["m3u8", "mp4", "m4v", "mov", "mp3", "aac", "m4a"].contains(ext)
    }
    static func vlcLink(_ url: String) -> URL? {
        URL(string: "vlc-x-callback://x-callback-url/stream?url=" + (url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? url))
    }

    static func cats(_ json: Any?) -> [Cat] {
        ((json as? [[String: Any]]) ?? []).compactMap { o in
            let id = str(o["category_id"]); return id.isEmpty ? nil : Cat(id: id, name: str(o["category_name"]))
        }
    }
    static func channels(_ json: Any?, _ p: Profile) -> [Channel] {
        ((json as? [[String: Any]]) ?? []).compactMap { o in
            let id = str(o["stream_id"]); guard !id.isEmpty else { return nil }
            return Channel(id: id, name: str(o["name"]), logo: str(o["stream_icon"]), cat: str(o["category_id"]), url: liveURL(p, id), epg: str(o["epg_channel_id"]))
        }
    }
    static func movies(_ json: Any?, _ p: Profile) -> [Movie] {
        ((json as? [[String: Any]]) ?? []).compactMap { o in
            let id = str(o["stream_id"]); guard !id.isEmpty else { return nil }
            let name = str(o["name"]), ext = str(o["container_extension"])
            return Movie(id: id, name: name, poster: str(o["stream_icon"]), cat: str(o["category_id"]), ext: ext.isEmpty ? "mp4" : ext,
                         rating: num(o["rating"]), year: year(name), url: movieURL(p, id, ext), added: num(o["added"]))
        }
    }
    static func shows(_ json: Any?) -> [Show] {
        ((json as? [[String: Any]]) ?? []).compactMap { o in
            let id = str(o["series_id"]); guard !id.isEmpty else { return nil }
            let name = str(o["name"])
            let y = String(str(o["releaseDate"]).prefix(4))
            return Show(id: id, name: name, poster: str(o["cover"]), cat: str(o["category_id"]), rating: num(o["rating"]), year: y.count == 4 ? y : year(name), plot: str(o["plot"]), added: num(o["last_modified"]))
        }
    }
    /// حلقات مسلسل من ردّ get_series_info
    static func episodes(_ json: Any?, _ p: Profile) -> [Episode] {
        guard let root = json as? [String: Any] else { return [] }
        var out: [Episode] = []
        func add(_ list: [[String: Any]], _ seasonHint: Int) {
            for e in list {
                let id = str(e["id"]); guard !id.isEmpty else { continue }
                let ext = str(e["container_extension"])
                let s = Int(num(e["season"])) > 0 ? Int(num(e["season"])) : seasonHint
                let info = e["info"] as? [String: Any]
                out.append(Episode(id: id, season: s, num: Int(num(e["episode_num"])), title: str(e["title"]), ext: ext.isEmpty ? "mp4" : ext,
                                   url: episodeURL(p, id, ext), mins: Int(num(info?["duration_secs"])) / 60))
            }
        }
        if let d = root["episodes"] as? [String: Any] {
            for (k, v) in d { add((v as? [[String: Any]]) ?? [], Int(k) ?? 1) }
        } else if let a = root["episodes"] as? [[[String: Any]]] {
            for (i, l) in a.enumerated() { add(l, i + 1) }
        }
        return out.sorted { $0.season != $1.season ? $0.season < $1.season : $0.num < $1.num }
    }
    /// دليل البرامج (get_short_epg): العناوين تجي base64
    static func programs(_ json: Any?) -> [Program] {
        guard let root = json as? [String: Any], let list = root["epg_listings"] as? [[String: Any]] else { return [] }
        func b64(_ s: String) -> String { Data(base64Encoded: s).flatMap { String(data: $0, encoding: .utf8) } ?? s }
        return list.compactMap { o in
            let st = num(o["start_timestamp"]), en = num(o["stop_timestamp"])
            guard st > 0, en > st else { return nil }
            return Program(id: str(o["id"]) + "-" + str(o["start_timestamp"]), title: b64(str(o["title"])), desc: b64(str(o["description"])),
                           start: Date(timeIntervalSince1970: st), end: Date(timeIntervalSince1970: en))
        }.sorted { $0.start < $1.start }
    }

    // MARK: M3U

    struct Entry { var name = ""; var logo = ""; var group = ""; var tvgId = ""; var url = "" }

    static func parseM3U(_ text: String) -> [Entry] {
        var out: [Entry] = []
        var cur: Entry? = nil
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#EXTINF") {
                var e = Entry()
                // الاسم بعد آخر فاصلة خارج علامات التنصيص
                var inQ = false, comma: String.Index? = nil
                for i in line.indices { let ch = line[i]; if ch == "\"" { inQ.toggle() } else if ch == "," && !inQ { comma = i } }
                if let c = comma { e.name = String(line[line.index(after: c)...]).trimmingCharacters(in: .whitespaces) }
                e.logo = attr(line, "tvg-logo"); e.group = attr(line, "group-title"); e.tvgId = attr(line, "tvg-id")
                if e.name.isEmpty { e.name = attr(line, "tvg-name") }
                cur = e
            } else if line.hasPrefix("#EXTGRP:") {
                if cur != nil, cur!.group.isEmpty { cur!.group = String(line.dropFirst(8)) }
            } else if line.hasPrefix("#") { continue }
            else if var e = cur {
                e.url = line; if e.name.isEmpty { e.name = line }
                out.append(e); cur = nil
            }
        }
        return out
    }
    private static func attr(_ line: String, _ key: String) -> String {
        guard let r = line.range(of: key + "=\"") else { return "" }
        let rest = line[r.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return "" }
        return String(rest[..<end])
    }

    /// نصنّف عناصر القائمة: فيديو بملفّ ⇒ فيلم (أو حلقة إذا اسمه بيه S01E02)، والباقي قنوات
    static func content(fromM3U text: String) -> Content {
        var c = Content()
        var liveCats: [String] = [], vodCats: [String] = [], serCats: [String] = []
        var showIndex: [String: Int] = [:]
        func catId(_ list: inout [String], _ g: String) -> String {
            let name = g.isEmpty ? "بلا تصنيف" : g
            if let i = list.firstIndex(of: name) { return String(i) }
            list.append(name); return String(list.count - 1)
        }
        for (i, e) in parseM3U(text).enumerated() {
            let ext = ((URL(string: e.url)?.path ?? e.url) as NSString).pathExtension.lowercased()
            let isFile = ["mp4", "mkv", "avi", "mov", "m4v", "flv", "wmv", "mpg", "webm"].contains(ext) || e.url.contains("/movie/") || e.url.contains("/series/")
            if isFile, let m = e.name.range(of: "[Ss](\\d{1,2})\\s*[Ee](\\d{1,3})", options: .regularExpression) {
                let tag = String(e.name[m])
                let nums = tag.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }.compactMap { Int($0) }
                let title = clean(String(e.name[..<m.lowerBound]).trimmingCharacters(in: CharacterSet(charactersIn: " -_.|")))
                let key = title.lowercased()
                let sid: String
                if let idx = showIndex[key] { sid = c.shows[idx].id } else {
                    sid = "s\(c.shows.count)"; showIndex[key] = c.shows.count
                    c.shows.append(Show(id: sid, name: title.isEmpty ? e.name : title, poster: e.logo, cat: catId(&serCats, e.group)))
                }
                c.episodes[sid, default: []].append(Episode(id: "e\(i)", season: nums.first ?? 1, num: nums.count > 1 ? nums[1] : 1, title: "", ext: ext.isEmpty ? "mp4" : ext, url: e.url))
            } else if isFile {
                c.movies.append(Movie(id: "m\(i)", name: e.name, poster: e.logo, cat: catId(&vodCats, e.group), ext: ext.isEmpty ? "mp4" : ext, year: year(e.name), url: e.url))
            } else {
                c.channels.append(Channel(id: "c\(i)", name: e.name, logo: e.logo, cat: catId(&liveCats, e.group), url: e.url, epg: e.tvgId))
            }
        }
        for k in c.episodes.keys { c.episodes[k]?.sort { $0.season != $1.season ? $0.season < $1.season : $0.num < $1.num } }
        c.liveCats = liveCats.enumerated().map { Cat(id: String($0), name: $1) }
        c.vodCats = vodCats.enumerated().map { Cat(id: String($0), name: $1) }
        c.seriesCats = serCats.enumerated().map { Cat(id: String($0), name: $1) }
        return c
    }

    // MARK: بحث

    static func fold(_ s: String) -> String {
        var t = s.lowercased()
        for (a, b) in [("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ة", "ه"), ("ى", "ي"), ("ـ", "")] { t = t.replacingOccurrences(of: a, with: b) }
        return t.folding(options: .diacriticInsensitive, locale: nil)
    }
    static func matches(_ name: String, _ q: String) -> Bool {
        let n = fold(name)
        return fold(q).split(separator: " ").allSatisfy { n.contains($0) }
    }
}
