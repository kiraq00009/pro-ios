import Foundation

/// حساب مستوى الصوت: RMS ← dBFS ← ديسيبل تقريبيّ (SPL) بمعايرة
enum Level {
    static func rms(_ x: [Float]) -> Double {
        guard !x.isEmpty else { return 0 }
        var s = 0.0
        for v in x { let d = Double(v); s += d * d }
        return (s / Double(x.count)).squareRoot()
    }

    /// ديسيبل نسبةً للأقصى الرقمي (0 = أعلى شي، سالب للأوطأ). أوطأ حدّ ‎-140
    static func dbfs(rms: Double) -> Double {
        20 * log10(max(rms, 1e-7))
    }

    /// تقدير ديسيبل الغرفة: dBFS + معايرة، محصور 0..130
    static func spl(rms: Double, offset: Double) -> Double {
        min(130, max(0, dbfs(rms: rms) + offset))
    }

    /// المتوسط الطاقيّ (Leq) لعدّة قراءات بنفس المدّة
    static func leq(_ levels: [Double]) -> Double {
        guard !levels.isEmpty else { return 0 }
        var e = 0.0
        for l in levels { e += pow(10, l / 10) }
        return 10 * log10(e / Double(levels.count))
    }

    /// المدّة المسموحة يوميًّا لمستوى معيّن (قاعدة 85 dB لثماني ساعات، كلّ ‎+3 dB نصّ المدّة)
    static func allowedSeconds(_ l: Double) -> Double {
        8 * 3600 / pow(2, (l - 85) / 3)
    }

    /// تنعيم القراءة: صعود سريع ونزول هادئ (مثل عدّادات الصوت)
    static func smooth(_ prev: Double, _ new: Double, attack: Double = 0.55, release: Double = 0.18) -> Double {
        let k = new > prev ? attack : release
        return prev + (new - prev) * k
    }

    /// منطقة الضجيج 0..4
    static func zone(_ db: Double) -> Int {
        if db < 40 { return 0 }
        if db < 60 { return 1 }
        if db < 75 { return 2 }
        if db < 85 { return 3 }
        return 4
    }

    static let zoneAr = ["هادئ", "طبيعي", "مرتفع", "مزعج", "مؤذٍ للسمع"]
    static let zoneTip = [
        "جوّ هادئ، مثالي للنوم والتركيز",
        "مستوى كلام عادي ومريح",
        "صوت عالي، يتعب إذا طال",
        "مزعج — خفّف المدّة أو ابتعد",
        "خطر على السمع مع الوقت، استعمل سدّادات",
    ]

    /// نسبة 0..1 لعرض المؤشّر بين 20 و 110 dB
    static func gauge(_ db: Double) -> Double {
        min(1, max(0, (db - 20) / 90))
    }
}

/// التعرّض اليوميّ للضجيج
struct Exposure: Codable, Equatable {
    var dose: Double = 0        // 1.0 = الحدّ اليوميّ كامل
    var seconds: Double = 0
    var energy: Double = 0      // مجموع 10^(L/10)·dt
    var peak: Double = 0
    var loudSeconds: Double = 0 // وقت فوق 75 dB

    mutating func add(level: Double, seconds dt: Double) {
        guard dt > 0 else { return }
        seconds += dt
        energy += pow(10, level / 10) * dt
        dose += dt / Level.allowedSeconds(level)
        peak = max(peak, level)
        if level >= 75 { loudSeconds += dt }
    }

    var leq: Double { seconds > 0 ? 10 * log10(energy / seconds) : 0 }
    var percent: Double { dose * 100 }
}
