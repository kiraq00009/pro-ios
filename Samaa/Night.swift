import SwiftUI

struct SleepScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var live: Live
    @EnvironmentObject var player: ClipPlayer
    @State private var report: SleepSession? = nil
    @State private var nightMode = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "النوم", sub: "سجّل أصوات ليلتك: شخير، كحّة، كلام") {
                    Text("🌙").font(.system(size: 30)).frame(width: 46, height: 46).background(SM.moon.opacity(0.14), in: Circle())
                }
                if store.sleep != nil {
                    ActiveSleepCard { nightMode = true }
                } else {
                    StartSleepCard {
                        store.startSleep()
                        nightMode = true
                    }
                }
                if let last = store.nights.first {
                    Button { report = last } label: { LastNightCard(s: last) }.buttonStyle(Press())
                }
                if store.nights.count >= 2 { TrendCard(nights: Array(store.nights.prefix(7))) }
                if store.nights.count > 1 {
                    SectionTitle(text: "الليالي السابقة", icon: "moon.stars.fill")
                    VStack(spacing: 8) {
                        ForEach(store.nights.dropFirst().prefix(20)) { n in
                            Button { report = n } label: { NightRow(s: n) }.buttonStyle(Press())
                        }
                    }
                }
                SleepTips()
            }
            .padding(18)
        }
        .background(Backdrop(tint: SM.moon))
        .sheet(item: $report) { s in
            NightReport(session: s) { report = nil }
                .environmentObject(store).environmentObject(player)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $nightMode) {
            NightMode { s in
                nightMode = false
                if let s = s {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 650_000_000)
                        report = s
                    }
                }
            }
            .environmentObject(store).environmentObject(live)
            .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .onAppear {
            if Shot.name == "sleep", report == nil, let n = store.nights.first { report = n }
        }
    }
}

struct StartSleepCard: View {
    let go: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill").font(.system(size: 24, weight: .bold)).foregroundStyle(SM.moon)
                    .frame(width: 52, height: 52).background(SM.moon.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("وضع النوم").font(rnd(20, .black)).foregroundStyle(Color.white)
                    Text("حطّ الآيفون جنب السرير وموصول بالشاحن").font(rnd(12.5)).foregroundStyle(SM.tx3)
                }
            }
            Text("أسجّل كلّ شخير وكحّة وكلام بالليل مع وقته، وأحفظ مقطع ٦ ثواني حول كلّ حدث حتى تسمعه الصبح. بالأخير تطلعلك درجة هدوء الليلة ورسم كامل.")
                .font(rnd(13)).foregroundStyle(SM.tx2).lineSpacing(3)
            Button(action: go) {
                HStack(spacing: 8) {
                    Image(systemName: "bed.double.fill").font(.system(size: 16, weight: .black))
                    Text("ابدأ الليلة").font(rnd(18, .black))
                }
                .foregroundStyle(Color.black.opacity(0.85)).frame(maxWidth: .infinity).frame(height: 56)
                .background(LinearGradient(colors: [SM.moon, SM.violet], startPoint: .leading, endPoint: .trailing), in: Capsule())
                .shadow(color: SM.violet.opacity(0.4), radius: 16, y: 6)
            }.buttonStyle(Press())
        }
        .padding(16).card(SM.s1, 24, stroke: SM.moon.opacity(0.25))
    }
}

struct ActiveSleepCard: View {
    @EnvironmentObject var store: Store
    let open: () -> Void
    var body: some View {
        let s = store.sleep
        Button(action: open) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(SM.violet.opacity(0.2)).frame(width: 56, height: 56)
                    Image(systemName: "waveform").font(.system(size: 22, weight: .bold)).foregroundStyle(SM.violet)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("الليلة تتسجّل الآن").font(rnd(17, .heavy)).foregroundStyle(Color.white)
                    if let s = s {
                        Text("من \(clockText(s.start)) · \(s.events.count) حدث").font(rnd(12.5)).foregroundStyle(SM.tx3)
                    }
                }
                Spacer()
                Text("افتح").font(rnd(13, .black)).foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 16).frame(height: 36).background(SM.violet, in: Capsule())
            }
            .padding(14).card(SM.s1, 22, stroke: SM.violet.opacity(0.4))
        }.buttonStyle(Press())
    }
}

