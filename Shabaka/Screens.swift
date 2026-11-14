import SwiftUI

// MARK: نظرة عامّة

struct OverviewScreen: View {
    @EnvironmentObject var store: Store
    @State private var showPing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header("شبكتي", "كلّ شي عن اتّصالك — محليًّا على جهازك")
                connCard
                qualityCard
                if let sub = store.conn.subnet { infoGrid(sub) }
                Text("التطبيق ما يرسل بياناتك لأيّ مكان — كلّ الفحص يصير من جهازك.").font(rnd(11.5)).foregroundStyle(SB.tx3)
            }.padding(18).padding(.bottom, 90)
        }
    }

    private var connCard: some View {
        let c = store.conn
        let on = c.ip != nil
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(on ? SB.cyan.opacity(0.18) : SB.s2).frame(width: 56, height: 56)
                    Image(systemName: c.hasWifi ? "wifi" : (on ? "antenna.radiowaves.left.and.right" : "wifi.slash")).font(.system(size: 24, weight: .bold)).foregroundStyle(on ? SB.cyan : SB.tx3)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.ssid.isEmpty ? (on ? "متّصل" : "مو متّصل بواي‑فاي") : c.ssid).font(rnd(21, .black)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text(on ? "الواجهة \(c.interface)" : "افتح الواي‑فاي حتى تبدي").font(rnd(12.5)).foregroundStyle(SB.tx3).environment(\.layoutDirection, .leftToRight)
                }
                Spacer()
                if on { Pill(text: "فعّال", color: SB.green) }
            }
            if on {
                Divider().overlay(Color.white.opacity(0.08))
                row("عنوانك المحليّ", store.conn.ip?.text ?? "—", "number")
                row("البوّابة (الراوتر)", store.conn.gateway?.text ?? "—", "network")
                if let s = store.conn.subnet { row("القناع", "\(s.mask.text)  (/\(s.prefix))", "square.grid.3x3") }
            }
        }.padding(16).card(SB.s1, 24, stroke: SB.cyan.opacity(0.2))
    }

    private var qualityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: "جودة الاتّصال")
                Spacer()
                Button { showPing = true; if !Shot.on { store.runPing("1.1.1.1", port: 443) } } label: {
                    Text(store.pinging ? "يفحص…" : "افحص").font(rnd(13, .heavy)).foregroundStyle(Color.black.opacity(0.82)).padding(.horizontal, 14).padding(.vertical, 7).background(SB.cyan, in: Capsule())
                }.buttonStyle(Press()).disabled(store.pinging)
            }
            if let p = store.ping, !p.samples.isEmpty {
                HStack(spacing: 10) {
                    gradeRing(p.grade)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(p.verdict).font(rnd(13.5, .bold)).foregroundStyle(Color.white).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            metric("\(Int(p.avg))", "ms تأخير")
                            metric("\(Int(p.jitter))", "ms تذبذب")
                            metric("\(Int(p.loss))%", "ضياع")
                        }
                    }
                }
            } else {
                Text("اضغط «افحص» حتى نقيس التأخير والتذبذب وضياع الحزم لاتّصالك بالإنترنت.").font(rnd(12.5)).foregroundStyle(SB.tx2)
            }
        }.padding(16).card(SB.s1, 24)
    }

    private func gradeRing(_ g: Int) -> some View {
        ZStack {
            Circle().stroke(SB.s3, lineWidth: 7).frame(width: 72, height: 72)
            Circle().trim(from: 0, to: CGFloat(g) / 5).stroke(SB.gradeColor(g), style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 72, height: 72)
            VStack(spacing: 0) {
                Text("\(g)").font(rnd(26, .black)).foregroundStyle(Color.white)
                Text("من ٥").font(rnd(9)).foregroundStyle(SB.tx3)
            }
        }
    }
    private func metric(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(v).font(rnd(17, .black)).foregroundStyle(SB.cyan).environment(\.layoutDirection, .leftToRight)
            Text(l).font(rnd(9.5)).foregroundStyle(SB.tx3)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoGrid(_ s: Subnet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "تفاصيل الشبكة")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                box("الشبكة", s.network.text, SB.blue)
                box("البثّ", s.broadcast.text, SB.violet)
                box("أوّل مضيف", s.firstHost.text, SB.green)
                box("آخر مضيف", s.lastHost.text, SB.amber)
                box("عدد الأجهزة الممكنة", "\(s.usable)", SB.cyan)
                box("نوع العنوان", store.conn.ip?.kind ?? "—", SB.tx2)
            }
        }
    }
    private func box(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(l).font(rnd(11.5)).foregroundStyle(SB.tx3)
            monoText(v, 15, .heavy).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).card(SB.s1, 16, stroke: c.opacity(0.18))
    }
    private func row(_ l: String, _ v: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(SB.cyan).frame(width: 22)
            Text(l).font(rnd(13.5)).foregroundStyle(SB.tx2)
            Spacer()
            monoText(v, 14, .bold).foregroundStyle(Color.white)
        }
    }
}

