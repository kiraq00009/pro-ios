import SwiftUI

struct RadarScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var live: Live
    @State private var settings = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ScreenHeader(title: "سَمَع", sub: store.running ? "أسمع اللي حولك الآن…" : "رادار الأصوات من حولك") {
                    HStack(spacing: 8) {
                        StatusPill(on: store.running, sleeping: store.sleep != nil)
                        Button { settings = true } label: {
                            Image(systemName: "gearshape.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.white)
                                .frame(width: 42, height: 42).background(SM.s2, in: Circle())
                        }.buttonStyle(Press())
                    }
                }
                if store.mic == .denied { MicDeniedCard() }
                if let p = store.problem { ProblemCard(text: p) }
                RadarDial(top: live.top, running: store.running, db: live.db)
                    .frame(height: 330)
                ListenButton()
                TopList(top: live.top, running: store.running)
                SessionStrip()
            }
            .padding(18)
        }
        .background(Backdrop())
        .sheet(isPresented: $settings) {
            SettingsSheet().environmentObject(store).environmentObject(live)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
    }
}

struct StatusPill: View {
    let on: Bool
    var sleeping: Bool = false
    @State private var blink = false
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(on ? (sleeping ? SM.violet : SM.sonar) : SM.tx3).frame(width: 8, height: 8)
                .opacity(on && blink ? 0.3 : 1)
            Text(on ? (sleeping ? "وضع النوم" : "يسمع") : "متوقّف").font(rnd(12, .heavy)).foregroundStyle(on ? Color.white : SM.tx3)
        }
        .padding(.horizontal, 12).frame(height: 32)
        .background(SM.s2, in: Capsule())
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { blink = true } }
    }
}

struct MicDeniedCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.slash.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(SM.coral)
                .frame(width: 46, height: 46).background(SM.coral.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("المايك مقفول").font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text("سَمَع يحتاج المايك حتى يتعرّف على الأصوات. كلّشي يصير على جهازك وما يطلع لأيّ مكان.").font(rnd(12)).foregroundStyle(SM.tx2)
            }
            Spacer(minLength: 0)
            Button {
                if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
            } label: {
                Text("الإعدادات").font(rnd(12.5, .heavy)).foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 12).frame(height: 34).background(SM.coral, in: Capsule())
            }.buttonStyle(Press())
        }
        .padding(14).card(SM.s1, 20, stroke: SM.coral.opacity(0.3))
    }
}

struct ProblemCard: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(SM.amber)
            Text(text).font(rnd(12.5)).foregroundStyle(SM.tx2)
            Spacer(minLength: 0)
        }.padding(12).card(SM.s1, 16, stroke: SM.amber.opacity(0.3))
    }
}

// MARK: الرادار

struct RadarDial: View {
    let top: [Hit]
    let running: Bool
    let db: Double

    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = min(geo.size.width, geo.size.height)
            ZStack {
                RadarGrid()
                if running { SweepLayer() }
                ForEach(Array(top.enumerated()), id: \.element.id) { pair in
                    Blip(hit: pair.element, rank: pair.offset)
                        .position(RadarDial.spot(pair.element, size: size))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
                CenterReadout(db: db, running: running)
            }
            .environment(\.layoutDirection, .leftToRight)
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// زاوية ثابتة لكلّ صوت، والأوثق أقرب للمركز
    static func spot(_ h: Hit, size: CGFloat) -> CGPoint {
        let r = Double(size) / 2
        let a = Catalog.angle(h.id) * Double.pi / 180
        let k = min(0.86, max(0.42, 0.95 - 0.5 * h.conf))
        let d = r * k
        return CGPoint(x: r + cos(a) * d, y: r + sin(a) * d)
    }
}

struct RadarGrid: View {
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [SM.sonarDeep.opacity(0.35), SM.s1.opacity(0.6), SM.bg.opacity(0.2)], center: .center, startRadius: 0, endRadius: 180))
            ForEach(1..<5, id: \.self) { i in
                Circle().stroke(SM.sonar.opacity(i == 4 ? 0.35 : 0.13), lineWidth: i == 4 ? 1.5 : 1)
                    .scaleEffect(CGFloat(i) / 4)
            }
            Rectangle().fill(SM.sonar.opacity(0.10)).frame(width: 1)
            Rectangle().fill(SM.sonar.opacity(0.10)).frame(height: 1)
            ForEach(0..<24, id: \.self) { i in
                Capsule().fill(SM.sonar.opacity(i % 6 == 0 ? 0.6 : 0.25)).frame(width: i % 6 == 0 ? 10 : 5, height: 1.5)
                    .offset(x: -1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .rotationEffect(.degrees(Double(i) * 15))
            }
        }
        .shadow(color: SM.sonar.opacity(0.18), radius: 24)
    }
}

