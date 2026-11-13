import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

struct LCG: RandomNumberGenerator {
    var s: UInt64
    mutating func next() -> UInt64 { s = s &* 6364136223846793005 &+ 1442695040888963407; return s }
}
func empty() -> Board { Board(pts: [Int](repeating: 0, count: 24)) }

// ── الوضع الابتدائيّ
let b0 = Board.start
check(b0.total(0) == 15 && b0.total(1) == 15, "15 checkers each")
check(b0.pips(0) == 167 && b0.pips(1) == 167, "starting pip count 167: \(b0.pips(0)) \(b0.pips(1))")
check(!b0.allHome(0) && b0.winner == nil, "start state")

// ── رمية 3-1 من البداية: حركات معروفة
let t31 = BG.turns(b0, 0, dice: BG.dice(3, 1))
check(!t31.isEmpty && t31.allSatisfy { $0.count == 2 }, "3-1 uses both dice")
check(t31.contains { Set($0.map { "\($0.from)>\($0.to)" }) == ["7>4", "5>4"] }, "3-1 can make the 5-point")
// الدبل ينلعب ٤ مرّات
check(BG.turns(b0, 0, dice: BG.dice(6, 6)).allSatisfy { $0.count == 4 }, "double plays four")
// ما يگدر ينزل على خانة مقفولة: 23 بزار 5 ⇒ الخانة 18 بيها ٥ للخصم
check(!b0.moves(0, die: 5).contains { $0.from == 23 }, "blocked point")

// ── البار: لازم يدخل أوّل، وإذا كلّ الخانات مقفولة ما يلعب
var bb = empty(); bb.bar[0] = 1; bb.pts[10] = 14
for i in 18...23 { bb.pts[i] = -2 }
bb.pts[0] = -3
check(BG.turns(bb, 0, dice: BG.dice(3, 5)).isEmpty, "closed board: no entry")
bb.pts[20] = 0; bb.pts[0] = -5       // نفتح خانة الدخول بزار 4
check(BG.turns(bb, 0, dice: BG.dice(4, 2)).allSatisfy { $0[0].from == -1 && $0[0].to == 20 }, "must enter from bar first")
// الضرب: حجر منفرد للخصم ينضرب ويروح للبار
var hb = empty(); hb.pts[10] = 1; hb.pts[7] = -1; hb.pts[0] = 14; hb.pts[23] = -14
let hm = hb.moves(0, die: 3).first { $0.from == 10 }
check(hm?.hit == true, "hit flagged")
let after = hb.applying(hm!, 0)
check(after.bar[1] == 1 && after.pts[7] == 1 && after.total(1) == 15 && after.total(0) == 15, "hit sends to bar")

// ── لازم يلعب الزارين إذا ممكن، وإذا واحد بس فالأكبر
var mb = empty(); mb.pts[10] = 1; mb.pts[0] = 14; mb.pts[23] = -11; mb.pts[4] = -2; mb.pts[3] = -2   // 10: بزار 6 ⇒ 4 مقفولة، بزار 1 ⇒ 9 ثمّ 6 ⇒ 3 مقفولة
let mt = BG.turns(mb, 0, dice: BG.dice(6, 1))
check(mt.allSatisfy { $0.count == 1 && $0[0].die == 1 } || mt.allSatisfy { $0.count == 2 }, "forced move rule holds: \(mt)")
var lb = empty(); lb.pts[12] = 1; lb.pts[0] = 14; lb.pts[23] = -15       // حجر واحد حرّ: يگدر يلعب 5 أو 3 أو الاثنين
check(BG.turns(lb, 0, dice: BG.dice(5, 3)).allSatisfy { $0.count == 2 }, "plays both when possible")
var big = empty(); big.pts[8] = 1; big.pts[0] = 14; big.pts[23] = -11; big.pts[3] = -2; big.pts[2] = -2; big.pts[5] = 0
// من 8: بزار 5 ⇒ 3 مقفولة · بزار 6 ⇒ 2 مقفولة · ما يگدر يلعب بالحجر 8. الأحجار بالخانة 0 ما تطلع لأنّ مو كلّهم بالبيت
check(BG.turns(big, 0, dice: BG.dice(5, 6)).isEmpty, "no legal move at all")

