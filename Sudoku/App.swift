import SwiftUI

// ── لوحة الألوان: ثيم غامق، خلفيّة عميقة، لون واحد بارز (برتقاليّ دافئ).
enum SD {
    static let bg = Color(red: 0.045, green: 0.05, blue: 0.065)
    static let s1 = Color(red: 0.09, green: 0.10, blue: 0.125)
    static let s2 = Color(red: 0.14, green: 0.155, blue: 0.19)
    static let cell = Color(red: 0.11, green: 0.12, blue: 0.15)
    static let cellGiven = Color(red: 0.065, green: 0.075, blue: 0.095)
    static let accent = Color(red: 1.0, green: 0.56, blue: 0.20)
    static let accentDim = Color(red: 0.98, green: 0.47, blue: 0.16)
    static let sel = Color(red: 1.0, green: 0.56, blue: 0.20).opacity(0.28)
    static let peer = Color(white: 1, opacity: 0.055)
    static let same = Color(red: 1.0, green: 0.56, blue: 0.20).opacity(0.14)
    static let line = Color(white: 1, opacity: 0.16)
    static let lineThin = Color(white: 1, opacity: 0.07)
    static let good = Color(red: 0.35, green: 0.92, blue: 0.62)
    static let bad = Color(red: 1.0, green: 0.42, blue: 0.40)
    static let tx = Color.white
    static let tx2 = Color(white: 1, opacity: 0.72)
    static let tx3 = Color(white: 1, opacity: 0.44)

    static func fmt(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}

@main
struct SudokuApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(SD.accent)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            SD.bg
            RadialGradient(colors: [SD.accent.opacity(0.18), Color.clear], center: .top, startRadius: 0, endRadius: 480)
            RadialGradient(colors: [Color(red: 0.25, green: 0.3, blue: 0.9).opacity(0.14), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var launch: GameLaunch? = nil
    @State private var picking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let s = store.saved { resumeCard(s) }
                newGameButton
                bestTimes
                Text("يشتغل كامل بلا إنترنت · تقدّمك ينحفظ لحاله").font(rnd(11.5)).foregroundStyle(SD.tx3).frame(maxWidth: .infinity).padding(.top, 2)
            }
            .padding(18)
        }
        .background(Backdrop())
        .fullScreenCover(item: $launch) { l in
            GameView(difficulty: l.difficulty, saved: l.saved, store: store) { launch = nil }
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(SD.accent)
        }
        .sheet(isPresented: $picking) {
            DifficultySheet(store: store) { d in
                picking = false
                launch = GameLaunch(difficulty: d, saved: nil)
            }
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
            .tint(SD.accent)
        }
        .onAppear {
            if !Shot.on { return }
            if Shot.name == "pick" {
                picking = true
            } else if Shot.name == "win" {
                launch = GameLaunch(difficulty: .medium, saved: nil)
            } else if Shot.isAny("game", "notes") {
                launch = GameLaunch(difficulty: .medium, saved: nil)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("سودوكو").font(rnd(42, .black)).foregroundStyle(SD.tx)
                Text("لغز الأرقام الكلاسيكيّ — ركّز وحلّ").font(rnd(13)).foregroundStyle(SD.tx3)
            }
            Spacer()
            MiniGrid().frame(width: 62, height: 62)
        }
    }

    private func resumeCard(_ s: SavedSudoku) -> some View {
        Button {
            Haptic.tap()
            launch = GameLaunch(difficulty: s.diff, saved: s)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("كمّل لعبتك").font(rnd(13, .heavy)).foregroundStyle(Color.black.opacity(0.65))
                    Text(s.diff.title).font(rnd(23, .black)).foregroundStyle(Color.black.opacity(0.85))
                    HStack(spacing: 12) {
                        label("clock.fill", SD.fmt(s.seconds))
                        label("xmark.circle.fill", "\(s.mistakes) أخطاء")
                    }
                }
                Spacer()
                Image(systemName: "play.fill").font(.system(size: 22, weight: .black)).foregroundStyle(Color.black.opacity(0.8)).frame(width: 58, height: 58).background(Color.black.opacity(0.14), in: Circle())
            }
            .padding(16)
            .background(LinearGradient(colors: [SD.accent, SD.accentDim], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: SD.accent.opacity(0.32), radius: 18, y: 8)
        }
        .buttonStyle(Press())
    }

    private func label(_ icon: String, _ t: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(t).font(rnd(12.5, .bold)).environment(\.layoutDirection, .leftToRight)
        }
        .foregroundStyle(Color.black.opacity(0.62))
    }

    private var newGameButton: some View {
        Button {
            Haptic.tap()
            picking = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(SD.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("لعبة جديدة").font(rnd(18, .heavy)).foregroundStyle(SD.tx)
                    Text("اختار الصعوبة وابدي").font(rnd(12.5)).foregroundStyle(SD.tx3)
                }
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .black)).foregroundStyle(SD.tx3)
            }
            .padding(16)
            .card(SD.s1, 22, stroke: SD.accent.opacity(0.22))
        }
        .buttonStyle(Press())
    }

    private var bestTimes: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(SD.accent)
                Text("أحسن أوقاتك").font(rnd(17, .heavy)).foregroundStyle(SD.tx)
            }
            HStack(spacing: 9) {
                ForEach(Difficulty.allCases) { d in bestCell(d) }
            }
        }
    }

    private func bestCell(_ d: Difficulty) -> some View {
        let best = store.best[d.rawValue]
        return VStack(spacing: 5) {
            Text(d.title).font(rnd(12, .heavy)).foregroundStyle(SD.tx2).lineLimit(1).minimumScaleFactor(0.7)
            Text(best != nil ? SD.fmt(best!) : "—").font(rnd(17, .black)).foregroundStyle(best != nil ? SD.accent : SD.tx3).environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .card(SD.s1, 15, stroke: SD.lineThin)
    }
}

