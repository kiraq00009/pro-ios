import Foundation

// MARK: - Deterministic RNG (xorshift64)
// Pure, seedable, overflow-safe. Same seed => same stream, always.
public struct Rng {
    public private(set) var state: UInt64
    public init(seed: UInt64) {
        // 0 is a fixed point for xorshift; fold it to a nonzero constant.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }
    public mutating func next() -> UInt64 {
        var x = state
        x ^= x &<< 13
        x ^= x &>> 7
        x ^= x &<< 17
        state = x
        return x
    }
    // Uniform-ish integer in 0..<upper (upper>=1).
    public mutating func int(_ upper: Int) -> Int {
        let u = upper <= 0 ? 1 : upper
        return Int(next() % UInt64(u))
    }
}

// MARK: - Card match: deal

/// Build a shuffled deck: ids 0..<pairs, each appearing exactly twice,
/// Fisher-Yates shuffled with a seeded RNG. Deterministic per seed.
public func deal(pairs: Int, seed: UInt64) -> [Int] {
    let p = pairs < 0 ? 0 : pairs
    var arr = [Int]()
    arr.reserveCapacity(p * 2)
    var id = 0
    while id < p {
        arr.append(id)
        arr.append(id)
        id += 1
    }
    var rng = Rng(seed: seed)
    if arr.count > 1 {
        var i = arr.count - 1
        while i > 0 {
            let j = rng.int(i + 1)
            arr.swapAt(i, j)
            i -= 1
        }
    }
    return arr
}

// MARK: - Card match: flip events

public enum FlipEvent: Equatable {
    case ignored          // tap did nothing (already matched, same card, or waiting)
    case firstFlip(Int)   // first card of a pair turned up
    case matched(Int, Int)   // the two indices just matched (stay up)
    case mismatch(Int, Int)  // the two indices do not match; caller flips them back
}

// MARK: - Card match: state machine

public struct MatchState {
    public let cards: [Int]                 // symbol id at each board position
    public private(set) var matched = Set<Int>()   // indices permanently face up
    public private(set) var first: Int? = nil      // first pick awaiting a partner
    public private(set) var pending: (Int, Int)? = nil // mismatch shown, awaiting clear
    public private(set) var moves = 0
    public private(set) var pairsMatched = 0

    public var totalPairs: Int { cards.count / 2 }
    public var isWon: Bool { totalPairs > 0 && pairsMatched == totalPairs }

    public init(cards: [Int]) { self.cards = cards }
    public init(pairs: Int, seed: UInt64) { self.cards = deal(pairs: pairs, seed: seed) }

    /// A card is shown face up when matched, when it's the pending first pick,
    /// or while a mismatch pair is being displayed before flipping back.
    public func isFaceUp(_ i: Int) -> Bool {
        if matched.contains(i) { return true }
        if first == i { return true }
        if let p = pending, p.0 == i || p.1 == i { return true }
        return false
    }

    /// Core flip logic. Returns what happened so the UI can react/animate.
    @discardableResult
    public mutating func flip(_ i: Int) -> FlipEvent {
        guard i >= 0, i < cards.count else { return .ignored }
        guard pending == nil else { return .ignored }   // waiting for mismatch to clear
        guard !matched.contains(i) else { return .ignored }
        if let f = first {
            if f == i { return .ignored }                // tapped the same card twice
            moves += 1
            if cards[f] == cards[i] {
                matched.insert(f)
                matched.insert(i)
                pairsMatched += 1
                first = nil
                return .matched(f, i)
            } else {
                pending = (f, i)
                first = nil
                return .mismatch(f, i)
            }
        } else {
            first = i
            return .firstFlip(i)
        }
    }

    /// Flip the mismatched pair back down. Returns the two indices cleared.
    @discardableResult
    public mutating func clearMismatch() -> (Int, Int)? {
        guard let p = pending else { return nil }
        pending = nil
        return p
    }
}

// MARK: - Sequence (Simon) game

/// A deterministic sequence of pad indices for a seed. The sequence of
/// `length` n is always a prefix of the sequence of length n+1 (same seed),
/// so a round can grow without regenerating earlier steps.
public func sequenceNext(seed: UInt64, length: Int, pads: Int = 4) -> [Int] {
    let n = length < 0 ? 0 : length
    let p = pads < 1 ? 1 : pads
    var rng = Rng(seed: seed)
    var out = [Int]()
    out.reserveCapacity(n)
    var k = 0
    while k < n {
        out.append(rng.int(p))
        k += 1
    }
    return out
}

/// True when `input` is a (possibly partial) correct prefix of `target`.
public func checkSequence(_ input: [Int], _ target: [Int]) -> Bool {
    if input.count > target.count { return false }
    var i = 0
    while i < input.count {
        if input[i] != target[i] { return false }
        i += 1
    }
    return true
}

/// True when the player reproduced the whole target correctly.
public func sequenceComplete(_ input: [Int], _ target: [Int]) -> Bool {
    return input.count == target.count && checkSequence(input, target)
}
