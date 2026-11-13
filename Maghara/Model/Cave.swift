import Foundation

// محرّك «مغارة» — مغامرة دهاليز بالأدوار. منطق خالص ينفحص آليًّا (بوت يلعب مئات الجولات).

struct RNG: RandomNumberGenerator, Codable, Hashable {
    var s: UInt64
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func int(_ r: ClosedRange<Int>) -> Int { Int.random(in: r, using: &self) }
    mutating func chance(_ p: Int) -> Bool { int(0...99) < p }
}

enum Tile: Int, Codable { case wall, floor, exit, trap, shop, shrine }
enum Item: Int, Codable { case potion, bomb, gold, sword, shield, heart, chest }

struct Kind {
    let name: String, glyph: String
    let hp: Int, hpF: Double, atk: Int, atkF: Double, def: Int, xp: Int, minFloor: Int
    var ranged = 0, fast = false, slow = false, poison = false, boss = false
    var note = ""
}

enum Bestiary {
    static let all: [Kind] = [
        Kind(name: "خفّاش", glyph: "🦇", hp: 4, hpF: 0.7, atk: 2, atkF: 0.3, def: 0, xp: 2, minFloor: 1, fast: true, note: "سريع: يتحرّك مرّتين بالدور وحركته مو متوقّعة"),
        Kind(name: "هلام", glyph: "🦠", hp: 7, hpF: 1.3, atk: 2, atkF: 0.4, def: 0, xp: 3, minFloor: 1, note: "بطيء الفهم بس يتحمّل"),
        Kind(name: "هيكل عظميّ", glyph: "💀", hp: 9, hpF: 1.6, atk: 3, atkF: 0.45, def: 1, xp: 4, minFloor: 2, note: "عنده درع — الضربات الضعيفة ما تأثّر بيه"),
        Kind(name: "عنكبوت", glyph: "🕷️", hp: 6, hpF: 1.1, atk: 2, atkF: 0.4, def: 0, xp: 4, minFloor: 3, poison: true, note: "عضّته مسمومة: تنزف ثلاث أدوار"),
        Kind(name: "غول", glyph: "👹", hp: 14, hpF: 1.9, atk: 4, atkF: 0.5, def: 1, xp: 6, minFloor: 5, note: "ضربته ثقيلة — لا تخلّيه يحاصرك"),
        Kind(name: "ساحر", glyph: "🧙", hp: 7, hpF: 1.1, atk: 3, atkF: 0.45, def: 0, xp: 6, minFloor: 6, ranged: 3, note: "يضرب من بعيد على خطّ مستقيم — اختبئ ورا الجدار"),
        Kind(name: "شبح", glyph: "👻", hp: 10, hpF: 1.3, atk: 5, atkF: 0.55, def: 2, xp: 7, minFloor: 8, slow: true, note: "بطيء بس ضربته توجع ودرعه قويّ"),
        Kind(name: "ملك الهلام", glyph: "🐸", hp: 40, hpF: 0, atk: 6, atkF: 0, def: 1, xp: 20, minFloor: 4, boss: true, note: "زعيم الطابق الرابع"),
        Kind(name: "زعيم الغيلان", glyph: "👺", hp: 72, hpF: 0, atk: 9, atkF: 0, def: 2, xp: 35, minFloor: 8, boss: true, note: "زعيم الطابق الثامن"),
        Kind(name: "التنّين", glyph: "🐉", hp: 120, hpF: 0, atk: 12, atkF: 0, def: 3, xp: 60, minFloor: 12, ranged: 3, boss: true, note: "آخر المغارة — ينفخ نار من بعيد")
    ]
}

struct Perk {
    let name: String, icon: String, text: String
    static let all: [Perk] = [
        Perk(name: "قلب حديد", icon: "heart.fill", text: "+8 للصحّة القصوى وتتعالج كامل"),
        Perk(name: "سيف أمضى", icon: "bolt.fill", text: "+2 للهجوم"),
        Perk(name: "جلد صخر", icon: "shield.fill", text: "+1 للدفاع"),
        Perk(name: "مصّاص", icon: "drop.fill", text: "كلّ قتلة ترجّعلك 3 صحّة"),
        Perk(name: "ضربة قاضية", icon: "flame.fill", text: "+18٪ احتمال ضربة مضاعفة"),
        Perk(name: "أشواك", icon: "staroflife.fill", text: "اللي يضربك ياخذ 2 ضرر"),
        Perk(name: "صيّاد كنوز", icon: "dollarsign.circle.fill", text: "ذهب أكثر بـ50٪"),
        Perk(name: "عين الصقر", icon: "eye.fill", text: "تشوف أبعد بخانتين"),
        Perk(name: "خفّة", icon: "wind", text: "+15٪ تتفادى الضربة"),
        Perk(name: "كيميائيّ", icon: "cross.vial.fill", text: "الدوا يعالجك كامل + دوا هديّة")
    ]
}

