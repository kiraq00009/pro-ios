import Foundation

/// دوزان (ضبط) لآلة: أرقام MIDI للأوتار من الأغلظ للأرفع
struct Tuning: Identifiable, Hashable {
    let id: String
    let name: String
    let notes: [Int]
}

struct Instrument: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let tunings: [Tuning]
    var isChromatic: Bool { tunings.isEmpty }
}

enum Instruments {
    static let chromatic = Instrument(id: "chromatic", name: "كروماتيك", symbol: "tuningfork", tunings: [])

    static let guitar = Instrument(id: "guitar", name: "جيتار", symbol: "guitars", tunings: [
        Tuning(id: "g_std", name: "قياسي", notes: [40, 45, 50, 55, 59, 64]),
        Tuning(id: "g_dropd", name: "دروب D", notes: [38, 45, 50, 55, 59, 64]),
        Tuning(id: "g_dadgad", name: "DADGAD", notes: [38, 45, 50, 55, 57, 62]),
        Tuning(id: "g_half", name: "نصف درجة أوطى", notes: [39, 44, 49, 54, 58, 63]),
        Tuning(id: "g_openg", name: "Open G", notes: [38, 43, 50, 55, 59, 62]),
        Tuning(id: "g_opend", name: "Open D", notes: [38, 45, 50, 54, 57, 62]),
    ])

    static let bass = Instrument(id: "bass", name: "باص", symbol: "guitars.fill", tunings: [
        Tuning(id: "b_std", name: "٤ أوتار", notes: [28, 33, 38, 43]),
        Tuning(id: "b_five", name: "٥ أوتار", notes: [23, 28, 33, 38, 43]),
        Tuning(id: "b_dropd", name: "دروب D", notes: [26, 33, 38, 43]),
    ])

    static let ukulele = Instrument(id: "ukulele", name: "يوكوليلي", symbol: "music.note", tunings: [
        Tuning(id: "u_std", name: "قياسي GCEA", notes: [67, 60, 64, 69]),
        Tuning(id: "u_lowg", name: "G منخفض", notes: [55, 60, 64, 69]),
        Tuning(id: "u_bari", name: "باريتون", notes: [50, 55, 59, 64]),
    ])

    static let violin = Instrument(id: "violin", name: "كمان", symbol: "music.quarternote.3", tunings: [
        Tuning(id: "v_std", name: "كمان", notes: [55, 62, 69, 76]),
        Tuning(id: "v_viola", name: "فيولا", notes: [48, 55, 62, 69]),
        Tuning(id: "v_cello", name: "تشيلو", notes: [36, 43, 50, 57]),
    ])

    static let oud = Instrument(id: "oud", name: "عود", symbol: "music.note.list", tunings: [
        Tuning(id: "o_classic", name: "كلاسيكي (دو فا لا ري صول دو)", notes: [36, 41, 45, 50, 55, 60]),
        Tuning(id: "o_d", name: "ري (ري صول لا ري صول دو)", notes: [38, 43, 45, 50, 55, 60]),
        Tuning(id: "o_f", name: "فا (فا لا ري صول دو فا)", notes: [41, 45, 50, 55, 60, 65]),
    ])

    static let all: [Instrument] = [chromatic, guitar, bass, ukulele, violin, oud]

    static func find(_ id: String) -> Instrument { all.first { $0.id == id } ?? chromatic }

    static func tuning(_ inst: Instrument, _ id: String) -> Tuning? {
        inst.tunings.first { $0.id == id } ?? inst.tunings.first
    }
}

enum StringFinder {
    /// أقرب وتر للتردّد المسموع (بالسنت)
    static func closest(freq: Double, notes: [Int], a4: Double = 440) -> (index: Int, cents: Double)? {
        guard freq > 0, !notes.isEmpty else { return nil }
        var best = 0
        var bestCents = Double.greatestFiniteMagnitude
        for (i, n) in notes.enumerated() {
            let c = NoteMath.cents(freq, from: NoteMath.freq(midi: Double(n), a4: a4))
            if abs(c) < abs(bestCents) { bestCents = c; best = i }
        }
        return (best, bestCents)
    }

    /// إرشاد الضبط بالكلام
    static func advice(cents: Double, tolerance: Double) -> String {
        if abs(cents) <= tolerance { return "مضبوط تمامًا" }
        if cents > 0 { return abs(cents) > 40 ? "عالي كثير — رخِّ الوتر" : "عالي شويّة — رخِّ بهدوء" }
        return abs(cents) > 40 ? "واطي كثير — شدّ الوتر" : "واطي شويّة — شدّ بهدوء"
    }
}

/// قفل «مضبوط»: لازم تبقى النغمة داخل الحدّ مدّة كافية حتى يثبت، وتطلع لبرّا بهامش حتى ينفكّ
struct InTuneLock {
    var tolerance: Double = 3
    var holdTime: Double = 0.6
    var release: Double = 2.2   // مضاعف الحدّ للخروج
    var graceGap: Double = 0.35
    private(set) var locked = false
    private(set) var held: Double = 0
    private var gap: Double = 0

    init(tolerance: Double = 3, holdTime: Double = 0.6) {
        self.tolerance = tolerance
        self.holdTime = holdTime
    }

    var progress: Double { locked ? 1 : min(1, held / max(0.01, holdTime)) }

    /// ترجع true بلحظة القفل فقط
    mutating func update(cents: Double?, dt: Double) -> Bool {
        guard let c = cents else {
            gap += dt
            if gap > graceGap { locked = false; held = 0 }
            return false
        }
        gap = 0
        if locked {
            if abs(c) > tolerance * release { locked = false; held = 0 }
            return false
        }
        if abs(c) <= tolerance {
            held += dt
            if held >= holdTime { locked = true; return true }
        } else {
            held = max(0, held - dt * 2)
        }
        return false
    }

    mutating func reset() { locked = false; held = 0; gap = 0 }
}
