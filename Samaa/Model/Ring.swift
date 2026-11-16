import Foundation

/// مخزن دائريّ ثابت الحجم: يحتفظ بآخر capacity عنصر (لصوت آخر ثواني حتى نحفظ مقطع حول الحدث)
struct Ring<T> {
    private(set) var buf: [T]
    let capacity: Int
    private(set) var head = 0      // مكان الكتابة الجاية
    private(set) var count = 0

    init(capacity: Int, fill: T) {
        let c = max(1, capacity)
        self.capacity = c
        buf = [T](repeating: fill, count: c)
    }

    var isFull: Bool { count == capacity }

    /// مكان أقدم عنصر بالمصفوفة
    var startIndex: Int { (head - count + capacity) % capacity }

    /// الفهرس الحقيقيّ للعنصر المنطقيّ i (0 = الأقدم)
    func physical(_ i: Int) -> Int { (startIndex + i) % capacity }

    subscript(logical i: Int) -> T { buf[physical(i)] }

    mutating func append(_ x: T) {
        buf[head] = x
        head = (head + 1) % capacity
        count = min(capacity, count + 1)
    }

    mutating func append(contentsOf xs: [T]) {
        if xs.count >= capacity {
            // يكفي آخر capacity عنصر
            let tail = xs[(xs.count - capacity)...]
            var i = 0
            for x in tail { buf[i] = x; i += 1 }
            head = 0
            count = capacity
            return
        }
        for x in xs { append(x) }
    }

    /// آخر n عناصر بالترتيب الزمنيّ
    func last(_ n: Int) -> [T] {
        let k = min(max(0, n), count)
        var out: [T] = []
        out.reserveCapacity(k)
        var i = count - k
        while i < count { out.append(self[logical: i]); i += 1 }
        return out
    }

    func ordered() -> [T] { last(count) }

    mutating func removeAll() {
        head = 0
        count = 0
    }
}

enum ClipMath {
    /// عيّنات أقلّ بالمتوسط (تصغير حجم المقطع): factor عيّنات ← وحدة
    static func decimate(_ x: [Float], factor: Int) -> [Float] {
        let f = max(1, factor)
        if f == 1 { return x }
        var out: [Float] = []
        out.reserveCapacity(x.count / f + 1)
        var i = 0
        while i < x.count {
            let j = min(x.count, i + f)
            var s: Float = 0
            var k = i
            while k < j { s += x[k]; k += 1 }
            out.append(s / Float(j - i))
            i = j
        }
        return out
    }

    /// تكبير هادئ حتى يصير أعلى شي target، وبحدّ أعلى للتكبير
    static func normalize(_ x: [Float], target: Float = 0.8, maxGain: Float = 8) -> [Float] {
        var peak: Float = 0
        for v in x { peak = max(peak, abs(v)) }
        guard peak > 0 else { return x }
        let g = min(maxGain, target / peak)
        return x.map { $0 * g }
    }

    static func factor(sampleRate: Double, target: Double = 16000) -> Int {
        max(1, Int((sampleRate / target).rounded(.down)))
    }
}
