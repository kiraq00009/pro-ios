import Foundation

var failures = 0
var passes = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) {
    if ok { passes += 1 } else { failures += 1; print("FAIL: " + msg()) }
}

let Y = 360.0
func world(_ items: [(OrbKind, Double, Double)], baseR: Double = 46, sparkR: Double = 50) -> World {
    var orbs: [Orb] = []
    for (i, it) in items.enumerated() { orbs.append(Orb(id: i, kind: it.0, pos: P(it.1, it.2))) }
    return World(orbs: orbs, baseR: baseR, sparkR: sparkR)
}

// ── أدوات أساسيّة
check(P(3, 4).len == 5, "vector length")
check(P(1, 1).dist(P(4, 5)) == 5, "distance")
var r1 = SRNG(42), r2 = SRNG(42), r3 = SRNG(43)
let a1 = (0..<20).map { _ in r1.next() }, a2 = (0..<20).map { _ in r2.next() }, a3 = (0..<20).map { _ in r3.next() }
check(a1 == a2, "same seed same stream")
check(a1 != a3, "different seed different stream")
var ru = SRNG(7)
var unitOK = true
for _ in 0..<2000 { let u = ru.unit(); if u < 0 || u >= 1 { unitOK = false } }
check(unitOK, "unit in [0,1)")
var rs = SRNG(9)
var arr = Array(0..<30)
rs.shuffle(&arr)
check(arr.sorted() == Array(0..<30) && arr != Array(0..<30), "shuffle is a permutation")

// ── حلقة الانفجار
var bl = Blast(id: 0, pos: P(0, 0), maxR: 40, gen: 0, source: nil)
check(bl.r == 0 && bl.hot && !bl.done, "blast starts at zero and hot")
bl.age = Tune.growT
check(abs(bl.r - 40) < 1e-9, "blast reaches max radius at growT")
bl.age = Tune.growT + Tune.holdT + 0.01
check(!bl.hot && !bl.done && bl.alpha < 1, "blast cools while fading")
bl.age = Tune.growT + Tune.holdT + Tune.fadeT
check(bl.done && bl.alpha == 0, "blast done")

check(World.mult(1) == 1 && World.mult(5) == 1 && World.mult(6) == 2 && World.mult(11) == 3, "chain multiplier steps every 5 links")

// ── تخطيط معروف: خطّ متقارب ⇒ كلّه ينفجر
let line = world([(.normal, 100, Y), (.normal, 150, Y), (.normal, 200, Y), (.normal, 250, Y), (.normal, 300, Y)])
let lo = line.simulate(tapAt: P(100, Y))
check(lo.pops == 5 && lo.good == 5 && lo.bad == 0, "tight line chains fully: \(lo)")
check(lo.score == 50, "5 normals at x1 = 50 points: \(lo.score)")
check(lo.maxGen >= 2, "chain depth grows along the line: \(lo.maxGen)")
check(!line.fired && line.pops == 0, "simulate does not mutate the original")
// متباعد ⇒ بس الأولى
let sparse = world([(.normal, 100, Y), (.normal, 170, Y), (.normal, 240, Y)])
check(sparse.simulate(tapAt: P(100, Y)).pops == 1, "sparse line: only the tapped orb")
// ضربة بالفراغ
check(sparse.simulate(tapAt: P(200, 650)).pops == 0, "tap in empty space pops nothing")
// ضربة بالنصّ تلحق الاثنين
let mid = world([(.normal, 150, Y), (.normal, 250, Y)])
check(mid.simulate(tapAt: P(200, Y)).pops == 2, "spark between two orbs reaches both")

