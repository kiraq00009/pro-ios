import Foundation

// منطق أدوات الشبكة — خالص وينفحص آليًّا (رياضة الشبكات، المنافذ، OUI، إحصاء البنگ، WOL).

// MARK: عنوان IPv4

struct IPv4: Equatable, Comparable, Codable {
    var raw: UInt32
    init(_ raw: UInt32) { self.raw = raw }
    init?(_ s: String) {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var v: UInt32 = 0
        for p in parts {
            guard let n = Int(p), n >= 0, n <= 255, p == "\(n)" else { return nil }
            v = (v << 8) | UInt32(n)
        }
        raw = v
    }
    var text: String { "\((raw >> 24) & 255).\((raw >> 16) & 255).\((raw >> 8) & 255).\(raw & 255)" }
    static func < (a: IPv4, b: IPv4) -> Bool { a.raw < b.raw }
    func offset(_ d: Int) -> IPv4 { IPv4(UInt32(truncatingIfNeeded: Int64(raw) + Int64(d))) }
    /// فئة العنوان (أ/ب/ج) والنوع (خاصّ، لوبباك، لينك‑لوكال، عامّ)
    var isPrivate: Bool {
        let a = (raw >> 24) & 255, b = (raw >> 16) & 255
        return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168)
    }
    var kind: String {
        let a = (raw >> 24) & 255, b = (raw >> 16) & 255
        if a == 127 { return "لوبباك" }
        if a == 169 && b == 254 { return "لينك-لوكال" }
        if a >= 224 && a <= 239 { return "ملتيكاست" }
        if isPrivate { return "خاصّ" }
        return "عامّ"
    }
}

// MARK: حاسبة الشبكات الفرعيّة (CIDR)

struct Subnet: Equatable {
    let ip: IPv4
    let prefix: Int       // 0…32

    init?(ip: String, prefix: Int) {
        guard let p = IPv4(ip), prefix >= 0, prefix <= 32 else { return nil }
        self.ip = p; self.prefix = prefix
    }
    init?(cidr: String) {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2, let pre = Int(parts[1]) else { return nil }
        self.init(ip: String(parts[0]), prefix: pre)
    }
    /// من IP وقناع نقطيّ (255.255.255.0)
    init?(ip: String, mask: String) {
        guard let m = IPv4(mask) else { return nil }
        var bits = m.raw, count = 0, seenZero = false, valid = true
        for _ in 0..<32 {
            if bits & 0x8000_0000 != 0 { if seenZero { valid = false }; count += 1 } else { seenZero = true }
            bits <<= 1
        }
        guard valid else { return nil }
        self.init(ip: ip, prefix: count)
    }

    var maskRaw: UInt32 { prefix == 0 ? 0 : ~UInt32(0) << (32 - prefix) }
    var mask: IPv4 { IPv4(maskRaw) }
    var wildcard: IPv4 { IPv4(~maskRaw) }
    var network: IPv4 { IPv4(ip.raw & maskRaw) }
    var broadcast: IPv4 { IPv4(network.raw | ~maskRaw) }
    var total: UInt64 { prefix >= 31 ? (prefix == 32 ? 1 : 2) : (UInt64(1) << (32 - prefix)) }
    var usable: UInt64 { prefix >= 31 ? total : total - 2 }
    var firstHost: IPv4 { prefix >= 31 ? network : IPv4(network.raw + 1) }
    var lastHost: IPv4 { prefix >= 31 ? broadcast : IPv4(broadcast.raw - 1) }
    func contains(_ a: IPv4) -> Bool { (a.raw & maskRaw) == network.raw }
    /// كلّ المضيفين القابلين للفحص (للماسح) — محدود بعدد معقول
    func hosts(limit: Int = 1024) -> [IPv4] {
        let lo = firstHost.raw, hi = lastHost.raw
        guard hi >= lo else { return [] }
        var out: [IPv4] = []
        var a = lo
        while a <= hi && out.count < limit { out.append(IPv4(a)); if a == UInt32.max { break }; a += 1 }
        return out
    }
    /// تقسيم لشبكات أصغر بطول بادئة جديد
    func split(into newPrefix: Int) -> [Subnet] {
        guard newPrefix > prefix, newPrefix <= 32 else { return [] }
        let step = UInt32(1) << (32 - newPrefix)
        var out: [Subnet] = []
        var a = network.raw
        let end = broadcast.raw
        while true {
            out.append(Subnet(ip: IPv4(a).text, prefix: newPrefix)!)
            if a > end - step { break }
            a += step
            if out.count > 4096 { break }
        }
        return out
    }
}

// MARK: دليل المنافذ

struct PortInfo: Equatable {
    let port: Int
    let name: String
    let proto: String
    let risk: Int        // 0 عاديّ · 1 انتبه · 2 خطر
    let note: String
}

