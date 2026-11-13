import SwiftUI
import AVFoundation

@main
struct PlayerApp: App {
    @StateObject private var lib = Library()
    init() { try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback) }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(lib)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(PL.ac)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            PL.bg
            RadialGradient(colors: [PL.ac.opacity(0.22), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [PL.ac2.opacity(0.12), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }
}

/// صورة العمل — وإذا ما أكو صورة (أو ما حمّلت) بلاطة ملوّنة باسمه
struct Art: View {
    let url: String; let title: String; var icon: String = ""
    private var tint: (Color, Color) {
        var h: UInt32 = 5381
        for b in title.utf8 { h = h &* 33 &+ UInt32(b) }
        let a = Double(h % 360) / 360, b = Double((h / 7) % 360) / 360
        return (Color(hue: a, saturation: 0.62, brightness: 0.62), Color(hue: b, saturation: 0.7, brightness: 0.28))
    }
    var body: some View {
        let t = tint
        ZStack {
            LinearGradient(colors: [t.0, t.1], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                if !icon.isEmpty { Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(Color.white.opacity(0.85)) }
                Text(Core.clean(title)).font(rnd(13, .heavy)).foregroundStyle(Color.white).multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.6).padding(.horizontal, 6)
            }
            if let u = URL(string: url), !url.isEmpty {
                AsyncImage(url: u) { ph in
                    if case .success(let img) = ph { img.resizable().aspectRatio(contentMode: .fill) } else { Color.clear }
                }
            }
        }
        .clipped()
    }
}

struct RootView: View {
    @EnvironmentObject var lib: Library
    @State private var tab = 0
    @State private var settings = false
    @State private var adding = false

    var body: some View {
        ZStack {
            Backdrop()
            if lib.current == nil { Welcome(adding: $adding) }
            else {
                VStack(spacing: 0) {
                    Group {
                        switch tab {
                        case 0: HomeTab(tab: $tab, settings: $settings)
                        case 1: LiveTab()
                        case 2: MoviesTab()
                        case 3: SeriesTab()
                        default: SearchTab()
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    TabBar(tab: $tab)
                }
            }
        }
        .sheet(isPresented: $settings) { SettingsView().environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .sheet(isPresented: $adding) { ProfileEditor(profile: nil).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .fullScreenCover(item: $lib.playing) { item in PlayerScreen(item: item).environmentObject(lib) }
        .onAppear {
            switch Shot.name {
            case "live", "channel": tab = 1
            case "movies", "movie": tab = 2
            case "series", "show": tab = 3
            case "search": tab = 4
            case "settings": settings = true
            case "add": adding = true
            default: break
            }
        }
    }
}

struct TabBar: View {
    @Binding var tab: Int
    private let items: [(String, String)] = [("الرئيسيّة", "house.fill"), ("مباشر", "dot.radiowaves.left.and.right"), ("أفلام", "film.fill"), ("مسلسلات", "tv.fill"), ("بحث", "magnifyingglass")]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { i in
                let on = tab == i
                Button { Haptic.tap(); withAnimation(.easeOut(duration: 0.15)) { tab = i } } label: {
                    VStack(spacing: 3) {
                        Image(systemName: items[i].1).font(.system(size: 18, weight: .semibold))
                        Text(items[i].0).font(rnd(10.5, .heavy)).lineLimit(1)
                    }
                    .foregroundStyle(on ? Color.white : PL.tx3).frame(maxWidth: .infinity).frame(height: 52)
                    .background { if on { RoundedRectangle(cornerRadius: 15, style: .continuous).fill(LinearGradient(colors: [PL.ac, PL.ac2], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.85)) } }
                    .contentShape(Rectangle())
                }.buttonStyle(Press())
            }
        }
        .padding(6).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(white: 1, opacity: 0.08)))
        .padding(.horizontal, 12).padding(.bottom, 4).padding(.top, 6)
    }
}

// MARK: - أوّل فتحة
struct Welcome: View {
    @EnvironmentObject var lib: Library
    @Binding var adding: Bool
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "play.tv.fill").font(.system(size: 64)).foregroundStyle(LinearGradient(colors: [PL.ac, PL.ac2], startPoint: .top, endPoint: .bottom))
            Text("بلاير").font(rnd(46, .black)).foregroundStyle(Color.white)
            Text("مشغّل قنوات وأفلام ومسلسلات.\nاربط اشتراكك (Xtream أو قائمة M3U) وكلّ شي يترتّب لحاله.").font(rnd(15)).foregroundStyle(PL.tx2).multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 30)
            Spacer()
            VStack(spacing: 10) {
                Button { adding = true } label: {
                    Label("اربط اشتراكي", systemImage: "link").font(rnd(17, .heavy)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 56)
                        .background(LinearGradient(colors: [PL.ac, PL.ac2], startPoint: .leading, endPoint: .trailing), in: Capsule())
                }.buttonStyle(Press())
                Button { lib.add(Profile(name: "تجريبيّ", kind: .demo)) } label: {
                    Text("جرّب بلا اشتراك").font(rnd(15, .heavy)).foregroundStyle(PL.tx2).frame(maxWidth: .infinity).frame(height: 50).background(PL.s2, in: Capsule())
                }.buttonStyle(Press())
            }.padding(.horizontal, 24)
            Text("التطبيق مشغّل فقط وما بيه أيّ محتوى. إنت تضيف اشتراكك الخاصّ.").font(rnd(11.5)).foregroundStyle(PL.tx3).multilineTextAlignment(.center).padding(.horizontal, 30).padding(.bottom, 16)
        }
    }
}

