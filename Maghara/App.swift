import SwiftUI

enum MG {
    static let bg = Color(red: 0.035, green: 0.03, blue: 0.06)
    static let s1 = Color(red: 0.085, green: 0.075, blue: 0.13)
    static let s2 = Color(red: 0.14, green: 0.125, blue: 0.21)
    static let wall = Color(red: 0.16, green: 0.145, blue: 0.24)
    static let wallTop = Color(red: 0.27, green: 0.25, blue: 0.38)
    static let floorA = Color(red: 0.255, green: 0.215, blue: 0.20)
    static let floorB = Color(red: 0.225, green: 0.19, blue: 0.18)
    static let torch = Color(red: 1, green: 0.62, blue: 0.22)
    static let red = Color(red: 0.95, green: 0.3, blue: 0.33)
    static let green = Color(red: 0.4, green: 0.92, blue: 0.55)
    static let gold = Color(red: 1, green: 0.82, blue: 0.32)
    static let violet = Color(red: 0.62, green: 0.5, blue: 1)
    static let tx2 = Color(white: 1, opacity: 0.72), tx3 = Color(white: 1, opacity: 0.45)
    static let hero = "🥷"
}

struct Best: Codable {
    var runs = 0, wins = 0, floor = 0, score = 0, kills = 0
    var met: [Int] = []
}

struct Pop: Identifiable {
    let id: Int
    let at: Int
    let text: String
    let tone: Int
}

@MainActor
final class Run: ObservableObject {
    @Published var cave: Cave
    @Published var pops: [Pop] = []
    @Published var shake = 0
    @Published var best = Best()
    @Published var hasSaved = false
    @Published var newBest = false
    private let ud = UserDefaults.standard
    private var popId = 0, gen = 0, counted = false

    init() {
        if Shot.on {
            cave = Run.staged(Shot.name)
            best = Best(runs: 37, wins: 2, floor: 12, score: 2140, kills: 611, met: [0, 1, 2, 3, 4, 5, 7])
            hasSaved = true
            if cave.over { newBest = Shot.name == "win" }
            pops = cave.fx.enumerated().map { Pop(id: $0.offset, at: $0.element.at, text: $0.element.text, tone: $0.element.tone) }
            return
        }
        let u = UserDefaults.standard
        if let d = u.data(forKey: "mg_run"), let v = try? JSONDecoder().decode(Cave.self, from: d), !v.over {
            cave = v; hasSaved = true
        } else {
            cave = Cave(seed: 1)
        }
        if let d = u.data(forKey: "mg_best"), let v = try? JSONDecoder().decode(Best.self, from: d) { best = v }
    }

    static var dailySeed: UInt64 {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let y: Int = c.year ?? 2026
        let m: Int = c.month ?? 1
        let d: Int = c.day ?? 1
        let n: Int = y * 10000 + m * 100 + d
        return UInt64(n)
    }

    func start(seed: UInt64) {
        gen += 1
        cave = Cave(seed: seed)
        pops = []; newBest = false; counted = false; hasSaved = true
        persist()
    }

    @discardableResult private func perform(_ f: (inout Cave) -> Bool) -> Bool {
        let hp = cave.hero.hp, fl = cave.floor
        var c = cave
        let ok = f(&c)
        withAnimation(.easeOut(duration: 0.14)) { cave = c }
        guard ok else { return false }
        pops = c.fx.map { x in
            popId += 1
            return Pop(id: popId, at: x.at, text: x.text, tone: x.tone)
        }
        if c.hero.hp < hp { shake += 1; Haptic.thud() } else if c.floor != fl { Haptic.ok() } else { Haptic.tap() }
        if c.over { finish() }
        persist()
        return true
    }