struct Mon: Codable, Hashable, Identifiable {
    var id: Int
    var kind: Int
    var pos: Int
    var hp: Int, maxHp: Int, atk: Int, def: Int
    var awake = false
}

struct Hero: Codable, Hashable {
    var pos = 0
    var hp = 30, maxHp = 30, atk = 4, def = 1
    var level = 1, xp = 0, gold = 0, potions = 1, bombs = 1, poison = 0, kills = 0
    var perks = [Int](repeating: 0, count: 10)
}

struct Fx: Codable, Hashable {
    var at: Int
    var text: String
    var tone: Int        // 0 ضرر للوحش · 1 ضرر إلك · 2 زين · 3 ذهب
}

struct Cave: Codable {
    static let W = 9, H = 13, lastFloor = 12
    static let shopPrices = [22, 28, 55, 55, 40]      // دوا · قنبلة · سيف · درع · قلب

    var seed: UInt64
    var rng: RNG
    var floor = 1
    var tiles: [Tile] = []
    var seen: [Bool] = []
    var lit: [Bool] = []
    var items: [Int: Item] = [:]
    var mons: [Mon] = []
    var hero = Hero()
    var turn = 0
    var nextId = 1
    var over = false, won = false
    var perks: [Int] = []         // خيارات الترقية المعروضة (لازم يختار قبل ما يكمّل)
    var owed = 0
    var atShop = false, atShrine = false
    var log: [String] = []
    var fx: [Fx] = []
    var met = Set<Int>()          // أنواع الوحوش اللي شافها

    init(seed: UInt64) {
        self.seed = seed
        rng = RNG(s: seed &* 2654435761 &+ 17)
        generate()
    }

    // MARK: مساعدات

    var busy: Bool { !perks.isEmpty || atShop || atShrine }
    var score: Int { (won ? 500 : 0) + (floor - 1) * 100 + hero.kills * 10 + hero.gold }
    var need: Int { 6 + hero.level * 5 }
    var sight: Int { 3 + hero.perks[7] * 2 }
    var bossAlive: Bool { mons.contains { Bestiary.all[$0.kind].boss } }
    func monAt(_ p: Int) -> Int? { mons.firstIndex { $0.pos == p } }
    func near(_ p: Int) -> [Int] { [p + 1, p + Cave.W, p - 1, p - Cave.W] }
    func adjacent(_ a: Int, _ b: Int) -> Bool { near(a).contains(b) }
    private mutating func say(_ s: String) { log.append(s); if log.count > 40 { log.removeFirst(log.count - 40) } }

    func bfs(from s: Int) -> [Int] {
        var d = [Int](repeating: 999, count: tiles.count)
        guard s >= 0, s < tiles.count, tiles[s] != .wall else { return d }
        d[s] = 0
        var q = [s], h = 0
        while h < q.count {
            let p = q[h]; h += 1
            for n in near(p) where tiles[n] != .wall && d[n] == 999 { d[n] = d[p] + 1; q.append(n) }
        }
        return d
    }

    func clear(_ a: Int, _ b: Int) -> Bool {
        let W = Cave.W
        var x0 = a % W, y0 = a / W
        let x1 = b % W, y1 = b / W
        let dx = abs(x1 - x0), dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        while true {
            if x0 == x1 && y0 == y1 { return true }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
            if x0 == x1 && y0 == y1 { return true }
            if tiles[y0 * W + x0] == .wall { return false }
        }
    }

