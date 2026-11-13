import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

let t0 = Date()
var unique = 0
var sizes: [String: Int] = [:]
for i in 0..<Hops.total {
    let l = Hops.level(i)
    let s = Hops.size(i)
    check(l.w == s.w && l.h == s.h, "level \(i) size \(l.w)x\(l.h) expected \(s.w)x\(s.h)")
    check(l.nums.count == l.count && l.solution.count == l.count, "level \(i) array sizes")
    check(Hops.valid(l, path: l.solution), "level \(i) stored solution invalid")
    check(l.solution.first == l.start, "level \(i) start")
    check(l.nums.filter { $0 == 0 }.count == 1 && l.nums[l.solution.last!] == 0, "level \(i) exactly one star at the end")
    check(l.nums.allSatisfy { $0 >= 0 && $0 < max(l.w, l.h) }, "level \(i) numbers in range")
    let c = Hops.solutions(l, cap: 3)
    check(c >= 1, "level \(i) unsolvable")
    if c == 1 { unique += 1 }
    check(Hops.level(i) == l, "level \(i) not deterministic")
    sizes["\(l.w)x\(l.h)", default: 0] += 1
    // التلميح من أيّ نقطة على الحلّ يكمّل للنهاية
    let half = Array(l.solution.prefix(l.count / 2))
    if let rest = Hops.complete(l, path: half) { check(Hops.valid(l, path: half + rest), "level \(i) hint completion invalid") } else { check(false, "level \(i) hint nil on solution path") }
}
let dt = Date().timeIntervalSince(t0)
print("levels: \(Hops.total), unique-solution: \(unique), sizes: \(sizes.sorted { $0.key < $1.key }), time: \(String(format: "%.2f", dt))s")
check(unique >= Hops.total * 2 / 3, "too few unique-solution levels: \(unique)")
check(dt < 60, "generation too slow: \(dt)s")

// ── الحركات
let l = Level(w: 3, h: 3, nums: [2, 1, 1, 1, 1, 1, 1, 1, 0], start: 0, solution: [])
var v = [Bool](repeating: false, count: 9); v[0] = true
check(Set(Hops.moves(l, visited: v, at: 0)) == [2, 6], "moves from corner with 2: \(Hops.moves(l, visited: v, at: 0))")
v[2] = true
check(Hops.moves(l, visited: v, at: 0) == [6], "visited cells excluded")
check(Hops.moves(l, visited: v, at: 8).isEmpty, "star has no moves")
check(Set(Hops.moves(l, visited: v, at: 4)) == [3, 5, 1, 7], "center moves")

// ── وضع مسدود ما إله تكملة
let dead = Level(w: 2, h: 2, nums: [1, 1, 0, 1], start: 0, solution: [0, 1, 3, 2])
check(Hops.valid(dead, path: [0, 1, 3, 2]) && !Hops.valid(dead, path: [0, 2, 3, 1]) && !Hops.valid(dead, path: [0, 1, 3]), "valid()")
check(Hops.complete(dead, path: [0, 2]) == nil, "dead end has no completion")
check(Hops.complete(dead, path: [0]) == [1, 3, 2], "completion from start")

// ── لغز اليوم ثابت ويختلف بين الأيّام
let d1 = Hops.daily(year: 2026, month: 11, day: 13), d2 = Hops.daily(year: 2026, month: 11, day: 14)
check(d1 == Hops.daily(year: 2026, month: 11, day: 13) && d1 != d2, "daily deterministic and varies")
check(Hops.valid(d1, path: d1.solution) && Hops.valid(d2, path: d2.solution), "daily solvable")

// ── الحفظ
check((try? JSONDecoder().decode(Level.self, from: JSONEncoder().encode(d1))) == d1, "codable")

print(failures == 0 ? "ALL QAFZA TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
