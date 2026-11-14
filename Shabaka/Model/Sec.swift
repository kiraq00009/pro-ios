import Foundation

// منطق الأمن السيبرانيّ (أخلاقيّ/دفاعيّ) — خالص وينفحص آليًّا.
// كلّه تحليل لما تجمعه الأدوات (رؤوس HTTP، منافذ، شهادات) — ما بيه أيّ هجوم.

// MARK: تحليل رؤوس HTTP الأمنيّة

struct HeaderCheck: Equatable {
    let name: String
    let present: Bool
    let advice: String
    let weight: Int
}

enum WebSec {
    /// الرؤوس الأمنيّة المهمّة اللي يُفترض يرجّعها أيّ موقع
    static func analyze(headers: [String: String]) -> (checks: [HeaderCheck], grade: String, score: Int) {
        let lower = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a })
        func has(_ k: String) -> Bool { lower[k.lowercased()] != nil }
        let defs: [(String, String, Int)] = [
            ("Strict-Transport-Security", "يجبر المتصفّح يستعمل HTTPS دائمًا — يمنع التنصّت", 25),
            ("Content-Security-Policy", "يمنع حقن سكربتات خبيثة (XSS)", 25),
            ("X-Frame-Options", "يمنع تضمين موقعك بإطار لخداع المستخدم (clickjacking)", 15),
            ("X-Content-Type-Options", "يمنع المتصفّح من تخمين نوع الملفّ", 10),
            ("Referrer-Policy", "يحدّ من تسريب العناوين للمواقع الثانية", 10),
            ("Permissions-Policy", "يتحكّم بصلاحيّات (كاميرا/موقع) للصفحة", 15)
        ]
        var checks: [HeaderCheck] = []
        var score = 100
        for (name, advice, w) in defs {
            let ok = has(name)
            checks.append(HeaderCheck(name: name, present: ok, advice: advice, weight: w))
            if !ok { score -= w }
        }
        // رأس يكشف نسخة الخادم = تسريب معلومات
        if let srv = lower["server"], srv.rangeOfCharacter(from: .decimalDigits) != nil {
            checks.append(HeaderCheck(name: "Server يكشف نسخته (\(srv))", present: false, advice: "إخفاء نسخة الخادم يصعّب على المهاجم", weight: 8))
            score -= 8
        }
        score = max(0, min(100, score))
        let grade = score >= 85 ? "A" : (score >= 70 ? "B" : (score >= 50 ? "C" : (score >= 30 ? "D" : "F")))
        return (checks, grade, score)
    }
}

// MARK: استشارات الخدمات (منفذ/خدمة → خطر معروف)

struct Advisory: Equatable {
    let title: String
    let severity: Int        // 1 منخفض · 2 متوسّط · 3 عالي · 4 حرج
    let detail: String
    let fix: String
}

enum Advisories {
    /// يحلّل منافذ جهاز مفتوحة ويطلع استشارات أمنيّة (CVE‑style، تعليميّة)
    static func forPorts(_ ports: [Int]) -> [Advisory] {
        var out: [Advisory] = []
        let set = Set(ports)
        func add(_ t: String, _ s: Int, _ d: String, _ f: String) { out.append(Advisory(title: t, severity: s, detail: d, fix: f)) }
        if set.contains(23) || set.contains(2323) { add("Telnet مفتوح", 4, "تلنت يرسل كلّشي — باسوردات وأوامر — بلا تشفير، أيّ واحد بالشبكة يقراها.", "اقفل تلنت واستعمل SSH بدلًا منه.") }
        if set.contains(21) { add("FTP مفتوح", 3, "بروتوكول نقل ملفّات قديم بلا تشفير.", "استعمل SFTP (منفذ 22) أو FTPS.") }
        if set.contains(445) || set.contains(139) { add("مشاركة SMB مكشوفة", 4, "هدف رئيسيّ لفيروسات الفدية (WannaCry وأمثاله).", "اقفل SMB للإنترنت، حدّث النظام، فعّل جدار الحماية.") }
        if set.contains(3389) { add("سطح مكتب بعيد (RDP)", 4, "من أكثر المنافذ استهدافًا بهجمات التخمين والاختراق.", "اقفله، أو خلفه VPN + مصادقة ثنائيّة.") }
        if set.contains(5900) { add("VNC مفتوح", 3, "تحكّم كامل بالشاشة، وغالبًا بلا باسورد قويّ.", "ضع باسورد قويّ أو اقفله خلف VPN.") }
        if set.contains(5555) { add("منفذ تصحيح أندرويد (ADB)", 4, "يسمح بتثبيت تطبيقات وتنفيذ أوامر على الجهاز بلا إذن.", "أطفئ تصحيح USB/الشبكة من إعدادات المطوّر.") }
        if set.contains(6379) { add("Redis بلا مصادقة", 4, "قاعدة بيانات تنفتح افتراضيًّا بلا باسورد — تسريب وتنفيذ أوامر.", "فعّل requirepass واربطه بـ127.0.0.1.") }
        if set.contains(3306) || set.contains(5432) { add("قاعدة بيانات مكشوفة", 3, "قواعد البيانات ما تنكشف للشبكة أبدًا.", "اربطها بالمضيف المحليّ فقط واستعمل جدار حماية.") }
        if set.contains(161) { add("SNMP مفتوح", 3, "غالبًا بكلمة مجتمع افتراضيّة (public) تكشف تفاصيل الجهاز.", "غيّر community string أو أطفئ SNMP.") }
        if set.contains(554) { add("بثّ كاميرا (RTSP)", 2, "كاميرات المراقبة غالبًا بباسورد افتراضيّ.", "غيّر الباسورد الافتراضيّ وحدّث الفيرموير.") }
        if set.contains(80) && !set.contains(443) { add("ويب بلا تشفير", 2, "صفحة إدارة على HTTP — الباسورد يمرّ واضح.", "فعّل HTTPS، وأقفل HTTP أو حوّله لـHTTPS.") }
        if set.contains(1900) { add("UPnP مفعّل", 2, "يسمح لأجهزة بفتح منافذ بالراوتر تلقائيًّا — خطر.", "أطفئ UPnP من إعدادات الراوتر إذا ما تحتاجه.") }
        return out.sorted { $0.severity > $1.severity }
    }