    private mutating func look() {
        let W = Cave.W, H = Cave.H
        let hx = hero.pos % W, hy = hero.pos / W
        let r = sight
        lit = [Bool](repeating: false, count: tiles.count)
        for y in max(0, hy - r)...min(H - 1, hy + r) {
            for x in max(0, hx - r)...min(W - 1, hx + r) {
                let ddx = x - hx, ddy = y - hy
                if ddx * ddx + ddy * ddy > r * r + r { continue }
                let p = y * W + x
                if clear(hero.pos, p) { lit[p] = true; seen[p] = true }
            }
        }
        for m in mons where lit[m.pos] { met.insert(m.kind) }
    }

    /// للتصوير والفحص: يقفز لطابق معيّن
    mutating func jump(_ f: Int) { floor = max(1, min(Cave.lastFloor, f)); generate() }

    // MARK: توليد الطابق

    private mutating func generate() {
        let W = Cave.W, H = Cave.H
        var t = [Tile](repeating: .wall, count: W * H)
        var x = W / 2, y = H / 2
        t[y * W + x] = .floor
        var carved = 1, tries = 0
        let goal = Int(Double((W - 2) * (H - 2)) * 0.6)
        let dxs = [1, 0, -1, 0], dys = [0, 1, 0, -1]
        while carved < goal && tries < 40000 {
            tries += 1
            let d = rng.int(0...3)
            let nx = x + dxs[d], ny = y + dys[d]
            if nx < 1 || ny < 1 || nx > W - 2 || ny > H - 2 { continue }
            x = nx; y = ny
            if t[y * W + x] == .wall { t[y * W + x] = .floor; carved += 1 }
        }
        tiles = t
        seen = [Bool](repeating: false, count: W * H)
        lit = seen
        items = [:]; mons = []
        atShop = false; atShrine = false
        let cells = (0..<(W * H)).filter { t[$0] == .floor }
        let a = cells[rng.int(0...(cells.count - 1))]
        let d1 = bfs(from: a)
        let exit = cells.max { d1[$0] < d1[$1] } ?? a
        let d2 = bfs(from: exit)
        let start = cells.max { d2[$0] < d2[$1] } ?? a
        tiles[exit] = .exit
        hero.pos = start
        let ds = bfs(from: start)
        var free = cells.filter { $0 != start && $0 != exit }
        free.shuffle(using: &rng)
        func take(_ minDist: Int) -> Int? {
            if let k = free.firstIndex(where: { ds[$0] >= minDist }) { return free.remove(at: k) }
            return free.popLast()
        }
        let bossFloor = floor % 4 == 0
        // وحوش
        if bossFloor {
            let bk = Bestiary.all.firstIndex { $0.boss && $0.minFloor == floor } ?? 7
            let spot = d2.enumerated().filter { t[$0.offset] == .floor && $0.offset != start && $0.element >= 1 && $0.element <= 3 }.map { $0.offset }.first ?? exit
            free.removeAll { $0 == spot }
            spawn(bk, at: spot)
        }
        let pool = Bestiary.all.indices.filter { !Bestiary.all[$0].boss && Bestiary.all[$0].minFloor <= floor }
        let count = bossFloor ? 2 + floor / 6 : min(8, 3 + floor / 2)
        for _ in 0..<count {
            guard let p = take(4) else { break }
            // الأنواع الأحدث تطلع أكثر
            let k = pool[max(rng.int(0...(pool.count - 1)), rng.int(0...(pool.count - 1)))]
            spawn(k, at: p)
        }
        // أغراض
        var loot: [Item] = [.gold, .gold, .chest]
        if rng.chance(70) { loot.append(.potion) }
        if rng.chance(35) { loot.append(.bomb) }
        if rng.chance(45) { loot.append(.gold) }
        if rng.chance(22) { loot.append(.heart) }
        if bossFloor { loot.append(.potion) }
        for it in loot { if let p = take(2) { items[p] = it } }
        // فخاخ ودكّان ومذبح
        if floor >= 3 { for _ in 0..<min(3, floor / 3) { if let p = take(3) { tiles[p] = .trap } } }
        if floor % 3 == 0 && !bossFloor, let p = take(3) { tiles[p] = .shop }
        if floor % 5 == 0 || floor == 7, let p = take(3) { tiles[p] = .shrine }
        look()
    }

