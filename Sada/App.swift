import SwiftUI
import AVFoundation
import Speech

enum SD {
    static let bg = Color(red: 0.05, green: 0.04, blue: 0.08)
    static let s1 = Color(red: 0.09, green: 0.08, blue: 0.14)
    static let s2 = Color(red: 0.13, green: 0.12, blue: 0.20)
    static let s3 = Color(red: 0.19, green: 0.17, blue: 0.28)
    static let lime = Color(red: 0.70, green: 1.0, blue: 0.42)
    static let violet = Color(red: 0.62, green: 0.48, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.50, blue: 0.42)
    static let tx2 = Color(white: 1, opacity: 0.74), tx3 = Color(white: 1, opacity: 0.45)
}

@MainActor
final class Library: ObservableObject {
    @Published var notes: [Note] = []
    @Published var open: Note.ID?
    @Published var toast: String?

    static let dir: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("notes", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    private let index = Library.dir.appendingPathComponent("index.json")

    init() {
        if Shot.on { notes = Demo.notes; if Shot.isAny("detail", "trans") { open = notes.first?.id }; return }
        if let d = try? Data(contentsOf: index), let v = try? JSONDecoder().decode([Note].self, from: d) {
            notes = v.map { n in
                var m = n
                if m.state == .transcribing || m.state == .summarizing || m.state == .waiting { m.state = .waiting }
                return m
            }
        }
        for n in notes where n.state == .waiting { process(n.id) }
    }

    func save() { if !Shot.on, let d = try? JSONEncoder().encode(notes) { try? d.write(to: index, options: .atomic) } }

    func url(_ n: Note) -> URL { Library.dir.appendingPathComponent(n.file) }

    var totalSaved: Double { notes.reduce(0) { $0 + $1.savedSeconds } }

    func update(_ id: UUID, _ f: (inout Note) -> Void) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        f(&notes[i]); save()
    }

    func remove(_ id: UUID) {
        if let n = notes.first(where: { $0.id == id }) { try? FileManager.default.removeItem(at: url(n)) }
        notes.removeAll { $0.id == id }; save()
    }

    /// ملفّ جاي من المشاركة (واتساب/تليكرام/الملفّات)
    func importFile(_ src: URL, source: String? = nil) {
        let scoped = src.startAccessingSecurityScopedResource()
        defer { if scoped { src.stopAccessingSecurityScopedResource() } }
        let ext = src.pathExtension.isEmpty ? "m4a" : src.pathExtension.lowercased()
        let id = UUID()
        let name = "\(id.uuidString).\(ext)"
        let dst = Library.dir.appendingPathComponent(name)
        do { try FileManager.default.copyItem(at: src, to: dst) } catch { toast = "ما گدرت أفتح الملفّ"; return }
        let lower = src.lastPathComponent.lowercased()
        let from = source ?? (ext == "opus" || lower.contains("whatsapp") || lower.hasPrefix("ptt") ? "واتساب"
                              : (ext == "ogg" || ext == "oga" ? "تليكرام" : (["mp4", "mov"].contains(ext) ? "فيديو" : "ملفّ")))
        let n = Note(id: id, file: name, source: from, created: Date(), duration: 0)
        notes.insert(n, at: 0); save()
        open = id
        process(id)
    }

    func addRecording(_ file: URL, duration: Double) {
        let id = UUID(); let name = "\(id.uuidString).m4a"
        try? FileManager.default.moveItem(at: file, to: Library.dir.appendingPathComponent(name))
        notes.insert(Note(id: id, file: name, source: "تسجيل", created: Date(), duration: duration), at: 0); save()
        open = id
        process(id)
    }

