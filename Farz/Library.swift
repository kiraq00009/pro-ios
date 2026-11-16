import SwiftUI
import UIKit
import Photos
import CoreLocation

struct FZDeckRequest: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
    let assets: [FZAsset]
}

struct FZCelebration: Identifiable, Equatable {
    let id = UUID()
    let bytes: Int64
    let count: Int
    let converted: Bool
}

struct FZDevice {
    var total: Int64
    var free: Int64
    var used: Int64 { max(0, total - free) }

    static func read() -> FZDevice {
        if Shot.on { return FZDevice(total: 128_000_000_000, free: 9_400_000_000) }
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let v = try? url.resourceValues(forKeys: keys) else { return FZDevice(total: 0, free: 0) }
        let total = Int64(v.volumeTotalCapacity ?? 0)
        let free = v.volumeAvailableCapacityForImportantUsage ?? 0
        return FZDevice(total: total, free: free)
    }
}

@MainActor
final class FZLibrary: ObservableObject {
    enum Phase: Equatable { case onboarding, denied, main }

    @Published var phase: Phase = .onboarding
    @Published private(set) var assets: [FZAsset] = []
    @Published private(set) var summary: [FZCat: FZClassify.Summary] = [:]
    @Published private(set) var byCat: [FZCat: [FZAsset]] = [:]
    @Published private(set) var groups: [[FZAsset]] = []
    @Published private(set) var cleanable: Int64 = 0
    @Published private(set) var quick: [FZAsset] = []
    @Published private(set) var libraryBytes: Int64 = 0
    @Published private(set) var device = FZDevice(total: 0, free: 0)
    @Published var rules: FZRules = FZRules() { didSet { if rules != oldValue { saveRules(); recompute() } } }
    @Published var ledger: FZLedger = FZLedger() { didSet { saveLedger() } }
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var stage: String = ""
    @Published var scanned = 0
    @Published var total = 0
    @Published var foundBytes: Int64 = 0
    @Published var foundGroups = 0
    @Published var lastScan: Date? = nil
    @Published var demo = false
    @Published var limited = false
    @Published var deck: FZDeckRequest? = nil
    @Published var toast: String? = nil
    @Published var celebration: FZCelebration? = nil
    @Published var working = false

    private var scanner: FZScanner? = nil
    private var toastTask: Task<Void, Never>? = nil
    private var booted = false

