import SwiftUI

struct SessionLaunch: Identifiable {
    let id = UUID()
    let def: ExerciseDef
}

struct TrainerView: View {
    @EnvironmentObject var store: DozanStore
    @EnvironmentObject var mic: MicPitch
    @EnvironmentObject var synth: ToneEngine
    @State private var launch: SessionLaunch? = nil
    @State private var showRange = false
    @State private var lockedHint: ExerciseDef? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header
                LevelCard()
                rangeCard
                dailyCard
                ForEach(ExerciseKind.allCases, id: \.rawValue) { k in
                    let defs = Exercises.all.filter { $0.kind == k }
                    if !defs.isEmpty { group(k, defs) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .fullScreenCover(item: $launch) { l in
            SessionView(def: l.def, root: Shot.on ? 55 : Exercises.root(for: l.def, low: store.profile.low, high: store.profile.high)) { launch = nil }
                .environmentObject(store)
                .environmentObject(mic)
                .environmentObject(synth)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $showRange) {
            RangeView { showRange = false }
                .environmentObject(store)
                .environmentObject(mic)
                .environmentObject(synth)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .alert(item: $lockedHint) { d in
            Alert(title: Text("مقفول 🔒"), message: Text("«\(d.title)» ينفتح بالمستوى \(d.unlockLevel). كمّل التمارين اللي قبله وتجمّع نقاط."), dismissButton: .default(Text("تمام")))
        }
        .onAppear {
            if Shot.name == "session", let d = Exercises.find("major") { launch = SessionLaunch(def: d) }
            if Shot.name == "range" { showRange = true }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("مدرّب الغناء").font(rnd(30, .black)).foregroundStyle(Color.white)
                Text("غنّي وشوف صوتك يرسم خطّ على اللحن").font(rnd(12.5)).foregroundStyle(DZ.tx3)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").foregroundStyle(store.practicedToday ? DZ.amber : DZ.tx3)
                Text("\(store.streak)").font(rnd(18, .black)).foregroundStyle(Color.white)
            }
            .padding(.horizontal, 12).frame(height: 38)
            .background(DZ.s2, in: Capsule())
        }
    }

    private var rangeCard: some View {
        Button { Haptic.tap(); showRange = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "waveform.and.mic").font(.system(size: 22, weight: .bold)).foregroundStyle(DZ.sky)
                    .frame(width: 54, height: 54).background(DZ.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    if let lo = store.profile.low, let hi = store.profile.high {
                        Text("مداك: \(NoteMath.name(lo)) ← \(NoteMath.name(hi))").font(rnd(16, .heavy)).foregroundStyle(Color.white)
                        Text("\(VoiceType.classify(low: lo, high: hi).title) · \(hi - lo) نصف درجة · التمارين تتلوّن على مداك").font(rnd(12)).foregroundStyle(DZ.tx3)
                    } else {
                        Text("اكتشف مداك الصوتي").font(rnd(16, .heavy)).foregroundStyle(Color.white)
                        Text("دقيقة وحدة: أوطى وأعلى نغمة تگدر تغنّيها").font(rnd(12)).foregroundStyle(DZ.tx3)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .black)).foregroundStyle(DZ.tx3)
            }
            .padding(14)
            .card(DZ.s1, 22, stroke: DZ.sky.opacity(0.25))
        }
        .buttonStyle(Press())
    }

    private var daily: ExerciseDef {
        let open = Exercises.all.filter { store.isUnlocked($0) }
        let pool = open.isEmpty ? Exercises.all : open
        let i = abs(store.today) % max(1, pool.count)
        return pool[i]
    }

    private var dailyCard: some View {
        let d = daily
        return Button { Haptic.tap(); launch = SessionLaunch(def: d) } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.practicedToday ? "تمرّنت اليوم ✓ — زيدها؟" : "تمرين اليوم").font(rnd(12.5, .heavy)).opacity(0.75)
                    Text(d.title).font(rnd(21, .black))
                    Text(d.detail).font(rnd(12.5, .semibold)).opacity(0.75)
                }
                Spacer()
                Image(systemName: "play.fill").font(.system(size: 22, weight: .black))
                    .frame(width: 58, height: 58).background(Color.black.opacity(0.18), in: Circle())
            }
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(16)
            .background(LinearGradient(colors: [DZ.mint, DZ.sky], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: DZ.mint.opacity(0.3), radius: 18, y: 8)
        }
        .buttonStyle(Press())
    }

    private func group(_ k: ExerciseKind, _ defs: [ExerciseDef]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: k.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(DZ.violet)
                Text(k.title).font(rnd(16, .black)).foregroundStyle(Color.white)
            }
            .padding(.top, 4)
            ForEach(defs) { d in
                ExerciseRow(def: d, unlocked: store.isUnlocked(d), best: store.profile.best[d.id], stars: store.profile.stars[d.id] ?? 0) {
                    if store.isUnlocked(d) { Haptic.tap(); launch = SessionLaunch(def: d) } else { Haptic.bad(); lockedHint = d }
                }
            }
        }
    }
}


