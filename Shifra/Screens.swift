import SwiftUI
import UIKit
import PhotosUI

// MARK: تشفير

struct EncryptScreen: View {
    @EnvironmentObject var vault: Vault
    @State private var text = Shot.on ? "نلتقي الساعة ٩ عند الجسر، لا تگول لأحد." : ""
    @State private var pass = Shot.on ? "code2026" : ""
    @State private var out = ""
    @State private var copied = false
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                header("تشفير رسالة", "اكتب رسالتك، حطّ كلمة سرّ، وارسل الناتج بأيّ تطبيق — محد يگدر يقراها إلّا اللي عنده الكلمة.")
                editor
                PassField(label: "كلمة السرّ (شاركها مع المستلم بأمان)", text: $pass)
                bigButton("اقفل الرسالة", "lock.fill", SF.mint, text.isEmpty || pass.isEmpty) { encrypt() }
                if !out.isEmpty || Shot.on { result }
            }.padding(18).padding(.bottom, 90)
        }
        .onAppear { if Shot.on { encrypt() } }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("الرسالة").font(rnd(12.5, .bold)).foregroundStyle(SF.tx3)
            ZStack(alignment: .topTrailing) {
                TextEditor(text: $text).scrollContentBackground(.hidden).font(rnd(15)).foregroundStyle(Color.white)
                    .frame(height: 120).padding(10).background(SF.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08)))
                if text.isEmpty { Text("اكتب هنا…").font(rnd(15)).foregroundStyle(SF.tx3).padding(18).allowsHitTesting(false).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) }
            }
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { Text("الناتج المقفل").font(rnd(14, .heavy)).foregroundStyle(SF.mint); Spacer(); Image(systemName: "checkmark.seal.fill").foregroundStyle(SF.mint) }
            Text(out).font(.system(size: 12, design: .monospaced)).foregroundStyle(SF.tx2).environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity, alignment: .leading).lineLimit(8).padding(12).background(SF.bg, in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 10) {
                Button { UIPasteboard.general.string = out; copied = true; Haptic.ok() } label: {
                    Label(copied ? "اننسخ ✓" : "انسخ", systemImage: "doc.on.doc.fill").font(rnd(14, .heavy)).foregroundStyle(Color.black.opacity(0.84)).frame(maxWidth: .infinity).frame(height: 46).background(SF.mint, in: Capsule())
                }.buttonStyle(Press())
                ShareLink(item: out) { Label("أرسل", systemImage: "square.and.arrow.up").font(rnd(14, .heavy)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 46).background(SF.s2, in: Capsule()) }
                Button { vault.save(title: String(text.prefix(24)), blob: out); saved = true; Haptic.tap() } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark").font(.system(size: 16, weight: .bold)).foregroundStyle(SF.amber).frame(width: 46, height: 46).background(SF.s2, in: Circle())
                }.buttonStyle(Press())
            }
        }.padding(14).card(SF.s1, 20, stroke: SF.mint.opacity(0.25))
    }

    private func encrypt() {
        guard let e = Crypto.encrypt(text, pass: pass) else { return }
        out = e; copied = false; saved = false; Haptic.ok()
    }
}

// MARK: فكّ

