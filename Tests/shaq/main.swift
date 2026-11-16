import Foundation

var failures = 0
var checks = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { checks += 1; if !ok { failures += 1; print("FAIL: " + msg()) } }
func near(_ a: Double, _ b: Double, _ e: Double = 1e-7) -> Bool { abs(a - b) <= e }
func areas(_ s: [Shape]) -> [Double] { s.map { $0.area }.sorted() }

let unitSquare = Shape([P(0, 0), P(1, 0), P(1, 1), P(0, 1)])

// ── رباط الحذاء
check(near(Poly.signedArea(unitSquare.outer), 1), "unit square CCW area = 1")
check(near(Poly.signedArea(Array(unitSquare.outer.reversed())), -1), "CW square area = -1")
check(near(Poly.area([P(0, 0), P(4, 0), P(0, 3)]), 6), "3-4-5 triangle area 6")
check(near(Poly.area([P(0, 0), P(1, 1)]), 0), "degenerate ring area 0")
let c0 = Poly.centroid(unitSquare.outer)
check(near(c0.x, 0.5) && near(c0.y, 0.5), "square centroid")
check(Poly.contains(unitSquare.outer, P(0.5, 0.5)) && !Poly.contains(unitSquare.outer, P(1.5, 0.5)), "point in polygon")
check(near(Poly.perimeter(unitSquare.outer), 4), "perimeter")

// ── شكل بثقب
let frame = Shape([P(-1, -1), P(1, -1), P(1, 1), P(-1, 1)], holes: [[P(-0.5, -0.5), P(0.5, -0.5), P(0.5, 0.5), P(-0.5, 0.5)]])
check(near(frame.area, 3), "frame area 4 - 1 = 3: \(frame.area)")
check(!frame.contains(P(0, 0)) && frame.contains(P(0.75, 0)), "hole is not inside the shape")
check(near(frame.centroid.x, 0) && near(frame.centroid.y, 0), "symmetric frame centroid at origin")

// ── قطع المربّع من النصّ = ٥٠٪
let mid = Cutter.split(unitSquare, by: Line(P(0.5, -1), P(0.5, 2)))
check(mid.crossed && mid.plus.count == 1 && mid.minus.count == 1, "square cut in two")
check(near(mid.plusArea, 0.5) && near(mid.minusArea, 0.5), "halves are 0.5: \(mid.plusArea) \(mid.minusArea)")
check(near(Judge.smallerPercent(mid), 50), "50%")
// القطر يمرّ بالرؤوس بالضبط
let diag = Cutter.split(unitSquare, by: Line(P(0, 0), P(1, 1)))
check(diag.pieces.count == 2 && near(diag.plusArea, 0.5) && near(diag.minusArea, 0.5), "diagonal through vertices = two triangles")
check(diag.pieces.allSatisfy { $0.outer.count == 3 }, "diagonal pieces are triangles")
// ربع
let q = Cutter.split(unitSquare, by: Line(P(-1, 0.25), P(2, 0.25)))
check(near(Judge.smallerPercent(q), 25), "quarter cut = 25%")
// خطّ ما يلمس الشكل
let miss = Cutter.split(unitSquare, by: Line(P(-1, 2), P(2, 2)))
check(!miss.crossed && miss.pieces.count == 1 && near(miss.pieces[0].area, 1), "line outside: one untouched piece")
// خطّ على ضلع
let edge = Cutter.split(unitSquare, by: Line(P(1, -1), P(1, 2)))
check(!edge.crossed && near(edge.plusArea + edge.minusArea, 1), "line along an edge does not cut")
// اتّجاه الخطّ ما يغيّر النسبة
let rev = Cutter.split(unitSquare, by: Line(P(0.5, 2), P(0.5, -1)))
check(near(rev.plusArea, 0.5) && near(Judge.smallerPercent(rev), 50), "reversed direction same split")

