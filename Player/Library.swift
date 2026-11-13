import SwiftUI

enum PL {
    static let bg = Color(red: 0.03, green: 0.03, blue: 0.07)
    static let s1 = Color(red: 0.07, green: 0.08, blue: 0.14)
    static let s2 = Color(red: 0.11, green: 0.13, blue: 0.21)
    static let s3 = Color(red: 0.17, green: 0.19, blue: 0.29)
    static let ac = Color(red: 0.45, green: 0.55, blue: 1)          // أزرق بنفسجيّ
    static let ac2 = Color(red: 0.75, green: 0.4, blue: 1)
    static let live = Color(red: 1, green: 0.28, blue: 0.36)
    static let gold = Color(red: 1, green: 0.8, blue: 0.3)
    static let green = Color(red: 0.3, green: 0.88, blue: 0.55)
    static let tx2 = Color(white: 1, opacity: 0.72), tx3 = Color(white: 1, opacity: 0.45)
    static let demoStream = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
}

struct AccountInfo { var status = ""; var exp: Date? = nil; var max = 0; var active = 0; var trial = false }

struct Resume: Codable, Hashable { var t: Double; var d: Double; var at: Double; var name: String; var poster: String; var kind: String; var id: String; var url: String }

/// ما يتشغّل: رابط + عنوان + (للقنوات) قائمة للتنقّل
struct PlayItem: Identifiable {
    let id = UUID()
    var title: String; var sub: String = ""; var url: String
    var live = false
    var key: String = ""                       // مفتاح حفظ موضع المشاهدة
    var poster: String = ""
    var channels: [Channel] = []; var index = 0
    var start: Double = 0
}

