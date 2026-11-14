import Foundation

// ───────────────────────── منطق خالص لسوليتير (كلوندايك) — بلا SwiftUI
// 4 أنواع، 13 مرتبة، 7 أعمدة، 4 أساسات. كلّ شي هنا قابل للاختبار وحتميّ.

/// مولّد عشوائيّ ببذرة (SplitMix64) — نفس البذرة ⇒ نفس الخلط دائمًا
public struct Seeded: RandomNumberGenerator {
    public var s: UInt64
    public init(_ seed: UInt64) { s = seed }
    public mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public enum Suit: Int, CaseIterable, Codable, Equatable {
    case spades = 0, hearts, diamonds, clubs
    public var isRed: Bool { self == .hearts || self == .diamonds }
    public var symbol: String {
        switch self { case .spades: return "♠"; case .hearts: return "♥"; case .diamonds: return "♦"; case .clubs: return "♣" }
    }
}

public struct Card: Codable, Equatable, Hashable, Identifiable {
    public var suit: Suit
    public var rank: Int          // 1 = آس … 11=J 12=Q 13=K
    public var faceUp: Bool
    public init(suit: Suit, rank: Int, faceUp: Bool = false) { self.suit = suit; self.rank = rank; self.faceUp = faceUp }
    /// معرّف ثابت للبطاقة (مستقلّ عن الوجه) حتى تبقى الأنيميشن مستقرّة في الواجهة
    public var id: Int { suit.rawValue * 13 + rank }
    public var isRed: Bool { suit.isRed }
    public var label: String {
        switch rank { case 1: return "A"; case 11: return "J"; case 12: return "Q"; case 13: return "K"; default: return "\(rank)" }
    }
}

/// حركة واحدة قابلة للتطبيق والتعداد (للتلميح)
public enum Move: Equatable, Codable {
    case draw                               // مخزن ← مرمى
    case recycle                            // مرمى ← مخزن (لمّا المخزن يفرغ)
    case wasteToFoundation                  // أعلى المرمى ← الأساس الموافق لنوعه
    case wasteToTableau(Int)                // أعلى المرمى ← عمود
    case tableauToFoundation(Int)           // أعلى عمود ← أساس نوعه
    case tableauToTableau(Int, Int, Int)    // من عمود، إلى عمود، عدد الأوراق
    case foundationToTableau(Int, Int)      // من أساس (رقم النوع)، إلى عمود
}

public struct GameState: Codable, Equatable {
    public var stock: [Card] = []
    public var waste: [Card] = []
    public var foundations: [[Card]] = [[], [], [], []]   // مفهرسة بـ suit.rawValue
    public var tableau: [[Card]] = Array(repeating: [], count: 7)
    public var draw3: Bool = false

    public init() {}

    // ───────── توزيع جديد
    public static func deal(seed: UInt64, draw3: Bool = false) -> GameState {
        var deck: [Card] = []
        for s in Suit.allCases { for r in 1...13 { deck.append(Card(suit: s, rank: r, faceUp: false)) } }
        var rng = Seeded(seed == 0 ? 1 : seed)
        deck.shuffle(using: &rng)
        var g = GameState()
        g.draw3 = draw3
        var idx = 0
        for col in 0..<7 {
            for row in 0...col {
                var c = deck[idx]; idx += 1
                c.faceUp = (row == col)      // آخر ورقة بكلّ عمود مكشوفة
                g.tableau[col].append(c)
            }
        }
        while idx < deck.count { var c = deck[idx]; idx += 1; c.faceUp = false; g.stock.append(c) }
        return g
    }

    // ───────── فحوص الشرعيّة (خالصة)
    public func canMoveToFoundation(_ c: Card, _ fi: Int) -> Bool {
        guard fi == c.suit.rawValue else { return false }
        let f = foundations[fi]
        if f.isEmpty { return c.rank == 1 }           // الآس أوّلًا
        return f.last!.rank == c.rank - 1              // ثمّ تصاعديًّا بنفس النوع
    }

    public static func canStackOnTableau(_ c: Card, onto pile: [Card]) -> Bool {
        guard let top = pile.last else { return c.rank == 13 }   // الفاضي: ملك فقط
        guard top.faceUp else { return false }
        return top.rank == c.rank + 1 && top.isRed != c.isRed     // تنازليّ بلون معاكس
    }

    /// أطول سلسلة مكشوفة صالحة (تنازليّ لون معاكس) من أعلى عمود
    public func runLength(col: Int) -> Int {
        let p = tableau[col]
        guard !p.isEmpty else { return 0 }
        var n = 1
        var i = p.count - 1
        while i > 0, p[i - 1].faceUp, p[i - 1].rank == p[i].rank + 1, p[i - 1].isRed != p[i].isRed {
            n += 1; i -= 1
        }
        return n
    }

    // ───────── تطبيق حركة
    public func applying(_ m: Move) -> GameState? {
        var g = self
        return g.apply(m) ? g : nil
    }

    private mutating func flipTop(_ col: Int) {
        if var c = tableau[col].last, !c.faceUp { c.faceUp = true; tableau[col][tableau[col].count - 1] = c }
    }