    // MARK: المعالجة: تفريغ ← تلخيص
    func process(_ id: UUID) {
        guard let n = notes.first(where: { $0.id == id }) else { return }
        let file = url(n)
        update(id) { $0.state = .transcribing; $0.error = nil }
        Task {
            var dur = await Audio.duration(file)
            var playable = Audio.playable(file)
            do {
                let data = try Data(contentsOf: file)
                var heard: Api.Heard?
                do { heard = try await Api.transcribe(audio: data, lang: nil) }
                catch let e as Api.Fail {
                    guard case .offline = e else { throw e }
                    guard playable else { throw LocalEar.Unsupported() }
                    heard = try await LocalEar.transcribe(file)
                }
                guard let h = heard, !h.segments.isEmpty else { throw Api.Fail.empty }
                if !playable, let conv = try? await Api.send("/conv", body: data, type: "application/octet-stream"), conv.count > 1000 {
                    let m4a = n.file.split(separator: ".").first.map(String.init)! + ".m4a"
                    try? conv.write(to: Library.dir.appendingPathComponent(m4a))
                    try? FileManager.default.removeItem(at: file)
                    update(id) { $0.file = m4a }
                    playable = true
                    if let nn = notes.first(where: { $0.id == id }) { dur = await Audio.duration(url(nn)) }
                }
                let lang = Lang(rawValue: h.lang)
                let d = dur > 0 ? dur : (h.secs ?? (h.segments.last?.e ?? 0))
                update(id) { $0.segments = h.segments; $0.lang = lang; $0.duration = d; $0.state = .summarizing }
                let text = h.segments.map(\.text).joined(separator: " ")
                var sum: Api.Summary
                if text.split(separator: " ").count < 18 {
                    sum = Api.Summary(title: "", summary: text, points: [], actions: LocalSummary.actions(text), engine: "short")
                } else {
                    do { sum = try await Api.summarize(text, lang: lang ?? .ar) }
                    catch { sum = LocalSummary.make(text) }
                }
                update(id) { $0.summary = sum; $0.state = .done; $0.engine = sum.engine }
                Haptic.ok()
                if let l = lang, l != .ar { translate(id) }
            } catch {
                update(id) { $0.state = .failed; $0.error = (error as? LocalizedError)?.errorDescription ?? "ما گدرت أفرّغ الصوت" }
                Haptic.bad()
            }
        }
    }

    func translate(_ id: UUID) {
        guard let n = notes.first(where: { $0.id == id }), let l = n.lang, l != .ar else { return }
        Task {
            if let out = try? await Api.translate(n.segments.map(\.text), from: l, to: .ar), out.count == n.segments.count {
                update(id) { $0.translation = out }
            }
        }
    }
}

enum Audio {
    static func duration(_ u: URL) async -> Double {
        let a = AVURLAsset(url: u)
        guard let d = try? await a.load(.duration) else { return 0 }
        let s = CMTimeGetSeconds(d)
        return s.isFinite ? s : 0
    }
    static func playable(_ u: URL) -> Bool {
        let ext = u.pathExtension.lowercased()
        return !["opus", "ogg", "oga", "webm"].contains(ext)
    }
}

/// تفريغ على الجهاز (Apple) — احتياط إذا سيرفرنا ما يوصل
enum LocalEar {
    struct Unsupported: LocalizedError {
        var errorDescription: String? { "بصمات واتساب/تليكرام (opus) تحتاج سيرفرنا — شغّل VPN واضغط «أعد المحاولة»" }
    }
    struct Denied: LocalizedError { var errorDescription: String? { "اسمح لصدى يستعمل التعرّف على الكلام من الإعدادات" } }

