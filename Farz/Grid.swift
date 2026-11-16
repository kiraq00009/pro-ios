import SwiftUI
import UIKit

/// شاشة فئة: شبكة أو قائمة فيديوهات مع تحديد وحذف/تحويل
struct FZGridView: View {
    let cat: FZCat
    @EnvironmentObject var lib: FZLibrary
    @State private var selected: Set<String> = []
    @State private var preview: FZAsset? = nil
    @State private var sortBySize = false
    @State private var seeded = false

    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    init(cat: FZCat) {
        self.cat = cat
    }

    private var items: [FZAsset] {
        let m = lib.members(cat)
        if sortBySize && cat != .videos { return m.sorted { FZClassify.saving($0, cat) > FZClassify.saving($1, cat) } }
        return m
    }

    private var selectedBytes: Int64 {
        items.filter { selected.contains($0.id) }.reduce(Int64(0)) { $0 + FZClassify.saving($1, cat) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FZCatHeader(cat: cat, sum: lib.sum(cat))
                    if items.isEmpty {
                        FZEmpty(icon: "checkmark.seal.fill", title: "نظيف تمامًا", note: "ما لقينا شي بهذا القسم. ارجع بعد ما تصوّر أكثر أو غيّر الإعدادات.")
                    } else {
                        controls
                        if cat == .videos { videoList } else { grid }
                    }
                }
                .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 130)
            }
            if !selected.isEmpty { actionBar.transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected.isEmpty)
        .background(FZBackdrop())
        .navigationTitle(cat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FZ.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Haptic.tap(); lib.startDeck(cat) } label: {
                    Label("سحب", systemImage: "hand.draw.fill").labelStyle(.titleAndIcon).font(rnd(14, .heavy))
                }.disabled(items.isEmpty)
            }
        }
        .sheet(item: $preview) { a in
            FZPreview(asset: a, cat: cat).environmentObject(lib)
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
        .onAppear {
            if !seeded {
                seeded = true
                if Shot.on { selected = Set(items.prefix(cat == .videos ? 3 : 7).map { $0.id }) }
            }
        }
        .onChange(of: lib.assets.count) { _ in
            let ids = Set(lib.assets.map { $0.id })
            selected = selected.filter { ids.contains($0) }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                Haptic.tap()
                if selected.count == items.count { selected = [] } else { selected = Set(items.map { $0.id }) }
            } label: {
                Label(selected.count == items.count ? "ألغِ التحديد" : "حدّد الكلّ", systemImage: selected.count == items.count ? "circle" : "checkmark.circle.fill")
                    .font(rnd(13, .heavy)).foregroundStyle(Color.white)
                    .padding(.horizontal, 12).frame(height: 36).background(FZ.s2, in: Capsule())
            }.buttonStyle(Press())
            Spacer()
            if cat != .videos && cat != .similar {
                Button { Haptic.tap(); withAnimation { sortBySize.toggle() } } label: {
                    Label(sortBySize ? "الأكبر أوّلًا" : (cat == .blurry ? "الأشدّ تشويشًا" : "الأقدم أوّلًا"), systemImage: "arrow.up.arrow.down")
                        .font(rnd(13, .heavy)).foregroundStyle(FZ.color(cat))
                        .padding(.horizontal, 12).frame(height: 36).background(FZ.s2, in: Capsule())
                }.buttonStyle(Press())
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: cols, spacing: 4) {
            ForEach(items) { a in
                FZCell(asset: a, cat: cat, on: selected.contains(a.id))
                    .onTapGesture { toggle(a.id) }
                    .onLongPressGesture(minimumDuration: 0.35) { Haptic.thud(); preview = a }
            }
        }
    }

    private var videoList: some View {
        let maxB = Double(items.first?.bytes ?? 1)
        return LazyVStack(spacing: 10) {
            ForEach(items) { a in
                FZVideoRow(asset: a, on: selected.contains(a.id), fraction: maxB > 0 ? Double(a.bytes) / maxB : 0)
                    .onTapGesture { toggle(a.id) }
                    .onLongPressGesture(minimumDuration: 0.35) { Haptic.thud(); preview = a }
            }
        }
    }

    private func toggle(_ id: String) {
        Haptic.tap()
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private var actionBar: some View {
        let ids = Array(selected)
        return VStack(spacing: 10) {
            HStack {
                Text(FZFormat.items(selected.count) + " محدّدة").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                Spacer()
                HStack(spacing: 4) {
                    Text(cat == .live ? "توفير" : "ستوفّر").font(rnd(13, .bold)).foregroundStyle(FZ.tx2)
                    Text(FZFormat.size(selectedBytes)).font(rnd(15, .black)).foregroundStyle(FZ.mint)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: selectedBytes)
                }
            }
            if cat == .live {
                HStack(spacing: 10) {
                    FZPrimaryButton(title: "حوّلها لصور عاديّة", icon: "livephoto.slash", busy: lib.working) {
                        Task { if await lib.convertLive(ids) { selected = [] } }
                    }
                    Button {
                        Task { if await lib.delete(ids) { selected = [] } }
                    } label: {
                        Image(systemName: "trash.fill").font(.system(size: 18, weight: .black)).foregroundStyle(FZ.danger)
                            .frame(width: 56, height: 56).background(FZ.s2, in: Circle())
                    }.buttonStyle(Press()).disabled(lib.working)
                }
            } else {
                FZPrimaryButton(title: "احذف \(FZFormat.items(selected.count))", icon: "trash.fill", style: 1, busy: lib.working) {
                    Task { if await lib.delete(ids) { selected = [] } }
                }
            }
            Text("بيظهر لك تأكيد من النظام قبل أيّ حذف، والمحذوف يروح لـ«المحذوفة مؤخّرًا» 30 يوم.")
                .font(rnd(10.5)).foregroundStyle(FZ.tx3).multilineTextAlignment(.center)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.08)))
        .padding(.horizontal, 12).padding(.bottom, 8)
    }
}

