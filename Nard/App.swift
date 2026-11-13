import SwiftUI

enum NT {
    static let bg = Color(red: 0.03, green: 0.055, blue: 0.05)
    static let s1 = Color(red: 0.07, green: 0.105, blue: 0.10)
    static let s2 = Color(red: 0.12, green: 0.175, blue: 0.16)
    static let felt = Color(red: 0.05, green: 0.30, blue: 0.24)
    static let feltDark = Color(red: 0.03, green: 0.20, blue: 0.165)
    static let wood = Color(red: 0.45, green: 0.27, blue: 0.14)
    static let woodDark = Color(red: 0.20, green: 0.11, blue: 0.055)
    static let triA = Color(red: 0.92, green: 0.76, blue: 0.46)
    static let triB = Color(red: 0.62, green: 0.21, blue: 0.16)
    static let gold = Color(red: 0.98, green: 0.80, blue: 0.38)
    static let ivory = Color(red: 0.97, green: 0.94, blue: 0.86)
    static let green = Color(red: 0.35, green: 0.95, blue: 0.6)
    static let cyan = Color(red: 0.3, green: 0.9, blue: 1)
    static let tx2 = Color(white: 1, opacity: 0.72), tx3 = Color(white: 1, opacity: 0.45)
    static let levels = ["سهل", "وسط", "صعب"]
    static let levelNotes = ["يغلط هواي — زين للتعلّم", "يلعب صحّ ويقفل الخانات", "يحسب ردّك على كلّ رمية"]
}

struct Launch: Identifiable {
    let id = UUID()
    let setup: Setup
    let saved: SavedGame?
}

@main
struct NardApp: App {
    @StateObject private var rec = Rec()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(rec)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(NT.gold)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            NT.bg
            RadialGradient(colors: [NT.felt.opacity(0.55), Color.clear], center: .top, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [NT.gold.opacity(0.10), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }
}

struct HomeView: View {
    @EnvironmentObject var rec: Rec
    @AppStorage("nd_level") private var level = 1
    @AppStorage("nd_target") private var target = 3
    @AppStorage("nd_seen_how") private var seenHow = false
    @State private var launch: Launch? = nil
    @State private var how = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let s = rec.saved { resume(s) }
                aiCard
                Button { launch = Launch(setup: Setup(level: -1, target: target), saved: nil) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.2.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(NT.cyan).frame(width: 52, height: 52).background(NT.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("لاعبين على نفس الآيفون").font(rnd(17, .heavy)).foregroundStyle(Color.white)
                            Text("حطّ الجهاز بينكم وكلّ واحد يلعب دوره").font(rnd(12.5)).foregroundStyle(NT.tx3)
                        }
                        Spacer()
                        Image(systemName: "chevron.left").font(.system(size: 13, weight: .black)).foregroundStyle(NT.tx3)
                    }.padding(14).card(NT.s1, 22)
                }.buttonStyle(Press())
                statsRow
                Text("يشتغل كامل بلا إنترنت · تقدّمك ينحفظ لحاله").font(rnd(11.5)).foregroundStyle(NT.tx3).frame(maxWidth: .infinity)
            }.padding(18)
        }
        .background(Backdrop())
        .fullScreenCover(item: $launch) { l in
            GameView(setup: l.setup, saved: l.saved, rec: rec) { launch = nil }
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $how, onDismiss: { seenHow = true }) { HowView { how = false }.environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
        .onAppear {
            if Shot.isAny("start", "game", "bear", "win", "hint") { launch = Launch(setup: Setup(level: 2, target: 3), saved: nil) }
            else if Shot.name == "two" { launch = Launch(setup: Setup(level: -1, target: 1), saved: nil) }
            else if Shot.name == "how" || (!seenHow && !Shot.on) { how = true }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("نرد").font(rnd(42, .black)).foregroundStyle(Color.white)
                Text("طاولة كاملة — ضدّ الجهاز أو ويّا صاحبك").font(rnd(13)).foregroundStyle(NT.tx3)
            }
            Spacer()
            HStack(spacing: -8) {
                DieView(face: 6, size: 44).rotationEffect(.degrees(-12))
                DieView(face: 5, size: 44).rotationEffect(.degrees(10)).offset(y: 8)
            }.padding(.leading, 6)
            Button { how = true } label: { Image(systemName: "questionmark").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white).frame(width: 42, height: 42).background(NT.s2, in: Circle()) }.buttonStyle(Press()).padding(.leading, 10)
        }
    }

    private func resume(_ s: SavedGame) -> some View {
        Button { launch = Launch(setup: s.setup, saved: s) } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("كمّل مباراتك").font(rnd(13, .heavy)).opacity(0.7)
                    Text(s.setup.level < 0 ? "لاعبين" : "ضدّ الجهاز · \(NT.levels[min(2, max(0, s.setup.level))])").font(rnd(21, .black))
                    HStack(spacing: 6) {
                        Text("النتيجة").font(rnd(12.5, .bold)).opacity(0.7)
                        Text("\(s.score[0]) – \(s.score[1])").font(rnd(14, .black)).environment(\.layoutDirection, .leftToRight)
                    }
                }
                Spacer()
                Image(systemName: "play.fill").font(.system(size: 22, weight: .black)).frame(width: 58, height: 58).background(Color.black.opacity(0.18), in: Circle())
            }
            .foregroundStyle(Color.black.opacity(0.82)).padding(16)
            .background(LinearGradient(colors: [NT.gold, Color(red: 0.93, green: 0.58, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: NT.gold.opacity(0.3), radius: 18, y: 8)
        }.buttonStyle(Press())
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: "cpu.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(NT.gold)
                Text("ضدّ الجهاز").font(rnd(19, .black)).foregroundStyle(Color.white)
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in chip(NT.levels[i], level == i) { level = i } }
            }
            Text(NT.levelNotes[min(2, max(0, level))]).font(rnd(12.5)).foregroundStyle(NT.tx2)
            Text("طول المباراة").font(rnd(12.5, .bold)).foregroundStyle(NT.tx3).padding(.top, 2)
            HStack(spacing: 8) {
                chip("جولة وحدة", target == 1) { target = 1 }
                chip("٣ نقاط", target == 3) { target = 3 }
                chip("٥ نقاط", target == 5) { target = 5 }
            }
            Button { launch = Launch(setup: Setup(level: min(2, max(0, level)), target: target), saved: nil) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 15, weight: .black))
                    Text("ابدي اللعب").font(rnd(18, .black))
                }.foregroundStyle(Color.black.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 56).background(NT.gold, in: Capsule())
            }.buttonStyle(Press()).padding(.top, 4)
        }.padding(16).card(NT.s1, 24, stroke: NT.gold.opacity(0.22))
    }

    private func chip(_ t: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); act() } label: {
            Text(t).font(rnd(14, .heavy)).foregroundStyle(on ? Color.black.opacity(0.82) : Color.white)
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(on ? NT.gold : NT.s2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }.buttonStyle(Press())
    }

    private var statsRow: some View {
        let st = rec.stats
        let pct = st.games > 0 ? Int((Double(st.wins) / Double(st.games) * 100).rounded()) : 0
        return HStack(spacing: 9) {
            stat("\(st.games)", "جولة", "flag.checkered", NT.cyan)
            stat("\(pct)%", "فوز", "trophy.fill", NT.gold)
            stat("\(st.gammons)", "مارس", "bolt.fill", NT.green)
            stat("\(st.best)", "أحسن سلسلة", "flame.fill", Color(red: 1, green: 0.5, blue: 0.3))
        }
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(c)
            Text(v).font(rnd(19, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.6).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(10.5)).foregroundStyle(NT.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }.padding(11).frame(maxWidth: .infinity, alignment: .leading).card(NT.s1, 16, stroke: c.opacity(0.22))
    }
}

