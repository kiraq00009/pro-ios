import SwiftUI

// MARK: - اللاعبين
struct PlayersView: View {
    @EnvironmentObject var store: Store
    @State private var newName = ""
    @State private var editing: Member? = nil

    var body: some View {
        let careers = Dictionary(uniqueKeysWithValues: store.careers.map { ($0.id, $0) })
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("", text: $newName, prompt: Text("اسم لاعب جديد").foregroundColor(DR.tx3)).font(rnd(15, .bold)).foregroundStyle(Color.white)
                        .submitLabel(.done).onSubmit(add)
                        .padding(.horizontal, 14).frame(height: 48).background(DR.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Button(action: add) { Image(systemName: "plus").font(.system(size: 17, weight: .black)).foregroundStyle(DR.onGreen).frame(width: 48, height: 48).background(DR.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous)) }.buttonStyle(Press())
                }
                if store.members.isEmpty { Text("ضيف أسماء الربع حتى تبدي.").font(rnd(14)).foregroundStyle(DR.tx3).padding(.top, 40) }
                ForEach(store.members) { m in
                    let c = careers[m.id]
                    NavigationLink(value: Route.player(m.id)) {
                        HStack(spacing: 12) {
                            Avatar(name: m.name, color: DR.color(m.color), size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name).font(rnd(17, .heavy)).foregroundStyle(Color.white)
                                Text(c.map { $0.p == 0 ? "ما لعب بعد" : "\($0.p) مباراة · \($0.w) فوز · \($0.titles) لقب" } ?? "").font(rnd(12)).foregroundStyle(DR.tx3)
                            }
                            Spacer()
                            Button { editing = m } label: { Image(systemName: "pencil").font(.system(size: 13, weight: .bold)).foregroundStyle(DR.tx2).frame(width: 34, height: 34).background(DR.s2, in: Circle()) }.buttonStyle(Press())
                            Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold)).foregroundStyle(DR.tx3)
                        }.padding(12).card(DR.s1, 18)
                    }.buttonStyle(Press())
                }
            }.padding(16)
        }
        .background(Backdrop())
        .navigationTitle("اللاعبين").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { m in
            EditMember(member: m).environmentObject(store).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark).presentationDetents([.medium])
        }
    }
    private func add() {
        let n = newName.trimmingCharacters(in: .whitespaces); guard !n.isEmpty else { return }
        store.addMember(n); newName = ""; Haptic.tap()
    }
}

struct EditMember: View {
    @State var member: Member
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Avatar(name: member.name, color: DR.color(member.color), size: 54)
                TextField("", text: $member.name, prompt: Text("الاسم").foregroundColor(DR.tx3)).font(rnd(20, .heavy)).foregroundStyle(Color.white)
                    .padding(.horizontal, 14).frame(height: 52).background(DR.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text("اللون").font(rnd(14, .heavy)).foregroundStyle(DR.tx2)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 10)], spacing: 10) {
                ForEach(DR.palette.indices, id: \.self) { i in
                    Button { member.color = i; Haptic.tap() } label: {
                        Circle().fill(DR.palette[i].gradient).frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.white, lineWidth: member.color % DR.palette.count == i ? 3 : 0))
                    }.buttonStyle(Press())
                }
            }
            Spacer()
            BigButton(title: "حفظ", icon: "checkmark") {
                if !member.name.trimmingCharacters(in: .whitespaces).isEmpty { store.update(member) }
                dismiss()
            }
            if !store.used(member.id) {
                Button { store.remove(member: member.id); dismiss() } label: { Text("امسح اللاعب").font(rnd(14, .bold)).foregroundStyle(DR.red).frame(maxWidth: .infinity) }.buttonStyle(.plain)
            }
        }.padding(20).background(DR.bg.ignoresSafeArea())
    }
}

// MARK: - صفحة لاعب
struct PlayerView: View {
    let id: UUID
    @EnvironmentObject var store: Store

    var body: some View {
        let c = store.careers.first { $0.id == id } ?? Engine.Career(id: id)
        let titles = store.tournaments.filter { $0.champion == id && !$0.friendly }
        let rivals: [Rival] = rivalList()
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    Avatar(name: store.name(id), color: store.tint(id), size: 86)
                    Text(store.name(id)).font(rnd(30, .black)).foregroundStyle(Color.white)
                    HStack(spacing: 6) {
                        if c.titles > 0 { Pill(text: "🏆 \(c.titles) لقب", tint: DR.gold) }
                        if c.streak >= 2 { Pill(text: "🔥 \(c.streak) انتصارات ورا بعض", tint: DR.red) }
                        if c.p == 0 { Pill(text: "ما لعب بعد", tint: DR.tx2) }
                    }
                }.padding(.top, 6)

