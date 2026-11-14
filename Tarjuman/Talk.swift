import SwiftUI
import UIKit

/// شاشة المحادثة: كلّ واحد يضغط زرّه ويحجي، يطلع النصّ مترجم ويُنطق للثاني
struct TalkScreen: View {
    @EnvironmentObject var store: Store
    @State private var face = Shot.name == "face"
    @State private var show: ShowText?
    @State private var typing: Bool?

    var body: some View {
        ZStack {
            TJ.bg.ignoresSafeArea()
            if face { FaceMode(face: $face) } else { list }
        }
        .sheet(item: $show) { s in ShowSheet(item: s) }
        .sheet(isPresented: Binding(get: { typing != nil }, set: { if !$0 { typing = nil } })) {
            TypeSheet(mine: typing ?? true).presentationDetents([.height(260)])
        }
    }

    private var list: some View {
        VStack(spacing: 12) {
            header
            LangBar()
            if store.turns.isEmpty { empty } else { bubbles }
            if let e = store.error {
                Text(e).font(rnd(13, .semibold)).foregroundStyle(TJ.rose).multilineTextAlignment(.center)
                    .padding(.horizontal, 20).transition(.opacity)
            }
            HStack(spacing: 12) {
                HoldMic(mine: true, lang: store.a, label: "اضغط واحجي")
                HoldMic(mine: false, lang: store.b, label: hint(store.b))
            }
            .padding(.horizontal, 16)
            HStack {
                Button { typing = true } label: { Label("اكتب بدل الحجي", systemImage: "keyboard") }
                Spacer()
                Button { typing = false } label: { Label("بنویسید", systemImage: "keyboard") }
            }
            .font(rnd(12, .semibold)).foregroundStyle(TJ.tx3).padding(.horizontal, 26).padding(.bottom, 6)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ترجمان").font(rnd(26, .heavy)).foregroundStyle(.white)
                HStack(spacing: 6) {
                    Circle().fill(store.online == false ? TJ.rose : (store.online == true ? TJ.teal : TJ.tx3)).frame(width: 7, height: 7)
                    Text(store.online == false ? "ماكو اتّصال — العبارات والتومان تشتغل بلا نت" : "ترجمة صوتيّة فوريّة")
                        .font(rnd(12, .medium)).foregroundStyle(TJ.tx3)
                }
            }
            Spacer()
            Button { withAnimation(.spring(response: 0.4)) { face = true } } label: {
                Image(systemName: "person.2.wave.2.fill").font(rnd(17, .semibold)).foregroundStyle(TJ.teal)
                    .frame(width: 42, height: 42).background(TJ.s2, in: Circle())
            }.buttonStyle(Press())
            Menu {
                Toggle("انطق الترجمة تلقائيًّا", isOn: $store.autoSpeak)
                Picker("الصوت", selection: $store.male) {
                    Text("صوت امرأة").tag(false)
                    Text("صوت رجل").tag(true)
                }
                if !store.turns.isEmpty {
                    ShareLink(item: Convo.transcript(store.turns)) { Label("شارك المحادثة", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { store.clear() } label: { Label("امسح المحادثة", systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis").font(rnd(17, .bold)).foregroundStyle(.white)
                    .frame(width: 42, height: 42).background(TJ.s2, in: Circle())
            }
        }
        .padding(.horizontal, 18).padding(.top, 8)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "waveform.and.mic").font(.system(size: 54, weight: .semibold)).foregroundStyle(TJ.teal.opacity(0.8))
            Text("اضغط زرّك مطوّلًا واحجي").font(rnd(19, .bold)).foregroundStyle(.white)
            Text("الزرّ الأخضر إلك، والذهبي للشخص اللي گدّامك.\nكلّ واحد يحجي بلغته والتطبيق يترجم وينطق للثاني.")
                .font(rnd(14)).foregroundStyle(TJ.tx2).multilineTextAlignment(.center).lineSpacing(4)
            Button { withAnimation(.spring(response: 0.4)) { face = true } } label: {
                Label("وضع وجهًا لوجه (الموبايل بينكم)", systemImage: "person.2.wave.2.fill")
                    .font(rnd(14, .bold)).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(TJ.s2, in: Capsule())
            }.buttonStyle(Press()).padding(.top, 6)
            Spacer()
        }.padding(.horizontal, 30)
    }

    private var bubbles: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.turns) { t in
                        Bubble(turn: t) { show = ShowText(text: t.translated, lang: t.to) }.id(t.id)
                    }
                    if store.busy != nil {
                        HStack {
                            if store.busy == false { Spacer() }
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text(store.status).font(rnd(14, .semibold)).foregroundStyle(TJ.tx2)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .card(TJ.s2, 18)
                            if store.busy == true { Spacer() }
                        }.id("busy")
                    }
                }.padding(.horizontal, 16).padding(.vertical, 6)
            }
            .onChange(of: store.turns.count) { _ in
                withAnimation { proxy.scrollTo(store.turns.last?.id, anchor: .bottom) }
            }
        }
    }

    private func hint(_ l: Lang) -> String {
        switch l {
        case .fa: return "فشار بدید و حرف بزنید"
        case .en: return "Hold & speak"
        case .tr: return "Basılı tut, konuş"
        case .ku: return "داگرە و قسە بکە"
        case .ar: return "اضغط واحجي"
        }
    }
}