    func tap(_ p: Int) {
        guard !cave.over, !cave.busy else { return }
        gen += 1
        if p == cave.hero.pos { perform { $0.rest() }; return }
        if let d = cave.near(cave.hero.pos).firstIndex(of: p) { perform { $0.act(d) }; return }
        guard p >= 0, p < cave.tiles.count, cave.seen[p], cave.tiles[p] != .wall else { return }
        let g = gen
        Task {
            while g == gen {
                guard let d = cave.step(toward: p) else { break }
                if !perform({ $0.act(d) }) { break }
                if cave.over || cave.busy || cave.hero.pos == p { break }
                if cave.mons.contains(where: { cave.lit[$0.pos] }) { break }
                try? await Task.sleep(nanoseconds: 95_000_000)
            }
        }
    }
    func swipe(_ d: Int) { gen += 1; perform { $0.act(d) } }
    func rest() { gen += 1; perform { $0.rest() } }
    func drink() { gen += 1; perform { $0.drink() } }
    func bomb() { gen += 1; perform { $0.bomb() } }
    func choose(_ k: Int) { Haptic.ok(); withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { cave.choose(k) }; persist() }
    func buy(_ i: Int) { if cave.buy(i) { Haptic.ok() } else { Haptic.bad() }; persist() }
    func pray() { if cave.pray() { Haptic.thud() } else { Haptic.bad() }; persist() }
    func leave() { withAnimation(.easeOut(duration: 0.15)) { cave.leave() } }
    func stop() { gen += 1 }

    private func finish() {
        guard !counted, !Shot.on else { return }
        counted = true
        best.runs += 1
        if cave.won { best.wins += 1 }
        newBest = cave.score > best.score
        best.score = max(best.score, cave.score)
        best.floor = max(best.floor, cave.floor)
        best.kills += cave.hero.kills
        hasSaved = false
        if cave.won { Haptic.ok() } else { Haptic.bad() }
    }

    private func persist() {
        guard !Shot.on else { return }
        best.met = Array(Set(best.met).union(cave.met)).sorted()
        if let d = try? JSONEncoder().encode(best) { ud.set(d, forKey: "mg_best") }
        if cave.over { ud.removeObject(forKey: "mg_run") }
        else if let d = try? JSONEncoder().encode(cave) { ud.set(d, forKey: "mg_run") }
    }

    private static func staged(_ n: String) -> Cave {
        var c = Cave(seed: 77)
        c.hero.perks[7] = 2
        switch n {
        case "play":
            c.jump(2); c.hero.gold = 31; c.hero.hp = 24
            c.rest(); c.rest(); c.rest()
        case "deep", "boss":
            c.hero.maxHp = 58; c.hero.hp = 41; c.hero.atk = 11; c.hero.def = 4; c.hero.level = 7; c.hero.gold = 96; c.hero.potions = 2; c.hero.bombs = 2
            c.hero.perks[1] = 1; c.hero.perks[3] = 1; c.hero.perks[4] = 2
            c.jump(n == "boss" ? 8 : 7)
            c.rest(); c.rest(); c.rest(); c.rest()
        case "perk":
            c.jump(3); c.rest(); c.hero.level = 3
            c.perks = [0, 4, 3]; c.owed = 1
        case "shop":
            c.jump(6); c.hero.gold = 148; c.hero.level = 5; c.hero.atk = 8; c.hero.def = 3
            c.rest(); c.atShop = true
        case "shrine":
            c.jump(5); c.hero.maxHp = 44; c.hero.hp = 39; c.rest(); c.atShrine = true
        case "dead":
            c.jump(5); c.rest(); c.hero.kills = 23; c.hero.gold = 77; c.hero.hp = 0; c.over = true
        case "win":
            c.hero.maxHp = 80; c.hero.atk = 17; c.hero.def = 6; c.hero.level = 11
            c.jump(12); c.hero.kills = 71; c.hero.gold = 263; c.hero.hp = 19; c.won = true; c.over = true
        default:
            c.jump(4); c.hero.hp = 22; c.hero.gold = 58
        }
        return c
    }
}

@main
struct MagharaApp: App {
    @StateObject private var run = Run()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(run)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(MG.torch)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            MG.bg
            RadialGradient(colors: [MG.torch.opacity(0.20), Color.clear], center: .top, startRadius: 0, endRadius: 480)
            RadialGradient(colors: [MG.violet.opacity(0.16), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 440)
        }.ignoresSafeArea()
    }
}

