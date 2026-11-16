import Foundation

/// حسابات النغمات: تردّد ↔ رقم MIDI ↔ سنت، وأسماء النغمات غربي وصولفيج عربي
enum NoteMath {
    static let wNames: [String] = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    static let sNames: [String] = ["دو", "دو♯", "ري", "ري♯", "مي", "فا", "فا♯", "صول", "صول♯", "لا", "لا♯", "سي"]
    /// الحرف بدون علامة الدييز (للعرض الكبير)
    static let wLetters: [String] = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
    static let sLetters: [String] = ["دو", "دو", "ري", "ري", "مي", "فا", "فا", "صول", "صول", "لا", "لا", "سي"]

    static func midi(freq: Double, a4: Double = 440) -> Double {
        guard freq > 0, a4 > 0 else { return 0 }
        return 69 + 12 * log2(freq / a4)
    }

    static func freq(midi: Double, a4: Double = 440) -> Double {
        a4 * pow(2, (midi - 69) / 12)
    }

    /// فرق السنت بين تردّدين (موجب = أعلى من المرجع)
    static func cents(_ f: Double, from ref: Double) -> Double {
        guard f > 0, ref > 0 else { return 0 }
        return 1200 * log2(f / ref)
    }

    static func pitchClass(_ m: Int) -> Int { ((m % 12) + 12) % 12 }
    static func octave(_ m: Int) -> Int { Int(floor(Double(m) / 12)) - 1 }
    static func isSharp(_ m: Int) -> Bool { [1, 3, 6, 8, 10].contains(pitchClass(m)) }

    static func name(_ m: Int) -> String { "\(wNames[pitchClass(m)])\(octave(m))" }
    static func western(_ m: Int) -> String { wNames[pitchClass(m)] }
    static func solfege(_ m: Int) -> String { sNames[pitchClass(m)] }
    static func solfegeName(_ m: Int) -> String { "\(sNames[pitchClass(m)]) \(octave(m))" }

    /// قراءة كاملة لتردّد: أقرب نغمة + الانحراف بالسنت
    static func reading(freq: Double, a4: Double = 440) -> NoteReading {
        let exact = midi(freq: freq, a4: a4)
        let n = Int(exact.rounded())
        return NoteReading(freq: freq, exact: exact, midi: n, cents: (exact - Double(n)) * 100)
    }

    /// يطوي النغمة المغنّاة لأقرب أوكتاف من الهدف (للمقارنة بدون عقوبة اختلاف الطبقة)
    static func fold(_ sung: Double, near target: Double) -> Double {
        sung + 12 * ((target - sung) / 12).rounded()
    }
}

struct NoteReading: Equatable {
    var freq: Double
    var exact: Double
    var midi: Int
    var cents: Double
}
