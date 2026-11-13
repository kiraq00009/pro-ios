import SwiftUI

struct TournamentView: View {
    let id: UUID
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var editing: Game? = nil
    @State private var onlyLeft = false
    @State private var celebrate = false
    @State private var del = false
    @State private var renaming = false
    @State private var newName = ""

    var body: some View {
        Group {
            if let t = store.tournament(id) { content(t) } else { Color.clear.onAppear { dismiss() } }
        }
        .background(Backdrop())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { g in
            ScoreSheet(tid: id, game: g).environmentObject(store).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark).presentationDetents([.large])
        }
        .onChange(of: store.tournament(id)?.champion) { c in if c != nil { Haptic.ok(); withAnimation { celebrate = true } } }
        .onAppear {
            guard Shot.on, let t = store.tournament(id) else { return }
            switch Shot.name {
            case "matches": tab = 0
            case "table", "groups": tab = 1
            case "bracket": tab = 2
            case "stats": tab = t.format == .league ? 2 : 3
            case "score": editing = t.games.first { $0.ready && !$0.decided }
            case "champion": celebrate = true
            default: break
            }
        }
    }

    private func tabs(_ t: Tournament) -> [String] {
        switch t.format {
        case .league: return ["المباريات", "الترتيب", "الأرقام"]
        case .cup: return ["المباريات", "الشجرة", "الأرقام"]
        case .groups: return ["المباريات", "المجموعات", "الشجرة", "الأرقام"]
        }
    }

    @ViewBuilder private func content(_ t: Tournament) -> some View {
        let names = tabs(t)
        let current = names[min(tab, names.count - 1)]
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(t)
                    HStack(spacing: 6) {
                        ForEach(Array(names.enumerated()), id: \.offset) { i, n in
                            Button { Haptic.tap(); withAnimation(.easeOut(duration: 0.15)) { tab = i } } label: {
                                Text(n).font(rnd(14, .heavy)).foregroundStyle(tab == i ? DR.onGreen : DR.tx2).frame(maxWidth: .infinity).frame(height: 40)
                                    .background(tab == i ? DR.green : DR.s2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }.buttonStyle(Press())
                        }
                    }
                    switch current {
                    case "المباريات": MatchesTab(t: t, onlyLeft: $onlyLeft) { editing = $0 }
                    case "الترتيب": TableCard(t: t, group: nil)
                    case "المجموعات": ForEach(t.groups.indices, id: \.self) { g in TableCard(t: t, group: g) }
                    case "الشجرة": BracketView(t: t) { editing = $0 }
                    default: StatsTab(t: t)
                    }
                }
                .padding(16)
            }
            if celebrate, let c = t.champion { ChampionOverlay(name: store.name(c), color: store.tint(c), club: t.club(c), title: t.name) { withAnimation { celebrate = false } } }
        }
        .navigationTitle(t.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if t.format != .cup, let img = shareImage(t) {
                        ShareLink(item: Image(uiImage: img), preview: SharePreview(t.name, image: Image(uiImage: img))) { Label("شارك الترتيب", systemImage: "square.and.arrow.up") }
                    }
                    Button { newName = t.name; renaming = true } label: { Label("غيّر الاسم", systemImage: "pencil") }
                    Button(role: .destructive) { del = true } label: { Label("امسح البطولة", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle").font(.system(size: 17, weight: .semibold)) }
            }
        }
        .alert("تمسح «\(t.name)»؟", isPresented: $del) {
            Button("امسحها", role: .destructive) { store.remove(tournament: id); dismiss() }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("كلّ نتائجها تنشال من الأرقام، وما ترجع.") }
        .alert("اسم البطولة", isPresented: $renaming) {
            TextField("الاسم", text: $newName)
            Button("حفظ") { if !newName.trimmingCharacters(in: .whitespaces).isEmpty { store.rename(id, newName) } }
            Button("إلغاء", role: .cancel) {}
        }
    }

    private func header(_ t: Tournament) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Pill(text: DR.formatName(t.format)); if t.legs == 2 { Pill(text: "ذهاب وإياب", tint: DR.tx2) }
                    Pill(text: "\(t.members.count) لاعبين", tint: DR.tx2)
                }
                if let c = t.champion {
                    HStack(spacing: 8) { Image(systemName: "trophy.fill").foregroundStyle(DR.gold); Text("البطل: " + store.name(c)).font(rnd(18, .black)).foregroundStyle(DR.gold) }
                } else {
                    Text("\(t.playedCount) من \(t.playable.count) مباراة").font(rnd(15, .heavy)).foregroundStyle(Color.white)
                    GeometryReader { g in
                        ZStack(alignment: .leading) { Capsule().fill(DR.s3); Capsule().fill(DR.green).frame(width: max(6, g.size.width * t.progress)) }
                    }.frame(height: 6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14).card(DR.s1, 20, stroke: t.champion != nil ? DR.gold.opacity(0.35) : Color(white: 1, opacity: 0.07))
    }

    @MainActor private func shareImage(_ t: Tournament) -> UIImage? {
        let v = VStack(alignment: .leading, spacing: 12) {
            Text(t.name).font(rnd(26, .black)).foregroundStyle(Color.white)
            if t.format == .league { TableCard(t: t, group: nil) } else { ForEach(t.groups.indices, id: \.self) { g in TableCard(t: t, group: g) } }
            Text("دوري — مدير بطولات الربع").font(rnd(12, .bold)).foregroundStyle(DR.tx3)
        }
        .padding(20).frame(width: 420).background(DR.bg)
        .environmentObject(store).environment(\.layoutDirection, .rightToLeft).environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: v); r.scale = 3
        return r.uiImage
    }
}