struct HomeView: View {
    @EnvironmentObject var run: Run
    @AppStorage("mg_seen_how") private var seenHow = false
    @State private var playing = false
    @State private var how = false
    @State private var book = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("مغارة").font(rnd(42, .black)).foregroundStyle(Color.white)
                        Text("١٢ طابق · وحوش · كنوز · موتة وحدة").font(rnd(13)).foregroundStyle(MG.tx3)
                    }
                    Spacer()
                    Button { how = true } label: { Image(systemName: "questionmark").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white).frame(width: 42, height: 42).background(MG.s2, in: Circle()) }.buttonStyle(Press())
                }
                art
                if run.hasSaved && !run.cave.over { resume }
                Button { run.start(seed: UInt64.random(in: 1...UInt64(Int.max))); playing = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill").font(.system(size: 16, weight: .black))
                        Text("مغامرة جديدة").font(rnd(18, .black))
                    }.foregroundStyle(Color.black.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 58)
                    .background(LinearGradient(colors: [MG.gold, MG.torch], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                    .shadow(color: MG.torch.opacity(0.35), radius: 16, y: 6)
                }.buttonStyle(Press())
                HStack(spacing: 10) {
                    small("مغارة اليوم", "نفس المغارة لكلّ الناس", "calendar", MG.violet) { run.start(seed: Run.dailySeed); playing = true }
                    small("كتاب الوحوش", "\(run.best.met.count) من \(Bestiary.all.count) شفتهم", "book.fill", MG.green) { book = true }
                }
                HStack(spacing: 9) {
                    stat("\(run.best.floor)", "أعمق طابق", "arrow.down.to.line", MG.torch)
                    stat("\(run.best.score)", "أعلى نقاط", "star.fill", MG.gold)
                    stat("\(run.best.wins)", "انتصار", "trophy.fill", MG.green)
                    stat("\(run.best.runs)", "مغامرة", "figure.walk", MG.violet)
                }
                Text("تشتغل كاملة بلا إنترنت · كلّ مغامرة مغارة جديدة").font(rnd(11.5)).foregroundStyle(MG.tx3).frame(maxWidth: .infinity)
            }.padding(18)
        }
        .background(Backdrop())
        .fullScreenCover(isPresented: $playing) {
            GameView { playing = false }.environmentObject(run).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $how, onDismiss: { seenHow = true }) { HowView { how = false }.environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .sheet(isPresented: $book) { BookView(met: Set(run.best.met)) { book = false }.environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .onAppear {
            if Shot.isAny("play", "deep", "boss", "perk", "shop", "shrine", "dead", "win") { playing = true }
            else if Shot.name == "book" { book = true }
            else if Shot.name == "how" || (!seenHow && !Shot.on) { how = true }
        }
    }

    private var art: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(LinearGradient(colors: [MG.s2, MG.s1], startPoint: .top, endPoint: .bottom))
            RadialGradient(colors: [MG.torch.opacity(0.45), Color.clear], center: .center, startRadius: 0, endRadius: 150)
            HStack(spacing: 14) {
                Text("🐉").font(.system(size: 58))
                Text("💀").font(.system(size: 34)).offset(y: 14)
                Text(MG.hero).font(.system(size: 62))
                Text("🦇").font(.system(size: 30)).offset(y: -22)
                Text("🎁").font(.system(size: 40)).offset(y: 12)
            }.environment(\.layoutDirection, .leftToRight)
        }
        .frame(height: 148)
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(MG.torch.opacity(0.25)))
    }

    private var resume: some View {
        Button { playing = true } label: {
            HStack(spacing: 14) {
                Text(MG.hero).font(.system(size: 34)).frame(width: 58, height: 58).background(MG.s2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("كمّل مغامرتك").font(rnd(13, .heavy)).foregroundStyle(MG.torch)
                    Text("الطابق \(run.cave.floor) من \(Cave.lastFloor)").font(rnd(20, .black)).foregroundStyle(Color.white)
                    Text("صحّة \(run.cave.hero.hp)/\(run.cave.hero.maxHp) · مستوى \(run.cave.hero.level) · ذهب \(run.cave.hero.gold)").font(rnd(12)).foregroundStyle(MG.tx3)
                }
                Spacer()
                Image(systemName: "play.fill").font(.system(size: 18, weight: .black)).foregroundStyle(MG.torch)
            }.padding(13).card(MG.s1, 22, stroke: MG.torch.opacity(0.45))
        }.buttonStyle(Press())
    }

    private func small(_ t: String, _ s: String, _ icon: String, _ c: Color, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(c)
                Text(t).font(rnd(16, .heavy)).foregroundStyle(Color.white)
                Text(s).font(rnd(11.5)).foregroundStyle(MG.tx3).lineLimit(1).minimumScaleFactor(0.8)
            }.padding(13).frame(maxWidth: .infinity, alignment: .leading).card(MG.s1, 20, stroke: c.opacity(0.3))
        }.buttonStyle(Press())
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(19, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.55).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(10.5)).foregroundStyle(MG.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }.padding(11).frame(maxWidth: .infinity, alignment: .leading).card(MG.s1, 16, stroke: c.opacity(0.22))
    }
}

