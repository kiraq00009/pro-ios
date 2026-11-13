import SwiftUI

private func header(_ t: String, _ sub: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
        Text(t).font(rnd(30, .black)).foregroundStyle(Color.white)
        Text(sub).font(rnd(13)).foregroundStyle(PL.tx3)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.top, 8)
}

// MARK: - المباشر
struct LiveTab: View {
    @EnvironmentObject var lib: Library
    @State private var cat = ""
    @State private var q = ""
    @State private var info: Channel? = nil

    private var list: [Channel] {
        var l = lib.channels
        if cat == "fav" { l = l.filter { lib.favs.contains("c:" + $0.id) } } else if !cat.isEmpty { l = l.filter { $0.cat == cat } }
        if q.count >= 2 { l = l.filter { Core.matches($0.name, q) } }
        return l
    }
    var body: some View {
        let l = list
        let names = Dictionary(uniqueKeysWithValues: lib.liveCats.map { ($0.id, $0.name) })
        VStack(spacing: 10) {
            header("مباشر", "\(lib.channels.count) قناة")
            SearchField(text: $q, hint: "دوّر على قناة…").padding(.horizontal, 16)
            CatBar(cats: lib.liveCats, sel: $cat, extra: [("fav", "⭐ المفضّلة")])
            ScrollView {
                LazyVStack(spacing: 8) {
                    if l.isEmpty { EmptyNote(icon: "tv.slash", text: cat == "fav" ? "اضغط النجمة يم أيّ قناة حتى تنضاف هنا." : "ماكو قنوات هنا.") }
                    ForEach(l) { c in
                        ChannelRow(c: c, catName: names[c.cat] ?? "", fav: lib.favs.contains("c:" + c.id)) { lib.play(channel: c, in: l) } star: { lib.toggleFav("c:" + c.id) } more: { info = c }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        .sheet(item: $info) { c in ChannelSheet(channel: c, list: l).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark).presentationDetents([.medium, .large]) }
        .onAppear { if Shot.name == "channel", let c = lib.channels.first { info = c } }
    }
}

struct ChannelRow: View {
    let c: Channel; let catName: String; let fav: Bool
    let play: () -> Void; let star: () -> Void; let more: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: play) {
                HStack(spacing: 12) {
                    Art(url: c.logo, title: c.name).frame(width: 64, height: 44).clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Core.clean(c.name)).font(rnd(15.5, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                        if !catName.isEmpty { Text(catName).font(rnd(11.5)).foregroundStyle(PL.tx3).lineLimit(1) }
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(Press())
            Button(action: more) { Image(systemName: "list.bullet.rectangle").font(.system(size: 14, weight: .bold)).foregroundStyle(PL.tx3).frame(width: 36, height: 36) }.buttonStyle(Press())
            Button(action: star) { Image(systemName: fav ? "star.fill" : "star").font(.system(size: 15, weight: .bold)).foregroundStyle(fav ? PL.gold : PL.tx3).frame(width: 36, height: 36) }.buttonStyle(Press())
        }
        .padding(.horizontal, 10).padding(.vertical, 8).card(PL.s1, 16)
    }
}

/// تفاصيل قناة: شنو يُعرض هسه واللي بعده
struct ChannelSheet: View {
    let channel: Channel; let list: [Channel]
    @EnvironmentObject var lib: Library
    @Environment(\.dismiss) private var dismiss
    @State private var progs: [Program]? = nil
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Art(url: channel.logo, title: channel.name).frame(width: 96, height: 66).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Core.clean(channel.name)).font(rnd(22, .black)).foregroundStyle(Color.white)
                        HStack(spacing: 5) { Circle().fill(PL.live).frame(width: 7, height: 7); Text("بثّ مباشر").font(rnd(12.5, .heavy)).foregroundStyle(PL.live) }
                    }
                    Spacer(minLength: 0)
                }
                Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { lib.play(channel: channel, in: list) } } label: {
                    Label("شغّل القناة", systemImage: "play.fill").font(rnd(17, .heavy)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 54)
                        .background(LinearGradient(colors: [PL.ac, PL.ac2], startPoint: .leading, endPoint: .trailing), in: Capsule())
                }.buttonStyle(Press())
                Text("دليل البرامج").font(rnd(17, .heavy)).foregroundStyle(Color.white).padding(.top, 4)
                if let p = progs {
                    if p.isEmpty { Text("المزوّد ما يوفّر دليل برامج لهالقناة.").font(rnd(13.5)).foregroundStyle(PL.tx3) }
                    ForEach(p) { x in
                        let now = x.start <= Date() && x.end > Date()
                        HStack(alignment: .top, spacing: 12) {
                            Text(x.start.formatted(date: .omitted, time: .shortened)).font(rnd(13, .heavy)).foregroundStyle(now ? PL.live : PL.tx3).frame(width: 64, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(x.title).font(rnd(15, now ? .black : .bold)).foregroundStyle(Color.white)
                                if now {
                                    GeometryReader { g in
                                        ZStack(alignment: .leading) { Capsule().fill(PL.s3); Capsule().fill(PL.live).frame(width: g.size.width * CGFloat(Date().timeIntervalSince(x.start) / x.end.timeIntervalSince(x.start))) }
                                    }.frame(height: 4).environment(\.layoutDirection, .leftToRight)
                                }
                            }
                            Spacer(minLength: 0)
                            if now { Text("هسه").font(rnd(11, .heavy)).foregroundStyle(PL.live).padding(.horizontal, 8).padding(.vertical, 2).background(PL.live.opacity(0.15), in: Capsule()) }
                        }.padding(12).card(now ? PL.s2 : PL.s1, 14)
                    }
                } else { ProgressView().tint(PL.ac).frame(maxWidth: .infinity).padding(.top, 10) }
            }.padding(20)
        }
        .background(PL.bg.ignoresSafeArea())
        .task { progs = await lib.programs(of: channel) }
    }
}