// ── مرّة وحدة بس
var once = line
check(once.fire(at: P(100, Y)), "first fire works")
check(!once.fire(at: P(300, Y)), "second fire refused")
once.settle()
check(once.finished && once.blasts.isEmpty && once.sparks.isEmpty, "settles to finished")
// الأحداث
var ev = line
ev.fire(at: P(100, Y))
var popEvents = 0, fireEvents = 0
while !ev.finished {
    ev.step()
    for e in ev.drainEvents() {
        switch e {
        case .pop: popEvents += 1
        case .fire: fireEvents += 1
        case .shield, .arm, .split, .tier: break
        }
    }
}
check(popEvents == 5, "one pop event per orb: \(popEvents)")
check(fireEvents == 1, "one fire event: \(fireEvents)")
check(ev.drainEvents().isEmpty, "events drained")

// ── المدرّعة: ضربتين من انفجارين مختلفين
let lone = world([(.shield, 200, Y)])
var ls = lone
ls.fire(at: P(200, Y))
ls.settle()
check(ls.pops == 0 && ls.orbs[0].hp == 1 && ls.orbs[0].state == .alive, "single blast only cracks the shield")
let pair = world([(.normal, 150, Y), (.shield, 200, Y)])
let po = pair.simulate(tapAt: P(150, Y))
check(po.pops == 2, "two blasts break the shield: \(po)")
check(po.score == 10 + 25, "shield scores 25: \(po.score)")

// ── العملاقة: انفجار أكبر
let bigW = world([(.big, 200, Y), (.normal, 200, Y + 90)])
let smallW = world([(.normal, 200, Y), (.normal, 200, Y + 90)])
check(bigW.simulate(tapAt: P(200, Y)).pops == 2, "big orb blast reaches 90")
check(smallW.simulate(tapAt: P(200, Y)).pops == 1, "normal orb blast does not reach 90")

// ── المشطورة: شرارة طايرة تلحق كرة بعيدة
var spl = world([(.splitter, 120, Y), (.normal, 320, Y)])
spl.orbs[0].phase = 0
check(spl.simulate(tapAt: P(120, Y)).pops == 2, "splitter spark flies 200 and pops the far orb")
let ctrl = world([(.normal, 120, Y), (.normal, 320, Y)])
check(ctrl.simulate(tapAt: P(120, Y)).pops == 1, "without splitter the far orb survives")
var spl2 = spl
spl2.fire(at: P(120, Y))
var sawSparks = false
for _ in 0..<20 { spl2.step(); if !spl2.sparks.isEmpty { sawSparks = true } }
check(sawSparks, "splitter spawns sparks")

// ── المؤقّتة: تنفجر متأخّرة
var tim = world([(.timer, 200, Y)])
tim.fire(at: P(200, Y))
for _ in 0..<60 { tim.step() }
check(tim.pops == 0 && tim.armedCount == 1 && !tim.finished, "timer still ticking after 1s")
tim.settle()
check(tim.pops == 1 && tim.finished, "timer explodes later")
check(tim.t > Tune.timerT, "timer exploded after its fuse: \(tim.t)")

// ── المغناطيس يسحب
let mag = world([(.magnet, 200, Y), (.normal, 200, Y + 120)])
let magCtrl = world([(.normal, 200, Y), (.normal, 200, Y + 120)])
check(mag.simulate(tapAt: P(200, Y)).pops == 2, "magnet pulls the orb into range")
check(magCtrl.simulate(tapAt: P(200, Y)).pops == 1, "without magnet it stays out of range")
var magStep = mag
magStep.fire(at: P(200, Y))
for _ in 0..<12 { magStep.step() }
check(magStep.orbs[1].pos.dist(magStep.orbs[0].pos) < 120, "orb moved toward magnet")

// ── المظلمة تنقص
let badW = world([(.normal, 100, Y), (.normal, 150, Y), (.bad, 200, Y)])
let bo = badW.simulate(tapAt: P(100, Y))
check(bo.pops == 3 && bo.bad == 1 && bo.good == 2 && bo.net == 1, "bad orb lowers net: \(bo)")
check(bo.score == 0, "score floors at zero: \(bo.score)")
check(badW.goodTotal == 2 && badW.badTotal == 1, "good/bad totals")