struct HowView: View {
    let done: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("شلون ألعب نرد؟").font(rnd(28, .black)).foregroundStyle(Color.white).padding(.top, 22)
                rule("flag.checkered", NT.gold, "الهدف", "ودّي أحجارك الـ15 كلّها لبيتك (الربع الأيمن جوّه)، وبعدين طلّعها برّا اللوحة. أوّل واحد يطلّع كلّ أحجاره يفوز.")
                rule("dice.fill", Color.white, "الزار", "كلّ زار حركة لحجر. إذا طلع نفس الرقم مرّتين (دبل) تلعبه أربع مرّات.")
                rule("lock.fill", NT.cyan, "الخانة المقفولة", "الخانة اللي بيها حجرين أو أكثر للخصم ما تگدر تنزل عليها.")
                rule("bolt.fill", Color(red: 1, green: 0.45, blue: 0.4), "الضرب", "حجر الخصم إذا كان وحده بخانة تگدر تضربه: يروح للنصّ ولازم يدخل من جديد قبل أيّ حركة ثانية.")
                rule("trophy.fill", NT.green, "المارس", "إذا فزت والخصم بعده ما طلّع ولا حجر تاخذ نقطتين بدل نقطة.")
                rule("hand.tap.fill", NT.gold, "باللعبة", "اضغط الحجر اللي عليه حلقة ذهبيّة، وبعدين اضغط الدائرة الخضراء. تگدر ترجّع حركتك قبل ما تضغط «تمام»، والمصباح يقترح عليك أحسن حركة.")
                Button(action: done) { Text("يلّا نلعب").font(rnd(18, .black)).foregroundStyle(Color.black.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 56).background(NT.gold, in: Capsule()) }.buttonStyle(Press()).padding(.top, 6)
            }.padding(22)
        }.background(NT.bg.ignoresSafeArea())
    }
    private func rule(_ icon: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 20, weight: .black)).foregroundStyle(c).frame(width: 52, height: 52).background(NT.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white)
                Text(s).font(rnd(13.5)).foregroundStyle(NT.tx2).lineSpacing(3)
            }
        }
    }
}
