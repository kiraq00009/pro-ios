import Foundation

// اختبارات محرّك «دوري» — تنبني وتشتغل على ماك البناء قبل ما ينبني التطبيق

var failures = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { failures += 1; print("FAIL: " + msg()) } }

func ids(_ n: Int) -> [UUID] { (0..<n).map { _ in UUID() } }

/// يلعب كلّ المباريات الجاهزة بنتائج عشوائيّة لحدّ ما تخلص البطولة
func playOut(_ t: inout Tournament, seed: inout UInt64) -> Int {
    func rnd(_ m: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(m)) }
    var steps = 0
    while t.champion == nil && steps < 2000 {
        guard let g = t.games.first(where: { $0.ready && !$0.decided }) else { break }
        let h = rnd(5), a = rnd(5)
        if g.stage.kind == 2 && h == a { let p = rnd(5); Engine.setScore(&t, game: g.id, hg: h, ag: a, hp: p + 1, ap: p) }
        else { Engine.setScore(&t, game: g.id, hg: h, ag: a) }
        steps += 1
    }
    return steps
}

var seed: UInt64 = 42

// ── الدوري: كلّ اثنين يتقابلون بالضبط «legs» مرّة
for n in 2...16 {
    for legs in 1...2 {
        let m = ids(n)
        var t = Engine.make(name: "L", format: .league, legs: legs, members: m)
        check(t.games.count == n * (n - 1) / 2 * legs, "league n=\(n) legs=\(legs) games=\(t.games.count)")
        var meet: [String: Int] = [:]
        for g in t.games { let k = [g.home!.uuidString, g.away!.uuidString].sorted().joined(); meet[k, default: 0] += 1 }
        check(meet.values.allSatisfy { $0 == legs }, "league n=\(n) legs=\(legs) pair counts")
        // ولا لاعب يلعب مرّتين بنفس الجولة
        for r in Set(t.games.map { $0.stage.round }) {
            let ps = t.games.filter { $0.stage.round == r }.flatMap { [$0.home!, $0.away!] }
            check(Set(ps).count == ps.count, "league n=\(n) round \(r) double booking")
        }
        _ = playOut(&t, seed: &seed)
        check(t.champion != nil, "league n=\(n) legs=\(legs) no champion")
        let rows = Engine.standings(t)
        check(rows.count == n, "league rows")
        check(rows.reduce(0) { $0 + $1.gf } == rows.reduce(0) { $0 + $1.ga }, "league goals balance")
        check(rows.reduce(0) { $0 + $1.w } == rows.reduce(0) { $0 + $1.l }, "league wins = losses")
        check(rows.allSatisfy { $0.p == (n - 1) * legs }, "league played count")
        check(zip(rows, rows.dropFirst()).allSatisfy { $0.pts >= $1.pts }, "league sorted")
        check(t.champion == rows.first?.id, "league champion is first")
    }
}

// ── الكأس: كلّ الأعداد توصل لبطل، وعدد المباريات الملعوبة = n - 1
for n in 2...16 {
    let m = ids(n)
    var t = Engine.make(name: "C", format: .cup, legs: 1, members: m)
    let first = t.games.filter { $0.stage.kind == 2 && $0.stage.round == 0 }
    let inFirst = first.flatMap { [$0.home, $0.away] }.compactMap { $0 }
    check(Set(inFirst).count == n && inFirst.count == n, "cup n=\(n) all players placed once")
    check(first.allSatisfy { $0.home != nil || $0.away != nil }, "cup n=\(n) empty pair")
    let steps = playOut(&t, seed: &seed)
    check(t.champion != nil, "cup n=\(n) no champion")
    check(steps == n - 1, "cup n=\(n) played \(steps) expected \(n - 1)")
    check(m.contains(t.champion ?? UUID()), "cup champion is a member")
}