// ── شكل L مقعّر: خطّ واحد يطلّع ٣ قطع
let L3 = Shape([P(0, 0), P(3, 0), P(3, 1), P(1, 1), P(1, 3), P(0, 3)])
check(near(L3.area, 5), "L area 5")
let lc = Cutter.split(L3, by: Line(P(3, -0.5), P(-0.5, 3)))
check(lc.pieces.count == 3, "concave L cut by one line into 3 pieces: \(lc.pieces.count)")
let la = areas(lc.pieces)
check(la.count == 3 && near(la[0], 1) && near(la[1], 1) && near(la[2], 3), "L pieces 1,1,3: \(la)")
check((lc.plus.count == 2 && lc.minus.count == 1) || (lc.plus.count == 1 && lc.minus.count == 2), "two tips on one side, body on the other")
check(near(Judge.smallerPercent(lc), 40), "L tips total 40%")
// نفس الشكل بخطّ يمرّ بالزاوية المقعّرة بالضبط
let lv = Cutter.split(L3, by: Line(P(1, 1), P(2, 2)))
check(near(lv.plusArea + lv.minusArea, 5), "reflex vertex cut keeps total area")

// ── الحرف S: خطّ عموديّ يقطعه لقطع كثيرة
let S = ShapeLib.make(.sLetter, seed: 1, vary: false)
let sc = Cutter.split(S, by: Line(P(0.05, -3), P(0.05, 3)))
check(sc.pieces.count >= 3, "S cut vertically gives 3+ pieces: \(sc.pieces.count)")
check(near(sc.plusArea + sc.minusArea, S.area, 1e-6), "S pieces sum to area")

// ── الإطار المثقوب
let fm = Cutter.split(frame, by: Line(P(0, -2), P(0, 2)))
check(fm.pieces.count == 2 && near(fm.plusArea, 1.5) && near(fm.minusArea, 1.5), "frame through hole: two U halves 1.5 each")
check(fm.pieces.allSatisfy { $0.holes.isEmpty }, "cut through the hole opens it")
let fs = Cutter.split(frame, by: Line(P(0.75, -2), P(0.75, 2)))
let big = fs.pieces.max { $0.area < $1.area }
check(fs.pieces.count == 2 && big?.holes.count == 1, "hole stays inside the big piece")
check(near(big?.area ?? 0, 2.5) && near(Judge.smallerPercent(fs), 0.5 / 3 * 100), "frame side cut 2.5 / 0.5")

// ── جبنة بثلاث ثقوب: مقارنة مع قصّ نصف المستوى بآلاف الخطوط
var rg = SRng(99)
var mismatch = 0
var lost = 0
let pool: [Shape] = [unitSquare, L3, frame, S, ShapeLib.make(.cheese, seed: 5), ShapeLib.make(.star, seed: 2), ShapeLib.make(.ring, seed: 8), ShapeLib.make(.gear, seed: 3), ShapeLib.make(.heart, seed: 1), ShapeLib.make(.moon, seed: 1), ShapeLib.make(.eLetter, seed: 4)]
for s in pool {
    let A = s.area
    for k in 0..<400 {
        var a = P(rg.range(-1.5, 1.5), rg.range(-1.5, 1.5))
        if k % 8 == 0 { a = s.outer[rg.int(s.outer.count)] }          // يمرّ برأس
        let L = Line(point: a, dir: P(1, 0).rotated(rg.range(0, 2 * Double.pi)))
        let r = Cutter.split(s, by: L)
        let exact = Cutter.sideArea(s, L, plus: true)
        if !near(r.plusArea, exact, 1e-6) { mismatch += 1 }
        if !near(r.plusArea + r.minusArea, A, 1e-6) { lost += 1 }
    }
}
check(mismatch == 0, "split areas match half-plane clipping (\(mismatch) mismatches)")
check(lost == 0, "split never loses area (\(lost))")