struct FZCatHeader: View {
    let cat: FZCat
    let sum: FZClassify.Summary
    var body: some View {
        let c = FZ.color(cat)
        return HStack(alignment: .top, spacing: 14) {
            FZIconBadge(icon: cat.icon, color: c, size: 54)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    FZSizeText(bytes: sum.bytes, size: 28)
                    Text("· " + FZFormat.items(sum.count)).font(rnd(13, .bold)).foregroundStyle(c)
                }
                Text(cat.explain).font(rnd(13)).foregroundStyle(FZ.tx2).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .card(FZ.s1, 24, stroke: c.opacity(0.25))
    }
}

struct FZCell: View {
    let asset: FZAsset
    let cat: FZCat
    let on: Bool

    var body: some View {
        FZThumb(asset: asset, px: 260)
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .bottom) {
                HStack(spacing: 4) {
                    if asset.kind == .live { Image(systemName: "livephoto").font(.system(size: 10, weight: .bold)) }
                    if cat == .blurry, let s = asset.sharpness {
                        Text("حدّة \(Int(FZBlur.sharpnessScore(s) * 100))").font(rnd(10, .heavy))
                    } else {
                        Text(FZFormat.size(FZClassify.saving(asset, cat))).font(rnd(10, .heavy))
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 6).padding(.vertical, 5)
                .background(LinearGradient(colors: [Color.clear, Color.black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
            }
            .overlay(alignment: .topLeading) {
                ZStack {
                    Circle().fill(on ? FZ.mint : Color.black.opacity(0.3)).frame(width: 24, height: 24)
                    Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5).frame(width: 24, height: 24)
                    if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(Color.black) }
                }.padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(on ? FZ.mint : Color.clear, lineWidth: 2.5))
            .scaleEffect(on ? 0.93 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: on)
            .contentShape(Rectangle())
    }
}

struct FZVideoRow: View {
    let asset: FZAsset
    let on: Bool
    let fraction: Double

