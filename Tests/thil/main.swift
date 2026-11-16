import Foundation

var failures = 0
var checks = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { checks += 1; if !ok { failures += 1; print("FAIL: " + msg()) } }
func near(_ a: Double, _ b: Double, _ eps: Double = 1e-6) -> Bool { abs(a - b) <= eps }

// ── الاحتواء والتعبئة
let box = TRect(0, 0, 400, 400)
let f1 = Fit.fit(TSize(200, 100), in: box)
check(near(f1.w, 400) && near(f1.h, 200) && near(f1.y, 100) && near(f1.x, 0), "fit wide: \(f1)")
let f2 = Fit.fill(TSize(200, 100), in: box)
check(near(f2.w, 800) && near(f2.h, 400) && near(f2.x, -200) && near(f2.y, 0), "fill wide: \(f2)")
let f3 = Fit.fit(TSize(9, 16), in: TRect(10, 20, 300, 300))
check(near(f3.h, 300) && near(f3.w, 168.75) && near(f3.midX, 160) && near(f3.y, 20), "fit tall offset: \(f3)")
check(Fit.fit(TSize(0, 10), in: box).w == 0, "fit zero content")
check(near(Fit.fill(TSize(1, 1), in: TRect(0, 0, 100, 50)).w, 100), "fill square in wide")
let nrm = Fit.normalized(TP(150, 250), in: TRect(100, 200, 100, 100))
check(nrm != nil && near(nrm?.x ?? -1, 0.5) && near(nrm?.y ?? -1, 0.5), "normalized center")
check(Fit.normalized(TP(50, 250), in: TRect(100, 200, 100, 100)) == nil, "normalized outside")

// ── حدود القناع
var alpha = [UInt8](repeating: 0, count: 10 * 8)
for y in 2...5 { for x in 3...7 { alpha[y * 10 + x] = 200 } }
alpha[0] = 5                                         // تحت العتبة ⇒ ينهمل
let ab = Fit.alphaBounds(alpha, width: 10, height: 8)
check(ab == TRect(3, 2, 5, 4), "alpha bounds: \(String(describing: ab))")
check(Fit.alphaBounds([UInt8](repeating: 0, count: 16), width: 4, height: 4) == nil, "empty mask")
check(Fit.alphaBounds([1, 2], width: 4, height: 4) == nil, "short buffer guarded")
let pd = Fit.padded(TRect(3, 2, 5, 4), frac: 0.2, bounds: TSize(10, 8))
check(pd == TRect(2, 1, 7, 6), "padded within bounds: \(pd)")
let pd2 = Fit.padded(TRect(0, 0, 10, 8), frac: 0.5, bounds: TSize(10, 8))
check(pd2 == TRect(0, 0, 10, 8), "padding clamped")
check(Fit.scaled(TRect(1, 2, 3, 4), by: 2) == TRect(2, 4, 6, 8), "scale rect")

// ── نسبة الحجم المناسبة
check(near(Fit.scaleToFit(hOverW: 1, maxW: 0.8, maxH: 0.8, canvasRatio: 1), 0.8), "fit square")
// طويل بلوحة ستوري: الارتفاع نسبة = s*1.5*0.5625
let sTall = Fit.scaleToFit(hOverW: 1.5, maxW: 0.9, maxH: 0.6, canvasRatio: 9.0 / 16.0)
check(near(sTall, 0.6 / (1.5 * 0.5625)) && sTall < 0.9, "fit tall in story: \(sTall)")
check(near(Fit.scaleToFit(hOverW: 0.2, maxW: 0.7, maxH: 0.9, canvasRatio: 1), 0.7), "wide limited by width")

// ── الألوان
check(RGBA(1, 0.5, 0).hex == "#FF8000", "hex: \(RGBA(1, 0.5, 0).hex)")
let hx = RGBA(hex: "#3366CC")
check(hx != nil && near(hx?.g ?? 0, 0.4, 0.002) && near(hx?.b ?? 0, 0.8, 0.002), "parse hex")
check(RGBA(hex: "zz") == nil && RGBA(hex: "#12345") == nil, "bad hex")
check(RGBA.black.mix(.white, 0.5) == RGBA(0.5, 0.5, 0.5, 1), "mix")
check(RGBA.white.luma > 0.99 && RGBA.black.luma < 0.01, "luma")