@MainActor
final class Library: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var current: Profile? = nil
    @Published var content = Content()
    @Published var loading = false
    @Published var progress = ""
    @Published var error = ""
    @Published var favs: Set<String> = []                  // "c:ID" · "m:ID" · "s:ID"
    @Published var recents: [String] = []                  // آخر القنوات
    @Published var resume: [String: Resume] = [:]
    @Published var account = AccountInfo()
    @Published var hideAdult = true
    @Published var playing: PlayItem? = nil

    private let ud = UserDefaults.standard
    private var dir: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0] }
    private func cacheURL(_ p: Profile) -> URL { dir.appendingPathComponent("lib-" + p.id.uuidString + ".json") }

    init() {
        hideAdult = ud.object(forKey: "pl_hide_adult") as? Bool ?? true
        if Shot.name == "welcome" { return }
        if Shot.on { let d = Profile(name: "تجريبيّ", kind: .demo); profiles = [d]; current = d; content = Demo.content(); seedShot(); return }
        if let d = ud.data(forKey: "pl_profiles"), let v = try? JSONDecoder().decode([Profile].self, from: d) { profiles = v }
        if let id = ud.string(forKey: "pl_current"), let p = profiles.first(where: { $0.id.uuidString == id }) { select(p, reload: false) }
        else if let p = profiles.first { select(p, reload: false) }
    }

    // MARK: الملفّات الشخصيّة
    private func saveProfiles() { if let d = try? JSONEncoder().encode(profiles) { ud.set(d, forKey: "pl_profiles") } }
    func add(_ p: Profile) { profiles.append(p); saveProfiles(); select(p, reload: true) }
    func update(_ p: Profile) { if let i = profiles.firstIndex(where: { $0.id == p.id }) { profiles[i] = p; saveProfiles(); if current?.id == p.id { select(p, reload: true) } } }
    func remove(_ p: Profile) {
        profiles.removeAll { $0.id == p.id }; saveProfiles()
        try? FileManager.default.removeItem(at: cacheURL(p))
        if current?.id == p.id { current = nil; content = Content(); if let n = profiles.first { select(n, reload: false) } }
    }
    func select(_ p: Profile, reload: Bool) {
        current = p; ud.set(p.id.uuidString, forKey: "pl_current"); error = ""
        loadState(p)
        if p.kind == .demo { content = Demo.content(); return }
        if !reload, let d = try? Data(contentsOf: cacheURL(p)), let c = try? JSONDecoder().decode(Content.self, from: d), !c.isEmpty {
            content = c
            if Date().timeIntervalSince1970 - c.at > 12 * 3600 { Task { await refresh() } }       // أقدم من ١٢ ساعة ⇒ نحدّث بالخلفيّة
            else { Task { await loadAccount() } }
        } else { content = Content(); Task { await refresh() } }
    }

    // MARK: المفضّلة والسجلّ (لكلّ ملفّ شخصيّ)
    private func key(_ k: String) -> String { "pl_" + k + "_" + (current?.id.uuidString ?? "") }
    private func loadState(_ p: Profile) {
        favs = Set(ud.stringArray(forKey: key("favs")) ?? [])
        recents = ud.stringArray(forKey: key("recents")) ?? []
        if let d = ud.data(forKey: key("resume")), let v = try? JSONDecoder().decode([String: Resume].self, from: d) { resume = v } else { resume = [:] }
    }
    func toggleFav(_ k: String) {
        if favs.contains(k) { favs.remove(k) } else { favs.insert(k) }
        ud.set(Array(favs), forKey: key("favs")); Haptic.tap()
    }
    func touch(channel id: String) {
        recents.removeAll { $0 == id }; recents.insert(id, at: 0); recents = Array(recents.prefix(20))
        ud.set(recents, forKey: key("recents"))
    }
    func savePos(_ r: Resume, key k: String) {
        // خلص تقريبًا ⇒ نشيله من «أكمل المشاهدة»
        if r.d > 0, r.t / r.d > 0.93 { resume.removeValue(forKey: k) } else if r.t > 20 { resume[k] = r }
        if resume.count > 60, let old = resume.min(by: { $0.value.at < $1.value.at })?.key { resume.removeValue(forKey: old) }
        if let d = try? JSONEncoder().encode(resume) { ud.set(d, forKey: key("resume")) }
    }
    func forget(_ k: String) { resume.removeValue(forKey: k); if let d = try? JSONEncoder().encode(resume) { ud.set(d, forKey: key("resume")) } }
    var continueList: [(String, Resume)] { resume.sorted { $0.value.at > $1.value.at }.map { ($0.key, $0.value) } }

    // MARK: فلترة أقسام البالغين
    private static let adultWords = ["adult", "xxx", "+18", "18+", "للكبار", "porn"]
    func visible(_ c: Cat) -> Bool { !hideAdult || !Library.adultWords.contains { c.name.lowercased().contains($0) } }
    func setHideAdult(_ v: Bool) { hideAdult = v; ud.set(v, forKey: "pl_hide_adult") }
    var liveCats: [Cat] { content.liveCats.filter(visible) }
    var vodCats: [Cat] { content.vodCats.filter(visible) }
    var seriesCats: [Cat] { content.seriesCats.filter(visible) }
    private func hidden(_ cats: [Cat]) -> Set<String> { Set(cats.filter { !visible($0) }.map { $0.id }) }
    var channels: [Channel] { let h = hidden(content.liveCats); return h.isEmpty ? content.channels : content.channels.filter { !h.contains($0.cat) } }
    var movies: [Movie] { let h = hidden(content.vodCats); return h.isEmpty ? content.movies : content.movies.filter { !h.contains($0.cat) } }
    var shows: [Show] { let h = hidden(content.seriesCats); return h.isEmpty ? content.shows : content.shows.filter { !h.contains($0.cat) } }

    // MARK: التحميل من المزوّد
    private func json(_ url: URL?, timeout: Double = 60) async throws -> Any {
        guard let url else { throw URLError(.badURL) }
        var rq = URLRequest(url: url); rq.timeoutInterval = timeout
        rq.setValue(current?.ua ?? "VLC/3.0.20 LibVLC/3.0.20", forHTTPHeaderField: "User-Agent")
        let (d, r) = try await URLSession.shared.data(for: rq)
        guard let h = r as? HTTPURLResponse, (200..<300).contains(h.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONSerialization.jsonObject(with: d)
    }

    func refresh() async {
        guard let p = current, p.kind != .demo, !loading else { return }
        loading = true; error = ""; defer { loading = false; progress = "" }
        do {
            var c = Content()
            if p.kind == .m3u {
                progress = "دا ننزّل القائمة…"
                guard let u = URL(string: p.m3u.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw URLError(.badURL) }
                var rq = URLRequest(url: u); rq.timeoutInterval = 90; rq.setValue(p.ua, forHTTPHeaderField: "User-Agent")
                let (d, _) = try await URLSession.shared.data(for: rq)
                let text = String(data: d, encoding: .utf8) ?? String(decoding: d, as: UTF8.self)
                progress = "دا نرتّب القنوات…"
                c = await Task.detached { Core.content(fromM3U: text) }.value
                if c.isEmpty { throw URLError(.cannotParseResponse) }
            } else {
                progress = "دا نتحقّق من الحساب…"
                let info = try await json(Core.api(p), timeout: 25)
                guard let ui = (info as? [String: Any])?["user_info"] as? [String: Any], Core.num(ui["auth"]) == 1 || Core.str(ui["status"]).lowercased() == "active" else {
                    error = "اسم المستخدم أو كلمة السرّ غلط، أو الاشتراك منتهي."; return
                }
                applyAccount(ui)
                progress = "القنوات المباشرة…"
                async let lc = json(Core.api(p, "get_live_categories"))
                async let ls = json(Core.api(p, "get_live_streams"), timeout: 120)
                c.liveCats = Core.cats(try await lc); c.channels = Core.channels(try await ls, p)
                progress = "الأفلام…"
                async let vc = json(Core.api(p, "get_vod_categories"))
                async let vs = json(Core.api(p, "get_vod_streams"), timeout: 180)
                c.vodCats = Core.cats(try? await vc); c.movies = Core.movies(try? await vs, p)
                progress = "المسلسلات…"
                async let sc = json(Core.api(p, "get_series_categories"))
                async let ss = json(Core.api(p, "get_series"), timeout: 180)
                c.seriesCats = Core.cats(try? await sc); c.shows = Core.shows(try? await ss)
            }
            c.at = Date().timeIntervalSince1970
            guard current?.id == p.id else { return }
            content = c
            let url = cacheURL(p)
            Task.detached { if let d = try? JSONEncoder().encode(c) { try? d.write(to: url, options: .atomic) } }
        } catch {
            if content.isEmpty { self.error = "ما وصلنا للسيرفر. تأكّد من العنوان والنت وجرّب مرّة ثانية." }
        }
    }

    private func applyAccount(_ ui: [String: Any]) {
        let exp = Core.num(ui["exp_date"])
        account = AccountInfo(status: Core.str(ui["status"]), exp: exp > 0 ? Date(timeIntervalSince1970: exp) : nil,
                              max: Int(Core.num(ui["max_connections"])), active: Int(Core.num(ui["active_cons"])), trial: Core.str(ui["is_trial"]) == "1")
    }
    func loadAccount() async {
        guard let p = current, p.kind == .xtream else { account = AccountInfo(); return }
        if let info = try? await json(Core.api(p), timeout: 20), let ui = (info as? [String: Any])?["user_info"] as? [String: Any] { applyAccount(ui) }
    }

    func episodes(of show: Show) async -> [Episode] {
        guard let p = current else { return [] }
        if let e = content.episodes[show.id] { return e }
        if p.kind == .demo { return Demo.episodes(show) }
        guard p.kind == .xtream, let j = try? await json(Core.api(p, "get_series_info", ["series_id": show.id]), timeout: 40) else { return [] }
        return Core.episodes(j, p)
    }
    func plot(of movie: Movie) async -> String {
        guard let p = current else { return "" }
        if p.kind == .demo { return Demo.plot }
        guard p.kind == .xtream, let j = try? await json(Core.api(p, "get_vod_info", ["vod_id": movie.id]), timeout: 25),
              let info = (j as? [String: Any])?["info"] as? [String: Any] else { return "" }
        let s = Core.str(info["plot"]); return s.isEmpty ? Core.str(info["description"]) : s
    }
    func programs(of ch: Channel) async -> [Program] {
        guard let p = current else { return [] }
        if p.kind == .demo { return Demo.programs(ch) }
        guard p.kind == .xtream, let j = try? await json(Core.api(p, "get_short_epg", ["stream_id": ch.id, "limit": "8"]), timeout: 20) else { return [] }
        return Core.programs(j)
    }

    // MARK: تشغيل
    func play(channel: Channel, in list: [Channel]) {
        touch(channel: channel.id)
        playing = PlayItem(title: Core.clean(channel.name), url: channel.url, live: true, poster: channel.logo, channels: list, index: list.firstIndex(of: channel) ?? 0)
    }
    func play(movie: Movie) {
        let k = "m:" + movie.id
        playing = PlayItem(title: Core.clean(movie.name), sub: movie.year, url: movie.url, key: k, poster: movie.poster, start: resume[k]?.t ?? 0)
    }
    func play(episode e: Episode, of show: Show) {
        let k = "e:" + show.id + ":" + e.id
        playing = PlayItem(title: Core.clean(show.name), sub: "م\(e.season) ح\(e.num)", url: e.url, key: k, poster: show.poster, start: resume[k]?.t ?? 0)
    }
    func play(resume k: String, _ r: Resume) { playing = PlayItem(title: r.name, url: r.url, key: k, poster: r.poster, start: r.t) }

    private func seedShot() {
        favs = ["c:c3", "c:c9", "m:m4", "s:s2"]; recents = ["c1", "c7", "c12", "c20"]
        let m = content.movies
        resume = ["m:" + m[2].id: Resume(t: 2400, d: 6600, at: 5, name: Core.clean(m[2].name), poster: "", kind: "m", id: m[2].id, url: m[2].url),
                  "m:" + m[7].id: Resume(t: 900, d: 5400, at: 4, name: Core.clean(m[7].name), poster: "", kind: "m", id: m[7].id, url: m[7].url)]
        account = AccountInfo(status: "Active", exp: Date().addingTimeInterval(86400 * 212), max: 2, active: 1, trial: false)
    }
}

