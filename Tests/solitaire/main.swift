import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

// ───────── توزيع جديد سليم
let g0 = GameState.deal(seed: 42)
check(g0.allCards.count == 52, "52 cards total: \(g0.allCards.count)")
check(Set(g0.allCards.map { $0.id }).count == 52, "52 unique cards")
check(g0.stock.count == 24, "24 in stock: \(g0.stock.count)")
check(g0.waste.isEmpty, "waste empty on deal")
check(g0.foundations.allSatisfy { $0.isEmpty }, "foundations empty on deal")
check(g0.tableau.reduce(0) { $0 + $1.count } == 28, "28 in tableau")
for col in 0..<7 {
    check(g0.tableau[col].count == col + 1, "col \(col) has \(col + 1) cards")
    check(g0.tableau[col].last!.faceUp, "col \(col) top is face up")
    check(g0.tableau[col].dropLast().allSatisfy { !$0.faceUp }, "col \(col) only top face up")
}
check(g0.stock.allSatisfy { !$0.faceUp }, "stock all face down")

// ───────── خلط حتميّ لكلّ بذرة
let a = GameState.deal(seed: 7), b = GameState.deal(seed: 7), c = GameState.deal(seed: 8)
check(a.allCards == b.allCards, "same seed ⇒ identical deal")
check(a.allCards != c.allCards, "different seed ⇒ different deal")

// ───────── canMoveToFoundation: الآس أوّلًا ثمّ تصاعديًّا بنفس النوع
var gs = GameState()
let aceS = Card(suit: .spades, rank: 1, faceUp: true)
let twoS = Card(suit: .spades, rank: 2, faceUp: true)
let twoH = Card(suit: .hearts, rank: 2, faceUp: true)
check(gs.canMoveToFoundation(aceS, 0), "ace goes to empty foundation")
check(!gs.canMoveToFoundation(twoS, 0), "2 cannot start a foundation")
gs.foundations[0] = [aceS]
check(gs.canMoveToFoundation(twoS, 0), "2♠ onto A♠")
check(!gs.canMoveToFoundation(twoH, 0), "2♥ not onto spade foundation (wrong index)")
check(!gs.canMoveToFoundation(twoH, 1), "2♥ not onto empty heart foundation (needs ace)")
check(!gs.canMoveToFoundation(Card(suit: .spades, rank: 3, faceUp: true), 0), "3♠ cannot skip onto A♠")

// ───────── canStackOnTableau: مرتبة-1 بلون معاكس، ملك للفاضي
check(GameState.canStackOnTableau(Card(suit: .spades, rank: 13), onto: []), "King to empty")
check(!GameState.canStackOnTableau(Card(suit: .spades, rank: 12), onto: []), "Queen not to empty")
let redK = Card(suit: .hearts, rank: 13, faceUp: true)
check(GameState.canStackOnTableau(Card(suit: .spades, rank: 12, faceUp: true), onto: [redK]), "black Q onto red K")
check(!GameState.canStackOnTableau(Card(suit: .diamonds, rank: 12, faceUp: true), onto: [redK]), "red Q not onto red K")
check(!GameState.canStackOnTableau(Card(suit: .spades, rank: 11, faceUp: true), onto: [redK]), "J not onto K (gap)")
check(!GameState.canStackOnTableau(Card(suit: .spades, rank: 12, faceUp: true), onto: [Card(suit: .hearts, rank: 13, faceUp: false)]), "cannot stack onto face-down")

// ───────── السحب يدوّر المخزن ← المرمى ثمّ يعيد التدوير
var d1 = GameState.deal(seed: 3, draw3: false)
let stock0 = d1.stock.count
check(d1.apply(.draw), "draw works")
check(d1.waste.count == 1 && d1.stock.count == stock0 - 1 && d1.waste.last!.faceUp, "draw-1 moves one face up")
while !d1.stock.isEmpty { d1.apply(.draw) }
check(d1.stock.isEmpty && d1.waste.count == stock0, "drew whole stock to waste")
check(!d1.apply(.draw), "cannot draw from empty stock")
check(d1.apply(.recycle), "recycle works")
check(d1.waste.isEmpty && d1.stock.count == stock0 && d1.stock.allSatisfy { !$0.faceUp }, "recycle rebuilds face-down stock")
check(!d1.apply(.recycle), "cannot recycle while stock non-empty")

// draw-3 يسحب ثلاثًا
var d3 = GameState.deal(seed: 3, draw3: true)
check(d3.apply(.draw) && d3.waste.count == 3, "draw-3 moves three")

