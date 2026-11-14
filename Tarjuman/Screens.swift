import SwiftUI
import PhotosUI
import UIKit

// MARK: - الكتابة

struct TextScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var voice: Voice
    @State private var input = Shot.on ? "أريد غرفة لشخصين لثلاث ليالي، والريوك داخل بالسعر؟" : ""
    @State private var output = Shot.on ? "یه اتاق دو تخته برای سه شب می‌خوام، صبحانه شامل قیمت هست؟" : ""
    @State private var working = false
    @State private var err: String?
    @State private var show: ShowText?
    @FocusState private var focus: Bool

    var from: Lang { input.isEmpty ? store.a : (Script.guess(input) == store.b ? store.b : store.a) }
    var to: Lang { from == store.a ? store.b : store.a }

    var body: some View {
        ZStack {
            TJ.bg.ignoresSafeArea().onTapGesture { focus = false }
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text("اكتب وترجم").font(rnd(26, .heavy)).foregroundStyle(.white)
                        Spacer()
                    }.padding(.top, 8)
                    LangBar()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("\(from.flag) \(from.name)").font(rnd(13, .bold)).foregroundStyle(TJ.teal)
                            Text("تلقائيّ").font(rnd(11)).foregroundStyle(TJ.tx3)
                            Spacer()
                            if !input.isEmpty {
                                Button { input = ""; output = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(TJ.tx3) }
                            }
                        }
                        ZStack(alignment: .topLeading) {
                            if input.isEmpty {
                                Text("اكتب أو الصق النصّ هنا…").font(rnd(18)).foregroundStyle(TJ.tx3).padding(.top, 8).padding(.leading, 4)
                            }
                            TextEditor(text: $input).font(rnd(19)).focused($focus)
                                .scrollContentBackground(.hidden).frame(minHeight: 120)
                                .environment(\.layoutDirection, from.rtl ? .rightToLeft : .leftToRight)
                        }
                        HStack {
                            Button {
                                if let s = UIPasteboard.general.string { input = s }
                            } label: { Label("الصق", systemImage: "doc.on.clipboard").font(rnd(13, .semibold)) }
                            Spacer()
                            Button(action: run) {
                                HStack(spacing: 6) {
                                    if working { ProgressView().tint(.black) }
                                    Text("ترجم").font(rnd(16, .heavy))
                                }
                                .foregroundStyle(.black).padding(.horizontal, 26).padding(.vertical, 11)
                                .background(TJ.teal, in: Capsule())
                            }
                            .buttonStyle(Press()).disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || working)
                        }
                    }
                    .padding(16).card(TJ.s1, 22)

                    if let err { Text(err).font(rnd(13, .semibold)).foregroundStyle(TJ.rose) }

                    if !output.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(to.flag) \(to.name)").font(rnd(13, .bold)).foregroundStyle(TJ.gold)
                            Text(output).font(rnd(22, .bold)).foregroundStyle(.white).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .environment(\.layoutDirection, to.rtl ? .rightToLeft : .leftToRight)
                            HStack(spacing: 18) {
                                Button { store.speak(output, to) } label: {
                                    Label("اسمع", systemImage: voice.speaking == output ? "speaker.wave.3.fill" : "speaker.wave.2")
                                }
                                Button { UIPasteboard.general.string = output; Haptic.tap() } label: { Label("انسخ", systemImage: "doc.on.doc") }
                                Button { show = ShowText(text: output, lang: to) } label: { Label("كبّر", systemImage: "arrow.up.left.and.arrow.down.right") }
                                Spacer()
                                ShareLink(item: output) { Image(systemName: "square.and.arrow.up") }
                            }.font(rnd(14, .semibold)).foregroundStyle(TJ.gold)
                        }
                        .padding(16)
                        .background(TJ.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(TJ.gold.opacity(0.3)))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .sheet(item: $show) { s in ShowSheet(item: s) }
    }

    func run() {
        focus = false; working = true; err = nil
        let f = from, t = to
        let lines = input.components(separatedBy: "\n")
        Task {
            do {
                let r = try await Api.translate(lines, from: f, to: t)
                output = r.joined(separator: "\n")
                Haptic.ok()
            } catch { err = error.localizedDescription; Haptic.bad() }
            working = false
        }
    }
}

