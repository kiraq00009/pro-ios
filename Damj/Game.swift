import Foundation
import SwiftUI

// MARK: - Animated tile (view-side model with stable identity)

struct Tile: Identifiable, Equatable {
    let id: Int
    var value: Int
    var row: Int
    var col: Int
    var isNew: Bool = false
    var pop: Bool = false
}

// MARK: - Game state

@MainActor
final class Game: ObservableObject {

    @Published var tiles: [Tile] = []
    @Published var score = 0
    @Published var best = 0
    @Published var size = 4
    @Published var won = false
    @Published var keepGoing = false
    @Published var over = false
    @Published var busy = false

    let target = 2048
    private var nextId = 0
    private var seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000) ^ 0x9E3779B97F4A7C15

    private struct Snapshot { let tiles: [Tile]; let score: Int; let seed: UInt64; let over: Bool; let won: Bool }
    private var undoSnap: Snapshot?

    private let slideDur = 0.13

    var canUndo: Bool { undoSnap != nil }
    var hasSaved: Bool { UserDefaults.standard.data(forKey: saveKey) != nil }

    private var saveKey: String { "damj.save" }
    private var bestKey: String { "damj.best" }

    init() {
        best = UserDefaults.standard.integer(forKey: bestKey)
    }

    // MARK: Board helpers

    func valueGrid() -> [[Int]] {
        var g = Grid.empty(size)
        for t in tiles where t.row < size && t.col < size { g[t.row][t.col] = t.value }
        return g
    }

    private func newTileId() -> Int { defer { nextId += 1 }; return nextId }

    // MARK: Lifecycle

    func newGame(size: Int? = nil) {
        if let s = size { self.size = s }
        tiles.removeAll()
        score = 0
        won = false
        keepGoing = false
        over = false
        undoSnap = nil
        seed ^= Grid.mix(seed)
        spawnTile(animated: false)
        spawnTile(animated: false)
        save()
    }

    private func addTile(value: Int, row: Int, col: Int, isNew: Bool) {
        tiles.append(Tile(id: newTileId(), value: value, row: row, col: col, isNew: isNew))
    }

    private func spawnTile(animated: Bool) {
        let res = Grid.spawn(valueGrid(), seed: seed)
        seed = res.seed
        guard res.placed, let at = res.at else { return }
        let v = res.grid[at.0][at.1]
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                addTile(value: v, row: at.0, col: at.1, isNew: true)
            }
        } else {
            addTile(value: v, row: at.0, col: at.1, isNew: false)
        }
    }

    // MARK: Move

    func move(_ dir: Move) {
        guard !over, !busy, !tiles.isEmpty else { return }

        var byCell = [Int: Tile]()           // row*size+col -> tile
        for t in tiles { byCell[t.row * size + t.col] = t }

        var updated = Dictionary(uniqueKeysWithValues: tiles.map { ($0.id, $0) })
        var consumed = Set<Int>()
        var gained = 0
        var moved = false

        for line in Grid.lines(size, dir) {
            let lineTiles = line.compactMap { byCell[$0.0 * size + $0.1] }
            var outIdx = 0
            var i = 0
            while i < lineTiles.count {
                let coord = line[outIdx]
                if i + 1 < lineTiles.count && lineTiles[i].value == lineTiles[i + 1].value {
                    var surv = updated[lineTiles[i].id]!
                    let other = lineTiles[i + 1]
                    surv.row = coord.0; surv.col = coord.1
                    surv.value *= 2; surv.pop = true; surv.isNew = false
                    updated[surv.id] = surv
                    var o = updated[other.id]!
                    o.row = coord.0; o.col = coord.1
                    updated[other.id] = o
                    consumed.insert(other.id)
                    gained += surv.value
                    moved = true
                    i += 2
                } else {
                    var t = updated[lineTiles[i].id]!
                    if t.row != coord.0 || t.col != coord.1 { moved = true }
                    t.row = coord.0; t.col = coord.1; t.pop = false; t.isNew = false
                    updated[t.id] = t
                    i += 1
                }
                outIdx += 1
            }
        }

        guard moved else { return }

        undoSnap = Snapshot(tiles: tiles, score: score, seed: seed, over: over, won: won)

        withAnimation(.easeInOut(duration: slideDur)) {
            tiles = tiles.map { updated[$0.id]! }
        }

        score += gained
        if score > best { best = score; UserDefaults.standard.set(best, forKey: bestKey) }

        if gained > 0 { Haptic.thud() } else { Haptic.tap() }

        busy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + slideDur) { [weak self] in
            guard let self else { return }
            self.tiles.removeAll { consumed.contains($0.id) }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                for i in self.tiles.indices { self.tiles[i].pop = false }
            }
            self.spawnTile(animated: true)

            let g = self.valueGrid()
            if !self.won && Grid.hasWon(g, target: self.target) {
                self.won = true
                Haptic.ok()
            }
            if Grid.isGameOver(g) {
                self.over = true
                Haptic.bad()
            }
            self.busy = false
            self.save()
        }
    }

    func undo() {
        guard let s = undoSnap else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            tiles = s.tiles
            score = s.score
            over = s.over
            won = s.won
        }
        seed = s.seed
        undoSnap = nil
        Haptic.tap()
        save()
    }

    func continueAfterWin() {
        keepGoing = true
        won = false
    }

    // MARK: Persistence

    func save() {
        guard !Shot.on else { return }
        let payload: [String: Any] = [
            "grid": valueGrid(),
            "score": score,
            "size": size,
            "seed": String(seed),
            "won": won,
            "keepGoing": keepGoing,
            "over": over
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    @discardableResult
    func loadSaved() -> Bool {
        guard !Shot.on,
              let data = UserDefaults.standard.data(forKey: saveKey),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let grid = obj["grid"] as? [[Int]], !grid.isEmpty
        else { return false }

        size = obj["size"] as? Int ?? grid.count
        score = obj["score"] as? Int ?? 0
        won = obj["won"] as? Bool ?? false
        keepGoing = obj["keepGoing"] as? Bool ?? false
        over = obj["over"] as? Bool ?? false
        if let s = obj["seed"] as? String, let v = UInt64(s) { seed = v }

        tiles.removeAll()
        for r in 0..<grid.count {
            for c in 0..<grid[r].count where grid[r][c] != 0 {
                addTile(value: grid[r][c], row: r, col: c, isNew: false)
            }
        }
        return !tiles.isEmpty
    }

    // MARK: Screenshot seeding

    func seed(board: [[Int]], score: Int, won: Bool = false, over: Bool = false) {
        size = board.count
        tiles.removeAll()
        nextId = 0
        for r in 0..<board.count {
            for c in 0..<board[r].count where board[r][c] != 0 {
                addTile(value: board[r][c], row: r, col: c, isNew: false)
            }
        }
        self.score = score
        self.best = max(best, score)
        self.won = won
        self.over = over
    }
}
