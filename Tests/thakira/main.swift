import Foundation

// Standalone test runner for the Thakira (ذاكرة) game model.
// Uses ONLY Thakira/Model + Foundation.

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if !cond {
        failures += 1
        print("FAIL: \(msg)")
    }
}

// MARK: - deal: exactly two of each symbol, correct count, deterministic

do {
    let pairs = 8
    let d = deal(pairs: pairs, seed: 42)
    check(d.count == pairs * 2, "deck count should be pairs*2 (got \(d.count))")
    var counts = [Int: Int]()
    for id in d { counts[id, default: 0] += 1 }
    check(counts.count == pairs, "deck should contain exactly \(pairs) distinct symbols")
    var allTwo = true
    for id in 0..<pairs {
        if counts[id] != 2 { allTwo = false }
    }
    check(allTwo, "every symbol must appear exactly twice")

    let d2 = deal(pairs: pairs, seed: 42)
    check(d == d2, "same seed must produce the same deck")
    let d3 = deal(pairs: pairs, seed: 43)
    check(d != d3, "different seed should (practically) produce a different deck")

    // Edge cases
    check(deal(pairs: 0, seed: 1).isEmpty, "0 pairs => empty deck")
    check(deal(pairs: 1, seed: 1).count == 2, "1 pair => 2 cards")
    check(deal(pairs: -5, seed: 1).isEmpty, "negative pairs => empty deck")
}

// MARK: - MatchState: matching pair marks matched + increments pairs

do {
    // Deterministic deck; find the two indices of symbol id 0.
    let deck = deal(pairs: 6, seed: 7)
    var idx = [Int: [Int]]()
    for (i, id) in deck.enumerated() { idx[id, default: []].append(i) }
    let pair0 = idx[0]!
    var st = MatchState(cards: deck)

    let e1 = st.flip(pair0[0])
    check(e1 == .firstFlip(pair0[0]), "first flip reports firstFlip")
    check(st.isFaceUp(pair0[0]), "first picked card is face up")
    check(st.moves == 0, "no move counted on the first flip of a pair")

    let e2 = st.flip(pair0[1])
    check(e2 == .matched(pair0[0], pair0[1]), "matching second flip reports matched")
    check(st.matched.contains(pair0[0]) && st.matched.contains(pair0[1]), "both indices marked matched")
    check(st.pairsMatched == 1, "pairsMatched incremented to 1")
    check(st.moves == 1, "a move is counted when second card is flipped")
    check(st.first == nil, "first pick cleared after a match")

    // Re-flipping a matched card is ignored.
    check(st.flip(pair0[0]) == .ignored, "flipping an already-matched card is ignored")
}

// MARK: - MatchState: mismatch leaves cards to flip back + counts a move

do {
    let deck = deal(pairs: 6, seed: 99)
    var idx = [Int: [Int]]()
    for (i, id) in deck.enumerated() { idx[id, default: []].append(i) }
    // two indices with DIFFERENT symbols
    let a = idx[0]![0]
    let b = idx[1]![0]
    var st = MatchState(cards: deck)
    _ = st.flip(a)
    let e = st.flip(b)
    check(e == .mismatch(a, b), "non-matching second flip reports mismatch")
    check(st.moves == 1, "mismatch still counts a move")
    check(st.pairsMatched == 0, "mismatch does not increment pairs")
    check(st.isFaceUp(a) && st.isFaceUp(b), "mismatched pair shown face up until cleared")
    // Taps are ignored while a mismatch is pending.
    check(st.flip(idx[2]![0]) == .ignored, "taps ignored while mismatch pending")
    let cleared = st.clearMismatch()
    check(cleared != nil && cleared! == (a, b), "clearMismatch returns the pending pair")
    check(!st.isFaceUp(a) && !st.isFaceUp(b), "pair flips back down after clear")
    check(st.first == nil, "no lingering first pick after mismatch clear")
}

// MARK: - MatchState: win when all pairs matched (seeded self-play)