struct LastNightCard: View {
    let s: SleepSession
    var body: some View {
        let sum = SleepMath.summary(events: s.events, duration: s.duration, levels: s.levels.map { $0.db })
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("آخر ليلة").font(rnd(13, .heavy)).foregroundStyle(SM.tx3)
                Spacer()
                Text(dayText(s.start)).font(rnd(12, .bold)).foregroundStyle(SM.tx3)
            }
            HStack(spacing: 16) {
                ScoreRing(score: sum.score, size: 96)
                VStack(alignment: .leading, spacing: 6) {
                    Text(SleepMath.grade(sum.score)).font(rnd(19, .black)).foregroundStyle(Color.white)
                    Text("\(clockText(s.start)) ← \(clockText(s.end)) · \(Stats.durationText(s.duration))").font(rnd(12)).foregroundStyle(SM.tx3)
                    HStack(spacing: 6) {
                        MiniStat(k: .snore, text: Stats.durationText(sum.snoreSeconds))
                        MiniStat(k: .cough, text: "\(sum.coughs)")
                        MiniStat(k: .talk, text: "\(sum.talks)")
                    }
                }
                Spacer(minLength: 0)
            }
            HStack {
                Text("شوف التقرير الكامل").font(rnd(13, .heavy)).foregroundStyle(SM.moon)
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .black)).foregroundStyle(SM.moon)
            }
        }
        .padding(16).card(SM.s1, 24)
    }
}

struct MiniStat: View {
    let k: SleepKind
    let text: String
    var body: some View {
        HStack(spacing: 3) {
            Text(k.emoji).font(.system(size: 12))
            Text(text).font(rnd(11.5, .heavy)).foregroundStyle(SM.kind(k))
        }
        .padding(.horizontal, 8).frame(height: 26).background(SM.kind(k).opacity(0.13), in: Capsule())
    }
}

struct ScoreRing: View {
    let score: Int
    var size: CGFloat = 120
    var body: some View {
        let c: Color = score >= 85 ? SM.sonar : (score >= 70 ? SM.moon : (score >= 50 ? SM.amber : SM.coral))
        ZStack {
            Circle().stroke(SM.s3, lineWidth: size * 0.09)
            Circle().trim(from: 0, to: CGFloat(score) / 100)
                .stroke(AngularGradient(gradient: Gradient(colors: [c.opacity(0.5), c]), center: .center, startAngle: .degrees(0), endAngle: .degrees(360)), style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: c.opacity(0.5), radius: 8)
            VStack(spacing: 0) {
                Text("\(score)").font(rnd(size * 0.32, .black)).foregroundStyle(Color.white)
                Text("من ١٠٠").font(rnd(size * 0.1, .bold)).foregroundStyle(SM.tx3)
            }
        }
        .frame(width: size, height: size)
    }
}

struct TrendCard: View {
    let nights: [SleepSession]
    var body: some View {
        let ordered: [SleepSession] = nights.reversed()
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "درجة الهدوء — آخر الليالي", icon: "chart.line.uptrend.xyaxis")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(ordered) { n in
                    let sc = SleepMath.summary(events: n.events, duration: n.duration, levels: n.levels.map { $0.db }).score
                    VStack(spacing: 5) {
                        Text("\(sc)").font(rnd(11, .black)).foregroundStyle(Color.white)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(LinearGradient(colors: [SM.violet, SM.moon], startPoint: .bottom, endPoint: .top))
                            .frame(height: max(8, CGFloat(sc) * 0.9))
                        Text(shortDay(n.start)).font(rnd(10, .bold)).foregroundStyle(SM.tx3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130, alignment: .bottom)
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16).card(SM.s1, 22)
    }