// ───────── ثبات الـ52 عبر سلسلة حركات شرعيّة عشوائيّة
var rngState = GameState.deal(seed: 99)
var rng = Seeded(12345)
for _ in 0..<4000 {
    let moves = rngState.legalMoves()
    if moves.isEmpty { break }      // حالة عالقة فعلًا (كلّ المخزن والمرمى صارت باللعب)
    let m = moves[Int(rng.next() % UInt64(moves.count))]
    let ok = rngState.apply(m)
    check(ok, "enumerated move must be applicable: \(m)")
    check(rngState.allCards.count == 52 && Set(rngState.allCards.map { $0.id }).count == 52, "still 52 unique after \(m)")
    if rngState.isWon { break }
}

// ───────── كلّ الحركات المعدودة شرعيّة على حالات يدويّة
func allLegal(_ s: GameState) {
    for m in s.legalMoves() { check(s.applying(m) != nil, "legalMoves emitted illegal move \(m)") }
}
allLegal(GameState.deal(seed: 1))
allLegal(GameState.deal(seed: 2))
var mid = GameState.deal(seed: 5)
for _ in 0..<50 { if let m = mid.hint() ?? mid.legalMoves().first { mid.apply(m) } }
allLegal(mid)
if let h = mid.hint() { check(mid.applying(h) != nil, "hint is a legal move") }

// ───────── isWon صحيح فقط لمّا الأساسات تحمل 52
var win = GameState()
check(!win.isWon, "empty not won")
for s in Suit.allCases { for r in 1...13 { win.foundations[s.rawValue].append(Card(suit: s, rank: r, faceUp: true)) } }
check(win.isWon, "full foundations ⇒ won")
check(win.allCards.count == 52, "won state still 52")
win.foundations[0].removeLast()
check(!win.isWon, "51 ⇒ not won")

// ───────── نقل تلقائيّ للأساسات + إكمال
var autoG = GameState()
autoG.waste = [Card(suit: .spades, rank: 1, faceUp: true)]
autoG.tableau[0] = [Card(suit: .hearts, rank: 1, faceUp: true)]
autoG.tableau[1] = [Card(suit: .spades, rank: 2, faceUp: true)]
let auto = autoG.autoMoveToFoundations()
check(auto.foundations[Suit.spades.rawValue].count == 2, "auto moved A♠ then 2♠")
check(auto.foundations[Suit.hearts.rawValue].count == 1, "auto moved A♥")
check(auto.waste.isEmpty && auto.tableau[0].isEmpty && auto.tableau[1].isEmpty, "sources emptied")

// إكمال كامل من حالة شبه-فائزة: كلّ الأوراق مكشوفة بالأعمدة بترتيب نازل
var near = GameState()
for s in Suit.allCases { near.foundations[s.rawValue] = (1...12).map { Card(suit: s, rank: $0, faceUp: true) } }
// الملوك الأربعة موزّعة على الأعمدة
for (i, s) in Suit.allCases.enumerated() { near.tableau[i] = [Card(suit: s, rank: 13, faceUp: true)] }
let done = near.autoCompleted()
check(done.isWon, "autoCompleted finishes a solvable endgame")
check(done.allCards.count == 52, "autoCompleted keeps 52")

// ───────── نقل سلسلة بين الأعمدة
var runG = GameState()
runG.tableau[0] = [Card(suit: .clubs, rank: 7, faceUp: true), Card(suit: .diamonds, rank: 6, faceUp: true), Card(suit: .spades, rank: 5, faceUp: true)]
runG.tableau[1] = [Card(suit: .hearts, rank: 8, faceUp: true)]
check(runG.runLength(col: 0) == 3, "full alternating run length 3")
check(runG.apply(.tableauToTableau(0, 1, 3)), "move run of 3 onto 8♥")
check(runG.tableau[1].count == 4 && runG.tableau[0].isEmpty, "run moved")
// لا تسمح بنقل سلسلة غير متتابعة
var badRun = GameState()
badRun.tableau[0] = [Card(suit: .clubs, rank: 7, faceUp: true), Card(suit: .clubs, rank: 5, faceUp: true)]
check(badRun.runLength(col: 0) == 1, "broken sequence ⇒ run length 1")
check(!badRun.apply(.tableauToTableau(0, 1, 2)), "cannot move broken run")

// كشف الورقة المخفيّة بعد النقل
var flip = GameState()
flip.tableau[0] = [Card(suit: .hearts, rank: 9, faceUp: false), Card(suit: .spades, rank: 1, faceUp: true)]
check(flip.apply(.wasteToFoundation) == false, "no waste to move")
check(flip.apply(.tableauToFoundation(0)), "A♠ to foundation")
check(flip.tableau[0].last!.faceUp, "exposed card flipped up")

print(failures == 0 ? "ALL SOLITAIRE TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
