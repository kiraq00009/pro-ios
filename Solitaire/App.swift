import SwiftUI

// ───────────────────────── سوليتير — الهويّة واللون
enum ST {
    static let bg = Color(red: 0.02, green: 0.11, blue: 0.085)
    static let felt = Color(red: 0.045, green: 0.34, blue: 0.26)
    static let feltDark = Color(red: 0.02, green: 0.21, blue: 0.16)
    static let s1 = Color(red: 0.06, green: 0.15, blue: 0.125)
    static let s2 = Color(red: 0.10, green: 0.22, blue: 0.185)
    static let face = Color(red: 0.98, green: 0.97, blue: 0.93)
    static let faceDim = Color(red: 0.90, green: 0.89, blue: 0.83)
    static let back1 = Color(red: 0.98, green: 0.56, blue: 0.18)
    static let back2 = Color(red: 0.85, green: 0.32, blue: 0.07)
    static let ink = Color(red: 0.11, green: 0.14, blue: 0.16)
    static let red = Color(red: 0.84, green: 0.16, blue: 0.16)
    static let gold = Color(red: 0.99, green: 0.82, blue: 0.40)
    static let slot = Color(white: 1, opacity: 0.14)
    static let tx = Color.white
    static let tx2 = Color(white: 1, opacity: 0.74)
    static let tx3 = Color(white: 1, opacity: 0.46)
}

@main
struct SolitaireApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(ST.gold)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            ST.bg
            RadialGradient(colors: [ST.felt.opacity(0.55), .clear], center: .top, startRadius: 0, endRadius: 560)
            RadialGradient(colors: [ST.gold.opacity(0.08), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 440)
        }
        .ignoresSafeArea()
    }
}

struct HomeView: View {
    @StateObject private var rec = Rec()
    @AppStorage("sl_draw3") private var draw3 = false
    @AppStorage("sl_seen_how") private var seenHow = false
    @State private var play = false
    @State private var fresh = false
    @State private var how = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                header
                if rec.saved != nil { continueCard }
                newCard
                drawToggle
                statsRow
                Text("يشتغل كامل بلا إنترنت · تقدّمك ينحفظ لحاله").font(rnd(11.5)).foregroundStyle(ST.tx3).frame(maxWidth: .infinity).padding(.top, 2)
            }
            .padding(18)
        }
        .background(Backdrop())
        .fullScreenCover(isPresented: $play) {
            GameView(rec: rec, startFresh: fresh, draw3: draw3) { play = false }
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(ST.gold)
        }
        .sheet(isPresented: $how, onDismiss: { seenHow = true }) {
            HowView { how = false }
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            if Shot.isAny("game", "win") { fresh = false; play = true }
            else if Shot.name == "how" { how = true }
            else if Shot.name == "home" { /* البقاء على الرئيسيّة */ }
            else if !seenHow && !Shot.on { how = true }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("سوليتير").font(rnd(42, .black)).foregroundStyle(ST.tx)
                Text("لعبة الصبر الكلاسيكيّة").font(rnd(13)).foregroundStyle(ST.tx3)
            }
            Spacer()
            FanDecor()
            Button { how = true } label: {
                Image(systemName: "questionmark").font(.system(size: 15, weight: .black)).foregroundStyle(ST.tx).frame(width: 42, height: 42).background(ST.s2, in: Circle())
            }
            .buttonStyle(Press())
            .padding(.leading, 8)
        }
    }

    private var continueCard: some View {
        Button {
            fresh = false; play = true; Haptic.tap()
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("كمّل لعبتك").font(rnd(13, .heavy)).foregroundStyle(ST.tx2)
                    HStack(spacing: 12) {
                        pill("الوقت", timeStr(rec.saved?.elapsed ?? 0))
                        pill("الحركات", "\(rec.saved?.moves ?? 0)")
                        pill("النقاط", "\(rec.saved?.score ?? 0)")
                    }
                }
                Spacer()
                Image(systemName: "play.fill").font(.system(size: 22, weight: .black)).foregroundStyle(ST.ink).frame(width: 56, height: 56).background(ST.gold, in: Circle())
            }
            .padding(15)
            .card(ST.s1, 22)
        }
        .buttonStyle(Press())
    }

    private var newCard: some View {
        Button {
            fresh = true; play = true; Haptic.tap()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles").font(.system(size: 21, weight: .bold)).foregroundStyle(ST.gold).frame(width: 52, height: 52).background(ST.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("لعبة جديدة").font(rnd(19, .heavy)).foregroundStyle(ST.tx)
                    Text("توزيع جديد عشوائيّ").font(rnd(12.5)).foregroundStyle(ST.tx3)
                }
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .black)).foregroundStyle(ST.tx3)
            }
            .padding(14)
            .card(ST.s1, 22)
        }
        .buttonStyle(Press())
    }

    private var drawToggle: some View {
        HStack(spacing: 10) {
            drawBtn("اسحب وحدة", on: !draw3) { draw3 = false; Haptic.tap() }
            drawBtn("اسحب ٣", on: draw3) { draw3 = true; Haptic.tap() }
        }
    }

    private func drawBtn(_ t: String, on: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 4) {
                Text(t).font(rnd(15, .heavy)).foregroundStyle(on ? ST.ink : ST.tx)
                Text(on ? "مُفعّل" : "اضغط للتبديل").font(rnd(10.5, .bold)).foregroundStyle(on ? ST.ink.opacity(0.65) : ST.tx3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .card(on ? ST.gold : ST.s1, 18, stroke: on ? .clear : ST.slot)
        }
        .buttonStyle(Press())
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statBox("مرّات الفوز", "\(rec.wins)", "crown.fill")
            statBox("أفضل وقت", rec.best > 0 ? timeStr(rec.best) : "—", "stopwatch.fill")
        }
    }

    private func statBox(_ t: String, _ v: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(ST.gold)
            Text(v).font(rnd(22, .black)).foregroundStyle(ST.tx).environment(\.layoutDirection, .leftToRight)
            Text(t).font(rnd(11.5, .semibold)).foregroundStyle(ST.tx3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .card(ST.s1, 20)
    }

    private func pill(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(t).font(rnd(10, .bold)).foregroundStyle(ST.tx3)
            Text(v).font(rnd(16, .black)).foregroundStyle(ST.tx).environment(\.layoutDirection, .leftToRight)
        }
    }
}