struct ExerciseRow: View {
    let def: ExerciseDef
    let unlocked: Bool
    let best: Int?
    let stars: Int
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DZ.s2)
                    Image(systemName: unlocked ? def.kind.symbol : "lock.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(unlocked ? DZ.mint : DZ.tx3)
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(def.title).font(rnd(15.5, .heavy)).foregroundStyle(unlocked ? Color.white : DZ.tx3)
                    Text(unlocked ? def.detail : "ينفتح بالمستوى \(def.unlockLevel)").font(rnd(11.5)).foregroundStyle(DZ.tx3).lineLimit(1)
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle().fill(i < def.difficulty ? DZ.violet : DZ.s3).frame(width: 5, height: 5)
                        }
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    if let b = best {
                        Text("\(b)%").font(rnd(16, .black)).foregroundStyle(DZ.pitchColor(Double(100 - b) / 2, tol: 7)).environment(\.layoutDirection, .leftToRight)
                        StarsRow(count: stars, size: 10)
                    } else if unlocked {
                        Text("جديد").font(rnd(11, .heavy)).foregroundStyle(Color.black.opacity(0.8)).padding(.horizontal, 8).frame(height: 22).background(DZ.amber, in: Capsule())
                    }
                }
            }
            .padding(11)
            .card(DZ.s1, 18)
            .opacity(unlocked ? 1 : 0.7)
        }
        .buttonStyle(Press())
    }
}

struct LevelCard: View {
    @EnvironmentObject var store: DozanStore
    var body: some View {
        let lvl = store.level
        let prog = Leveling.progress(xp: store.profile.xp)
        let next = Leveling.xpNeeded(level: lvl + 1)
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(DZ.s2, lineWidth: 7)
                Circle().trim(from: 0, to: CGFloat(prog))
                    .stroke(DZ.grad, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text("\(lvl)").font(rnd(24, .black)).foregroundStyle(Color.white)
                    Text("مستوى").font(rnd(9.5, .bold)).foregroundStyle(DZ.tx3)
                }
            }
            .frame(width: 70, height: 70)
            VStack(alignment: .leading, spacing: 5) {
                Text(Leveling.title(lvl)).font(rnd(18, .black)).foregroundStyle(Color.white)
                Text("\(store.profile.xp) / \(next) نقطة").font(rnd(12.5, .bold)).foregroundStyle(DZ.tx2).environment(\.layoutDirection, .leftToRight)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DZ.s2)
                        Capsule().fill(DZ.grad).frame(width: max(8, g.size.width * CGFloat(prog)))
                    }
                }
                .frame(height: 8)
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(14)
        .card(DZ.s1, 22, stroke: DZ.violet.opacity(0.25))
    }
}
