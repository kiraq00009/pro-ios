import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── IPv4
check(IPv4("192.168.1.1")?.raw == 0xC0A80101, "parse")
check(IPv4("255.255.255.255")?.raw == 0xFFFFFFFF && IPv4("0.0.0.0")?.raw == 0, "bounds")
check(IPv4("256.1.1.1") == nil && IPv4("1.2.3") == nil && IPv4("1.2.3.4.5") == nil && IPv4("a.b.c.d") == nil && IPv4("1.2.3.04") == nil, "reject bad")
check(IPv4(0xC0A80101).text == "192.168.1.1", "text")
check(IPv4("10.0.0.5")!.isPrivate && IPv4("172.16.0.1")!.isPrivate && IPv4("172.32.0.1")!.isPrivate == false && !IPv4("8.8.8.8")!.isPrivate, "private")
check(IPv4("127.0.0.1")!.kind == "لوبباك" && IPv4("169.254.1.1")!.kind == "لينك-لوكال" && IPv4("8.8.8.8")!.kind == "عامّ", "kind")
check(IPv4("192.168.1.1")!.offset(5).text == "192.168.1.6", "offset")

// ── Subnet
let s = Subnet(cidr: "192.168.1.10/24")!
check(s.network.text == "192.168.1.0" && s.broadcast.text == "192.168.1.255", "net/bcast")
check(s.mask.text == "255.255.255.0" && s.wildcard.text == "0.0.0.255", "mask")
check(s.firstHost.text == "192.168.1.1" && s.lastHost.text == "192.168.1.254", "host range")
check(s.total == 256 && s.usable == 254, "counts /24")
check(s.contains(IPv4("192.168.1.99")!) && !s.contains(IPv4("192.168.2.1")!), "contains")
check(s.hosts().count == 254 && s.hosts()[0].text == "192.168.1.1", "hosts")
let s30 = Subnet(cidr: "10.0.0.0/30")!
check(s30.total == 4 && s30.usable == 2 && s30.firstHost.text == "10.0.0.1" && s30.lastHost.text == "10.0.0.2", "/30")
let s31 = Subnet(cidr: "10.0.0.0/31")!
check(s31.total == 2 && s31.usable == 2, "/31 point-to-point")
let s32 = Subnet(cidr: "10.0.0.5/32")!
check(s32.total == 1 && s32.usable == 1 && s32.network.text == "10.0.0.5", "/32 host")
let s8 = Subnet(cidr: "10.0.0.0/8")!
check(s8.total == 16_777_216 && s8.usable == 16_777_214, "/8 count")
check(Subnet(ip: "192.168.1.1", mask: "255.255.255.0")?.prefix == 24, "mask→prefix")
check(Subnet(ip: "192.168.1.1", mask: "255.255.255.192")?.prefix == 26, "mask /26")
check(Subnet(ip: "1.1.1.1", mask: "255.0.255.0") == nil, "non-contiguous mask rejected")
check(Subnet(cidr: "192.168.1.0/33") == nil && Subnet(cidr: "x/24") == nil, "bad cidr")
let parts = s.split(into: 26)
check(parts.count == 4 && parts[0].network.text == "192.168.1.0" && parts[1].network.text == "192.168.1.64" && parts[3].network.text == "192.168.1.192", "split /24→/26")
check(Subnet(cidr: "10.0.0.0/16")!.split(into: 24).count == 256, "split /16→/24")

// ── المنافذ
check(Ports.info(22).name == "SSH" && Ports.info(23).risk == 2 && Ports.info(443).risk == 0, "port catalog")
check(Ports.info(9999).name == "غير معروف", "unknown port")
check(Ports.common.contains(445) && Ports.common.contains(3389), "common has risky")
for p in Ports.common { _ = Ports.info(p) }

// ── OUI
check(OUI.vendor("B8:27:EB:12:34:56") == "Raspberry Pi", "oui raspberry")
check(OUI.vendor("d052a80a0b0c") == "Samsung", "oui lowercase no colon")
check(OUI.vendor("00:00:00:00:00:00") == nil, "oui unknown")
check(OUI.vendor("zz") == nil, "oui bad")

// ── إحصاء البنگ
let good = PingStat(sent: 10, samples: [12, 14, 11, 13, 12, 15, 12, 13, 11, 12])
check(good.loss == 0 && good.grade == 5 && abs(good.avg - 12.5) < 0.1, "good ping grade 5")
check(good.min == 11 && good.max == 15, "min/max")
check(good.jitter > 0 && good.jitter < 5, "jitter small")
let lossy = PingStat(sent: 10, samples: [40, 180, 30, 220, 35])
check(lossy.loss == 50 && lossy.grade <= 2, "lossy graded low")
let empty = PingStat(sent: 5, samples: [])
check(empty.grade == 0 && empty.loss == 100, "no response")
let mid = PingStat(sent: 20, samples: Array(repeating: 55, count: 20))
check(mid.jitter == 0 && mid.grade >= 3 && mid.grade <= 4, "stable mid")