struct ShowText: Identifiable { let id = UUID(); let text: String; let lang: Lang }

struct Bubble: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var voice: Voice
    let turn: Turn
    var onShow: () -> Void
    @State private var copied = false

    var body: some View {
        HStack {
            if !turn.mine { Spacer(minLength: 34) }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(turn.from.flag).font(rnd(13))
                    Text(turn.heard).font(rnd(14)).foregroundStyle(TJ.tx2)
                        .environment(\.layoutDirection, turn.from.rtl ? .rightToLeft : .leftToRight)
                }
                Text(turn.translated).font(rnd(20, .bold)).foregroundStyle(.white)
                    .environment(\.layoutDirection, turn.to.rtl ? .rightToLeft : .leftToRight)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Button { store.speak(turn.translated, turn.to) } label: {
                        Image(systemName: voice.speaking == turn.translated ? "speaker.wave.3.fill" : "speaker.wave.2")
                    }
                    Button { UIPasteboard.general.string = turn.translated; copied = true; Haptic.tap() } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    Button(action: onShow) { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    Spacer()
                    Text(turn.date.formatted(date: .omitted, time: .shortened)).font(rnd(11)).foregroundStyle(TJ.tx3)
                }
                .font(rnd(15, .semibold)).foregroundStyle(TJ.side(turn.mine))
            }
            .padding(14)
            .background(TJ.side(turn.mine).opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(TJ.side(turn.mine).opacity(0.28)))
            if turn.mine { Spacer(minLength: 34) }
        }
    }
}

/// زرّ «اضغط مطوّلًا واحجي» مع موجة صوت حيّة
struct HoldMic: View {
    @EnvironmentObject var store: Store
    let mine: Bool
    let lang: Lang
    let label: String
    var big = false
    @State private var down = false

    var active: Bool { store.busy == mine && store.status == "أسمعك…" }
    var waiting: Bool { store.busy == mine && store.status != "أسمعك…" }

    var body: some View {
        let c = TJ.side(mine)
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active)) { _ in
            let lv = CGFloat(active ? store.rec.level : 0)
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(c.opacity(0.18)).scaleEffect(1 + lv * 0.45)
                    Circle().fill(active ? c : c.opacity(0.9))
                        .frame(width: big ? 96 : 64, height: big ? 96 : 64)
                        .shadow(color: c.opacity(active ? 0.7 : 0.25), radius: active ? 22 : 10)
                    if waiting { ProgressView().tint(.black) }
                    else {
                        Image(systemName: active ? "waveform" : "mic.fill")
                            .font(.system(size: big ? 34 : 24, weight: .bold)).foregroundStyle(.black.opacity(0.82))
                    }
                }
                .frame(width: big ? 130 : 86, height: big ? 130 : 86)
                Text("\(lang.flag) \(lang.native)").font(rnd(big ? 16 : 13, .bold)).foregroundStyle(.white)
                Text(active ? "شيل إصبعك من تخلّص" : label).font(rnd(big ? 13 : 11, .medium)).foregroundStyle(TJ.tx3)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity).padding(.vertical, big ? 14 : 10)
            .background(TJ.s1, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(c.opacity(active ? 0.8 : 0.2), lineWidth: active ? 2 : 1))
        }
        .opacity(store.busy != nil && store.busy != mine ? 0.4 : 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !down { down = true; store.startTalk(mine: mine) } }
                .onEnded { v in
                    down = false
                    // سحب لبرّا = إلغاء
                    if abs(v.translation.height) > 140 { store.cancelTalk() } else { store.endTalk() }
                }
        )
    }
}

/// وضع وجهًا لوجه: النصّ الفوقانيّ مقلوب للشخص اللي گبالك
struct FaceMode: View {
    @EnvironmentObject var store: Store
    @Binding var face: Bool

    var lastFor: (mine: Turn?, theirs: Turn?) {
        (store.turns.last { !$0.mine }, store.turns.last { $0.mine })
    }

