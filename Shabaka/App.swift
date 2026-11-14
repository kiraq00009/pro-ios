import SwiftUI

enum SB {
    static let bg = Color(red: 0.03, green: 0.05, blue: 0.07)
    static let s1 = Color(red: 0.07, green: 0.10, blue: 0.14)
    static let s2 = Color(red: 0.11, green: 0.16, blue: 0.21)
    static let s3 = Color(red: 0.16, green: 0.22, blue: 0.29)
    static let cyan = Color(red: 0.26, green: 0.86, blue: 0.95)
    static let blue = Color(red: 0.33, green: 0.56, blue: 1)
    static let green = Color(red: 0.32, green: 0.9, blue: 0.56)
    static let amber = Color(red: 1, green: 0.74, blue: 0.3)
    static let red = Color(red: 1, green: 0.42, blue: 0.42)
    static let violet = Color(red: 0.62, green: 0.5, blue: 1)
    static let tx2 = Color(white: 1, opacity: 0.74), tx3 = Color(white: 1, opacity: 0.46)
    static func riskColor(_ r: Int) -> Color { r == 2 ? red : (r == 1 ? amber : green) }
    static func gradeColor(_ g: Int) -> Color { g >= 4 ? green : (g == 3 ? amber : red) }
}

@MainActor
final class Store: ObservableObject {
    @Published var conn = ConnInfo()
    @Published var devices: [Device] = []
    @Published var scanning = false
    @Published var scanDone = 0
    @Published var ping: PingStat? = nil
    @Published var pinging = false
    @Published var loaded = false

    func refresh() {
        guard !Shot.on else { return }
        Perms.shared.requestLocation()
        conn = LiveNet.localInfo()
        loaded = true
    }

    func scan() {
        guard !Shot.on, !scanning, let sub = conn.subnet else { return }
        scanning = true; devices = []; scanDone = 0
        let selfIP = conn.ip, gw = conn.gateway
        Task {
            await LiveNet.scanLAN(sub, gateway: gw, selfIP: selfIP, onDevice: { d in
                Task { @MainActor in
                    var dev = d
                    dev.isSelf = d.ip == selfIP
                    dev.isGateway = d.ip == gw
                    if dev.isGateway { dev.name = "الراوتر (البوّابة)" }
                    if dev.isSelf { dev.name = "جهازك" }
                    if !self.devices.contains(where: { $0.ip == dev.ip }) {
                        self.devices.append(dev)
                        self.devices.sort { $0.ip.raw < $1.ip.raw }
                    }
                }
            }, done: { n in
                Task { @MainActor in self.scanDone = n; self.scanning = false; self.conn.localDenied = (n == 0) }
            })
        }
    }

    func runPing(_ host: String, port: Int) {
        guard !Shot.on, !pinging else { return }
        pinging = true; ping = nil
        Task {
            let final = await LiveNet.ping(host, port: port) { s in Task { @MainActor in self.ping = s } }
            await MainActor.run { self.ping = final; self.pinging = false }
        }
    }

    // بيانات العرض للتصوير
    static func demoConn() -> ConnInfo {
        var c = ConnInfo()
        c.ssid = "Khairi_5G"
        c.ip = IPv4("192.168.1.37")
        c.subnet = Subnet(cidr: "192.168.1.37/24")
        c.gateway = IPv4("192.168.1.1")
        c.interface = "en0"; c.hasWifi = true
        return c
    }
    static func demoDevices() -> [Device] {
        func d(_ ip: String, _ name: String, _ vendor: String, _ mac: String, _ ports: [Int], self_: Bool = false, gw: Bool = false) -> Device {
            var x = Device(ip: IPv4(ip)!); x.name = name; x.vendor = vendor; x.mac = mac; x.ports = ports; x.isSelf = self_; x.isGateway = gw
            x.latency = Double(Int.random(in: 3...40))
            return x
        }
        return [
            d("192.168.1.1", "الراوتر (البوّابة)", "TP-Link", "AC:84:C6:11:22:33", [53, 80, 443], gw: true),
            d("192.168.1.12", "جهاز أندرويد", "Samsung", "D0:52:A8:0A:0B:0C", [5555]),
            d("192.168.1.18", "راسبيري باي", "Raspberry Pi", "B8:27:EB:12:34:56", [22, 80, 445]),
            d("192.168.1.24", "كاميرا مراقبة", "Hikvision", "C0:56:E3:AA:BB:CC", [554, 23]),
            d("192.168.1.31", "تلفزيون Roku", "Roku", "D8:31:34:DD:EE:FF", [8060, 443]),
            d("192.168.1.37", "جهازك", "Apple", "F0:DB:F8:99:88:77", [62078], self_: true),
            d("192.168.1.44", "طابعة HP", "HP", "3C:2A:F4:00:11:22", [9100, 631, 80])
        ]
    }
}

@main
struct ShabakaApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(SB.cyan)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            SB.bg
            RadialGradient(colors: [SB.cyan.opacity(0.14), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [SB.blue.opacity(0.14), Color.clear], center: .bottomLeading, startRadius: 0, endRadius: 440)
        }.ignoresSafeArea()
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Backdrop()
            Group {
                switch tab {
                case 0: OverviewScreen()
                case 1: ScannerScreen()
                case 2: ToolsScreen()
                default: SecurityScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            tabBar
        }
        .onAppear {
            if Shot.on {
                store.conn = Store.demoConn(); store.loaded = true
                store.devices = Store.demoDevices(); store.scanDone = store.devices.count
                store.ping = PingStat(sent: 10, samples: [13, 15, 12, 14, 13, 16, 12, 13, 14, 13])
                switch Shot.name {
                case "scan": tab = 1
                case "tools", "subnet", "wol", "dns", "websec", "pubip": tab = 2
                case "security": tab = 3
                default: tab = 0
                }
            } else {
                store.refresh()
            }
        }
    }

    private var tabBar: some View {
        let items: [(String, String)] = [("نظرة", "wifi"), ("الأجهزة", "rectangle.3.group.fill"), ("أدوات", "wrench.and.screwdriver.fill"), ("أمان", "lock.shield.fill")]
        return HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                Button { Haptic.tap(); tab = i } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].1).font(.system(size: 19, weight: .semibold))
                        Text(items[i].0).font(rnd(10.5, .bold))
                    }
                    .foregroundStyle(tab == i ? SB.cyan : SB.tx3)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                }.buttonStyle(Press())
            }
        }
        .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.08)))
        .padding(.horizontal, 14).padding(.bottom, 6)
    }
}

// مكوّنات مشتركة
struct SectionTitle: View {
    let text: String
    var body: some View { Text(text).font(rnd(18, .heavy)).foregroundStyle(Color.white).frame(maxWidth: .infinity, alignment: .leading) }
}

struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(rnd(11, .heavy)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
    }
}

func monoText(_ s: String, _ size: CGFloat = 15, _ w: Font.Weight = .bold) -> some View {
    Text(s).font(.system(size: size, weight: w, design: .monospaced)).environment(\.layoutDirection, .leftToRight)
}
