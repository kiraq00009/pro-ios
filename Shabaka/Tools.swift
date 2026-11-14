import SwiftUI

// MARK: أدوات

struct ToolsScreen: View {
    @State private var tool: String? = nil
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header("أدوات الشبكة", "صندوق عدّة كامل — كلّه يشتغل على جهازك")
                grid
            }.padding(18).padding(.bottom, 90)
        }
        .onAppear { if Shot.isAny("subnet", "wol", "dns", "websec", "pubip") { tool = Shot.name } }
        .sheet(item: Binding(get: { tool.map { Tool(id: $0) } }, set: { tool = $0?.id })) { t in
            toolSheet(t.id).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark)
        }
    }
    struct Tool: Identifiable { let id: String }
    private let tools: [(String, String, String, Color)] = [
        ("subnet", "حاسبة الشبكات", "square.grid.3x3.fill", SB.blue),
        ("ping", "بنگ وجودة", "waveform.path.ecg", SB.green),
        ("ports", "فاحص المنافذ", "number.square.fill", SB.amber),
        ("websec", "فحص أمان موقع", "lock.shield.fill", SB.red),
        ("dns", "بحث DNS", "globe", SB.cyan),
        ("pubip", "عنوانك العامّ", "globe.badge.chevron.backward", SB.violet),
        ("wol", "إيقاظ جهاز (WOL)", "power", SB.violet),
        ("ref", "دليل المنافذ", "list.bullet.rectangle.fill", SB.tx2)
    ]
    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(0..<tools.count, id: \.self) { i in
                Button { tool = tools[i].0; Haptic.tap() } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: tools[i].2).font(.system(size: 22, weight: .bold)).foregroundStyle(tools[i].3)
                        Text(tools[i].1).font(rnd(15, .heavy)).foregroundStyle(Color.white).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading).padding(14).card(SB.s1, 20, stroke: tools[i].3.opacity(0.22))
                }.buttonStyle(Press())
            }
        }
    }
    @ViewBuilder private func toolSheet(_ id: String) -> some View {
        switch id {
        case "subnet": SubnetTool()
        case "ping": PingTool()
        case "ports": PortsTool()
        case "websec": WebSecTool()
        case "dns": DNSTool()
        case "pubip": PublicIPTool()
        case "wol": WOLTool()
        default: PortRefTool()
        }
    }
}

// فحص أمان موقع — رؤوس الأمان
struct WebSecTool: View {
    @State private var host = "dawwirli.watch"
    @State private var result: (checks: [HeaderCheck], grade: String, score: Int)? = Shot.on ? WebSec.analyze(headers: ["Server": "cloudflare", "Strict-Transport-Security": "max-age=31536000", "X-Content-Type-Options": "nosniff"]) : nil
    @State private var server = Shot.on ? "cloudflare" : ""
    @State private var busy = false
    @State private var err = ""
    var body: some View {
        ToolShell(title: "فحص أمان موقع") {
            Text("يفحص رؤوس الأمان اللي يرجّعها أيّ موقع — هذا جوهر تدقيق أمان الويب (ethical web audit).").font(rnd(12.5)).foregroundStyle(SB.tx2)
            Field(label: "النطاق", text: $host, placeholder: "example.com")
            goButton(busy ? "يفحص…" : "افحص", busy) { run() }
            if !err.isEmpty { Text(err).font(rnd(13, .bold)).foregroundStyle(SB.red) }
            if let r = result {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(SB.s3, lineWidth: 8).frame(width: 78, height: 78)
                        Circle().trim(from: 0, to: CGFloat(r.score) / 100).stroke(gradeC(r.grade), style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 78, height: 78)
                        Text(r.grade).font(rnd(30, .black)).foregroundStyle(Color.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("درجة الأمان \(r.score)/100").font(rnd(16, .heavy)).foregroundStyle(Color.white)
                        if !server.isEmpty { Text("الخادم: \(server)").font(rnd(12)).foregroundStyle(SB.tx3).environment(\.layoutDirection, .leftToRight) }
                    }
                    Spacer(minLength: 0)
                }.padding(14).card(SB.s1, 18)
                ForEach(0..<r.checks.count, id: \.self) { i in
                    let c = r.checks[i]
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: c.present ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(c.present ? SB.green : SB.red).font(.system(size: 17))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name).font(rnd(13.5, .heavy)).foregroundStyle(Color.white).environment(\.layoutDirection, .leftToRight).frame(maxWidth: .infinity, alignment: .leading)
                            Text(c.advice).font(rnd(11.5)).foregroundStyle(SB.tx3)
                        }
                    }.padding(11).card(SB.s1, 13)
                }
            } else if !busy {
                Text("نطلب الصفحة ونحلّل رؤوس HSTS و CSP و X-Frame وغيرها، ونعطيك درجة.").font(rnd(12.5)).foregroundStyle(SB.tx3)
            }
        }
    }
    private func gradeC(_ g: String) -> Color { g == "A" ? SB.green : (g == "B" ? SB.cyan : (g == "C" ? SB.amber : SB.red)) }
    private func run() {
        guard !Shot.on, !busy else { return }
        busy = true; err = ""; result = nil
        Task {
            if let r = await LiveNet.httpHeaders(host.trimmingCharacters(in: .whitespaces)) {
                let a = WebSec.analyze(headers: r.headers)
                await MainActor.run { result = a; server = r.server; busy = false }
            } else {
                await MainActor.run { err = "ما گدرنا نوصل الموقع — تأكّد من الاسم والاتّصال."; busy = false }
            }
        }
    }
}

