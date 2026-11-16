import Foundation

var failures = 0
var passed = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) {
    if ok { passed += 1 } else { failures += 1; print("FAIL: " + msg()) }
}
func near(_ a: Double, _ b: Double, _ eps: Double) -> Bool { abs(a - b) <= eps }

// ── الجغرافيا
let c0 = Coord(41.39, 2.16)
let oneLat = Geo.haversine(Coord(10, 20), Coord(11, 20))
check(near(oneLat, 111_195, 2), "1° latitude ≈ 111.195 km: \(oneLat)")
check(near(Geo.haversine(Coord(0, 0), Coord(0, 1)), 111_195, 2), "1° longitude at equator")
check(near(Geo.haversine(c0, Coord(41.4, 2.17)), Geo.haversine(Coord(41.4, 2.17), c0), 1e-6), "haversine symmetric")
check(Geo.haversine(c0, c0) == 0, "zero distance")
let m345 = Geo.moved(c0, east: 300, north: 400)
check(near(Geo.haversine(c0, m345), 500, 0.6), "moved 300E/400N ⇒ 500 m: \(Geo.haversine(c0, m345))")
check(near(Geo.bearing(c0, Geo.moved(c0, east: 0, north: 500)), 0, 0.01) || near(Geo.bearing(c0, Geo.moved(c0, east: 0, north: 500)), 360, 0.01), "bearing north")
check(near(Geo.bearing(c0, Geo.moved(c0, east: 500, north: 0)), 90, 0.05), "bearing east")
check(near(Geo.bearing(c0, Geo.moved(c0, east: 0, north: -500)), 180, 0.05), "bearing south")

// ── الإسقاط المحليّ
let proj = Projection(origin: c0)
let back = proj.coord(proj.xy(Coord(41.401, 2.149)))
check(near(back.lat, 41.401, 1e-9) && near(back.lon, 2.149, 1e-9), "projection round trip")
let pa = proj.xy(Coord(41.395, 2.165)), pb = proj.xy(Coord(41.405, 2.180))
let hv = Geo.haversine(Coord(41.395, 2.165), Coord(41.405, 2.180))
check(abs(pa.dist(pb) - hv) / hv < 0.003, "projection distance matches haversine: \(pa.dist(pb)) vs \(hv)")
check(proj.xy(c0) == P(0, 0), "origin maps to 0,0")
let east = proj.xy(Geo.moved(c0, east: 250, north: 0))
check(near(east.x, 250, 0.5) && near(east.y, 0, 0.5), "x is east in metres")

// ── المضلّعات
let sq: [P] = [P(0, 0), P(100, 0), P(100, 100), P(0, 100)]
check(near(Geo.polygonArea(sq), 10_000, 1e-6), "square area")
check(near(Geo.polygonArea(sq.reversed()), 10_000, 1e-6), "area independent of winding")
check(Geo.contains(sq, P(50, 50)) && !Geo.contains(sq, P(150, 50)) && !Geo.contains(sq, P(-1, 50)), "point in square")
let ell: [P] = [P(0, 0), P(200, 0), P(200, 100), P(100, 100), P(100, 200), P(0, 200)]
check(Geo.contains(ell, P(50, 150)) && !Geo.contains(ell, P(150, 150)) && Geo.contains(ell, P(150, 50)), "concave L polygon")
check(near(Geo.polygonArea(ell), 30_000, 1e-6), "L area")
check(Geo.polygonArea([P(0, 0), P(1, 1)]) == 0 && !Geo.contains([P(0, 0), P(1, 1)], P(0, 0)), "degenerate polygon")

