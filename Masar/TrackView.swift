import SwiftUI
import UIKit

/// شاشة الجولة: خريطة كاملة + لوحة الأرقام الحيّة + أزرار البدء/الإيقاف
struct TrackView: View {
    @EnvironmentObject var store: MasarStore
    @EnvironmentObject var tracker: Tracker
    @State private var fitKey = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            map.ignoresSafeArea()
            LinearGradient(colors: [MT.bg.opacity(0.85), Color.clear], startPoint: .top, endPoint: .center)
                .frame(height: 220).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 10) {
                TrackTopBar()
                Spacer()
                if let f = tracker.flash {
                    FlashBanner(flash: f).id(f.id).transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if tracker.isActive { LivePanel() } else { IdlePanel() }
            }
            .padding(.horizontal, 14).padding(.bottom, 8)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: tracker.isActive)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: tracker.flash)
        }
        .onAppear {
            fitKey += 1
            tracker.warmUp()
        }
        .onDisappear { tracker.coolDown() }
        .onChange(of: tracker.isActive) { _ in fitKey += 1 }
        .onChange(of: tracker.flash) { f in
            guard let f = f, !Shot.on else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                if tracker.flash?.id == f.id { tracker.flash = nil }
            }
        }
        .alert("الموقع مغلق", isPresented: $tracker.denied) {
            Button("افتح الإعدادات") {
                if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
            }
            Button("لاحقًا", role: .cancel) {}
        } message: {
            Text("«مسار» يحتاج موقعك حتى يرسم طريقك ويحسب الخلايا اللي تاخذها. فعّله من الإعدادات ← الخصوصيّة ← الموقع.")
        }
        .alert("الجولة قصيرة جدًّا", isPresented: $tracker.tooShort) {
            Button("تمام", role: .cancel) {}
        } message: {
            Text("ما حفظناها لأنّ المسافة أقلّ من 50 م. في المرّة القادمة امشِ مسافة أطول!")
        }
    }

    private var map: some View {
        let live = tracker.isActive
        return MasarMap(
            routes: tracker.routes,
            hexes: live ? tracker.mapHexes : store.mapHexes,
            hexKey: live ? 1_000_000 + tracker.hexRev : store.revision,
            routeKey: tracker.routeRev,
            fitKey: fitKey,
            follow: !Shot.on && tracker.authorized,
            showsUser: !Shot.on && tracker.authorized,
            bottomPad: live ? 300 : 330,
            fitToRoute: live,
            fallback: (store.origin ?? Demo.center).cl
        )
    }
}

struct TrackTopBar: View {
    @EnvironmentObject var store: MasarStore
    @EnvironmentObject var tracker: Tracker

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("مسار").font(rnd(26, .black)).foregroundStyle(MT.brand)
                Text(tracker.isActive ? (tracker.state == .paused ? "موقّفة مؤقّتًا" : "الجولة شغّالة") : "مدينتك ساحة لعب")
                    .font(rnd(12, .bold)).foregroundStyle(MT.tx2)
            }
            Spacer()
            gps
            HStack(spacing: 5) {
                Image(systemName: "hexagon.fill").font(.system(size: 12, weight: .black)).foregroundStyle(MT.mint)
                Text(tracker.isActive ? "+\(tracker.newCells)" : "\(store.activeCells)").font(rnd(14, .black)).foregroundStyle(Color.white)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.horizontal, 11).frame(height: 34).background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.top, 4)
    }

    private var gps: some View {
        let a = tracker.gpsAcc
        let (txt, col): (String, Color) = {
            if Shot.on { return ("GPS قويّ", MT.mint) }
            if !tracker.authorized { return ("بلا موقع", MT.red) }
            if a < 0 { return ("يبحث…", MT.gold) }
            if a <= 10 { return ("GPS قويّ", MT.mint) }
            if a <= 25 { return ("GPS وسط", MT.gold) }
            return ("GPS ضعيف", MT.red)
        }()
        return HStack(spacing: 5) {
            Circle().fill(col).frame(width: 7, height: 7).shadow(color: col, radius: 4)
            Text(txt).font(rnd(12, .heavy)).foregroundStyle(Color.white)
        }
        .padding(.horizontal, 11).frame(height: 34).background(.ultraThinMaterial, in: Capsule())
    }
}

struct FlashBanner: View {
    let flash: Flash
    @State private var pop = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: flash.icon).font(.system(size: 20, weight: .black))
                .foregroundStyle(MT.ink).frame(width: 46, height: 46)
                .background(flash.gold ? MT.hot : MT.brand, in: Circle())
                .scaleEffect(pop ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 2) {
                Text(flash.title).font(rnd(18, .black)).foregroundStyle(Color.white)
                Text(flash.sub).font(rnd(13, .bold)).foregroundStyle(MT.tx2)
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke((flash.gold ? MT.gold : MT.mint).opacity(0.55), lineWidth: 1.2))
        .shadow(color: (flash.gold ? MT.gold : MT.mint).opacity(0.35), radius: 18)
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { pop = true } }
    }
}