struct DecryptScreen: View {
    @State private var blob = Shot.on ? "-----شفرة مقفلة-----\nU0Yxr5kZ2mK9vQ3xL8pW7nB4tH6yJ1cD0eF2aG5sM8iR3oT9uV7wX2zA6bN4qE1\nkP0lC8mD5fH3jK7nB2vX9yZ4tQ6wR1sL8aG3oU5iM7eP0cF2dN4qH6yJ1kB9vX\n-----نهاية-----" : ""
    @State private var pass = Shot.on ? "code2026" : ""
    @State private var out: String? = nil
    @State private var tried = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                header("فكّ الشفرة", "الصق الرسالة المقفلة اللي وصلتك، حطّ نفس كلمة السرّ، وتطلعلك واضحة.")
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("الرسالة المقفلة").font(rnd(12.5, .bold)).foregroundStyle(SF.tx3)
                        Spacer()
                        Button { if let s = UIPasteboard.general.string { blob = s; Haptic.tap() } } label: { Label("الصق", systemImage: "doc.on.clipboard").font(rnd(12, .bold)).foregroundStyle(SF.mint) }
                    }
                    TextEditor(text: $blob).scrollContentBackground(.hidden).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight)
                        .frame(height: 120).padding(10).background(SF.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08)))
                }
                PassField(label: "كلمة السرّ", text: $pass)
                bigButton("افتح الرسالة", "lock.open.fill", SF.violet, blob.isEmpty || pass.isEmpty) { decrypt() }
                if Shot.on { reveal("نلتقي الساعة ٩ عند الجسر، لا تگول لأحد.") }
                else if tried { if let o = out { reveal(o) } else { failCard } }
            }.padding(18).padding(.bottom, 90)
        }
    }
    private func reveal(_ s: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "checkmark.seal.fill").foregroundStyle(SF.mint); Text("الرسالة").font(rnd(14, .heavy)).foregroundStyle(SF.mint) }
            Text(s).font(rnd(17, .bold)).foregroundStyle(Color.white).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true).padding(14).background(SF.bg, in: RoundedRectangle(cornerRadius: 14))
            Button { UIPasteboard.general.string = s } label: { Label("انسخ", systemImage: "doc.on.doc").font(rnd(13, .bold)).foregroundStyle(SF.tx2) }
        }.padding(14).card(SF.s1, 20, stroke: SF.mint.opacity(0.25))
    }
    private var failCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.octagon.fill").foregroundStyle(SF.red).font(.system(size: 22))
            Text("ما انفتحت — كلمة السرّ غلط أو الرسالة ناقصة/معدّلة.").font(rnd(13.5, .heavy)).foregroundStyle(Color.white)
            Spacer(minLength: 0)
        }.padding(14).card(SF.red.opacity(0.1), 18, stroke: SF.red.opacity(0.3))
    }
    private func decrypt() { out = Crypto.decrypt(blob, pass: pass); tried = true; if out != nil { Haptic.ok() } else { Haptic.bad() } }
}

// MARK: الإخفاء داخل صورة

