import Foundation
import SwiftUI
import UIKit
import CoreLocation
import AVFoundation

enum TState { case idle, running, paused }

struct Flash: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let sub: String
    let icon: String
    let gold: Bool
}

/// التتبّع الحيّ: CoreLocation (ومعه الخلفيّة أثناء الجولة) → المحرّك → الخريطة + الصوت
final class Tracker: NSObject, ObservableObject, CLLocationManagerDelegate, AVSpeechSynthesizerDelegate {
    @Published private(set) var state: TState = .idle
    @Published var activity: Activity = .run
    @Published private(set) var distance: Double = 0
    @Published private(set) var routes: [[CLLocationCoordinate2D]] = []
    @Published private(set) var routeRev = 0
    @Published private(set) var hexRev = 0
    @Published private(set) var mapHexes: [MapHex] = []
    @Published private(set) var newCells = 0
    @Published private(set) var touched = 0
    @Published private(set) var loops = 0
    @Published private(set) var pace: Double = 0
    @Published private(set) var elevGain: Double = 0
    @Published private(set) var gpsAcc: Double = -1
    @Published private(set) var auth: CLAuthorizationStatus = .notDetermined
    @Published var flash: Flash? = nil
    @Published var finished: Session? = nil
    @Published var denied = false
    @Published var tooShort = false