// MARK: - الكاميرا

struct OcrLine: Identifiable { let id = UUID(); let src: String; var dst: String }

struct CameraScreen: View {
    @EnvironmentObject var store: Store
    @State private var image: UIImage?
    @State private var pick: PhotosPickerItem?
    @State private var camera = false
    @State private var lines: [OcrLine] = Shot.on ? [
        OcrLine(src: "منوی رستوران", dst: "قائمة المطعم"),
        OcrLine(src: "چلو کباب کوبیده — ۳۲۰ هزار تومان", dst: "تمّن وكباب كوبيدة — ٣٢٠ ألف تومان"),
        OcrLine(src: "جوجه کباب — ۲۹۰ هزار تومان", dst: "كباب دجاج — ٢٩٠ ألف تومان"),
        OcrLine(src: "دوغ محلی", dst: "لبن محلّي"),
        OcrLine(src: "چای و قلیان ممنوع", dst: "الشاي والأرگيلة ممنوعة"),
    ] : []
    @State private var stage = ""
    @State private var err: String?
    @State private var srcLang: Lang = .fa

    var body: some View {
        ZStack {
            TJ.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ترجمة الصور").font(rnd(26, .heavy)).foregroundStyle(.white)
                            Text("منيو، لافتة، ورقة، شاشة… صوّرها وتطلع مترجمة").font(rnd(13)).foregroundStyle(TJ.tx3)
                        }
                        Spacer()
                    }.padding(.top, 8)

                    HStack(spacing: 10) {
                        Text("لغة الصورة").font(rnd(14, .semibold)).foregroundStyle(TJ.tx2)
                        Spacer()
                        LangMenu(lang: $srcLang, color: TJ.gold)
                    }.padding(14).card(TJ.s1, 18)

                    HStack(spacing: 12) {
                        Button { camera = true } label: { bigBtn("صوّر", "camera.fill", TJ.teal) }.buttonStyle(Press())
                        PhotosPicker(selection: $pick, matching: .images) { bigBtn("من الصور", "photo.on.rectangle", TJ.gold) }
                    }

