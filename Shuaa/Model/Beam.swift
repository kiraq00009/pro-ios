import Foundation

// منطق لعبة «شعاع» (Foundation فقط): مسار الليزر، توليد المراحل، والحلّال — ينفحص آليًّا
//
// شعاع ليزر يطلع من المصدر ويمشي مستقيم. المرايا تعكسه ٩٠ درجة. اضغط المراية حتى تقلبها (/ ⇄ \).
// الهدف: الشعاع يمرّ على كلّ الأهداف.

enum Tile: Int, Codable { case empty = 0, wall, target, mirrorA, mirrorB, fixedA, fixedB }      // A = «/» · B = «\»

struct BeamLevel: Codable, Equatable {
    var w: Int
    var h: Int
    var tiles: [Tile]
    var src: Int             // خانة المصدر
    var dir: Int             // اتّجاه الشعاع: 0 يمين · 1 جوّه · 2 يسار · 3 فوق
    var par: Int             // أقلّ عدد ضغطات للحلّ
    var count: Int { w * h }
}

struct Trace: Equatable {
    var cells: [Int]         // الخانات اللي يمرّ عليها الشعاع بالترتيب (تبدي بالمصدر)
    var lit: Set<Int>        // الأهداف المضاءة
    var loop: Bool
}

struct BeamRNG: RandomNumberGenerator {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum Beam {
    static let total = 50
    static let dx = [1, 0, -1, 0], dy = [0, 1, 0, -1]

    /// انعكاس الاتّجاه على مراية: «/» يمين⇄فوق و يسار⇄جوّه · «\» يمين⇄جوّه و يسار⇄فوق
    static func reflect(_ dir: Int, slash: Bool) -> Int { slash ? [3, 2, 1, 0][dir] : [1, 0, 3, 2][dir] }

    static func isMirror(_ t: Tile) -> Bool { t == .mirrorA || t == .mirrorB || t == .fixedA || t == .fixedB }
    static func movable(_ t: Tile) -> Bool { t == .mirrorA || t == .mirrorB }

    /// يمشّي الشعاع من المصدر ويرجّع مساره والأهداف اللي ضوّاها
    static func trace(_ l: BeamLevel) -> Trace {
        var x = l.src % l.w, y = l.src / l.w, d = l.dir
        var cells = [l.src]
        var lit = Set<Int>()
        var seen = Set<Int>()
        var loop = false
        while true {
            x += dx[d]; y += dy[d]
            guard x >= 0, x < l.w, y >= 0, y < l.h else { break }
            let i = y * l.w + x
            let t = l.tiles[i]
            if t == .wall { break }
            if i == l.src { cells.append(i); break }                 // رجع للمصدر
            cells.append(i)
            if t == .target { lit.insert(i) }
            if isMirror(t) { d = reflect(d, slash: t == .mirrorA || t == .fixedA) }
            let key = i * 4 + d
            if !seen.insert(key).inserted { loop = true; break }
            if cells.count > l.count * 4 + 8 { loop = true; break }
        }
        return Trace(cells: cells, lit: lit, loop: loop)
    }

    static func targets(_ l: BeamLevel) -> Int { l.tiles.filter { $0 == .target }.count }
    static func solved(_ l: BeamLevel) -> Bool { let n = targets(l); return n > 0 && trace(l).lit.count == n }

    static func flipped(_ l: BeamLevel, at i: Int) -> BeamLevel {
        var c = l
        if c.tiles[i] == .mirrorA { c.tiles[i] = .mirrorB } else if c.tiles[i] == .mirrorB { c.tiles[i] = .mirrorA }
        return c
    }

    /// يجرّب كلّ أوضاع المرايا: يرجّع (أقلّ عدد قلبات، المرايا اللي تنقلب) أو nil إذا ما إلها حلّ
    static func solve(_ l: BeamLevel) -> (flips: Int, which: [Int])? {
        let ms = l.tiles.indices.filter { movable(l.tiles[$0]) }
        guard ms.count <= 16 else { return nil }
        var best: (Int, [Int])? = nil
        for mask in 0..<(1 << ms.count) {
            let bits = mask.nonzeroBitCount
            if let b = best, bits >= b.0 { continue }
            var c = l
            for (k, m) in ms.enumerated() where mask & (1 << k) != 0 { c.tiles[m] = c.tiles[m] == .mirrorA ? .mirrorB : .mirrorA }
            if solved(c) { best = (bits, ms.enumerated().filter { mask & (1 << $0.offset) != 0 }.map { $0.element }) }
        }
        return best.map { (flips: $0.0, which: $0.1) }
    }

