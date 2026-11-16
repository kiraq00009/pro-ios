import SwiftUI
import UIKit

/// وضع المراجعة بالسحب: يسار = حذف، يمين = إبقاء، مع تراجع وعدّاد التوفير
struct FZSwipeView: View {
    let req: FZDeckRequest
    @EnvironmentObject var lib: FZLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var deck: FZDeck
    @State private var drag: CGSize = .zero
    @State private var flying = false
    @State private var crossed = false
    @State private var summary = false

    private let threshold: CGFloat = 110

    init(req: FZDeckRequest) {
        self.req = req
        var d = FZDeck(ids: req.assets.map { $0.id }, sizes: req.assets.map { $0.bytes })
        if Shot.name == "swipe" {
            let plan: [FZChoice] = [.trash, .trash, .keep, .trash, .trash, .trash, .keep, .trash, .trash, .keep, .trash]
            for c in plan { d.choose(c) }
        }
        _deck = State(initialValue: d)
    }

    private func asset(_ id: String) -> FZAsset? { req.assets.first { $0.id == id } }

    var body: some View {
        ZStack {
            FZBackdrop()
            if summary || deck.isDone {
                FZDeckSummary(req: req, deck: $deck, onBack: { withAnimation { summary = false; if deck.isDone { _ = deck.undo() } } }, onClose: { dismiss() })
                    .transition(.opacity)
            } else {
                VStack(spacing: 14) {
                    topBar
                    progressBar
                    stack.frame(maxHeight: .infinity)
                    hint
                    buttons
                }
                .padding(.horizontal, 18).padding(.bottom, 14).padding(.top, 6)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: summary || deck.isDone)
    }

    // MARK: الشريط العلويّ

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { Haptic.tap(); dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                    .frame(width: 42, height: 42).background(FZ.s2, in: Circle())
            }.buttonStyle(Press())
            VStack(alignment: .leading, spacing: 1) {
                Text(req.title).font(rnd(17, .black)).foregroundStyle(Color.white)
                Text("\(deck.position + 1) من \(deck.ids.count)").font(rnd(12, .bold)).foregroundStyle(FZ.tx3)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("ستوفّر").font(rnd(11, .bold)).foregroundStyle(FZ.tx3)
                Text(FZFormat.size(deck.trashBytes)).font(rnd(20, .black)).foregroundStyle(FZ.mint)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35), value: deck.trashBytes)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(FZ.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button { Haptic.tap(); withAnimation { summary = true } } label: {
                Text("إنهاء").font(rnd(14, .black)).foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 14).frame(height: 42).background(FZ.brand, in: Capsule())
            }.buttonStyle(Press())
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(FZ.s2)
                Capsule().fill(FZ.brand).frame(width: max(6, geo.size.width * deck.fraction))
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.4), value: deck.position)
    }

    // MARK: الرزمة (اتّجاهات فعليّة: نثبّت LTR داخلها)

    private var stack: some View {
        let ids = Array(deck.ids.dropFirst(deck.position).prefix(3))
        return ZStack {
            ForEach(Array(ids.enumerated().reversed()), id: \.element) { pair in
                let depth = pair.offset
                if let a = asset(pair.element) {
                    FZSwipeCard(asset: a, lib: lib, tint: req.color)
                        .overlay { if depth == 0 { stamp } }
                        .scaleEffect(depth == 0 ? 1 : 1 - CGFloat(depth) * 0.05)
                        .offset(x: depth == 0 ? drag.width : 0, y: depth == 0 ? drag.height * 0.4 : CGFloat(depth) * 18)
                        .rotationEffect(.degrees(depth == 0 ? Double(drag.width / 18) : 0), anchor: .bottom)
                        .opacity(depth > 1 ? 0.6 : 1)
                        .zIndex(Double(10 - depth))
                        .allowsHitTesting(depth == 0)
                        .gesture(dragGesture)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: deck.position)
    }

    private var stamp: some View {
        let x = drag.width
        let trash = x < 0
        let strength = min(1, abs(x) / threshold)
        return ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill((trash ? FZ.danger : FZ.green).opacity(0.28 * strength))
            HStack {
                if !trash { Spacer() }
                VStack(spacing: 6) {
                    Image(systemName: trash ? "trash.fill" : "heart.fill").font(.system(size: 34, weight: .black))
                    Text(trash ? "احذف" : "أبقِ").font(rnd(24, .black))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 22).padding(.vertical, 14)
                .background((trash ? FZ.danger : FZ.green).opacity(0.85), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .rotationEffect(.degrees(trash ? 12 : -12))
                .opacity(Double(strength))
                .scaleEffect(0.8 + 0.2 * strength)
                if trash { Spacer() }
            }
            .padding(28)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                guard !flying else { return }
                drag = v.translation
                let over = abs(v.translation.width) > threshold
                if over != crossed { crossed = over; if over { Haptic.tap() } }
            }
            .onEnded { v in
                guard !flying else { return }
                let w = v.translation.width + v.predictedEndTranslation.width * 0.25
                if w < -threshold { fly(.trash) }
                else if w > threshold { fly(.keep) }
                else { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = .zero }; crossed = false }
            }
    }

    private func fly(_ c: FZChoice) {
        guard !flying, !deck.isDone else { return }
        flying = true
        if c == .trash { Haptic.thud() } else { Haptic.tap() }
        withAnimation(.easeIn(duration: 0.22)) {
            drag = CGSize(width: c == .trash ? -560 : 560, height: drag.height + 40)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                deck.choose(c)
                drag = .zero
            }
            crossed = false
            flying = false
            if deck.isDone { Haptic.ok() }
        }
    }

    private var hint: some View {
        HStack {
            Label("اسحب يسار للحذف", systemImage: "arrow.left").font(rnd(12, .bold)).foregroundStyle(FZ.danger.opacity(0.85))
            Spacer()
            Label("يمين للإبقاء", systemImage: "arrow.right").font(rnd(12, .bold)).foregroundStyle(FZ.green.opacity(0.85))
                .environment(\.layoutDirection, .leftToRight)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var buttons: some View {
        HStack(spacing: 22) {
            roundButton("trash.fill", FZ.danger, 70) { fly(.trash) }
            roundButton("arrow.uturn.backward", Color.white, 54) {
                guard !flying, deck.position > 0 else { Haptic.bad(); return }
                Haptic.tap()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { _ = deck.undo() }
            }
            .opacity(deck.position > 0 ? 1 : 0.4)
            roundButton("heart.fill", FZ.green, 70) { fly(.keep) }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func roundButton(_ icon: String, _ c: Color, _ size: CGFloat, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).font(.system(size: size * 0.36, weight: .black)).foregroundStyle(c)
                .frame(width: size, height: size)
                .background(FZ.s1, in: Circle())
                .overlay(Circle().stroke(c.opacity(0.4), lineWidth: 1.5))
                .shadow(color: c.opacity(0.3), radius: 12, y: 4)
        }.buttonStyle(Press())
    }
}

struct FZSwipeCard: View {
    let asset: FZAsset
    let lib: FZLibrary
    let tint: Color

    var body: some View {
        let reason = FZClassify.mainReason(asset, rules: lib.rules, now: lib.now)
        return FZThumb(asset: asset, px: 820)
            .overlay(alignment: .bottom) { info(reason) }
            .overlay(alignment: .top) {
                if asset.kind == .video {
                    Image(systemName: "play.circle.fill").font(.system(size: 54, weight: .bold)).foregroundStyle(Color.white.opacity(0.85))
                        .shadow(radius: 10).padding(.top, 110)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.1)))
            .shadow(color: Color.black.opacity(0.45), radius: 22, y: 12)
    }

    private func info(_ reason: FZCat?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let r = reason {
                    Label(r.short, systemImage: r.icon).font(rnd(12.5, .heavy)).foregroundStyle(Color.black.opacity(0.85))
                        .padding(.horizontal, 10).frame(height: 28).background(FZ.color(r), in: Capsule())
                }
                if asset.kind == .video {
                    Text(FZFormat.duration(asset.duration)).font(rnd(12.5, .heavy)).foregroundStyle(Color.white)
                        .padding(.horizontal, 10).frame(height: 28).background(Color.white.opacity(0.18), in: Capsule())
                        .environment(\.layoutDirection, .leftToRight)
                }
                Spacer()
            }
            HStack(alignment: .lastTextBaseline) {
                FZSizeText(bytes: asset.bytes, size: 34)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(asset.date.fzShort).font(rnd(13, .bold)).foregroundStyle(Color.white)
                    Text("\(asset.width)×\(asset.height)").font(rnd(11.5)).foregroundStyle(FZ.tx2)
                }
            }
        }
        .padding(18)
        .padding(.top, 40)
        .background(LinearGradient(colors: [Color.clear, Color.black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

/// الخلاصة بعد السحب: مراجعة المحدّد ثمّ الحذف بنافذة النظام
struct FZDeckSummary: View {
    let req: FZDeckRequest
    @Binding var deck: FZDeck
    let onBack: () -> Void
    let onClose: () -> Void
    @EnvironmentObject var lib: FZLibrary

    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button { Haptic.tap(); onBack() } label: {
                        Label("رجوع", systemImage: "chevron.right").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                            .padding(.horizontal, 14).frame(height: 40).background(FZ.s2, in: Capsule())
                    }.buttonStyle(Press())
                    Spacer()
                    Button { Haptic.tap(); onClose() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color.white)
                            .frame(width: 40, height: 40).background(FZ.s2, in: Circle())
                    }.buttonStyle(Press())
                }
                ZStack {
                    Circle().fill(FZ.mint.opacity(0.12)).frame(width: 150, height: 150)
                    Circle().stroke(FZ.mint.opacity(0.3), lineWidth: 2).frame(width: 182, height: 182)
                    VStack(spacing: 0) {
                        FZSizeText(bytes: deck.trashBytes, size: 38, color: FZ.mint)
                        Text("جاهزة للتوفير").font(rnd(12, .bold)).foregroundStyle(FZ.tx2)
                    }
                }.padding(.top, 4)
                HStack(spacing: 10) {
                    pill("\(deck.trashCount)", "للحذف", FZ.danger)
                    pill("\(deck.keepCount)", "تبقى", FZ.green)
                    pill("\(deck.remaining)", "ما راجعتها", FZ.tx2)
                }
                if deck.trashCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("اضغط صورة لترجّعها للإبقاء").font(rnd(12)).foregroundStyle(FZ.tx3)
                        LazyVGrid(columns: cols, spacing: 6) {
                            ForEach(deck.trashIndices, id: \.self) { i in
                                if let a = req.assets.first(where: { $0.id == deck.ids[i] }) {
                                    FZThumb(asset: a, px: 200).aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(alignment: .topLeading) {
                                            Image(systemName: "trash.circle.fill").font(.system(size: 18)).foregroundStyle(Color.white, FZ.danger).padding(4)
                                        }
                                        .onTapGesture { Haptic.tap(); withAnimation { deck.set(i, .keep) } }
                                }
                            }
                        }
                    }
                    FZPrimaryButton(title: "احذف \(FZFormat.items(deck.trashCount))", icon: "trash.fill", style: 1, busy: lib.working) {
                        let ids = deck.trashIDs
                        Task { if await lib.delete(ids) { onClose() } }
                    }
                    Text("النظام بيطلب تأكيدك. المحذوف يبقى بـ«المحذوفة مؤخّرًا» 30 يوم.").font(rnd(11)).foregroundStyle(FZ.tx3).multilineTextAlignment(.center)
                } else {
                    FZEmpty(icon: "heart.fill", title: "كلّها محفوظة", note: "ما حدّدت شي للحذف. تقدر ترجع وتراجع من جديد.")
                    FZPrimaryButton(title: "راجع من جديد", icon: "arrow.counterclockwise", style: 2) {
                        withAnimation { deck.restart(); onBack() }
                    }
                }
            }
            .padding(18)
        }
    }

    private func pill(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(rnd(22, .black)).foregroundStyle(c)
            Text(l).font(rnd(11.5, .bold)).foregroundStyle(FZ.tx3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .card(FZ.s1, 18)
    }
}