    var body: some View {
        HStack(spacing: 12) {
            FZThumb(asset: asset, px: 220)
                .frame(width: 92, height: 92)
                .overlay(alignment: .bottomLeading) {
                    Text(FZFormat.duration(asset.duration)).font(rnd(11, .heavy)).foregroundStyle(Color.white)
                        .padding(.horizontal, 6).padding(.vertical, 3).background(Color.black.opacity(0.55), in: Capsule()).padding(5)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .overlay { Image(systemName: "play.fill").font(.system(size: 20, weight: .black)).foregroundStyle(Color.white.opacity(0.85)) }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                FZSizeText(bytes: asset.bytes, size: 24)
                Text(asset.date.fzShort + " · " + resolution).font(rnd(12)).foregroundStyle(FZ.tx3)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(FZ.s2)
                        Capsule().fill(LinearGradient(colors: [FZ.coral, FZ.pink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, geo.size.width * fraction))
                    }
                }.frame(height: 6)
            }
            ZStack {
                Circle().fill(on ? FZ.mint : FZ.s2).frame(width: 28, height: 28)
                if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .black)).foregroundStyle(Color.black) }
            }
        }
        .padding(10)
        .card(on ? FZ.s2 : FZ.s1, 22, stroke: on ? FZ.mint.opacity(0.6) : Color.white.opacity(0.06))
        .contentShape(Rectangle())
        .animation(.spring(response: 0.25), value: on)
    }

    private var resolution: String {
        let s = min(asset.width, asset.height)
        if s >= 2160 { return "4K" }
        if s >= 1080 { return "1080p" }
        if s >= 720 { return "720p" }
        return "\(s)p"
    }
}

/// معاينة عنصر واحد بتفاصيله
struct FZPreview: View {
    let asset: FZAsset
    let cat: FZCat
    @EnvironmentObject var lib: FZLibrary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Capsule().fill(Color.white.opacity(0.25)).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.top, 10)
                FZThumb(asset: asset, px: 900)
                    .aspectRatio(CGFloat(max(1, asset.width)) / CGFloat(max(1, asset.height)), contentMode: .fit)
                    .frame(maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .frame(maxWidth: .infinity)
                reasons
                info
                FZPrimaryButton(title: cat == .live ? "حوّلها لصورة عاديّة" : "احذفها", icon: cat == .live ? "livephoto.slash" : "trash.fill", style: cat == .live ? 0 : 1, busy: lib.working) {
                    Task {
                        var ok = false
                        if cat == .live { ok = await lib.convertLive([asset.id]) } else { ok = await lib.delete([asset.id]) }
                        if ok { dismiss() }
                    }
                }
                FZPrimaryButton(title: "خلّيها", icon: "hand.thumbsup.fill", style: 2) { dismiss() }
            }.padding(18)
        }
        .background(FZ.bg.ignoresSafeArea())
    }

    private var reasons: some View {
        let cs = Array(FZClassify.cats(asset, rules: lib.rules, now: lib.now)).sorted { $0.rawValue < $1.rawValue }
        return HStack(spacing: 8) {
            ForEach(cs) { c in
                Label(c.short, systemImage: c.icon).font(rnd(12, .heavy)).foregroundStyle(FZ.color(c))
                    .padding(.horizontal, 10).frame(height: 30).background(FZ.color(c).opacity(0.14), in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private var info: some View {
        VStack(spacing: 0) {
            row("الحجم", FZFormat.size(asset.bytes))
            if asset.kind == .live { row("مقطع الصورة الحيّة", FZFormat.size(asset.pairedBytes)) }
            row("الأبعاد", "\(asset.width)×\(asset.height)")
            row("التاريخ", asset.date.fzShort)
            if asset.kind == .video { row("المدّة", FZFormat.duration(asset.duration)) }
            if let s = asset.sharpness { row("الحدّة", "\(Int(FZBlur.sharpnessScore(s) * 100)) من 100") }
            if asset.faces > 0 { row("وجوه", "\(asset.faces)") }
            if !asset.fileName.isEmpty { row("الملفّ", asset.fileName) }
        }
        .card(FZ.s1, 20)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(rnd(14)).foregroundStyle(FZ.tx3)
            Spacer()
            Text(v).font(rnd(14, .heavy)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16).frame(height: 46)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1) }
    }
}