// ── درجات السلسلة (كلّ ٨)
var grid: [(OrbKind, Double, Double)] = []
for gy in 0..<4 { for gx in 0..<4 { grid.append((.normal, 110 + Double(gx) * 45, 280 + Double(gy) * 45)) } }
var gw = world(grid)
gw.fire(at: P(110, 280))
var tiers: [Int] = []
while !gw.finished {
    gw.step()
    for e in gw.drainEvents() { if case .tier(let n) = e { tiers.append(n) } }
}
check(gw.pops == 16, "4x4 grid fully chains: \(gw.pops)")
check(tiers == [1, 2], "tier events at 8 and 16: \(tiers)")
check(gw.score == 10 * 5 + 20 * 5 + 30 * 5 + 40, "multiplied score: \(gw.score)")
check(ChainWords.tier(0) == "" && ChainWords.tier(2) == "نار!" && ChainWords.tier(9) == "شرارة مطلقة!", "chain words")

// ── الحيطان
var wb = World(orbs: [Orb(id: 0, kind: .normal, pos: P(380, Y), vel: P(100, 0))], baseR: 46, sparkR: 50)
for _ in 0..<30 { wb.step() }
check(wb.orbs[0].vel.x < 0 && wb.orbs[0].pos.x <= Tune.W - wb.orbs[0].r, "bounces off right wall")
var wt = World(orbs: [Orb(id: 0, kind: .normal, pos: P(200, 20), vel: P(0, -80))], baseR: 46, sparkR: 50)
for _ in 0..<30 { wt.step() }
check(wt.orbs[0].vel.y > 0 && wt.orbs[0].pos.y >= wt.orbs[0].r, "bounces off top wall")

// ── الحتميّة: نفس البذرة + نفس الضربة = نفس النتيجة
let s12 = Gen.campaign(12)
let wA = Gen.world(s12), wB = Gen.world(s12)
check(wA.orbs.count == wB.orbs.count && zip(wA.orbs, wB.orbs).allSatisfy { pr in pr.0.pos == pr.1.pos && pr.0.kind == pr.1.kind && pr.0.vel == pr.1.vel }, "same seed same layout")
let tapP = P(180, 300)
let oA = wA.simulate(tapAt: tapP, after: 45), oB = wB.simulate(tapAt: tapP, after: 45)
check(oA == oB, "same seed + same tap => same outcome")
check(Gen.world(Gen.campaign(13)).orbs.map { $0.pos } != wA.orbs.map { $0.pos }, "different level different layout")
// الكرات ما تتراكب
var minGap = 1e9
for i in 0..<wA.orbs.count { for j in (i + 1)..<wA.orbs.count { minGap = min(minGap, wA.orbs[i].pos.dist(wA.orbs[j].pos) - wA.orbs[i].r - wA.orbs[j].r) } }
check(minGap > 0, "generated orbs do not overlap: \(minGap)")
check(wA.orbs.allSatisfy { $0.pos.x >= $0.r && $0.pos.x <= Tune.W - $0.r && $0.pos.y >= $0.r && $0.pos.y <= Tune.H - $0.r }, "orbs inside arena")

