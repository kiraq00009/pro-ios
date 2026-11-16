import SwiftUI
import UIKit

/// مصغّرة صورة من المكتبة (حقيقيّة أو تجريبيّة)
struct FZThumb: View {
    let asset: FZAsset
    var px: CGFloat = 240
    @EnvironmentObject var lib: FZLibrary
    @State private var img: UIImage? = nil

    init(asset: FZAsset, px: CGFloat = 240) {
        self.asset = asset
        self.px = px
    }

    var body: some View {
        Rectangle().fill(FZ.s2)
            .overlay {
                if let img {
                    Image(uiImage: img).resizable().scaledToFill().transition(.opacity)
                } else {
                    Image(systemName: asset.kind == .video ? "video" : "photo").font(.system(size: 18, weight: .semibold)).foregroundStyle(FZ.tx3)
                }
            }
            .clipped()
            .task(id: asset.id) {
                if let c = FZThumbs.shared.cached(asset.id, px: px) { img = c; return }
                let r = await FZThumbs.shared.load(asset, px: px, demo: lib.demo)
                withAnimation(.easeOut(duration: 0.2)) { img = r }
            }
    }
}

struct FZHome: View {
    @EnvironmentObject var lib: FZLibrary
    @Binding var path: [FZRoute]
    @State private var settings = false

    init(path: Binding<[FZRoute]>) {
        _path = path
    }

    private let cols: [GridItem] = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                if lib.demo && !Shot.on { demoBanner }
                if lib.limited { limitedBanner }
                FZRingCard()
                quickButton
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(FZCat.allCases) { c in
                        Button { Haptic.tap(); path.append(.cat(c)) } label: { FZTile(cat: c, sum: lib.sum(c)) }
                            .buttonStyle(Press())
                    }
                }
                Button { Haptic.tap(); path.append(.stats) } label: { FZCleanedCard() }.buttonStyle(Press())
                footer
            }
            .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 34)
        }
        .background(FZBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $settings) {
            FZSettings().environmentObject(lib)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .refreshable { if !lib.isScanning { lib.startScan() } }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("فرز").font(rnd(40, .black)).foregroundStyle(FZ.brand)
                Text("نظّف مكتبة صورك ووفّر الغيغات").font(rnd(13.5)).foregroundStyle(FZ.tx3)
            }
            Spacer()
            Button { Haptic.tap(); lib.startScan() } label: {
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 16, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 44, height: 44).background(FZ.s2, in: Circle())
            }.buttonStyle(Press())
            Button { Haptic.tap(); settings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 16, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 44, height: 44).background(FZ.s2, in: Circle())
            }.buttonStyle(Press())
        }
    }

    private var demoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(FZ.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("مكتبة تجريبيّة").font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text("صور مولّدة للتجربة — ما نلمس صورك").font(rnd(12)).foregroundStyle(FZ.tx3)
            }
            Spacer()
            Button("صوري أنا") { lib.exitDemo() }.font(rnd(13, .black)).foregroundStyle(FZ.amber)
        }
        .padding(14).card(FZ.s1, 18, stroke: FZ.amber.opacity(0.3))
    }

    private var limitedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.rectangle.stack.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(FZ.sky)
            Text("صلاحيّة جزئيّة: نفحص الصور اللي اخترتها فقط. للفحص الكامل اسمح بكلّ الصور من الإعدادات.")
                .font(rnd(12.5)).foregroundStyle(FZ.tx2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
            } label: { Image(systemName: "gearshape.fill").foregroundStyle(FZ.sky) }
        }
        .padding(14).card(FZ.s1, 18, stroke: FZ.sky.opacity(0.3))
    }

    private var quickButton: some View {
        let q = lib.quick
        let bytes = q.reduce(Int64(0)) { $0 + $1.bytes }
        return Button { Haptic.thud(); lib.startQuickDeck() } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.18)).frame(width: 34, height: 44).rotationEffect(.degrees(-12)).offset(x: -6)
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.28)).frame(width: 34, height: 44).rotationEffect(.degrees(8)).offset(x: 6)
                    Image(systemName: "hand.draw.fill").font(.system(size: 18, weight: .black))
                }.frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text("مراجعة سريعة بالسحب").font(rnd(19, .black))
                    Text(q.isEmpty ? "ما في مرشّحات حاليًّا" : "\(FZFormat.items(q.count)) · حتى \(FZFormat.size(bytes))").font(rnd(13, .bold)).opacity(0.75)
                }
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .black))
            }
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(16)
            .background(FZ.brand, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: FZ.mint.opacity(0.35), radius: 18, y: 8)
        }.buttonStyle(Press())
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(lib.scanAgeText + " · " + FZFormat.thousands(lib.assets.count) + " عنصر بالمكتبة").font(rnd(12)).foregroundStyle(FZ.tx3)
            Text("كلّ التحليل يصير على جهازك. ما يطلع شي للإنترنت.").font(rnd(11.5)).foregroundStyle(FZ.tx3)
        }.frame(maxWidth: .infinity).padding(.top, 4)
    }
}

// MARK: - الحلقة الكبيرة

