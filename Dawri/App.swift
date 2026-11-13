import SwiftUI

enum Route: Hashable { case tournament(UUID), player(UUID), hall, players }

@main
struct DawriApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(DR.green)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            DR.bg
            RadialGradient(colors: [DR.green.opacity(0.16), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 480)
            RadialGradient(colors: [Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.10), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var path: [Route] = []
    @State private var creating = false
    @State private var friendly = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path, creating: $creating, friendly: $friendly)
                .navigationDestination(for: Route.self) { r in
                    switch r {
                    case .tournament(let id): TournamentView(id: id)
                    case .player(let id): PlayerView(id: id)
                    case .hall: HallView()
                    case .players: PlayersView()
                    }
                }
        }
        .sheet(isPresented: $creating) {
            CreateView { t in creating = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { path.append(.tournament(t.id)) } }
                .environmentObject(store).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $friendly) {
            FriendlyView().environmentObject(store).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark).presentationDetents([.large])
        }
        .onAppear(perform: shot)
    }

    /// وضع التصوير: نفتح الشاشة المطلوبة مباشرة
    private func shot() {
        guard Shot.on else { return }
        let groups = store.tournaments.first { $0.format == .groups }, league = store.tournaments.first { $0.format == .league && !$0.finished }
        switch Shot.name {
        case "table", "matches", "stats", "score": if let t = league { path = [.tournament(t.id)] }
        case "groups", "bracket": if let t = groups { path = [.tournament(t.id)] }
        case "champion": if let t = store.done.first { path = [.tournament(t.id)] }
        case "player": if let m = store.careers.first { path = [.player(m.id)] }
        case "hall": path = [.hall]
        case "players": path = [.players]
        case "create", "create2", "create3": creating = true
        default: break
        }
    }
}

// MARK: - الرئيسيّة
struct HomeView: View {
    @EnvironmentObject var store: Store
    @Binding var path: [Route]
    @Binding var creating: Bool
    @Binding var friendly: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("دوري").font(rnd(36, .black)).foregroundStyle(Color.white)
                        Text("بطولاتك ويّا الربع — منو البطل الليلة؟").font(rnd(13)).foregroundStyle(DR.tx3)
                    }
                    Spacer()
                    Button { path.append(.players) } label: {
                        Image(systemName: "person.2.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.white).frame(width: 44, height: 44).background(DR.s2, in: Circle())
                    }.buttonStyle(Press())
                }

                if store.tournaments.isEmpty { empty } else {
                    if !store.active.isEmpty {
                        section("شغّالة هسه")
                        ForEach(store.active) { t in
                            Button { path.append(.tournament(t.id)) } label: { ActiveCard(t: t) }.buttonStyle(Press())
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button { creating = true } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "trophy.fill").font(.system(size: 24, weight: .bold))
                            Text("بطولة جديدة").font(rnd(17, .black))
                            Text("دوري، كأس، أو مجموعات").font(rnd(11.5)).opacity(0.7)
                        }
                        .foregroundStyle(DR.onGreen).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [DR.green, Color(red: 0.1, green: 0.75, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }.buttonStyle(Press())
                    Button { friendly = true } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "bolt.fill").font(.system(size: 24, weight: .bold)).foregroundStyle(DR.gold)
                            Text("مباراة ودّيّة").font(rnd(17, .black)).foregroundStyle(Color.white)
                            Text("سجّل نتيجة سريعة").font(rnd(11.5)).foregroundStyle(DR.tx3)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(DR.s1, 24)
                    }.buttonStyle(Press())
                }

                if store.careers.contains(where: { $0.p > 0 }) { leaders }

                if !store.done.isEmpty {
                    section("بطولات خلصت")
                    ForEach(store.done) { t in
                        Button { path.append(.tournament(t.id)) } label: { DoneRow(t: t) }.buttonStyle(Press())
                    }
                }
            }
            .padding(18)
        }
        .background(Backdrop())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func section(_ t: String) -> some View { Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white).padding(.top, 4) }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "sportscourt.fill").font(.system(size: 46)).foregroundStyle(DR.green)
            Text("سوّي أوّل بطولة").font(rnd(20, .black)).foregroundStyle(Color.white)
            Text("ضيف أسماء الربع، اختار نوع البطولة، والتطبيق يرتّب المباريات ويحسب الترتيب والأرقام لحاله.").font(rnd(13.5)).foregroundStyle(DR.tx2).multilineTextAlignment(.center).lineSpacing(3)
        }
        .padding(24).frame(maxWidth: .infinity).card(DR.s1, 24)
    }

    private var leaders: some View {
        let top = Array(store.careers.filter { $0.p > 0 }.prefix(3))
        return Button { path.append(.hall) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("قاعة الأبطال", systemImage: "crown.fill").font(rnd(16, .heavy)).foregroundStyle(DR.gold)
                    Spacer()
                    Text("الكلّ").font(rnd(12.5, .bold)).foregroundStyle(DR.tx3)
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold)).foregroundStyle(DR.tx3)
                }
                HStack(spacing: 10) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { i, c in
                        VStack(spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                Avatar(name: store.name(c.id), color: store.tint(c.id), size: 50)
                                Text("\(i + 1)").font(rnd(11, .black)).foregroundStyle(Color.black).frame(width: 20, height: 20).background(i == 0 ? DR.gold : Color(white: 0.8), in: Circle()).offset(x: 6, y: -4)
                            }
                            Text(store.name(c.id)).font(rnd(14, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                            Text("\(c.titles) لقب · \(c.w) فوز").font(rnd(11)).foregroundStyle(DR.tx3)
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16).card(DR.s1, 24, stroke: DR.gold.opacity(0.25))
        }.buttonStyle(Press())
    }
}