// MARK: - المباريات
struct MatchesTab: View {
    @EnvironmentObject var store: Store
    let t: Tournament
    @Binding var onlyLeft: Bool
    let open: (Game) -> Void

    private struct Block: Identifiable { let id: String; let title: String; let games: [Game] }
    private var blocks: [Block] {
        var out: [Block] = []
        let list = t.playable.filter { !onlyLeft || !$0.decided }
        let league = list.filter { $0.stage.kind == 0 }
        for r in Set(league.map { $0.stage.round }).sorted() { out.append(Block(id: "l\(r)", title: "الجولة \(r + 1)", games: league.filter { $0.stage.round == r })) }
        let grp = list.filter { $0.stage.kind == 1 }
        for r in Set(grp.map { $0.stage.round }).sorted() {
            for g in Set(grp.filter { $0.stage.round == r }.map { $0.stage.group }).sorted() {
                out.append(Block(id: "g\(g)-\(r)", title: "المجموعة \(DR.groupNames[g]) · الجولة \(r + 1)", games: grp.filter { $0.stage.round == r && $0.stage.group == g }))
            }
        }
        let ko = list.filter { $0.stage.kind == 2 }
        for r in Set(ko.map { $0.stage.round }).sorted() { out.append(Block(id: "k\(r)", title: Engine.koName(t, round: r), games: ko.filter { $0.stage.round == r }.sorted { $0.stage.slot < $1.stage.slot })) }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $onlyLeft) { Text("الباقية فقط").font(rnd(14, .bold)).foregroundStyle(DR.tx2) }.tint(DR.green).padding(.horizontal, 4)
            if blocks.isEmpty { Text("ماكو مباريات باقية 🎉").font(rnd(15, .heavy)).foregroundStyle(DR.tx2).frame(maxWidth: .infinity).padding(.vertical, 30) }
            ForEach(blocks) { b in
                VStack(alignment: .leading, spacing: 8) {
                    Text(b.title).font(rnd(13.5, .heavy)).foregroundStyle(DR.tx3).padding(.horizontal, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(b.games.enumerated()), id: \.element.id) { i, g in
                            Button { if g.ready { Haptic.tap(); open(g) } } label: { GameRow(t: t, g: g) }.buttonStyle(Press())
                            if i < b.games.count - 1 { Divider().overlay(Color(white: 1, opacity: 0.06)).padding(.horizontal, 12) }
                        }
                    }.card(DR.s1, 18)
                }
            }
        }
    }
}

