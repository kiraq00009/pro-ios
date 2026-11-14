import SwiftUI
import AVFoundation
import Speech

enum TJ {
    static let bg = Color(red: 0.03, green: 0.06, blue: 0.08)
    static let s1 = Color(red: 0.06, green: 0.11, blue: 0.14)
    static let s2 = Color(red: 0.09, green: 0.16, blue: 0.20)
    static let s3 = Color(red: 0.13, green: 0.22, blue: 0.27)
    static let teal = Color(red: 0.16, green: 0.84, blue: 0.80)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.36)
    static let rose = Color(red: 1.0, green: 0.45, blue: 0.52)
    static let tx2 = Color(white: 1, opacity: 0.74), tx3 = Color(white: 1, opacity: 0.45)
    static func side(_ mine: Bool) -> Color { mine ? teal : gold }
}

@MainActor
final class Store: ObservableObject {
    @Published var a: Lang = .ar { didSet { save() } }
    @Published var b: Lang = .fa { didSet { save() } }
    @Published var turns: [Turn] = []
    @Published var rates = Rates() { didSet { save() } }
    @Published var autoSpeak = true { didSet { save() } }
    @Published var male = false { didSet { save() } }
    @Published var busy: Bool? = nil          // nil = فاضي، true = أنا، false = الطرف الثاني
    @Published var status: String = ""
    @Published var error: String?
    @Published var online: Bool? = nil

    let rec = Recorder()
    let voice = Voice()
    private let ud = UserDefaults.standard

    init() {
        if Shot.on { demo(); return }
        if let s = ud.string(forKey: "tj_a"), let l = Lang(rawValue: s) { a = l }
        if let s = ud.string(forKey: "tj_b"), let l = Lang(rawValue: s) { b = l }
        if let d = ud.data(forKey: "tj_turns"), let v = try? JSONDecoder().decode([Turn].self, from: d) { turns = v }
        if let d = ud.data(forKey: "tj_rates"), let v = try? JSONDecoder().decode(Rates.self, from: d) { rates = v }
        if ud.object(forKey: "tj_auto") != nil { autoSpeak = ud.bool(forKey: "tj_auto") }
        male = ud.bool(forKey: "tj_male")
    }

    private func save() {
        guard !Shot.on else { return }
        ud.set(a.rawValue, forKey: "tj_a"); ud.set(b.rawValue, forKey: "tj_b")
        ud.set(autoSpeak, forKey: "tj_auto"); ud.set(male, forKey: "tj_male")
        if let d = try? JSONEncoder().encode(rates) { ud.set(d, forKey: "tj_rates") }
        if let d = try? JSONEncoder().encode(Array(turns.suffix(300))) { ud.set(d, forKey: "tj_turns") }
    }

    func swap() { let t = a; a = b; b = t; Haptic.tap() }

    // MARK: التسجيل والترجمة
    func startTalk(mine: Bool) {
        guard busy == nil else { return }
        error = nil
        Task {
            guard await Recorder.permission() else { error = "اسمح للتطبيق يستعمل المايك من الإعدادات"; return }
            do { try rec.start(); busy = mine; status = "أسمعك…"; Haptic.thud() }
            catch { self.error = "ما اشتغل المايك" }
        }
    }

    func endTalk() {
        guard let mine = busy else { return }
        guard let data = rec.stop(), data.count > 2_000, rec.lastDuration > 0.5 else {
            busy = nil; status = ""; error = "اضغط مطوّلًا وأنت تحجي، وشيل إصبعك بعد ما تخلّص"; return
        }
        status = "أترجم…"
        let from = mine ? a : b, to = mine ? b : a
        Task {
            do {
                let t = try await Api.talk(audio: data, from: from, to: to, pair: (a, b))
                let heardLang = Lang(rawValue: t.lang) ?? from
                let target = heardLang == from ? to : Convo.target(heard: heardLang, pair: (a, b))
                let turn = Turn(id: UUID(), from: heardLang, to: target, heard: t.heard, translated: t.translated, date: Date(), mine: mine)
                turns.append(turn); save()
                online = true
                busy = nil; status = ""
                Haptic.ok()
                if autoSpeak { speak(turn.translated, target) }
            } catch {
                if let f = error as? Api.Fail, case .offline = f {
                    online = false
                    await offlineTalk(mine: mine, from: from, to: to)
                    return
                }
                busy = nil; status = ""
                self.error = error.localizedDescription
                Haptic.bad()
            }
        }
    }

