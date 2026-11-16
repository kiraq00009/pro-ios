import SwiftUI
import UIKit

struct FZGroupBox: Identifiable {
    let items: [FZAsset]
    var id: String { items.first?.id ?? UUID().uuidString }
}

/// المجموعات المتشابهة: أفضل لقطة تبقى، والباقي محدّد للحذف (المستخدم يقدر يغيّر)
struct FZSimilarView: View {
    @EnvironmentObject var lib: FZLibrary
    @State private var marked: Set<String> = []
    @State private var bestPick: [String: String] = [:]   // مفتاح المجموعة → المعرّف المختار كأفضل
    @State private var seeded = false

    private var boxes: [FZGroupBox] { lib.groups.map { FZGroupBox(items: $0) } }

    private var markedBytes: Int64 {
        lib.groups.joined().filter { marked.contains($0.id) }.reduce(Int64(0)) { $0 + $1.bytes }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    FZCatHeader(cat: .similar, sum: lib.sum(.similar))
                    if boxes.isEmpty {
                        FZEmpty(icon: "square.on.square", title: "ما في تكرار", note: "ما لقينا لقطات متشابهة. لو غيّرت دقّة التشابه من الإعدادات أعد الفحص.")
                    } else {
                        toolbarRow
                        ForEach(boxes) { b in
                            FZGroupCard(box: b, best: bestID(b), marked: $marked) { newBest in
                                choose(newBest, in: b)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 140)
            }
            if !marked.isEmpty { actionBar.transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: marked.isEmpty)
        .background(FZBackdrop())
        .navigationTitle("صور متشابهة")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FZ.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Haptic.tap(); lib.startDeck(.similar) } label: {
                    Label("سحب", systemImage: "hand.draw.fill").labelStyle(.titleAndIcon).font(rnd(14, .heavy))
                }.disabled(boxes.isEmpty)
            }
        }
        .onAppear {
            if !seeded { seeded = true; markSuggested() }
        }
        .onChange(of: lib.assets.count) { _ in
            let ids = Set(lib.assets.map { $0.id })
            marked = marked.filter { ids.contains($0) }
        }
    }

    private func bestID(_ b: FZGroupBox) -> String {
        if let o = bestPick[b.id], b.items.contains(where: { $0.id == o }) { return o }
        return b.items.first { $0.isBest }?.id ?? b.items.first?.id ?? ""
    }

    private func choose(_ id: String, in b: FZGroupBox) {
        Haptic.thud()
        let old = bestID(b)
        bestPick[b.id] = id
        marked.remove(id)
        if old != id, let oa = b.items.first(where: { $0.id == old }), !oa.isFavorite { marked.insert(old) }
    }

    private func markSuggested() {
        var s = Set<String>()
        for b in boxes {
            let best = bestID(b)
            for a in b.items where a.id != best && !a.isFavorite { s.insert(a.id) }
        }
        marked = s
    }

    private var toolbarRow: some View {
        HStack(spacing: 8) {
            Text(FZFormat.groups(boxes.count)).font(rnd(14, .heavy)).foregroundStyle(Color.white)
            Spacer()
            Button {
                Haptic.tap()
                if marked.isEmpty { markSuggested() } else { marked = [] }
            } label: {
                Label(marked.isEmpty ? "حدّد المقترح" : "ألغِ التحديد", systemImage: marked.isEmpty ? "wand.and.stars" : "circle")
                    .font(rnd(13, .heavy)).foregroundStyle(FZ.violet)
                    .padding(.horizontal, 12).frame(height: 36).background(FZ.s2, in: Capsule())
            }.buttonStyle(Press())
        }
    }

    private var actionBar: some View {
        let ids = Array(marked)
        return VStack(spacing: 10) {
            HStack {
                Text(FZFormat.photos(marked.count) + " للحذف").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                Spacer()
                Text("ستوفّر " + FZFormat.size(markedBytes)).font(rnd(15, .black)).foregroundStyle(FZ.mint)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: markedBytes)
            }
            FZPrimaryButton(title: "احذف المكرّر وخلّي الأفضل", icon: "sparkles", style: 1, busy: lib.working) {
                Task { if await lib.delete(ids) { marked = [] } }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.08)))
        .padding(.horizontal, 12).padding(.bottom, 8)
    }
}

struct FZGroupCard: View {
    let box: FZGroupBox
    let best: String
    @Binding var marked: Set<String>
    let makeBest: (String) -> Void

    private var saving: Int64 { box.items.filter { marked.contains($0.id) }.reduce(Int64(0)) { $0 + $1.bytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.on.square.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(FZ.violet)
                Text(FZFormat.photos(box.items.count) + " متشابهة").font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text("· " + (box.items.first?.date.fzShort ?? "")).font(rnd(12)).foregroundStyle(FZ.tx3)
                Spacer()
                Text(saving > 0 ? "−" + FZFormat.size(saving) : "بدون حذف").font(rnd(13, .black)).foregroundStyle(saving > 0 ? FZ.mint : FZ.tx3)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(box.items) { a in
                        FZGroupThumb(asset: a, isBest: a.id == best, isMarked: marked.contains(a.id))
                            .onTapGesture {
                                Haptic.tap()
                                if marked.contains(a.id) { marked.remove(a.id) } else { marked.insert(a.id) }
                            }
                            .onLongPressGesture(minimumDuration: 0.4) { makeBest(a.id) }
                    }
                }.padding(.vertical, 2)
            }
            Text("اضغط للتبديل · اضغط مطوّلًا لتختارها كأفضل لقطة").font(rnd(11)).foregroundStyle(FZ.tx3)
        }
        .padding(14)
        .card(FZ.s1, 24, stroke: FZ.violet.opacity(0.18))
    }
}

struct FZGroupThumb: View {
    let asset: FZAsset
    let isBest: Bool
    let isMarked: Bool

    var body: some View {
        FZThumb(asset: asset, px: 300)
            .frame(width: 118, height: 156)
            .overlay {
                if isMarked { Color.black.opacity(0.35) }
            }
            .overlay(alignment: .top) {
                if isBest {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill").font(.system(size: 10, weight: .black))
                        Text("الأفضل").font(rnd(11, .black))
                    }
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 8).frame(height: 22)
                    .background(FZ.brand, in: Capsule())
                    .padding(.top, 7)
                }
            }
            .overlay(alignment: .bottomLeading) {
                ZStack {
                    Circle().fill(isMarked ? FZ.danger : Color.black.opacity(0.35)).frame(width: 26, height: 26)
                    Image(systemName: isMarked ? "trash.fill" : "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(Color.white)
                }.padding(7)
            }
            .overlay(alignment: .bottomTrailing) {
                if let s = asset.sharpness {
                    Text("\(Int(FZBlur.sharpnessScore(s) * 100))").font(rnd(10, .black)).foregroundStyle(Color.white)
                        .padding(.horizontal, 6).frame(height: 18).background(Color.black.opacity(0.5), in: Capsule()).padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isBest ? FZ.mint : (isMarked ? FZ.danger.opacity(0.7) : Color.clear), lineWidth: 2.5))
            .scaleEffect(isMarked ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isMarked)
            .contentShape(Rectangle())
    }
}