// ── الشبكة السداسيّة
let grid = HexGrid(proj: proj)
check(near(grid.width, 69.28, 0.01), "cell width ≈ 69 m: \(grid.width)")
check(near(grid.cellArea, 4156.9, 0.2), "cell area: \(grid.cellArea)")
var rtOK = true
for q in -6...6 { for r in -6...6 { let h = Hex(q, r); if grid.hex(at: grid.center(h)) != h { rtOK = false } } }
check(rtOK, "center → hex round trip")
var rng = MRng(42)
var nearestOK = true, withinOK = true
for _ in 0..<3000 {
    let p = P((rng.unit() - 0.5) * 4000, (rng.unit() - 0.5) * 4000)
    let h = grid.hex(at: p)
    let d = grid.center(h).dist(p)
    if d > grid.size + 1e-6 { withinOK = false }
    for n in h.neighbours where grid.center(n).dist(p) < d - 1e-6 { nearestOK = false }
}
check(withinOK, "point within one radius of its cell centre")
check(nearestOK, "assigned cell is the nearest centre")
let h0 = Hex(3, -2)
check(Set(h0.neighbours).count == 6 && h0.neighbours.allSatisfy { $0.distance(h0) == 1 }, "six neighbours at distance 1")
check(h0.neighbours.allSatisfy { near(grid.center($0).dist(grid.center(h0)), grid.width, 1e-6) }, "neighbour centres one width apart")
check(grid.corners(h0).allSatisfy { near($0.dist(grid.center(h0)), grid.size, 1e-9) } && grid.corners(h0).count == 6, "corners at radius")
let shared = grid.corners(h0).filter { c in grid.corners(Hex(4, -2)).contains { $0.dist(c) < 1e-6 } }.count
check(shared == 2, "adjacent cells share an edge (2 corners): \(shared)")
check(Hex(0, 0).distance(Hex(3, -1)) == 3 && Hex(3, -1).distance(Hex(0, 0)) == 3, "hex distance")
check(Hex(2, 5).s == -7 && Hex(2, 5).key == "2,5", "cube s and key")
let ln = grid.line(Hex(0, 0), Hex(5, -3))
check(ln.count == 6 && ln.first == Hex(0, 0) && ln.last == Hex(5, -3), "line length n+1")
check(zip(ln, ln.dropFirst()).allSatisfy { $0.distance($1) == 1 }, "line cells adjacent")
check(grid.line(Hex(1, 1), Hex(1, 1)) == [Hex(1, 1)], "line to self")
var travOK = true
for _ in 0..<300 {
    let a = P((rng.unit() - 0.5) * 3000, (rng.unit() - 0.5) * 3000)
    let b = P(a.x + (rng.unit() - 0.5) * 900, a.y + (rng.unit() - 0.5) * 900)
    let cs = grid.cells(from: a, to: b)
    if cs.first != grid.hex(at: a) || cs.last != grid.hex(at: b) { travOK = false }
    if !zip(cs, cs.dropFirst()).allSatisfy({ $0.distance($1) == 1 }) { travOK = false }
    if cs.count < grid.hex(at: a).distance(grid.hex(at: b)) + 1 { travOK = false }
}
check(travOK, "segment traversal: correct ends, contiguous, no shortcuts")
check(grid.cells(from: P(5, 5), to: P(6, 5)).count == 1, "tiny step stays in one cell")
let lonLat = Geo.moved(c0, east: 1000, north: -700)
check(grid.hex(lonLat) == grid.hex(at: proj.xy(lonLat)), "lat/lon → cell")
check(grid.cornerCoords(h0).count == 6 && near(Geo.haversine(grid.centerCoord(h0), grid.cornerCoords(h0)[0]), 40, 0.1), "corner coords")

// ── تعبئة الدائرة
let big: [P] = [P(0, 0), P(600, 0), P(600, 600), P(0, 600)]
let inside = grid.cellsInside(big)
check(inside.count >= 75 && inside.count <= 100, "600×600 loop fills ≈ 87 cells: \(inside.count)")
check(inside.allSatisfy { Geo.contains(big, grid.center($0)) }, "filled cells are inside")
check(Set(inside).count == inside.count, "no duplicate cells")
let lInside = grid.cellsInside(ell.map { P($0.x * 3, $0.y * 3) })
check(!lInside.contains(grid.hex(at: P(450, 450))) && lInside.contains(grid.hex(at: P(150, 450))), "concave fill skips the notch")
check(grid.cellsInside([P(0, 0), P(10, 0)]).isEmpty, "degenerate fill empty")