// MARK: - الأفلام
struct MoviesTab: View {
    @EnvironmentObject var lib: Library
    @State private var cat = ""
    @State private var sort = 0
    @State private var open: Movie? = nil
    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var list: [Movie] {
        var l = lib.movies
        if cat == "fav" { l = l.filter { lib.favs.contains("m:" + $0.id) } } else if !cat.isEmpty { l = l.filter { $0.cat == cat } }
        if sort == 1 { l.sort { $0.rating > $1.rating } }
        else if sort == 2 { l.sort { Core.clean($0.name) < Core.clean($1.name) } }
        else { l.sort { $0.added > $1.added } }
        return l
    }
    var body: some View {
        let l = list
        VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                header("أفلام", "\(l.count) فيلم")
                SortMenu(sort: $sort).padding(.trailing, 18)
            }
            CatBar(cats: lib.vodCats, sel: $cat, extra: [("fav", "❤️ قائمتي")])
            ScrollView {
                if l.isEmpty { EmptyNote(icon: "film", text: "ماكو أفلام هنا.") }
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(l) { m in Button { open = m } label: { PosterCell(title: m.name, url: m.poster, sub: m.year, rating: m.rating, fav: lib.favs.contains("m:" + m.id)) }.buttonStyle(Press()) }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        .sheet(item: $open) { m in MovieSheet(movie: m).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .onAppear { if Shot.name == "movie", let m = lib.movies.dropFirst(3).first { open = m } }
    }
}

struct SortMenu: View {
    @Binding var sort: Int
    var body: some View {
        Menu {
            Picker("", selection: $sort) { Text("الأحدث").tag(0); Text("الأعلى تقييمًا").tag(1); Text("أبجديّ").tag(2) }
        } label: {
            Image(systemName: "arrow.up.arrow.down").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.white).frame(width: 40, height: 40).background(PL.s2, in: Circle())
        }
    }
}