// ── الإخراج
var eb = empty(); eb.pts[5] = 2; eb.pts[2] = 3; eb.pts[23] = -15; eb.off[0] = 10
check(eb.allHome(0), "all home")
check(eb.moves(0, die: 6).contains { $0.from == 5 && $0.to == 99 }, "exact bear off")
check(eb.moves(0, die: 3).contains { $0.from == 2 && $0.to == 99 } && eb.moves(0, die: 3).contains { $0.from == 5 && $0.to == 2 }, "bear off or move inside")
var eb2 = empty(); eb2.pts[2] = 3; eb2.pts[23] = -15; eb2.off[0] = 12
check(eb2.moves(0, die: 6).contains { $0.from == 2 && $0.to == 99 }, "bigger die bears off the farthest")
check(!eb.moves(0, die: 4).contains { $0.from == 2 && $0.to == 99 }, "bigger die not allowed when a farther checker exists")
var nh = eb; nh.pts[10] = 1; nh.off[0] = 9
check(!nh.moves(0, die: 6).contains { $0.to == 99 }, "no bearing off unless all home")
// اللاعب 1 (المرآة)
var e1 = empty(); e1.pts[18] = -2; e1.pts[0] = 15; e1.off[1] = 13
check(e1.moves(1, die: 6).contains { $0.from == 18 && $0.to == 99 } && e1.moves(1, die: 2).contains { $0.to == 20 }, "player 1 bear off mirrored")

// ── قيمة الفوز
var w1 = empty(); w1.off[0] = 15; w1.off[1] = 3; w1.pts[20] = -12
check(w1.winner == 0 && w1.winValue(0) == 1, "single win")
var w2 = empty(); w2.off[0] = 15; w2.pts[20] = -15
check(w2.winValue(0) == 2, "gammon")
var w3 = empty(); w3.off[0] = 15; w3.pts[3] = -1; w3.pts[20] = -14
check(w3.winValue(0) == 3, "backgammon")

// ── مباريات كاملة: القواعد ما تنكسر، واللعبة تخلص، والذكاء يغلب العشوائيّ
var rng = LCG(s: 99)
func play(levels: [Int], seed: UInt64) -> (winner: Int, turns: Int) {
    var r = LCG(s: seed)
    var b = Board.start
    var p = Int.random(in: 0...1, using: &r), n = 0
    while b.winner == nil && n < 2000 {
        let d = BG.dice(Int.random(in: 1...6, using: &r), Int.random(in: 1...6, using: &r))
        let all = BG.turns(b, p, dice: d)
        let t: [Move] = levels[p] < 0 ? (all.randomElement(using: &r) ?? []) : BG.choose(b, p, dice: d, level: levels[p], using: &r)
        check(all.isEmpty ? t.isEmpty : all.contains(t), "AI chose an illegal turn")
        for m in t { b = b.applying(m, p) }
        check(b.total(0) == 15 && b.total(1) == 15 && b.pts.allSatisfy { abs($0) <= 15 } && b.bar[0] >= 0 && b.bar[1] >= 0, "invariant broken")
        p = 1 - p; n += 1
    }
    check(b.winner != nil, "game did not finish")
    return (b.winner ?? -1, n)
}
let t0 = Date()
var wins = 0, total = 0, turnsSum = 0
for g in 0..<120 { let r = play(levels: [1, -1], seed: UInt64(g) &* 77 &+ 3); if r.winner == 0 { wins += 1 }; total += 1; turnsSum += r.turns }
print("medium vs random: \(wins)/\(total), avg turns \(turnsSum / total)")
check(wins >= total * 85 / 100, "medium AI should crush random")
var w2m = 0
for g in 0..<40 { if play(levels: [1, 0], seed: UInt64(g) &* 131 &+ 9).winner == 0 { w2m += 1 } }
print("medium vs easy: \(w2m)/40")
check(w2m >= 22, "medium should beat easy")
var hw = 0
for g in 0..<30 { if play(levels: [2, 1], seed: UInt64(g) &* 911 &+ 1).winner == 0 { hw += 1 } }
for g in 0..<30 { if play(levels: [1, 2], seed: UInt64(g) &* 577 &+ 4).winner == 1 { hw += 1 } }
print("hard vs medium: \(hw)/60, time \(String(format: "%.1f", Date().timeIntervalSince(t0)))s")
check(hw >= 31, "hard should beat medium")
check(Date().timeIntervalSince(t0) < 240, "too slow")

print(failures == 0 ? "ALL NARD TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
