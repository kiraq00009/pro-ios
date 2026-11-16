import SwiftUI

struct WatchScreen: View {
    @EnvironmentObject var store: Store

    private let cols: [GridItem] = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "التنبيهات", sub: "اختار الأصوات المهمّة وأنبّهك أوّل ما أسمعها") {
                    Image(systemName: "bell.and.waves.left.and.right.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(SM.coral)
                        .frame(width: 46, height: 46).background(SM.coral.opacity(0.14), in: Circle())
                }
                GuardCard()
                SectionTitle(text: "الأصوات المحروسة", icon: "checkmark.shield.fill")
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(Watch.groups) { g in
                        WatchTile(group: g, on: store.watched.contains(g.id)) { store.toggleWatch(g.id) }
                    }
                }
                SensitivityCard()
                Button { store.testAlert() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill").font(.system(size: 15, weight: .bold))
                        Text("جرّب شكل التنبيه").font(rnd(15, .heavy))
                    }
                    .foregroundStyle(SM.coral).frame(maxWidth: .infinity).frame(height: 50)
                    .background(SM.coral.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(SM.coral.opacity(0.35)))
                }.buttonStyle(Press())
                RecentAlerts()
            }
            .padding(18)
        }
        .background(Backdrop(tint: SM.coral))
    }
}

struct GuardCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let n = store.watched.count
        HStack(spacing: 14) {
            ZStack {
                Circle().fill((store.running ? SM.sonar : SM.tx3).opacity(0.15)).frame(width: 54, height: 54)
                Image(systemName: store.running ? "shield.lefthalf.filled" : "shield.slash").font(.system(size: 22, weight: .bold))
                    .foregroundStyle(store.running ? SM.sonar : SM.tx3)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(store.running ? "الحراسة شغّالة" : "الحراسة متوقّفة").font(rnd(17, .heavy)).foregroundStyle(Color.white)
                Text(n == 0 ? "ما اخترت أيّ صوت بعد" : "أراقب \(n) أصوات · تهدئة \(cooldownText(store.cooldown))").font(rnd(12.5)).foregroundStyle(SM.tx3)
            }
            Spacer(minLength: 0)
            Button { store.toggle() } label: {
                Text(store.running ? "أوقف" : "شغّل").font(rnd(14, .black))
                    .foregroundStyle(store.running ? Color.white : Color.black.opacity(0.85))
                    .padding(.horizontal, 18).frame(height: 40)
                    .background(store.running ? SM.s3 : SM.sonar, in: Capsule())
            }.buttonStyle(Press())
        }
        .padding(14).card(SM.s1, 22, stroke: (store.running ? SM.sonar : SM.line).opacity(store.running ? 0.3 : 1))
    }
}

func cooldownText(_ s: Double) -> String {
    if s < 60 { return "\(Int(s)) ث" }
    let m = Int(s / 60)
    return m == 1 ? "دقيقة" : "\(m) د"
}

struct WatchTile: View {
    let group: WatchGroup
    let on: Bool
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(group.emoji).font(.system(size: 28))
                    Spacer()
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 20, weight: .bold))
                        .foregroundStyle(on ? SM.coral : SM.tx3)
                }
                Text(group.ar).font(rnd(15, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                Text(group.note).font(rnd(11.5)).foregroundStyle(SM.tx3).lineLimit(2).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
            }
            .padding(13)
            .background(on ? SM.coral.opacity(0.13) : SM.s1, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(on ? SM.coral.opacity(0.55) : SM.line, lineWidth: on ? 1.5 : 1))
            .shadow(color: on ? SM.coral.opacity(0.18) : Color.clear, radius: 10)
        }
        .buttonStyle(Press())
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: on)
    }
}

struct SensitivityCard: View {
    @EnvironmentObject var store: Store
    private let cools: [Double] = [10, 30, 60, 300]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "الحساسيّة", icon: "slider.horizontal.3")
            HStack {
                Text("أقلّ إنذارات كاذبة").font(rnd(11.5, .bold)).foregroundStyle(SM.tx3)
                Spacer()
                Text("يلقط أخفّ صوت").font(rnd(11.5, .bold)).foregroundStyle(SM.tx3)
            }
            Slider(value: $store.sensitivity, in: 0...1).tint(SM.coral)
            Text("أنبّهك إذا كنت متأكّد \(pct(Tuning.threshold(sensitivity: store.sensitivity))) أو أكثر، والصوت تكرّر مرّتين خلال ٣ ثواني.")
                .font(rnd(12.5)).foregroundStyle(SM.tx2)
            Divider().overlay(SM.line)
            Text("فترة التهدئة بعد كلّ تنبيه").font(rnd(13.5, .heavy)).foregroundStyle(Color.white)
            HStack(spacing: 8) {
                ForEach(cools, id: \.self) { c in
                    Chip(text: cooldownText(c), on: store.cooldown == c, color: SM.coral) { store.cooldown = c }
                }
            }
            Text("حتى ما يرجع ينبّهك على نفس الصوت كلّ ثانية.").font(rnd(11.5)).foregroundStyle(SM.tx3)
        }
        .padding(16).card(SM.s1, 22)
    }
}