    var now: Double { Date().timeIntervalSince1970 }
    var today: Int { FZDay.of(now, offset: TimeZone.current.secondsFromGMT()) }

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "fz_rules"), let r = try? JSONDecoder().decode(FZRules.self, from: data) { rules = r }
        if let data = d.data(forKey: "fz_ledger"), let l = try? JSONDecoder().decode(FZLedger.self, from: data) { ledger = l }
        if Shot.on { setupShot() }
    }

    // MARK: إقلاع

    func boot() {
        if booted { return }
        booted = true
        device = FZDevice.read()
        if Shot.on { return }
        let st = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch st {
        case .authorized, .limited:
            limited = st == .limited
            phase = .main
            if !loadCache() { startScan() } else { validateCache() }
        case .denied, .restricted:
            phase = UserDefaults.standard.bool(forKey: "fz_onboarded") ? .denied : .onboarding
        case .notDetermined:
            phase = .onboarding
        @unknown default:
            phase = .onboarding
        }
    }

    func requestAccess() {
        UserDefaults.standard.set(true, forKey: "fz_onboarded")
        Task { @MainActor in
            let st = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            switch st {
            case .authorized, .limited:
                self.limited = st == .limited
                self.demo = false
                self.phase = .main
                if !self.loadCache() { self.startScan() }
            case .denied, .restricted, .notDetermined:
                self.phase = .denied
            @unknown default:
                self.phase = .denied
            }
        }
    }

    func startDemo() {
        demo = true
        UserDefaults.standard.set(true, forKey: "fz_onboarded")
        phase = .main
        setAssets(FZDemoLib.make(seed: UInt64(Int.random(in: 1...999)), now: now))
        lastScan = Date()
        show("هذه مكتبة تجريبيّة — جرّب كلّ شيء بأمان")
    }

    func exitDemo() {
        demo = false
        setAssets([])
        let st = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if st == .authorized || st == .limited { phase = .main; if !loadCache() { startScan() } }
        else { phase = .denied }
    }

    private func setupShot() {
        demo = true
        phase = .main
        booted = true
        device = FZDevice.read()
        setAssets(FZDemoLib.make(seed: 7, now: now))
        ledger = FZDemoLib.ledger(today: today)
        lastScan = Date().addingTimeInterval(-3 * 3600)
        if Shot.name == "scan" {
            isScanning = true
            progress = 0.64
            stage = "نحلّل الصور ونقارن البصمات…"
            scanned = 3128
            total = 4870
            foundBytes = 6_840_000_000
            foundGroups = 41
        }
    }

    // MARK: الحسابات

    private func setAssets(_ a: [FZAsset]) {
        assets = a
        recompute()
    }

    func recompute() {
        let n = now
        let r = rules
        summary = FZClassify.summary(assets, rules: r, now: n)
        var d: [FZCat: [FZAsset]] = [:]
        for c in FZCat.allCases { d[c] = FZClassify.members(c, assets, rules: r, now: n) }
        byCat = d
        groups = FZClassify.groups(assets)
        cleanable = FZClassify.cleanable(assets, rules: r, now: n)
        quick = FZClassify.quickQueue(assets, rules: r, now: n, limit: 60)
        libraryBytes = assets.reduce(Int64(0)) { $0 + $1.bytes }
    }

    func members(_ c: FZCat) -> [FZAsset] { byCat[c] ?? [] }
    func sum(_ c: FZCat) -> FZClassify.Summary { summary[c] ?? FZClassify.Summary() }
    func asset(_ id: String) -> FZAsset? { assets.first { $0.id == id } }

    // MARK: الفحص

    func startScan() {
        guard !isScanning else { return }
        progress = 0; scanned = 0; total = 0; foundBytes = 0; foundGroups = 0
        stage = "نجهّز الفحص…"
        isScanning = true
        if demo { runDemoScan(); return }
        let sc = FZScanner()
        scanner = sc
        UIApplication.shared.isIdleTimerDisabled = true
        let r = rules
        Task.detached(priority: .userInitiated) {
            let result = sc.run(rules: r) { rep in
                Task { @MainActor in self.apply(rep) }
            }
            await MainActor.run { self.finishScan(result) }
        }
    }

    func cancelScan() {
        scanner?.cancel()
        if demo { isScanning = false }
    }

    private func apply(_ rep: FZScanReport) {
        guard isScanning else { return }
        progress = max(progress, rep.progress)
        stage = rep.stage
        scanned = rep.done
        total = rep.total
        foundBytes = rep.found
        foundGroups = rep.groups
    }

    private func finishScan(_ result: [FZAsset]?) {
        UIApplication.shared.isIdleTimerDisabled = false
        scanner = nil
        isScanning = false
        guard let result else { show("أوقفت الفحص — النتائج السابقة باقية"); return }
        setAssets(result)
        lastScan = Date()
        saveCache()
        Haptic.ok()
        if cleanable > 0 { show("خلص الفحص: تقدر توفّر \(FZFormat.size(cleanable))") }
        else { show("مكتبتك نظيفة — ما لقينا شي يستاهل الحذف") }
    }

    private func runDemoScan() {
        let target = FZDemoLib.make(seed: UInt64(Int.random(in: 1...999)), now: now)
        let stages = ["نقرأ أحجام المكتبة…", "نحلّل الحدّة ونستخرج البصمات…", "نختار أفضل لقطة بكلّ مجموعة…"]
        Task { @MainActor in
            let steps = 60
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: 45_000_000)
                if !self.isScanning { return }
                let f = Double(i) / Double(steps)
                self.progress = f
                self.stage = stages[min(2, Int(f * 3))]
                self.total = target.count
                self.scanned = Int(Double(target.count) * f)
                self.foundBytes = Int64(Double(FZClassify.cleanable(target, rules: self.rules, now: self.now)) * f)
                self.foundGroups = Int(9 * f)
            }
            self.isScanning = false
            self.setAssets(target)
            self.lastScan = Date()
            Haptic.ok()
        }
    }

    // MARK: الحذف (دائمًا عبر نافذة النظام)

    /// يحذف عبر PhotoKit؛ النظام يعرض نافذة تأكيد خاصّة به. يرجّع true إذا وافق المستخدم.
    @discardableResult
    func delete(_ ids: [String]) async -> Bool {
        let unique = Array(Set(ids))
        guard !unique.isEmpty, !working else { return false }
        let freed = unique.compactMap { asset($0)?.bytes }.reduce(Int64(0), +)
        working = true
        defer { working = false }
        if demo {
            try? await Task.sleep(nanoseconds: 350_000_000)
            removeLocally(unique)
            finishClean(bytes: freed, count: unique.count, converted: false)
            return true
        }
        let ok = await FZPhotoOps.delete(unique)
        if ok {
            removeLocally(unique)
            finishClean(bytes: freed, count: unique.count, converted: false)
        } else {
            show("ما انحذف شي — تقدر ترجع تحاول بأيّ وقت")
        }
        return ok
    }

    /// تحويل الصور الحيّة لصور ثابتة: ننشئ نسخة ثابتة ونحذف الأصل (بنافذة النظام)
    @discardableResult
    func convertLive(_ ids: [String]) async -> Bool {
        let list = Array(Set(ids)).prefix(40)
        guard !list.isEmpty, !working else { return false }
        working = true
        defer { working = false }
        let freed = list.compactMap { asset($0)?.pairedBytes }.reduce(Int64(0), +)
        if demo {
            try? await Task.sleep(nanoseconds: 500_000_000)
            for id in list {
                if let i = assets.firstIndex(where: { $0.id == id }) {
                    assets[i].kind = .photo
                    assets[i].bytes -= assets[i].pairedBytes
                    assets[i].pairedBytes = 0
                }
            }
            recompute()
            finishClean(bytes: freed, count: list.count, converted: true)
            return true
        }
        let made: [FZConverted] = await FZPhotoOps.convertLive(Array(list))
        if made.isEmpty {
            show("ما تمّ التحويل — ما تغيّر شي")
            return false
        }
        // الأصول انحذفت وانضافت نسخ ثابتة جديدة: نحدّث القائمة محلّيًّا
        let oldIDs = Set(made.map { $0.oldID })
        let realFreed = assets.filter { oldIDs.contains($0.id) }.reduce(Int64(0)) { $0 + $1.pairedBytes }
        var newAssets = assets.filter { !oldIDs.contains($0.id) }
        for m in made {
            if var a = assets.first(where: { $0.id == m.oldID }) {
                a.id = m.newID
                a.kind = .photo
                a.bytes = max(0, a.bytes - a.pairedBytes)
                a.pairedBytes = 0
                newAssets.append(a)
            }
        }
        setAssets(newAssets.sorted { $0.created < $1.created })
        saveCache()
        finishClean(bytes: realFreed > 0 ? realFreed : freed, count: made.count, converted: true)
        return true
    }


    private func removeLocally(_ ids: [String]) {
        let s = Set(ids)
        var left = assets.filter { !s.contains($0.id) }
        // مجموعة بقى بيها عنصر واحد تنحلّ
        var counts: [Int: Int] = [:]
        for a in left { if let g = a.group { counts[g, default: 0] += 1 } }
        for i in 0..<left.count {
            if let g = left[i].group, (counts[g] ?? 0) < 2 { left[i].group = nil; left[i].isBest = false }
        }
        setAssets(left)
        if !demo { saveCache() }
    }

    private func finishClean(bytes: Int64, count: Int, converted: Bool) {
        if !demo || Shot.on {
            var l = ledger
            l.record(bytes: bytes, count: count, day: today, converted: converted ? count : 0)
            ledger = l
        }
        device = FZDevice.read()
        Haptic.ok()
        celebration = FZCelebration(bytes: bytes, count: count, converted: converted)
    }

    // MARK: المراجعة بالسحب

    func startDeck(_ c: FZCat) {
        let list = Array(members(c).prefix(150))
        guard !list.isEmpty else { show("ما في شي بهذا القسم"); return }
        deck = FZDeckRequest(title: c.title, color: FZ.color(c), assets: list)
    }

    func startQuickDeck() {
        let q = quick
        guard !q.isEmpty else { show("ما في مرشّحات حاليًّا — مكتبتك مرتّبة"); return }
        deck = FZDeckRequest(title: "مراجعة سريعة", color: FZ.mint, assets: q)
    }

    // MARK: رسائل

    func show(_ s: String) {
        toastTask?.cancel()
        toast = s
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if !Task.isCancelled { self.toast = nil }
        }
    }

    func resetLedger() { ledger = FZLedger() }

    // MARK: الحفظ

    private func saveRules() {
        if let d = try? JSONEncoder().encode(rules) { UserDefaults.standard.set(d, forKey: "fz_rules") }
    }

    private func saveLedger() {
        if Shot.on { return }
        if let d = try? JSONEncoder().encode(ledger) { UserDefaults.standard.set(d, forKey: "fz_ledger") }
    }

    private struct Cache: Codable {
        var date: Double
        var assets: [FZAsset]
    }

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return dir.appendingPathComponent("farz_scan.json")
    }

    private func saveCache() {
        if demo || Shot.on { return }
        let c = Cache(date: (lastScan ?? Date()).timeIntervalSince1970, assets: assets)
        let url = cacheURL
        if let d = try? JSONEncoder().encode(c) { try? d.write(to: url, options: .atomic) }
    }

    private func loadCache() -> Bool {
        guard let d = try? Data(contentsOf: cacheURL), let c = try? JSONDecoder().decode(Cache.self, from: d) else { return false }
        setAssets(c.assets)
        lastScan = Date(timeIntervalSince1970: c.date)
        return true
    }

    /// نشيل من النتائج المحفوظة اللي انحذف من مكان ثاني
    private func validateCache() {
        let ids = assets.map { $0.id }
        guard !ids.isEmpty else { return }
        Task.detached(priority: .utility) {
            let found = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            var alive = Set<String>()
            found.enumerateObjects { a, _, _ in alive.insert(a.localIdentifier) }
            let gone = ids.filter { !alive.contains($0) }
            if gone.isEmpty { return }
            await MainActor.run { self.removeLocally(gone) }
        }
    }

    var scanAgeText: String {
        guard let d = lastScan else { return "ما صار فحص بعد" }
        return "آخر فحص " + agoText(d)
    }
}
