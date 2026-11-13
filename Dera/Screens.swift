import SwiftUI

struct Primary: View {
    let title: String; var icon: String = ""; var tint: Color = DE.ac; var on: Color = DE.on; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { if !icon.isEmpty { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }; Text(title).font(rnd(16, .heavy)) }
                .foregroundStyle(on).frame(maxWidth: .infinity).frame(height: 52).background(tint, in: Capsule())
        }.buttonStyle(Press())
    }
}

// MARK: - كلمات السرّ
struct PasswordTab: View {
    @State private var mode = Shot.name == "gen" ? 1 : 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                pageTitle("كلمات السرّ", "افحص قوّتها، شوف إذا تسرّبت، أو ولّد وحدة قويّة")
                Picker("", selection: $mode) { Text("افحص").tag(0); Text("ولّد").tag(1) }.pickerStyle(.segmented)
                if mode == 0 { CheckPane() } else { GeneratePane() }
            }.padding(18)
        }.scrollDismissesKeyboard(.interactively)
    }
}

struct StrengthBar: View {
    let s: Sec.Strength
    var body: some View {
        let lv = DE.level(s.score)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) { ForEach(0..<5, id: \.self) { i in Capsule().fill(i <= s.score ? lv.1 : DE.s3).frame(height: 7) } }.environment(\.layoutDirection, .leftToRight)
            HStack {
                Text(lv.0).font(rnd(17, .black)).foregroundStyle(lv.1)
                Spacer()
                Text("تنكسر خلال: " + s.crack).font(rnd(12.5, .heavy)).foregroundStyle(DE.tx2)
            }
        }
    }
}

struct CheckPane: View {
    @State private var pw = Shot.isAny("pass", "leak") ? "Summer2024" : ""
    @State private var show = Shot.on
    @State private var leak: Int? = Shot.name == "leak" ? 51259 : nil
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        let s = Sec.strength(pw)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Group {
                    if show { TextField("", text: $pw, prompt: Text("اكتب كلمة السرّ").foregroundColor(DE.tx3)) } else { SecureField("", text: $pw, prompt: Text("اكتب كلمة السرّ").foregroundColor(DE.tx3)) }
                }.font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(Color.white).textInputAutocapitalization(.never).autocorrectionDisabled().environment(\.layoutDirection, .leftToRight)
                Button { show.toggle() } label: { Image(systemName: show ? "eye.slash.fill" : "eye.fill").foregroundStyle(DE.tx3) }.buttonStyle(.plain)
            }.padding(.horizontal, 16).frame(height: 56).background(DE.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onChange(of: pw) { _ in leak = nil; failed = false }

            if pw.isEmpty {
                Text("اللي تكتبه هنا ما ينحفظ وما يطلع من جهازك.").font(rnd(12.5)).foregroundStyle(DE.tx3)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    StrengthBar(s: s)
                    if s.issues.isEmpty { Label("ما لگينا بيها نقطة ضعف واضحة.", systemImage: "checkmark.circle.fill").font(rnd(13.5, .heavy)).foregroundStyle(DE.ac) }
                    ForEach(s.issues, id: \.self) { i in
                        HStack(alignment: .top, spacing: 8) { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(DE.amber).padding(.top, 3); Text(i).font(rnd(13.5)).foregroundStyle(DE.tx2) }
                    }
                }.padding(14).card(DE.s1, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("هل تسرّبت قبل؟").font(rnd(16, .heavy)).foregroundStyle(Color.white)
                    if let n = leak {
                        HStack(spacing: 10) {
                            Image(systemName: n > 0 ? "xmark.octagon.fill" : "checkmark.seal.fill").font(.system(size: 26)).foregroundStyle(n > 0 ? DE.red : DE.ac)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n > 0 ? "طلعت بتسريبات \(n) مرّة" : "ما طلعت بأيّ تسريب معروف").font(rnd(15.5, .black)).foregroundStyle(n > 0 ? DE.red : DE.ac)
                                Text(n > 0 ? "لا تستعملها أبد — موجودة بقوائم المخترقين." : "هذا ما يعني إنّها قويّة، بس ما مكشوفة.").font(rnd(12.5)).foregroundStyle(DE.tx2)
                            }
                        }
                    } else {
                        Text("نقارنها بقاعدة تسريبات عالميّة. ما ينبعث من الكلمة إلّا أوّل ٥ حروف من بصمتها المشفّرة، فالكلمة نفسها ما تطلع من جهازك.").font(rnd(12.5)).foregroundStyle(DE.tx3).lineSpacing(3)
                        if failed { Text("ما وصلنا لقاعدة التسريبات — تأكّد من النت.").font(rnd(12.5, .bold)).foregroundStyle(DE.amber) }
                        Primary(title: busy ? "دا نفحص…" : "افحص التسريب", icon: "magnifyingglass", tint: DE.blue, on: Color.white) { check() }.disabled(busy).opacity(busy ? 0.5 : 1)
                    }
                }.padding(14).card(DE.s1, 20)
            }
        }
    }
    private func check() {
        busy = true; failed = false
        let hash = Sec.sha1(pw)
        Task {
            defer { busy = false }
            guard let u = URL(string: "https://api.pwnedpasswords.com/range/" + String(hash.prefix(5))) else { return }
            var rq = URLRequest(url: u); rq.timeoutInterval = 15; rq.setValue("true", forHTTPHeaderField: "Add-Padding")
            guard let (d, r) = try? await URLSession.shared.data(for: rq), (r as? HTTPURLResponse)?.statusCode == 200, let body = String(data: d, encoding: .utf8) else { failed = true; return }
            leak = Sec.pwnedCount(rangeBody: body, hash: hash)
            if (leak ?? 0) > 0 { Haptic.bad() } else { Haptic.ok() }
        }
    }
}