                    if let image {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    if !stage.isEmpty {
                        HStack(spacing: 8) { ProgressView().tint(.white); Text(stage).font(rnd(14, .semibold)).foregroundStyle(TJ.tx2) }
                            .padding(.vertical, 8)
                    }
                    if let err { Text(err).font(rnd(13, .semibold)).foregroundStyle(TJ.rose).multilineTextAlignment(.center) }

                    if !lines.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(lines) { l in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(l.dst).font(rnd(18, .bold)).foregroundStyle(.white)
                                    Text(l.src).font(rnd(13)).foregroundStyle(TJ.tx3)
                                        .environment(\.layoutDirection, srcLang.rtl ? .rightToLeft : .leftToRight)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 11).padding(.horizontal, 14)
                                .onTapGesture { store.speak(l.dst, target) }
                                if l.id != lines.last?.id { Divider().overlay(TJ.s3) }
                            }
                        }
                        .card(TJ.s1, 20)
                        HStack {
                            Button { UIPasteboard.general.string = lines.map { $0.dst }.joined(separator: "\n"); Haptic.tap() } label: {
                                Label("انسخ الترجمة", systemImage: "doc.on.doc")
                            }
                            Spacer()
                            ShareLink(item: lines.map { "\($0.src)\n← \($0.dst)" }.joined(separator: "\n\n")) { Label("شارك", systemImage: "square.and.arrow.up") }
                        }.font(rnd(14, .semibold)).foregroundStyle(TJ.teal).padding(.horizontal, 6)
                    }
                    if lines.isEmpty && image == nil && stage.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "text.viewfinder").font(.system(size: 50)).foregroundStyle(TJ.teal.opacity(0.7))
                            Text("قرّب على النصّ وخلّي الضوء زين.\nكلّ سطر يطلع مترجم تحته، اضغطه ينلفظ.")
                                .font(rnd(14)).foregroundStyle(TJ.tx2).multilineTextAlignment(.center).lineSpacing(4)
                        }.padding(.top, 30)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .onAppear { if !Shot.on { srcLang = store.b == .ar ? store.a : store.b } }
        .onChange(of: pick) { item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { process(img) }
                pick = nil
            }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { img in camera = false; if let img { process(img) } }.ignoresSafeArea()
        }
    }

    var target: Lang { srcLang == .ar ? (store.b == .ar ? store.a : store.b) : .ar }

    func bigBtn(_ t: String, _ icon: String, _ c: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 26, weight: .semibold))
            Text(t).font(rnd(15, .bold))
        }
        .foregroundStyle(c).frame(maxWidth: .infinity).padding(.vertical, 20)
        .background(c.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(c.opacity(0.3)))
    }

    func process(_ img: UIImage) {
        image = img; lines = []; err = nil; stage = "أقرا النصّ…"
        let small = img.resized(maxSide: 2000)
        guard let jpeg = small.jpegData(compressionQuality: 0.82) else { stage = ""; return }
        let src = srcLang, dst = target
        Task {
            do {
                let o = try await Api.ocr(jpeg: jpeg, lang: src)
                let found = o.lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 1 }
                if found.isEmpty { err = "ما لگيت نصّ واضح بالصورة — قرّب أكثر أو غيّر لغة الصورة"; stage = ""; return }
                stage = "أترجم \(found.count) سطر…"
                let tr = try await Api.translate(found, from: src, to: dst)
                lines = zip(found, tr).map { OcrLine(src: $0.0, dst: $0.1) }
                Haptic.ok()
            } catch { err = error.localizedDescription; Haptic.bad() }
            stage = ""
        }
    }
}

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let m = max(size.width, size.height)
        guard m > maxSide else { return self }
        let s = maxSide / m
        let n = CGSize(width: size.width * s, height: size.height * s)
        return UIGraphicsImageRenderer(size: n).image { _ in draw(in: CGRect(origin: .zero, size: n)) }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var done: (UIImage?) -> Void
    func makeCoordinator() -> Coord { Coord(done: done) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}

// MARK: - العبارات

struct PhrasesScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var voice: Voice
    @State private var q = ""
    @State private var cat: String = Shot.name == "phrase" ? "taxi" : "hi"
    @State private var show: ShowText?

    var items: [Phrase] { q.isEmpty ? Phrases.of(cat) : Phrases.search(q) }

    var body: some View {
        ZStack {
            TJ.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("عبارات جاهزة").font(rnd(26, .heavy)).foregroundStyle(.white)
                            Text("\(Phrases.all.count) عبارة فارسيّة تشتغل بلا نت").font(rnd(13)).foregroundStyle(TJ.tx3)
                        }
                        Spacer()
                    }.padding(.top, 8)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(TJ.tx3)
                        TextField("دوّر: مستشفى، بيش، فندق…", text: $q).font(rnd(16))
                    }.padding(12).card(TJ.s1, 16)

                    if q.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Phrases.cats) { c in
                                    Button { withAnimation(.spring(response: 0.3)) { cat = c.id }; Haptic.tap() } label: {
                                        Label(c.name, systemImage: c.icon).font(rnd(14, .bold))
                                            .foregroundStyle(cat == c.id ? .black : .white)
                                            .padding(.horizontal, 14).padding(.vertical, 9)
                                            .background(cat == c.id ? TJ.teal : TJ.s2, in: Capsule())
                                    }.buttonStyle(Press())
                                }
                            }
                        }
                    }

                    ForEach(items) { p in
                        PhraseCard(p: p, speaking: voice.speaking == p.fa) { store.speak(p.fa, .fa) } onShow: {
                            show = ShowText(text: p.fa, lang: .fa)
                        }
                    }

                    offlineCard.padding(.top, 8)
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .sheet(item: $show) { s in ShowSheet(item: s) }
    }

    private var offlineCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 28)).foregroundStyle(TJ.gold)
            VStack(alignment: .leading, spacing: 3) {
                Text("كلّ الأصوات داخل التطبيق").font(rnd(15, .bold)).foregroundStyle(.white)
                Text("نطق فارسيّ طبيعيّ (رجل وامرأة) يشتغل حتى بالطيّارة بلا نت. غيّر الصوت من ⋯ بالمحادثة.")
                    .font(rnd(12)).foregroundStyle(TJ.tx2)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(TJ.s1, 20)
    }
}

