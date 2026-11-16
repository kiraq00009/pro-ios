import SwiftUI
import AVFoundation

struct LiveAlert: Identifiable, Equatable {
    var id: String
    var group: String
    var sound: String
    var conf: Double
    var t: Double
    var clip: String?
}

struct AlertRec: Codable, Identifiable, Equatable {
    var id: String
    var group: String
    var sound: String
    var conf: Double
    var t: Double
    var clip: String?
}

/// القراءات الحيّة (تتحدّث كثير بالثانية — منفصلة حتى ما تعيد رسم كلّ الشاشات)
@MainActor
final class Live: ObservableObject {
    @Published var top: [Hit] = []
    @Published var db: Double = 0
    @Published var trail: [Double] = []
    @Published var exposure = Exposure()
    @Published var pulse: Int = 0        // يزيد مع كلّ نتيجة من المصنّف
}

func nowT() -> Double { Date().timeIntervalSince1970 }
var localTZ: Int { TimeZone.current.secondsFromGMT() }

@MainActor
final class Store: ObservableObject {
    let live = Live()

    @Published var running = false
    @Published var mic: MicState = .unknown
    @Published var problem: String? = nil
    @Published var alert: LiveAlert? = nil
    @Published var heard: [String: Int] = [:]       // أحداث هذي الجلسة
    @Published var listenStart: Double = 0

    @Published var events: [SoundEvent] = []
    @Published var alerts: [AlertRec] = []
    @Published var nights: [SleepSession] = []
    @Published var sleep: SleepSession? = nil

    @Published var watched: Set<String> = ["baby", "door", "smoke", "glass"] { didSet { saveSettings() } }
    @Published var sensitivity: Double = 0.55 { didSet { gate.threshold = Tuning.threshold(sensitivity: sensitivity); saveSettings() } }
    @Published var cooldown: Double = 30 { didSet { gate.cooldown = cooldown; saveSettings() } }
    @Published var calib: Double = 95 { didSet { saveSettings() } }
    @Published var keepAwake: Bool = false { didSet { saveSettings() } }
    @Published var saveClips: Bool = true { didSet { saveSettings() } }
    @Published var autoStart: Bool = true { didSet { saveSettings() } }

    let core = AudioCore()
    var gate = AlertGate(threshold: 0.6, cooldown: 30)
    var tracker = EventTracker()
    var clipGate = ClipThrottle(minGap: 15, maxCount: 200)
    var pendingClips: [String: String] = [:]
    var minuteAcc: [Double] = []
    var minuteStart: Double = 0
    var trailTick: Double = 0
    var expDay: Int = 0
    var lastEventSave: Double = 0
    var lastExpSave: Double = 0
    var hapticTimer: Timer?
    var hapticCount = 0
    var booted = false
    var resumeOnActive = false
    var loadingSettings = false
    var observers: [NSObjectProtocol] = []

    let ud = UserDefaults.standard

    init() {
        loadingSettings = true
        if let w = ud.array(forKey: "sm_watch") as? [String] { watched = Set(w) }
        if ud.object(forKey: "sm_sens") != nil { sensitivity = ud.double(forKey: "sm_sens") }
        if ud.object(forKey: "sm_cool") != nil { cooldown = ud.double(forKey: "sm_cool") }
        if ud.object(forKey: "sm_calib") != nil { calib = ud.double(forKey: "sm_calib") }
        if ud.object(forKey: "sm_awake") != nil { keepAwake = ud.bool(forKey: "sm_awake") }
        if ud.object(forKey: "sm_clips") != nil { saveClips = ud.bool(forKey: "sm_clips") }
        if ud.object(forKey: "sm_auto") != nil { autoStart = ud.bool(forKey: "sm_auto") }
        loadingSettings = false
        gate = AlertGate(threshold: Tuning.threshold(sensitivity: sensitivity), cooldown: cooldown)
        if Shot.on { fillDemo(); booted = true }
    }

    // MARK: التشغيل

