import Foundation

/// مكدّس تراجع/إعادة عامّ: نخزّن الحالة قبل كلّ تعديل
struct History<T: Equatable> {
    private(set) var past: [T] = []
    private(set) var future: [T] = []
    let limit: Int

    init(limit: Int = 60) { self.limit = max(1, limit) }

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    /// سجّل الحالة السابقة لتعديل جديد (يمسح مسار الإعادة)
    mutating func record(_ before: T) {
        future.removeAll()
        if let last = past.last, last == before { return }
        past.append(before)
        if past.count > limit { past.removeFirst(past.count - limit) }
    }

    /// يرجّع الحالة السابقة ويحفظ الحاليّة للإعادة
    mutating func undo(_ current: T) -> T? {
        guard let p = past.popLast() else { return nil }
        future.append(current)
        return p
    }

    mutating func redo(_ current: T) -> T? {
        guard let n = future.popLast() else { return nil }
        past.append(current)
        if past.count > limit { past.removeFirst(past.count - limit) }
        return n
    }

    mutating func reset() { past.removeAll(); future.removeAll() }
}