struct PhraseCard: View {
    let p: Phrase
    let speaking: Bool
    var onSpeak: () -> Void
    var onShow: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(p.ar).font(rnd(14, .semibold)).foregroundStyle(TJ.tx2)
                Text(p.fa).font(rnd(21, .bold)).foregroundStyle(.white)
                Text("🔊 \(p.say)").font(rnd(13)).foregroundStyle(TJ.teal.opacity(0.85))
            }
            Spacer()
            VStack(spacing: 10) {
                Button(action: onSpeak) {
                    Image(systemName: speaking ? "speaker.wave.3.fill" : "play.fill").font(rnd(15, .bold)).foregroundStyle(.black)
                        .frame(width: 40, height: 40).background(TJ.teal, in: Circle())
                }.buttonStyle(Press())
                Button(action: onShow) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(rnd(13, .bold)).foregroundStyle(TJ.tx2)
                        .frame(width: 40, height: 32)
                }
            }
        }
        .padding(14).card(TJ.s1, 20)
        .contentShape(Rectangle()).onTapGesture(perform: onSpeak)
    }
}

// MARK: - التومان

struct MoneyScreen: View {
    @EnvironmentObject var store: Store
    @State private var heard = Shot.on ? "۱۵۰ تومن" : ""
    @State private var iqd = Shot.on ? "25000" : ""
    @State private var editRates = false
    @FocusState private var focus: Bool

    var readings: [PriceReading] { Money.readings(heard) }
    var iqdValue: Double? { Double(Script.latinDigits(iqd).replacingOccurrences(of: ",", with: "")) }

    var body: some View {
        ZStack {
            TJ.bg.ignoresSafeArea().onTapGesture { focus = false }
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("فكّ التومان").font(rnd(26, .heavy)).foregroundStyle(.white)
                            Text("ريال؟ تومان؟ «٥٠ تومن» يعني ٥٠ ألف؟ هنا تنحلّ").font(rnd(13)).foregroundStyle(TJ.tx3)
                        }
                        Spacer()
                    }.padding(.top, 8)