    static func transcribe(_ url: URL) async throws -> Api.Heard {
        let ok: Bool = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) } }
        guard ok else { throw Denied() }
        let tries: [Lang] = [.ar, .en]
        var lastErr: Error = Api.Fail.empty
        for l in tries {
            guard let r = SFSpeechRecognizer(locale: Locale(identifier: l.voice)), r.isAvailable else { continue }
            let req = SFSpeechURLRecognitionRequest(url: url)
            req.shouldReportPartialResults = false
            if r.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            req.addsPunctuation = true
            do {
                let res: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { c in
                    var done = false
                    _ = r.recognitionTask(with: req) { res, err in
                        if done { return }
                        if let res, res.isFinal { done = true; c.resume(returning: res); return }
                        if let err { done = true; c.resume(throwing: err) }
                    }
                }
                let segs = group(res.bestTranscription.segments.map { ($0.timestamp, $0.timestamp + $0.duration, $0.substring) })
                if !segs.isEmpty { return Api.Heard(lang: l.rawValue, text: segs.map(\.text).joined(separator: " "), segments: segs, secs: segs.last?.e) }
            } catch { lastErr = error }
        }
        throw lastErr
    }

    /// كلمات منفردة ← جمل (فاصل صمت > ٠٫٨ث أو ١٤ كلمة)
    static func group(_ w: [(Double, Double, String)]) -> [Api.Segment] {
        var out: [Api.Segment] = []
        var cur: [(Double, Double, String)] = []
        for x in w {
            if let last = cur.last, x.0 - last.1 > 0.8 || cur.count >= 14 {
                out.append(Api.Segment(s: cur[0].0, e: last.1, text: cur.map(\.2).joined(separator: " ")))
                cur = []
            }
            cur.append(x)
        }
        if let last = cur.last { out.append(Api.Segment(s: cur[0].0, e: last.1, text: cur.map(\.2).joined(separator: " "))) }
        return out
    }
}

/// مشغّل البصمة مع متابعة الوقت
@MainActor
final class Player: ObservableObject {
    @Published var playing = false
    @Published var time: Double = 0
    @Published var rate: Float = 1
    private var p: AVAudioPlayer?
    private var timer: Timer?
    private(set) var url: URL?

    func load(_ u: URL) {
        guard url != u else { return }
        stop(); url = u
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        p = try? AVAudioPlayer(contentsOf: u)
        p?.enableRate = true
        p?.prepareToPlay()
        time = 0
    }
    var duration: Double { p?.duration ?? 0 }
    func toggle() {
        guard let p else { return }
        if p.isPlaying { p.pause(); playing = false; timer?.invalidate() }
        else {
            try? AVAudioSession.sharedInstance().setActive(true)
            p.rate = rate; p.play(); playing = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let p = self.p else { return }
                    self.time = p.currentTime
                    if !p.isPlaying { self.playing = false; self.timer?.invalidate() }
                }
            }
        }
    }
    func seek(_ t: Double) { p?.currentTime = max(0, t); time = max(0, t); if !(p?.isPlaying ?? false) { toggle() } }
    func cycleRate() {
        rate = rate == 1 ? 1.5 : (rate == 1.5 ? 2 : 1)
        p?.rate = rate
    }
    func stop() { p?.stop(); p = nil; timer?.invalidate(); playing = false }
}

/// مسجّل الاجتماعات (يكمل حتى لو قفلت الشاشة)
@MainActor
final class Recorder: ObservableObject {
    @Published var on = false
    @Published var paused = false
    @Published var time: Double = 0
    @Published var level: Float = 0
    private var r: AVAudioRecorder?
    private var timer: Timer?
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("sada_rec.m4a")

    func start() async -> Bool {
        let ok: Bool = await withCheckedContinuation { c in AVAudioSession.sharedInstance().requestRecordPermission { c.resume(returning: $0) } }
        guard ok else { return false }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try? s.setActive(true)
        try? FileManager.default.removeItem(at: file)
        let set: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 22_050, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 40_000]
        r = try? AVAudioRecorder(url: file, settings: set)
        r?.isMeteringEnabled = true
        guard r?.record() == true else { return false }
        on = true; paused = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let r = self.r else { return }
                r.updateMeters()
                self.time = r.currentTime
                self.level = max(0, min(1, (r.averagePower(forChannel: 0) + 50) / 50))
            }
        }
        return true
    }
    func pause() { guard let r else { return }; if paused { r.record() } else { r.pause() }; paused.toggle() }
    func stop() -> (URL, Double)? {
        guard let r else { return nil }
        let d = r.currentTime
        r.stop(); self.r = nil; timer?.invalidate(); on = false
        return d > 1 ? (file, d) : nil
    }
}