struct MovieSheet: View {
    let movie: Movie
    @EnvironmentObject var lib: Library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var plot = ""
    var body: some View {
        let key = "m:" + movie.id, r = lib.resume[key], ok = Core.playable(movie.url)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom, spacing: 14) {
                    Art(url: movie.poster, title: movie.name).frame(width: 130, height: 195).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).shadow(color: .black.opacity(0.5), radius: 14, y: 8)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Core.clean(movie.name)).font(rnd(24, .black)).foregroundStyle(Color.white).lineLimit(4)
                        HStack(spacing: 6) {
                            if !movie.year.isEmpty { Tag(movie.year) }
                            if movie.rating > 0 { Tag(String(format: "★ %.1f", movie.rating), PL.gold) }
                            Tag(movie.ext.uppercased(), ok ? PL.green : PL.live)
                        }.environment(\.layoutDirection, .leftToRight)
                    }
                    Spacer(minLength: 0)
                }
                if !ok {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("صيغة \(movie.ext.uppercased()) ما يشغّلها الآيفون مباشرة", systemImage: "exclamationmark.triangle.fill").font(rnd(14, .heavy)).foregroundStyle(PL.gold)
                        Text("تگدر تفتحه ببرنامج VLC (مجّانيّ)، أو تجرّب تشغّله هنا — بعض الأعمال تشتغل رغم الاسم.").font(rnd(12.5)).foregroundStyle(PL.tx2).lineSpacing(3)
                        if let v = Core.vlcLink(movie.url) {
                            Button { openURL(v) } label: { Label("افتح بـVLC", systemImage: "arrow.up.forward.app.fill").font(rnd(15, .heavy)).foregroundStyle(Color.black).frame(maxWidth: .infinity).frame(height: 46).background(PL.gold, in: Capsule()) }.buttonStyle(Press())
                        }
                    }.padding(14).card(PL.s1, 18, stroke: PL.gold.opacity(0.35))
                }
                HStack(spacing: 10) {
                    Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { lib.play(movie: movie) } } label: {
                        Label(r != nil ? "أكمل من \(clock(r!.t))" : (ok ? "شغّل" : "جرّب هنا"), systemImage: "play.fill").font(rnd(17, .heavy)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 54)
                            .background(LinearGradient(colors: [PL.ac, PL.ac2], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    }.buttonStyle(Press())
                    Button { lib.toggleFav(key) } label: {
                        Image(systemName: lib.favs.contains(key) ? "heart.fill" : "heart").font(.system(size: 19, weight: .bold)).foregroundStyle(lib.favs.contains(key) ? PL.live : Color.white).frame(width: 54, height: 54).background(PL.s2, in: Circle())
                    }.buttonStyle(Press())
                }
                if r != nil { Button { lib.forget(key) } label: { Text("ابدي من الأوّل").font(rnd(13.5, .bold)).foregroundStyle(PL.tx3) }.buttonStyle(.plain) }
                if !plot.isEmpty { Text(plot).font(rnd(14.5)).foregroundStyle(PL.tx2).lineSpacing(5) }
            }.padding(20)
        }
        .background(PL.bg.ignoresSafeArea())
        .task { plot = await lib.plot(of: movie) }
    }
}

func clock(_ s: Double) -> String { let t = Int(s); return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t % 3600 / 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60) }

struct Tag: View {
    let text: String; var tint: Color
    init(_ t: String, _ c: Color = PL.tx2) { text = t; tint = c }
    var body: some View { Text(text).font(rnd(12, .heavy)).foregroundStyle(tint).padding(.horizontal, 9).padding(.vertical, 3).background(tint.opacity(0.15), in: Capsule()) }
}

struct EmptyNote: View {
    let icon: String; let text: String
    var body: some View {
        VStack(spacing: 10) { Image(systemName: icon).font(.system(size: 38)).foregroundStyle(PL.tx3); Text(text).font(rnd(14)).foregroundStyle(PL.tx3).multilineTextAlignment(.center) }
            .frame(maxWidth: .infinity).padding(.top, 60).padding(.horizontal, 30)
    }
}

