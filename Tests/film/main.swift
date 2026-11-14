import Foundation

var failures: [String] = []
func check(_ cond: Bool, _ msg: String) {
    if !cond { failures.append(msg) }
}

// MARK: - Wheel

do {
    let g = Wheel.genres()
    check(!g.isEmpty, "genres() should be non-empty")
    check(g.count >= 10, "genres() should have a decent count (got \(g.count))")
    let names = Set(g.map { $0.name })
    check(names.count == g.count, "genre names must be distinct")
    for ge in g {
        check(!ge.name.isEmpty, "genre name not empty")
        check(!ge.vibe.isEmpty, "genre vibe not empty")
        check(!ge.emoji.isEmpty, "genre emoji not empty")
    }
    // Deterministic per seed
    for s in [0, 1, 2, 7, 42, 100, 9999, -5] {
        let a = Wheel.spin(seed: s)
        let b = Wheel.spin(seed: s)
        check(a == b, "spin(\(s)) must be deterministic")
        check(g.contains(a), "spin(\(s)) must return a valid genre")
    }
    // Different seeds should (at least sometimes) differ -> coverage sanity
    let sample = Set((0..<200).map { Wheel.spin(seed: $0).name })
    check(sample.count > 1, "spin should produce more than one distinct genre across seeds")
}

// MARK: - Bracket

func runBracket(_ opts: [String]) -> (champ: String?, matches: Int) {
    var b = Bracket(options: opts)
    var guardCount = 0
    while let m = b.next() {
        b.pick(m.0)          // always pick the first option
        guardCount += 1
        if guardCount > 1000 { break }   // safety
    }
    check(b.next() == nil, "no pairing after done for \(opts.count) options")
    return (b.champion, b.matchesPlayed)
}

do {
    // 2 options -> one match
    let r2 = runBracket(["A", "B"])
    check(r2.champ == "A", "2 options: champion should be first-picked A")
    check(r2.matches == 1, "2 options: exactly 1 match (got \(r2.matches))")

    // 4 options -> 3 matches
    let r4 = runBracket(["A", "B", "C", "D"])
    check(r4.matches == 3, "4 options: exactly 3 matches (got \(r4.matches))")
    check(["A", "B", "C", "D"].contains(r4.champ ?? ""), "4 options: champ in inputs")

    // odd counts with byes still end with one champion
    for opts in [["A", "B", "C"], ["A", "B", "C", "D", "E"], ["A", "B", "C", "D", "E", "F", "G"]] {
        let r = runBracket(opts)
        check(r.champ != nil, "\(opts.count) options: must have a champion")
        check(opts.contains(r.champ ?? ""), "\(opts.count) options: champ is one of the inputs")
    }

    // picking a non-participant is ignored (state stays consistent)
    var bb = Bracket(options: ["X", "Y", "Z"])
    _ = bb.next()
    bb.pick("NOPE")                 // invalid -> ignored
    check(bb.champion == nil, "invalid pick must not finish bracket")
    check(bb.matchesPlayed == 0, "invalid pick must not count a match")

    // champion decided by picks: pick the second each time
    var b2 = Bracket(options: ["A", "B", "C", "D"])
    while let m = b2.next() { b2.pick(m.1) }
    check(b2.champion != nil, "pick-second bracket must finish")
    check(["A", "B", "C", "D"].contains(b2.champion ?? ""), "pick-second champ in inputs")
}

// MARK: - Vote

do {
    let t = Vote.tally(votes: [0, 1, 1, 2, 1], options: 3)
    check(t.counts == [1, 3, 1], "tally counts wrong: \(t.counts)")
    check(t.counts.reduce(0, +) == 5, "tally should count all valid votes")
    check(t.winnerIndices == [1], "winner should be index 1")

    // tie -> multiple winners
    let tie = Vote.tally(votes: [0, 0, 1, 1], options: 3)
    check(tie.winnerIndices == [0, 1], "tie should return both winners: \(tie.winnerIndices)")

    // out-of-range votes ignored
    let oor = Vote.tally(votes: [0, 5, -1, 1], options: 2)
    check(oor.counts == [1, 1], "out-of-range votes must be ignored: \(oor.counts)")
    check(oor.winnerIndices == [0, 1], "two equal valid votes -> tie")

    // no votes -> no winner
    let none = Vote.tally(votes: [], options: 3)
    check(none.counts == [0, 0, 0], "empty votes -> zero counts")
    check(none.winnerIndices.isEmpty, "empty votes -> no winner")
}

// MARK: - Trivia

do {
    let bank = Trivia.questions()
    check(bank.count >= 30, "question bank must have >=30 (got \(bank.count))")
    for (i, q) in bank.enumerated() {
        check(q.options.count >= 2, "Q\(i): need >=2 options")
        check(q.answer >= 0 && q.answer < q.options.count, "Q\(i): answer index valid")
        check(Set(q.options).count == q.options.count, "Q\(i): options must be distinct")
        check(!q.text.isEmpty, "Q\(i): text not empty")
    }
    // quiz deterministic + exact count
    for seed in [1, 2, 50, 123] {
        let a = Trivia.quiz(seed: seed, count: 10)
        let b = Trivia.quiz(seed: seed, count: 10)
        check(a == b, "quiz(\(seed)) must be deterministic")
        check(a.count == 10, "quiz(\(seed)) should return requested count (got \(a.count))")
        for q in a { check(q.answer >= 0 && q.answer < q.options.count, "quiz Q answer valid") }
    }
    // count capped at bank size
    let big = Trivia.quiz(seed: 1, count: 9999)
    check(big.count == bank.count, "quiz count capped at bank size")
    // zero count
    check(Trivia.quiz(seed: 1, count: 0).isEmpty, "quiz count 0 -> empty")

    // scoring helper
    check(Trivia.points(correct: false, streak: 5, timeLeft: 9) == 0, "wrong answer -> 0 points")
    check(Trivia.points(correct: true, streak: 0, timeLeft: 0) == 10, "base correct -> 10")
    check(Trivia.points(correct: true, streak: 3, timeLeft: 5) == 10 + 6 + 5, "streak+time bonus")
}

// MARK: - Result

if failures.isEmpty {
    print("ALL FILM TESTS PASSED")
    exit(0)
} else {
    print("FAILURES (\(failures.count)):")
    for f in failures { print("  - \(f)") }
    exit(1)
}