// ── كاشف الدوائر
func sample(_ way: [P], step: Double) -> [P] {
    var out: [P] = []
    for i in 1..<way.count {
        let a = way[i - 1], b = way[i]
        let n = max(1, Int(a.dist(b) / step))
        for k in 0..<n { let t = Double(k) / Double(n); out.append(P(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)) }
    }
    out.append(way[way.count - 1])
    return out
}
var det = LoopDetector()
var loopsFound: [[P]] = []
for p in sample([P(0, 0), P(400, 0), P(400, 400), P(0, 400), P(0, 0), P(0, -20)], step: 5) { if let l = det.add(p) { loopsFound.append(l) } }
check(loopsFound.count == 1, "one loop around a square: \(loopsFound.count)")
if let l = loopsFound.first { check(near(Geo.polygonArea(l), 160_000, 16_000), "loop area ≈ 0.16 km²: \(Geo.polygonArea(l))") }
var det2 = LoopDetector()
var outBack = 0
for p in sample([P(0, 0), P(500, 0), P(0, 3)], step: 5) { if det2.add(p) != nil { outBack += 1 } }
check(outBack == 0, "out-and-back on one street is not a loop")
var det3 = LoopDetector()
var gapLoops = 0
let half1 = sample([P(0, 0), P(400, 0), P(400, 400)], step: 5), half2 = sample([P(0, 400), P(0, 0), P(0, -10)], step: 5)
for p in half1 { if det3.add(p) != nil { gapLoops += 1 } }
det3.breakPath()
for p in half2 { if det3.add(p) != nil { gapLoops += 1 } }
check(gapLoops == 0, "no loop across a pause gap")
var det4 = LoopDetector()
var twoLaps = 0
let lapWay = Demo.rect(0, 0, 3, 3, laps: 2)
for p in sample(lapWay, step: 6) { if det4.add(p) != nil { twoLaps += 1 } }
check(twoLaps == 2, "two laps ⇒ two loops: \(twoLaps)")

// ── فلتر GPS
var gf = GPSFilter(maxSpeed: 12)
check(gf.push(GPSFix(t: 0, lat: 41.39, lon: 2.16, alt: 10, acc: 60, vacc: 5)) == nil, "reject poor accuracy")
check(gf.push(GPSFix(t: 0, lat: 41.39, lon: 2.16, alt: 10, acc: -1, vacc: 5)) == nil, "reject invalid accuracy")
check(gf.push(GPSFix(t: 0, lat: 41.39, lon: 2.16, alt: 10, acc: 5, vacc: 5)) != nil && gf.ready, "first good fix seeds")
check(gf.push(GPSFix(t: 0, lat: 41.39, lon: 2.16, alt: 10, acc: 5, vacc: 5)) == nil, "same timestamp ignored")
let spike = Geo.moved(Coord(41.39, 2.16), east: 400, north: 0)
check(gf.push(GPSFix(t: 1, lat: spike.lat, lon: spike.lon, alt: 10, acc: 5, vacc: 5)) == nil, "400 m jump in 1 s rejected")
let ok1 = Geo.moved(Coord(41.39, 2.16), east: 3, north: 0)
check(gf.push(GPSFix(t: 2, lat: ok1.lat, lon: ok1.lon, alt: 10, acc: 5, vacc: 5)) != nil, "normal step accepted after spike")
var reseeded = false
for i in 0..<5 {
    let far = Geo.moved(Coord(41.39, 2.16), east: 5000 + Double(i) * 3, north: 0)
    if let tp = gf.push(GPSFix(t: 3 + Double(i), lat: far.lat, lon: far.lon, alt: 10, acc: 5, vacc: 5)) {
        reseeded = Geo.haversine(tp.coord, far) < 1
    }
}
check(reseeded, "five consistent far fixes ⇒ re-seed (real relocation)")
// التنعيم يقلّل الخطأ على مسار مستقيم
var rawErr = 0.0, filtErr = 0.0
var f2 = GPSFilter(maxSpeed: 7)
var nrng = MRng(7)
for i in 0..<600 {
    let truth = P(Double(i) * 1.4, 0)
    let noisy = P(truth.x + nrng.gauss() * 4, truth.y + nrng.gauss() * 4)
    let c = proj.coord(noisy)
    if let tp = f2.push(GPSFix(t: Double(i), lat: c.lat, lon: c.lon, alt: 0, acc: 5, vacc: 5)), i > 20 {
        rawErr += noisy.dist(truth)
        filtErr += proj.xy(tp.coord).dist(truth)
    }
}
check(filtErr < rawErr * 0.85, "Kalman smoothing reduces position error: \(filtErr / 579) vs \(rawErr / 579)")

