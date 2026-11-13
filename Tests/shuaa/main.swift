import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ── الانعكاس: كلّ مراية ترجّع الشعاع لنفس الطريق إذا انعكس مرّتين من الجهة المعاكسة
for d in 0..<4 {
    for slash in [true, false] {
        let r = Beam.reflect(d, slash: slash)
        check(r != d && (r + d) % 2 == 1, "reflect turns 90°: d=\(d) slash=\(slash) → \(r)")
        check(Beam.reflect((r + 2) % 4, slash: slash) == (d + 2) % 4, "reflect reversible: d=\(d) slash=\(slash)")
    }
}
check(Beam.reflect(0, slash: true) == 3 && Beam.reflect(0, slash: false) == 1, "right hits / goes up, hits \\ goes down")

// ── مسار يدويّ
let tiny = BeamLevel(w: 3, h: 3, tiles: [.empty, .mirrorB, .empty, .empty, .empty, .empty, .empty, .target, .empty], src: 0, dir: 0, par: 0)
let tr = Beam.trace(tiny)
check(tr.cells == [0, 1, 4, 7] && tr.lit == [7] && !tr.loop, "manual trace: \(tr.cells)")
check(Beam.solved(tiny), "tiny solved")
let flipped = Beam.flipped(tiny, at: 1)
check(!Beam.solved(flipped) && Beam.trace(flipped).cells == [0, 1], "flipped mirror sends beam out")
check(Beam.flipped(flipped, at: 1) == tiny && Beam.flipped(tiny, at: 0) == tiny, "flip toggles only movable mirrors")
if let s = Beam.solve(flipped) { check(s.flips == 1 && s.which == [1], "solver finds the single flip") } else { check(false, "solver nil") }
// الجدار يوقّف الشعاع
let walled = BeamLevel(w: 3, h: 1, tiles: [.empty, .wall, .target], src: 0, dir: 0, par: 0)
check(Beam.trace(walled).lit.isEmpty && Beam.solve(walled) == nil, "wall blocks, unsolvable")
// حلقة مرايا ما تعلّق
let ring = BeamLevel(w: 3, h: 3, tiles: [.empty, .fixedB, .empty, .fixedA, .fixedB, .empty, .fixedB, .fixedA, .empty], src: 0, dir: 0, par: 0)
check(Beam.trace(ring).cells.count < 60, "trace always terminates")

// ── كلّ المراحل
let t0 = Date()
var parSum = 0
for i in 0..<Beam.total {
    let l = Beam.level(i)
    let s = Beam.spec(i)
    check(l.w == s.w && l.h == s.h && l.tiles.count == l.count, "level \(i) size")
    check(Beam.targets(l) >= 1, "level \(i) has targets")
    check(!Beam.solved(l), "level \(i) starts solved")
    if let sol = Beam.solve(l) {
        check(sol.flips == l.par && l.par >= 1, "level \(i) par \(l.par) vs solver \(sol.flips)")
        var c = l; for m in sol.which { c = Beam.flipped(c, at: m) }
        check(Beam.solved(c), "level \(i) solver answer does not solve")
        parSum += l.par
    } else { check(false, "level \(i) unsolvable") }
    check(l.tiles[l.src] == .empty, "level \(i) source cell free")
    check(Beam.level(i) == l, "level \(i) not deterministic")
}
let dt = Date().timeIntervalSince(t0)
print("levels: \(Beam.total), avg par: \(String(format: "%.1f", Double(parSum) / Double(Beam.total))), time: \(String(format: "%.2f", dt))s")
check(dt < 60, "generation too slow \(dt)")
check(Double(parSum) / Double(Beam.total) >= 2, "levels too easy")

let d1 = Beam.daily(year: 2026, month: 11, day: 13)
check(d1 == Beam.daily(year: 2026, month: 11, day: 13) && d1 != Beam.daily(year: 2026, month: 11, day: 14) && Beam.solve(d1) != nil, "daily")
check((try? JSONDecoder().decode(BeamLevel.self, from: JSONEncoder().encode(d1))) == d1, "codable")

print(failures == 0 ? "ALL SHUAA TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