    private let manager = CLLocationManager()
    private let speech = AVSpeechSynthesizer()
    private var engine = Engine(grid: HexGrid(proj: Projection(origin: Demo.center)), activity: .run)
    private var engineReady = false
    private var terr = Territory()
    private var baseHexes: [MapHex] = []
    private var sessionHexes: [MapHex] = []
    private var accum: Double = 0
    private var runStart: Date? = nil
    private var started: Date = Date()
    private var pendingStart = false
    private weak var store: MasarStore?
    private var frozen: Double? = nil
    private var minAlt: Double? = nil
    private var lastAlt: Double? = nil
    private var lastLoopCells = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.pausesLocationUpdatesAutomatically = false
        auth = manager.authorizationStatus
        speech.delegate = self
    }

    var authorized: Bool { auth == .authorizedWhenInUse || auth == .authorizedAlways }
    var isActive: Bool { state != .idle }

    private var canBackground: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains("location") ?? false
    }

    func elapsed(_ now: Date) -> Double {
        if let f = frozen { return f }
        return accum + (runStart.map { now.timeIntervalSince($0) } ?? 0)
    }

    // MARK: الأذونات

    func requestPermission() {
        guard !Shot.on else { return }
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    func requestAlways() {
        guard !Shot.on else { return }
        manager.requestAlwaysAuthorization()
    }

    /// نشغّل GPS حتى نعرض مكانك ودقّة الإشارة قبل ما تبدأ
    func warmUp() {
        guard !Shot.on, authorized, state == .idle else { return }
        manager.startUpdatingLocation()
    }

    func coolDown() {
        guard !Shot.on, state == .idle else { return }
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        auth = manager.authorizationStatus
        if pendingStart {
            pendingStart = false
            if authorized, let s = store { begin(s) } else if auth == .denied || auth == .restricted { denied = true }
        } else if authorized && state == .idle && !Shot.on {
            manager.startUpdatingLocation()
        }
    }

    // MARK: التحكّم بالجولة

    func start(_ store: MasarStore) {
        guard state == .idle, !Shot.on else { return }
        self.store = store
        switch manager.authorizationStatus {
        case .notDetermined:
            pendingStart = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            denied = true
        case .authorizedAlways, .authorizedWhenInUse:
            begin(store)
        @unknown default:
            begin(store)
        }
    }

    private func begin(_ store: MasarStore) {
        terr = store.territory
        baseHexes = store.mapHexes
        sessionHexes = []
        mapHexes = baseHexes
        engineReady = false
        if let o = store.origin { engine = Engine(grid: HexGrid(proj: Projection(origin: o)), activity: activity); engineReady = true }
        distance = 0; newCells = 0; touched = 0; loops = 0; pace = 0; elevGain = 0
        routes = [[]]; routeRev += 1; hexRev += 1
        accum = 0; started = Date(); runStart = Date(); frozen = nil
        minAlt = nil; lastAlt = nil
        state = .running
        if canBackground {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
        UIApplication.shared.isIdleTimerDisabled = store.keepAwake
        Haptic.thud()
        speak("يلّا بدينا. بالتوفيق")
    }

    func pause() {
        guard state == .running else { return }
        if let r = runStart { accum += Date().timeIntervalSince(r) }
        runStart = nil
        state = .paused
        Haptic.tap()
        speak("وقّفنا مؤقّتًا")
    }

    func resume() {
        guard state == .paused else { return }
        runStart = Date()
        state = .running
        if engineReady { engine.newSegment() }
        routes.append([])
        Haptic.tap()
        speak("كمّلنا")
    }

    /// إنهاء الجولة: تنحفظ وتنفتح الخلاصة
    func stop() {
        guard state != .idle, let store = store else { state = .idle; return }
        if let r = runStart { accum += Date().timeIntervalSince(r) }
        runStart = nil
        manager.stopUpdatingLocation()
        if canBackground { manager.allowsBackgroundLocationUpdates = false }
        UIApplication.shared.isIdleTimerDisabled = false
        state = .idle
        guard engineReady, engine.distance >= 50 else {
            tooShort = true
            reset()
            Haptic.bad()
            return
        }
        let s = engine.session(id: UUID().uuidString, start: started.timeIntervalSince1970, end: Date().timeIntervalSince1970,
                               active: accum, weightKg: store.weight)
        store.finish(s, territory: terr)
        reset()
        Haptic.ok()
        speak("خلصت الجولة. \(spokenKm(s.distance)). كسبت \(s.newCells) خليّة")
        finished = s
    }

    func discard() {
        manager.stopUpdatingLocation()
        if canBackground { manager.allowsBackgroundLocationUpdates = false }
        UIApplication.shared.isIdleTimerDisabled = false
        state = .idle
        runStart = nil
        reset()
    }

    private func reset() {
        routes = []; routeRev += 1
        sessionHexes = []; mapHexes = []; hexRev += 1
        distance = 0; newCells = 0; touched = 0; loops = 0; pace = 0; elevGain = 0
        engineReady = false
        frozen = nil
    }

    // MARK: القراءات

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for l in locations { handle(l) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func handle(_ l: CLLocation) {
        gpsAcc = l.horizontalAccuracy
        guard state == .running, let store = store else { return }
        guard abs(l.timestamp.timeIntervalSinceNow) < 20 else { return }
        let c = Coord(l.coordinate.latitude, l.coordinate.longitude)
        if !engineReady {
            guard l.horizontalAccuracy > 0 && l.horizontalAccuracy <= 35 else { return }
            store.ensureOrigin(c)
            engine = Engine(grid: store.grid, activity: activity)
            engineReady = true
        }
        feed(GPSFix(t: l.timestamp.timeIntervalSince1970, lat: c.lat, lon: c.lon, alt: l.altitude,
                    acc: l.horizontalAccuracy, vacc: l.verticalAccuracy))
    }

    private func feed(_ f: GPSFix) {
        let u = engine.push(f, into: &terr)
        guard u.accepted, let p = u.point else { return }
        if routes.isEmpty { routes = [[]] }
        let segCount = engine.segments.count
        if segCount > 0, let last = engine.segments[segCount - 1].last, last == p {
            routes[routes.count - 1].append(p.coord.cl)
            routeRev += 1
        }
        distance = engine.distance
        pace = engine.currentPace
        elevGain = Stats.elevation(engine.segments.flatMap { $0.map { $0.alt } }).gain
        if u.touched > 0 {
            let g = engine.grid
            let fresh = u.newCells
            for h in fresh { sessionHexes.append(MapHex(corners: g.cornerCoords(h).map { $0.cl }, tone: 0)) }
            newCells = engine.newCells
            touched = engine.touched.count
            if !fresh.isEmpty {
                mapHexes = baseHexes + sessionHexes
                hexRev += 1
            }
        }
        if u.loop != nil {
            loops = engine.loops
            lastLoopCells = u.loopCells
            flash = Flash(title: "قفلت دائرة!", sub: "+\(u.loopCells) خليّة صارت إلك", icon: "lasso", gold: true)
            if !Shot.on { Haptic.ok(); speak("قفلت دائرة. كسبت \(u.loopCells) خليّة") }
        }
        if let km = u.km {
            let el = elapsed(Date())
            let avg = Stats.pace(seconds: el, meters: engine.distance)
            if u.loop == nil { flash = Flash(title: "كيلو \(km) ✓", sub: "معدّلك \(Stats.paceText(avg)) لكلّ كم", icon: "flag.checkered", gold: false) }
            if !Shot.on {
                Haptic.thud()
                speak("كيلومتر \(km). الوقت \(spokenTime(el)). معدّل السرعة \(spokenPace(avg)) لكلّ كيلو")
            }
        }
    }

    // MARK: الصوت (عربي)

    func speak(_ s: String) {
        guard !Shot.on, store?.voiceOn ?? true else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
        let u = AVSpeechUtterance(string: s)
        u.voice = AVSpeechSynthesisVoice(language: "ar-SA")
        u.rate = 0.48
        u.preUtteranceDelay = 0.1
        speech.speak(u)
    }

    func testVoice(_ store: MasarStore) {
        self.store = store
        speak("كيلومتر 3. الوقت 16 دقيقة و 40 ثانية. معدّل السرعة 5 دقائق و 33 ثانية لكلّ كيلو")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if !synthesizer.isSpeaking { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }

    private func spokenKm(_ m: Double) -> String {
        let km = m / 1000
        return km < 1 ? "\(Int(m.rounded())) متر" : String(format: "%.1f كيلومتر", km)
    }

    private func spokenTime(_ s: Double) -> String {
        let v = Int(s), h = v / 3600, m = (v % 3600) / 60, sec = v % 60
        if h > 0 { return "\(h) ساعة و \(m) دقيقة" }
        return sec > 0 ? "\(m) دقيقة و \(sec) ثانية" : "\(m) دقيقة"
    }

    private func spokenPace(_ s: Double) -> String {
        guard s.isFinite, s > 0, s < 3600 else { return "غير معروف" }
        let v = Int(s.rounded())
        return "\(v / 60) دقائق و \(v % 60) ثانية"
    }

    // MARK: وضع التصوير

    func loadDemo(_ store: MasarStore) {
        self.store = store
        terr = store.territory
        baseHexes = store.mapHexes
        sessionHexes = []
        engine = Engine(grid: store.grid, activity: .run)
        engineReady = true
        activity = .run
        state = .running
        routes = [[]]
        let t0 = store.now - 1660
        for f in Demo.live(center: store.origin ?? Demo.center, t0: t0) { feed(f) }
        mapHexes = baseHexes + sessionHexes
        hexRev += 1
        frozen = engine.activeT
        gpsAcc = 4
        flash = Flash(title: "قفلت دائرة!", sub: "+\(max(1, lastLoopCells)) خليّة صارت إلك", icon: "lasso", gold: true)
    }
}
