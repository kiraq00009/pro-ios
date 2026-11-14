import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

let N = Blocks.N

// ── الأشكال صحيحة: منسّقة، غير فارغة، ضمن اللوح
check(Blocks.shapes.count >= 20, "too few shapes: \(Blocks.shapes.count)")
for (i, s) in Blocks.shapes.enumerated() {
    check(!s.isEmpty, "shape \(i) empty")
    check(Set(s).count == s.count, "shape \(i) duplicate cells")
    let mr = s.map { $0.r }.min() ?? -1
    let mc = s.map { $0.c }.min() ?? -1
    check(mr == 0 && mc == 0, "shape \(i) not normalized (\(mr),\(mc))")
    let maxR = s.map { $0.r }.max() ?? 0
    let maxC = s.map { $0.c }.max() ?? 0
    check(maxR < N && maxC < N, "shape \(i) bigger than board")
    check(s.allSatisfy { $0.r >= 0 && $0.c >= 0 }, "shape \(i) negative cell")
}

// ── canPlace: يرفض التجاوز والتداخل، يقبل الانطباق الصحيح
let empty = Blocks.empty()
let pL = Blocks.piece(kind: 22, id: 0, color: 3)   // شكل L تقريبًا
check(Blocks.canPlace(empty, pL, atRow: 0, atCol: 0), "valid fit on empty rejected")
check(!Blocks.canPlace(empty, pL, atRow: -1, atCol: 0), "negative row accepted")
check(!Blocks.canPlace(empty, pL, atRow: N, atCol: 0), "out of bounds row accepted")
check(!Blocks.canPlace(empty, pL, atRow: N - pL.h + 1, atCol: 0), "bottom overflow accepted")
check(!Blocks.canPlace(empty, pL, atRow: 0, atCol: N - pL.w + 1), "right overflow accepted")

let domino = Blocks.piece(kind: 1, id: 1, color: 2)   // "XX" أفقيّ
var b2 = Blocks.place(empty, domino, atRow: 0, atCol: 0)
check(b2[0][0] == 2 && b2[0][1] == 2, "place did not set exactly piece cells")
check(Blocks.filled(b2) == 2, "place set wrong number of cells")
check(!Blocks.canPlace(b2, domino, atRow: 0, atCol: 0), "overlap accepted")
check(!Blocks.canPlace(b2, domino, atRow: 0, atCol: 1), "partial overlap accepted")
check(Blocks.canPlace(b2, domino, atRow: 0, atCol: 2), "free spot rejected")

// ── place يضبط خلايا القطعة بالضبط لشكل مركّب
let plus = Blocks.piece(kind: 30, id: 2, color: 4)   // + (5 خلايا)
let bp = Blocks.place(Blocks.empty(), plus, atRow: 2, atCol: 2)
var expected = Set<Int>()
for cell in plus.cells { expected.insert((2 + cell.r) * N + (2 + cell.c)) }
var got = Set<Int>()
for r in 0..<N { for c in 0..<N where bp[r][c] != 0 { got.insert(r * N + c) } }
check(got == expected, "place cells mismatch for plus")
check(bp.flatMap { $0 }.allSatisfy { $0 == 0 || $0 == 4 }, "place used wrong color")

// ── clearLines: مسح صفّ كامل
var bRow = Blocks.empty()
for c in 0..<N { bRow[3][c] = 1 }
bRow[5][2] = 2   // خليّة فردية لا تتأثّر
var res = Blocks.clearLines(bRow)
check(res.cleared == 1, "one full row not counted as 1 (got \(res.cleared))")
check(res.board[3].allSatisfy { $0 == 0 }, "full row not cleared")
check(res.board[5][2] == 2, "unrelated cell cleared")
check(res.cells.count == N, "cleared cells count wrong for one row")

// ── خليّة واحدة ناقصة تُكمل صفًّا ⇒ يُمسح
var almost = Blocks.empty()
for c in 0..<N where c != 4 { almost[1][c] = 3 }
check(Blocks.clearLines(almost).cleared == 0, "incomplete row cleared early")
let single = Blocks.piece(kind: 0, id: 9, color: 5)   // مفردة
let placed = Blocks.place(almost, single, atRow: 1, atCol: 4)
let afterClear = Blocks.clearLines(placed)
check(afterClear.cleared == 1, "completing a row did not clear it")
check(afterClear.board[1].allSatisfy { $0 == 0 }, "completed row still filled")

// ── مسح صفّ وعمود معًا (تقاطع يُحسب مرّة)
var cross = Blocks.empty()
for c in 0..<N { cross[0][c] = 1 }   // صفّ كامل
for r in 0..<N { cross[r][0] = 1 }   // عمود كامل
let cr = Blocks.clearLines(cross)
check(cr.cleared == 2, "row+col should count as 2 (got \(cr.cleared))")
check(cr.cells.count == N + N - 1, "intersection cell double-counted (got \(cr.cells.count))")
check(Blocks.filled(cr.board) == 0, "row+col board not fully cleared")

// ── مسح متعدّد في آن واحد (صفّان)
var two = Blocks.empty()
for c in 0..<N { two[2][c] = 1; two[6][c] = 2 }
check(Blocks.clearLines(two).cleared == 2, "two simultaneous rows miscounted")