struct BookView: View {
    let met: Set<Int>
    let done: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("كتاب الوحوش").font(rnd(26, .black)).foregroundStyle(Color.white)
                    Spacer()
                    Button(action: done) { Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(Color.white).frame(width: 38, height: 38).background(MG.s2, in: Circle()) }
                }.padding(.top, 20)
                ForEach(0..<Bestiary.all.count, id: \.self) { i in
                    row(i)
                }
            }.padding(20)
        }.background(MG.bg.ignoresSafeArea())
    }
    private func row(_ i: Int) -> some View {
        let k = Bestiary.all[i]
        let known = met.contains(i)
        return HStack(alignment: .top, spacing: 13) {
            Text(known ? k.glyph : "❔").font(.system(size: 30)).frame(width: 56, height: 56).background(MG.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(known ? k.name : "؟؟؟").font(rnd(16.5, .heavy)).foregroundStyle(Color.white)
                    if k.boss { Text("زعيم").font(rnd(10, .heavy)).foregroundStyle(Color.black.opacity(0.8)).padding(.horizontal, 7).padding(.vertical, 2).background(MG.red, in: Capsule()) }
                }
                Text(known ? k.note : "يظهر من الطابق \(k.minFloor) — بعدك ما شفته").font(rnd(12.5)).foregroundStyle(MG.tx2).lineSpacing(2)
                if known { Text("صحّة \(k.hp) · هجوم \(k.atk) · دفاع \(k.def) · من الطابق \(k.minFloor)").font(rnd(11)).foregroundStyle(MG.tx3) }
            }
            Spacer(minLength: 0)
        }.padding(11).card(MG.s1, 18)
    }
}

struct HowView: View {
    let done: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("شلون ألعب؟").font(rnd(28, .black)).foregroundStyle(Color.white).padding(.top, 22)
                rule("hand.tap.fill", MG.torch, "تحرّك", "اضغط أيّ خانة تشوفها وتمشي إلها لحالك، أو اسحب بإصبعك باتّجاه الحركة. كلّ خطوة دور — والوحوش تتحرّك وياك.")
                rule("bolt.fill", MG.red, "اضرب", "امشي باتّجاه الوحش حتى تضربه. خلّيهم يجونك واحد واحد بالممرّات الضيّقة ولا تخلّيهم يحاصرونك.")
                rule("cross.vial.fill", MG.green, "دوا وقنابل", "الدوا يرجّع نصّ صحّتك. القنبلة تضرب كلّ وحش قريب منك. الاثنين ياخذون دور.")
                rule("arrow.up.circle.fill", MG.violet, "ترقيات", "كلّ ما تقتل تاخذ خبرة، ومن ترتفع مستوى تختار ترقية من ثلاث. اختيارك يبني شخصيّتك.")
                rule("door.left.hand.open", MG.gold, "انزل", "دوّر على الباب وانزل للطابق الجاي. كلّ رابع طابق بيه زعيم لازم تقتله حتى ينفتح الباب.")
                rule("xmark.octagon.fill", Color.white, "موتة وحدة", "إذا متت ترجع من الأوّل بمغارة جديدة. هدفك توصل الطابق 12 وتغلب التنّين.")
                Button(action: done) { Text("ادخل المغارة").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 56).background(MG.torch, in: Capsule()) }.buttonStyle(Press()).padding(.top, 6)
            }.padding(22)
        }.background(MG.bg.ignoresSafeArea())
    }
    private func rule(_ icon: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 20, weight: .black)).foregroundStyle(c).frame(width: 52, height: 52).background(MG.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white)
                Text(s).font(rnd(13.5)).foregroundStyle(MG.tx2).lineSpacing(3)
            }
        }
    }
}