do {
    let pairs = 8
    let deck = deal(pairs: pairs, seed: 2024)
    var st = MatchState(cards: deck)
    var idx = [Int: [Int]]()
    for (i, id) in deck.enumerated() { idx[id, default: []].append(i) }
    check(!st.isWon, "fresh board is not won")
    for id in 0..<pairs {
        let p = idx[id]!
        _ = st.flip(p[0])
        let ev = st.flip(p[1])
        check(ev == .matched(p[0], p[1]), "self-play pair \(id) matches")
    }
    check(st.isWon, "board is won when all pairs matched")
    check(st.pairsMatched == pairs, "all \(pairs) pairs counted")
    check(st.moves == pairs, "moves equal pairs on a perfect run")
    check(st.matched.count == pairs * 2, "every index is matched")
}

// MARK: - MatchState: invariant over a mixed seeded self-play

do {
    let deck = deal(pairs: 10, seed: 555)
    var st = MatchState(cards: deck)
    // Greedy correct play but interleave a wrong attempt first each round.
    var remaining = Set(0..<deck.count)
    var guardCount = 0
    while !st.isWon && guardCount < 1000 {
        guardCount += 1
        let sorted = remaining.sorted()
        guard let firstIdx = sorted.first(where: { !st.matched.contains($0) }) else { break }
        // find its partner
        let partner = sorted.first(where: { $0 != firstIdx && deck[$0] == deck[firstIdx] })!
        _ = st.flip(firstIdx)
        _ = st.flip(partner)
        remaining.remove(firstIdx)
        remaining.remove(partner)
        // Invariant: matched count is always even and 2*pairsMatched.
        check(st.matched.count == st.pairsMatched * 2, "matched == 2*pairsMatched invariant")
    }
    check(st.isWon, "mixed self-play eventually wins")
}

// MARK: - Sequence: deterministic generation + prefix property

do {
    let s3 = sequenceNext(seed: 1234, length: 3)
    let s3b = sequenceNext(seed: 1234, length: 3)
    check(s3 == s3b, "same seed+length => same sequence")
    check(s3.count == 3, "sequence has requested length")
    let s5 = sequenceNext(seed: 1234, length: 5)
    check(Array(s5.prefix(3)) == s3, "shorter sequence is a prefix of the longer one")
    for v in s5 {
        check(v >= 0 && v < 4, "pad values within 0..<4 by default")
    }
    let sPads = sequenceNext(seed: 9, length: 20, pads: 6)
    check(sPads.allSatisfy { $0 >= 0 && $0 < 6 }, "custom pad count respected")
    check(sequenceNext(seed: 1, length: 0).isEmpty, "length 0 => empty")

    let s99 = sequenceNext(seed: 42, length: 4)
    let s99other = sequenceNext(seed: 43, length: 4)
    check(s99 != s99other, "different seeds differ")
}

// MARK: - checkSequence / sequenceComplete

do {
    let target = sequenceNext(seed: 7, length: 5)
    check(checkSequence([], target), "empty input is a valid prefix")
    check(checkSequence([target[0]], target), "correct 1-length prefix accepted")
    check(checkSequence(Array(target.prefix(3)), target), "correct 3-length prefix accepted")
    check(checkSequence(target, target), "full correct input accepted")
    check(sequenceComplete(target, target), "full correct input is complete")
    check(!sequenceComplete(Array(target.prefix(3)), target), "partial input is not complete")

    // Wrong inputs
    let wrongFirst = [target[0] == 0 ? 1 : 0]
    check(!checkSequence(wrongFirst, target), "wrong first value rejected")
    var mixed = Array(target.prefix(3))
    mixed[2] = mixed[2] == 0 ? 1 : 0
    check(!checkSequence(mixed, target), "wrong value mid-prefix rejected")
    check(!checkSequence(target + [0], target), "input longer than target rejected")
}

// MARK: - Rng: deterministic + nonzero fold

do {
    var r1 = Rng(seed: 0)
    var r2 = Rng(seed: 0)
    check(r1.next() == r2.next(), "seed 0 is deterministic (folded)")
    var r3 = Rng(seed: 12345)
    let a = r3.int(10)
    let b = r3.int(10)
    check(a >= 0 && a < 10 && b >= 0 && b < 10, "int() stays in range")
    var r0 = Rng(seed: 1); check(r0.int(0) == 0, "int(0) is safe")
}

// MARK: - Result

if failures == 0 {
    print("ALL THAKIRA TESTS PASSED")
    exit(0)
} else {
    print("\(failures) FAILURES")
    exit(1)
}