// ── الإحصاءات
let prof = (0...175).map { DT(d: Double($0) * 20, t: Double($0) * 5) }    // 4 م/ث لمسافة 3.5 كم
let sp = Stats.splits(prof)
check(sp.count == 3 && sp.allSatisfy { near($0, 250, 1e-6) }, "constant-pace splits: \(sp)")
check(near(Stats.fastest(prof, meters: 1000) ?? 0, 250, 1e-6), "fastest km at constant pace")
check(Stats.fastest(prof, meters: 5000) == nil, "no 5k in 3.5 km")
var vprof: [DT] = []
for i in 0...100 { vprof.append(DT(d: Double(i) * 10, t: Double(i) * 3)) }          // كيلو أوّل 300 ث
for i in 1...100 { vprof.append(DT(d: 1000 + Double(i) * 10, t: 300 + Double(i) * 2.4)) } // كيلو ثاني 240 ث
let vs = Stats.splits(vprof)
check(vs.count == 2 && near(vs[0], 300, 1e-6) && near(vs[1], 240, 1e-6), "varying splits: \(vs)")
check(near(Stats.fastest(vprof, meters: 1000) ?? 0, 240, 1e-6), "fastest km finds the quick one")
check(near(Stats.fastest(vprof, meters: 500) ?? 0, 120, 1e-6), "fastest 500 m")
let el = Stats.elevation([0, 1, 2, 1, 0, 5, 10, 8, 12, 4])
check(near(el.gain, 10, 1e-9) && near(el.loss, 6, 1e-9), "elevation hysteresis: \(el)")
check(Stats.elevation([]).gain == 0, "empty elevation")
check(Stats.paceText(312) == "5:12" && Stats.paceText(59.6) == "1:00" && Stats.paceText(0) == "–:––", "pace text")
check(Stats.durationText(3725) == "1:02:05" && Stats.durationText(65) == "1:05" && Stats.durationText(0) == "0:00", "duration text")
check(near(Stats.pace(seconds: 1500, meters: 5000), 300, 1e-9) && near(Stats.kmh(seconds: 3600, meters: 10000), 10, 1e-9), "pace/kmh")
check(near(Stats.calories(.run, weightKg: 70, seconds: 3600, meters: 10000), 714, 0.5), "running calories ≈ 714")
check(Stats.calories(.walk, weightKg: 70, seconds: 3600, meters: 4500) < Stats.calories(.run, weightKg: 70, seconds: 3600, meters: 10000), "walking burns less")
check(Stats.calories(.cycle, weightKg: 70, seconds: 0, meters: 0) == 0, "no time no calories")
let many = (0..<1000).map { Coord(Double($0), 0) }
let ds = Stats.downsample(many, max: 50)
check(ds.count == 50 && ds.first == many.first && ds.last == many.last, "downsample keeps ends")
check(Stats.downsample(Array(many.prefix(10)), max: 50).count == 10, "short route untouched")

// ── الإقليم
var terr = Territory()
let hx = Hex(1, 2)
check(terr.capture(hx, at: 1000), "first capture is new")
check(!terr.capture(hx, at: 2000), "recapture while fresh is not new")
check(near(terr.freshness(hx, now: 2000 + 7 * 86400), 0.5, 1e-9), "half faded after 7 days")
check(terr.isActive(hx, now: 2000 + 13 * 86400) && !terr.isActive(hx, now: 2000 + 15 * 86400), "expires after 14 days")
check(terr.fading(now: 2000 + 12 * 86400, withinDays: 3) == 1 && terr.fading(now: 2000, withinDays: 3) == 0, "fading soon")
check(terr.capture(hx, at: 2000 + 15 * 86400), "expired cell can be retaken")
check(terr.cells[hx]?.visits == 3 && terr.cells[hx]?.first == 2000 + 15 * 86400, "visits counted, first reset on retake")
terr.capture(Hex(5, 5), at: 0)
check(terr.activeCount(now: 2000 + 15 * 86400) == 1 && terr.everCount == 2, "active vs ever")
check(near(terr.areaKm2(now: 2000 + 15 * 86400, cellArea: grid.cellArea), grid.cellArea / 1e6, 1e-12), "area")
let rebuilt = Territory(records: terr.records)
check(rebuilt.everCount == 2 && rebuilt.cells[hx] == terr.cells[hx], "records round trip")
terr.prune(now: 100 * 86400, olderThanDays: 90)
check(terr.everCount == 1, "prune old cells")
check(terr.active(now: 2000 + 16 * 86400).count == 1, "active list")