enum Ports {
    static let known: [Int: PortInfo] = {
        var m: [Int: PortInfo] = [:]
        func add(_ p: Int, _ n: String, _ pr: String, _ r: Int, _ note: String) { m[p] = PortInfo(port: p, name: n, proto: pr, risk: r, note: note) }
        add(20, "FTP-Data", "TCP", 2, "نقل ملفّات بلا تشفير")
        add(21, "FTP", "TCP", 2, "باسوردات تمرّ واضحة — استعمل SFTP")
        add(22, "SSH", "TCP", 1, "دخول آمن — تأكّد من باسورد قويّ أو مفتاح")
        add(23, "Telnet", "TCP", 2, "خطر: كلّشي واضح بلا تشفير — اقفله")
        add(25, "SMTP", "TCP", 1, "بريد صادر")
        add(53, "DNS", "UDP", 0, "ترجمة أسماء النطاقات")
        add(67, "DHCP", "UDP", 0, "توزيع العناوين")
        add(80, "HTTP", "TCP", 1, "ويب بلا تشفير")
        add(110, "POP3", "TCP", 1, "بريد وارد قديم")
        add(123, "NTP", "UDP", 0, "توقيت")
        add(135, "RPC", "TCP", 2, "ويندوز — هدف شائع للهجمات")
        add(137, "NetBIOS", "UDP", 2, "مشاركة ويندوز قديمة")
        add(139, "NetBIOS", "TCP", 2, "مشاركة ويندوز قديمة")
        add(143, "IMAP", "TCP", 1, "بريد وارد")
        add(161, "SNMP", "UDP", 2, "إدارة أجهزة — غالبًا بكلمة سرّ ضعيفة")
        add(443, "HTTPS", "TCP", 0, "ويب مشفّر — سليم")
        add(445, "SMB", "TCP", 2, "مشاركة ملفّات ويندوز — هدف فيروسات الفدية")
        add(515, "Printer", "TCP", 1, "طابعة")
        add(554, "RTSP", "TCP", 1, "بثّ كاميرات")
        add(631, "IPP", "TCP", 0, "طباعة")
        add(993, "IMAPS", "TCP", 0, "بريد مشفّر")
        add(995, "POP3S", "TCP", 0, "بريد مشفّر")
        add(1080, "SOCKS", "TCP", 1, "بروكسي")
        add(1883, "MQTT", "TCP", 1, "إنترنت الأشياء")
        add(1900, "SSDP", "UDP", 1, "اكتشاف UPnP")
        add(2323, "Telnet-alt", "TCP", 2, "تلنت بديل — خطر")
        add(3306, "MySQL", "TCP", 2, "قاعدة بيانات — ما تنكشف للشبكة")
        add(3389, "RDP", "TCP", 2, "سطح مكتب بعيد — هدف اختراق كبير")
        add(5353, "mDNS", "UDP", 0, "Bonjour/اكتشاف أبل")
        add(5432, "Postgres", "TCP", 2, "قاعدة بيانات مكشوفة")
        add(5555, "ADB", "TCP", 2, "تصحيح أندرويد — خطر إذا مفتوح")
        add(5900, "VNC", "TCP", 2, "تحكّم عن بعد — غالبًا بلا باسورد")
        add(6379, "Redis", "TCP", 2, "قاعدة بيانات بلا مصادقة افتراضيًّا")
        add(8080, "HTTP-alt", "TCP", 1, "ويب إداريّ")
        add(8443, "HTTPS-alt", "TCP", 0, "ويب إداريّ مشفّر")
        add(8888, "HTTP-alt", "TCP", 1, "لوحات إدارة")
        add(9100, "Printer", "TCP", 1, "طباعة خام")
        add(32400, "Plex", "TCP", 0, "خادم وسائط Plex")
        return m
    }()
    /// منافذ يفحصها الماسح السريع (الأكثر شيوعًا)
    static let common = [21, 22, 23, 53, 80, 135, 139, 443, 445, 515, 554, 631, 1883, 3306, 3389, 5900, 6379, 8080, 8443, 9100, 32400]
    static func info(_ p: Int) -> PortInfo { known[p] ?? PortInfo(port: p, name: "غير معروف", proto: "TCP", risk: 0, note: "منفذ غير قياسيّ") }
    static func risk(_ p: Int) -> Int { known[p]?.risk ?? 0 }
}

// MARK: OUI — الشركة المصنّعة من أوّل ٣ بايت من MAC