// ── قطعتان: ثلث وثلث وثلث
let two = Cutter.splitAll(Cutter.split(unitSquare, by: Line(P(1.0 / 3, -1), P(1.0 / 3, 2))).pieces, by: Line(P(2.0 / 3, -1), P(2.0 / 3, 2)))
check(two.pieces.count == 3 && two.cutCount == 1, "two parallel cuts = 3 pieces")
check(near(Judge.equalError(two.pieces, n: 3), 0, 1e-6), "three equal thirds")
let cross = Cutter.splitAll(Cutter.split(unitSquare, by: Line(P(0.5, -1), P(0.5, 2))).pieces, by: Line(P(-1, 0.5), P(2, 0.5)))
check(cross.pieces.count == 4 && cross.cutCount == 2, "cross cut = 4 pieces")
check(near(Judge.equalError(cross.pieces, n: 4), 0, 1e-6), "four equal quarters")
check(Judge.equalError(cross.pieces, n: 3) == 20, "wrong piece count = max error")
let pcts = Judge.percents(cross.pieces)
check(near(pcts.reduce(0, +), 100), "percents sum to 100")

// ── الحلّ (تنصيف ثنائيّ)
for (k, f) in [0.1, 0.25, 0.37, 0.5].enumerated() {
    let sh = ShapeLib.make(ShapeKind.allCases[k * 3], seed: UInt64(k + 1))
    let L = Cutter.solve(sh, angle: 0.4 + Double(k), fraction: f)
    check(near(Cutter.plusFraction(sh, L), f, 1e-6), "solve hits \(f) on \(sh.vertexCount)")
    check(near(Judge.smallerPercent(Cutter.split(sh, by: L)), min(f, 1 - f) * 100, 1e-4), "solved line splits to \(f)")
}

// ── الأشكال كلّها مطبَّعة وسليمة
for k in ShapeKind.allCases {
    for seed in [UInt64(1), 77, 12345] {
        let s = ShapeLib.make(k, seed: seed)
        check(near(s.radius, 1, 1e-9), "\(k) normalized radius")
        check(near(s.centroid.len, 0, 1e-6), "\(k) centered")
        check(s.area > 0.25 && s.area < Double.pi + 0.01, "\(k) sane area \(s.area)")
        check(Poly.signedArea(s.outer) > 0, "\(k) outer CCW")
        check(s.holes.allSatisfy { Poly.signedArea($0) < 0 }, "\(k) holes CW")
        check(s.holes.allSatisfy { h in h.allSatisfy { s.outer.count > 0 && Poly.contains(s.outer, $0) } }, "\(k) holes inside outer")
    }
    check(ShapeLib.make(k, seed: 5) == ShapeLib.make(k, seed: 5), "\(k) deterministic")
    check(!ShapeLib.name(k).isEmpty, "\(k) has Arabic name")
}
check(ShapeLib.make(.blob, seed: 1) != ShapeLib.make(.blob, seed: 2), "different seeds = different blobs")
check(ShapeLib.holed.allSatisfy { !ShapeLib.make($0, seed: 3).holes.isEmpty }, "holed shapes have holes")
// التحويل يحافظ على النسبة
let hx = ShapeLib.make(.hexagon, seed: 1)
let moved = hx.placed(scale: 1.7, angle: 0.9, offset: P(3, -2))
check(near(moved.area, hx.area * 1.7 * 1.7, 1e-9), "scaling multiplies area by k²")