    private mutating func spawn(_ k: Int, at p: Int) {
        let s = Bestiary.all[k]
        let f = Double(floor - 1)
        let hp = s.hp + Int(s.hpF * f), atk = s.atk + Int(s.atkF * f)
        mons.append(Mon(id: nextId, kind: k, pos: p, hp: hp, maxHp: hp, atk: atk, def: s.def))
        nextId += 1
    }

    // MARK: أفعال اللاعب

    /// حركة أو هجوم باتّجاه: 0 يمين · 1 جوّه · 2 يسار · 3 فوق
    @discardableResult mutating func act(_ dir: Int) -> Bool {
        guard !over, !busy, dir >= 0, dir < 4 else { return false }
        let to = near(hero.pos)[dir]
        guard to >= 0, to < tiles.count, tiles[to] != .wall else { return false }
        fx = []
        if let mi = monAt(to) { strike(mi); endTurn(); return true }
        if tiles[to] == .exit && floor % 4 == 0 && bossAlive {
            say("الباب مقفول — لازم تخلّص على الزعيم أوّل")
            return false
        }
        hero.pos = to
        if let it = items[to] { items[to] = nil; pick(it, at: to) }
        switch tiles[to] {
        case .trap:
            let dmg = 3 + floor / 2
            hero.hp -= dmg; tiles[to] = .floor
            fx.append(Fx(at: to, text: "-\(dmg)", tone: 1)); say("دست على فخّ! -\(dmg)")
            if hero.hp <= 0 { die("فخّ"); return true }
        case .shop: atShop = true
        case .shrine: atShrine = true
        case .exit: descend(); return true
        default: break
        }
        endTurn()
        return true
    }

    @discardableResult mutating func rest() -> Bool {
        guard !over, !busy else { return false }
        fx = []
        endTurn()
        return true
    }

    @discardableResult mutating func drink() -> Bool {
        guard !over, !busy, hero.potions > 0, hero.hp < hero.maxHp else { return false }
        fx = []
        hero.potions -= 1
        let heal = hero.perks[9] > 0 ? hero.maxHp : max(8, hero.maxHp / 2)
        let before = hero.hp
        hero.hp = min(hero.maxHp, hero.hp + heal); hero.poison = 0
        fx.append(Fx(at: hero.pos, text: "+\(hero.hp - before)", tone: 2)); say("شربت الدوا: +\(hero.hp - before) صحّة")
        endTurn()
        return true
    }

    @discardableResult mutating func bomb() -> Bool {
        guard !over, !busy, hero.bombs > 0 else { return false }
        fx = []
        hero.bombs -= 1
        let W = Cave.W
        let hx = hero.pos % W, hy = hero.pos / W
        let dmg = 8 + floor * 2
        var hit = 0
        for id in mons.map({ $0.id }) {
            guard let i = mons.firstIndex(where: { $0.id == id }) else { continue }
            let p = mons[i].pos
            if abs(p % W - hx) <= 2 && abs(p / W - hy) <= 2 && lit[p] {
                hit += 1
                mons[i].hp -= dmg; mons[i].awake = true
                fx.append(Fx(at: p, text: "\(dmg)", tone: 0))
                if mons[i].hp <= 0 { kill(i) }
            }
        }
        say(hit > 0 ? "بوم! القنبلة صابت \(hit)" : "القنبلة ما صابت أحد")
        endTurn()
        return true
    }

    mutating func choose(_ k: Int) {
        guard perks.contains(k) else { return }
        hero.perks[k] += 1
        switch k {
        case 0: hero.maxHp += 8; hero.hp = hero.maxHp
        case 1: hero.atk += 2
        case 2: hero.def += 1
        case 9: hero.potions += 1
        default: break
        }
        say("ترقية: \(Perk.all[k].name)")
        perks = []
        owed -= 1
        if owed > 0 { offer() } else { owed = 0; look() }
    }

    func price(_ i: Int) -> Int { Cave.shopPrices[i] + floor * 2 }
    @discardableResult mutating func buy(_ i: Int) -> Bool {
        guard atShop, i >= 0, i < 5, hero.gold >= price(i) else { return false }
        hero.gold -= price(i)
        switch i {
        case 0: hero.potions += 1
        case 1: hero.bombs += 1
        case 2: hero.atk += 1
        case 3: hero.def += 1
        default: hero.maxHp += 5; hero.hp += 5
        }
        return true
    }
    mutating func leave() { atShop = false; atShrine = false }
    /// المذبح: تضحّي بربع صحّتك وتاخذ +2 هجوم
    @discardableResult mutating func pray() -> Bool {
        guard atShrine else { return false }
        let cost = max(1, hero.maxHp / 4)
        guard hero.hp > cost else { return false }
        hero.hp -= cost; hero.atk += 2
        tiles[hero.pos] = .floor; atShrine = false
        say("ضحّيت بـ\(cost) صحّة — هجومك زاد 2")
        return true
    }