                if c.p > 0 {
                    // شريط الفوز/التعادل/الخسارة
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("\(c.p) مباراة").font(rnd(15, .heavy)).foregroundStyle(Color.white); Spacer(); Text(String(format: "نسبة الفوز %.0f٪", c.winRate * 100)).font(rnd(13, .heavy)).foregroundStyle(DR.green) }
                        GeometryReader { g in
                            HStack(spacing: 3) {
                                bar(DR.green, share(g.size.width, c.w, c.p))
                                bar(DR.tx3, share(g.size.width, c.d, c.p))
                                bar(DR.red, share(g.size.width, c.l, c.p))
                            }
                        }.frame(height: 10).environment(\.layoutDirection, .leftToRight)
                        HStack { key(DR.green, "فوز \(c.w)"); key(DR.tx3, "تعادل \(c.d)"); key(DR.red, "خسارة \(c.l)") }
                    }.padding(14).card(DR.s1, 20)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        tile("\(c.gf)", "سجّل")
                        tile("\(c.ga)", "استقبل")
                        tile(String(format: "%.1f", c.gpg), "هدف بالمباراة")
                        tile("\(c.finals)", "نهائيّ")
                        tile("\(c.bestStreak)", "أطول سلسلة")
                        tile(c.bestWin > 0 ? "+\(c.bestWin)" : "—", "أكبر فوز")
                    }
                }

                if !titles.isEmpty {
                    section("الألقاب")
                    ForEach(titles) { t in
                        NavigationLink(value: Route.tournament(t.id)) {
                            HStack(spacing: 10) {
                                Image(systemName: "trophy.fill").foregroundStyle(DR.gold)
                                Text(t.name).font(rnd(15, .heavy)).foregroundStyle(Color.white)
                                Spacer()
                                Text(agoText(t.created)).font(rnd(12)).foregroundStyle(DR.tx3)
                            }.padding(12).card(DR.s1, 16, stroke: DR.gold.opacity(0.25))
                        }.buttonStyle(Press())
                    }
                }

                if !rivals.isEmpty {
                    section("ضدّ كلّ واحد")
                    ForEach(rivals) { r in rivalRow(r) }
                    Text("أخضر = فاز عليه · رماديّ = تعادل · أحمر = خسر منه").font(rnd(11)).foregroundStyle(DR.tx3)
                }
            }.padding(16)
        }
        .background(Backdrop())
        .navigationBarTitleDisplayMode(.inline)
    }
    struct Rival: Identifiable { let id: UUID; let name: String; let color: Int; let w: Int; let d: Int; let l: Int; let gf: Int; let ga: Int; var total: Int { w + d + l } }
    private func rivalList() -> [Rival] {
        var out: [Rival] = []
        for m in store.members where m.id != id {
            let h = Engine.h2h(id, m.id, store.tournaments)
            let r = Rival(id: m.id, name: m.name, color: m.color, w: h.aw, d: h.d, l: h.bw, gf: h.ag, ga: h.bg)
            if r.total > 0 { out.append(r) }
        }
        return out.sorted { $0.total > $1.total }
    }
    private func rivalRow(_ r: Rival) -> some View {
        HStack(spacing: 10) {
            Avatar(name: r.name, color: DR.color(r.color), size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(r.name).font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text("الأهداف \(r.gf) - \(r.ga)").font(rnd(11.5)).foregroundStyle(DR.tx3)
            }
            Spacer()
            HStack(spacing: 5) {
                res("\(r.w)", DR.green)
                res("\(r.d)", DR.tx3)
                res("\(r.l)", DR.red)
            }.environment(\.layoutDirection, .leftToRight)
        }.padding(12).card(DR.s1, 16)
    }
    private func share(_ w: CGFloat, _ n: Int, _ of: Int) -> CGFloat { of == 0 ? 0 : w * CGFloat(n) / CGFloat(of) }
    private func bar(_ c: Color, _ w: CGFloat) -> some View { Capsule().fill(c).frame(width: max(0, w - 2)) }
    private func key(_ c: Color, _ t: String) -> some View { HStack(spacing: 5) { Circle().fill(c).frame(width: 8, height: 8); Text(t).font(rnd(12.5, .bold)).foregroundStyle(DR.tx2) }.frame(maxWidth: .infinity) }
    private func tile(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) { Text(v).font(rnd(24, .black)).foregroundStyle(Color.white); Text(l).font(rnd(11.5)).foregroundStyle(DR.tx3) }.frame(maxWidth: .infinity).padding(.vertical, 14).card(DR.s1, 18)
    }
    private func section(_ t: String) -> some View { Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4) }
    private func res(_ v: String, _ c: Color) -> some View { Text(v).font(rnd(14, .black)).foregroundStyle(c).frame(width: 32, height: 30).background(c.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous)) }
}

// MARK: - قاعة الأبطال
struct HallView: View {
    @EnvironmentObject var store: Store
    @State private var sort = 0

