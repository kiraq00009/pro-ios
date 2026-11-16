import Foundation
import Network
import SystemConfiguration.CaptiveNetwork
#if canImport(NetworkExtension)
import NetworkExtension
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif

// محرّك الشبكة الحيّ — أطر آبل الحقيقيّة. أوضاع التصوير ببيانات تجريبيّة.

struct Device: Identifiable, Equatable {
    var id: UInt32 { ip.raw }
    let ip: IPv4
    var name: String = ""
    var vendor: String = ""
    var mac: String = ""
    var ports: [Int] = []
    var isSelf = false
    var isGateway = false
    var latency: Double? = nil
}

struct ConnInfo: Equatable {
    var ssid: String = ""
    var ip: IPv4? = nil
    var subnet: Subnet? = nil
    var gateway: IPv4? = nil
    var interface = ""
    var hasWifi = false
    var localDenied = false        // صار واضح إنّ إذن الشبكة المحليّة مرفوض
}

// يطلب إذن الموقع (ضروريّ لاسم الواي‑فاي) ويحفّز إذن الشبكة المحليّة
final class Perms: NSObject, CLLocationManagerDelegate {
    static let shared = Perms()
    private let loc = CLLocationManager()
    private var browser: NWBrowser?
    override init() { super.init(); loc.delegate = self }
    func requestLocation() {
        if loc.authorizationStatus == .notDetermined { loc.requestWhenInUseAuthorization() }
    }
    /// يفتح متصفّح Bonjour حتى يطلع نظام iOS نافذة إذن الشبكة المحليّة
    func primeLocalNetwork() {
        let b = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: .init())
        b.stateUpdateHandler = { _ in }
        b.start(queue: .global())
        browser = b
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in self?.browser?.cancel(); self?.browser = nil }
    }
}

enum LiveNet {

    // MARK: عنوان الجهاز والواجهة