    // MARK: القتال

    private mutating func strike(_ mi: Int) {
        var dmg = max(1, hero.atk - mons[mi].def + rng.int(-1...1))
        let crit = rng.chance(5 + 18 * hero.perks[4])
        if crit { dmg *= 2 }
        mons[mi].hp -= dmg; mons[mi].awake = true
        fx.append(Fx(at: mons[mi].pos, text: crit ? "\(dmg)!" : "\(dmg)", tone: 0))
        if mons[mi].hp <= 0 { kill(mi) }
    }

    private mutating func kill(_ mi: Int) {
        let m = mons.remove(at: mi)
        let k = Bestiary.all[m.kind]
        hero.kills += 1
        say("خلّصت على \(k.name)")
        if hero.perks[3] > 0 && hero.hp > 0 {
            let h = min(hero.maxHp - hero.hp, 3 * hero.perks[3])
            if h > 0 { hero.hp += h; fx.append(Fx(at: hero.pos, text: "+\(h)", tone: 2)) }
        }
        if items[m.pos] == nil && tiles[m.pos] == .floor {
            if k.boss { items[m.pos] = .chest } else if rng.chance(30) { items[m.pos] = .gold }
        }
        hero.xp += k.xp
        while hero.xp >= need {
            hero.xp -= need
            hero.level += 1; hero.maxHp += 2; hero.hp = min(hero.maxHp, hero.hp + 2)
            owed += 1
        }
        if owed > 0 && perks.isEmpty { offer() }
    }

    private mutating func offer() {
        var all = Array(0..<Perk.all.count)
        if hero.perks[7] >= 2 { all.removeAll { $0 == 7 } }
        if hero.perks[8] >= 3 { all.removeAll { $0 == 8 } }
        if hero.perks[9] >= 1 { all.removeAll { $0 == 9 } }
        all.shuffle(using: &rng)
        perks = Array(all.prefix(3))
        say("وصلت المستوى \(hero.level)! اختار ترقية")
    }

    private mutating func pick(_ it: Item, at p: Int) {
        switch it {
        case .potion: hero.potions += 1; fx.append(Fx(at: p, text: "+دوا", tone: 2)); say("لگيت دوا")
        case .bomb: hero.bombs += 1; fx.append(Fx(at: p, text: "+قنبلة", tone: 2)); say("لگيت قنبلة")
        case .gold:
            var g = rng.int(5...11) + floor * 2
            if hero.perks[6] > 0 { g += g * hero.perks[6] / 2 }
            hero.gold += g; fx.append(Fx(at: p, text: "+\(g)", tone: 3)); say("ذهب +\(g)")
        case .sword: hero.atk += 1; fx.append(Fx(at: p, text: "هجوم +1", tone: 2)); say("سيف أحسن: هجوم +1")
        case .shield: hero.def += 1; fx.append(Fx(at: p, text: "دفاع +1", tone: 2)); say("درع أحسن: دفاع +1")
        case .heart: hero.maxHp += 5; hero.hp += 5; fx.append(Fx(at: p, text: "صحّة +5", tone: 2)); say("قلب: الصحّة القصوى +5")
        case .chest:
            let r = rng.int(0...9)
            if r < 3 { pick(.sword, at: p) } else if r < 6 { pick(.shield, at: p) } else if r < 8 { pick(.heart, at: p) }
            else { hero.potions += 1; hero.bombs += 1; fx.append(Fx(at: p, text: "+دوا وقنبلة", tone: 2)); say("الصندوق بيه دوا وقنبلة") }
        }
    }