enum OUI {
    static let table: [String: String] = [
        "FCFBFB": "Cisco", "001A11": "Google", "F4F5E8": "Google", "3C5AB4": "Google",
        "D83134": "Roku", "B827EB": "Raspberry Pi", "DCA632": "Raspberry Pi", "E45F01": "Raspberry Pi",
        "001451": "Apple", "A4B197": "Apple", "F0DBF8": "Apple", "8866A5": "Apple", "ACBC32": "Apple", "3C0754": "Apple",
        "001132": "Synology", "0011D8": "Asus", "AC9E17": "Asus", "88D7F6": "Asus",
        "002618": "TP-Link", "5C628B": "TP-Link", "3C84A1": "TP-Link", "9C5322": "TP-Link",
        "0024B2": "Netgear", "A040A0": "Netgear", "20E52A": "Netgear",
        "F81A67": "TP-Link", "C46E1F": "TP-Link", "001018": "Broadcom",
        "001E8C": "Asus", "000C29": "VMware", "005056": "VMware", "0800275A": "VirtualBox",
        "D052A8": "Samsung", "F8042E": "Samsung", "5CF6DC": "Samsung", "E8508B": "Samsung",
        "B07FB9": "Netgear", "0018E7": "Xiaomi", "286C07": "Xiaomi", "7802F8": "Xiaomi",
        "D461DA": "Amazon", "FC65DE": "Amazon", "44650D": "Amazon", "0C47C9": "Amazon",
        "ECFABC": "Huawei", "48435A": "Huawei", "001882": "Huawei",
        "000D4B": "Roku", "CC6DA0": "Roku", "001788": "Philips Hue", "ECB5FA": "Philips Hue"
    ]
    static func vendor(_ mac: String) -> String? {
        let hex = mac.uppercased().filter { $0.isHexDigit }
        guard hex.count >= 6 else { return nil }
        if hex.count >= 8, let v = table[String(hex.prefix(8))] { return v }
        return table[String(hex.prefix(6))]
    }
}

// MARK: إحصاء البنگ

struct PingStat: Equatable {
    var sent: Int
    var samples: [Double]        // بالملّي ثانية (الناجحة بس)
    var min: Double { samples.min() ?? 0 }
    var max: Double { samples.max() ?? 0 }
    var avg: Double { samples.isEmpty ? 0 : samples.reduce(0, +) / Double(samples.count) }
    /// التذبذب: متوسّط الفرق المطلق بين القياسات المتتالية
    var jitter: Double {
        guard samples.count > 1 else { return 0 }
        var s = 0.0
        for i in 1..<samples.count { s += abs(samples[i] - samples[i - 1]) }
        return s / Double(samples.count - 1)
    }
    var loss: Double { sent == 0 ? 0 : Double(sent - samples.count) / Double(sent) * 100 }
    /// درجة من ٥: جودة الاتّصال للألعاب/المكالمات
    var grade: Int {
        if samples.isEmpty { return 0 }
        var g = 5
        if avg > 30 { g -= 1 }; if avg > 70 { g -= 1 }; if avg > 150 { g -= 1 }
        if jitter > 15 { g -= 1 }; if jitter > 40 { g -= 1 }
        if loss > 1 { g -= 1 }; if loss > 5 { g -= 2 }
        return Swift.max(1, Swift.min(5, g))
    }
    var verdict: String {
        switch grade {
        case 5: return "ممتاز — مناسب للألعاب والبثّ المباشر"
        case 4: return "زين — مكالمات وبثّ بلا مشاكل"
        case 3: return "متوسّط — يكفي للتصفّح"
        case 2: return "ضعيف — تقطّع بالمكالمات والألعاب"
        default: return "سيّئ — اتّصال غير مستقرّ"
        }
    }
}

// MARK: WOL — حزمة الإيقاظ السحريّة

enum WOL {
    /// بايتات الحزمة السحريّة: 6 × 0xFF ثمّ 16 تكرار لعنوان MAC
    static func magicPacket(mac: String) -> [UInt8]? {
        let hex = mac.uppercased().filter { $0.isHexDigit }
        guard hex.count == 12 else { return nil }
        var bytes: [UInt8] = []
        var i = hex.startIndex
        for _ in 0..<6 {
            let j = hex.index(i, offsetBy: 2)
            guard let b = UInt8(hex[i..<j], radix: 16) else { return nil }
            bytes.append(b); i = j
        }
        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet += bytes }
        return packet
    }
}

// MARK: تقييم أمان الشبكة

struct SecurityItem: Equatable {
    let title: String
    let detail: String
    let level: Int       // 0 سليم · 1 تحذير · 2 خطر
}

enum Audit {
    /// يحلّل المنافذ المفتوحة لجهاز ويطلع ملاحظات أمان
    static func device(openPorts: [Int]) -> [SecurityItem] {
        var out: [SecurityItem] = []
        for p in openPorts.sorted() {
            let info = Ports.info(p)
            if info.risk > 0 {
                out.append(SecurityItem(title: "منفذ \(p) مفتوح — \(info.name)", detail: info.note, level: info.risk))
            }
        }
        if out.isEmpty { out.append(SecurityItem(title: "ما أكو منافذ خطرة مفتوحة", detail: "هذا الجهاز يبيّن سليم من ناحية المنافذ", level: 0)) }
        return out
    }
    /// درجة أمان الشبكة من ١٠٠
    static func score(devices: Int, riskyPorts: Int, encrypted: Bool, guestFound: Bool) -> Int {
        var s = 100
        s -= riskyPorts * 12
        if !encrypted { s -= 25 }
        if guestFound { s -= 8 }
        if devices > 30 { s -= 5 }
        return Swift.max(0, Swift.min(100, s))
    }
}