/// مروحة ورق تزيينيّة أعلى الرئيسيّة
struct FanDecor: View {
    var body: some View {
        ZStack {
            miniBack(-16, -10)
            miniFace("K", "♠", false, 0, 0)
            miniFace("A", "♥", true, 16, -10)
        }
        .frame(width: 92, height: 72)
    }
    private func miniBack(_ deg: Double, _ dy: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(LinearGradient(colors: [ST.back1, ST.back2], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.35), lineWidth: 1.5))
            .frame(width: 44, height: 62).rotationEffect(.degrees(deg)).offset(y: dy)
    }
    private func miniFace(_ r: String, _ s: String, _ red: Bool, _ dx: CGFloat, _ dy: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(ST.face)
            .overlay(
                VStack(spacing: 0) {
                    Text(r).font(rnd(13, .black))
                    Text(s).font(rnd(15, .black))
                }.foregroundStyle(red ? ST.red : ST.ink).environment(\.layoutDirection, .leftToRight)
            )
            .frame(width: 44, height: 62).rotationEffect(.degrees(dx == 0 ? 0 : (dx > 0 ? 16 : -16))).offset(x: dx, y: dy)
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}

func timeStr(_ s: Int) -> String {
    String(format: "%d:%02d", s / 60, s % 60)
}

// ───────────────────────── كيف تلعب
struct HowView: View {
    var close: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("كيف تلعب").font(rnd(28, .black)).foregroundStyle(ST.tx)
                    Spacer()
                    Button { close() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(ST.tx).frame(width: 38, height: 38).background(ST.s2, in: Circle()) }.buttonStyle(Press())
                }
                step("1", "الهدف", "رتّب كلّ الورق بالأساسات الأربعة فوق — من الآس للملك، كلّ نوع لحاله (♠ ♥ ♦ ♣).")
                step("2", "الأعمدة", "بالأعمدة السبعة رتّب تنازليًّا وبتبديل اللون: ورقة حمرا على سودا وبالعكس. الفاضي يقبل الملك بس.")
                step("3", "المخزن", "انقر الكومة اليسار حتى تسحب ورق جديد للمرمى. لمّا تفرغ، انقرها تدور من جديد.")
                step("4", "النقل", "اسحب الورقة أو سلسلة كاملة لمكانها. وانقر الورقة نقرة حتى تطير للأساس إذا تنفع.")
                step("5", "تلميح وتراجع", "علّق؟ اضغط «تلميح». غلطت؟ «تراجع» يرجّعك خطوة خطوة.")
                Button { close() } label: {
                    Text("يلّا نلعب").font(rnd(17, .heavy)).foregroundStyle(ST.ink).frame(maxWidth: .infinity).padding(.vertical, 15).background(ST.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(Press()).padding(.top, 4)
            }
            .padding(20)
        }
        .background(Backdrop())
    }
    private func step(_ n: String, _ t: String, _ d: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(n).font(rnd(16, .black)).foregroundStyle(ST.ink).frame(width: 34, height: 34).background(ST.gold, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(t).font(rnd(16.5, .heavy)).foregroundStyle(ST.tx)
                Text(d).font(rnd(13.5)).foregroundStyle(ST.tx2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