    @discardableResult
    public mutating func apply(_ m: Move) -> Bool {
        switch m {
        case .draw:
            guard !stock.isEmpty else { return false }
            let n = min(draw3 ? 3 : 1, stock.count)
            for _ in 0..<n { var c = stock.removeLast(); c.faceUp = true; waste.append(c) }
            return true
        case .recycle:
            guard stock.isEmpty, !waste.isEmpty else { return false }
            while let c = waste.popLast() { var d = c; d.faceUp = false; stock.append(d) }
            return true
        case .wasteToFoundation:
            guard let c = waste.last, canMoveToFoundation(c, c.suit.rawValue) else { return false }
            foundations[c.suit.rawValue].append(waste.removeLast())
            return true
        case .wasteToTableau(let col):
            guard col >= 0, col < 7, let c = waste.last, GameState.canStackOnTableau(c, onto: tableau[col]) else { return false }
            tableau[col].append(waste.removeLast())
            return true
        case .tableauToFoundation(let col):
            guard col >= 0, col < 7, let c = tableau[col].last, c.faceUp, canMoveToFoundation(c, c.suit.rawValue) else { return false }
            foundations[c.suit.rawValue].append(tableau[col].removeLast())
            flipTop(col)
            return true
        case .tableauToTableau(let from, let to, let count):
            guard from >= 0, from < 7, to >= 0, to < 7, from != to, count >= 1, count <= tableau[from].count else { return false }
            guard count <= runLength(col: from) else { return false }
            let run = Array(tableau[from].suffix(count))
            guard let bottom = run.first, GameState.canStackOnTableau(bottom, onto: tableau[to]) else { return false }
            tableau[from].removeLast(count)
            tableau[to].append(contentsOf: run)
            flipTop(from)
            return true
        case .foundationToTableau(let fi, let to):
            guard fi >= 0, fi < 4, to >= 0, to < 7, let c = foundations[fi].last, GameState.canStackOnTableau(c, onto: tableau[to]) else { return false }
            tableau[to].append(foundations[fi].removeLast())
            return true
        }
    }

    // ───────── تعداد الحركات الشرعيّة (للتلميح)
    public func legalMoves() -> [Move] {
        var out: [Move] = []
        if !stock.isEmpty { out.append(.draw) }
        else if !waste.isEmpty { out.append(.recycle) }
        if let c = waste.last {
            if canMoveToFoundation(c, c.suit.rawValue) { out.append(.wasteToFoundation) }
            for col in 0..<7 where GameState.canStackOnTableau(c, onto: tableau[col]) { out.append(.wasteToTableau(col)) }
        }
        for col in 0..<7 {
            if let c = tableau[col].last, c.faceUp, canMoveToFoundation(c, c.suit.rawValue) { out.append(.tableauToFoundation(col)) }
        }
        for from in 0..<7 {
            let rl = runLength(col: from)
            guard rl >= 1 else { continue }
            for count in 1...rl {
                let bottom = tableau[from][tableau[from].count - count]
                for to in 0..<7 where to != from {
                    // لا تنقل ملكًا من عمود فيه هو الوحيد المكشوف إلى فاضٍ (حركة بلا فائدة)
                    if tableau[to].isEmpty && count == tableau[from].count { continue }
                    if GameState.canStackOnTableau(bottom, onto: tableau[to]) { out.append(.tableauToTableau(from, to, count)) }
                }
            }
        }
        for fi in 0..<4 {
            if let c = foundations[fi].last {
                for col in 0..<7 where GameState.canStackOnTableau(c, onto: tableau[col]) { out.append(.foundationToTableau(fi, col)) }
            }
        }
        return out
    }

    /// نقلة تلميح مفيدة: يفضّل الأساسات ثمّ حركات العمود المفيدة
    public func hint() -> Move? {
        let moves = legalMoves()
        if let f = moves.first(where: { if case .wasteToFoundation = $0 { return true }; if case .tableauToFoundation = $0 { return true }; return false }) { return f }
        if let t = moves.first(where: { if case .tableauToTableau = $0 { return true }; if case .wasteToTableau = $0 { return true }; return false }) { return t }
        return moves.first
    }

    // ───────── نقل تلقائيّ للأساسات (نقرة ورقة أو إكمال)
    /// يحاول نقل بطاقة واحدة (أعلى عمود أو أعلى المرمى) إلى أساسها
    public func autoMoveToFoundations() -> GameState {
        var g = self
        var changed = true
        while changed {
            changed = false
            if let c = g.waste.last, g.canMoveToFoundation(c, c.suit.rawValue) { g.apply(.wasteToFoundation); changed = true; continue }
            for col in 0..<7 {
                if let c = g.tableau[col].last, c.faceUp, g.canMoveToFoundation(c, c.suit.rawValue) { g.apply(.tableauToFoundation(col)); changed = true; break }
            }
        }
        return g
    }

    /// إكمال تلقائيّ كامل: ينقل للأساسات ويسحب من المخزن حتى يفوز أو يعلق
    public func autoCompleted() -> GameState {
        var g = self
        var guardN = 0
        while !g.isWon && guardN < 2000 {
            guardN += 1
            let before = g
            g = g.autoMoveToFoundations()
            if g != before { continue }
            if !g.stock.isEmpty { g.apply(.draw) }
            else if !g.waste.isEmpty { g.apply(.recycle) }
            else { break }
            // إذا دار دورة كاملة بلا تقدّم، اوقف
            if g == before { break }
        }
        return g
    }

    /// كلّ أوراق الأعمدة مكشوفة (شرط عرض زرّ الإكمال التلقائيّ)
    public var allTableauFaceUp: Bool { tableau.allSatisfy { $0.allSatisfy { $0.faceUp } } }

    public var isWon: Bool { foundations.reduce(0) { $0 + $1.count } == 52 }

    /// كلّ البطاقات (للتحقّق من الثبات في الاختبار)
    public var allCards: [Card] { stock + waste + foundations.flatMap { $0 } + tableau.flatMap { $0 } }
}
