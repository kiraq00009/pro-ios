import SwiftUI
import LocalAuthentication
import Security

enum DE {
    static let bg = Color(red: 0.02, green: 0.04, blue: 0.08)
    static let s1 = Color(red: 0.06, green: 0.09, blue: 0.15)
    static let s2 = Color(red: 0.10, green: 0.14, blue: 0.22)
    static let s3 = Color(red: 0.16, green: 0.21, blue: 0.31)
    static let ac = Color(red: 0.2, green: 0.9, blue: 0.68)
    static let on = Color(red: 0.01, green: 0.12, blue: 0.09)
    static let blue = Color(red: 0.35, green: 0.62, blue: 1)
    static let red = Color(red: 1, green: 0.33, blue: 0.38)
    static let amber = Color(red: 1, green: 0.72, blue: 0.25)
    static let tx2 = Color(white: 1, opacity: 0.72), tx3 = Color(white: 1, opacity: 0.45)
    static func level(_ score: Int) -> (String, Color) {
        if score <= 0 { return ("ضعيفة جدًّا", red) }
        if score == 1 { return ("ضعيفة", red) }
        if score == 2 { return ("متوسّطة", amber) }
        if score == 3 { return ("قويّة", ac) }
        return ("قويّة جدًّا", ac)
    }
}

/// خزنة الآيفون المشفّرة — لمفاتيح رموز التحقّق
enum Chain {
    private static let svc = "app.pro.dera"
    static func get(_ k: String) -> Data? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: svc, kSecAttrAccount as String: k, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
    static func set(_ k: String, _ v: Data) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: svc, kSecAttrAccount as String: k]
        SecItemDelete(base as CFDictionary)
        var add = base; add[kSecValueData as String] = v; add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

struct Check: Identifiable { let id: String; let title: String; let detail: String; let ok: Bool; let weight: Int; var auto = true; var fix: String = "" }

@MainActor
final class Guard: ObservableObject {
    @Published var otps: [Sec.OTPAccount] = []
    @Published var manual: Set<String> = []
    @Published var autos: [Check] = []
    private let ud = UserDefaults.standard

    static let habits: [(id: String, title: String, detail: String, weight: Int)] = [
        ("2fa", "مفعّل التحقّق بخطوتين على إيميلي الأساسيّ", "الإيميل مفتاح كلّ حساباتك — إذا راح، راحت وياه.", 14),
        ("unique", "كلّ حساب مهمّ إله كلمة سرّ مختلفة", "إذا تسرّبت وحدة ما تنفتح الباقيات.", 14),
        ("findmy", "مفعّل «تحديد الموقع» (Find My)", "تقفل الجهاز وتمسحه إذا ضاع أو انباگ.", 8),
        ("update", "التحديث التلقائيّ للنظام شغّال", "التحديثات تسدّ ثغرات معروفة.", 8),
        ("preview", "إشعارات الرسائل ما تبيّن محتواها والجهاز مقفول", "رموز التحقّق توصل برسالة — لا تخلّيها تنقرا من شاشة القفل.", 6),
        ("simpin", "حاطّ رمز PIN على شريحة الاتّصال", "يمنع أحد ياخذ رقمك ويستلم رموزك.", 6),
        ("backup", "عندي نسخة احتياطيّة لصوري وملفّاتي", "الحماية من الضياع جزء من الأمان.", 6)]

    init() {
        if Shot.on { seedShot(); return }
        if let d = Chain.get("otps"), let v = try? JSONDecoder().decode([Sec.OTPAccount].self, from: d) { otps = v }
        manual = Set(ud.stringArray(forKey: "de_manual") ?? [])
        scan()
    }
    private func saveOTP() { guard !Shot.on else { return }; if let d = try? JSONEncoder().encode(otps) { Chain.set("otps", d) } }
    func add(_ a: Sec.OTPAccount) { otps.append(a); saveOTP() }
    func remove(_ a: Sec.OTPAccount) { otps.removeAll { $0.id == a.id }; saveOTP() }
    func toggle(_ id: String) { if manual.contains(id) { manual.remove(id) } else { manual.insert(id) }; ud.set(Array(manual), forKey: "de_manual"); Haptic.tap() }