// MARK: - الرئيسيّة
struct HomeTab: View {
    @EnvironmentObject var lib: Library
    @Binding var tab: Int
    @Binding var settings: Bool
    @State private var movie: Movie? = nil
    @State private var show: Show? = nil

    var body: some View {
        let chans = lib.channels
        let recent = lib.recents.compactMap { id in chans.first { $0.id == id } }
        let favCh = chans.filter { lib.favs.contains("c:" + $0.id) }
        let newMovies = Array(lib.movies.sorted { $0.added > $1.added }.prefix(14))
        let newShows = Array(lib.shows.sorted { $0.added > $1.added }.prefix(14))
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("بلاير").font(rnd(32, .black)).foregroundStyle(Color.white)
                        Text(lib.current?.name ?? "").font(rnd(13, .bold)).foregroundStyle(PL.tx3)
                    }
                    Spacer()
                    if lib.loading { ProgressView().tint(PL.ac) }
                    Button { settings = true } label: { Image(systemName: "gearshape.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.white).frame(width: 44, height: 44).background(PL.s2, in: Circle()) }.buttonStyle(Press())
                }.padding(.horizontal, 18)

                if lib.loading && lib.content.isEmpty { loadingCard }
                else if !lib.error.isEmpty && lib.content.isEmpty { errorCard }
                else {
                    counts
                    if !lib.continueList.isEmpty { continueRow }
                    if !recent.isEmpty { row("آخر القنوات") { ForEach(recent) { c in chip(c, chans) } } }
                    if !favCh.isEmpty { row("قنواتي المفضّلة ⭐") { ForEach(favCh) { c in chip(c, chans) } } }
                    if !newMovies.isEmpty { row("أحدث الأفلام", more: { tab = 2 }) { ForEach(newMovies) { m in Button { movie = m } label: { PosterCell(title: m.name, url: m.poster, sub: m.year, rating: m.rating, width: 116) }.buttonStyle(Press()) } } }
                    if !newShows.isEmpty { row("أحدث المسلسلات", more: { tab = 3 }) { ForEach(newShows) { s in Button { show = s } label: { PosterCell(title: s.name, url: s.poster, sub: s.year, rating: s.rating, width: 116) }.buttonStyle(Press()) } } }
                }
            }.padding(.top, 8).padding(.bottom, 16)
        }
        .sheet(item: $movie) { m in MovieSheet(movie: m).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .sheet(item: $show) { s in ShowSheet(show: s).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
    }

    private var counts: some View {
        HStack(spacing: 10) {
            count("\(lib.channels.count)", "قناة", "dot.radiowaves.left.and.right", PL.live) { tab = 1 }
            count("\(lib.movies.count)", "فيلم", "film.fill", PL.ac) { tab = 2 }
            count("\(lib.shows.count)", "مسلسل", "tv.fill", PL.ac2) { tab = 3 }
        }.padding(.horizontal, 18)
    }
    private func count(_ v: String, _ l: String, _ icon: String, _ c: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(c)
                Text(v).font(rnd(24, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.5)
                Text(l).font(rnd(12)).foregroundStyle(PL.tx3)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).card(PL.s1, 18, stroke: c.opacity(0.25))
        }.buttonStyle(Press())
    }
    private func row<C: View>(_ title: String, more: (() -> Void)? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(rnd(18, .heavy)).foregroundStyle(Color.white)
                Spacer()
                if let more { Button(action: more) { HStack(spacing: 3) { Text("الكلّ").font(rnd(13, .bold)); Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold)) }.foregroundStyle(PL.tx3) }.buttonStyle(.plain) }
            }.padding(.horizontal, 18)
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { content() }.padding(.horizontal, 18) }
        }
    }
    private func chip(_ c: Channel, _ list: [Channel]) -> some View {
        Button { lib.play(channel: c, in: list) } label: {
            VStack(spacing: 6) {
                Art(url: c.logo, title: c.name).frame(width: 92, height: 62).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topLeading) { Circle().fill(PL.live).frame(width: 7, height: 7).padding(6) }
                Text(Core.clean(c.name)).font(rnd(12, .bold)).foregroundStyle(PL.tx2).lineLimit(1).frame(width: 92)
            }
        }.buttonStyle(Press())
    }
    private var continueRow: some View {
        row("أكمل المشاهدة") {
            ForEach(lib.continueList, id: \.0) { k, r in
                Button { lib.play(resume: k, r) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Art(url: r.poster, title: r.name, icon: "play.fill").frame(width: 190, height: 106)
                            GeometryReader { g in ZStack(alignment: .leading) { Rectangle().fill(Color.black.opacity(0.4)); Rectangle().fill(PL.ac).frame(width: g.size.width * min(1, r.t / max(1, r.d))) } }
                                .frame(height: 4).environment(\.layoutDirection, .leftToRight)
                        }.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text(r.name).font(rnd(13.5, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                        Text("باقي \(max(1, Int((r.d - r.t) / 60))) دقيقة").font(rnd(11.5)).foregroundStyle(PL.tx3)
                    }.frame(width: 190, alignment: .leading)
                }.buttonStyle(Press())
            }
        }
    }
    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().tint(PL.ac).scaleEffect(1.3)
            Text("دا نحمّل مكتبتك").font(rnd(18, .heavy)).foregroundStyle(Color.white)
            Text(lib.progress.isEmpty ? "لحظات…" : lib.progress).font(rnd(13.5)).foregroundStyle(PL.tx2)
            Text("أوّل مرّة تاخذ شويّة إذا المكتبة كبيرة. بعدها تفتح فورًا.").font(rnd(12)).foregroundStyle(PL.tx3).multilineTextAlignment(.center)
        }.padding(26).frame(maxWidth: .infinity).card(PL.s1, 24).padding(.horizontal, 18)
    }
    private var errorCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 40)).foregroundStyle(PL.live)
            Text("ما حمّلت المكتبة").font(rnd(18, .heavy)).foregroundStyle(Color.white)
            Text(lib.error).font(rnd(13.5)).foregroundStyle(PL.tx2).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button { Task { await lib.refresh() } } label: { Text("جرّب مرّة ثانية").font(rnd(14, .heavy)).foregroundStyle(Color.white).padding(.horizontal, 18).frame(height: 44).background(PL.ac, in: Capsule()) }.buttonStyle(Press())
                Button { settings = true } label: { Text("عدّل الاشتراك").font(rnd(14, .heavy)).foregroundStyle(PL.tx2).padding(.horizontal, 18).frame(height: 44).background(PL.s2, in: Capsule()) }.buttonStyle(Press())
            }
        }.padding(24).frame(maxWidth: .infinity).card(PL.s1, 24).padding(.horizontal, 18)
    }
}