struct GeneratePane: View {
    @State private var phrase = false
    @State private var length = 18.0
    @State private var words = 4.0
    @State private var upper = true
    @State private var digits = true
    @State private var symbols = true
    @State private var readable = false
    @State private var out = Shot.on ? "v9#Tq2!mKx7@Lr4$Zp" : ""
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text(out).font(.system(size: 22, weight: .heavy, design: .monospaced)).foregroundStyle(Color.white).frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
                    .padding(.vertical, 18).padding(.horizontal, 10).background(DE.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).environment(\.layoutDirection, .leftToRight).textSelection(.enabled)
                StrengthBar(s: Sec.strength(out))
                HStack(spacing: 10) {
                    Primary(title: copied ? "انّسخت ✓" : "انسخ", icon: "doc.on.doc") { UIPasteboard.general.string = out; copied = true; Haptic.ok() }
                    Button { make() } label: { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.white).frame(width: 52, height: 52).background(DE.s3, in: Circle()) }.buttonStyle(Press())
                }
            }.padding(14).card(DE.s1, 20)

            Picker("", selection: $phrase) { Text("حروف ورموز").tag(false); Text("عبارة تنحفظ").tag(true) }.pickerStyle(.segmented)
            VStack(spacing: 0) {
                if phrase {
                    slider("عدد الكلمات", $words, 3...8, "\(Int(words))")
                    Text("كلمات عشوائيّة سهلة الحفظ والكتابة، وقوّتها من طولها.").font(rnd(12)).foregroundStyle(DE.tx3).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.bottom, 12)
                } else {
                    slider("الطول", $length, 8...40, "\(Int(length))")
                    opt2("حروف كبيرة A-Z", $upper)
                    opt2("أرقام 0-9", $digits)
                    opt2("رموز !@#", $symbols)
                    opt2("بلا حروف متشابهة (l · 1 · O · 0)", $readable)
                }
            }.card(DE.s1, 20)
        }
        .onAppear { if out.isEmpty { make() } }
        .onChange(of: phrase) { _ in make() }.onChange(of: length) { _ in make() }.onChange(of: words) { _ in make() }
        .onChange(of: upper) { _ in make() }.onChange(of: digits) { _ in make() }.onChange(of: symbols) { _ in make() }.onChange(of: readable) { _ in make() }
    }
    private func make() {
        var rng = SystemRandomNumberGenerator()
        out = phrase ? Sec.passphrase(words: Int(words), using: &rng) : Sec.generate(length: Int(length), upper: upper, digits: digits, symbols: symbols, readable: readable, using: &rng)
        copied = false
    }
    private func slider(_ t: String, _ v: Binding<Double>, _ r: ClosedRange<Double>, _ val: String) -> some View {
        VStack(spacing: 4) {
            HStack { Text(t).font(rnd(15, .heavy)).foregroundStyle(Color.white); Spacer(); Text(val).font(rnd(17, .black)).foregroundStyle(DE.ac) }
            Slider(value: v, in: r, step: 1).environment(\.layoutDirection, .leftToRight)
        }.padding(14)
    }
    private func opt2(_ t: String, _ b: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(white: 1, opacity: 0.06))
            Toggle(isOn: b) { Text(t).font(rnd(14.5, .bold)).foregroundStyle(Color.white) }.tint(DE.ac).padding(.horizontal, 14).padding(.vertical, 9)
        }
    }
}