func header(_ t: String, _ s: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(t).font(rnd(32, .black)).foregroundStyle(Color.white)
        Text(s).font(rnd(13)).foregroundStyle(SB.tx3)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
}

// MARK: ماسح الأجهزة

struct ScannerScreen: View {
    @EnvironmentObject var store: Store
    @State private var sel: Device? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header("أجهزة الشبكة", store.conn.subnet != nil ? "مين متّصل على نفس شبكتك" : "اتّصل بواي‑فاي أوّل")
                scanBar
                ForEach(store.devices) { d in
                    Button { sel = d; Haptic.tap() } label: { deviceRow(d) }.buttonStyle(Press())
                }
                if store.devices.isEmpty && !store.scanning {
                    empty
                }
            }.padding(18).padding(.bottom, 90)
        }
        .sheet(item: $sel) { d in DeviceSheet(device: d) { sel = nil }.environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
    }

    private var scanBar: some View {
        HStack(spacing: 12) {
            Button { if !Shot.on { store.scan() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: store.scanning ? "arrow.triangle.2.circlepath" : "dot.radiowaves.left.and.right").font(.system(size: 15, weight: .black))
                        .rotationEffect(.degrees(store.scanning ? 360 : 0)).animation(store.scanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: store.scanning)
                    Text(store.scanning ? "يفحص الشبكة…" : "افحص الشبكة").font(rnd(16, .black))
                }.foregroundStyle(Color.black.opacity(0.82)).frame(maxWidth: .infinity).frame(height: 52).background(SB.cyan, in: Capsule())
            }.buttonStyle(Press()).disabled(store.scanning || store.conn.subnet == nil)
            VStack(spacing: 0) {
                Text("\(store.devices.count)").font(rnd(22, .black)).foregroundStyle(Color.white)
                Text("جهاز").font(rnd(10)).foregroundStyle(SB.tx3)
            }.frame(width: 60, height: 52).card(SB.s1, 16)
        }
    }

    private func deviceRow(_ d: Device) -> some View {
        let risky = d.ports.contains { Ports.risk($0) == 2 }
        return HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(d.isGateway ? SB.blue.opacity(0.18) : (d.isSelf ? SB.cyan.opacity(0.18) : SB.s2)).frame(width: 48, height: 48)
                Image(systemName: icon(d)).font(.system(size: 20, weight: .semibold)).foregroundStyle(d.isGateway ? SB.blue : (d.isSelf ? SB.cyan : SB.tx2))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(d.name.isEmpty ? (d.vendor.isEmpty ? "جهاز" : d.vendor) : d.name).font(rnd(15.5, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                HStack(spacing: 6) {
                    monoText(d.ip.text, 12.5, .semibold).foregroundStyle(SB.tx2)
                    if !d.vendor.isEmpty && !d.name.contains(d.vendor) { Text("· \(d.vendor)").font(rnd(11.5)).foregroundStyle(SB.tx3).lineLimit(1) }
                }
            }
            Spacer(minLength: 4)
            if risky { Pill(text: "خطر", color: SB.red) }
            else if let l = d.latency { Text("\(Int(l))ms").font(rnd(11.5, .bold)).foregroundStyle(SB.tx3).environment(\.layoutDirection, .leftToRight) }
            Image(systemName: "chevron.left").font(.system(size: 12, weight: .black)).foregroundStyle(SB.tx3)
        }.padding(11).card(SB.s1, 18, stroke: risky ? SB.red.opacity(0.3) : Color.white.opacity(0.06))
    }
    private func icon(_ d: Device) -> String {
        if d.isGateway { return "network" }
        if d.isSelf { return "iphone" }
        let v = d.vendor.lowercased()
        if v.contains("apple") { return "applelogo" }
        if d.name.contains("طابعة") || d.ports.contains(9100) { return "printer.fill" }
        if d.name.contains("كاميرا") || d.ports.contains(554) { return "web.camera.fill" }
        if d.name.contains("تلفزيون") || d.name.lowercased().contains("roku") { return "tv.fill" }
        if v.contains("raspberry") { return "cpu.fill" }
        if d.name.contains("أندرويد") || v.contains("samsung") || v.contains("xiaomi") || v.contains("huawei") { return "candybarphone" }
        return "desktopcomputer"
    }
    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 40)).foregroundStyle(SB.tx3)
            Text("اضغط «افحص الشبكة» حتى نلگى كلّ الأجهزة المتّصلة").font(rnd(13.5)).foregroundStyle(SB.tx2).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