                    // البيّاع گال
                    VStack(alignment: .leading, spacing: 12) {
                        Label("البيّاع گال / مكتوب", systemImage: "ear").font(rnd(15, .bold)).foregroundStyle(TJ.gold)
                        TextField("مثل: ۱۵۰ تومن، صد و پنجاه هزار، 2 میلیون", text: $heard)
                            .font(rnd(20, .bold)).focused($focus).padding(12).card(TJ.s2, 14)
                        HStack(spacing: 8) {
                            ForEach(["۵۰ تومن", "۲۰۰ هزار", "۱.۵ میلیون", "۵۰۰۰۰۰ ریال"], id: \.self) { s in
                                Button { heard = s } label: {
                                    Text(s).font(rnd(12, .semibold)).foregroundStyle(TJ.tx2).padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(TJ.s2, in: Capsule())
                                }
                            }
                        }
                        if !heard.isEmpty && readings.isEmpty {
                            Text("ما فهمت الرقم — اكتبه أرقام أو كلمات فارسيّة").font(rnd(13)).foregroundStyle(TJ.rose)
                        }
                        ForEach(Array(readings.enumerated()), id: \.offset) { _, r in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(r.label).font(rnd(13, .semibold)).foregroundStyle(r.likely ? TJ.teal : TJ.tx3)
                                    if r.likely { Text("الأرجح").font(rnd(10, .heavy)).foregroundStyle(.black).padding(.horizontal, 7).padding(.vertical, 3).background(TJ.teal, in: Capsule()) }
                                }
                                HStack(alignment: .firstTextBaseline) {
                                    Text(Money.fmt(store.rates.toIQD(toman: r.toman))).font(rnd(r.likely ? 32 : 22, .heavy)).foregroundStyle(.white)
                                    Text("دينار").font(rnd(14, .bold)).foregroundStyle(TJ.tx2)
                                    Spacer()
                                    Text("$" + Money.fmt(store.rates.toUSD(toman: r.toman), digits: 2)).font(rnd(16, .bold)).foregroundStyle(TJ.gold)
                                }
                                Text("\(Money.fmt(r.toman)) تومان = \(Money.fmt(r.toman * 10)) ريال").font(rnd(12)).foregroundStyle(TJ.tx3)
                            }
                            .padding(12).background(r.likely ? TJ.teal.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(16).card(TJ.s1, 22)

                    // أنا أريد أدفع
                    VStack(alignment: .leading, spacing: 12) {
                        Label("أريد أدفع بالدينار", systemImage: "hand.point.up.left").font(rnd(15, .bold)).foregroundStyle(TJ.teal)
                        HStack {
                            TextField("المبلغ بالدينار", text: $iqd).keyboardType(.numberPad).font(rnd(20, .bold)).focused($focus)
                            Text("د.ع").font(rnd(14, .bold)).foregroundStyle(TJ.tx3)
                        }.padding(12).card(TJ.s2, 14)
                        if let v = iqdValue, v > 0 {
                            let t = (store.rates.toToman(iqd: v) / 1000).rounded() * 1000
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(Money.fmt(t)) تومان").font(rnd(30, .heavy)).foregroundStyle(.white)
                                Text("گلّه هيچي:").font(rnd(12, .semibold)).foregroundStyle(TJ.tx3)
                                HStack {
                                    Text(Money.streetSay(toman: t)).font(rnd(20, .bold)).foregroundStyle(TJ.gold)
                                    Spacer()
                                    Button { store.speak(Money.streetSay(toman: t), .fa) } label: {
                                        Image(systemName: "speaker.wave.2.fill").font(rnd(15, .bold)).foregroundStyle(.black)
                                            .frame(width: 38, height: 38).background(TJ.gold, in: Circle())
                                    }
                                }
                                Text(Script.digits(Money.fmt(t), for: .fa) + " تومان").font(rnd(15, .semibold)).foregroundStyle(TJ.tx2)
                            }
                        }
                    }
                    .padding(16).card(TJ.s1, 22)

                    // الأسعار
                    Button { editRates.toggle() } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("الدولار = \(Money.fmt(store.rates.tomanPerUSD)) تومان · \(Money.fmt(store.rates.iqdPerUSD)) دينار")
                                .font(rnd(13, .semibold))
                            Spacer()
                            Image(systemName: editRates ? "chevron.up" : "chevron.down")
                        }.foregroundStyle(TJ.tx2).padding(14).card(TJ.s1, 16)
                    }
                    if editRates { RatesEditor() }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
    }
}

struct RatesEditor: View {
    @EnvironmentObject var store: Store
    @State private var toman = ""
    @State private var iqd = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("السعر يتغيّر كلّ يوم — اسأل الصرّاف وعدّله هنا").font(rnd(12)).foregroundStyle(TJ.tx3)
            HStack { Text("تومان بالدولار").font(rnd(14)); Spacer(); TextField("", text: $toman).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 130) }
            HStack { Text("دينار بالدولار").font(rnd(14)); Spacer(); TextField("", text: $iqd).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 130) }
            Button {
                if let t = Double(Script.latinDigits(toman)), t > 1000 { store.rates.tomanPerUSD = t }
                if let i = Double(Script.latinDigits(iqd)), i > 100 { store.rates.iqdPerUSD = i }
                store.rates.updated = Date(); Haptic.ok()
            } label: {
                Text("احفظ").font(rnd(15, .heavy)).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 10).background(TJ.teal, in: Capsule())
            }
        }
        .font(rnd(16, .bold)).padding(16).card(TJ.s1, 18)
        .onAppear { toman = String(Int(store.rates.tomanPerUSD)); iqd = String(Int(store.rates.iqdPerUSD)) }
    }
}