/// بطاقة بوستر (فيلم/مسلسل)
struct PosterCell: View {
    let title: String; let url: String; var sub: String = ""; var rating: Double = 0; var width: CGFloat? = nil; var fav = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Color.clear.aspectRatio(2 / 3, contentMode: .fit)
                .overlay(Art(url: url, title: title))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if rating > 0 { Text(String(format: "★ %.1f", rating)).font(rnd(10.5, .heavy)).foregroundStyle(PL.gold).padding(.horizontal, 6).padding(.vertical, 2).background(Color.black.opacity(0.6), in: Capsule()).padding(6) }
                }
                .overlay(alignment: .topLeading) { if fav { Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(PL.live).padding(6).background(Color.black.opacity(0.55), in: Circle()).padding(5) } }
            Text(Core.clean(title)).font(rnd(12.5, .heavy)).foregroundStyle(Color.white).lineLimit(1)
            if !sub.isEmpty { Text(sub).font(rnd(11)).foregroundStyle(PL.tx3).environment(\.layoutDirection, .leftToRight) }
        }.frame(width: width)
    }
}

/// شريط التصنيفات
struct CatBar: View {
    let cats: [Cat]; @Binding var sel: String; var extra: [(String, String)] = []
    var body: some View {
        ScrollViewReader { sp in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    pill("", "الكلّ")
                    ForEach(extra, id: \.0) { e in pill(e.0, e.1) }
                    ForEach(cats) { c in pill(c.id, c.name) }
                }.padding(.horizontal, 16)
            }
        }
    }
    private func pill(_ id: String, _ name: String) -> some View {
        Button { Haptic.tap(); sel = id } label: {
            Text(name).font(rnd(13.5, .heavy)).lineLimit(1).foregroundStyle(sel == id ? Color.white : PL.tx2)
                .padding(.horizontal, 15).frame(height: 36).background(sel == id ? PL.ac : PL.s2, in: Capsule())
        }.buttonStyle(Press()).id(id)
    }
}