/// بيانات تجريبيّة — للتجربة بلا اشتراك، ولصور الشاشات
enum Demo {
    static let plot = "قصّة تجريبيّة قصيرة تبيّن شكل صفحة العمل. لمّا تربط اشتراكك تطلع هنا القصّة الحقيقيّة من المزوّد."
    static func content() -> Content {
        var c = Content()
        let lc = ["الرياضة", "الأخبار", "أفلام", "ترفيه", "أطفال", "وثائقيّ"]
        c.liveCats = lc.enumerated().map { Cat(id: String($0), name: $1) }
        let names: [[String]] = [["سبورت 1 HD", "سبورت 2 HD", "سبورت 3 HD", "سبورت 4K", "كورة لايف", "أرينا"], ["أخبار العالم", "الأخبار 24", "اقتصاد", "الطقس"],
                                 ["سينما 1", "سينما 2", "أكشن", "كلاسيك", "كوميدي"], ["منوّعات", "دراما", "مسلسلات", "طبخ"], ["كرتون", "صغار", "مغامرات"], ["الطبيعة", "تاريخ", "علوم", "سفر"]]
        var n = 0
        for (ci, list) in names.enumerated() { for nm in list { n += 1; c.channels.append(Channel(id: "c\(n)", name: nm, cat: String(ci), url: PL.demoStream)) } }
        let vc = ["أحدث الأفلام", "أكشن", "كوميدي", "دراما", "خيال علميّ"]
        c.vodCats = vc.enumerated().map { Cat(id: String($0), name: $1) }
        let films = ["المدينة الأخيرة", "ظلّ القمر", "سباق الريح", "حارس البوّابة", "ليلة طويلة", "البحر الأزرق", "رحلة العودة", "النجم البعيد", "ضحكة الصباح", "الطريق السريع",
                     "قلب الأسد", "مدينة الضباب", "السرّ القديم", "حلم الصيف", "آخر قطار", "الجزيرة", "صوت المطر", "نهاية اللعبة", "أرض الذهب", "العاصفة"]
        for (i, f) in films.enumerated() {
            c.movies.append(Movie(id: "m\(i)", name: f, cat: String(i % vc.count), ext: "mp4", rating: 6 + Double((i * 37) % 30) / 10, year: String(2018 + i % 8), url: PL.demoStream, added: Double(1000 - i)))
        }
        let sc = ["مسلسلات جديدة", "دراما", "جريمة", "كوميدي"]
        c.seriesCats = sc.enumerated().map { Cat(id: String($0), name: $1) }
        let shows = ["بيت الجبل", "المحقّق", "أيّام الجامعة", "الحيّ القديم", "ما وراء البحر", "العائلة", "المختبر", "طريق الحرير", "الفريق", "ليالي المدينة", "الوريث", "القضيّة"]
        for (i, s) in shows.enumerated() {
            c.shows.append(Show(id: "s\(i)", name: s, cat: String(i % sc.count), rating: 6.5 + Double((i * 53) % 28) / 10, year: String(2019 + i % 7), plot: plot, added: Double(1000 - i)))
        }
        c.at = Date().timeIntervalSince1970
        return c
    }
    static func episodes(_ s: Show) -> [Episode] {
        var out: [Episode] = []
        for season in 1...3 { for e in 1...8 { out.append(Episode(id: "\(s.id)-\(season)-\(e)", season: season, num: e, title: "الحلقة \(e)", ext: "mp4", url: PL.demoStream, mins: 42 + (e * 3) % 9)) } }
        return out
    }
    static func programs(_ ch: Channel) -> [Program] {
        let titles = ["نشرة المساء", "برنامج خاصّ", "الاستوديو التحليليّ", "فيلم السهرة", "جولة حول العالم", "آخر الليل"]
        let base = Date().addingTimeInterval(-1500)
        return titles.enumerated().map { i, t in Program(id: "\(ch.id)-\(i)", title: t, desc: "", start: base.addingTimeInterval(Double(i) * 3600), end: base.addingTimeInterval(Double(i + 1) * 3600)) }
    }
}