@main
struct SadaApp: App {
    @StateObject private var lib = Library()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(lib)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(SD.lime)
                .onOpenURL { u in if u.isFileURL { lib.importFile(u) } }
        }
    }
}

enum Demo {
    static var notes: [Note] {
        let now = Date()
        func seg(_ a: [(Double, Double, String)]) -> [Api.Segment] { a.map { Api.Segment(s: $0.0, e: $0.1, text: $0.2) } }
        var a = Note(id: UUID(), file: "x.m4a", source: "واتساب", created: now.addingTimeInterval(-900), duration: 184, lang: .ar)
        a.segments = seg([(0, 6, "هلا خيري شلونك، اسمع عندي كم شغلة مهمّة بخصوص الشحنة."),
                          (6, 15, "البضاعة توصل باچر العصر للمخزن، بس لازم واحد يكون موجود يستلم الساعة أربعة."),
                          (15, 26, "السايق طلب مية وخمسين ألف دينار أجرة النقل، وآني كتله زين بس بعد ما يفرّغ."),
                          (26, 38, "وبعدين الفاتورة الجديدة ارسلتها على الواتساب، شوفها وگلّي إذا الأسعار زينة."),
                          (38, 50, "وإذا تكدر حوّل الدفعة الثانية قبل الخميس حتى ما يتأخّر الطلب الجاي.")])
        a.summary = Api.Summary(title: "استلام الشحنة باچر العصر",
                                summary: "الشحنة توصل للمخزن باچر العصر ولازم أحد يستلمها الساعة ٤. السايق يريد ١٥٠ ألف دينار بعد التفريغ.",
                                points: ["البضاعة توصل باچر العصر للمخزن", "لازم أحد يستلم الساعة ٤", "أجرة النقل ١٥٠ ألف دينار بعد التفريغ", "الفاتورة الجديدة مرسلة بالواتساب للمراجعة"],
                                actions: ["استلام الشحنة باچر الساعة ٤ العصر", "دفع ١٥٠ ألف للسايق بعد التفريغ", "مراجعة الفاتورة", "تحويل الدفعة الثانية قبل الخميس"], engine: "gemini")
        a.state = .done
        var b = Note(id: UUID(), file: "y.m4a", source: "تليكرام", created: now.addingTimeInterval(-86_000), duration: 96, lang: .fa)
        b.segments = seg([(0, 8, "سلام آقا، قیمت زعفران امروز کیلویی صد و هشتاد میلیون شده."), (8, 18, "اگه تا فردا سفارش بدید همین قیمت رو براتون نگه می‌دارم.")])
        b.translation = ["سلام أستاذ، سعر الزعفران اليوم صار ١٨٠ مليون للكيلو.", "إذا تطلب قبل باچر أثبّتلك نفس السعر."]
        b.summary = Api.Summary(title: "سعر الزعفران اليوم", summary: "الزعفران صار ١٨٠ مليون تومان للكيلو، والسعر يثبت إذا تطلب قبل باچر.",
                                points: ["١٨٠ مليون تومان للكيلو", "تثبيت السعر للطلب قبل باچر"], actions: ["قرّر قبل باچر"], engine: "gemini")
        b.state = .done
        var c = Note(id: UUID(), file: "z.m4a", source: "تسجيل", created: now.addingTimeInterval(-200_000), duration: 2_710, lang: .ar)
        c.summary = Api.Summary(title: "اجتماع خطّة الشهر الجاي", summary: "اتّفقنا على إطلاق النسخة الجديدة أوّل الشهر وتقسيم المهامّ.", points: [], actions: [], engine: "gemini")
        c.segments = seg([(0, 30, String(repeating: "كلام الاجتماع ", count: 60))])
        c.state = .done
        var d = Note(id: UUID(), file: "w.opus", source: "واتساب", created: now, duration: 42)
        d.state = .transcribing
        return Shot.name == "home" ? [d, a, b, c] : [a, b, c]
    }
}