// ── المقاسات
check(Aspect.story.pixelSize(width: 1080) == TSize(1080, 1920), "story 1080x1920")
check(Aspect.portrait.pixelSize(width: 1080) == TSize(1080, 1350), "portrait 1080x1350")
check(Aspect.square.pixelSize(width: 2048) == TSize(2048, 2048), "square")
check(Aspect.landscape.pixelSize(width: 1920) == TSize(1920, 1080), "landscape")
check(Set(Aspect.allCases.map { $0.title }).count == 4 && Set(Aspect.allCases.map { $0.label }).count == 4, "aspect titles unique")

// ── التحويل والدوران واللمس
let canvas = TSize(1000, 1000)
var xf = XForm()
xf.scale = 0.4                                        // 400 عرض
check(xf.box(hOverW: 0.5, canvas: canvas) == TSize(400, 200), "box size")
check(xf.contains(TP(690, 500), hOverW: 0.5, canvas: canvas), "inside right edge")
check(!xf.contains(TP(500, 650), hOverW: 0.5, canvas: canvas), "outside below (unrotated)")
var rx = xf
rx.rot = Double.pi / 2                                // بعد ٩٠° الصندوق صار ٢٠٠×٤٠٠
check(rx.contains(TP(500, 650), hOverW: 0.5, canvas: canvas), "rotated now inside below")
check(!rx.contains(TP(690, 500), hOverW: 0.5, canvas: canvas), "rotated now outside right")
check(xf.contains(TP(705, 500), hOverW: 0.5, canvas: canvas, slop: 10), "slop widens hit")
let cs = rx.corners(hOverW: 0.5, canvas: canvas)
check(cs.count == 4 && near(cs[0].x, 600) && near(cs[0].y, 300), "rotated corner: \(cs[0])")
let p90 = TP(1, 0).rotated(Double.pi / 2)
check(near(p90.x, 0) && near(p90.y, 1), "rotation is clockwise on y-down screen")

let mv = xf.moved(0.1, -0.2)
check(near(mv.cx, 0.6) && near(mv.cy, 0.3), "moved")
check(near(xf.moved(5, -5).cx, 1.25) && near(xf.moved(5, -5).cy, -0.25), "move clamped")
check(near(xf.scaled(2).scale, 0.8) && near(xf.scaled(100).scale, XForm.maxScale) && near(xf.scaled(0.001).scale, XForm.minScale), "scale clamp")
check(near(xf.scaled(-3).scale, 0.4), "negative factor ignored")
check(xf.rotated(0.03).rot == 0, "small rotation snaps to 0")
check(near(xf.rotated(1.55).rot, Double.pi / 2), "snap to 90")
check(near(xf.rotated(0.5).rot, 0.5), "free rotation")
check(near(XForm.norm(4.0), 4.0 - 2 * Double.pi, 1e-9), "norm 4 wraps negative")
check(near(XForm.norm(-Double.pi), Double.pi), "norm −π → π")
check(near(XForm.norm(-0.5), -0.5) && near(XForm.norm(2 * Double.pi + 0.25), 0.25), "norm keeps small")
check(near(XForm.snapAngle(-1.56, 0.05), -Double.pi / 2), "snap −90")
var nearC = XForm(); nearC.cx = 0.509; nearC.cy = 0.7
let sn = nearC.snapped()
check(sn.1 && !sn.2 && near(sn.0.cx, 0.5) && near(sn.0.cy, 0.7), "center snapping")

// ── النصّ
let ts = TextSpec(text: "سطر\nسطر ثاني", size: 0.1)
check(ts.lines == 2, "two lines")
check(near(ts.hOverW(scale: 0.8), (2 * 1.32 + 0.25) * 0.1 / 0.8), "text box ratio")
check(TextSpec(text: "").lines == 1, "empty text 1 line")
var pillT = ts; pillT.pill = true
check(pillT.hOverW(scale: 0.8) > ts.hOverW(scale: 0.8), "pill adds padding")
var tl = Layer.text(id: "t", "مرحبا")
let h0 = tl.hOverW
tl.setText { $0.size *= 2 }
check(near(tl.hOverW, h0 * 2), "setText refits height: \(tl.hOverW) vs \(h0)")
tl.setText { $0.text = "ا\nب\nج" }
check(tl.hOverW > h0 * 2 && tl.isText && tl.imageID == nil, "more lines taller")
var notText = Layer.cutout(id: "c", image: "img", hOverW: 1.2)
notText.setText { $0.text = "x" }
check(notText.textSpec == nil && near(notText.hOverW, 1.2) && notText.imageID == "img", "setText ignores cutouts")