// عنوانك العامّ
struct PublicIPTool: View {
    @State private var ip = Shot.on ? "91.106.44.23" : ""
    @State private var busy = false
    @State private var done = Shot.on
    var body: some View {
        ToolShell(title: "عنوانك العامّ") {
            Text("العنوان اللي يشوفه الإنترنت إلك (غير عنوانك المحليّ). مفيد تعرف إذا VPN شغّال.").font(rnd(12.5)).foregroundStyle(SB.tx2)
            goButton(busy ? "…" : "اعرف عنواني العامّ", busy) { run() }
            if done {
                if ip.isEmpty { Text("ما گدرنا نجيبه — تأكّد من الاتّصال.").font(rnd(13)).foregroundStyle(SB.red) }
                else {
                    resultBox { HStack { Text("عنوانك العامّ").font(rnd(13.5)).foregroundStyle(SB.tx2); Spacer(); monoText(ip, 18, .black).foregroundStyle(SB.cyan) } }
                }
            }
        }
    }
    private func run() {
        guard !Shot.on, !busy else { return }
        busy = true; done = false
        Task {
            let r = await LiveNet.publicIP()
            await MainActor.run { ip = r?.ip ?? ""; busy = false; done = true }
        }
    }
}

struct ToolShell<V: View>: View {
    let title: String
    @ViewBuilder let content: () -> V
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title).font(rnd(24, .black)).foregroundStyle(Color.white)
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(Color.white).frame(width: 38, height: 38).background(SB.s2, in: Circle()) }
                }
                content()
            }.padding(20).padding(.bottom, 30)
        }.background(SB.bg.ignoresSafeArea())
    }
}

struct Field: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(rnd(12.5, .bold)).foregroundStyle(SB.tx3)
            TextField(placeholder, text: $text)
                .font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundStyle(Color.white)
                .keyboardType(keyboard).autocorrectionDisabled().textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
                .padding(13).background(SB.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08)))
        }
    }
}

func goButton(_ t: String, _ busy: Bool = false, _ act: @escaping () -> Void) -> some View {
    Button(action: act) {
        Text(busy ? "…" : t).font(rnd(16, .black)).foregroundStyle(Color.black.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 52).background(SB.cyan, in: Capsule())
    }.buttonStyle(Press()).disabled(busy)
}

func resultBox<V: View>(@ViewBuilder _ c: () -> V) -> some View {
    VStack(alignment: .leading, spacing: 9) { c() }.frame(maxWidth: .infinity, alignment: .leading).padding(15).card(SB.s1, 18)
}