    func boot() {
        if booted { return }
        booted = true
        if Shot.on { fillDemo(); return }
        events = Store.load([SoundEvent].self, "events.json") ?? []
        alerts = Store.load([AlertRec].self, "alerts.json") ?? []
        nights = Store.load([SleepSession].self, "nights.json") ?? []
        let today = Stats.dayKey(nowT(), tz: localTZ)
        expDay = ud.integer(forKey: "sm_expday")
        if expDay == today, let d = ud.data(forKey: "sm_exp"), let e = try? JSONDecoder().decode(Exposure.self, from: d) { live.exposure = e } else { expDay = today }
        recoverNight()
        mic = Mic.state
        let nc = NotificationCenter.default
        let o = nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
            let ended = AVAudioSession.InterruptionType(rawValue: raw) == .ended
            Task { @MainActor in self?.interrupted(ended: ended) }
        }
        observers.append(o)
        if autoStart && mic == .granted && ud.bool(forKey: "sm_onboarded") { start() }
    }

    func interrupted(ended: Bool) {
        guard running, ended else { return }
        core.stop()
        do { try core.start() } catch { running = false; problem = "توقّف المايك بسبب مكالمة أو تطبيق ثاني — شغّله من جديد" }
    }

    func scene(_ p: ScenePhase) {
        guard !Shot.on else { return }
        switch p {
        case .background:
            saveAll()
            if running && sleep == nil {
                flushTracker()
                core.stop()
                running = false
                resumeOnActive = true
            }
        case .active:
            if resumeOnActive { resumeOnActive = false; start() }
            mic = Mic.state
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    func toggle() { running ? stop() : start() }

    func start() {
        if Shot.on { running = true; return }
        switch Mic.state {
        case .granted:
            begin()
        case .unknown:
            Mic.request { ok in
                Task { @MainActor in
                    self.mic = ok ? .granted : .denied
                    if ok { self.begin() } else { Haptic.bad() }
                }
            }
        case .denied:
            mic = .denied
            Haptic.bad()
        }
    }

    private func begin() {
        if running { return }
        core.onHits = { [weak self] h in Task { @MainActor in self?.handle(h) } }
        core.onLevel = { [weak self] r, dt in Task { @MainActor in self?.level(r, dt) } }
        do {
            try core.start()
            running = true
            problem = nil
            mic = .granted
            listenStart = nowT()
            heard = [:]
            Haptic.ok()
        } catch {
            running = false
            problem = "ما قدرنا نشغّل المايك (\(error.localizedDescription))"
            Haptic.bad()
        }
    }

    func stop() {
        if sleep != nil { _ = stopSleep() }
        flushTracker()
        core.stop()
        running = false
        withAnimation(.easeOut(duration: 0.3)) { live.top = [] }
        live.db = 0
        saveAll()
        Haptic.thud()
    }

    private func flushTracker() {
        for e in tracker.flush() { record(e) }
    }

    // MARK: النتائج الحيّة

    func handle(_ hits: [Hit]) {
        guard running else { return }
        let t = nowT()
        let clean = Tuning.top(hits, n: 5, minConf: 0.06, ignore: EventTracker.defaultIgnore)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { live.top = clean }
        live.pulse &+= 1

        for gid in watched.sorted() {
            guard let g = Watch.group(id: gid) else { continue }
            let c = Watch.confidence(g, in: hits)
            if c > 0 && gate.feed(gid, conf: c, at: t) { fire(g, hits: hits, conf: c, at: t) }
        }

        let out = tracker.feed(hits, at: t, db: live.db)
        if sleep != nil && saveClips {
            for e in out.started where SleepMath.wantsClip(e.sound) && clipGate.allow(at: t) { capture(e.id) }
        }
        for e in out.closed { record(e) }
    }

    func level(_ rms: Double, _ dt: Double) {
        guard running else { return }
        let l = Level.spl(rms: rms, offset: calib)
        live.db = Level.smooth(live.db, l)
        let t = nowT()
        let day = Stats.dayKey(t, tz: localTZ)
        if day != expDay { live.exposure = Exposure(); expDay = day }
        live.exposure.add(level: l, seconds: dt)
        if t - trailTick >= 0.2 {
            trailTick = t
            live.trail.append(live.db)
            if live.trail.count > 150 { live.trail.removeFirst(live.trail.count - 150) }
        }
        if sleep != nil {
            minuteAcc.append(l)
            if t - minuteStart >= 60 {
                sleep?.levels.append(LevelSample(t: minuteStart, db: Level.leq(minuteAcc)))
                minuteAcc = []
                minuteStart = t
                Store.save(sleep, "active.json")
            }
        }
        if t - lastExpSave > 30 { lastExpSave = t; saveExposure() }
    }

    private func capture(_ eventId: String) {
        let name = "\(eventId).caf"
        pendingClips[eventId] = name
        core.saveClip(to: ClipPlayer.url(name), seconds: 6, delay: 2.5) { _ in }
    }

    func record(_ ev: SoundEvent) {
        var e = ev
        if let c = pendingClips.removeValue(forKey: e.id) { e.clip = c }
        heard[e.sound, default: 0] += 1
        if sleep != nil {
            sleep?.events.append(e)
            return
        }
        events.append(e)
        if events.count > 4000 {
            let drop = events.prefix(events.count - 4000)
            for d in drop { Store.removeClip(d.clip) }
            events.removeFirst(events.count - 4000)
        }
        let t = nowT()
        if t - lastEventSave > 8 { lastEventSave = t; Store.save(events, "events.json") }
    }

    // MARK: التنبيه

    private func fire(_ g: WatchGroup, hits: [Hit], conf: Double, at t: Double) {
        var sound = g.ids.first ?? g.id
        var best = 0.0
        for h in hits where g.ids.contains(h.id) && h.conf > best { best = h.conf; sound = h.id }
        var clip: String? = nil
        if saveClips && !Shot.on {
            let name = "alert-\(Int(t * 1000)).caf"
            clip = name
            core.saveClip(to: ClipPlayer.url(name), seconds: 6, delay: 2) { _ in }
        }
        let id = UUID().uuidString
        alerts.insert(AlertRec(id: id, group: g.id, sound: sound, conf: conf, t: t, clip: clip), at: 0)
        if alerts.count > 200 {
            for a in alerts[200...] { Store.removeClip(a.clip) }
            alerts.removeLast(alerts.count - 200)
        }
        Store.save(alerts, "alerts.json")
        alert = LiveAlert(id: id, group: g.id, sound: sound, conf: conf, t: t, clip: clip)
        buzz()
    }

    func testAlert() {
        guard let g = Watch.group(id: watched.sorted().first ?? "door") ?? Watch.group(id: "door") else { return }
        alert = LiveAlert(id: UUID().uuidString, group: g.id, sound: g.ids.first ?? g.id, conf: 0.93, t: nowT(), clip: nil)
        buzz()
    }

    private func buzz() {
        Haptic.bad()
        hapticTimer?.invalidate()
        hapticCount = 0
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.hapticCount += 1
                if self.alert == nil || self.hapticCount > 6 { self.hapticTimer?.invalidate(); self.hapticTimer = nil; return }
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }

    func dismissAlert() {
        hapticTimer?.invalidate(); hapticTimer = nil
        alert = nil
        Haptic.tap()
    }

    func toggleWatch(_ id: String) {
        if watched.contains(id) { watched.remove(id) } else { watched.insert(id) }
        Haptic.tap()
    }

    // MARK: وضع النوم

    func startSleep() {
        if sleep != nil { return }
        if !running { start() }
        flushTracker()
        let t = nowT()
        tracker = EventTracker(threshold: 0.5, gap: 3)
        sleep = SleepSession(id: UUID().uuidString, start: t, end: t, events: [], levels: [])
        minuteAcc = []
        minuteStart = t
        clipGate = ClipThrottle(minGap: 20, maxCount: 60)
        if keepAwake { UIApplication.shared.isIdleTimerDisabled = true }
        Store.save(sleep, "active.json")
        Haptic.ok()
    }

    @discardableResult
    func stopSleep() -> SleepSession? {
        guard sleep != nil else { return nil }
        flushTracker()
        guard var s = sleep else { return nil }
        if !minuteAcc.isEmpty { s.levels.append(LevelSample(t: minuteStart, db: Level.leq(minuteAcc))) }
        minuteAcc = []
        s.end = nowT()
        sleep = nil
        tracker = EventTracker()
        clipGate = ClipThrottle(minGap: 15, maxCount: 200)
        nights.insert(s, at: 0)
        if nights.count > 60 {
            for n in nights[60...] { for e in n.events { Store.removeClip(e.clip) } }
            nights.removeLast(nights.count - 60)
        }
        Store.save(nights, "nights.json")
        Store.removeFile("active.json")
        UIApplication.shared.isIdleTimerDisabled = false
        Haptic.ok()
        return s
    }

    /// إذا التطبيق انسدّ بنصّ الليل، نحفظ الليلة اللي انسجلت
    private func recoverNight() {
        guard var s = Store.load(SleepSession.self, "active.json") else { return }
        let lastLevel: Double = s.levels.last.map { $0.t + 60 } ?? s.start
        let lastEvent: Double = s.events.last?.end ?? s.start
        s.end = max(s.start, max(lastLevel, lastEvent))
        if s.duration > 120 { nights.insert(s, at: 0); Store.save(nights, "nights.json") }
        Store.removeFile("active.json")
    }

    func deleteNight(_ id: String) {
        guard let i = nights.firstIndex(where: { $0.id == id }) else { return }
        for e in nights[i].events { Store.removeClip(e.clip) }
        nights.remove(at: i)
        Store.save(nights, "nights.json")
    }

    func clearHistory() {
        for e in events { Store.removeClip(e.clip) }
        for a in alerts { Store.removeClip(a.clip) }
        events = []
        alerts = []
        heard = [:]
        Store.save(events, "events.json")
        Store.save(alerts, "alerts.json")
    }

    func clearAll() {
        clearHistory()
        for n in nights { for e in n.events { Store.removeClip(e.clip) } }
        nights = []
        Store.save(nights, "nights.json")
        live.exposure = Exposure()
        saveExposure()
    }

    // MARK: الحفظ

    func saveSettings() {
        if loadingSettings || Shot.on { return }
        ud.set(Array(watched).sorted(), forKey: "sm_watch")
        ud.set(sensitivity, forKey: "sm_sens")
        ud.set(cooldown, forKey: "sm_cool")
        ud.set(calib, forKey: "sm_calib")
        ud.set(keepAwake, forKey: "sm_awake")
        ud.set(saveClips, forKey: "sm_clips")
        ud.set(autoStart, forKey: "sm_auto")
    }

    func saveExposure() {
        if Shot.on { return }
        if let d = try? JSONEncoder().encode(live.exposure) { ud.set(d, forKey: "sm_exp") }
        ud.set(expDay, forKey: "sm_expday")
    }

    func saveAll() {
        if Shot.on { return }
        Store.save(events, "events.json")
        Store.save(alerts, "alerts.json")
        Store.save(nights, "nights.json")
        if sleep != nil { Store.save(sleep, "active.json") }
        saveExposure()
    }

    static func docURL(_ name: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }

    static func save<T: Encodable>(_ v: T, _ name: String) {
        if Shot.on { return }
        if let d = try? JSONEncoder().encode(v) { try? d.write(to: docURL(name), options: .atomic) }
    }

    static func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let d = try? Data(contentsOf: docURL(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: d)
    }

    static func removeFile(_ name: String) {
        try? FileManager.default.removeItem(at: docURL(name))
    }

    static func removeClip(_ name: String?) {
        guard let n = name else { return }
        try? FileManager.default.removeItem(at: ClipPlayer.url(n))
    }

    // MARK: إحصاءات جاهزة

    var todayEvents: [SoundEvent] {
        let s = Stats.dayStart(nowT(), tz: localTZ)
        return Stats.within(events, from: s, to: s + 86400)
    }
}