struct DeviceSheet: View {
    let device: Device
    let done: () -> Void
    @EnvironmentObject var store: Store
    @State private var ports: [Int] = []
    @State private var scanning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name.isEmpty ? device.vendor : device.name).font(rnd(24, .black)).foregroundStyle(Color.white)
                        monoText(device.ip.text, 14, .bold).foregroundStyle(SB.cyan)
                    }
                    Spacer()
                    Button(action: done) { Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(Color.white).frame(width: 38, height: 38).background(SB.s2, in: Circle()) }
                }
                let info: [(String, String)] = [("الشركة", device.vendor.isEmpty ? "غير معروفة" : device.vendor), ("MAC", device.mac.isEmpty ? "—" : device.mac), ("الاستجابة", device.latency != nil ? "\(Int(device.latency!)) ms" : "—"), ("النوع", device.ip.kind)]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<info.count, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(info[i].0).font(rnd(11)).foregroundStyle(SB.tx3)
                            Text(info[i].1).font(.system(size: 14, weight: .bold, design: info[i].0 == "MAC" ? .monospaced : .rounded)).foregroundStyle(Color.white).lineLimit(1).minimumScaleFactor(0.7).environment(\.layoutDirection, info[i].0 == "الشركة" ? .rightToLeft : .leftToRight)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).card(SB.s1, 14)
                    }
                }
                HStack {
                    SectionTitle(text: "المنافذ المفتوحة")
                    Spacer()
                    Button { runScan() } label: { Text(scanning ? "يفحص…" : "افحص المنافذ").font(rnd(12.5, .heavy)).foregroundStyle(Color.black.opacity(0.82)).padding(.horizontal, 12).padding(.vertical, 6).background(SB.cyan, in: Capsule()) }.buttonStyle(Press()).disabled(scanning)
                }
                let shown = ports.isEmpty ? device.ports : ports
                if shown.isEmpty {
                    Text(scanning ? "يفحص…" : "ما لگينا منافذ مفتوحة — افحص حتى تتأكّد").font(rnd(12.5)).foregroundStyle(SB.tx2)
                } else {
                    ForEach(shown.sorted(), id: \.self) { p in portRow(p) }
                    let audit = Audit.device(openPorts: shown)
                    if audit.contains(where: { $0.level > 0 }) {
                        SectionTitle(text: "ملاحظات أمان").padding(.top, 4)
                        ForEach(0..<audit.count, id: \.self) { i in if audit[i].level > 0 { auditRow(audit[i]) } }
                    }
                }
            }.padding(20).padding(.bottom, 30)
        }.background(SB.bg.ignoresSafeArea())
        .onAppear { if Shot.on { ports = device.ports } }
    }
    private func runScan() {
        guard !Shot.on, !scanning else { return }
        scanning = true; ports = []
        Task {
            let found = await LiveNet.scanPorts(device.ip.text, ports: Ports.common) { p in Task { @MainActor in if !ports.contains(p) { ports.append(p) } } }
            await MainActor.run { ports = found; scanning = false }
        }
    }
    private func portRow(_ p: Int) -> some View {
        let info = Ports.info(p)
        return HStack(spacing: 11) {
            monoText("\(p)", 15, .black).foregroundStyle(SB.riskColor(info.risk)).frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(info.name) · \(info.proto)").font(rnd(14, .heavy)).foregroundStyle(Color.white)
                Text(info.note).font(rnd(11.5)).foregroundStyle(SB.tx3).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            Circle().fill(SB.riskColor(info.risk)).frame(width: 9, height: 9)
        }.padding(11).card(SB.s1, 14)
    }
    private func auditRow(_ it: SecurityItem) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: it.level == 2 ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill").font(.system(size: 17)).foregroundStyle(SB.riskColor(it.level))
            VStack(alignment: .leading, spacing: 2) {
                Text(it.title).font(rnd(13.5, .heavy)).foregroundStyle(Color.white)
                Text(it.detail).font(rnd(12)).foregroundStyle(SB.tx2)
            }
            Spacer(minLength: 0)
        }.padding(11).card(SB.riskColor(it.level).opacity(0.1), 14, stroke: SB.riskColor(it.level).opacity(0.3))
    }
}