struct FZRingCard: View {
    @EnvironmentObject var lib: FZLibrary
    @State private var appear: Double = 0
    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ringBack
                ForEach(Array(arcs.enumerated()), id: \.offset) { i, arc in
                    FZArcShape(start: arc.start * appear, end: arc.end * appear)
                        .stroke(FZ.color(FZCat.allCases[i]), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                        .shadow(color: FZ.color(FZCat.allCases[i]).opacity(0.55), radius: 8)
                }
                sheen
                center
            }
            .frame(width: 252, height: 252)
            .padding(.top, 6)
            deviceBar
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .card(FZ.s1, 30, stroke: FZ.violet.opacity(0.22))
        .onAppear {
            withAnimation(.spring(response: 1.3, dampingFraction: 0.82).delay(0.1)) { appear = 1 }
            spin = true
            pulse = true
        }
    }

    private var arcs: [FZArc] {
        let vals: [Double] = FZCat.allCases.map { Double(lib.sum($0).bytes) }
        return FZRing.segments(vals, total: Double(max(lib.libraryBytes, 1)), gap: 0.018)
    }

    private var ringBack: some View {
        ZStack {
            Circle().stroke(FZ.s2, lineWidth: 22)
            Circle().stroke(FZ.violet.opacity(pulse ? 0.16 : 0.05), lineWidth: 46).blur(radius: 18)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulse)
        }
    }

    private var sheen: some View {
        Circle()
            .trim(from: 0, to: 0.09)
            .stroke(LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 214, height: 214)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 7).repeatForever(autoreverses: false), value: spin)
    }

    private var center: some View {
        VStack(spacing: 2) {
            Text("تقدر توفّر").font(rnd(14, .bold)).foregroundStyle(FZ.tx2)
            FZSizeText(bytes: lib.cleanable, size: 46, color: FZ.mint)
            Text("من مكتبة " + FZFormat.size(lib.libraryBytes)).font(rnd(12.5)).foregroundStyle(FZ.tx3)
        }
        .frame(width: 180)
    }

    private var deviceBar: some View {
        let d = lib.device
        let used = d.total > 0 ? Double(d.used) / Double(d.total) : 0
        let lib0 = d.total > 0 ? min(used, Double(lib.libraryBytes) / Double(d.total)) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("مساحة الجهاز", systemImage: "internaldrive.fill").font(rnd(13, .heavy)).foregroundStyle(Color.white)
                Spacer()
                Text(d.total > 0 ? "متاح \(FZFormat.size(d.free)) من \(FZFormat.size(d.total))" : "—").font(rnd(12, .bold)).foregroundStyle(FZ.tx2)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(FZ.s2)
                    Capsule().fill(FZ.s3).frame(width: geo.size.width * used * appear)
                    Capsule().fill(FZ.brand).frame(width: geo.size.width * lib0 * appear)
                }
            }
            .frame(height: 10)
            HStack(spacing: 14) {
                legend(FZ.brand, "الصور والفيديو")
                legend(FZ.s3, "تطبيقات وغيرها")
                Spacer()
            }
        }
    }

    private func legend<S: ShapeStyle>(_ s: S, _ t: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(s).frame(width: 8, height: 8)
            Text(t).font(rnd(11)).foregroundStyle(FZ.tx3)
        }
    }
}

/// قوس من الحلقة يبدأ من الأعلى ويدور مع عقارب الساعة (0…1)
struct FZArcShape: Shape {
    var start: Double
    var end: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, end) }
        set { start = newValue.first; end = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard end > start + 0.0005 else { return p }
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.addArc(center: c, radius: r, startAngle: .degrees(-90 + start * 360), endAngle: .degrees(-90 + end * 360), clockwise: false)
        return p
    }
}

// MARK: - بلاطات الفئات

struct FZTile: View {
    let cat: FZCat
    let sum: FZClassify.Summary

    var body: some View {
        let c = FZ.color(cat)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                FZIconBadge(icon: cat.icon, color: c, size: 40)
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .black)).foregroundStyle(FZ.tx3)
            }
            Text(cat.title).font(rnd(14.5, .heavy)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.75)
            FZSizeText(bytes: sum.bytes, size: 25, color: sum.count > 0 ? Color.white : FZ.tx3)
            Text(sum.count > 0 ? FZFormat.items(sum.count) : "نظيف").font(rnd(12, .bold)).foregroundStyle(sum.count > 0 ? c : FZ.green)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                FZ.s1
                RadialGradient(colors: [c.opacity(0.22), Color.clear], center: .topLeading, startRadius: 0, endRadius: 140)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(c.opacity(0.22)))
    }
}

// MARK: - ما نظّفته لحدّ الآن

struct FZCleanedCard: View {
    @EnvironmentObject var lib: FZLibrary

    var body: some View {
        let l = lib.ledger
        let streak = l.liveStreak(today: lib.today)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("نظّفت لحدّ الآن").font(rnd(13, .bold)).foregroundStyle(FZ.tx3)
                    FZSizeText(bytes: l.freed, size: 32)
                    Text(FZFormat.items(l.items) + " · " + FZLevel.name(l.freed)).font(rnd(12.5, .bold)).foregroundStyle(FZ.violet)
                }
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill").font(.system(size: 26, weight: .black))
                        .foregroundStyle(streak > 0 ? AnyShapeStyle(FZ.hot) : AnyShapeStyle(FZ.tx3))
                    Text("\(streak)").font(rnd(22, .black)).foregroundStyle(Color.white)
                    Text("أيّام متتالية").font(rnd(10.5)).foregroundStyle(FZ.tx3)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(FZ.s2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(FZ.s2)
                        Capsule().fill(LinearGradient(colors: [FZ.violet, FZ.pink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * FZLevel.progress(l.freed)))
                    }
                }.frame(height: 8)
                Text(FZLevel.remaining(l.freed) > 0 ? "باقي \(FZFormat.size(FZLevel.remaining(l.freed))) للمستوى الجاي" : "وصلت أعلى مستوى!")
                    .font(rnd(11.5)).foregroundStyle(FZ.tx3)
            }
        }
        .padding(16)
        .card(FZ.s1, 24, stroke: FZ.pink.opacity(0.2))
    }
}