// ── المشروع: ترتيب الطبقات واللمس
var pj = Project(id: "p1", name: "تجربة", now: 100, aspect: .square)
var a = Layer.cutout(id: "a", image: "ia", hOverW: 1); a.xf.scale = 0.5
var b = Layer.cutout(id: "b", image: "ib", hOverW: 1); b.xf.scale = 0.3
var c = Layer.text(id: "c", "نصّ"); c.xf.cy = 0.1
pj.add(a); pj.add(b); pj.add(c)
check(pj.layers.map { $0.id } == ["a", "b", "c"], "add order")
check(pj.hitTest(TP(500, 500), canvas: canvas) == "b", "top cutout hit first")
check(pj.hitTest(TP(700, 500), canvas: canvas) == "a", "lower layer hit outside top")
check(pj.hitTest(TP(30, 950), canvas: canvas) == nil, "miss")
pj.layers[1].hidden = true
check(pj.hitTest(TP(500, 500), canvas: canvas) == "a", "hidden skipped")
pj.layers[1].hidden = false; pj.layers[1].locked = true
check(pj.hitTest(TP(500, 500), canvas: canvas) == "a", "locked skipped")
pj.layers[1].locked = false
check(pj.hitTest(TP(500, 100), canvas: canvas) == "c", "text hit")
check(pj.moveUp("a") && pj.layers.map { $0.id } == ["b", "a", "c"], "move up")
check(!pj.moveUp("c"), "top can't move up")
check(pj.moveDown("c") && pj.layers.map { $0.id } == ["b", "c", "a"], "move down")
check(!pj.moveDown("b") && !pj.moveDown("zzz"), "bottom can't move down")
pj.toFront("b"); check(pj.layers.map { $0.id } == ["c", "a", "b"], "to front")
pj.toBack("b"); check(pj.layers.map { $0.id } == ["b", "c", "a"], "to back")
let dup = pj.duplicate("a", newID: "a2")
check(dup?.id == "a2" && pj.layers.count == 4 && pj.layers[3].id == "a2" && near(pj.layers[3].xf.cx, 0.54), "duplicate above with offset")
check(pj.duplicate("nope", newID: "x") == nil, "duplicate missing")
pj.remove("a2"); check(pj.layers.count == 3 && pj.index(of: "a2") == nil, "remove")
check(pj.cutoutCount == 2, "cutout count")
pj.bkg = .blurPhoto("src", 0.05); pj.source = "orig"
check(pj.imageIDs == ["ia", "ib", "src", "orig"], "image ids: \(pj.imageIDs)")
check(pj.cutouts.map { $0.image } == ["ib", "ia"], "cutouts in stack order")
check(Bkg.photo("q").photoID == "q" && Bkg.clear.photoID == nil && Bkg.clear.isClear && !Bkg.solid(.white).isClear, "bkg helpers")
let gp = Bkg.gradientPoints(90)
check(near(gp.0.x, 0.5) && near(gp.0.y, 0) && near(gp.1.y, 1), "gradient 90° is top→bottom")
let g0 = Bkg.gradientPoints(0)
check(near(g0.0.x, 0) && near(g0.1.x, 1) && near(g0.0.y, 0.5), "gradient 0° is left→right")

// ── التراجع والإعادة
var h = History<Int>(limit: 3)
check(!h.canUndo && !h.canRedo && h.undo(5) == nil, "empty history")
var state = 0
for v in 1...5 { h.record(state); state = v }
check(h.past == [2, 3, 4], "limit keeps last 3: \(h.past)")
if let u = h.undo(state) { state = u }
check(state == 4 && h.canRedo && h.future == [5], "undo")
if let u = h.undo(state) { state = u }
check(state == 3, "undo twice")
if let r = h.redo(state) { state = r }
check(state == 4 && h.future == [5], "redo")
h.record(state); state = 9
check(!h.canRedo && h.past.last == 4, "new edit clears redo")
h.record(4)
check(h.past.filter { $0 == 4 }.count == 1, "duplicate state not pushed twice")
h.reset(); check(!h.canUndo && !h.canRedo, "reset")
var hp = History<Project>()
var cur = pj
hp.record(cur); cur.layers.removeAll()
hp.record(cur); cur.aspect = .story
if let u = hp.undo(cur) { cur = u }
check(cur.layers.isEmpty && cur.aspect == .square, "project undo step 1")
if let u = hp.undo(cur) { cur = u }
check(cur.layers.count == 3, "project undo step 2")
if let r = hp.redo(cur) { cur = r }
if let r = hp.redo(cur) { cur = r }
check(cur.aspect == .story && cur.layers.isEmpty, "project redo all")