    private mutating func hurt(_ id: Int, ranged: Bool) {
        guard let i = mons.firstIndex(where: { $0.id == id }) else { return }
        let k = Bestiary.all[mons[i].kind]
        if rng.chance(15 * hero.perks[8]) { fx.append(Fx(at: hero.pos, text: "تفادي", tone: 2)); return }
        let dmg = max(1, mons[i].atk - (ranged ? 1 : 0) - hero.def + rng.int(-1...1))
        hero.hp -= dmg
        fx.append(Fx(at: hero.pos, text: "-\(dmg)", tone: 1))
        if k.poison && hero.poison == 0 { hero.poison = 3; say("\(k.name) سمّمك") }
        if hero.hp <= 0 { die(k.name); return }
        if hero.perks[5] > 0 && !ranged {
            mons[i].hp -= 2 * hero.perks[5]
            if mons[i].hp <= 0 { kill(i) }
        }
    }

    private mutating func die(_ by: String) {
        hero.hp = 0; over = true
        say("انتهت المغامرة — \(by)")
    }

    private mutating func descend() {
        if floor >= Cave.lastFloor { won = true; over = true; say("طلعت من المغارة حيّ! 🏆"); return }
        floor += 1
        hero.hp = min(hero.maxHp, hero.hp + 3)
        say("نزلت للطابق \(floor)")
        generate()
    }

    private mutating func endTurn() {
        turn += 1
        if hero.poison > 0 && !over {
            hero.poison -= 1; hero.hp -= 1
            fx.append(Fx(at: hero.pos, text: "-1", tone: 1))
            if hero.hp <= 0 { die("السمّ"); return }
        }
        look()
        monstersAct()
        if !over { look() }
    }

    private mutating func monstersAct() {
        let dist = bfs(from: hero.pos)
        for id in mons.map({ $0.id }) {
            guard !over, let i = mons.firstIndex(where: { $0.id == id }) else { continue }
            let k = Bestiary.all[mons[i].kind]
            if !mons[i].awake {
                if lit[mons[i].pos] || dist[mons[i].pos] <= 3 { mons[i].awake = true }
                continue
            }
            for _ in 0..<(k.fast ? 2 : 1) {
                guard !over, let j = mons.firstIndex(where: { $0.id == id }) else { break }
                let p = mons[j].pos
                if adjacent(p, hero.pos) { hurt(id, ranged: false); break }
                if k.ranged > 0 && inLine(p, hero.pos, k.ranged) { hurt(id, ranged: true); break }
                if k.slow && turn % 2 == 1 { break }
                var best = p, bd = dist[p]
                var opts = near(p).filter { tiles[$0] != .wall && $0 != hero.pos && monAt($0) == nil }
                if k.fast && rng.chance(30) && !opts.isEmpty {
                    opts.shuffle(using: &rng); best = opts[0]
                } else {
                    for n in opts where dist[n] < bd { best = n; bd = dist[n] }
                }
                mons[j].pos = best
            }
        }
    }

    private func inLine(_ a: Int, _ b: Int, _ range: Int) -> Bool {
        let W = Cave.W
        let ax = a % W, ay = a / W, bx = b % W, by = b / W
        guard ax == bx || ay == by else { return false }
        let d = abs(ax - bx) + abs(ay - by)
        return d <= range && clear(a, b)
    }

    // MARK: المشي التلقائيّ

    /// أوّل اتّجاه بأقصر طريق معروف للهدف (يتجنّب الوحوش الظاهرة والفخاخ إذا يگدر)
    func step(toward target: Int) -> Int? {
        guard target != hero.pos, target >= 0, target < tiles.count, seen[target], tiles[target] != .wall else { return nil }
        for avoid in [true, false] {
            var d = [Int](repeating: 999, count: tiles.count)
            d[target] = 0
            var q = [target], h = 0
            while h < q.count {
                let p = q[h]; h += 1
                if p == hero.pos { break }
                for n in near(p) where seen[n] && tiles[n] != .wall && d[n] == 999 {
                    if n != hero.pos {
                        if lit[n] && monAt(n) != nil { continue }
                        if avoid && (tiles[n] == .trap || tiles[n] == .shop || tiles[n] == .shrine) { continue }
                    }
                    d[n] = d[p] + 1; q.append(n)
                }
            }
            if d[hero.pos] == 999 { continue }
            let ns = near(hero.pos)
            var best = -1, bd = d[hero.pos]
            for k in 0..<4 where d[ns[k]] < bd { bd = d[ns[k]]; best = k }
            if best >= 0 { return best }
        }
        return nil
    }
}