    static func localInfo() -> ConnInfo {
        var info = ConnInfo()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return info }
        defer { freeifaddrs(ifaddr) }
        var best: (ip: IPv4, mask: String, name: String)? = nil
        var ptr = ifaddr
        while let p = ptr {
            defer { ptr = p.pointee.ifa_next }
            let flags = Int32(p.pointee.ifa_flags)
            guard let addr = p.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
                  (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING), (flags & IFF_LOOPBACK) == 0 else { continue }
            let name = String(cString: p.pointee.ifa_name)
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let ipStr = String(cString: host)
            guard let ip = IPv4(ipStr), !ipStr.hasPrefix("169.254") else { continue }
            var maskStr = "255.255.255.0"
            if let m = p.pointee.ifa_netmask {
                var mh = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(m, socklen_t(m.pointee.sa_len), &mh, socklen_t(mh.count), nil, 0, NI_NUMERICHOST)
                maskStr = String(cString: mh)
            }
            // الأفضليّة لـen0 (واي‑فاي)، وإلّا أوّل واجهة صالحة
            if name == "en0" || best == nil { best = (ip, maskStr, name) }
        }
        if let b = best {
            info.ip = b.ip
            info.interface = b.name
            info.hasWifi = b.name == "en0"
            info.subnet = Subnet(ip: b.ip.text, mask: b.mask)
            info.gateway = defaultGateway() ?? info.subnet.map { IPv4($0.network.raw + 1) }
        }
        info.ssid = currentSSID() ?? ""
        return info
    }

    /// البوّابة الحقيقيّة من جدول التوجيه عبر sysctl (fallback = أوّل مضيف)
    static func defaultGateway() -> IPv4? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, 2 /* NET_RT_FLAGS */, Int32(0x2) /* RTF_GATEWAY */]
        var len = 0
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0, len > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: len)
        guard buf.withUnsafeMutableBytes({ sysctl(&mib, 6, $0.baseAddress, &len, nil, 0) }) == 0 else { return nil }
        var result: IPv4? = nil
        buf.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var off = 0
            let hdr = 92 // sizeof(rt_msghdr) على داروين — الهيدر مو مكشوف بـSDK الآيفون
            while off + hdr <= len {
                let msgLen = Int(base.loadUnaligned(fromByteOffset: off, as: UInt16.self))
                if msgLen <= 0 || off + msgLen > len { break }
                // أوّل sockaddr = الوجهة · الثاني = البوّابة (لمّا RTA_GATEWAY مضبوط)
                var sa = off + hdr
                let addrs = base.loadUnaligned(fromByteOffset: off + 12, as: Int32.self)
                func readSA() -> (family: UInt8, inaddr: UInt32)? {
                    guard sa + 2 <= off + msgLen else { return nil }
                    let slen = Int(base.load(fromByteOffset: sa, as: UInt8.self))
                    let fam = base.load(fromByteOffset: sa + 1, as: UInt8.self)
                    let step = slen == 0 ? 4 : (slen + 3) & ~3
                    var ipv: UInt32 = 0
                    if fam == UInt8(AF_INET), sa + 8 <= off + msgLen {
                        // sockaddr_in.sin_addr على الإزاحة 4
                        let b0 = UInt32(base.load(fromByteOffset: sa + 4, as: UInt8.self))
                        let b1 = UInt32(base.load(fromByteOffset: sa + 5, as: UInt8.self))
                        let b2 = UInt32(base.load(fromByteOffset: sa + 6, as: UInt8.self))
                        let b3 = UInt32(base.load(fromByteOffset: sa + 7, as: UInt8.self))
                        ipv = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
                    }
                    sa += step
                    return (fam, ipv)
                }
                var destIsDefault = false
                var gw: UInt32? = nil
                if addrs & Int32(0x1) != 0, let d = readSA() { destIsDefault = (d.inaddr == 0) }
                if addrs & Int32(0x2) != 0, let g = readSA(), g.family == UInt8(AF_INET) { gw = g.inaddr }
                if destIsDefault, let g = gw, g != 0 { result = IPv4(g); break }
                off += msgLen
            }
        }
        return result
    }

    static func currentSSID() -> String? {
        #if canImport(NetworkExtension)
        if #available(iOS 14.0, *) {
            var result: String?
            let sem = DispatchSemaphore(value: 0)
            NEHotspotNetwork.fetchCurrent { net in result = net?.ssid; sem.signal() }
            _ = sem.wait(timeout: .now() + 1.5)
            if let r = result, !r.isEmpty { return r }
        }
        #endif
        if let ifs = CNCopySupportedInterfaces() as? [String] {
            for i in ifs {
                if let d = CNCopyCurrentNetworkInfo(i as CFString) as? [String: Any], let ssid = d[kCNNetworkInfoKeySSID as String] as? String { return ssid }
            }
        }
        return nil
    }

    // MARK: فحص منفذ TCP

    static func probe(_ host: String, port: Int, timeout: Double = 1.0) async -> Double? {
        await withCheckedContinuation { cont in
            let start = DispatchTime.now()
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { cont.resume(returning: nil); return }
            let params = NWParameters.tcp
            params.prohibitedInterfaceTypes = [.cellular]       // الشبكة المحليّة تجي من الواي‑فاي
            let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: params)
            let done = Locked(false)
            func finish(_ v: Double?) {
                if done.swap(true) { return }
                conn.cancel(); cont.resume(returning: v)
            }
            conn.stateUpdateHandler = { st in
                switch st {
                case .ready:
                    let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
                    finish(ms)
                case .failed, .cancelled: finish(nil)
                default: break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    static func ping(_ host: String, port: Int = 443, count: Int = 8, progress: @escaping (PingStat) -> Void) async -> PingStat {
        var samples: [Double] = []
        for i in 0..<count {
            if let ms = await probe(host, port: port, timeout: 1.5) { samples.append(ms) }
            progress(PingStat(sent: i + 1, samples: samples))
            try? await Task.sleep(nanoseconds: 220_000_000)
        }
        return PingStat(sent: count, samples: samples)
    }

    static func scanPorts(_ host: String, ports: [Int], onFound: @escaping (Int) -> Void) async -> [Int] {
        var open: [Int] = []
        await withTaskGroup(of: (Int, Bool).self) { group in
            for p in ports { group.addTask { (p, await probe(host, port: p, timeout: 1.3) != nil) } }
            for await (p, ok) in group where ok { open.append(p); onFound(p) }
        }
        return open.sorted()
    }

    /// ماسح الشبكة: يفحص كلّ مضيف على منافذ شائعة؛ يبلّغ كلّ ما يلگى جهاز
    static func scanLAN(_ subnet: Subnet, gateway: IPv4?, selfIP: IPv4?, onDevice: @escaping (Device) -> Void, done: @escaping (Int) -> Void) async {
        Perms.shared.primeLocalNetwork()
        try? await Task.sleep(nanoseconds: 400_000_000)
        var hosts = subnet.hosts(limit: 254)
        // ابدأ بالبوّابة ونفسك حتى يظهرون أوّل
        if let gw = gateway { hosts.removeAll { $0 == gw }; hosts.insert(gw, at: 0) }
        let probePorts = [80, 443, 22, 53, 139, 445, 8080, 62078, 7, 548, 3689, 9100, 1900, 23, 554]
        var responded = 0
        await withTaskGroup(of: Device?.self) { group in
            var active = 0
            for h in hosts {
                if active >= 40 { if (await group.next()) != nil {}; active -= 1 }
                active += 1
                group.addTask {
                    for p in probePorts {
                        if let ms = await probe(h.text, port: p, timeout: 0.8) {
                            var d = Device(ip: h); d.latency = ms; d.ports = [p]; return d
                        }
                    }
                    return nil
                }
            }
            for await d in group { if let d = d { responded += 1; onDevice(d) } }
        }
        done(responded)
    }

    // MARK: DNS

    static func resolve(_ host: String) async -> (ips: [String], ms: Double)? {
        await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let start = DispatchTime.now()
                var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM, ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
                var res: UnsafeMutablePointer<addrinfo>?
                guard getaddrinfo(host, nil, &hints, &res) == 0, let first = res else { cont.resume(returning: nil); return }
                defer { freeaddrinfo(res) }
                var ips: [String] = []
                var p: UnsafeMutablePointer<addrinfo>? = first
                while let node = p {
                    var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if let a = node.pointee.ai_addr, getnameinfo(a, node.pointee.ai_addrlen, &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let s = String(cString: buf); if !ips.contains(s) { ips.append(s) }
                    }
                    p = node.pointee.ai_next
                }
                let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
                cont.resume(returning: (ips, ms))
            }
        }
    }

    // MARK: فاحص رؤوس HTTP الأمنيّة (أمن ويب أخلاقيّ)

    static func httpHeaders(_ host: String, port: Int = 0) async -> (status: Int, headers: [String: String], server: String)? {
        let useTLS = port == 443 || (port == 0)
        let p = port == 0 ? (useTLS ? 443 : 80) : port
        guard let url = URL(string: "\(useTLS ? "https" : "http")://\(host):\(p)/") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 6)
        req.httpMethod = "GET"
        req.setValue("Shabaka/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let h = resp as? HTTPURLResponse else { return nil }
            var headers: [String: String] = [:]
            for (k, v) in h.allHeaderFields { headers[String(describing: k)] = String(describing: v) }
            return (h.statusCode, headers, headers["Server"] ?? "")
        } catch { return nil }
    }

    // MARK: عنوان الإنترنت العامّ + المزوّد (اختياريّ — يحتاج نت)

    static func publicIP() async -> (ip: String, org: String)? {
        guard let url = URL(string: "https://api.ipify.org?format=json") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let ip = j["ip"] as? String { return (ip, "") }
        } catch {}
        return nil
    }

    // MARK: WOL

    static func wake(mac: String, broadcast: String = "255.255.255.255") -> Bool {
        guard let bytes = WOL.magicPacket(mac: mac) else { return false }
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = (9 as UInt16).bigEndian
        addr.sin_addr.s_addr = inet_addr(broadcast)
        let sent = bytes.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { ap in
                ap.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, raw.baseAddress, raw.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        return sent > 0
    }
}

final class Locked<T>: @unchecked Sendable {
    private var v: T
    private let lock = NSLock()
    init(_ v: T) { self.v = v }
    func swap(_ n: T) -> T { lock.lock(); defer { lock.unlock() }; let o = v; v = n; return o }
}