    func shortDay(_ t: Double) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "EEE"
        return f.string(from: Date(timeIntervalSince1970: t))
    }
}

struct NightRow: View {
    let s: SleepSession
    var body: some View {
        let sum = SleepMath.summary(events: s.events, duration: s.duration, levels: s.levels.map { $0.db })
        HStack(spacing: 12) {
            ScoreRing(score: sum.score, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(dayText(s.start)).font(rnd(14.5, .heavy)).foregroundStyle(Color.white)
                Text("\(Stats.durationText(s.duration)) · \(SleepMath.grade(sum.score))").font(rnd(11.5)).foregroundStyle(SM.tx3)
            }
            Spacer()
            MiniStat(k: .snore, text: Stats.durationText(sum.snoreSeconds))
            Image(systemName: "chevron.left").font(.system(size: 11, weight: .black)).foregroundStyle(SM.tx3)
        }
        .padding(12).card(SM.s1, 18)
    }
}

struct SleepTips: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "حتى يطلع التسجيل أدقّ", icon: "lightbulb.fill")
            tip("🔌", "خلّي الآيفون على الشاحن — الاستماع طول الليل يحتاج بطارية")
            tip("📏", "حطّه على بعد متر تقريبًا من راسك، والمايك مو مغطّى")
            tip("🔕", "شغّل «عدم الإزعاج» حتى الإشعارات ما تنحسب أصوات")
            tip("🔒", "كلّ التسجيلات تبقى على جهازك فقط")
        }
        .padding(16).card(SM.s1, 22)
    }

    func tip(_ e: String, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(e).font(.system(size: 16))
            Text(t).font(rnd(12.5)).foregroundStyle(SM.tx2)
        }
    }
}

// MARK: شاشة الليل (معتمة)

struct NightMode: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var live: Live
    let done: (SleepSession?) -> Void
    @State private var confirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [SM.violet.opacity(0.14), Color.clear], center: .center, startRadius: 0, endRadius: 400).ignoresSafeArea()
            VStack(spacing: 22) {
                HStack {
                    Button { done(nil) } label: {
                        Image(systemName: "chevron.down").font(.system(size: 16, weight: .black)).foregroundStyle(SM.tx3)
                            .frame(width: 42, height: 42).background(Color.white.opacity(0.06), in: Circle())
                    }.buttonStyle(Press())
                    Spacer()
                    StatusPill(on: store.running, sleeping: true)
                }
                Spacer()
                TimelineView(.periodic(from: Date(), by: 1)) { ctx in
                    VStack(spacing: 8) {
                        Text(clockText(ctx.date.timeIntervalSince1970)).font(rnd(64, .black)).foregroundStyle(Color.white.opacity(0.85)).monospacedDigit()
                        if let s = store.sleep {
                            Text("صار \(Stats.durationText(max(0, ctx.date.timeIntervalSince1970 - s.start))) من بداية الليلة").font(rnd(14, .bold)).foregroundStyle(SM.tx3)
                        }
                    }
                }
                NightBreath(db: live.db)
                if let s = store.sleep { NightCounters(s: s) }
                Spacer()
                Text("تقدر تقفل الشاشة — أكمّل أسمع بالخلفيّة").font(rnd(12)).foregroundStyle(SM.tx3)
                Button { confirm = true } label: {
                    Text("صحيت! أوقف وشوف التقرير").font(rnd(17, .black)).foregroundStyle(Color.black.opacity(0.85))
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(LinearGradient(colors: [SM.amber, Color(red: 1, green: 0.55, blue: 0.35)], startPoint: .leading, endPoint: .trailing), in: Capsule())
                }.buttonStyle(Press())
            }
            .padding(22)
        }
        .confirmationDialog("ننهي تسجيل الليلة؟", isPresented: $confirm, titleVisibility: .visible) {
            Button("إي، أنهِ الليلة") { done(store.stopSleep()) }
            Button("لا، كمّل", role: .cancel) {}
        }
    }
}