// ── المحرّك من البداية للنهاية
var erng = MRng(5)
let way = Demo.rect(0, 0, 6, 4)
let fx = Demo.fixes(way, center: c0, speed: 3, t0: 10_000, rng: &erng)
var t1 = Territory()
var eng = Engine(grid: grid, activity: .run)
var kms: [Int] = [], loopEvents = 0, loopCellsSum = 0
for f in fx {
    let u = eng.push(f, into: &t1)
    if let k = u.km { kms.append(k) }
    if u.loop != nil { loopEvents += 1; loopCellsSum += u.loopCells }
}
let truthLen = Geo.pathLength(way)
check(abs(eng.distance - truthLen) / truthLen < 0.12, "engine distance ≈ route length: \(eng.distance) vs \(truthLen)")
check(eng.loops == 1 && loopEvents == 1, "engine closes one loop: \(eng.loops)")
let fillCount = grid.cellsInside(Array(way.dropLast())).count
check(loopCellsSum > fillCount / 2, "loop captured the inside: \(loopCellsSum) of ~\(fillCount)")
check(eng.newCells == t1.everCount && eng.newCells == eng.touched.count, "all touched cells new on empty map")
check(eng.newCells >= fillCount, "captured ≥ enclosed area: \(eng.newCells) vs \(fillCount)")
check(kms == [1, 2], "km cues: \(kms)")
let sess = eng.session(id: "t", start: fx.first?.t ?? 0, end: fx.last?.t ?? 0, weightKg: 70)
check(sess.splits.count == 2 && sess.splits.allSatisfy { $0 > 250 && $0 < 450 }, "session splits: \(sess.splits)")
check(sess.pace > 250 && sess.pace < 450 && sess.calories > 100, "session pace/calories: \(sess.pace) \(sess.calories)")
check(sess.route.count == 1 && sess.route[0].count <= 500 && sess.route[0].count > 50, "route stored downsampled")
check(sess.best1k != nil && sess.best5k == nil && sess.loops == 1 && sess.biggestLoop > 150_000, "session records")
check(eng.currentPace > 250 && eng.currentPace < 450, "rolling pace: \(eng.currentPace)")
// نفس المسار مرّة ثانية: ما في خلايا جديدة بس تنعشت
var erng2 = MRng(5)
let fx2 = Demo.fixes(way, center: c0, speed: 3, t0: 10_000 + 5 * 86400, rng: &erng2)
var eng2 = Engine(grid: grid, activity: .run)
for f in fx2 { _ = eng2.push(f, into: &t1) }
check(eng2.newCells == 0 && eng2.touched.count == eng.touched.count, "same route again: refresh only")
check(near(t1.freshness(eng.touched[0], now: 10_000 + 5 * 86400 + 4000), 1, 0.01), "revisit refreshes freshness")
// إيقاف مؤقّت: الفجوة ما تنحسب مسافة
var eng3 = Engine(grid: grid, activity: .walk)
var t3 = Territory()
let a1 = Geo.moved(c0, east: 0, north: 0)
for i in 0..<60 { let c = Geo.moved(a1, east: Double(i) * 2.8, north: 0); _ = eng3.push(GPSFix(t: Double(i) * 2, lat: c.lat, lon: c.lon, alt: 0, acc: 4, vacc: 4), into: &t3) }
let dBefore = eng3.distance
eng3.newSegment()
for i in 0..<60 { let c = Geo.moved(a1, east: 2000 + Double(i) * 2.8, north: 0); _ = eng3.push(GPSFix(t: 1000 + Double(i) * 2, lat: c.lat, lon: c.lon, alt: 0, acc: 4, vacc: 4), into: &t3) }
check(eng3.segments.count == 2 && near(eng3.distance, dBefore * 2, 30) && eng3.distance < 400, "pause gap not counted: \(eng3.distance)")
check(eng3.activeT < 300, "paused time excluded: \(eng3.activeT)")
// رجفة بمكانك: ما تزيد المسافة
var eng4 = Engine(grid: grid, activity: .run)
var t4 = Territory()
var jr = MRng(3)
for i in 0..<300 { let c = Geo.moved(c0, east: jr.gauss() * 1.5, north: jr.gauss() * 1.5); _ = eng4.push(GPSFix(t: Double(i), lat: c.lat, lon: c.lon, alt: 0, acc: 5, vacc: 5), into: &t4) }
check(eng4.distance < 60, "standing still barely moves: \(eng4.distance)")