// MARK: - رموز التحقّق بخطوتين
struct CodesTab: View {
    @EnvironmentObject var g: Guard
    @State private var adding = Shot.name == "addcode"
    @State private var copied: UUID? = nil
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                pageTitle("الرموز", "رموز التحقّق بخطوتين — تتغيّر كلّ ٣٠ ثانية")
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    let now = Shot.on ? 1_700_000_012.0 : tl.date.timeIntervalSince1970
                    VStack(spacing: 10) {
                        ForEach(g.otps) { a in
                            let left = Double(a.period) - now.truncatingRemainder(dividingBy: Double(a.period))
                            let code = Sec.totp(secret: a.secret, at: now, period: a.period, digits: a.digits) ?? "------"
                            Button { UIPasteboard.general.string = code; copied = a.id; Haptic.ok() } label: {
                                HStack(spacing: 12) {
                                    Text(String(a.issuer.first ?? "?")).font(rnd(18, .black)).foregroundStyle(DE.on).frame(width: 44, height: 44).background(DE.ac.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(a.issuer).font(rnd(15, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                                        Text(copied == a.id ? "انّسخ ✓" : a.name).font(rnd(12)).foregroundStyle(copied == a.id ? DE.ac : DE.tx3).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Text(String(code.prefix(code.count / 2)) + " " + String(code.suffix(code.count - code.count / 2))).font(.system(size: 26, weight: .heavy, design: .monospaced)).foregroundStyle(left < 6 ? DE.red : Color.white)
                                    ZStack {
                                        Circle().stroke(DE.s3, lineWidth: 3.5)
                                        Circle().trim(from: 0, to: left / Double(a.period)).stroke(left < 6 ? DE.red : DE.ac, style: StrokeStyle(lineWidth: 3.5, lineCap: .round)).rotationEffect(.degrees(-90))
                                        Text("\(Int(left))").font(rnd(10.5, .heavy)).foregroundStyle(DE.tx2)
                                    }.frame(width: 30, height: 30)
                                }.padding(12).card(DE.s1, 18).environment(\.layoutDirection, .leftToRight)
                            }.buttonStyle(Press())
                            .contextMenu { Button(role: .destructive) { g.remove(a) } label: { Label("احذف الحساب", systemImage: "trash") } }
                        }
                    }
                }
                if g.otps.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill").font(.system(size: 44)).foregroundStyle(DE.ac)
                        Text("ضيف أوّل حساب").font(rnd(19, .black)).foregroundStyle(Color.white)
                        Text("من إعدادات أيّ موقع (گوگل، إنستغرام، …) فعّل «التحقّق بخطوتين بتطبيق»، وانسخ المفتاح اللي يطلعلك هنا.").font(rnd(13.5)).foregroundStyle(DE.tx2).multilineTextAlignment(.center).lineSpacing(3)
                    }.padding(24).frame(maxWidth: .infinity).card(DE.s1, 24)
                } else { Text("اضغط على الرمز حتى ينّسخ. اضغط مطوّلًا حتى تحذف الحساب.").font(rnd(12)).foregroundStyle(DE.tx3) }
                Primary(title: "ضيف حساب", icon: "plus") { adding = true }
                Text("المفاتيح تنحفظ بخزنة الآيفون المشفّرة وما تطلع من جهازك. احتفظ برموز الاسترجاع مال كلّ موقع بمكان ثاني.").font(rnd(11.5)).foregroundStyle(DE.tx3).lineSpacing(3)
            }.padding(18)
        }
        .sheet(isPresented: $adding) { AddCode().environmentObject(g).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
    }
}