    /// سيرفرنا محجوب ⇒ نفهم الكلام بالجهاز (Apple) ونترجم مباشرةً
    private func offlineTalk(mine: Bool, from: Lang, to: Lang) async {
        status = "أترجم (طريق مباشر)…"
        do {
            let heard = try await LocalEar.transcribe(rec.fileURL, lang: from)
            let r = try await Direct.translate(Script.normalize(heard, as: from), from: from, to: to)
            let turn = Turn(id: UUID(), from: from, to: to, heard: heard, translated: Script.normalize(r.text, as: to), date: Date(), mine: mine)
            turns.append(turn); save()
            busy = nil; status = ""
            Haptic.ok()
            if autoSpeak { speak(turn.translated, to) }
        } catch {
            busy = nil; status = ""
            self.error = (error as? LocalizedError)?.errorDescription ?? "ما گدرت أترجم — تأكّد من النت"
            Haptic.bad()
        }
    }

    /// كتابة بدل الحجي (مفيد إذا المكان صاخب أو الطرف الثاني يفضّل يكتب)
    func typed(_ text: String, mine: Bool) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, busy == nil else { return }
        let from = mine ? a : b, to = mine ? b : a
        busy = mine; status = "أترجم…"; error = nil
        Task {
            do {
                let out = try await Api.translate([clean], from: from, to: to).joined(separator: " ")
                let turn = Turn(id: UUID(), from: from, to: to, heard: clean, translated: out, date: Date(), mine: mine)
                turns.append(turn); save()
                Haptic.ok()
                if autoSpeak { speak(out, to) }
            } catch { self.error = error.localizedDescription; Haptic.bad() }
            busy = nil; status = ""
        }
    }

    func cancelTalk() { _ = rec.stop(); busy = nil; status = "" }

    func speak(_ text: String, _ lang: Lang) { voice.say(text, lang: lang, male: male) }

    func clear() { turns.removeAll(); save() }

    func checkServer() {
        Task {
            if let d = try? await Api.send("/ping", body: Data("{}".utf8), type: "application/json"),
               let p = try? JSONDecoder().decode(Api.Ping.self, from: d) { online = p.ok } else { online = false }
        }
    }

    private func demo() {
        let now = Date()
        turns = [
            Turn(id: UUID(), from: .ar, to: .fa, heard: "السلام عليكم، شكد الأجرة للحرم؟", translated: "سلام علیکم، تا حرم چقدر میشه؟", date: now.addingTimeInterval(-300), mine: true),
            Turn(id: UUID(), from: .fa, to: .ar, heard: "سلام، صد و پنجاه هزار تومن میشه", translated: "سلام، تصير مية وخمسين ألف تومان", date: now.addingTimeInterval(-260), mine: false),
            Turn(id: UUID(), from: .ar, to: .fa, heard: "غالي، أنطيك مية ألف", translated: "گرونه، صد هزار تومن میدم", date: now.addingTimeInterval(-200), mine: true),
            Turn(id: UUID(), from: .fa, to: .ar, heard: "باشه، بفرمایید سوار شید", translated: "تمام، تفضّلوا اركبوا", date: now.addingTimeInterval(-150), mine: false),
        ]
        online = true
        if Shot.name == "listen" { busy = true; status = "أسمعك…" }
    }
}