// ── المستويات والأيّام
check(Levels.level(0) == (1, 0, 100) , "level 1 at 0 xp")
check(Levels.level(100) == (2, 0, 160) && Levels.level(259) == (2, 159, 160) && Levels.level(260).level == 3, "level thresholds")
check(Levels.rank(1) == "مستكشف" && Levels.rank(6) == Levels.ranks[1] && Levels.rank(99) == Levels.ranks.last, "ranks")
check(Days.weekday(0) == 4 && Days.weekday(3) == 0 && Days.weekday(-1) == 3, "weekday from epoch (Thu)")
check(Days.weekStart(0, firstWeekday: 1) == -3 && Days.weekStart(3, firstWeekday: 0) == 3 && Days.weekStart(9, firstWeekday: 6) == 9, "week start")
check(Days.hour(23 * 3600 + 5, tz: 0) == 23 && Days.hour(23 * 3600, tz: 3 * 3600) == 2 && Days.hour(3600, tz: -2 * 3600) == 23, "local hour")
check(Days.index(86399, tz: 0) == 0 && Days.index(86400, tz: 0) == 1 && Days.index(0, tz: -3600) == -1, "day index")
let st = Days.streak([10, 11, 12, 5, 6], today: 12)
check(st.current == 3 && st.best == 3, "streak today: \(st)")
check(Days.streak([10, 11, 12], today: 13).current == 3 && Days.streak([10, 11, 12], today: 14).current == 0, "streak yesterday rule")
check(Days.streak([1, 2, 3, 4, 8], today: 30).best == 4 && Days.streak([], today: 3) == (0, 0), "best streak")

// ── السجلّ التجريبيّ: نفس المحرّك + الشارات
let now = 1_800_000_000.0
let hist = Demo.history(now: now, tz: 0)
check(hist.sessions.count == 12, "demo sessions")
check(zip(hist.sessions, hist.sessions.dropFirst()).allSatisfy { $0.start > $1.start }, "newest first")
check(hist.sessions.allSatisfy { $0.end <= now && $0.distance > 500 && $0.loops >= 1 }, "every demo session valid and closes a loop")
let area = hist.territory.areaKm2(now: now, cellArea: grid.cellArea)
check(area > 1 && area < 12, "demo territory area: \(area)")
check(hist.territory.everCount > hist.territory.activeCount(now: now), "some old cells expired")
let hist2 = Demo.history(now: now, tz: 0)
check(hist2.sessions.map { $0.distance } == hist.sessions.map { $0.distance }, "demo deterministic")
let days = Set(hist.sessions.map { Days.index($0.start, tz: 0) })
let streak = Days.streak(days, today: Days.index(now, tz: 0))
check(streak.current == 4, "demo streak: \(streak)")
let earned = Badges.earned(BadgeContext(sessions: hist.sessions, areaKm2: area, everCells: hist.territory.everCount, bestStreak: streak.best, tz: 0))
for b in ["first", "loop", "5k", "10runs", "night", "dawn", "km2", "streak3"] { check(earned.contains(b), "badge \(b) earned") }
check(!earned.contains("streak7") && !earned.contains("half"), "hard badges still locked")
check(Badges.earned(BadgeContext(sessions: [], areaKm2: 0, everCells: 0, bestStreak: 0, tz: 0)).isEmpty, "no badges for nobody")
check(Set(Badges.all.map { $0.id }).count == Badges.all.count && Badges.badge("km2") != nil, "badge ids unique")
let rec = Records.of(hist.sessions)
check(rec.longest == hist.sessions.map { $0.distance }.max() && rec.best1k != nil && rec.fastestKmh > 15, "records: \(rec)")
check(rec.mostCells > 0 && rec.biggestLoop > 0, "records cells/loops")
let xp = Levels.xp(hist.sessions)
check(xp > 500 && Levels.level(xp).level >= 3, "demo xp: \(xp)")
let wk = Week.days(hist.sessions, today: Days.index(now, tz: 0), firstWeekday: 1, tz: 0)
check(wk.count == 7 && wk.reduce(0, +) > 0, "week distances: \(wk)")
// الجولة الحيّة التجريبيّة
var lt = hist.territory
var le = Engine(grid: grid, activity: .run)
for f in Demo.live(center: Demo.center, t0: now - 1500) { _ = le.push(f, into: &lt) }
check(le.loops == 1 && le.distance > 2000, "live demo: \(le.loops) loops, \(le.distance) m")

print("Masar tests: \(passed) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