// ── المجموعات + الإقصاء
for n in 6...16 {
    let m = ids(n)
    var t = Engine.make(name: "G", format: .groups, legs: 1, members: m)
    check(t.groups.flatMap { $0 }.count == n && Set(t.groups.flatMap { $0 }).count == n, "groups n=\(n) membership")
    check(t.groups.count == (n >= 12 ? 4 : 2), "groups count")
    let ko0 = t.games.filter { $0.stage.kind == 2 && $0.stage.round == 0 }
    check(ko0.allSatisfy { $0.home == nil && $0.away == nil }, "groups n=\(n) KO filled too early")
    _ = playOut(&t, seed: &seed)
    check(t.champion != nil, "groups n=\(n) no champion")
    let q = t.games.filter { $0.stage.kind == 2 && $0.stage.round == 0 }.flatMap { [$0.home, $0.away] }.compactMap { $0 }
    check(Set(q).count == t.groups.count * 2, "groups n=\(n) qualifiers distinct")
    // المتأهّلون هم فعلًا أوّل اثنين بكلّ مجموعة
    for g in t.groups.indices {
        let top = Engine.standings(t, group: g).prefix(2).map { $0.id }
        check(top.allSatisfy { q.contains($0) }, "groups n=\(n) group \(g) top2 qualified")
    }
}

// ── تعديل نتيجة قديمة بالإقصاء يمسح اللي تبنّى عليها
do {
    let m = ids(4)
    var t = Engine.make(name: "C", format: .cup, legs: 1, members: m, shuffle: false)
    let semis = t.games.filter { $0.stage.round == 0 }
    Engine.setScore(&t, game: semis[0].id, hg: 2, ag: 0)
    Engine.setScore(&t, game: semis[1].id, hg: 1, ag: 0)
    let final = t.games.first { $0.stage.round == 1 }!
    check(final.home == m[0] && final.away == m[2], "final participants")
    Engine.setScore(&t, game: final.id, hg: 3, ag: 1)
    check(t.champion == m[0], "champion m0")
    Engine.setScore(&t, game: semis[0].id, hg: 0, ag: 1)          // انقلبت نتيجة نصف النهائيّ
    let f2 = t.games.first { $0.stage.round == 1 }!
    check(f2.home == m[1] && !f2.played && t.champion == nil, "final reset after semi change")
    // تعادل بالإقصاء يحتاج ترجيح
    Engine.setScore(&t, game: f2.id, hg: 1, ag: 1)
    check(t.champion == nil && t.games.first { $0.id == f2.id }!.needsPens, "draw needs pens")
    Engine.setScore(&t, game: f2.id, hg: 1, ag: 1, hp: 4, ap: 5)
    check(t.champion == m[2], "pens winner")
}

// ── الترتيب: النقاط ثمّ فارق الأهداف ثمّ المواجهة المباشرة
do {
    let m = ids(3)
    var t = Engine.make(name: "L", format: .league, legs: 1, members: m, shuffle: false)
    func game(_ a: UUID, _ b: UUID) -> Game { t.games.first { ($0.home == a && $0.away == b) || ($0.home == b && $0.away == a) }! }
    func set(_ a: UUID, _ ga: Int, _ b: UUID, _ gb: Int) { let g = game(a, b); Engine.setScore(&t, game: g.id, hg: g.home == a ? ga : gb, ag: g.home == a ? gb : ga) }
    set(m[0], 1, m[1], 0); set(m[1], 1, m[2], 0); set(m[2], 1, m[0], 0)        // الكلّ ٣ نقاط وفارق صفر
    let r = Engine.standings(t)
    check(r.allSatisfy { $0.pts == 3 && $0.gd == 0 }, "3-way tie setup")
    check(t.champion != nil, "tie still yields a champion")
}

// ── الإحصائيّات
do {
    let ms = (0..<4).map { Member(name: "P\($0)") }
    var t = Engine.make(name: "L", format: .league, legs: 2, members: ms.map { $0.id })
    _ = playOut(&t, seed: &seed)
    let cs = Engine.careers(ms, [t])
    check(cs.reduce(0) { $0 + $1.titles } == 1, "one title")
    check(cs.reduce(0) { $0 + $1.gf } == cs.reduce(0) { $0 + $1.ga }, "career goals balance")
    check(cs.allSatisfy { $0.p == 6 && $0.w + $0.d + $0.l == 6 }, "career played")
    let h = Engine.h2h(ms[0].id, ms[1].id, [t])
    check(h.aw + h.d + h.bw == 2, "h2h two games")
    // الحفظ والقراءة
    let data = try! JSONEncoder().encode(t)
    let back = try! JSONDecoder().decode(Tournament.self, from: data)
    check(back == t, "codable roundtrip")
}

print(failures == 0 ? "ALL DAWRI TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