// ── الحملة: ٨٠ مرحلة كلّها قابلة للحلّ
check(Gen.campaignCount == 80 && Gen.galaxyNames.count == 8 && Gen.galaxyIntro.count == 8, "8 galaxies x 10")
var allOK = true, replayOK = true, starsOK = true
var prevFracG = -1.0
for i in 0..<Gen.campaignCount {
    let sp = Gen.campaign(i)
    let lv = Gen.make(sp)
    if !(lv.target >= 1 && lv.target <= lv.best && lv.target <= lv.goodTotal) { allOK = false; print("level \(i): target \(lv.target) best \(lv.best) good \(lv.goodTotal)") }
    if lv.world.simulate(tapAt: lv.bestTap).net != lv.best { replayOK = false; print("level \(i) replay mismatch") }
    if !(lv.target <= lv.t2 && lv.t2 <= lv.t3 && lv.stars(lv.t3) == 3 && lv.stars(lv.target) >= 1 && lv.stars(lv.target - 1) == 0) { starsOK = false }
    if i % 10 == 0 { check(sp.designFrac > prevFracG, "difficulty rises by galaxy \(i)"); prevFracG = sp.designFrac }
    check(lv.world.orbs.count == sp.total && sp.total >= 18, "level \(i) orb count \(sp.total)")
}
check(allOK, "every campaign level is solvable with one tap")
check(replayOK, "best tap replays deterministically")
check(starsOK, "star thresholds are ordered")
check(Gen.campaign(3).counts[OrbKind.normal.rawValue] == Gen.campaign(3).total, "first levels only normal orbs")
check(Gen.campaign(25).count(.shield) >= 2, "galaxy 3 features shields")
check(Gen.campaign(35).count(.splitter) >= 2, "galaxy 4 features splitters")
check(Gen.campaign(55).count(.magnet) >= 2, "galaxy 6 features magnets")
check(Gen.campaign(65).count(.bad) >= 2 && Gen.campaign(59).count(.bad) == 0, "bad orbs from galaxy 7")
check(Gen.campaign(79).speed > Gen.campaign(0).speed && Gen.campaign(79).baseR < Gen.campaign(0).baseR, "late levels faster with smaller blasts")
check(Gen.campaign(-5).index == 0 && Gen.campaign(500).index == 79, "index clamped")

// ── بلا نهاية
check(Gen.endlessQuota(0) < Gen.endlessQuota(5) && Gen.endlessQuota(100) == 0.85, "endless quota rises and caps")
check(Gen.endless(round: 10, runSeed: 5).total > Gen.endless(round: 0, runSeed: 5).total, "endless rounds grow")
var endlessOK = true
for r in [0, 3, 7, 12] {
    let lv = Gen.make(Gen.endless(round: r, runSeed: 2024))
    if !(lv.target >= 1 && lv.target <= lv.best) { endlessOK = false }
}
check(endlessOK, "endless rounds solvable")
check(Gen.endless(round: 6, runSeed: 1).count(.bad) > 0, "endless adds bad orbs later")

// ── تحدّي اليوم
let d1 = Gen.world(Gen.daily(day: 20000)), d2 = Gen.world(Gen.daily(day: 20000)), d3 = Gen.world(Gen.daily(day: 20001))
check(d1.orbs.map { $0.pos } == d2.orbs.map { $0.pos }, "daily is the same for everyone that day")
check(d1.orbs.map { $0.pos } != d3.orbs.map { $0.pos }, "daily changes tomorrow")
check(Gen.daily(day: 20000).total == 40, "daily has 40 orbs")
let dl = Gen.make(Gen.daily(day: 20000))
check(dl.target >= 1 && dl.target <= dl.best, "daily solvable")

// ── الضربة الكاملة
var perfOK = true
for i in [0, 5, 11, 23] {
    let lv = Gen.make(Gen.perfect(i))
    if !(lv.target == lv.best && lv.best <= lv.goodTotal && lv.stars(lv.target) == 3) { perfOK = false; print("perfect \(i): \(lv.target) \(lv.best) \(lv.goodTotal)") }
}
check(perfOK, "perfect shot target = best achievable")