struct ActiveCard: View {
    @EnvironmentObject var store: Store
    let t: Tournament
    private var next: Game? { t.games.first { $0.ready && !$0.decided } }
    private var leader: UUID? { t.format == .league ? Engine.standings(t).first(where: { $0.p > 0 })?.id : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.name).font(rnd(20, .black)).foregroundStyle(Color.white).lineLimit(1)
                    HStack(spacing: 6) {
                        Pill(text: DR.formatName(t.format))
                        Pill(text: "\(t.members.count) لاعبين", tint: DR.tx2)
                        if let l = leader { Pill(text: "المتصدّر: " + store.name(l), tint: DR.gold) }
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color(white: 1, opacity: 0.1), lineWidth: 5)
                    Circle().trim(from: 0, to: t.progress).stroke(DR.green, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(Int(t.progress * 100))٪").font(rnd(12, .heavy)).foregroundStyle(Color.white)
                }.frame(width: 50, height: 50)
            }
            if let g = next {
                HStack(spacing: 10) {
                    Text("الجاية").font(rnd(11, .heavy)).foregroundStyle(DR.tx3)
                    Avatar(name: store.name(g.home), color: store.tint(g.home), size: 26)
                    Text(store.name(g.home)).font(rnd(14, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                    Text("×").font(rnd(13, .bold)).foregroundStyle(DR.tx3)
                    Text(store.name(g.away)).font(rnd(14, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                    Avatar(name: store.name(g.away), color: store.tint(g.away), size: 26)
                    Spacer(minLength: 0)
                }
                .padding(10).background(DR.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text("\(t.playedCount) من \(t.playable.count) مباراة").font(rnd(12)).foregroundStyle(DR.tx3)
        }
        .padding(16).card(DR.s1, 24, stroke: DR.green.opacity(0.22))
    }
}

struct DoneRow: View {
    @EnvironmentObject var store: Store
    let t: Tournament
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill").font(.system(size: 18)).foregroundStyle(DR.gold).frame(width: 44, height: 44).background(DR.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name).font(rnd(16, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                Text(DR.formatName(t.format) + " · " + agoText(t.created)).font(rnd(12)).foregroundStyle(DR.tx3)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("البطل").font(rnd(10.5, .bold)).foregroundStyle(DR.tx3)
                Text(store.name(t.champion)).font(rnd(15, .black)).foregroundStyle(DR.gold)
            }
        }
        .padding(12).card(DR.s1, 18)
    }
}