struct AddCode: View {
    @EnvironmentObject var g: Guard
    @Environment(\.dismiss) private var dismiss
    @State private var issuer = Shot.on ? "Google" : ""
    @State private var name = Shot.on ? "me@gmail.com" : ""
    @State private var secret = Shot.on ? "JBSW Y3DP EHPK 3PXP" : ""
    private var valid: Bool { !issuer.trimmingCharacters(in: .whitespaces).isEmpty && Sec.base32(secret) != nil && secret.filter({ $0 != " " }).count >= 8 }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("حساب جديد").font(rnd(26, .black)).foregroundStyle(Color.white)
                Button { paste() } label: { Label("الصق رابط أو مفتاح من الحافظة", systemImage: "doc.on.clipboard").font(rnd(14.5, .heavy)).foregroundStyle(DE.ac).frame(maxWidth: .infinity).frame(height: 48).card(DE.s1, 16, stroke: DE.ac.opacity(0.35)) }.buttonStyle(Press())
                field("اسم الموقع — مثلًا Google", $issuer, false)
                field("الحساب — إيميلك أو اسم المستخدم", $name, true)
                field("المفتاح السرّيّ (حروف وأرقام)", $secret, true)
                if !secret.isEmpty && Sec.base32(secret) == nil { Text("المفتاح مو صحيح — لازم حروف A-Z وأرقام 2-7 بس.").font(rnd(12.5, .bold)).foregroundStyle(DE.red) }
                if valid, let code = Sec.totp(secret: secret, at: Shot.on ? 1_700_000_012 : Date().timeIntervalSince1970) {
                    HStack { Text("الرمز الحاليّ").font(rnd(13)).foregroundStyle(DE.tx3); Spacer(); Text(code).font(.system(size: 22, weight: .heavy, design: .monospaced)).foregroundStyle(DE.ac) }.padding(14).card(DE.s1, 16)
                    Text("قارنه بالرمز اللي يطلبه الموقع حتى تتأكّد إنّ المفتاح صحّ.").font(rnd(12)).foregroundStyle(DE.tx3)
                }
                Primary(title: "احفظ", icon: "checkmark") {
                    g.add(Sec.OTPAccount(issuer: issuer.trimmingCharacters(in: .whitespaces), name: name.trimmingCharacters(in: .whitespaces), secret: secret.uppercased().filter { $0 != " " && $0 != "-" }))
                    Haptic.ok(); dismiss()
                }.disabled(!valid).opacity(valid ? 1 : 0.4)
            }.padding(20)
        }.background(DE.bg.ignoresSafeArea())
    }
    private func paste() {
        guard let t = UIPasteboard.general.string else { return }
        if let a = Sec.parseOTP(t) { issuer = a.issuer; name = a.name; secret = a.secret } else if Sec.base32(t) != nil { secret = t.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    private func field(_ hint: String, _ t: Binding<String>, _ ltr: Bool) -> some View {
        TextField("", text: t, prompt: Text(hint).foregroundColor(DE.tx3)).font(rnd(16, .bold)).foregroundStyle(Color.white).textInputAutocapitalization(.never).autocorrectionDisabled()
            .environment(\.layoutDirection, ltr ? .leftToRight : .rightToLeft)
            .padding(.horizontal, 16).frame(height: 54).background(DE.s2, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// MARK: - الروابط
struct LinksTab: View {
    @State private var text = Shot.name == "linkbad" ? "http://paypa1-secure.xyz/login/verify" : (Shot.name == "link" ? "https://www.wikipedia.org" : "")
    @State private var report: Sec.LinkReport? = nil
    @State private var hops: [String] = []
    @State private var busy = false
    @State private var bad = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                pageTitle("الروابط", "وصلك رابط وما متأكّد منه؟ افحصه قبل ما تفتحه")
                HStack(spacing: 8) {
                    TextField("", text: $text, prompt: Text("الصق الرابط هنا").foregroundColor(DE.tx3), axis: .vertical).lineLimit(1...3).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(Color.white)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).environment(\.layoutDirection, .leftToRight)
                    Button { if let s = UIPasteboard.general.string { text = s; run() } } label: { Image(systemName: "doc.on.clipboard").font(.system(size: 15, weight: .bold)).foregroundStyle(DE.ac).frame(width: 40, height: 40).background(DE.ac.opacity(0.14), in: Circle()) }.buttonStyle(Press())
                }.padding(.horizontal, 14).padding(.vertical, 9).background(DE.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Primary(title: "افحص الرابط", icon: "magnifyingglass") { run() }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty).opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                if bad { Text("هذا مو رابط صحيح.").font(rnd(13, .bold)).foregroundStyle(DE.amber) }
                if let r = report { result(r) }
                else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("شنو نفحص؟").font(rnd(15, .heavy)).foregroundStyle(Color.white)
                        tip("textformat.abc.dottedunderline", "تقليد الأسماء المشهورة (paypa1 بدل paypal)")
                        tip("eye.slash.fill", "الروابط المختصرة اللي تخفي وجهتها")
                        tip("lock.open.fill", "الاتّصال غير المشفّر والعناوين الرقميّة")
                        tip("character.textbox", "حروف من لغات ثانية تشبه الإنكليزيّة")
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).card(DE.s1, 20)
                }
            }.padding(18)
        }.scrollDismissesKeyboard(.interactively)
        .onAppear { if Shot.on && !text.isEmpty { report = Sec.analyze(text) } }
    }
    private func tip(_ icon: String, _ t: String) -> some View {
        HStack(spacing: 10) { Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(DE.ac).frame(width: 26); Text(t).font(rnd(13.5)).foregroundStyle(DE.tx2) }
    }
    private func run() {
        hops = []
        guard let r = Sec.analyze(text) else { report = nil; bad = true; return }
        bad = false; report = r; Haptic.thud()
    }
    @ViewBuilder private func result(_ r: Sec.LinkReport) -> some View {
        let tint = r.verdict == 2 ? DE.red : (r.verdict == 1 ? DE.amber : DE.ac)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: r.verdict == 2 ? "xmark.shield.fill" : (r.verdict == 1 ? "exclamationmark.shield.fill" : "checkmark.shield.fill")).font(.system(size: 40)).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.verdict == 2 ? "خطير — لا تفتحه" : (r.verdict == 1 ? "انتبه" : "ما لگينا شي مشبوه")).font(rnd(21, .black)).foregroundStyle(tint)
                    Text(r.host).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(Color.white).lineLimit(1).truncationMode(.middle)
                }
            }
            ForEach(Array(r.flags.enumerated()), id: \.offset) { _, f in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(f.level == 2 ? DE.red : DE.amber).frame(width: 8, height: 8).padding(.top, 6)
                    Text(f.text).font(rnd(13.5)).foregroundStyle(DE.tx2).lineSpacing(3)
                }
            }
            if r.flags.isEmpty { Text("شكل الرابط سليم. هذا فحص للعنوان فقط — الموقع نفسه ممكن يكون مضرّ، فخلّيك حذر إذا طلب بياناتك.").font(rnd(12.5)).foregroundStyle(DE.tx3).lineSpacing(3) }
            if !hops.isEmpty {
                Divider().overlay(Color(white: 1, opacity: 0.08))
                Text("الرابط يحوّلك على:").font(rnd(13, .heavy)).foregroundStyle(Color.white)
                ForEach(hops, id: \.self) { h in Text("← " + h).font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(DE.tx2).lineLimit(2) }
            }
            Button { follow() } label: { Label(busy ? "دا نتتبّع…" : "وين يوصلني هالرابط؟", systemImage: "arrow.triangle.turn.up.right.diamond.fill").font(rnd(14, .heavy)).foregroundStyle(DE.blue).frame(maxWidth: .infinity).frame(height: 44).background(DE.blue.opacity(0.12), in: Capsule()) }.buttonStyle(Press()).disabled(busy)
        }.padding(16).card(DE.s1, 22, stroke: tint.opacity(0.4))
    }
    /// نتتبّع التحويلات بلا ما نفتح الصفحة — ونفحص الوجهة النهائيّة
    private func follow() {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) == nil { s = "https://" + s }
        guard let start = URL(string: s) else { return }
        busy = true
        Task {
            let chain = await Tracer.trace(start)
            hops = chain.isEmpty ? ["ما بيه تحويل — يفتح نفس العنوان"] : chain
            if let last = chain.last, let r2 = Sec.analyze(last), let r1 = report, r2.verdict > r1.verdict { report = Sec.LinkReport(host: r2.host, flags: r2.flags + [Sec.Flag(level: 1, text: "النتيجة فوق للوجهة النهائيّة بعد التحويل")], verdict: r2.verdict) }
            busy = false
        }
    }
}

/// يتتبّع تحويلات الرابط (لحدّ ٦ قفزات) بطلبات رأس فقط — بلا تحميل الصفحة
final class Tracer: NSObject, URLSessionTaskDelegate {
    private var chain: [String] = []
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if let u = request.url?.absoluteString { chain.append(u) }
        completionHandler(chain.count >= 6 ? nil : request)
    }
    static func trace(_ url: URL) async -> [String] {
        let t = Tracer()
        let cfg = URLSessionConfiguration.ephemeral; cfg.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: cfg, delegate: t, delegateQueue: nil)
        var rq = URLRequest(url: url); rq.httpMethod = "HEAD"
        _ = try? await session.data(for: rq)
        session.invalidateAndCancel()
        return t.chain
    }
}