struct NightBreath: View {
    let db: Double
    var body: some View {
        TimelineView(.animation) { ctx in
            let t: Double = ctx.date.timeIntervalSinceReferenceDate
            let b: Double = (sin(t * 2 * Double.pi / 5) + 1) / 2
            let lv: Double = Level.gauge(db)
            ZStack {
                Circle().fill(SM.violet.opacity(0.10 + 0.08 * b)).frame(width: 190, height: 190).scaleEffect(CGFloat(0.9 + 0.1 * b))
                Circle().stroke(SM.moon.opacity(0.35), lineWidth: 1.5).frame(width: 150, height: 150).scaleEffect(CGFloat(0.85 + lv * 0.4))
                VStack(spacing: 2) {
                    Text("\(Int(db.rounded()))").font(rnd(30, .black)).foregroundStyle(SM.moon)
                    Text("dB بالغرفة").font(rnd(11, .bold)).foregroundStyle(SM.tx3)
                }
            }
            .frame(height: 200)
        }
    }
}

struct NightCounters: View {
    let s: SleepSession
    var body: some View {
        let sum = SleepMath.summary(events: s.events, duration: max(60, s.duration), levels: [])
        HStack(spacing: 10) {
            counter(.snore, "\(sum.snoreCount)")
            counter(.cough, "\(sum.coughs)")
            counter(.talk, "\(sum.talks)")
            counter(.other, "\(sum.others)")
        }
    }

    func counter(_ k: SleepKind, _ v: String) -> some View {
        VStack(spacing: 4) {
            Text(k.emoji).font(.system(size: 18))
            Text(v).font(rnd(18, .black)).foregroundStyle(SM.kind(k))
            Text(k.ar).font(rnd(10, .bold)).foregroundStyle(SM.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: تقرير الليلة

struct NightReport: View {
    let session: SleepSession
    let close: () -> Void
    @EnvironmentObject var store: Store
    @EnvironmentObject var player: ClipPlayer
    @State private var kindFilter: SleepKind? = nil
    @State private var confirmDelete = false

    var body: some View {
        let s = session
        let sum = SleepMath.summary(events: s.events, duration: s.duration, levels: s.levels.map { $0.db })
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("تقرير الليلة").font(rnd(28, .black)).foregroundStyle(Color.white)
                        Text("\(dayText(s.start)) · \(clockText(s.start)) ← \(clockText(s.end))").font(rnd(12.5)).foregroundStyle(SM.tx3)
                    }
                    Spacer()
                    Button { player.stop(); close() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color.white)
                            .frame(width: 40, height: 40).background(SM.s2, in: Circle())
                    }.buttonStyle(Press())
                }
                HStack(spacing: 18) {
                    ScoreRing(score: sum.score, size: 124)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(SleepMath.grade(sum.score)).font(rnd(21, .black)).foregroundStyle(Color.white)
                        Text("مدّة التسجيل \(Stats.durationText(s.duration))").font(rnd(12.5, .bold)).foregroundStyle(SM.tx2)
                        Text("هدوء تامّ \(Int(sum.quietPct.rounded()))٪ من الوقت").font(rnd(12.5, .bold)).foregroundStyle(SM.sonar)
                        Text("متوسّط الغرفة \(Int(sum.leq.rounded())) dB").font(rnd(12.5, .bold)).foregroundStyle(SM.tx3)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16).card(SM.s1, 24)
                HStack(spacing: 8) {
                    KindTile(k: .snore, value: Stats.durationText(sum.snoreSeconds), sub: "\(sum.snoreCount) مرّة")
                    KindTile(k: .cough, value: "\(sum.coughs)", sub: "مرّة")
                    KindTile(k: .talk, value: "\(sum.talks)", sub: "مرّة")
                    KindTile(k: .other, value: "\(sum.others)", sub: "مرّة")
                }
                NightGraph(session: s)
                NightAdvice(sum: sum, hours: s.duration / 3600)
                eventsSection
                Button { confirmDelete = true } label: {
                    Text("احذف هالليلة").font(rnd(14, .heavy)).foregroundStyle(SM.coral).frame(maxWidth: .infinity).frame(height: 46)
                }.buttonStyle(Press())
            }
            .padding(18)
        }
        .background(Backdrop(tint: SM.moon))
        .confirmationDialog("نحذف الليلة ومقاطعها؟", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("احذف", role: .destructive) { player.stop(); store.deleteNight(session.id); close() }
            Button("لا", role: .cancel) {}
        }
    }

    private var eventsSection: some View {
        let list: [SoundEvent] = session.events
            .filter { !SleepMath.ignoreIds.contains($0.sound) }
            .filter { kindFilter == nil || SleepMath.kind($0.sound) == kindFilter }
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "أحداث الليلة (\(list.count))", icon: "waveform.path")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(text: "الكلّ", on: kindFilter == nil, color: SM.moon) { kindFilter = nil }
                    ForEach(SleepKind.allCases, id: \.rawValue) { k in
                        Chip(text: "\(k.emoji) \(k.ar)", on: kindFilter == k, color: SM.kind(k)) { kindFilter = k }
                    }
                }
            }
            if list.isEmpty {
                EmptyCard(emoji: "🤍", title: "ماكو شي هنا", note: "ليلة هادئة من هالنوع.")
            } else {
                VStack(spacing: 0) {
                    ForEach(list.prefix(80)) { e in
                        EventRow(e: e)
                        if e.id != list.prefix(80).last?.id { Divider().overlay(SM.line).padding(.leading, 56) }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4).card(SM.s1, 22)
            }
        }
    }
}