// ── التقييم
check(Grade.of(0.4) == .perfect && Grade.of(1.0) == .perfect, "±1% = perfect")
check(Grade.of(2.5) == .great && Grade.of(5) == .good && Grade.of(9) == .ok && Grade.of(10.5) == .miss, "grade bands")
check(Grade.allCases.allSatisfy { !$0.title.isEmpty }, "grade titles")
check(Scoring.points(0, combo: 0) == 150, "perfect base 150: \(Scoring.points(0, combo: 0))")
check(Scoring.points(5, combo: 0) == 50, "5% off = 50")
check(Scoring.points(12, combo: 3) == 0, "far miss = 0")
check(Scoring.points(0, combo: 4) == 300, "combo x2 at 4: \(Scoring.points(0, combo: 4))")
check(Scoring.points(0, combo: 50) == Scoring.points(0, combo: 8), "combo multiplier capped")
check(Scoring.nextCombo(2, .perfect) == 3 && Scoring.nextCombo(2, .great) == 3 && Scoring.nextCombo(5, .good) == 0, "combo rules")
check(Scoring.comboLabel(3) == "جرّاح!" && Scoring.comboLabel(4) == nil && Scoring.comboLabel(8) != nil, "combo labels")
check(Scoring.stars([0.5, 1, 2]) == 3, "3 stars avg ≤1.5")
check(Scoring.stars([3, 4, 5]) == 2, "2 stars")
check(Scoring.stars([6, 8, 9]) == 1, "1 star")
check(Scoring.stars([20, 15, 9]) == 0 && Scoring.stars([]) == 0, "fail")
check(Scoring.coins(stars: 3, perfects: 2, improved: 1) == 23, "coins")
check(near(Judge.error(percent: 36.4, target: 37), 0.6), "error is distance in points")
check(Goal.percent(37).title == "اقطع 37%" && Goal.equal(3).cuts == 2 && Goal.percent(10).cuts == 1, "goal titles & cuts")

// ── الحركة
let mo = Motion(spin: 0.5, driftX: 0.2, driftY: 0.1, driftW: 1, pulse: 0.1, pulseW: 2)
check(mo.moving && !Motion.still.moving, "motion flags")
check(near(mo.scale(0), 1) && near(mo.angle(2), 1) && near(mo.offset(0).x, 0), "motion at t")
check(mo.scale(0.7) <= 1.1 + 1e-12 && mo.scale(0.7) >= 0.9 - 1e-12, "pulse bounded")
let rd = Round(kind: .star, seed: 4, vary: true, goal: .percent(30), motion: mo, nails: [], time: nil)
let p1 = rd.placed(1.3)
let fr0 = Cutter.plusFraction(rd.shape, Cutter.solve(rd.shape, angle: 1, fraction: 0.3))
check(near(fr0, 0.3, 1e-6) && p1.area > rd.shape.area * 0.8, "placed round shape")

// ── المسامير والفتحة
let ns = ShapeLib.make(.hexagon, seed: 3)
let nails = Levels.gapNails(ns, target: 30, angle: 0.7, gap: 0.1)
let sol = Cutter.solve(ns, angle: 0.7, fraction: 0.3)
check(nails.count == 4, "four nails")
check(Judge.hitsNail(sol, nails) == nil, "solution passes through the gap")
check(Judge.hitsNail(sol.shifted(0.16), nails) != nil, "a shifted line hits a nail")
check(Judge.hitsNail(sol.shifted(-0.16), nails) != nil, "shift other way hits too")
check(nails.allSatisfy { !ns.contains($0.p) }, "nails sit outside the shape")

