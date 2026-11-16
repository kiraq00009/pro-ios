import SwiftUI

struct MeterScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var live: Live

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "الضجيج", sub: "كم عالي الصوت حولك، وكم تعرّضت اليوم") {
                    StatusPill(on: store.running, sleeping: store.sleep != nil)
                }
                GaugeCard(db: live.db, running: store.running)
                TrailCard(trail: live.trail)
                ExposureCard(e: live.exposure)
                ReferenceCard(db: store.running ? live.db : -1)
                if !store.running {
                    ListenButton()
                }
            }
            .padding(18)
        }
        .background(Backdrop(tint: SM.zone(Level.zone(live.db))))
    }
}

struct GaugeCard: View {
    let db: Double
    let running: Bool
    private let bounds: [Double] = [20, 40, 60, 75, 85, 110]

    var body: some View {
        let z = Level.zone(db)
        let g = running ? Level.gauge(db) : 0
        VStack(spacing: 6) {
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    let a = Level.gauge(bounds[i]), b = Level.gauge(bounds[i + 1])
                    Circle()
                        .trim(from: CGFloat(0.5 + a * 0.5) + 0.003, to: CGFloat(0.5 + b * 0.5) - 0.003)
                        .stroke(SM.zone(i).opacity(running && i == z ? 1 : 0.35), style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                        .frame(width: 250, height: 250)
                }
                Circle()
                    .trim(from: 0.5, to: CGFloat(0.5 + g * 0.5))
                    .stroke(SM.zone(z).opacity(0.25), style: StrokeStyle(lineWidth: 34, lineCap: .round))
                    .frame(width: 250, height: 250)
                    .blur(radius: 10)
                Capsule().fill(Color.white)
                    .frame(width: 4, height: 100)
                    .offset(y: -50)
                    .rotationEffect(.degrees(-90 + g * 180))
                    .shadow(color: SM.zone(z), radius: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: g)
                Circle().fill(Color.white).frame(width: 16, height: 16)
            }
            .frame(width: 250, height: 140, alignment: .top)
            .offset(y: 4)
            .clipped()
            .environment(\.layoutDirection, .leftToRight)
            Text(running ? "\(Int(db.rounded()))" : "—").font(rnd(58, .black)).foregroundStyle(Color.white).monospacedDigit()
            Text(running ? "ديسيبل · \(Level.zoneAr[z])" : "شغّل الاستماع حتى أقيس").font(rnd(15, .heavy)).foregroundStyle(running ? SM.zone(z) : SM.tx3)
            if running {
                Text(Level.zoneTip[z]).font(rnd(12.5)).foregroundStyle(SM.tx2).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18).padding(.horizontal, 14)
        .card(SM.s1, 26, stroke: SM.zone(z).opacity(running ? 0.3 : 0.08))
    }
}

struct TrailCard: View {
    let trail: [Double]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: "آخر ٣٠ ثانية", icon: "waveform.path.ecg")
                if let mx = trail.max() {
                    Text("أعلى \(Int(mx.rounded())) dB").font(rnd(12, .bold)).foregroundStyle(SM.tx3)
                }
            }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let pts: [CGPoint] = TrailCard.points(trail, w: w, h: h)
                ZStack {
                    ForEach([40.0, 60.0, 80.0], id: \.self) { lv in
                        let y = h - CGFloat((lv - 20) / 80) * h
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).position(x: w / 2, y: y)
                    }
                    if pts.count > 1 {
                        Path { p in
                            p.move(to: CGPoint(x: pts[0].x, y: h))
                            for q in pts { p.addLine(to: q) }
                            p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: h))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [SM.sonar.opacity(0.35), SM.sonar.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                        Path { p in
                            p.move(to: pts[0])
                            for q in pts.dropFirst() { p.addLine(to: q) }
                        }
                        .stroke(SM.sonar, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    } else {
                        Text("ماكو قراءات بعد").font(rnd(12.5)).foregroundStyle(SM.tx3).position(x: w / 2, y: h / 2)
                    }
                }
            }
            .frame(height: 110)
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16).card(SM.s1, 22)
    }

    static func points(_ t: [Double], w: CGFloat, h: CGFloat) -> [CGPoint] {
        let n = 150
        let data = Array(t.suffix(n))
        guard data.count > 1 else { return [] }
        let start = n - data.count
        var out: [CGPoint] = []
        out.reserveCapacity(data.count)
        for (i, v) in data.enumerated() {
            let x = CGFloat(start + i) / CGFloat(n - 1) * w
            let k = min(1, max(0, (v - 20) / 80))
            out.append(CGPoint(x: x, y: h - CGFloat(k) * h))
        }
        return out
    }
}

