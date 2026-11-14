import Foundation
import Network
import SystemConfiguration.CaptiveNetwork
#if canImport(NetworkExtension)
import NetworkExtension
#endif

// محرّك الشبكة الحيّ — يستعمل أطر آبل الحقيقيّة (Network/getifaddrs). أوضاع التصوير ببيانات تجريبيّة.

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
    var interface = ""         // en0 واي‑فاي · pdp_ip0 بيانات
    var hasWifi = false
}

enum LiveNet {

    // MARK: عنوان الجهاز المحليّ والواجهة

    static func localInfo() -> ConnInfo {
        var info = ConnInfo()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return info }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let p = ptr {
            let flags = Int32(p.pointee.ifa_flags)
            let addr = p.pointee.ifa_addr
            if let addr = addr, addr.pointee.sa_family == UInt8(AF_INET),
               (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
               (flags & IFF_LOOPBACK) == 0 {
                let name = String(cString: p.pointee.ifa_name)
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                let ipStr = String(cString: host)
                if let ip = IPv4(ipStr), !ip.text.hasPrefix("169.254") {
                    var maskStr = "255.255.255.0"
                    if let m = p.pointee.ifa_netmask {
                        var mh = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(m, socklen_t(m.pointee.sa_len), &mh, socklen_t(mh.count), nil, 0, NI_NUMERICHOST)
                        maskStr = String(cString: mh)
                    }
                    if name == "en0" || info.ip == nil {
                        info.ip = ip
                        info.interface = name
                        info.hasWifi = name == "en0"
                        info.subnet = Subnet(ip: ipStr, mask: maskStr)
                        if let sub = info.subnet { info.gateway = IPv4(sub.network.raw + 1) }   // تقدير شائع: أوّل مضيف
                    }
                }
            }
            ptr = p.pointee.ifa_next
        }
        info.ssid = currentSSID() ?? ""
        return info
    }

    static func currentSSID() -> String? {
        #if canImport(NetworkExtension)
        if #available(iOS 14.0, *) {
            var result: String?
            let sem = DispatchSemaphore(value: 0)
            NEHotspotNetwork.fetchCurrent { net in result = net?.ssid; sem.signal() }
            _ = sem.wait(timeout: .now() + 1.2)
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

    // MARK: فحص منفذ TCP (أساس الماسح والبنگ)

    /// يحاول يفتح اتّصال TCP؛ يرجّع زمن الاتّصال بالملّي ثانية أو nil إذا فشل
    static func probe(_ host: String, port: Int, timeout: Double = 1.0) async -> Double? {
        await withCheckedContinuation { cont in
            let start = DispatchTime.now()
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { cont.resume(returning: nil); return }
            let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let done = Locked(false)
            func finish(_ v: Double?) {
                if done.swap(true) { return }
                conn.cancel()
                cont.resume(returning: v)
            }
            conn.stateUpdateHandler = { st in
                switch st {
                case .ready:
                    let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
                    finish(ms)
                case .failed, .cancelled:
                    finish(nil)
                default: break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    /// بنگ TCP متكرّر لمضيف:منفذ ويرجّع الإحصاء
    static func ping(_ host: String, port: Int = 443, count: Int = 8, progress: @escaping (PingStat) -> Void) async -> PingStat {
        var samples: [Double] = []
        for i in 0..<count {
            if let ms = await probe(host, port: port, timeout: 1.5) { samples.append(ms) }
            let stat = PingStat(sent: i + 1, samples: samples)
            progress(stat)
            try? await Task.sleep(nanoseconds: 220_000_000)
        }
        return PingStat(sent: count, samples: samples)
    }

    /// فحص منافذ مضيف واحد
    static func scanPorts(_ host: String, ports: [Int], onFound: @escaping (Int) -> Void) async -> [Int] {
        var open: [Int] = []
        await withTaskGroup(of: (Int, Bool).self) { group in
            for p in ports { group.addTask { (p, await probe(host, port: p, timeout: 1.2) != nil) } }
            for await (p, ok) in group where ok { open.append(p); onFound(p) }
        }
        return open.sorted()
    }

    /// ماسح الشبكة: يفحص كلّ مضيف على منافذ شائعة؛ يبلّغ كلّ ما يلگى جهاز
    static func scanLAN(_ subnet: Subnet, onDevice: @escaping (Device) -> Void) async {
        let hosts = subnet.hosts(limit: 254)
        let probePorts = [80, 443, 22, 139, 445, 62078, 5353, 7]      // 62078 = آيفون، 7 = echo
        await withTaskGroup(of: Device?.self) { group in
            var running = 0
            for h in hosts {
                if running >= 48 { _ = await group.next(); running -= 1 }
                running += 1
                group.addTask {
                    for p in probePorts {
                        if let ms = await probe(h.text, port: p, timeout: 0.9) {
                            var d = Device(ip: h)
                            d.latency = ms
                            d.ports = [p]
                            return d
                        }
                    }
                    return nil
                }
            }
            for await d in group { if let d = d { onDevice(d) } }
        }
    }

    // MARK: DNS

    static func resolve(_ host: String) async -> (ips: [String], ms: Double)? {
        await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let start = DispatchTime.now()
                var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM, ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
                var res: UnsafeMutablePointer<addrinfo>?
                let err = getaddrinfo(host, nil, &hints, &res)
                guard err == 0, let first = res else { cont.resume(returning: nil); return }
                defer { freeaddrinfo(res) }
                var ips: [String] = []
                var p: UnsafeMutablePointer<addrinfo>? = first
                while let node = p {
                    var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if let a = node.pointee.ai_addr, getnameinfo(a, node.pointee.ai_addrlen, &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let s = String(cString: buf)
                        if !ips.contains(s) { ips.append(s) }
                    }
                    p = node.pointee.ai_next
                }
                let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
                cont.resume(returning: (ips, ms))
            }
        }
    }

    // MARK: WOL — يبعث الحزمة السحريّة على UDP broadcast

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

/// قفل بسيط لحماية حالة الإنهاء بالاتّصال
final class Locked<T>: @unchecked Sendable {
    private var v: T
    private let lock = NSLock()
    init(_ v: T) { self.v = v }
    func swap(_ n: T) -> T { lock.lock(); defer { lock.unlock() }; let o = v; v = n; return o }
}
extension Locked where T == Bool {}