    var body: some View {
        VStack(spacing: 0) {
            half(mine: false).rotationEffect(.degrees(180))
            ZStack {
                Rectangle().fill(TJ.s3).frame(height: 1)
                Button { withAnimation(.spring(response: 0.4)) { face = false } } label: {
                    Image(systemName: "xmark").font(rnd(14, .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(TJ.s3, in: Circle())
                }
            }
            half(mine: true)
        }
        .padding(.vertical, 6)
    }

    /// كلّ نصّ يعرض آخر شي انگال للطرف هذا (مترجم للغته)
    @ViewBuilder func half(mine: Bool) -> some View {
        let lang = mine ? store.a : store.b
        // آخر جملة قالها الطرف الثاني مترجمة للغة هذا الطرف
        let t = mine ? lastFor.mine : lastFor.theirs
        VStack(spacing: 12) {
            Spacer(minLength: 4)
            if let t {
                Text(t.translated).font(rnd(26, .bold)).foregroundStyle(.white).multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5).padding(.horizontal, 22)
                    .environment(\.layoutDirection, lang.rtl ? .rightToLeft : .leftToRight)
                Text(t.heard).font(rnd(13)).foregroundStyle(TJ.tx3).lineLimit(2).multilineTextAlignment(.center).padding(.horizontal, 30)
            } else {
                Text(mine ? "اضغط واحجي بالعربي" : welcome(lang)).font(rnd(18, .semibold)).foregroundStyle(TJ.tx2)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
            }
            Spacer(minLength: 4)
            HoldMic(mine: mine, lang: lang, label: mine ? "اضغط واحجي" : welcomeShort(lang), big: true)
                .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func welcome(_ l: Lang) -> String {
        switch l {
        case .fa: return "سلام! این مترجم است. دکمه را نگه دارید و فارسی صحبت کنید."
        case .en: return "Hi! This is a translator. Hold the button and speak."
        case .tr: return "Merhaba! Bu bir çevirmen. Düğmeyi basılı tutup konuşun."
        case .ku: return "سڵاو! دوگمەکە داگرە و قسە بکە."
        case .ar: return "اضغط الزرّ واحجي"
        }
    }
    private func welcomeShort(_ l: Lang) -> String {
        switch l {
        case .fa: return "نگه دارید و صحبت کنید"
        case .en: return "Hold & speak"
        case .tr: return "Basılı tut"
        case .ku: return "داگرە"
        case .ar: return "اضغط واحجي"
        }
    }
}

/// عرض النصّ بخطّ كبير حتى تراويه للشخص
struct ShowSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let item: ShowText
    @State private var flip = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(rnd(18, .bold)).foregroundStyle(.white) }
                    Spacer()
                    Button { withAnimation { flip.toggle() } } label: {
                        Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down").font(rnd(18, .bold)).foregroundStyle(TJ.teal)
                    }
                    Button { store.speak(item.text, item.lang) } label: {
                        Image(systemName: "speaker.wave.2.fill").font(rnd(18, .bold)).foregroundStyle(TJ.teal)
                    }.padding(.leading, 18)
                }.padding(.horizontal, 22).padding(.top, 12)
                Spacer()
                Text(item.text).font(.system(size: 46, weight: .bold)).foregroundStyle(.white)
                    .multilineTextAlignment(.center).minimumScaleFactor(0.3).padding(.horizontal, 20)
                    .environment(\.layoutDirection, item.lang.rtl ? .rightToLeft : .leftToRight)
                    .rotationEffect(.degrees(flip ? 180 : 0))
                Spacer()
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

/// كتابة جملة بدل الحجي
struct TypeSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let mine: Bool
    @State private var text = ""
    @FocusState private var f: Bool
    var lang: Lang { mine ? store.a : store.b }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(lang.flag) \(mine ? "اكتب بالعربي" : (lang == .fa ? "به فارسی بنویسید" : lang.native))")
                .font(rnd(16, .bold)).foregroundStyle(TJ.side(mine))
            TextField(lang == .fa ? "اینجا بنویسید…" : "اكتب هنا…", text: $text, axis: .vertical)
                .font(rnd(20)).lineLimit(2...4).focused($f).padding(12).card(TJ.s2, 14)
                .environment(\.layoutDirection, lang.rtl ? .rightToLeft : .leftToRight)
            Button {
                store.typed(text, mine: mine); dismiss()
            } label: {
                Text(lang == .fa && !mine ? "ترجمه کن" : "ترجم").font(rnd(16, .heavy)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12).background(TJ.side(mine), in: Capsule())
            }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(20).frame(maxHeight: .infinity, alignment: .top).background(TJ.s1)
        .onAppear { f = true }
    }
}