struct KindTile: View {
    let k: SleepKind
    let value: String
    let sub: String
    var body: some View {
        VStack(spacing: 4) {
            Text(k.emoji).font(.system(size: 18))
            Text(value).font(rnd(15, .black)).foregroundStyle(SM.kind(k)).lineLimit(1).minimumScaleFactor(0.6)
            Text(k.ar).font(rnd(10, .bold)).foregroundStyle(SM.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 11).card(SM.s1, 16)
    }
}

struct NightGraph: View {
    let session: SleepSession

    var body: some View {
        let s = session
        let dur = max(60, s.duration)
        let bin = max(120, dur / 72)
        let lv: [Double?] = Stats.bins(s.levels, start: s.start, end: s.start + dur, bin: bin)
        let evs: [SoundEvent] = s.events.filter { !SleepMath.ignoreIds.contains($0.sound) }
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "رسم الليلة", icon: "waveform.path.ecg")
            Canvas { ctx, size in
                NightGraph.draw(ctx: ctx, size: size, levels: lv, events: evs, start: s.start, dur: dur)
            }
            .frame(height: 190)
            .environment(\.layoutDirection, .leftToRight)
            HStack {
                Text(clockText(s.start)).font(rnd(10.5, .bold)).foregroundStyle(SM.tx3)
                Spacer()
                Text(clockText(s.start + dur / 2)).font(rnd(10.5, .bold)).foregroundStyle(SM.tx3)
                Spacer()
                Text(clockText(s.start + dur)).font(rnd(10.5, .bold)).foregroundStyle(SM.tx3)
            }
            .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 12) {
                ForEach(SleepKind.allCases, id: \.rawValue) { k in
                    HStack(spacing: 4) {
                        Circle().fill(SM.kind(k)).frame(width: 8, height: 8)
                        Text(k.ar).font(rnd(10.5, .bold)).foregroundStyle(SM.tx3)
                    }
                }
            }
        }
        .padding(16).card(SM.s1, 22)
    }

    static func draw(ctx: GraphicsContext, size: CGSize, levels: [Double?], events: [SoundEvent], start: Double, dur: Double) {
        let laneH: CGFloat = 9
        let lanesTop: CGFloat = size.height - laneH * 4 - 6
        let gh: CGFloat = lanesTop - 10
        let w: CGFloat = size.width
        let lo = 25.0, hi = 75.0

        // خطوط المستويات
        for db in [30.0, 45.0, 60.0] {
            let y = gh - CGFloat((db - lo) / (hi - lo)) * gh
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(p, with: .color(Color.white.opacity(0.06)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }

        // منحنى الضجيج
        let n = levels.count
        if n > 0 {
            var line = Path()
            var area = Path()
            var started = false
            var lastX: CGFloat = 0
            for i in 0..<n {
                guard let v = levels[i] else { continue }
                let x = n == 1 ? w / 2 : CGFloat(i) / CGFloat(n - 1) * w
                let k = min(1, max(0, (v - lo) / (hi - lo)))
                let y = gh - CGFloat(k) * gh
                if !started {
                    line.move(to: CGPoint(x: x, y: y))
                    area.move(to: CGPoint(x: x, y: gh))
                    area.addLine(to: CGPoint(x: x, y: y))
                    started = true
                } else {
                    line.addLine(to: CGPoint(x: x, y: y))
                    area.addLine(to: CGPoint(x: x, y: y))
                }
                lastX = x
            }
            if started {
                area.addLine(to: CGPoint(x: lastX, y: gh))
                area.closeSubpath()
                ctx.fill(area, with: .linearGradient(Gradient(colors: [SM.moon.opacity(0.45), SM.moon.opacity(0.02)]),
                                                     startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: gh)))
                ctx.stroke(line, with: .color(SM.moon), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }

        // مسارات الأحداث
        for (li, k) in SleepKind.allCases.enumerated() {
            let y = lanesTop + CGFloat(li) * laneH
            let bg = Path(roundedRect: CGRect(x: 0, y: y + 1, width: w, height: laneH - 3), cornerRadius: 3)
            ctx.fill(bg, with: .color(Color.white.opacity(0.04)))
            for e in events where SleepMath.kind(e.sound) == k {
                let x = CGFloat((e.start - start) / dur) * w
                let ew = max(3, CGFloat(e.duration / dur) * w)
                let r = Path(roundedRect: CGRect(x: x, y: y + 1, width: ew, height: laneH - 3), cornerRadius: 2)
                ctx.fill(r, with: .color(SM.kind(k)))
            }
        }
    }
}

struct NightAdvice: View {
    let sum: SleepSummary
    let hours: Double
    var body: some View {
        let lines = NightAdvice.advice(sum, hours: hours)
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "ملاحظات", icon: "sparkles")
            ForEach(lines, id: \.self) { l in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(SM.moon).frame(width: 6, height: 6).padding(.top, 7)
                    Text(l).font(rnd(13)).foregroundStyle(SM.tx2)
                }
            }
        }
        .padding(16).card(SM.s1, 22)
    }

    static func advice(_ s: SleepSummary, hours: Double) -> [String] {
        var out: [String] = []
        let h = max(0.5, hours)
        if s.snoreSeconds / (h * 3600) > 0.1 { out.append("الشخير أخذ أكثر من ١٠٪ من الليل. النوم على الجنب ومخدّة أعلى شوي ممكن يقلّلونه.") }
        else if s.snoreCount > 0 { out.append("شخير خفيف ومتقطّع — طبيعي عند أغلب الناس.") }
        if Double(s.coughs) / h > 2 { out.append("كحّة متكرّرة بالليل. جرّب ترطّب الغرفة وتشرب ماء قبل النوم، وإذا استمرّت راجع طبيب.") }
        if s.talks > 3 { out.append("انسمع كلام أو أصوات \(s.talks) مرّات — اسمع المقاطع، يمكن تتفاجأ 😄") }
        if s.loudMinutes > 10 { out.append("الغرفة كانت عالية (فوق ٥٥ dB) لمدّة \(s.loudMinutes) دقيقة. سدّادات الأذن أو صوت أبيض هادئ تساعد.") }
        if out.isEmpty { out.append("ليلة هادئة 👌 ماكو شي يستاهل القلق.") }
        return out
    }
}