// حاسبة الشبكات
struct SubnetTool: View {
    @State private var cidr = "192.168.1.37/24"
    @State private var result: Subnet? = Subnet(cidr: "192.168.1.37/24")
    var body: some View {
        ToolShell(title: "حاسبة الشبكات") {
            Field(label: "العنوان / البادئة (CIDR)", text: $cidr, placeholder: "192.168.1.0/24")
            goButton("احسب") { result = Subnet(cidr: cidr.trimmingCharacters(in: .whitespaces)) }
            if let s = result {
                resultBox {
                    line("الشبكة", s.network.text, SB.blue)
                    line("القناع", "\(s.mask.text)  /\(s.prefix)", SB.cyan)
                    line("البثّ", s.broadcast.text, SB.violet)
                    line("أوّل مضيف", s.firstHost.text, SB.green)
                    line("آخر مضيف", s.lastHost.text, SB.green)
                    line("Wildcard", s.wildcard.text, SB.amber)
                    line("عدد الأجهزة", "\(s.usable)", SB.tx2)
                }
                if s.prefix < 24 {
                    Text("تقسيم إلى /\(s.prefix + 2)").font(rnd(13, .heavy)).foregroundStyle(SB.tx2)
                    ForEach(Array(s.split(into: min(32, s.prefix + 2)).prefix(8)), id: \.network.raw) { sub in
                        monoText("\(sub.network.text)/\(sub.prefix)", 13, .semibold).foregroundStyle(SB.tx2)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 7).background(SB.s1, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                Text("صيغة غير صحيحة — مثال: 10.0.0.0/8").font(rnd(13)).foregroundStyle(SB.red)
            }
        }
    }
    private func line(_ l: String, _ v: String, _ c: Color) -> some View {
        HStack { Text(l).font(rnd(13.5)).foregroundStyle(SB.tx2); Spacer(); monoText(v, 14.5, .heavy).foregroundStyle(c) }
    }
}

// بنگ
struct PingTool: View {
    @EnvironmentObject var store: Store
    @State private var host = "1.1.1.1"
    @State private var port = "443"
    var body: some View {
        ToolShell(title: "بنگ وجودة") {
            Field(label: "المضيف", text: $host, placeholder: "1.1.1.1 أو google.com")
            Field(label: "المنفذ", text: $port, placeholder: "443", keyboard: .numberPad)
            goButton(store.pinging ? "يفحص…" : "ابدي", store.pinging) { if !Shot.on { store.runPing(host.trimmingCharacters(in: .whitespaces), port: Int(port) ?? 443) } }
            if let p = store.ping {
                resultBox {
                    HStack {
                        big("\(Int(p.avg))", "متوسّط ms", SB.cyan)
                        big("\(Int(p.min))", "أقلّ", SB.green)
                        big("\(Int(p.max))", "أعلى", SB.amber)
                    }
                    HStack {
                        big("\(Int(p.jitter))", "تذبذب", SB.violet)
                        big("\(Int(p.loss))%", "ضياع", p.loss > 2 ? SB.red : SB.green)
                        big("\(p.samples.count)/\(p.sent)", "وصلت", SB.tx2)
                    }
                    Text(p.verdict).font(rnd(13.5, .bold)).foregroundStyle(SB.gradeColor(p.grade)).padding(.top, 2)
                }
            } else {
                Text("نفتح اتّصال TCP مرّات متتالية ونقيس الزمن — هيك نعرف ثبات اتّصالك.").font(rnd(12.5)).foregroundStyle(SB.tx2)
            }
        }
    }
    private func big(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) { Text(v).font(rnd(22, .black)).foregroundStyle(c).environment(\.layoutDirection, .leftToRight); Text(l).font(rnd(10.5)).foregroundStyle(SB.tx3) }.frame(maxWidth: .infinity)
    }
}

// فاحص منافذ
struct PortsTool: View {
    @State private var host = "192.168.1.1"
    @State private var found: [Int] = []
    @State private var scanning = false
    @State private var done = false
    var body: some View {
        ToolShell(title: "فاحص المنافذ") {
            Field(label: "عنوان الجهاز", text: $host, placeholder: "192.168.1.1")
            goButton(scanning ? "يفحص…" : "افحص المنافذ الشائعة", scanning) { run() }
            if Shot.on || done || scanning {
                let list = Shot.on ? [22, 80, 443, 445] : found
                if list.isEmpty && !scanning {
                    Text("ما لگينا منافذ مفتوحة — الجهاز يبيّن مقفول زين 👍").font(rnd(13)).foregroundStyle(SB.green)
                } else {
                    ForEach(list.sorted(), id: \.self) { p in
                        let info = Ports.info(p)
                        HStack(spacing: 10) {
                            monoText("\(p)", 15, .black).foregroundStyle(SB.riskColor(info.risk)).frame(width: 50, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(info.name).font(rnd(14, .heavy)).foregroundStyle(Color.white)
                                Text(info.note).font(rnd(11)).foregroundStyle(SB.tx3).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            Spacer(minLength: 2)
                            Circle().fill(SB.riskColor(info.risk)).frame(width: 9, height: 9)
                        }.padding(11).card(SB.s1, 14)
                    }
                }
            } else {
                Text("نجرّب ٢١ منفذ شائع ونبيّنلك المفتوح منها وخطورته.").font(rnd(12.5)).foregroundStyle(SB.tx2)
            }
        }
    }
    private func run() {
        guard !Shot.on, !scanning else { return }
        scanning = true; found = []; done = false
        Task {
            let f = await LiveNet.scanPorts(host.trimmingCharacters(in: .whitespaces), ports: Ports.common) { p in Task { @MainActor in if !found.contains(p) { found.append(p) } } }
            await MainActor.run { found = f; scanning = false; done = true }
        }
    }
}

// DNS
struct DNSTool: View {
    @State private var host = "dawwirli.watch"
    @State private var ips: [String] = []
    @State private var ms: Double = 0
    @State private var busy = false
    @State private var done = false
    var body: some View {
        ToolShell(title: "بحث DNS") {
            Field(label: "اسم النطاق", text: $host, placeholder: "google.com")
            goButton(busy ? "…" : "ابحث", busy) { run() }
            if Shot.on {
                resultBox {
                    Text("زمن الاستجابة: 24 ms").font(rnd(13.5, .bold)).foregroundStyle(SB.green)
                    ForEach(["172.67.142.11", "104.21.48.9", "2606:4700:3035::6815:3009"], id: \.self) { ip in monoText(ip, 14, .semibold).foregroundStyle(SB.cyan) }
                }
            } else if done {
                if ips.isEmpty { Text("ما انحلّ الاسم — تأكّد من الكتابة والاتّصال").font(rnd(13)).foregroundStyle(SB.red) }
                else {
                    resultBox {
                        Text("زمن الاستجابة: \(Int(ms)) ms").font(rnd(13.5, .bold)).foregroundStyle(SB.green)
                        ForEach(ips, id: \.self) { ip in monoText(ip, 14, .semibold).foregroundStyle(SB.cyan) }
                    }
                }
            } else {
                Text("نترجم اسم النطاق لعناوين IP ونقيس وقت الاستعلام.").font(rnd(12.5)).foregroundStyle(SB.tx2)
            }
        }
    }
    private func run() {
        guard !Shot.on, !busy else { return }
        busy = true; done = false
        Task {
            let r = await LiveNet.resolve(host.trimmingCharacters(in: .whitespaces))
            await MainActor.run { ips = r?.ips ?? []; ms = r?.ms ?? 0; busy = false; done = true }
        }
    }
}

// WOL
struct WOLTool: View {
    @State private var mac = "AC:84:C6:11:22:33"
    @State private var bc = "255.255.255.255"
    @State private var msg = ""
    var body: some View {
        ToolShell(title: "إيقاظ جهاز") {
            Text("أرسل حزمة «الإيقاظ السحريّة» لجهاز على شبكتك حتى يشتغل عن بعد (لازم الجهاز يدعم Wake‑on‑LAN).").font(rnd(12.5)).foregroundStyle(SB.tx2)
            Field(label: "عنوان MAC", text: $mac, placeholder: "AC:84:C6:11:22:33")
            Field(label: "عنوان البثّ", text: $bc, placeholder: "255.255.255.255")
            goButton("أيقظ الجهاز") {
                if Shot.on { msg = "انبعثت الحزمة ✓"; return }
                let ok = LiveNet.wake(mac: mac.trimmingCharacters(in: .whitespaces), broadcast: bc.trimmingCharacters(in: .whitespaces))
                msg = ok ? "انبعثت الحزمة ✓ — الجهاز لازم يصحى" : "صيغة MAC غلط (لازم ٦ بايت)"
                Haptic.ok()
            }
            if !msg.isEmpty { Text(msg).font(rnd(13.5, .bold)).foregroundStyle(msg.contains("✓") ? SB.green : SB.red) }
            if let pkt = WOL.magicPacket(mac: mac), Shot.on || !msg.isEmpty {
                Text("حجم الحزمة: \(pkt.count) بايت (6 رأس + 16 تكرار)").font(rnd(11.5)).foregroundStyle(SB.tx3)
            }
        }
    }
}

// دليل المنافذ
struct PortRefTool: View {
    @State private var q = ""
    var body: some View {
        ToolShell(title: "دليل المنافذ") {
            Field(label: "بحث برقم أو اسم", text: $q, placeholder: "مثال: 443 أو ssh")
            let all = Ports.known.values.sorted { $0.port < $1.port }
            let list = q.isEmpty ? all : all.filter { "\($0.port)".contains(q) || $0.name.lowercased().contains(q.lowercased()) }
            ForEach(list, id: \.port) { info in
                HStack(spacing: 11) {
                    monoText("\(info.port)", 15, .black).foregroundStyle(SB.riskColor(info.risk)).frame(width: 52, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(info.name) · \(info.proto)").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                        Text(info.note).font(rnd(11)).foregroundStyle(SB.tx3)
                    }
                    Spacer(minLength: 2)
                    Circle().fill(SB.riskColor(info.risk)).frame(width: 8, height: 8)
                }.padding(10).card(SB.s1, 13)
            }
        }
    }
}

// MARK: أمان سيبرانيّ — تقرير الثغرات

struct SecurityScreen: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let input = store.devices.map { (name: $0.name.isEmpty ? $0.vendor : $0.name, ip: $0.ip.text, ports: $0.ports) }
        let rep = store.devices.isEmpty ? nil : Report.build(input)
        let creds = Array(Set(store.devices.map { $0.vendor })).flatMap { DefaultCreds.forVendor($0) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header("أمن سيبرانيّ", "تدقيق أخلاقيّ دفاعيّ لشبكتك — ثغرات أجهزتك وشلون تسدّها")
                if let rep = rep {
                    scoreCard(rep)
                    if rep.vulns.isEmpty {
                        okCard
                    } else {
                        HStack {
                            SectionTitle(text: "الثغرات المكتشفة")
                            Spacer()
                            Text("\(rep.vulns.count)").font(rnd(14, .black)).foregroundStyle(SB.red)
                        }
                        ForEach(0..<rep.vulns.count, id: \.self) { i in vulnCard(rep.vulns[i]) }
                    }
                    if !creds.isEmpty { credsSection(creds) }
                    tips
                    disclaimer
                } else { empty }
            }.padding(18).padding(.bottom, 90)
        }
    }

    private func sevColor(_ s: Int) -> Color { s >= 4 ? SB.red : (s == 3 ? Color(red: 1, green: 0.55, blue: 0.3) : (s == 2 ? SB.amber : SB.cyan)) }
    private func sevLabel(_ s: Int) -> String { ["", "منخفض", "متوسّط", "عالي", "حرج"][max(0, min(4, s))] }

    private func scoreCard(_ rep: (vulns: [Vuln], score: Int, critical: Int, high: Int)) -> some View {
        let c: Color = rep.score >= 80 ? SB.green : (rep.score >= 55 ? SB.amber : SB.red)
        return VStack(spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(SB.s3, lineWidth: 9).frame(width: 92, height: 92)
                    Circle().trim(from: 0, to: CGFloat(rep.score) / 100).stroke(c, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 92, height: 92)
                    VStack(spacing: 0) {
                        Text("\(rep.score)").font(rnd(29, .black)).foregroundStyle(Color.white)
                        Text("من ١٠٠").font(rnd(9, .bold)).foregroundStyle(SB.tx3)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(rep.score >= 80 ? "شبكتك آمنة" : (rep.score >= 55 ? "فيها نقاط ضعف" : "تحتاج انتباه")).font(rnd(19, .black)).foregroundStyle(Color.white)
                    Text("\(store.devices.count) جهاز مفحوص").font(rnd(12.5)).foregroundStyle(SB.tx3)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                countBox("\(rep.critical)", "حرجة", SB.red)
                countBox("\(rep.high)", "عالية", Color(red: 1, green: 0.55, blue: 0.3))
                countBox("\(store.conn.hasWifi ? "✓" : "؟")", "تشفير", store.conn.hasWifi ? SB.green : SB.amber)
            }
        }.padding(16).card(SB.s1, 24, stroke: c.opacity(0.3))
    }
    private func countBox(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) { Text(v).font(rnd(22, .black)).foregroundStyle(c); Text(l).font(rnd(10.5)).foregroundStyle(SB.tx3) }.frame(maxWidth: .infinity).padding(.vertical, 9).background(SB.bg, in: RoundedRectangle(cornerRadius: 13))
    }

    private func vulnCard(_ v: Vuln) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Pill(text: sevLabel(v.advisory.severity), color: sevColor(v.advisory.severity))
                Text(v.advisory.title).font(rnd(14.5, .heavy)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            Text(v.advisory.detail).font(rnd(12.5)).foregroundStyle(SB.tx2).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(SB.green).padding(.top, 2)
                Text(v.advisory.fix).font(rnd(12, .bold)).foregroundStyle(SB.green).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Text(v.device).font(rnd(11.5, .bold)).foregroundStyle(SB.tx3)
                monoText(v.ip, 11, .semibold).foregroundStyle(SB.tx3)
            }
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading).card(sevColor(v.advisory.severity).opacity(0.08), 16, stroke: sevColor(v.advisory.severity).opacity(0.3))
    }

    private func credsSection(_ creds: [DefaultCred]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "افحص كلمات السرّ الافتراضيّة")
            Text("أجهزة على شبكتك ممكن تكون بباسورد المصنع — جرّب تسجّل الدخول عليها بنفسك، وإذا اشتغل غيّره فورًا.").font(rnd(12)).foregroundStyle(SB.tx3)
            ForEach(0..<creds.count, id: \.self) { i in
                let c = creds[i]
                HStack(spacing: 11) {
                    Image(systemName: "key.horizontal.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(SB.amber).frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.device).font(rnd(13.5, .heavy)).foregroundStyle(Color.white)
                        Text("المستخدم: \(c.user) · الباسورد: \(c.pass)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(SB.tx2).environment(\.layoutDirection, .leftToRight)
                    }
                    Spacer(minLength: 0)
                }.padding(11).card(SB.s1, 13)
            }
        }
    }

    private var okCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill").font(.system(size: 26)).foregroundStyle(SB.green)
            Text("ما لگينا ثغرات خطرة على أجهزتك — عاش! 👏").font(rnd(14, .heavy)).foregroundStyle(Color.white)
            Spacer(minLength: 0)
        }.padding(14).card(SB.green.opacity(0.1), 18, stroke: SB.green.opacity(0.3))
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "نصائح تحصين")
            ForEach(tipList, id: \.0) { t in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: t.1).font(.system(size: 15, weight: .bold)).foregroundStyle(SB.cyan).frame(width: 24)
                    Text(t.0).font(rnd(13)).foregroundStyle(SB.tx2).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }.padding(.vertical, 2)
            }
        }.padding(15).card(SB.s1, 20)
    }
    private let tipList: [(String, String)] = [
        ("بدّل باسورد الراوتر الافتراضيّ وخلّيه قويّ.", "key.fill"),
        ("شغّل تشفير WPA3 أو WPA2 وأقفل WPS.", "lock.fill"),
        ("اقفل المنافذ اللي ما تستعملها (تلنت، SMB، RDP).", "xmark.shield.fill"),
        ("سوّي شبكة ضيوف منفصلة لأجهزة إنترنت الأشياء.", "person.2.fill"),
        ("حدّث فيرموير الراوتر والكاميرات بانتظام.", "arrow.triangle.2.circlepath")
    ]
    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill").font(.system(size: 13)).foregroundStyle(SB.tx3)
            Text("هذا تدقيق دفاعيّ — افحص بس الأجهزة والشبكات اللي تملكها أو عندك إذن عليها. التطبيق ما يخترق ولا يهاجم شي.").font(rnd(11)).foregroundStyle(SB.tx3).fixedSize(horizontal: false, vertical: true)
        }.padding(12).card(SB.s1, 14)
    }
    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield").font(.system(size: 40)).foregroundStyle(SB.tx3)
            Text("روح لتبويب «الأجهزة» وافحص الشبكة، وبعدها نحلّل ثغراتها هنا.").font(rnd(13.5)).foregroundStyle(SB.tx2).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 50)
    }
}