// ── anyMoveAvailable
check(Blocks.anyMoveAvailable(Blocks.empty(), Blocks.dealPieces(seed: 1)), "empty board should allow moves")
var jammed = Blocks.empty()
for r in 0..<N { for c in 0..<N { jammed[r][c] = 1 } }
jammed[0][0] = 0   // خليّة فاضية وحدة
let big = Blocks.piece(kind: 33, id: 0, color: 1)    // 3×3
let one = Blocks.piece(kind: 0, id: 1, color: 1)     // مفردة
check(!Blocks.anyMoveAvailable(jammed, [big]), "3x3 fit on nearly full board")
check(Blocks.anyMoveAvailable(jammed, [one]), "single cannot fit the lone empty cell")
check(Blocks.anyMoveAvailable(jammed, [big, one]), "mixed tray should find the single")

// ── dealPieces حتميّ وصالح
let d1 = Blocks.dealPieces(seed: 12345)
let d2 = Blocks.dealPieces(seed: 12345)
let d3 = Blocks.dealPieces(seed: 777)
check(d1 == d2, "dealPieces not deterministic")
check(d1 != d3, "different seeds gave same pieces")
check(d1.count == 3, "dealPieces must return 3")
for p in d1 {
    check(p.kind >= 0 && p.kind < Blocks.shapes.count, "dealt kind out of range")
    check(p.color >= 1 && p.color <= Blocks.colorCount, "dealt color out of range")
    check(p.cells == Blocks.shapes[p.kind], "dealt cells mismatch shape")
    check(!p.cells.isEmpty, "dealt empty piece")
}
check(Set(d1.map { $0.id }).count == 3, "dealt ids not unique")

// ── النقاط
check(Blocks.placeScore(plus) == 5, "placeScore wrong (expected 5)")
check(Blocks.placeScore(single) == 1, "placeScore single wrong")
check(Blocks.clearScore(lines: 0, combo: 1) == 0, "no clear = 0")
check(Blocks.clearScore(lines: 1, combo: 1) == 10, "single line = 10")
check(Blocks.clearScore(lines: 2, combo: 1) == 30, "double line bonus wrong")
check(Blocks.clearScore(lines: 3, combo: 1) == 50, "triple line bonus wrong")
check(Blocks.clearScore(lines: 1, combo: 3) == 20, "combo streak wrong")
check(Blocks.clearScore(lines: 2, combo: 2) > Blocks.clearScore(lines: 2, combo: 1), "combo must add")

// ── Codable
let enc = try JSONEncoder().encode(d1)
let dec = try JSONDecoder().decode([Piece].self, from: enc)
check(dec == d1, "Piece not codable round-trip")

// ── محاكاة ذاتيّة جشعة: تضع القطع وتمسح، مع ثبات اللافتات حتى تنتهي اللعبة
let t0 = Date()
var board = Blocks.empty()
var turn = 0
var totalPlaced = 0
var totalCleared = 0
var score = 0
var combo = 0
var terminated = false
var nextId = 0

while turn < 5000 {
    var pieces = Blocks.dealPieces(seed: UInt64(turn) &* 2654435761 &+ 1, startId: nextId)
    nextId += 3
    if !Blocks.anyMoveAvailable(board, pieces) { terminated = true; break }
    // ضع كلّ قطعة تنطبق (بترتيب عشوائيّ بسيط حتميّ)
    for idx in pieces.indices {
        let p = pieces[idx]
        var done = false
        var placedThisPiece = false
        for r in 0...(N - p.h) {
            if done { break }
            for c in 0...(N - p.w) where Blocks.canPlace(board, p, atRow: r, atCol: c) {
                let before = Blocks.filled(board)
                board = Blocks.place(board, p, atRow: r, atCol: c)
                check(Blocks.filled(board) == before + p.size, "turn \(turn): filled mismatch after place")
                totalPlaced += p.size
                score += Blocks.placeScore(p)
                let cl = Blocks.clearLines(board)
                if cl.cleared > 0 {
                    combo += 1
                    board = cl.board
                    totalCleared += cl.cells.count
                    score += Blocks.clearScore(lines: cl.cleared, combo: combo)
                } else {
                    combo = 0
                }
                // ثوابت اللوح: كلّ قيمة 0 أو لون صالح، والعدّ متّسق
                for row in board { for v in row { check(v >= 0 && v <= Blocks.colorCount, "turn \(turn): illegal cell \(v)") } }
                check(Blocks.filled(board) == totalPlaced - totalCleared, "turn \(turn): cell accounting broke")
                placedThisPiece = true
                done = true
                break
            }
        }
        _ = placedThisPiece
    }
    turn += 1
}
let dt = Date().timeIntervalSince(t0)
check(turn > 10, "self-play ran too few turns: \(turn)")
check(terminated || turn >= 5000, "self-play neither terminated nor hit cap")
check(Blocks.filled(board) == totalPlaced - totalCleared, "final cell accounting broke")
check(score > 0, "self-play scored nothing")
print("self-play: turns=\(turn), placed=\(totalPlaced), clearedCells=\(totalCleared), score=\(score), terminated=\(terminated), time=\(String(format: "%.2f", dt))s")

print(failures == 0 ? "ALL KATLA TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