// ── WOL
let pkt = WOL.magicPacket(mac: "AA:BB:CC:DD:EE:FF")!
check(pkt.count == 102, "wol length 6+16*6")
check(pkt.prefix(6).allSatisfy { $0 == 0xFF }, "wol header")
check(Array(pkt[6..<12]) == [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF], "wol first mac")
check(Array(pkt.suffix(6)) == [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF], "wol last mac")
check(WOL.magicPacket(mac: "AA:BB:CC") == nil, "wol bad mac")

// ── تقييم الأمان
let items = Audit.device(openPorts: [80, 443, 23, 445])
check(items.contains { $0.title.contains("23") && $0.level == 2 }, "audit flags telnet")
check(items.contains { $0.title.contains("445") }, "audit flags smb")
check(!items.contains { $0.title.contains("443") }, "audit ignores safe https")
check(Audit.device(openPorts: [443, 993]).first?.level == 0, "clean device ok")
check(Audit.score(devices: 8, riskyPorts: 0, encrypted: true, guestFound: false) == 100, "perfect score")
check(Audit.score(devices: 8, riskyPorts: 2, encrypted: true, guestFound: false) == 76, "risky ports deduct")
check(Audit.score(devices: 40, riskyPorts: 3, encrypted: false, guestFound: true) < 50, "bad network low")

// ── أمن ويب: تحليل الرؤوس
let weak = WebSec.analyze(headers: ["Server": "nginx/1.18.0"])
check(weak.score < 40 && weak.grade == "F", "no security headers = F: \(weak.score)")
check(weak.checks.contains { $0.name.contains("Server") && !$0.present }, "flags server version leak")
let strong = WebSec.analyze(headers: ["Strict-Transport-Security": "max-age=63072000", "Content-Security-Policy": "default-src 'self'", "X-Frame-Options": "DENY", "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer", "Permissions-Policy": "geolocation=()"])
check(strong.score >= 85 && strong.grade == "A", "all headers = A: \(strong.score)")
check(WebSec.analyze(headers: [:]).checks.count >= 6, "lists all checks")

// ── استشارات الخدمات
let adv = Advisories.forPorts([23, 445, 80])
check(adv.contains { $0.title.contains("Telnet") && $0.severity == 4 }, "telnet critical")
check(adv.contains { $0.title.contains("SMB") }, "smb flagged")
check(adv.first!.severity >= adv.last!.severity, "sorted by severity")
check(Advisories.forPorts([443, 993]).isEmpty, "safe ports no advisory")
check(Advisories.maxSeverity([3389, 80]) == 4, "rdp max severity")
check(Advisories.maxSeverity([443]) == 0, "safe max severity 0")

// ── كلمات السرّ الافتراضيّة
check(DefaultCreds.forVendor("TP-Link").contains { $0.user == "admin" }, "tplink defaults")
check(DefaultCreds.forVendor("Raspberry Pi").contains { $0.pass.contains("raspberry") }, "raspberry defaults")
check(DefaultCreds.forVendor("Apple").isEmpty, "no defaults for apple")
check(DefaultCreds.known.count >= 7, "has default cred list")

// ── تقرير شامل
let rep = Report.build([("كاميرا", "192.168.1.10", [23, 554]), ("راوتر", "192.168.1.1", [80, 443]), ("سيرفر", "192.168.1.5", [3389, 445])])
check(rep.critical >= 2 && rep.vulns.first!.advisory.severity == 4, "report ranks critical first")
check(rep.score < 70 && rep.score >= 0, "vulnerable network low score: \(rep.score)")
check(Report.build([("هاتف", "192.168.1.2", [62078]), ("لابتوب", "192.168.1.3", [443])]).score == 100, "clean network perfect")

// ── إشارة الواي‑فاي
check(Signal.quality(dBm: -45).label == "ممتاز" && Signal.quality(dBm: -45).percent > 70, "strong signal")
check(Signal.quality(dBm: -85).label == "سيّئ", "weak signal")
check(Signal.quality(dBm: -200).percent == 0 && Signal.quality(dBm: 0).percent == 100, "signal clamped")

print(failures == 0 ? "ALL SHABAKA TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