/// تسجيل صوت مضغوط صغير (AAC 16kHz) حتى يوصل للسيرفر بسرعة
final class Recorder: NSObject {
    private var r: AVAudioRecorder?
    private(set) var lastDuration: TimeInterval = 0
    private let url = FileManager.default.temporaryDirectory.appendingPathComponent("tj_rec.m4a")
    var fileURL: URL { url }

    static func permission() async -> Bool {
        await withCheckedContinuation { c in AVAudioSession.sharedInstance().requestRecordPermission { c.resume(returning: $0) } }
    }

    func start() throws {
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try s.setActive(true)
        let set: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16_000, AVNumberOfChannelsKey: 1,
                                  AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue, AVEncoderBitRateKey: 32_000]
        try? FileManager.default.removeItem(at: url)
        r = try AVAudioRecorder(url: url, settings: set)
        r?.isMeteringEnabled = true
        r?.record()
    }

    var level: Float {
        guard let r, r.isRecording else { return 0 }
        r.updateMeters()
        return max(0, min(1, (r.averagePower(forChannel: 0) + 50) / 50))
    }

    func stop() -> Data? {
        guard let r else { return nil }
        lastDuration = r.currentTime
        r.stop(); self.r = nil
        return try? Data(contentsOf: url)
    }
}

/// النطق: صوت طبيعيّ من السيرفر (يتخزّن بالجهاز ويشتغل بعدين بلا نت)، وإذا ماكو نت صوت الجهاز
@MainActor
final class Voice: NSObject, ObservableObject {
    private var player: AVAudioPlayer?
    private let synth = AVSpeechSynthesizer()
    @Published var speaking: String?

    static let dir: URL = {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("tts", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    static func file(_ text: String, _ lang: Lang, _ male: Bool) -> URL {
        var h: UInt64 = 1469598103934665603
        for b in (text + lang.rawValue + (male ? "m" : "f")).utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return dir.appendingPathComponent(String(h, radix: 36) + ".mp3")
    }

    /// أصوات العبارات مدمجة داخل التطبيق (تشتغل بلا نت)
    static let phraseIndex: [String: Int] = {
        var m: [String: Int] = [:]
        for p in Phrases.all { m[p.fa] = p.id }
        return m
    }()
    static func bundled(_ text: String, _ lang: Lang, _ male: Bool) -> URL? {
        guard lang == .fa, let id = phraseIndex[text] else { return nil }
        return Bundle.main.url(forResource: "fa_\(id)_\(male ? "m" : "f")", withExtension: "mp3")
    }

    static func cached(_ text: String, _ lang: Lang, _ male: Bool) -> Bool {
        FileManager.default.fileExists(atPath: file(text, lang, male).path)
    }

    func say(_ text: String, lang: Lang, male: Bool) {
        stop()
        speaking = text
        let f = Voice.file(text, lang, male)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        if let b = Voice.bundled(text, lang, male), let d = try? Data(contentsOf: b) { play(d); return }
        if let d = try? Data(contentsOf: f) { play(d); return }
        Task {
            if let d = try? await Api.speech(text, lang: lang, male: male), d.count > 500 {
                try? d.write(to: f)
                if speaking == text { play(d) }
                return
            }
            if let u = Direct.ttsURL(text, lang: lang), let res = try? await URLSession.shared.data(from: u),
               (res.1 as? HTTPURLResponse)?.statusCode == 200, res.0.count > 500 {
                try? res.0.write(to: f)
                if speaking == text { play(res.0) }
                return
            }
            if speaking == text { local(text, lang) }
        }
    }

    /// ينزّل الصوت بدون تشغيل (لتجهيز العبارات للاستعمال بلا نت)
    static func prefetch(_ text: String, _ lang: Lang, _ male: Bool) async -> Bool {
        let f = file(text, lang, male)
        if FileManager.default.fileExists(atPath: f.path) { return true }
        guard let d = try? await Api.speech(text, lang: lang, male: male), d.count > 500 else { return false }
        try? d.write(to: f)
        return true
    }

    private func play(_ d: Data) {
        player = try? AVAudioPlayer(data: d)
        player?.delegate = self
        player?.play()
    }

    private func local(_ text: String, _ lang: Lang) {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: lang.voice) ?? AVSpeechSynthesisVoice(language: "ar-SA")
        u.rate = 0.47
        synth.delegate = self
        synth.speak(u)
    }

    func stop() {
        player?.stop(); player = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speaking = nil
    }
}

extension Voice: AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.speaking = nil }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = nil }
    }
}