    /// أعلى خطورة بقائمة منافذ (للتلوين)
    static func maxSeverity(_ ports: [Int]) -> Int { forPorts(ports).map { $0.severity }.max() ?? 0 }
}

// MARK: قائمة الفحص اليدويّ لكلمات السرّ الافتراضيّة (تعليميّ — ما يجرّب شي)

struct DefaultCred: Equatable {
    let device: String
    let user: String
    let pass: String
    let note: String
}

enum DefaultCreds {
    /// اقتراحات حسب الشركة المصنّعة — المستخدم يفحصها بنفسه على أجهزته
    static let known: [DefaultCred] = [
        DefaultCred(device: "راوترات TP-Link", user: "admin", pass: "admin", note: "جرّب تسجيل الدخول للراوتر — إذا اشتغل، غيّره فورًا"),
        DefaultCred(device: "راوترات D-Link", user: "admin", pass: "(فارغ)", note: "كثير موديلات بلا باسورد افتراضيّ"),
        DefaultCred(device: "كاميرات Hikvision", user: "admin", pass: "12345", note: "باسورد المصنع الشهير"),
        DefaultCred(device: "كاميرات Dahua", user: "admin", pass: "admin", note: "غيّره من إعدادات الكاميرا"),
        DefaultCred(device: "راسبيري باي (Raspbian)", user: "pi", pass: "raspberry", note: "غيّره بأمر passwd"),
        DefaultCred(device: "طابعات HP/الشبكة", user: "admin", pass: "(فارغ)", note: "فعّل باسورد لوحة الإدارة"),
        DefaultCred(device: "أجهزة IoT رخيصة", user: "root", pass: "root / 1234 / 12345", note: "بدّل الباسورد وحدّث الفيرموير")
    ]
    /// يرشّح القائمة حسب شركة مكتشفة
    static func forVendor(_ vendor: String) -> [DefaultCred] {
        let v = vendor.lowercased()
        return known.filter { c in
            let d = c.device.lowercased()
            if v.contains("tp-link") { return d.contains("tp-link") }
            if v.contains("d-link") { return d.contains("d-link") }
            if v.contains("hikvision") { return d.contains("hikvision") }
            if v.contains("raspberry") { return d.contains("راسبيري") }
            if v.contains("hp") { return d.contains("طابعات") }
            return false
        }
    }
}

// MARK: تقرير أمان الشبكة الشامل

struct Vuln: Equatable {
    let device: String
    let ip: String
    let advisory: Advisory
}

enum Report {
    /// يجمع كلّ الثغرات من أجهزة (اسم، IP، منافذ)
    static func build(_ devices: [(name: String, ip: String, ports: [Int])]) -> (vulns: [Vuln], score: Int, critical: Int, high: Int) {
        var vulns: [Vuln] = []
        for d in devices {
            for a in Advisories.forPorts(d.ports) { vulns.append(Vuln(device: d.name, ip: d.ip, advisory: a)) }
        }
        vulns.sort { $0.advisory.severity > $1.advisory.severity }
        let critical = vulns.filter { $0.advisory.severity == 4 }.count
        let high = vulns.filter { $0.advisory.severity == 3 }.count
        let med = vulns.filter { $0.advisory.severity == 2 }.count
        var score = 100 - critical * 22 - high * 12 - med * 5
        score = max(0, min(100, score))
        return (vulns, score, critical, high)
    }
}

// MARK: حاسبة قوّة الواي‑فاي (dBm → جودة)

enum Signal {
    static func quality(dBm: Int) -> (percent: Int, label: String) {
        let clamped = max(-100, min(-30, dBm))
        let pct = Int(Double(clamped + 100) / 70.0 * 100)
        let label = dBm >= -50 ? "ممتاز" : (dBm >= -60 ? "قويّ" : (dBm >= -70 ? "جيّد" : (dBm >= -80 ? "ضعيف" : "سيّئ")))
        return (max(0, min(100, pct)), label)
    }
}