    /// الفحوص التلقائيّة على الجهاز
    func scan() {
        var list: [Check] = []
        let ctx = LAContext()
        var err: NSError?
        let pass = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
        list.append(Check(id: "pass", title: "رمز قفل الجهاز", detail: pass ? "الجهاز مقفول برمز." : "الجهاز بلا رمز قفل — أيّ أحد يمسكه يفتح كلّشي.", ok: pass, weight: 16, fix: "الإعدادات ← بصمة الوجه ورمز الدخول ← تشغيل رمز الدخول"))
        let bio = LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        list.append(Check(id: "bio", title: "بصمة الوجه أو الإصبع", detail: bio ? "مفعّلة." : "مو مفعّلة — البصمة تخلّيك تستعمل رمز طويل بلا تعب.", ok: bio, weight: 6, fix: "الإعدادات ← بصمة الوجه ورمز الدخول"))
        let jb = Guard.jailbroken()
        list.append(Check(id: "jb", title: "سلامة النظام", detail: jb ? "لگينا علامات كسر حماية (جيلبريك) — التطبيقات تگدر توصل لبياناتك." : "ما لگينا علامات كسر حماية.", ok: !jb, weight: 12, fix: "رجّع الجهاز لنظام آبل الأصليّ"))
        let net = Guard.network()
        list.append(Check(id: "proxy", title: "وسيط الشبكة (Proxy)", detail: net.proxy ? "اتّصالك يمرّ عبر وسيط — إذا مو إنت اللي حاطّه، أحد يگدر يشوف تصفّحك." : "ماكو وسيط مفروض على اتّصالك.", ok: !net.proxy, weight: 4, fix: "الإعدادات ← Wi-Fi ← (i) ← إعداد الوسيط ← إيقاف"))
        autos = list
        vpn = net.vpn
    }
    @Published var vpn = false

    static func jailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        for p in ["/Applications/Cydia.app", "/Applications/Sileo.app", "/bin/bash", "/usr/sbin/sshd", "/etc/apt", "/private/var/lib/apt", "/usr/bin/ssh", "/var/jb"] where FileManager.default.fileExists(atPath: p) { return true }
        let probe = "/private/dera-probe-" + UUID().uuidString
        if (try? "x".write(toFile: probe, atomically: true, encoding: .utf8)) != nil { try? FileManager.default.removeItem(atPath: probe); return true }
        return false
        #endif
    }
    static func network() -> (proxy: Bool, vpn: Bool) {
        guard let s = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else { return (false, false) }
        let proxy = (s["HTTPEnable"] as? Int == 1) || (s["HTTPSEnable"] as? Int == 1) || (s["ProxyAutoConfigEnable"] as? Int == 1)
        let scoped = (s["__SCOPED__"] as? [String: Any])?.keys.map { $0.lowercased() } ?? []
        let vpn = scoped.contains { $0.hasPrefix("utun") || $0.hasPrefix("ppp") || $0.hasPrefix("ipsec") || $0.hasPrefix("tap") || $0.hasPrefix("tun") }
        return (proxy, vpn)
    }

    var score: Int {
        var got = 0, total = 0
        for c in autos { total += c.weight; if c.ok { got += c.weight } }
        for h in Guard.habits { total += h.weight; if manual.contains(h.id) { got += h.weight } }
        return total == 0 ? 0 : Int((Double(got) / Double(total) * 100).rounded())
    }

    private func seedShot() {
        otps = [Sec.OTPAccount(issuer: "Google", name: "me@gmail.com", secret: "JBSWY3DPEHPK3PXP"), Sec.OTPAccount(issuer: "GitHub", name: "dev-account", secret: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"),
                Sec.OTPAccount(issuer: "Instagram", name: "@my.page", secret: "KRSXG5CTMVRXEZLU"), Sec.OTPAccount(issuer: "Binance", name: "wallet", secret: "MFRGGZDFMZTWQ2LK")]
        manual = ["2fa", "findmy", "update", "backup"]
        autos = [Check(id: "pass", title: "رمز قفل الجهاز", detail: "الجهاز مقفول برمز.", ok: true, weight: 16), Check(id: "bio", title: "بصمة الوجه أو الإصبع", detail: "مفعّلة.", ok: true, weight: 6),
                 Check(id: "jb", title: "سلامة النظام", detail: "ما لگينا علامات كسر حماية.", ok: true, weight: 12), Check(id: "proxy", title: "وسيط الشبكة (Proxy)", detail: "ماكو وسيط مفروض على اتّصالك.", ok: true, weight: 4)]
    }
}

@main
struct DeraApp: App {
    @StateObject private var g = Guard()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(g)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(DE.ac)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            DE.bg
            RadialGradient(colors: [DE.ac.opacity(0.16), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [DE.blue.opacity(0.12), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }
}

struct RootView: View {
    @State private var tab = ["pass": 1, "gen": 1, "leak": 1, "codes": 2, "addcode": 2, "link": 3, "linkbad": 3][Shot.name] ?? 0
    private let items: [(String, String)] = [("الفحص", "shield.lefthalf.filled"), ("كلمات السرّ", "key.fill"), ("الرموز", "timer"), ("الروابط", "link")]
    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case 0: CheckupTab()
                    case 1: PasswordTab()
                    case 2: CodesTab()
                    default: LinksTab()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 2) {
                    ForEach(items.indices, id: \.self) { i in
                        let on = tab == i
                        Button { Haptic.tap(); tab = i } label: {
                            VStack(spacing: 3) { Image(systemName: items[i].1).font(.system(size: 18, weight: .semibold)); Text(items[i].0).font(rnd(10.5, .heavy)).lineLimit(1) }
                                .foregroundStyle(on ? DE.on : DE.tx3).frame(maxWidth: .infinity).frame(height: 52)
                                .background { if on { RoundedRectangle(cornerRadius: 15, style: .continuous).fill(DE.ac) } }.contentShape(Rectangle())
                        }.buttonStyle(Press())
                    }
                }
                .padding(6).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(white: 1, opacity: 0.08)))
                .padding(.horizontal, 12).padding(.bottom, 4).padding(.top, 6)
            }
        }
    }
}