    var body: some View {
        let all = store.careers.filter { $0.p > 0 }
        let list: [Engine.Career] = sort == 0 ? all : (sort == 1 ? all.sorted { $0.winRate > $1.winRate } : all.sorted { $0.gf > $1.gf })
        let games = store.tournaments.flatMap { t in t.games.filter { $0.played && !$0.bye } }
        let big = games.max { abs(($0.hg ?? 0) - ($0.ag ?? 0)) < abs(($1.hg ?? 0) - ($1.ag ?? 0)) }
        let streak = all.max { $0.bestStreak < $1.bestStreak }
        ScrollView {
            VStack(spacing: 14) {
                if list.count >= 3 { podium(Array(list.prefix(3))) }
                Picker("", selection: $sort) { Text("الألقاب").tag(0); Text("نسبة الفوز").tag(1); Text("الأهداف").tag(2) }.pickerStyle(.segmented)
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, c in
                        NavigationLink(value: Route.player(c.id)) {
                            HStack(spacing: 10) {
                                Text("\(i + 1)").font(rnd(14, .black)).foregroundStyle(i == 0 ? DR.gold : DR.tx2).frame(width: 24)
                                Avatar(name: store.name(c.id), color: store.tint(c.id), size: 34)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(store.name(c.id)).font(rnd(15.5, .heavy)).foregroundStyle(Color.white)
                                    Text("\(c.p) مباراة · \(c.w)-\(c.d)-\(c.l)").font(rnd(11.5)).foregroundStyle(DR.tx3)
                                }
                                Spacer()
                                Text(sort == 0 ? "\(c.titles) 🏆" : (sort == 1 ? String(format: "%.0f٪", c.winRate * 100) : "\(c.gf) ⚽️")).font(rnd(16, .black)).foregroundStyle(sort == 0 ? DR.gold : DR.green)
                            }.padding(.horizontal, 12).padding(.vertical, 10).contentShape(Rectangle())
                        }.buttonStyle(Press())
                        if i < list.count - 1 { Divider().overlay(Color(white: 1, opacity: 0.06)).padding(.horizontal, 12) }
                    }
                }.card(DR.s1, 20)

                if let g = big, abs((g.hg ?? 0) - (g.ag ?? 0)) > 0 {
                    record("flame.fill", "أكبر نتيجة بالتاريخ", "\(store.name(g.winner)) \(max(g.hg ?? 0, g.ag ?? 0))-\(min(g.hg ?? 0, g.ag ?? 0)) \(store.name(g.loser))", DR.red)
                }
                if let s = streak, s.bestStreak >= 2 { record("bolt.fill", "أطول سلسلة انتصارات", "\(store.name(s.id)) — \(s.bestStreak) ورا بعض", DR.gold) }
                record("soccerball", "مجموع الأهداف", "\(games.reduce(0) { $0 + ($1.hg ?? 0) + ($1.ag ?? 0) }) هدف بـ\(games.count) مباراة", DR.green)
                if all.isEmpty { Text("الأرقام تطلع بعد أوّل مباراة.").font(rnd(14)).foregroundStyle(DR.tx3).padding(.top, 30) }
            }.padding(16)
        }
        .background(Backdrop())
        .navigationTitle("قاعة الأبطال").navigationBarTitleDisplayMode(.inline)
    }

    private func podium(_ top: [Engine.Career]) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            step(top[1], 2, 74, Color(white: 0.78))
            step(top[0], 1, 104, DR.gold)
            step(top[2], 3, 56, Color(red: 0.8, green: 0.52, blue: 0.3))
        }.environment(\.layoutDirection, .leftToRight).padding(.top, 8)
    }
    private func step(_ c: Engine.Career, _ rank: Int, _ h: CGFloat, _ col: Color) -> some View {
        VStack(spacing: 6) {
            if rank == 1 { Image(systemName: "crown.fill").font(.system(size: 20)).foregroundStyle(DR.gold) }
            Avatar(name: store.name(c.id), color: store.tint(c.id), size: rank == 1 ? 62 : 50)
            Text(store.name(c.id)).font(rnd(15, .heavy)).foregroundStyle(Color.white).lineLimit(1)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient(colors: [col.opacity(0.55), col.opacity(0.12)], startPoint: .top, endPoint: .bottom)).frame(height: h)
                Text("\(rank)").font(rnd(26, .black)).foregroundStyle(Color.white).padding(.top, 8)
            }
        }.frame(maxWidth: .infinity)
    }
    private func record(_ icon: String, _ t: String, _ v: String, _ c: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(c).frame(width: 44, height: 44).background(c.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 1) { Text(t).font(rnd(12, .bold)).foregroundStyle(DR.tx3); Text(v).font(rnd(16, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.7) }
            Spacer(minLength: 0)
        }.padding(12).card(DR.s1, 18)
    }
}