struct ExposureCard: View {
    let e: Exposure
    var body: some View {
        let p = e.percent
        let c: Color = p < 50 ? SM.sonar : (p < 100 ? SM.amber : SM.coral)
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "تعرّضك اليوم", icon: "ear.fill")
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(SM.s3, lineWidth: 11)
                    Circle().trim(from: 0, to: CGFloat(min(1, p / 100)))
                        .stroke(c, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(p < 1 && p > 0 ? "<1٪" : "\(Int(p.rounded()))٪").font(rnd(22, .black)).foregroundStyle(Color.white)
                        Text("من الحدّ").font(rnd(10, .bold)).foregroundStyle(SM.tx3)
                    }
                }
                .frame(width: 100, height: 100)
                VStack(alignment: .leading, spacing: 8) {
                    row("المتوسّط", e.seconds > 0 ? "\(Int(e.leq.rounded())) dB" : "—")
                    row("أعلى قراءة", e.seconds > 0 ? "\(Int(e.peak.rounded())) dB" : "—")
                    row("وقت القياس", Stats.durationText(e.seconds))
                    row("فوق ٧٥ dB", Stats.durationText(e.loudSeconds))
                }
            }
            Text(p < 100 ? "الحدّ الآمن يوميًّا ٨٥ dB لمدّة ٨ ساعات، وكلّ ٣ dB زيادة تنصّ المدّة." : "تجاوزت الحدّ اليوميّ الآمن — ريّح سمعك بمكان هادئ.")
                .font(rnd(12)).foregroundStyle(p < 100 ? SM.tx3 : SM.coral)
        }
        .padding(16).card(SM.s1, 22)
    }

    func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(rnd(12.5)).foregroundStyle(SM.tx3)
            Spacer()
            Text(v).font(rnd(13.5, .heavy)).foregroundStyle(Color.white)
        }
    }
}

struct ReferenceCard: View {
    let db: Double
    private let refs: [(String, String, Double)] = [
        ("🍃", "حفيف أوراق", 20), ("🤫", "همس", 30), ("🏠", "بيت هادئ", 40), ("🗣️", "كلام عادي", 60),
        ("🧹", "مكنسة كهربائية", 75), ("🚗", "شارع مزدحم", 85), ("🏍️", "دراجة نارية", 95), ("🎆", "ألعاب نارية وحفلات", 110),
    ]

    var body: some View {
        let near: Int = nearest()
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "شنو يعادل هذا الصوت؟", icon: "ruler.fill")
            ForEach(0..<refs.count, id: \.self) { i in
                let r = refs[i]
                HStack(spacing: 10) {
                    Text(r.0).font(.system(size: 18)).frame(width: 30)
                    Text(r.1).font(rnd(13.5, i == near ? .heavy : .regular)).foregroundStyle(i == near ? Color.white : SM.tx2)
                    Spacer()
                    if i == near {
                        Text("أنت هنا").font(rnd(11, .heavy)).foregroundStyle(Color.black.opacity(0.85))
                            .padding(.horizontal, 8).frame(height: 22).background(SM.zone(Level.zone(r.2)), in: Capsule())
                    }
                    Text("\(Int(r.2)) dB").font(rnd(13, .black)).foregroundStyle(SM.zone(Level.zone(r.2)))
                }
                .padding(.vertical, 4).padding(.horizontal, 8)
                .background(i == near ? SM.zone(Level.zone(r.2)).opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16).card(SM.s1, 22)
    }

    func nearest() -> Int {
        guard db >= 0 else { return -1 }
        var best = 0
        var bd = Double.greatestFiniteMagnitude
        for (i, r) in refs.enumerated() where abs(r.2 - db) < bd { bd = abs(r.2 - db); best = i }
        return best
    }
}