struct SweepLayer: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t: Double = ctx.date.timeIntervalSinceReferenceDate
            let deg: Double = t.truncatingRemainder(dividingBy: 3.6) / 3.6 * 360
            let ph: Double = t.truncatingRemainder(dividingBy: 2.4) / 2.4
            ZStack {
                Circle()
                    .fill(AngularGradient(gradient: Gradient(stops: [
                        .init(color: SM.sonar.opacity(0), location: 0),
                        .init(color: SM.sonar.opacity(0), location: 0.72),
                        .init(color: SM.sonar.opacity(0.34), location: 0.995),
                        .init(color: SM.sonar.opacity(0), location: 1),
                    ]), center: .center, startAngle: .degrees(0), endAngle: .degrees(360)))
                    .rotationEffect(.degrees(deg))
                GeometryReader { g in
                    Capsule().fill(SM.sonar).frame(width: g.size.width / 2, height: 2)
                        .shadow(color: SM.sonar, radius: 6)
                        .position(x: g.size.width * 0.75, y: g.size.height / 2)
                }
                .rotationEffect(.degrees(deg))
                Circle().stroke(SM.sonar.opacity(0.5 * (1 - ph)), lineWidth: 2).scaleEffect(CGFloat(0.2 + ph * 0.8))
                Circle().stroke(SM.sonar.opacity(0.35 * (1 - ((ph + 0.5).truncatingRemainder(dividingBy: 1)))), lineWidth: 1.5)
                    .scaleEffect(CGFloat(0.2 + ((ph + 0.5).truncatingRemainder(dividingBy: 1)) * 0.8))
            }
        }
        .allowsHitTesting(false)
    }
}

struct Blip: View {
    let hit: Hit
    let rank: Int

    var d: CGFloat { CGFloat(30 + hit.conf * 26) }

    var body: some View {
        let info = Catalog.info(hit.id)
        let c = SM.color(hit.id)
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(c.opacity(0.30)).frame(width: d + 20, height: d + 20).blur(radius: 8)
                Circle().fill(SM.s2).frame(width: d, height: d)
                    .overlay(Circle().stroke(c, lineWidth: rank == 0 ? 2.5 : 1.5))
                Text(info.emoji).font(.system(size: d * 0.5))
            }
            Text(info.ar).font(rnd(11, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.black.opacity(0.55), in: Capsule())
        }
        .fixedSize()
    }
}

struct CenterReadout: View {
    let db: Double
    let running: Bool
    var body: some View {
        let z = Level.zone(db)
        VStack(spacing: 0) {
            if running {
                Text("\(Int(db.rounded()))").font(rnd(30, .black)).foregroundStyle(Color.white).monospacedDigit()
                Text("dB · \(Level.zoneAr[z])").font(rnd(10.5, .bold)).foregroundStyle(SM.zone(z))
            } else {
                Image(systemName: "ear").font(.system(size: 28, weight: .bold)).foregroundStyle(SM.tx3)
            }
        }
        .frame(width: 92, height: 92)
        .background(SM.bg.opacity(0.85), in: Circle())
        .overlay(Circle().stroke(running ? SM.zone(z).opacity(0.6) : SM.line, lineWidth: 2))
        .animation(.easeOut(duration: 0.2), value: Int(db.rounded()))
    }
}