    /// يولّد مرحلة: نرسم مسار شعاع عشوائيّ بمرايا، نحطّ أهداف على طريقه، نضيف مرايا وجدران تمويه، ثمّ نخربط المرايا
    static func generate(w: Int, h: Int, mirrors: Int, targets: Int, decoys: Int, walls: Int, seed: UInt64) -> BeamLevel? {
        var rng = BeamRNG(seed)
        var tiles = [Tile](repeating: .empty, count: w * h)
        // المصدر على الحافّة اليسرى أو العليا
        let fromLeft = Bool.random(using: &rng)
        let src = fromLeft ? Int.random(in: 0..<h, using: &rng) * w : Int.random(in: 0..<w, using: &rng)
        let dir = fromLeft ? 0 : 1
        var x = src % w, y = src / w, d = dir
        var path: [Int] = []
        var used = Set([src])
        var placed = 0, straight = 0
        while path.count < w * h {
            let nx = x + dx[d], ny = y + dy[d]
            guard nx >= 0, nx < w, ny >= 0, ny < h else { break }
            let i = ny * w + nx
            if used.contains(i) { break }                                        // ما نخلّي المسار يقطع نفسه
            x = nx; y = ny; used.insert(i); path.append(i); straight += 1
            if placed < mirrors, straight >= 1, Int.random(in: 0..<100, using: &rng) < 38 {
                let slash = Bool.random(using: &rng)
                let nd = reflect(d, slash: slash)
                let tx = x + dx[nd], ty = y + dy[nd]
                if tx >= 0, tx < w, ty >= 0, ty < h, !used.contains(ty * w + tx) {
                    tiles[i] = slash ? .mirrorA : .mirrorB; d = nd; placed += 1; straight = 0
                }
            }
        }
        guard placed >= max(2, mirrors - 1) else { return nil }
        // الأهداف: خانات فاضية على المسار، ولازم وحدة منها بعد آخر مراية حتى كلّ المرايا تلزم
        let free = path.filter { tiles[$0] == .empty }
        guard let lastMirror = path.lastIndex(where: { tiles[$0] != .empty }) else { return nil }
        let tail = path[(lastMirror + 1)...].filter { tiles[$0] == .empty }
        guard !tail.isEmpty, free.count >= targets else { return nil }
        var chosen: Set<Int> = [tail.randomElement(using: &rng)!]
        var pool = free.shuffled(using: &rng)
        while chosen.count < targets, let c = pool.popLast() { chosen.insert(c) }
        for c in chosen { tiles[c] = .target }
        // تمويه خارج المسار
        var off = (0..<(w * h)).filter { !used.contains($0) }.shuffled(using: &rng)
        for _ in 0..<decoys { if let c = off.popLast() { tiles[c] = Bool.random(using: &rng) ? .mirrorA : .mirrorB } }
        for _ in 0..<walls { if let c = off.popLast() { tiles[c] = .wall } }
        var l = BeamLevel(w: w, h: h, tiles: tiles, src: src, dir: dir, par: 0)
        guard solved(l) else { return nil }
        // نخربط: نقلب مرايا عشوائيّة لحدّ ما الحلّ يحتاج قلبتين على الأقلّ
        let ms = l.tiles.indices.filter { movable(l.tiles[$0]) }
        for _ in 0..<12 {
            var c = l
            for m in ms where Int.random(in: 0..<100, using: &rng) < 55 { c = flipped(c, at: m) }
            if solved(c) { continue }
            guard let s = solve(c), s.flips >= min(2, ms.count) else { continue }
            c.par = s.flips; l = c
            return l
        }
        return nil
    }

    /// إعدادات كلّ مرحلة (تكبر بالتدريج)
    static func spec(_ i: Int) -> (w: Int, h: Int, mirrors: Int, targets: Int, decoys: Int, walls: Int) {
        switch i {
        case ..<5: return (4, 5, 2, 1, 0, 0)
        case ..<12: return (5, 6, 3, 2, 1, 1)
        case ..<22: return (5, 7, 4, 2, 2, 2)
        case ..<34: return (6, 8, 5, 3, 3, 3)
        default: return (7, 9, 6, 3, 4, 4)
        }
    }

    static func level(_ i: Int, salt: UInt64 = 0) -> BeamLevel {
        let s = spec(i)
        var best: BeamLevel? = nil
        for k in 0..<400 {
            guard let l = generate(w: s.w, h: s.h, mirrors: s.mirrors, targets: s.targets, decoys: s.decoys, walls: s.walls, seed: UInt64(i) &* 9973 &+ UInt64(k) &* 131_071 &+ salt &* 1_000_003 &+ 5) else { continue }
            if best == nil || l.par > best!.par { best = l }
            if l.par >= min(s.mirrors, 2 + i / 8) { break }
            if k > 60, best != nil { break }
        }
        return best ?? BeamLevel(w: 3, h: 3, tiles: [.empty, .mirrorA, .empty, .empty, .empty, .empty, .empty, .target, .empty], src: 0, dir: 0, par: 1)
    }
    static func daily(year: Int, month: Int, day: Int) -> BeamLevel { level(22 + (day % 20), salt: UInt64(year * 10_000 + month * 100 + day)) }
}