/// شعار مصغّر: شبكة ٣×٣ فيها أرقام بارزة.
struct MiniGrid: View {
    var body: some View {
        let d = [7, 0, 2, 0, 5, 0, 1, 0, 9]
        return VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { c in
                        let v = d[r * 3 + c]
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(v == 0 ? SD.s2 : SD.accent.opacity(0.9))
                            if v != 0 {
                                Text("\(v)").font(rnd(12, .black)).foregroundStyle(Color.black.opacity(0.8)).environment(\.layoutDirection, .leftToRight)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DifficultySheet: View {
    @ObservedObject var store: Store
    let pick: (Difficulty) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("اختار الصعوبة").font(rnd(28, .black)).foregroundStyle(SD.tx).padding(.top, 22)
                ForEach(Difficulty.allCases) { d in row(d) }
            }
            .padding(20)
        }
        .background(SD.bg.ignoresSafeArea())
        .presentationDetents([.large])
    }

    private func row(_ d: Difficulty) -> some View {
        let best = store.best[d.rawValue]
        return Button {
            Haptic.tap()
            pick(d)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SD.s2)
                    Text("\(d.givens)").font(rnd(20, .black)).foregroundStyle(SD.accent).environment(\.layoutDirection, .leftToRight)
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(d.title).font(rnd(19, .heavy)).foregroundStyle(SD.tx)
                    Text(d.note).font(rnd(12.5)).foregroundStyle(SD.tx3)
                    if let b = best {
                        Text("أحسن وقت " + SD.fmt(b)).font(rnd(11.5, .bold)).foregroundStyle(SD.accent.opacity(0.9)).environment(\.layoutDirection, .leftToRight)
                    }
                }
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .black)).foregroundStyle(SD.tx3)
            }
            .padding(14)
            .card(SD.s1, 20, stroke: SD.lineThin)
        }
        .buttonStyle(Press())
    }
}