struct PhotoScreen: View {
    @State private var mode = 0       // 0 خبّي · 1 اكشف
    @State private var pick: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    @State private var text = Shot.on ? "الباسورد: Qx7!mn — امسح الرسالة بعد ما تحفظها" : ""
    @State private var pass = Shot.on ? "٢٠٢٦" : ""
    @State private var result: UIImage? = nil
    @State private var revealed: String? = nil
    @State private var err = ""
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                header("رسالة داخل صورة", "خبّي رسالة سرّيّة جوّه صورة عاديّة — تبيّن صورة طبيعيّة بس داخلها كلامك.")
                Picker("", selection: $mode) { Text("خبّي رسالة").tag(0); Text("اكشف رسالة").tag(1) }
                    .pickerStyle(.segmented).onChange(of: mode) { _ in reset() }
                photoBox
                if mode == 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("الرسالة السرّيّة").font(rnd(12.5, .bold)).foregroundStyle(SF.tx3)
                        TextEditor(text: $text).scrollContentBackground(.hidden).font(rnd(15)).foregroundStyle(Color.white)
                            .frame(height: 80).padding(10).background(SF.s2, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
                    }
                }
                PassField(label: mode == 0 ? "كلمة سرّ (اختياريّة — تشفّر الرسالة بعد)" : "كلمة السرّ (إذا كانت مشفّرة)", text: $pass)
                if mode == 0 {
                    bigButton(busy ? "…" : "خبّي واحفظ الصورة", "eye.slash.fill", SF.pink, image == nil || text.isEmpty) { hide() }
                } else {
                    bigButton(busy ? "…" : "اكشف الرسالة", "eye.fill", SF.violet, image == nil) { reveal() }
                }
                if !err.isEmpty { Text(err).font(rnd(13, .bold)).foregroundStyle(SF.red) }
                if Shot.on && mode == 1 { revealCard("الباسورد: Qx7!mn — امسح الرسالة بعد ما تحفظها") }
                else if let r = revealed { revealCard(r) }
                if result != nil || (Shot.on && mode == 0) { savedCard }
            }.padding(18).padding(.bottom, 90)
        }
        .onChange(of: pick) { _ in loadImage() }
        .onAppear { if Shot.on { image = demoImage(); if mode == 0 { result = image } } }
    }

    private var photoBox: some View {
        PhotosPicker(selection: $pick, matching: .images) {
            ZStack {
                if let img = result ?? image {
                    Image(uiImage: img).resizable().scaledToFill().frame(height: 170).clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus.fill").font(.system(size: 34)).foregroundStyle(SF.tx3)
                        Text("اختار صورة").font(rnd(14, .heavy)).foregroundStyle(SF.tx2)
                    }.frame(height: 170).frame(maxWidth: .infinity)
                }
            }.frame(maxWidth: .infinity).background(SF.s1, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(SF.pink.opacity(0.25)))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
    private func revealCard(_ s: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "sparkle.magnifyingglass").foregroundStyle(SF.violet); Text("لگينا رسالة مخبّاة").font(rnd(14, .heavy)).foregroundStyle(SF.violet) }
            Text(s).font(rnd(16, .bold)).foregroundStyle(Color.white).frame(maxWidth: .infinity, alignment: .leading).padding(13).background(SF.bg, in: RoundedRectangle(cornerRadius: 12))
        }.padding(14).card(SF.s1, 20, stroke: SF.violet.opacity(0.25))
    }
    private var savedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(SF.mint).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text("انحفظت بالصور ✓").font(rnd(14.5, .heavy)).foregroundStyle(Color.white)
                Text("أرسل الصورة لأيّ أحد — الرسالة مخبّاة جوّاها").font(rnd(11.5)).foregroundStyle(SF.tx3)
            }
            Spacer(minLength: 0)
        }.padding(14).card(SF.mint.opacity(0.1), 18, stroke: SF.mint.opacity(0.3))
    }

    private func loadImage() {
        guard let pick = pick else { return }
        reset()
        pick.loadTransferable(type: Data.self) { res in
            if case .success(let d?) = res, let ui = UIImage(data: d) {
                DispatchQueue.main.async { self.image = ui }
            }
        }
    }
    private func hide() {
        guard let img = image, !busy else { return }
        busy = true; err = ""
        DispatchQueue.global().async {
            let r = ImageStego.hide(text, pass: pass, in: img)
            DispatchQueue.main.async {
                busy = false
                if let r = r { result = r; UIImageWriteToSavedPhotosAlbum(r, nil, nil, nil); Haptic.ok() }
                else { err = "الرسالة أطول من ما تتحمّل الصورة — اختار صورة أكبر أو رسالة أقصر." }
            }
        }
    }
    private func reveal() {
        guard let img = image, !busy else { return }
        busy = true; err = ""; revealed = nil
        DispatchQueue.global().async {
            let r = ImageStego.reveal(img, pass: pass)
            DispatchQueue.main.async {
                busy = false
                if let r = r { revealed = r; Haptic.ok() } else { err = "ما لگينا رسالة بالصورة (أو كلمة السرّ غلط)."; Haptic.bad() }
            }
        }
    }
    private func reset() { result = nil; revealed = nil; err = "" }
    private func demoImage() -> UIImage {
        let s = CGSize(width: 400, height: 300)
        return UIGraphicsImageRenderer(size: s).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(red: 0.1, green: 0.15, blue: 0.3, alpha: 1).cgColor); c.fill(CGRect(origin: .zero, size: s))
            let cols = [UIColor(red: 1, green: 0.5, blue: 0.3, alpha: 1), UIColor(red: 0.9, green: 0.3, blue: 0.5, alpha: 1)]
            for i in 0..<2 { c.setFillColor(cols[i].cgColor); c.fillEllipse(in: CGRect(x: 60 + i * 180, y: 80, width: 140, height: 140)) }
        }
    }
}

// MARK: كلمات سرّ