// ── شبكة الملصقات
check(Templates.gridSlots(0).isEmpty && Templates.gridSlots(1) == [TP(0.5, 0.5)], "grid 0/1")
let g2 = Templates.gridSlots(2)
check(g2.count == 2 && near(g2[0].x, 0.29) && near(g2[1].x, 0.71) && near(g2[0].y, 0.5), "grid 2: \(g2)")
let g3 = Templates.gridSlots(3)
check(g3.count == 3 && near(g3[2].x, 0.5) && near(g3[2].y, 0.71) && near(g3[0].y, 0.29), "grid 3 centers last row: \(g3)")
let g5 = Templates.gridSlots(5)
check(g5.count == 5 && g5.allSatisfy { $0.x > 0 && $0.x < 1 && $0.y > 0 && $0.y < 1 }, "grid 5 inside")
check(near(g5[3].x + g5[4].x, 1.0), "grid 5 last row symmetric")
for n in 1...9 { check(Set(Templates.gridSlots(n).map { "\($0.x),\($0.y)" }).count == n, "grid \(n) no overlaps") }

// ── القوالب
check(Set(Templates.all.map { $0.id }).count == Templates.all.count && Templates.all.count >= 6, "template ids unique")
check(Templates.find("poster")?.aspect == .story && Templates.find("nope") == nil, "find template")
var counter = 0
let gen: () -> String = { counter += 1; return "L\(counter)" }
let cutA = CutRef("imgA", 1.5), cutB = CutRef("imgB", 0.8), cutC = CutRef("imgC", 1.2)
for t in Templates.all {
    counter = 0
    let p = Templates.build(t, cuts: [cutA, cutB, cutC], source: "orig", id: "P", name: "ت", now: 50, newID: gen)
    check(p.aspect == t.aspect && p.template == t.id && p.id == "P" && p.source == "orig", "\(t.id) basics")
    check(p.cutoutCount == min(3, t.maxCuts), "\(t.id) uses up to maxCuts: \(p.cutoutCount)")
    check(Set(p.layers.map { $0.id }).count == p.layers.count, "\(t.id) unique layer ids")
    let cv = p.canvas(width: 1000)
    for l in p.layers where !l.isText {
        let hFrac = l.xf.scale * l.hOverW * p.aspect.ratio
        check(l.xf.scale <= 0.951 && hFrac <= 0.801, "\(t.id) cutout fits: w \(l.xf.scale) h \(hFrac)")
        check(l.xf.cy - hFrac / 2 >= -0.001 && l.xf.cy + hFrac / 2 <= 1.001, "\(t.id) cutout inside vertically")
        let ctr = l.xf.center(cv)
        check(p.hitTest(ctr, canvas: cv) != nil, "\(t.id) cutout is tappable")
    }
    for l in p.layers where l.isText { check(l.hOverW > 0 && l.xf.cy > 0 && l.xf.cy < 1, "\(t.id) text placed") }
}
let product = Templates.build(Templates.find("product")!, cuts: [cutA], source: nil, id: "Q", name: "م", now: 1, newID: gen)
if case .floor(_, _, let hz) = product.bkg {
    let l = product.layers[0]
    let bottom = l.xf.cy + l.xf.scale * l.hOverW / 2
    check(near(bottom, 0.76) && hz < bottom, "product stands on the floor: \(bottom)")
    check(l.fx.reflect, "product reflection")
} else { check(false, "product uses floor") }
let stick = Templates.build(Templates.find("sticker")!, cuts: [cutA, cutB, cutC, cutA], source: nil, id: "S", name: "م", now: 1, newID: gen)
check(stick.bkg.isClear && stick.layers.allSatisfy { $0.fx.stroke > 0.03 }, "sticker clear + stroke")
check(stick.layers.count == 4 && stick.layers[0].xf.rot != stick.layers[1].xf.rot, "sticker playful tilt")
let dreamNo = Templates.build(Templates.find("dream")!, cuts: [cutA], source: nil, id: "D", name: "م", now: 1, newID: gen)
if case .gradient = dreamNo.bkg { check(true, "") } else { check(false, "dream without source falls back to gradient") }
let dreamYes = Templates.build(Templates.find("dream")!, cuts: [cutA], source: "orig", id: "D", name: "م", now: 1, newID: gen)
check(dreamYes.bkg == .blurPhoto("orig", 0.05), "dream blurs the original")
let popP = Templates.build(Templates.find("pop")!, cuts: [cutA], source: nil, id: "M", name: "م", now: 1, newID: gen)
check(popP.layers.first?.isText == true && popP.layers[1].imageID == "imgA", "pop: big word behind the subject")
let emptyBuild = Templates.build(Templates.find("poster")!, cuts: [], source: nil, id: "E", name: "م", now: 1, newID: gen)
check(emptyBuild.cutoutCount == 0 && emptyBuild.layers.count == 2, "template with no cuts still builds")
var orig = Templates.build(Templates.find("clean")!, cuts: [cutA, cutB], source: "orig", id: "R", name: "اسمي", now: 10, newID: gen)
orig.layers.append(Layer.cutout(id: "extra", image: "imgB", hOverW: 0.8))
let re = Templates.restyle(orig, with: Templates.find("collage")!, now: 99, newID: gen)
check(re.id == "R" && re.name == "اسمي" && re.created == 10 && re.template == "collage", "restyle keeps identity")
check(re.cutoutCount == 2 && re.cutouts.map { $0.image } == ["imgA", "imgB"], "restyle carries cutouts: \(re.cutouts.map { $0.image })")