struct SearchField: View {
    @Binding var text: String; let hint: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .bold)).foregroundStyle(PL.tx3)
            TextField("", text: $text, prompt: Text(hint).foregroundColor(PL.tx3)).font(rnd(15, .bold)).foregroundStyle(Color.white).autocorrectionDisabled().submitLabel(.search)
            if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(PL.tx3) }.buttonStyle(.plain) }
        }.padding(.horizontal, 14).frame(height: 44).background(PL.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - المسلسلات
struct SeriesTab: View {
    @EnvironmentObject var lib: Library
    @State private var cat = ""
    @State private var sort = 0
    @State private var open: Show? = nil
    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private var list: [Show] {
        var l = lib.shows
        if cat == "fav" { l = l.filter { lib.favs.contains("s:" + $0.id) } } else if !cat.isEmpty { l = l.filter { $0.cat == cat } }
        if sort == 1 { l.sort { $0.rating > $1.rating } }
        else if sort == 2 { l.sort { Core.clean($0.name) < Core.clean($1.name) } }
        else { l.sort { $0.added > $1.added } }
        return l
    }
    var body: some View {
        let l = list
        VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                header("مسلسلات", "\(l.count) مسلسل")
                SortMenu(sort: $sort).padding(.trailing, 18)
            }
            CatBar(cats: lib.seriesCats, sel: $cat, extra: [("fav", "❤️ قائمتي")])
            ScrollView {
                if l.isEmpty { EmptyNote(icon: "tv", text: "ماكو مسلسلات هنا.") }
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(l) { s in Button { open = s } label: { PosterCell(title: s.name, url: s.poster, sub: s.year, rating: s.rating, fav: lib.favs.contains("s:" + s.id)) }.buttonStyle(Press()) }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        .sheet(item: $open) { s in ShowSheet(show: s).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .onAppear { if Shot.name == "show", let s = lib.shows.first { open = s } }
    }
}

struct ShowSheet: View {
    let show: Show
    @EnvironmentObject var lib: Library
    @Environment(\.dismiss) private var dismiss
    @State private var eps: [Episode]? = nil
    @State private var season = 0
    var body: some View {
        let key = "s:" + show.id
        let seasons = Array(Set((eps ?? []).map { $0.season })).sorted()
        let cur = seasons.contains(season) ? season : (seasons.first ?? 1)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom, spacing: 14) {
                    Art(url: show.poster, title: show.name).frame(width: 120, height: 180).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).shadow(color: .black.opacity(0.5), radius: 14, y: 8)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Core.clean(show.name)).font(rnd(24, .black)).foregroundStyle(Color.white).lineLimit(3)
                        HStack(spacing: 6) {
                            if !show.year.isEmpty { Tag(show.year) }
                            if show.rating > 0 { Tag(String(format: "★ %.1f", show.rating), PL.gold) }
                            if !seasons.isEmpty { Tag("\(seasons.count) موسم", PL.ac) }
                        }
                        Button { lib.toggleFav(key) } label: {
                            Label(lib.favs.contains(key) ? "بقائمتي" : "ضيف لقائمتي", systemImage: lib.favs.contains(key) ? "heart.fill" : "heart").font(rnd(13.5, .heavy))
                                .foregroundStyle(lib.favs.contains(key) ? PL.live : Color.white).padding(.horizontal, 14).frame(height: 38).background(PL.s2, in: Capsule())
                        }.buttonStyle(Press())
                    }
                    Spacer(minLength: 0)
                }
                if !show.plot.isEmpty { Text(show.plot).font(rnd(14)).foregroundStyle(PL.tx2).lineSpacing(4).lineLimit(5) }
                if eps == nil { ProgressView().tint(PL.ac).frame(maxWidth: .infinity).padding(.top, 20) }
                else if seasons.isEmpty { EmptyNote(icon: "tv.slash", text: "ما لگينا حلقات لهالمسلسل.") }
                else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(seasons, id: \.self) { s in
                                Button { season = s } label: {
                                    Text("الموسم \(s)").font(rnd(13.5, .heavy)).foregroundStyle(cur == s ? Color.white : PL.tx2).padding(.horizontal, 15).frame(height: 36).background(cur == s ? PL.ac : PL.s2, in: Capsule())
                                }.buttonStyle(Press())
                            }
                        }
                    }
                    ForEach((eps ?? []).filter { $0.season == cur }) { e in episode(e) }
                }
            }.padding(20)
        }
        .background(PL.bg.ignoresSafeArea())
        .task { eps = await lib.episodes(of: show) }
    }
    private func episode(_ e: Episode) -> some View {
        let r = lib.resume["e:" + show.id + ":" + e.id]
        return Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { lib.play(episode: e, of: show) } } label: {
            HStack(spacing: 12) {
                Text("\(e.num)").font(rnd(17, .black)).foregroundStyle(PL.ac).frame(width: 44, height: 44).background(PL.ac.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.title.isEmpty ? "الحلقة \(e.num)" : e.title).font(rnd(15, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                    HStack(spacing: 6) {
                        if e.mins > 0 { Text("\(e.mins) دقيقة").font(rnd(11.5)).foregroundStyle(PL.tx3) }
                        if !Core.playable(e.url) { Text(e.ext.uppercased()).font(rnd(10, .heavy)).foregroundStyle(PL.gold) }
                    }
                    if let r, r.d > 0 {
                        GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(PL.s3); Capsule().fill(PL.ac).frame(width: g.size.width * min(1, r.t / r.d)) } }.frame(height: 3).environment(\.layoutDirection, .leftToRight)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill").font(.system(size: 28)).foregroundStyle(PL.ac)
            }.padding(10).card(PL.s1, 16)
        }.buttonStyle(Press())
    }
}