struct IdlePanel: View {
    @EnvironmentObject var store: MasarStore
    @EnvironmentObject var tracker: Tracker
    @State private var glow = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(Activity.allCases) { a in chip(a) }
            }
            HStack(spacing: 10) {
                mini("\(Fmt.area(store.areaKm2))", "كم² منطقتك", "map.fill", MT.mint)
                mini("\(store.fadingSoon)", "تذبل قريبًا", "hourglass", MT.gold)
                mini(String(format: "%.1f", store.weekKm), "كم هذا الأسبوع", "calendar", MT.cyan)
            }
            Button { tracker.start(store) } label: {
                ZStack {
                    Circle().fill(MT.mint.opacity(0.18)).frame(width: 96, height: 96).scaleEffect(glow ? 1.18 : 0.96).opacity(glow ? 0.2 : 0.8)
                    Circle().fill(MT.brand).frame(width: 84, height: 84).shadow(color: MT.mint.opacity(0.6), radius: 18)
                    VStack(spacing: 0) {
                        Image(systemName: tracker.activity.icon).font(.system(size: 24, weight: .black))
                        Text("ابدأ").font(rnd(15, .black))
                    }.foregroundStyle(MT.ink)
                }
            }
            .buttonStyle(Press())
            .onAppear {
                guard !Shot.on else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
            }
            Text(store.sessions.isEmpty ? "امشِ أو اركض — كلّ خليّة تعبر بيها تصير إلك، ولو قفلت دائرة تاخذ كلّ ما بداخلها" : "ارجع للخلايا الذابلة قبل أن تضيع منك 👀")
                .font(rnd(12)).foregroundStyle(MT.tx3).multilineTextAlignment(.center)
        }
        .padding(16)
        .background(MT.bg.opacity(0.82), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.08)))
    }

    private func chip(_ a: Activity) -> some View {
        let on = tracker.activity == a
        return Button { Haptic.tap(); tracker.activity = a } label: {
            HStack(spacing: 6) {
                Image(systemName: a.icon).font(.system(size: 14, weight: .black))
                Text(a.title).font(rnd(14, .heavy))
            }
            .foregroundStyle(on ? MT.ink : Color.white)
            .frame(maxWidth: .infinity).frame(height: 42)
            .background(on ? AnyShapeStyle(MT.color(a)) : AnyShapeStyle(MT.s2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }.buttonStyle(Press())
    }

    private func mini(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .black)).foregroundStyle(c)
                Text(v).font(rnd(17, .black)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
            }
            Text(l).font(rnd(10.5)).foregroundStyle(MT.tx3).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity).padding(.vertical, 9).card(MT.s1, 14)
    }
}

struct LivePanel: View {
    @EnvironmentObject var store: MasarStore
    @EnvironmentObject var tracker: Tracker

    var body: some View {
        VStack(spacing: 14) {
            TimelineView(.periodic(from: Date(), by: 1)) { ctx in
                LiveNumbers(elapsed: tracker.elapsed(ctx.date))
            }
            controls
        }
        .padding(16)
        .background(MT.bg.opacity(0.86), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(MT.mint.opacity(tracker.state == .running ? 0.3 : 0.1)))
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 14) {
            if tracker.state == .running {
                round("pause.fill", "إيقاف مؤقّت", MT.s3, Color.white) { tracker.pause() }
                HoldStop { tracker.stop() }
            } else {
                round("play.fill", "كمّل", MT.mint, MT.ink) { tracker.resume() }
                HoldStop { tracker.stop() }
            }
        }
    }

    private func round(_ icon: String, _ label: String, _ bg: Color, _ fg: Color, _ act: @escaping () -> Void) -> some View {
        Button { act() } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 18, weight: .black))
                Text(label).font(rnd(16, .black))
            }
            .foregroundStyle(fg).frame(maxWidth: .infinity).frame(height: 58)
            .background(bg, in: Capsule())
        }.buttonStyle(Press())
    }
}

struct LiveNumbers: View {
    @EnvironmentObject var tracker: Tracker
    let elapsed: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.km(tracker.distance)).font(.system(size: 60, weight: .black, design: .rounded)).foregroundStyle(Color.white)
                    .monospacedDigit()
                Text("كم").font(rnd(18, .heavy)).foregroundStyle(MT.tx3)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Label(tracker.activity.title, systemImage: tracker.activity.icon).font(rnd(13, .heavy)).foregroundStyle(MT.color(tracker.activity))
                    if tracker.loops > 0 {
                        Text("\(tracker.loops) دائرة").font(rnd(12, .bold)).foregroundStyle(MT.gold)
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 8) {
                cell(Stats.durationText(elapsed), "الوقت", "timer")
                cell(Stats.paceText(tracker.pace), "دقيقة/كم", "speedometer")
                cell("+\(tracker.newCells)", "خليّة جديدة", "hexagon.fill")
                cell("\(Int(tracker.elevGain.rounded()))", "م صعود", "arrow.up.right")
            }
        }
    }

    private func cell(_ v: String, _ l: String, _ icon: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(rnd(18, .black)).foregroundStyle(Color.white).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9, weight: .black)).foregroundStyle(MT.mint)
                Text(l).font(rnd(10)).foregroundStyle(MT.tx3).lineLimit(1).minimumScaleFactor(0.7)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 9).card(MT.s1, 14)
    }
}

/// إنهاء بالضغط المطوّل حتى ما تنتهي الجولة بالغلط
struct HoldStop: View {
    let action: () -> Void
    @State private var holding = false
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Capsule().fill(MT.red.opacity(0.18))
            GeometryReader { g in
                Capsule().fill(MT.red).frame(width: max(58, g.size.width * progress))
            }
            HStack(spacing: 8) {
                Image(systemName: "stop.fill").font(.system(size: 17, weight: .black))
                Text(holding ? "استمرّ…" : "اضغط مطوّل للإنهاء").font(rnd(14, .black)).lineLimit(1).minimumScaleFactor(0.7)
            }.foregroundStyle(Color.white)
        }
        .frame(height: 58)
        .clipShape(Capsule())
        .onLongPressGesture(minimumDuration: 0.9, maximumDistance: 60, pressing: { p in
            holding = p
            if p {
                Haptic.tap()
                withAnimation(.linear(duration: 0.9)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }, perform: {
            progress = 0
            action()
        })
    }
}