struct ListenButton: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Button { store.toggle() } label: {
            HStack(spacing: 10) {
                Image(systemName: store.running ? "stop.fill" : "waveform").font(.system(size: 18, weight: .black))
                Text(store.running ? "أوقف الاستماع" : "ابدأ الاستماع").font(rnd(18, .black))
            }
            .foregroundStyle(store.running ? Color.white : Color.black.opacity(0.85))
            .frame(maxWidth: .infinity).frame(height: 58)
            .background(
                Group {
                    if store.running { Capsule().fill(SM.s2).overlay(Capsule().stroke(SM.coral.opacity(0.5), lineWidth: 1.5)) }
                    else { Capsule().fill(SM.grad) }
                }
            )
            .shadow(color: store.running ? Color.clear : SM.sonar.opacity(0.35), radius: 18, y: 6)
        }.buttonStyle(Press())
    }
}

struct TopList: View {
    let top: [Hit]
    let running: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "أقوى ٥ أصوات الآن", icon: "list.number")
            if !running {
                Text("شغّل الاستماع وخلّي الجهاز قريب. سَمَع يميّز مئات الأصوات: بكاء طفل، جرس الباب، إنذار دخان، نباح، هورن، ماء مفتوح وغيرها — وكلّه على جهازك بدون إنترنت.")
                    .font(rnd(13)).foregroundStyle(SM.tx2).lineSpacing(3)
            } else if top.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(SM.sonar)
                    Text("هدوء… أستنّى صوت واضح").font(rnd(13.5, .bold)).foregroundStyle(SM.tx2)
                }.padding(.vertical, 8)
            } else {
                ForEach(Array(top.enumerated()), id: \.element.id) { pair in
                    HitRow(hit: pair.element, rank: pair.offset + 1)
                }
            }
        }
        .padding(16).card(SM.s1, 22)
    }
}

struct HitRow: View {
    let hit: Hit
    let rank: Int
    var body: some View {
        let info = Catalog.info(hit.id)
        let c = SM.color(hit.id)
        HStack(spacing: 12) {
            Text("\(rank)").font(rnd(13, .black)).foregroundStyle(SM.tx3).frame(width: 16)
            Text(info.emoji).font(.system(size: 22)).frame(width: 44, height: 44).background(c.opacity(0.15), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(info.ar).font(rnd(15, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                    Spacer()
                    Text(pct(hit.conf)).font(rnd(13, .black)).foregroundStyle(c).monospacedDigit()
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(SM.s3)
                        Capsule().fill(LinearGradient(colors: [c.opacity(0.6), c], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, g.size.width * CGFloat(hit.conf)))
                    }
                }.frame(height: 6)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: hit.conf)
    }
}

struct SessionStrip: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let items: [Tally] = Tally.from(store.heard, limit: 10)
        if store.running && !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(text: "سمعته بهالجلسة", icon: "clock.arrow.circlepath")
                    if store.listenStart > 0 {
                        Text(Stats.durationText(max(0, nowT() - store.listenStart))).font(rnd(12, .bold)).foregroundStyle(SM.tx3)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { it in
                            HStack(spacing: 6) {
                                Text(Catalog.emoji(it.id))
                                Text(Catalog.ar(it.id)).font(rnd(12.5, .bold)).foregroundStyle(Color.white)
                                Text("×\(it.n)").font(rnd(12, .black)).foregroundStyle(SM.color(it.id))
                            }
                            .padding(.horizontal, 12).frame(height: 36).background(SM.s2, in: Capsule())
                        }
                    }
                }
            }
            .padding(16).card(SM.s1, 22)
        }
    }
}

struct Tally: Identifiable {
    let id: String
    let n: Int

    static func from(_ m: [String: Int], limit: Int) -> [Tally] {
        let all: [Tally] = m.map { Tally(id: $0.key, n: $0.value) }
        let sorted: [Tally] = all.sorted { a, b in a.n == b.n ? a.id < b.id : a.n > b.n }
        return Array(sorted.prefix(limit))
    }
}