// MARK: - مباراة ودّيّة سريعة
struct FriendlyView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var a: UUID? = nil
    @State private var b: UUID? = nil
    @State private var hg = 0
    @State private var ag = 0
    @State private var newName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("مباراة ودّيّة").font(rnd(26, .black)).foregroundStyle(Color.white)
                Text("اختار لاعبين وسجّل النتيجة — تنحسب بأرقامهم بلا بطولة.").font(rnd(13)).foregroundStyle(DR.tx3)
                MemberPicker(selected: Binding(get: { Set([a, b].compactMap { $0 }) }, set: { s in
                    let list = store.members.map { $0.id }.filter { s.contains($0) }
                    a = list.first; b = list.count > 1 ? list[1] : nil
                }), limit: 2)
                if let a, let b {
                    HStack(spacing: 14) {
                        ScoreSide(name: store.name(b), color: store.tint(b), value: $ag)
                        Text(":").font(rnd(40, .black)).foregroundStyle(DR.tx3)
                        ScoreSide(name: store.name(a), color: store.tint(a), value: $hg)
                    }.environment(\.layoutDirection, .leftToRight).padding(.vertical, 6)
                    BigButton(title: "احفظ النتيجة", icon: "checkmark") {
                        var t = Engine.make(name: "ودّيّة", format: .league, legs: 1, members: [a, b], shuffle: false)
                        t.friendly = true
                        if let g = t.games.first { Engine.setScore(&t, game: g.id, hg: hg, ag: ag) }
                        store.add(t); Haptic.ok(); dismiss()
                    }
                }
            }.padding(20)
        }.background(DR.bg.ignoresSafeArea())
    }
}

/// اختيار اللاعبين (مع إضافة اسم جديد)
struct MemberPicker: View {
    @EnvironmentObject var store: Store
    @Binding var selected: Set<UUID>
    var limit = 16
    @State private var newName = ""
    @FocusState private var focus: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(store.members) { m in
                    let on = selected.contains(m.id)
                    Button {
                        Haptic.tap()
                        if on { selected.remove(m.id) } else if selected.count < limit { selected.insert(m.id) }
                    } label: {
                        HStack(spacing: 7) {
                            Avatar(name: m.name, color: DR.color(m.color), size: 26)
                            Text(m.name).font(rnd(14, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                            Spacer(minLength: 0)
                            if on { Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(DR.green) }
                        }
                        .padding(.horizontal, 9).frame(height: 44)
                        .background(on ? DR.green.opacity(0.14) : DR.s2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(on ? DR.green.opacity(0.6) : Color.clear, lineWidth: 1.5))
                    }.buttonStyle(Press())
                }
            }
            HStack(spacing: 8) {
                TextField("", text: $newName, prompt: Text("اسم لاعب جديد").foregroundColor(DR.tx3)).font(rnd(15, .bold)).foregroundStyle(Color.white)
                    .focused($focus).submitLabel(.done).onSubmit(add)
                    .padding(.horizontal, 14).frame(height: 46).background(DR.s2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Button(action: add) {
                    Image(systemName: "plus").font(.system(size: 17, weight: .black)).foregroundStyle(DR.onGreen).frame(width: 46, height: 46).background(DR.green, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }.buttonStyle(Press()).opacity(newName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
        }
    }
    private func add() {
        let n = newName.trimmingCharacters(in: .whitespaces); guard !n.isEmpty else { return }
        let m = store.addMember(n); newName = ""
        if selected.count < limit { selected.insert(m.id) }
        Haptic.tap(); focus = true
    }
}

/// جهة وحدة بلوحة النتيجة: اسم + رقم كبير + أزرار زيادة ونقصان
struct ScoreSide: View {
    let name: String; let color: Color
    @Binding var value: Int
    var body: some View {
        VStack(spacing: 10) {
            Avatar(name: name, color: color, size: 46)
            Text(name).font(rnd(15, .heavy)).foregroundStyle(Color.white).lineLimit(1)
            Text("\(value)").font(rnd(72, .black)).foregroundStyle(Color.white).contentTransition(.numericText()).frame(height: 78)
            HStack(spacing: 10) {
                step("minus", DR.s3) { if value > 0 { value -= 1; Haptic.tap() } }
                step("plus", DR.green) { if value < 30 { value += 1; Haptic.thud() } }
            }
        }.frame(maxWidth: .infinity)
    }
    private func step(_ icon: String, _ c: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: icon).font(.system(size: 20, weight: .black)).foregroundStyle(c == DR.green ? DR.onGreen : Color.white).frame(width: 58, height: 52).background(c, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }.buttonStyle(Press())
    }
}