struct RecentAlerts: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "آخر التنبيهات", icon: "clock.fill")
            if store.alerts.isEmpty {
                EmptyCard(emoji: "🔕", title: "ماكو تنبيهات بعد", note: "لمّا أسمع صوت من قائمتك راح يطلع هنا مع مقطع قصير تقدر تسمعه.")
            } else {
                VStack(spacing: 0) {
                    ForEach(store.alerts.prefix(12)) { a in
                        AlertRow(rec: a)
                        if a.id != store.alerts.prefix(12).last?.id { Divider().overlay(SM.line).padding(.leading, 60) }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4).card(SM.s1, 22)
            }
        }
    }
}

struct AlertRow: View {
    let rec: AlertRec
    var body: some View {
        let g = Watch.group(id: rec.group)
        HStack(spacing: 12) {
            Text(g?.emoji ?? Catalog.emoji(rec.sound)).font(.system(size: 22))
                .frame(width: 44, height: 44).background(SM.coral.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(g?.ar ?? Catalog.ar(rec.sound)).font(rnd(14.5, .heavy)).foregroundStyle(Color.white)
                Text("\(dayText(rec.t)) · \(clockText(rec.t)) · \(pct(rec.conf))").font(rnd(11.5)).foregroundStyle(SM.tx3)
            }
            Spacer()
            ClipButton(name: rec.clip, color: SM.coral)
        }
        .padding(.vertical, 9)
    }
}

/// زرّ تشغيل مقطع (يختفي إذا ماكو ملفّ)
struct ClipButton: View {
    let name: String?
    var color: Color = SM.sonar
    @EnvironmentObject var player: ClipPlayer
    var body: some View {
        if let n = name, ClipPlayer.exists(n) || Shot.on {
            let on = player.playing == n
            Button { player.toggle(n) } label: {
                ZStack {
                    Circle().fill(color.opacity(0.15))
                    if on {
                        Circle().trim(from: 0, to: CGFloat(player.progress)).stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    Image(systemName: on ? "stop.fill" : "play.fill").font(.system(size: 13, weight: .black)).foregroundStyle(color)
                }
                .frame(width: 38, height: 38)
            }.buttonStyle(Press())
        }
    }
}

// MARK: التنبيه بملء الشاشة

struct AlertOverlay: View {
    let alert: LiveAlert
    @EnvironmentObject var store: Store
    @EnvironmentObject var player: ClipPlayer
    @State private var flash = false
    @State private var pop = false
    @State private var clipReady = false

    var body: some View {
        let g = Watch.group(id: alert.group)
        let info = Catalog.info(alert.sound)
        ZStack {
            SM.bg.ignoresSafeArea()
            SM.coral.opacity(flash ? 0.55 : 0.12).ignoresSafeArea()
            RadialGradient(colors: [Color.white.opacity(flash ? 0.18 : 0.04), Color.clear], center: .center, startRadius: 0, endRadius: 380).ignoresSafeArea()
            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("تنبيه صوتي").font(rnd(14, .heavy))
                }
                .foregroundStyle(Color.white).padding(.horizontal, 14).frame(height: 34).background(Color.black.opacity(0.3), in: Capsule())
                .padding(.top, 30)
                Spacer()
                AlertRings(emoji: g?.emoji ?? info.emoji).scaleEffect(pop ? 1 : 0.6)
                Text(g?.ar ?? info.ar).font(rnd(42, .black)).foregroundStyle(Color.white).multilineTextAlignment(.center)
                Text("سمعت «\(info.ar)» · متأكّد \(pct(alert.conf))").font(rnd(15, .bold)).foregroundStyle(Color.white.opacity(0.85))
                Text(clockText(alert.t)).font(rnd(13, .bold)).foregroundStyle(Color.white.opacity(0.6))
                Spacer()
                if clipReady, let c = alert.clip {
                    Button { player.toggle(c) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: player.playing == c ? "stop.fill" : "play.fill")
                            Text(player.playing == c ? "إيقاف" : "اسمع اللي صار").font(rnd(16, .heavy))
                        }
                        .foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 54)
                        .background(Color.black.opacity(0.3), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3)))
                    }.buttonStyle(Press())
                }
                Button { player.stop(); store.dismissAlert() } label: {
                    Text("تمام، شفته").font(rnd(19, .black)).foregroundStyle(SM.coral)
                        .frame(maxWidth: .infinity).frame(height: 62)
                        .background(Color.white, in: Capsule())
                        .shadow(color: Color.black.opacity(0.3), radius: 16, y: 6)
                }.buttonStyle(Press())
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { flash = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = true }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_700_000_000)
            clipReady = ClipPlayer.exists(alert.clip)
        }
    }
}

struct AlertRings: View {
    let emoji: String
    var body: some View {
        TimelineView(.animation) { ctx in
            let t: Double = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p: Double = (t / 1.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Circle().stroke(Color.white.opacity(0.6 * (1 - p)), lineWidth: 3)
                        .frame(width: 150, height: 150).scaleEffect(CGFloat(0.7 + p * 1.1))
                }
                Circle().fill(Color.white.opacity(0.16)).frame(width: 150, height: 150)
                Text(emoji).font(.system(size: 84))
                    .scaleEffect(CGFloat(1 + 0.06 * sin(t * 9)))
            }
            .frame(width: 260, height: 260)
        }
    }
}