// ── التقدّم والمتجر
var pg = Career()
check(pg.unlocked(0) && !pg.unlocked(1) && pg.current == 0, "only first level open")
let oc = Outcome(pops: 21, good: 20, bad: 1, score: 400, maxGen: 6)
let c1 = pg.finishCampaign(0, stars: 2, outcome: oc)
check(c1 == 2 * 15 + 7 + 20, "coins for first clear: \(c1)")
check(pg.unlocked(1) && pg.current == 1 && pg.stars[0] == 2, "next level unlocked")
let c2 = pg.finishCampaign(0, stars: 1, outcome: oc)
check(c2 == 7 && pg.stars[0] == 2, "replay keeps best stars, small coins: \(c2)")
let c3 = pg.finishCampaign(0, stars: 3, outcome: oc)
check(c3 == 15 + 7 && pg.stars[0] == 3, "improving stars pays the difference: \(c3)")
check(pg.finishCampaign(1, stars: 0, outcome: oc) == 0 && !pg.unlocked(2), "fail pays nothing")
check(pg.shots == 4 && pg.wins == 3 && pg.totalPops == 84 && pg.longest == 21 && pg.deepest == 6 && pg.badPops == 4, "stats tracked")
check(pg.coins == c1 + c2 + c3 && pg.coinsEarned == pg.coins, "coin totals")
check(pg.totalStars == 3 && pg.galaxyStars(0) == 3 && pg.galaxyStars(1) == 0, "star totals")
check(!pg.buy("gold"), "cannot buy without coins")
check(!pg.buy("ember"), "cannot buy owned")
pg.coins = 1000
check(pg.buy("ice") && pg.coins == 750 && pg.owns("ice"), "buy spark skin")
check(pg.select("ice") && pg.spark == "ice", "select owned skin")
check(!pg.select("gold") && pg.spark == "ice", "cannot select unowned")
check(pg.buy("deep") && pg.select("deep") && pg.back == "deep", "buy + select background")
check(!pg.buy("nope"), "unknown item")
check(pg.finishDaily(day: 100, outcome: oc, passed: true) == 120 && pg.dailyDone == [100], "daily first clear bonus")
check(pg.finishDaily(day: 100, outcome: oc, passed: true) == 5 && pg.dailyDone == [100], "daily repeat")
check(pg.finishPerfect(2, outcome: oc, passed: true) == 70 && pg.perfect[2], "perfect first clear")
check(pg.finishPerfect(2, outcome: oc, passed: true) == 0, "perfect repeat pays nothing")
check(pg.perfectUnlocked(0) && pg.perfectUnlocked(2) && pg.perfectUnlocked(3) && !pg.perfectUnlocked(5), "perfect unlock chain")
check(pg.finishEndless(rounds: 6, score: 3000, outcome: oc, passed: true) == 12 && pg.endlessRounds == 6 && pg.endlessScore == 3000, "endless record")
pg.finishEndless(rounds: 2, score: 100, outcome: oc, passed: false)
check(pg.endlessRounds == 6 && pg.endlessScore == 3000, "endless keeps best")
if let data = try? JSONEncoder().encode(pg), let back = try? JSONDecoder().decode(Career.self, from: data) {
    check(back == pg, "progress JSON round trip")
} else { check(false, "progress encodes") }
check(Catalog.sparks.count >= 6 && Catalog.backs.count >= 5 && Catalog.sparks[0].price == 0 && Catalog.backs[0].price == 0, "catalog with free defaults")
check(Set(Catalog.sparks.map { $0.id }).count == Catalog.sparks.count, "unique skin ids")
check(Catalog.spark("zzz").id == "ember" && Catalog.back("zzz").id == "nebula", "fallback skins")

// ── الأيّام
check(Days.index(86400 * 3 + 10, tzOffset: 0) == 3, "day index")
check(Days.index(86400 * 3 - 10, tzOffset: 3600) == 3, "day index with timezone")
check(Days.streak([10, 11, 12], today: 12) == 3, "streak today")
check(Days.streak([10, 11, 12], today: 13) == 3, "streak alive until tomorrow ends")
check(Days.streak([10, 11, 12], today: 14) == 0, "streak broken")
check(Days.streak([], today: 5) == 0, "empty streak")

print("sharara: \(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