struct GameRow: View {
    @EnvironmentObject var store: Store
    let t: Tournament; let g: Game

    private func label(_ id: UUID?, _ seed: String?) -> String {
        if let id { return store.name(id) }
        if let s = seed, s.count == 2, let gi = ["A", "B", "C", "D"].firstIndex(of: String(s.prefix(1))) { return (s.hasSuffix("1") ? "أوّل " : "ثاني ") + "المجموعة " + DR.groupNames[gi] }
        return "الفائز"
    }
    var body: some View {
        let w = g.winner
        HStack(spacing: 8) {
            side(g.home, label(g.home, g.seedHome), win: w != nil && w == g.home, lead: true)
            Group {
                if g.played {
                    VStack(spacing: 1) {
                        Text("\(g.hg ?? 0) - \(g.ag ?? 0)").font(rnd(19, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
                        if let p = g.hp, let q = g.ap { Text("ترجيح \(p)-\(q)").font(rnd(10, .bold)).foregroundStyle(DR.gold) }
                        else if g.needsPens { Text("يحتاج ترجيح").font(rnd(10, .bold)).foregroundStyle(DR.red) }
                    }
                } else {
                    Text(g.ready ? "سجّل" : "—").font(rnd(12.5, .heavy)).foregroundStyle(g.ready ? DR.onGreen : DR.tx3)
                        .padding(.horizontal, 12).frame(height: 30).background(g.ready ? DR.green : DR.s3, in: Capsule())
                }
            }.frame(width: 84)
            side(g.away, label(g.away, g.seedAway), win: w != nil && w == g.away, lead: false)
        }
        .padding(.horizontal, 12).padding(.vertical, 11).contentShape(Rectangle())
        .environment(\.layoutDirection, .leftToRight)
    }
    private func side(_ id: UUID?, _ name: String, win: Bool, lead: Bool) -> some View {
        HStack(spacing: 8) {
            if !lead { Spacer(minLength: 0) }
            if lead { avatar(id, name) }
            VStack(alignment: lead ? .leading : .trailing, spacing: 0) {
                Text(name).font(rnd(15, win ? .black : .bold)).foregroundStyle(id == nil ? DR.tx3 : (win ? DR.green : Color.white)).lineLimit(1).minimumScaleFactor(0.7)
                if let id, !t.club(id).isEmpty { Text(t.club(id)).font(rnd(10.5)).foregroundStyle(DR.tx3).lineLimit(1) }
            }
            if !lead { avatar(id, name) }
            if lead { Spacer(minLength: 0) }
        }.frame(maxWidth: .infinity)
    }
    @ViewBuilder private func avatar(_ id: UUID?, _ name: String) -> some View {
        if let id { Avatar(name: name, color: store.tint(id), size: 32) }
        else { Image(systemName: "questionmark").font(.system(size: 12, weight: .black)).foregroundStyle(DR.tx3).frame(width: 32, height: 32).background(DR.s3, in: Circle()) }
    }
}

// MARK: - جدول الترتيب
struct TableCard: View {
    @EnvironmentObject var store: Store
    let t: Tournament; let group: Int?
    var body: some View {
        let rows = Engine.standings(t, group: group)
        VStack(alignment: .leading, spacing: 0) {
            if let g = group { Text("المجموعة " + DR.groupNames[g]).font(rnd(15, .heavy)).foregroundStyle(Color.white).padding(.horizontal, 14).padding(.top, 12) }
            HStack(spacing: 0) {
                Text("#").frame(width: 26); Text("اللاعب").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(["لعب", "ف", "ت", "خ", "±", "نقاط"], id: \.self) { h in Text(h).frame(width: h == "نقاط" ? 40 : 30) }
            }
            .font(rnd(11.5, .heavy)).foregroundStyle(DR.tx3).padding(.horizontal, 12).padding(.vertical, 10)
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                let q = group != nil && i < 2
                HStack(spacing: 0) {
                    Text("\(i + 1)").font(rnd(13, .black)).foregroundStyle(i == 0 ? DR.gold : (q ? DR.green : DR.tx2)).frame(width: 26)
                    HStack(spacing: 8) {
                        Avatar(name: store.name(r.id), color: store.tint(r.id), size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(store.name(r.id)).font(rnd(14.5, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                            HStack(spacing: 3) { ForEach(Array(r.form.enumerated()), id: \.offset) { _, f in Circle().fill(f > 0 ? DR.green : (f < 0 ? DR.red : DR.tx3)).frame(width: 6, height: 6) } }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Group {
                        Text("\(r.p)").frame(width: 30); Text("\(r.w)").frame(width: 30); Text("\(r.d)").frame(width: 30); Text("\(r.l)").frame(width: 30)
                        Text(r.gd > 0 ? "+\(r.gd)" : "\(r.gd)").frame(width: 30).foregroundStyle(r.gd > 0 ? DR.green : (r.gd < 0 ? DR.red : DR.tx2))
                    }.font(rnd(13, .bold)).foregroundStyle(DR.tx2)
                    Text("\(r.pts)").font(rnd(16, .black)).foregroundStyle(Color.white).frame(width: 40)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(i == 0 && r.p > 0 ? DR.gold.opacity(0.07) : Color.clear)
                if group != nil && i == 1 { Rectangle().fill(DR.green.opacity(0.5)).frame(height: 1.5).padding(.horizontal, 12) }
            }
            if group != nil { Text("أوّل اثنين يتأهّلون").font(rnd(11)).foregroundStyle(DR.tx3).padding(.horizontal, 14).padding(.vertical, 8) }
            else { Color.clear.frame(height: 6) }
        }
        .card(DR.s1, 20)
    }
}

// MARK: - شجرة الإقصاء
struct BracketView: View {
    @EnvironmentObject var store: Store
    let t: Tournament
    let open: (Game) -> Void
    private let bw: CGFloat = 168, bh: CGFloat = 76, gap: CGFloat = 34

    var body: some View {
        let rounds = Engine.koRounds(t)
        let first = t.games.filter { $0.stage.kind == 2 && $0.stage.round == (rounds.first ?? 0) }.count
        let unit = bh + 14
        let height = CGFloat(max(1, first)) * unit
        VStack(alignment: .leading, spacing: 10) {
            if t.format == .groups && t.games.contains(where: { $0.stage.kind == 1 && !$0.played }) {
                Text("الشجرة تتعبّى بعد ما تخلص مباريات المجموعات.").font(rnd(12.5)).foregroundStyle(DR.tx3)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // خطوط الربط
                    Canvas { ctx, _ in
                        for (ri, r) in rounds.enumerated() where ri + 1 < rounds.count {
                            let games = t.games.filter { $0.stage.kind == 2 && $0.stage.round == r }
                            for g in games {
                                let span = height / CGFloat(games.count), y = span * (CGFloat(g.stage.slot) + 0.5)
                                let nspan = span * 2, ny = nspan * (CGFloat(g.stage.slot / 2) + 0.5)
                                let x0 = CGFloat(ri) * (bw + gap) + bw, x1 = x0 + gap
                                var p = Path(); p.move(to: CGPoint(x: x0, y: y)); p.addLine(to: CGPoint(x: x0 + gap / 2, y: y)); p.addLine(to: CGPoint(x: x0 + gap / 2, y: ny)); p.addLine(to: CGPoint(x: x1, y: ny))
                                ctx.stroke(p, with: .color(g.decided ? DR.green.opacity(0.7) : Color(white: 1, opacity: 0.16)), lineWidth: 2)
                            }
                        }
                    }
                    ForEach(Array(rounds.enumerated()), id: \.element) { ri, r in
                        let games = t.games.filter { $0.stage.kind == 2 && $0.stage.round == r }.sorted { $0.stage.slot < $1.stage.slot }
                        ForEach(games) { g in
                            let span = height / CGFloat(games.count)
                            Button { if g.ready { Haptic.tap(); open(g) } } label: { box(g) }.buttonStyle(Press())
                                .frame(width: bw, height: bh)
                                .position(x: CGFloat(ri) * (bw + gap) + bw / 2, y: span * (CGFloat(g.stage.slot) + 0.5))
                        }
                        Text(Engine.koName(t, round: r)).font(rnd(12, .heavy)).foregroundStyle(DR.tx3)
                            .frame(width: bw).position(x: CGFloat(ri) * (bw + gap) + bw / 2, y: -14)
                    }
                }
                .frame(width: CGFloat(rounds.count) * (bw + gap) - gap, height: height)
                .padding(.top, 30).padding(.bottom, 10).padding(.horizontal, 2)
                .environment(\.layoutDirection, .leftToRight)
            }
        }
    }
    private func seedLabel(_ s: String?) -> String? {
        guard let s, s.count == 2, let gi = ["A", "B", "C", "D"].firstIndex(of: String(s.prefix(1))) else { return nil }
        return (s.hasSuffix("1") ? "أوّل " : "ثاني ") + DR.groupNames[gi]
    }
    private func box(_ g: Game) -> some View {
        let w = g.winner
        return VStack(spacing: 0) {
            line(g.home, g.seedHome, g.hg, g.hp, win: w != nil && w == g.home, bye: g.bye && g.home == nil)
            Divider().overlay(Color(white: 1, opacity: 0.08))
            line(g.away, g.seedAway, g.ag, g.ap, win: w != nil && w == g.away, bye: g.bye && g.away == nil)
        }
        .card(DR.s1, 14, stroke: g.ready && !g.decided ? DR.green.opacity(0.6) : Color(white: 1, opacity: 0.08))
    }
    private func line(_ id: UUID?, _ seed: String?, _ goals: Int?, _ pens: Int?, win: Bool, bye: Bool) -> some View {
        HStack(spacing: 7) {
            if let id { Avatar(name: store.name(id), color: store.tint(id), size: 22) } else { Circle().fill(DR.s3).frame(width: 22, height: 22) }
            Text(id != nil ? store.name(id) : (bye ? "تأهّل مباشر" : (seedLabel(seed) ?? "الفائز")))
                .font(rnd(13.5, win ? .black : .bold)).foregroundStyle(id == nil ? DR.tx3 : (win ? DR.green : Color.white)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if let p = pens { Text("(\(p))").font(rnd(10.5, .bold)).foregroundStyle(DR.gold) }
            if let s = goals { Text("\(s)").font(rnd(15, .black)).foregroundStyle(win ? DR.green : Color.white) }
        }
        .padding(.horizontal, 9).frame(height: 37)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - أرقام البطولة
struct StatsTab: View {
    @EnvironmentObject var store: Store
    let t: Tournament
    var body: some View {
        let played = t.games.filter { $0.played && !$0.bye }
        let goals = played.reduce(0) { $0 + ($1.hg ?? 0) + ($1.ag ?? 0) }
        let cs = Engine.careers(t.members.compactMap { store.member($0) }, [t]).filter { $0.p > 0 }
        let top = cs.sorted { $0.gf > $1.gf }.first, wall = cs.sorted { Double($0.ga) / Double($0.p) < Double($1.ga) / Double($1.p) }.first
        let big = played.max { abs(($0.hg ?? 0) - ($0.ag ?? 0)) < abs(($1.hg ?? 0) - ($1.ag ?? 0)) }
        let fest = played.max { ($0.hg ?? 0) + ($0.ag ?? 0) < ($1.hg ?? 0) + ($1.ag ?? 0) }
        VStack(spacing: 10) {
            if played.isEmpty { Text("الأرقام تطلع بعد أوّل مباراة.").font(rnd(14)).foregroundStyle(DR.tx3).padding(.vertical, 30) }
            else {
                HStack(spacing: 10) {
                    tile("\(goals)", "هدف", "soccerball", DR.green)
                    tile(String(format: "%.1f", Double(goals) / Double(played.count)), "هدف بالمباراة", "chart.bar.fill", Color(red: 0.3, green: 0.65, blue: 1))
                    tile("\(played.count)", "مباراة", "flag.fill", DR.gold)
                }
                if let x = top { award("flame.fill", "الهدّاف", store.name(x.id), "\(x.gf) هدف", DR.red, store.tint(x.id)) }
                if let x = wall { award("shield.fill", "أقوى دفاع", store.name(x.id), "استقبل \(x.ga) بـ\(x.p) مباراة", Color(red: 0.3, green: 0.65, blue: 1), store.tint(x.id)) }
                if let x = cs.sorted(by: { $0.bestStreak > $1.bestStreak }).first, x.bestStreak >= 2 { award("bolt.fill", "أطول سلسلة انتصارات", store.name(x.id), "\(x.bestStreak) ورا بعض", DR.gold, store.tint(x.id)) }
                if let g = big, abs((g.hg ?? 0) - (g.ag ?? 0)) > 0 { match("أكبر فوز", g) }
                if let g = fest { match("أكثر مباراة بيها أهداف", g) }
            }
        }
    }
    private func tile(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(26, .black)).foregroundStyle(Color.white)
            Text(l).font(rnd(11.5)).foregroundStyle(DR.tx3)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).card(DR.s1, 18, stroke: c.opacity(0.22))
    }
    private func award(_ icon: String, _ title: String, _ name: String, _ sub: String, _ c: Color, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(c).frame(width: 44, height: 44).background(c.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 1) { Text(title).font(rnd(12, .bold)).foregroundStyle(DR.tx3); Text(name).font(rnd(17, .black)).foregroundStyle(Color.white) }
            Spacer()
            Text(sub).font(rnd(13, .heavy)).foregroundStyle(c)
            Avatar(name: name, color: tint, size: 34)
        }.padding(12).card(DR.s1, 18)
    }
    private func match(_ title: String, _ g: Game) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(rnd(12, .bold)).foregroundStyle(DR.tx3).padding(.horizontal, 12).padding(.top, 10)
            GameRow(t: t, g: g)
        }.card(DR.s1, 18)
    }
}

// MARK: - تسجيل النتيجة
struct ScoreSheet: View {
    let tid: UUID; let game: Game
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var hg = 0
    @State private var ag = 0
    @State private var hp = 0
    @State private var ap = 0

    var body: some View {
        let ko = game.stage.kind == 2, tie = ko && hg == ag
        VStack(spacing: 16) {
            Capsule().fill(DR.s3).frame(width: 40, height: 5).padding(.top, 10)
            Text(game.played ? "عدّل النتيجة" : "سجّل النتيجة").font(rnd(22, .black)).foregroundStyle(Color.white)
            HStack(alignment: .top, spacing: 10) {
                ScoreSide(name: store.name(game.home), color: store.tint(game.home), value: $hg)
                Text(":").font(rnd(40, .black)).foregroundStyle(DR.tx3).padding(.top, 86)
                ScoreSide(name: store.name(game.away), color: store.tint(game.away), value: $ag)
            }.environment(\.layoutDirection, .leftToRight).padding(.horizontal, 16)

            if tie {
                VStack(spacing: 10) {
                    Text("تعادل — منو فاز بركلات الترجيح؟").font(rnd(14, .heavy)).foregroundStyle(DR.gold)
                    HStack(spacing: 12) {
                        pens($hp); Text("ترجيح").font(rnd(12, .bold)).foregroundStyle(DR.tx3); pens($ap)
                    }.environment(\.layoutDirection, .leftToRight)
                    if hp == ap { Text("لازم واحد يفوز بالترجيح").font(rnd(12)).foregroundStyle(DR.red) }
                }.padding(14).frame(maxWidth: .infinity).card(DR.s1, 18, stroke: DR.gold.opacity(0.35)).padding(.horizontal, 16)
            }
            Spacer(minLength: 0)
            BigButton(title: "احفظ", icon: "checkmark") {
                store.score(tid, game.id, hg: hg, ag: ag, hp: tie ? hp : nil, ap: tie ? ap : nil); Haptic.ok(); dismiss()
            }.opacity(tie && hp == ap ? 0.4 : 1).disabled(tie && hp == ap).padding(.horizontal, 16)
            if game.played {
                Button { store.score(tid, game.id, hg: nil, ag: nil); dismiss() } label: { Text("امسح النتيجة").font(rnd(14, .bold)).foregroundStyle(DR.red) }.buttonStyle(.plain)
            }
            Color.clear.frame(height: 6)
        }
        .background(DR.bg.ignoresSafeArea())
        .onAppear {
            hg = game.hg ?? 0; ag = game.ag ?? 0; hp = game.hp ?? 0; ap = game.ap ?? 0
            if Shot.name == "score" { hg = 3; ag = 1 }
        }
    }
    private func pens(_ v: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Button { if v.wrappedValue > 0 { v.wrappedValue -= 1; Haptic.tap() } } label: { Image(systemName: "minus").font(.system(size: 13, weight: .black)).foregroundStyle(Color.white).frame(width: 34, height: 34).background(DR.s3, in: Circle()) }.buttonStyle(Press())
            Text("\(v.wrappedValue)").font(rnd(24, .black)).foregroundStyle(Color.white).frame(width: 34)
            Button { v.wrappedValue += 1; Haptic.tap() } label: { Image(systemName: "plus").font(.system(size: 13, weight: .black)).foregroundStyle(DR.onGreen).frame(width: 34, height: 34).background(DR.gold, in: Circle()) }.buttonStyle(Press())
        }
    }
}

// MARK: - احتفال البطل
struct ChampionOverlay: View {
    let name: String; let color: Color; let club: String; let title: String
    let close: () -> Void
    @State private var start = Date()
    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea().onTapGesture(perform: close)
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(start)
                    for i in 0..<90 {
                        let f = Double(i)
                        let x = (sin(f * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                        let speed = 120 + abs(sin(f * 3.7)) * 180, delay = abs(sin(f * 1.3)) * 2.2
                        let y = (t - delay) * speed
                        guard y > 0 else { continue }
                        let px = abs(x) * size.width + sin(t * 2 + f) * 18, py = y.truncatingRemainder(dividingBy: Double(size.height) + 40) - 20
                        let c = DR.palette[i % DR.palette.count]
                        var p = Path(roundedRect: CGRect(x: -4, y: -7, width: 8, height: 14), cornerRadius: 2)
                        p = p.applying(CGAffineTransform(rotationAngle: CGFloat(t * 3 + f)).concatenating(CGAffineTransform(translationX: CGFloat(px), y: CGFloat(py))))
                        ctx.fill(p, with: .color(c))
                    }
                }
            }.ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 14) {
                Image(systemName: "trophy.fill").font(.system(size: 76)).foregroundStyle(DR.gold).shadow(color: DR.gold.opacity(0.6), radius: 24)
                Text("البطل").font(rnd(18, .heavy)).foregroundStyle(DR.tx2)
                Avatar(name: name, color: color, size: 84)
                Text(name).font(rnd(44, .black)).foregroundStyle(Color.white)
                if !club.isEmpty { Text(club).font(rnd(16, .heavy)).foregroundStyle(DR.gold) }
                Text(title).font(rnd(14)).foregroundStyle(DR.tx3)
                Button(action: close) { Text("تمام").font(rnd(16, .heavy)).foregroundStyle(DR.onGreen).frame(width: 180, height: 50).background(DR.green, in: Capsule()) }.buttonStyle(Press()).padding(.top, 10)
            }
        }
        .transition(.opacity)
    }
}