/// فهم الكلام على الجهاز نفسه (Apple) — احتياط إذا سيرفرنا ما يوصل
enum LocalEar {
    struct NoLang: LocalizedError { let lang: Lang
        var errorDescription: String? { "الموبايل ما يفهم \(lang.name) بلا سيرفرنا — شغّل VPN أو خلّي الطرف يكتب ⌨️" } }

    static func transcribe(_ url: URL, lang: Lang) async throws -> String {
        let ok: Bool = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard ok, let r = SFSpeechRecognizer(locale: Locale(identifier: lang.voice)), r.isAvailable else { throw NoLang(lang: lang) }
        let req = SFSpeechURLRecognitionRequest(url: url)
        req.shouldReportPartialResults = false
        if r.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = false }
        return try await withCheckedThrowingContinuation { c in
            var done = false
            _ = r.recognitionTask(with: req) { res, err in
                if done { return }
                if let res, res.isFinal { done = true; c.resume(returning: res.bestTranscription.formattedString); return }
                if let err { done = true; c.resume(throwing: err) }
            }
        }
    }
}

@main
struct TarjumanApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(store.voice)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(TJ.teal)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab: Int = {
        switch Shot.name {
        case "text": return 1
        case "camera": return 2
        case "phrases", "phrase": return 3
        case "money": return 4
        default: return 0
        }
    }()
    var body: some View {
        TabView(selection: $tab) {
            TalkScreen().tag(0).tabItem { Label("محادثة", systemImage: "waveform") }
            TextScreen().tag(1).tabItem { Label("اكتب", systemImage: "character.bubble") }
            CameraScreen().tag(2).tabItem { Label("كاميرا", systemImage: "camera.viewfinder") }
            PhrasesScreen().tag(3).tabItem { Label("عبارات", systemImage: "text.book.closed") }
            MoneyScreen().tag(4).tabItem { Label("تومان", systemImage: "banknote") }
        }
        .onAppear {
            let a = UITabBarAppearance(); a.configureWithOpaqueBackground()
            a.backgroundColor = UIColor(TJ.s1)
            UITabBar.appearance().standardAppearance = a; UITabBar.appearance().scrollEdgeAppearance = a
            if !Shot.on { store.checkServer() }
        }
    }
}

/// حبّة اختيار لغة
struct LangMenu: View {
    @Binding var lang: Lang
    var color: Color = TJ.teal
    var body: some View {
        Menu {
            ForEach(Lang.allCases) { l in
                Button { lang = l } label: { Text("\(l.flag) \(l.name) — \(l.native)") }
            }
        } label: {
            HStack(spacing: 6) {
                Text(lang.flag).font(rnd(18))
                Text(lang.name).font(rnd(15, .bold)).foregroundStyle(.white)
                Image(systemName: "chevron.down").font(rnd(10, .bold)).foregroundStyle(TJ.tx3)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.35)))
        }
    }
}

struct LangBar: View {
    @EnvironmentObject var store: Store
    var body: some View {
        HStack(spacing: 10) {
            LangMenu(lang: $store.a, color: TJ.teal)
            Button { store.swap() } label: {
                Image(systemName: "arrow.left.arrow.right").font(rnd(15, .bold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(TJ.s3, in: Circle())
            }.buttonStyle(Press())
            LangMenu(lang: $store.b, color: TJ.gold)
        }
    }
}