// ── المراحل
var nailRounds = 0, equalRounds = 0, holedRounds = 0, timed = 0
for id in 0..<Levels.total {
    let lv = Levels.level(id)
    check(lv.id == id && lv.world == id / 10 && lv.index == id % 10, "level id \(id)")
    check(lv.rounds.count >= 3 && lv.rounds.count <= 5, "level \(id) rounds \(lv.rounds.count)")
    check(lv == Levels.level(id), "level \(id) deterministic")
    for r in lv.rounds {
        switch r.goal {
        case .percent(let p): check(p >= 10 && p <= 50, "level \(id) percent \(p)")
        case .equal(let n):
            equalRounds += 1
            check(n == 3 || n == 4, "equal n")
            let s = r.shape
            if n == 3 {
                let a = Cutter.solve(s, angle: 0.3, fraction: 2.0 / 3), b = Cutter.solve(s, angle: 0.3, fraction: 1.0 / 3)
                let res = Cutter.splitAll(Cutter.split(s, by: a).pieces, by: b)
                check(Judge.equalError(res.pieces, n: 3) < 0.01, "level \(id) equal(3) solvable: \(Judge.equalError(res.pieces, n: 3))")
            } else {
                let c = s.centroid
                let res = Cutter.splitAll(Cutter.split(s, by: Line(point: c, dir: P(1, 0.3))).pieces, by: Line(point: c, dir: P(-0.3, 1)))
                check(Judge.equalError(res.pieces, n: 4) < 0.3, "level \(id) equal(4) solvable: \(Judge.equalError(res.pieces, n: 4))")
            }
        }
        if !r.nails.isEmpty {
            nailRounds += 1
            check(!r.motion.moving, "nail rounds are still")
            if case .percent(let p) = r.goal {
                // نتحقّق إن أكو خطّ ينجح يمرّ بالفتحة
                var ok = false
                for k in 0..<180 {
                    let L = Cutter.solve(r.shape, angle: Double(k) / 180 * Double.pi, fraction: Double(p) / 100)
                    if Judge.hitsNail(L, r.nails) == nil { ok = true; break }
                }
                check(ok, "level \(id) nail round solvable")
            }
        }
        if !r.shape.holes.isEmpty { holedRounds += 1 }
        if r.time != nil { timed += 1; check((r.time ?? 0) >= 3, "time limit sane") }
        check(r.shape.area > 0.25, "round shape area")
    }
}
check(nailRounds >= 8, "campaign has gap levels: \(nailRounds)")
check(equalRounds >= 12, "campaign has equal-piece rounds: \(equalRounds)")
check(holedRounds >= 4, "campaign has holed shapes: \(holedRounds)")
check(timed >= 10, "campaign has timed rounds: \(timed)")
check(Levels.level(0).rounds[0].goal == .percent(50) && Levels.level(0).rounds[0].kind == .square, "first level is handmade square 50%")
check(Levels.level(0).rounds.allSatisfy { !$0.motion.moving }, "world 1 is still")
check(Levels.level(15).rounds.allSatisfy { $0.motion.moving }, "world 2 spins")
check(Levels.level(55).rounds.contains { $0.time != nil }, "expert world is timed")
check(Levels.level(12) != Levels.level(13), "levels differ")
check(Levels.worlds.count == Levels.worldCount, "world info")

// ── تحدّي اليوم
let d1 = Levels.daily(2026, 11, 16), d1b = Levels.daily(2026, 11, 16), d2 = Levels.daily(2026, 11, 17)
check(d1 == d1b, "same date = same daily")
check(d1 != d2, "next day differs")
check(d1.rounds.count == 5, "daily has 5 rounds")
// بلا نهاية + زِن
let e0 = Levels.endless(0, seed: 9), e30 = Levels.endless(30, seed: 9)
check(e0.time == nil && !e0.motion.moving, "endless starts gentle")
check(e30.time != nil && (e30.time ?? 99) <= 10, "endless gets timed")
check(Levels.endless(7, seed: 3) == Levels.endless(7, seed: 3), "endless deterministic")
var endlessHoles = false
for i in 12..<120 where !Levels.endless(i, seed: 1).shape.holes.isEmpty { endlessHoles = true }
check(endlessHoles, "endless eventually has holed shapes")
check(Levels.zen(3, seed: 1).time == nil, "zen untimed")

// ── الوتر (نقاط الشرر)
let ch = Cutter.chord(unitSquare, Line(P(0.5, -1), P(0.5, 2)))
check(!ch.isEmpty && ch.allSatisfy { near($0.x, 0.5) && unitSquare.contains($0) }, "chord points on cut inside shape")

// ── المولّد
var r1 = SRng(5), r2 = SRng(5)
check((0..<20).allSatisfy { _ in r1.next() == r2.next() }, "seeded rng repeatable")
var r3 = SRng(6)
var inRange = true
for _ in 0..<500 { let u = r3.unit(); let n = r3.int(3, 7); if u < 0 || u >= 1 || n < 3 || n > 7 { inRange = false } }
check(inRange, "rng ranges")

print("\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