func pageTitle(_ t: String, _ s: String) -> some View {
    VStack(alignment: .leading, spacing: 2) { Text(t).font(rnd(32, .black)).foregroundStyle(Color.white); Text(s).font(rnd(13)).foregroundStyle(DE.tx3) }.frame(maxWidth: .infinity, alignment: .leading)
}

// MARK: - الفحص
struct CheckupTab: View {
    @EnvironmentObject var g: Guard
    var body: some View {
        let score = g.score
        let tint = score >= 80 ? DE.ac : (score >= 55 ? DE.amber : DE.red)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pageTitle("درع", "فحص أمان جهازك وعاداتك — كلّشي يصير على الجهاز")
                HStack(spacing: 18) {
                    ZStack {
                        Circle().stroke(DE.s3, lineWidth: 12)
                        Circle().trim(from: 0, to: Double(score) / 100).stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: -2) { Text("\(score)").font(rnd(44, .black)).foregroundStyle(Color.white); Text("من 100").font(rnd(11)).foregroundStyle(DE.tx3) }
                    }.frame(width: 128, height: 128)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(score >= 80 ? "وضعك زين" : (score >= 55 ? "يحتاج شويّة شغل" : "أكو ثغرات مهمّة")).font(rnd(22, .black)).foregroundStyle(tint)
                        Text(score >= 80 ? "كمّل اللي باقي حتى توصل 100." : "صلّح اللي بالأحمر أوّل، وبعدها علّم العادات اللي تسوّيها.").font(rnd(13)).foregroundStyle(DE.tx2).lineSpacing(3)
                        if g.vpn { Text("VPN شغّال").font(rnd(11.5, .heavy)).foregroundStyle(DE.blue).padding(.horizontal, 9).padding(.vertical, 3).background(DE.blue.opacity(0.15), in: Capsule()) }
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).card(DE.s1, 24, stroke: tint.opacity(0.3))

                Text("فحص الجهاز").font(rnd(17, .heavy)).foregroundStyle(Color.white)
                VStack(spacing: 0) {
                    ForEach(Array(g.autos.enumerated()), id: \.element.id) { i, c in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: c.ok ? "checkmark.shield.fill" : "exclamationmark.shield.fill").font(.system(size: 20)).foregroundStyle(c.ok ? DE.ac : DE.red).frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.title).font(rnd(15.5, .heavy)).foregroundStyle(Color.white)
                                Text(c.detail).font(rnd(12.5)).foregroundStyle(DE.tx2).lineSpacing(2)
                                if !c.ok && !c.fix.isEmpty { Text("الحلّ: " + c.fix).font(rnd(12, .bold)).foregroundStyle(DE.amber) }
                            }
                            Spacer(minLength: 0)
                        }.padding(13)
                        if i < g.autos.count - 1 { Divider().overlay(Color(white: 1, opacity: 0.06)) }
                    }
                }.card(DE.s1, 20)

                Text("عاداتك — علّم اللي تسوّيه").font(rnd(17, .heavy)).foregroundStyle(Color.white)
                VStack(spacing: 0) {
                    ForEach(Array(Guard.habits.enumerated()), id: \.element.id) { i, h in
                        let on = g.manual.contains(h.id)
                        Button { g.toggle(h.id) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(on ? DE.ac : DE.s3).frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(h.title).font(rnd(15, .heavy)).foregroundStyle(Color.white).multilineTextAlignment(.leading)
                                    Text(h.detail).font(rnd(12.5)).foregroundStyle(DE.tx3).lineSpacing(2).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                            }.padding(13).contentShape(Rectangle())
                        }.buttonStyle(Press())
                        if i < Guard.habits.count - 1 { Divider().overlay(Color(white: 1, opacity: 0.06)) }
                    }
                }.card(DE.s1, 20)
                Button { g.scan(); Haptic.ok() } label: { Label("افحص مرّة ثانية", systemImage: "arrow.clockwise").font(rnd(14.5, .heavy)).foregroundStyle(DE.ac).frame(maxWidth: .infinity).frame(height: 46).card(DE.s1, 16, stroke: DE.ac.opacity(0.3)) }.buttonStyle(Press())
            }.padding(18)
        }
    }
}