// MARK: - البحث الشامل
struct SearchTab: View {
    @EnvironmentObject var lib: Library
    @State private var q = Shot.name == "search" ? "ال" : ""
    @State private var movie: Movie? = nil
    @State private var show: Show? = nil
    var body: some View {
        let on = q.trimmingCharacters(in: .whitespaces).count >= 2
        let ch = on ? Array(lib.channels.filter { Core.matches($0.name, q) }.prefix(12)) : []
        let mv = on ? Array(lib.movies.filter { Core.matches($0.name, q) }.prefix(18)) : []
        let sh = on ? Array(lib.shows.filter { Core.matches($0.name, q) }.prefix(18)) : []
        VStack(spacing: 10) {
            header("بحث", "بكلّ القنوات والأفلام والمسلسلات")
            SearchField(text: $q, hint: "اسم قناة، فيلم، أو مسلسل…").padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !on { EmptyNote(icon: "magnifyingglass", text: "اكتب حرفين أو أكثر.") }
                    else if ch.isEmpty && mv.isEmpty && sh.isEmpty { EmptyNote(icon: "questionmark.circle", text: "ما لگينا شي بهالاسم.") }
                    if !ch.isEmpty {
                        title("قنوات")
                        ForEach(ch) { c in ChannelRow(c: c, catName: "", fav: lib.favs.contains("c:" + c.id)) { lib.play(channel: c, in: ch) } star: { lib.toggleFav("c:" + c.id) } more: {} }
                    }
                    if !mv.isEmpty {
                        title("أفلام")
                        strip(mv.map { ($0.id, $0.name, $0.poster, $0.year, $0.rating) }) { id in movie = mv.first { $0.id == id } }
                    }
                    if !sh.isEmpty {
                        title("مسلسلات")
                        strip(sh.map { ($0.id, $0.name, $0.poster, $0.year, $0.rating) }) { id in show = sh.first { $0.id == id } }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }.scrollDismissesKeyboard(.immediately)
        }
        .sheet(item: $movie) { m in MovieSheet(movie: m).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .sheet(item: $show) { s in ShowSheet(show: s).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
    }
    private func title(_ t: String) -> some View { Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white) }
    private func strip(_ items: [(String, String, String, String, Double)], _ tap: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.0) { it in
                    Button { tap(it.0) } label: { PosterCell(title: it.1, url: it.2, sub: it.3, rating: it.4, width: 110) }.buttonStyle(Press())
                }
            }
        }
    }
}