// ── الحفظ (ملفّات حقيقيّة بمجلّد مؤقّت)
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("thil-test-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
try? FileManager.default.removeItem(at: tmp)
let store = ProjectStore(root: tmp)
check(FileManager.default.fileExists(atPath: store.imagesDir.path), "dirs created")
check(store.all().isEmpty, "empty store")
var s1 = Templates.build(Templates.find("poster")!, cuts: [cutA], source: "orig", id: "s1", name: "أوّل", now: 10, newID: gen)
s1.modified = 10
var s2 = Templates.build(Templates.find("sticker")!, cuts: [cutB, cutC], source: nil, id: "s2", name: "ثاني", now: 20, newID: gen)
s2.modified = 20
do { try store.save(s1); try store.save(s2) } catch { check(false, "save threw \(error)") }
let loaded = store.load("s1")
check(loaded == s1, "roundtrip equal")
check(store.all().map { $0.id } == ["s2", "s1"], "sorted newest first")
let dataEnc = (try? ProjectStore.encode(s2)) ?? Data()
check(ProjectStore.decode(dataEnc) == s2, "encode/decode")
check(ProjectStore.decode(Data("{bad".utf8)) == nil, "bad json")
for id in ["imgA", "imgB", "imgC", "orig", "junk1", "junk2"] { try? store.saveImage(Data([1, 2, 3]), id: id) }
check(store.storedImageIDs().count == 6 && store.imageData("imgA") == Data([1, 2, 3]), "images stored")
let removed = store.cleanOrphans()
check(removed == 2 && !store.storedImageIDs().contains("junk1") && store.storedImageIDs().contains("orig"), "orphans cleaned: \(removed)")
check(store.cleanOrphans(keep: ["imgA"]) == 0, "nothing more to clean")
let cp = try? store.duplicate(s1, newID: "s3", now: 30)
check(cp?.id == "s3" && store.all().first?.id == "s3" && store.all().count == 3, "duplicate saved on top")
try? store.rename("s3", to: "  جديد  ", now: 40)
check(store.load("s3")?.name == "جديد" && store.load("s3")?.modified == 40, "rename trims")
try? store.rename("s3", to: "   ", now: 50)
check(store.load("s3")?.name == "جديد", "blank rename ignored")
store.delete("s3")
check(store.load("s3") == nil && store.all().count == 2, "delete")
store.deleteAll()
check(store.all().isEmpty && store.storedImageIDs().isEmpty && FileManager.default.fileExists(atPath: store.projectsDir.path), "delete all keeps dirs")
try? FileManager.default.removeItem(at: tmp)

check(ProjectStore.nextName([]) == "تصميم 1", "first name")
check(ProjectStore.nextName(["تصميم 2"]) == "تصميم 3", "skip taken name")
var st = Stats()
st.noteExport(layers: 3, stickers: 2); st.noteExport(layers: 1, stickers: 0)
check(st.exports == 2 && st.stickers == 2 && st.bestLayers == 3, "stats")

print("thil: \(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