struct PassScreen: View {
    @State private var length: Double = 16
    @State private var upper = true, digit = true, symbol = true
    @State private var pw = Shot.on ? "Kx9#mPq2$wZ7!vL4" : Pass.generate(length: 16, upper: true, digit: true, symbol: true)
    @State private var test = Shot.on ? "sara1990" : ""
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header("كلمات السرّ", "ولّد كلمة سرّ قويّة، أو افحص قوّة كلمتك — كلّ شي على جهازك.")
                genCard
                checkCard
            }.padding(18).padding(.bottom, 90)
        }
    }

    private var genCard: some View {
        let s = Pass.rate(pw)
        return VStack(alignment: .leading, spacing: 13) {
            Text("مولّد").font(rnd(17, .heavy)).foregroundStyle(Color.white)
            HStack {
                Text(pw).font(.system(size: 19, weight: .bold, design: .monospaced)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight).lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                Button { pw = Pass.generate(length: Int(length), upper: upper, digit: digit, symbol: symbol); copied = false; Haptic.tap() } label: { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 17, weight: .black)).foregroundStyle(SF.mint) }.buttonStyle(Press())
            }.padding(13).background(SF.bg, in: RoundedRectangle(cornerRadius: 14))
            strengthBar(s)
            HStack { Text("الطول").font(rnd(13, .bold)).foregroundStyle(SF.tx2); Spacer(); Text("\(Int(length))").font(rnd(15, .black)).foregroundStyle(SF.mint).environment(\.layoutDirection, .leftToRight) }
            Slider(value: $length, in: 8...32, step: 1).tint(SF.mint).onChange(of: length) { _ in pw = Pass.generate(length: Int(length), upper: upper, digit: digit, symbol: symbol) }
            HStack(spacing: 8) {
                toggle("ABC", $upper); toggle("123", $digit); toggle("#@!", $symbol)
            }
            Button { UIPasteboard.general.string = pw; copied = true; Haptic.ok() } label: {
                Label(copied ? "اننسخت ✓" : "انسخ", systemImage: "doc.on.doc.fill").font(rnd(15, .heavy)).foregroundStyle(Color.black.opacity(0.84)).frame(maxWidth: .infinity).frame(height: 48).background(SF.mint, in: Capsule())
            }.buttonStyle(Press())
        }.padding(16).card(SF.s1, 22, stroke: SF.mint.opacity(0.2))
    }

    private var checkCard: some View {
        let s = Pass.rate(test)
        return VStack(alignment: .leading, spacing: 11) {
            Text("افحص كلمتك").font(rnd(17, .heavy)).foregroundStyle(Color.white)
            SecureFieldAlt(text: $test)
            if !test.isEmpty {
                strengthBar(s)
                HStack(spacing: 8) {
                    Image(systemName: s.score >= 3 ? "checkmark.shield.fill" : "exclamationmark.shield.fill").foregroundStyle(SF.strengthColor(s.score))
                    Text("تنكسر خلال: \(s.crackTime)").font(rnd(13.5, .bold)).foregroundStyle(SF.tx2)
                }
            } else {
                Text("اكتب كلمة سرّ حتى نقيّم قوّتها ووقت كسرها.").font(rnd(12.5)).foregroundStyle(SF.tx3)
            }
        }.padding(16).card(SF.s1, 22)
    }

    private func strengthBar(_ s: Strength) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule().fill(i <= s.score ? SF.strengthColor(s.score) : SF.s3).frame(height: 6)
                }
            }
            Text(s.label).font(rnd(12.5, .heavy)).foregroundStyle(SF.strengthColor(s.score))
        }
    }
    private func toggle(_ t: String, _ b: Binding<Bool>) -> some View {
        Button { b.wrappedValue.toggle(); pw = Pass.generate(length: Int(length), upper: upper, digit: digit, symbol: symbol); Haptic.tap() } label: {
            Text(t).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(b.wrappedValue ? Color.black.opacity(0.84) : SF.tx3)
                .frame(maxWidth: .infinity).frame(height: 42).background(b.wrappedValue ? SF.mint : SF.s2, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(Press())
    }
}

struct SecureFieldAlt: View {
    @Binding var text: String
    @State private var show = false
    var body: some View {
        HStack {
            Group { if show { TextField("كلمتك", text: $text) } else { SecureField("كلمتك", text: $text) } }
                .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(Color.white).autocorrectionDisabled().textInputAutocapitalization(.never).environment(\.layoutDirection, .leftToRight)
            Button { show.toggle() } label: { Image(systemName: show ? "eye.slash.fill" : "eye.fill").foregroundStyle(SF.tx3) }
        }.padding(13).background(SF.s2, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
    }
}
