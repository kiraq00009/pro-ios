import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── ترتيب عنوان السيرفر
check(Core.normalize(server: " example.com:8080/ ") == "http://example.com:8080", "normalize adds scheme, trims slash")
check(Core.normalize(server: "https://a.b/player_api.php?username=x") == "https://a.b", "normalize strips api path")
check(Core.normalize(server: "HTTP://a.b///") == "HTTP://a.b", "normalize keeps scheme")
check(Core.normalize(server: "") == "", "normalize empty")

// ── استخراج بيانات Xtream من رابط M3U
if let x = Core.xtream(fromM3U: "http://tv.host.com:8080/get.php?username=john&password=p%40ss&type=m3u_plus&output=ts") {
    check(x.server == "http://tv.host.com:8080" && x.user == "john" && x.pass == "p@ss", "xtream from m3u: \(x)")
} else { check(false, "xtream from m3u nil") }
check(Core.xtream(fromM3U: "http://host/list.m3u") == nil, "plain m3u is not xtream")

// ── الروابط
let p = Profile(name: "t", kind: .xtream, server: "host.tv:80/", user: "us er", pass: "p/w")
check(Core.liveURL(p, "55") == "http://host.tv:80/live/us%20er/p%2Fw/55.m3u8", "live url: " + Core.liveURL(p, "55"))
check(Core.movieURL(p, "9", "mkv").hasSuffix("/movie/us%20er/p%2Fw/9.mkv"), "movie url")
check(Core.episodeURL(p, "9", "").hasSuffix("/9.mp4"), "episode default ext")
check(Core.api(p, "get_live_streams", ["category_id": "3"])?.absoluteString == "http://host.tv:80/player_api.php?username=us%20er&password=p%2Fw&action=get_live_streams&category_id=3", "api url: \(Core.api(p, "get_live_streams", ["category_id": "3"])?.absoluteString ?? "nil")")

// ── الصيغ
check(Core.playable("http://x/a.m3u8") && Core.playable("http://x/a.MP4?token=1") && Core.playable("http://x/stream"), "playable formats")
check(!Core.playable("http://x/a.mkv") && !Core.playable("http://x/a.avi"), "mkv/avi not playable")
check(Core.vlcLink("http://x/a.mkv")?.scheme == "vlc-x-callback", "vlc link")

// ── تنظيف الأسماء
check(Core.clean("AR| The Batman ") == "The Batman", "clean prefix: " + Core.clean("AR| The Batman "))
check(Core.clean("EN - Viking Wolf - 2022 [Multi Sub]") == "Viking Wolf", "clean full: " + Core.clean("EN - Viking Wolf - 2022 [Multi Sub]"))
check(Core.clean("beIN Sports 1 HD") == "beIN Sports 1 HD", "clean keeps normal names")
check(Core.clean("[4K]") == "[4K]", "clean never returns empty")
check(Core.year("EN - Viking Wolf - 2022 [Multi Sub]") == "2022" && Core.year("No Year") == "", "year")

// ── قراءة ردود Xtream (أرقام تجي نصوص وبالعكس)
let liveJSON: [[String: Any]] = [["stream_id": 12, "name": "News", "stream_icon": "http://l/1.png", "category_id": "4", "epg_channel_id": "news.tv"], ["name": "no id"]]
let ch = Core.channels(liveJSON, p)
check(ch.count == 1 && ch[0].id == "12" && ch[0].cat == "4" && ch[0].url.hasSuffix("/12.m3u8"), "channels parse")
let vodJSON: [[String: Any]] = [["stream_id": "7", "name": "Film - 2019", "rating": "7.5", "container_extension": "mkv", "category_id": 2, "added": "1700000000"]]
let mv = Core.movies(vodJSON, p)
check(mv.count == 1 && mv[0].rating == 7.5 && mv[0].ext == "mkv" && mv[0].year == "2019" && mv[0].added == 1700000000, "movies parse")
check(Core.cats([["category_id": 5, "category_name": "Sports"], ["category_name": "x"]]).map { $0.id } == ["5"], "cats parse")
let serInfo: [String: Any] = ["episodes": ["2": [["id": "20", "episode_num": 1, "title": "B", "container_extension": "mp4"]], "1": [["id": "11", "episode_num": "2"], ["id": 10, "episode_num": 1, "info": ["duration_secs": 2700]]]]]
let eps = Core.episodes(serInfo, p)
check(eps.map { $0.id } == ["10", "11", "20"] && eps[0].mins == 45 && eps[2].season == 2, "episodes parse + order: \(eps.map { $0.id })")
let epg: [String: Any] = ["epg_listings": [["id": "1", "title": "2KPYrtio2KfYsQ==", "description": "", "start_timestamp": "2000", "stop_timestamp": 5600], ["id": "0", "title": "bad", "start_timestamp": 0, "stop_timestamp": 0]]]
let pr = Core.programs(epg)
check(pr.count == 1 && pr[0].title == "أخبار", "epg base64: \(pr.first?.title ?? "nil")")

// ── M3U
let m3u = """
#EXTM3U
#EXTINF:-1 tvg-id="bein1" tvg-logo="http://l/b.png" group-title="Sports, HD",beIN Sports 1
http://s/live/1.ts

#EXTINF:-1 group-title="Movies",The Film (2020)
http://s/movie/a/b/100.mp4
#EXTINF:-1 group-title="Series",My Show S01 E02
http://s/series/a/b/201.mkv
#EXTINF:-1 group-title="Series",My Show S01E01
http://s/series/a/b/200.mkv
#EXTINF:-1 group-title="Series",Other Show S02E05
http://s/series/a/b/300.mp4
#EXTINF:-1,No Group Channel
#EXTVLCOPT:http-user-agent=x
http://s/live/2.m3u8
"""
let en = Core.parseM3U(m3u)
check(en.count == 6, "m3u entries \(en.count)")
check(en[0].name == "beIN Sports 1" && en[0].group == "Sports, HD" && en[0].logo == "http://l/b.png" && en[0].tvgId == "bein1", "m3u attrs with comma in group: \(en[0])")
let c = Core.content(fromM3U: m3u)
check(c.channels.count == 2 && c.movies.count == 1 && c.shows.count == 2, "m3u classify: \(c.channels.count) \(c.movies.count) \(c.shows.count)")
check(c.channels[1].url == "http://s/live/2.m3u8", "m3u skips option lines")
let my = c.shows.first { $0.name == "My Show" }
check(my != nil && c.episodes[my!.id]?.map { $0.num } == [1, 2], "m3u episodes grouped and sorted")
check(c.liveCats.map { $0.name } == ["Sports, HD", "بلا تصنيف"], "m3u live cats: \(c.liveCats.map { $0.name })")
check(c.movies[0].year == "2020", "m3u movie year")

// ── البحث
check(Core.matches("أخبار الإمارات", "اخبار امارات") && !Core.matches("The Batman", "superman") && Core.matches("The Batman", "batman the"), "search folding")

// ── الحفظ
let data = try! JSONEncoder().encode(c)
check((try? JSONDecoder().decode(Content.self, from: data))?.channels.count == 2, "content codable")

print(failures == 0 ? "ALL PLAYER TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
