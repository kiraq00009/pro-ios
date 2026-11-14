import SwiftUI
import AVFoundation
import Speech
import Photos
import CoreTransferable
import UniformTypeIdentifiers

enum MT {
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let s1 = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let s2 = Color(red: 0.14, green: 0.14, blue: 0.17)
    static let s3 = Color(red: 0.21, green: 0.21, blue: 0.25)
    static let hot = Color(red: 1.0, green: 0.23, blue: 0.40)
    static let cyan = Color(red: 0.25, green: 0.92, blue: 0.95)
    static let yellow = Color(red: 1.0, green: 0.83, blue: 0.0)
    static let tx2 = Color(white: 1, opacity: 0.72), tx3 = Color(white: 1, opacity: 0.44)
    static func hex(_ h: Int) -> Color { Color(red: Double((h >> 16) & 0xFF) / 255, green: Double((h >> 8) & 0xFF) / 255, blue: Double(h & 0xFF) / 255) }
}

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var file: String
    var created: Date
    var duration: Double = 0
    var lang: Lang?
    var target: Lang = .ar
    var cues: [Cue] = []
    var style = Style()
    var phase: Phase = .new
    var error: String?
    var exported: String?
    var portrait = true

    enum Phase: String, Codable { case new, listening, translating, ready, failed }

    static func == (a: Project, b: Project) -> Bool { a.id == b.id && a.cues == b.cues && a.style == b.style && a.phase == b.phase }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum Paths {
    static let videos: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
}

/// فيديو جاي من الألبوم
struct Movie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { m in SentTransferredFile(m.url) } importing: { r in
            let dst = Paths.videos.appendingPathComponent(UUID().uuidString + "." + (r.file.pathExtension.isEmpty ? "mov" : r.file.pathExtension))
            try FileManager.default.copyItem(at: r.file, to: dst)
            return Movie(url: dst)
        }
    }
}

@MainActor
final class Studio: ObservableObject {
    @Published var projects: [Project] = []
    @Published var open: UUID?
    @Published var defaultStyle = Style()

    static var dir: URL { Paths.videos }
    private let index = Paths.videos.appendingPathComponent("projects.json")

    init() {
        if Shot.on { projects = Demo.projects; if Shot.isAny("editor", "lines", "export") { open = projects.first?.id }; return }
        if let d = try? Data(contentsOf: index), let v = try? JSONDecoder().decode([Project].self, from: d) {
            projects = v.map { var p = $0; if p.phase == .listening || p.phase == .translating { p.phase = .failed; p.error = "انقطعت المعالجة — اضغط «أعد المحاولة»" }; return p }
        }
        if let d = UserDefaults.standard.data(forKey: "mt_style"), let s = try? JSONDecoder().decode(Style.self, from: d) { defaultStyle = s }
    }

    func save() { if !Shot.on, let d = try? JSONEncoder().encode(projects) { try? d.write(to: index, options: .atomic) } }
    func url(_ p: Project) -> URL { Studio.dir.appendingPathComponent(p.file) }

    func update(_ id: UUID, _ f: (inout Project) -> Void) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        f(&projects[i]); save()
    }

    func rememberStyle(_ s: Style) {
        defaultStyle = s
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: "mt_style") }
    }

    func remove(_ id: UUID) {
        if let p = projects.first(where: { $0.id == id }) { try? FileManager.default.removeItem(at: url(p)) }
        projects.removeAll { $0.id == id }; save()
    }

    func add(_ m: Movie) {
        let id = UUID()
        var p = Project(id: id, file: m.url.lastPathComponent, created: Date())
        p.style = defaultStyle
        projects.insert(p, at: 0); save()
        open = id
        Task {
            let a = AVURLAsset(url: m.url)
            if let d = try? await a.load(.duration) { update(id) { $0.duration = CMTimeGetSeconds(d) } }
            if let t = try? await a.loadTracks(withMediaType: .video).first,
               let n = try? await t.load(.naturalSize), let tr = try? await t.load(.preferredTransform) {
                let r = CGRect(origin: .zero, size: n).applying(tr)
                update(id) { $0.portrait = abs(r.height) >= abs(r.width) }
            }
            process(id)
        }
    }

    /// الصوت ← كلام بتوقيت كلّ كلمة ← ترجمة
    func process(_ id: UUID) {
        guard let p = projects.first(where: { $0.id == id }) else { return }
        let video = url(p), target = p.target
        update(id) { $0.phase = .listening; $0.error = nil }
        Task {
            do {
                let audio = try await Burner.audio(of: video)
                let data = try Data(contentsOf: audio)
                var segs: [Api.Segment] = []
                var lang: Lang?
                do {
                    let r = try await Api.subs(audio: data, lang: nil, to: target)
                    segs = r.segments; lang = Lang(rawValue: r.lang)
                } catch let e as Api.Fail {
                    guard case .offline = e else { throw e }
                    let r = try await LocalEar.words(audio)
                    segs = r.1; lang = r.0
                }
                guard !segs.isEmpty else { throw Api.Fail.empty }
                var cues = Subs.cues(from: segs)
                update(id) { $0.lang = lang; $0.cues = cues; $0.phase = .translating }
                if let l = lang, l != target, cues.contains(where: { $0.tr.isEmpty }) {
                    let out = try await Api.translate(cues.map(\.text), from: l, to: target)
                    for i in cues.indices where i < out.count { cues[i].tr = out[i] }
                }
                if lang == target { for i in cues.indices { cues[i].tr = "" } }
                let same = lang == target
                update(id) { $0.cues = cues; $0.phase = .ready; if same { $0.style.mode = .original } }
                Haptic.ok()
            } catch {
                update(id) { $0.phase = .failed; $0.error = (error as? LocalizedError)?.errorDescription ?? "ما گدرت أسمع الفيديو" }
                Haptic.bad()
            }
        }
    }

    func retranslate(_ id: UUID, to: Lang) {
        update(id) { $0.target = to; $0.phase = .translating }
        guard let p = projects.first(where: { $0.id == id }), let l = p.lang else { return }
        Task {
            var cues = p.cues
            if l == to { for i in cues.indices { cues[i].tr = "" } }
            else if let out = try? await Api.translate(cues.map(\.text), from: l, to: to) {
                for i in cues.indices where i < out.count { cues[i].tr = out[i] }
            }
            update(id) { $0.cues = cues; $0.phase = .ready; if l == to { $0.style.mode = .original } else if $0.style.mode == .original { $0.style.mode = .translation } }
        }
    }

    static func saveToPhotos(_ u: URL) async -> Bool {
        let st = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard st == .authorized || st == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: u) }
            return true
        } catch { return false }
    }
}

/// تفريغ على الجهاز بتوقيت كلّ كلمة (احتياط)
enum LocalEar {
    struct Denied: LocalizedError { var errorDescription: String? { "اسمح بالتعرّف على الكلام من الإعدادات، أو شغّل VPN حتى يشتغل سيرفرنا" } }
    static func words(_ url: URL) async throws -> (Lang, [Api.Segment]) {
        let ok: Bool = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) } }
        guard ok else { throw Denied() }
        var last: Error = Api.Fail.empty
        for l in [Lang.en, .ar, .tr] {
            guard let r = SFSpeechRecognizer(locale: Locale(identifier: l.voice)), r.isAvailable else { continue }
            let req = SFSpeechURLRecognitionRequest(url: url)
            req.shouldReportPartialResults = false
            if r.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            do {
                let res: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { c in
                    var done = false
                    _ = r.recognitionTask(with: req) { res, err in
                        if done { return }
                        if let res, res.isFinal { done = true; c.resume(returning: res); return }
                        if let err { done = true; c.resume(throwing: err) }
                    }
                }
                let ws = res.bestTranscription.segments.map { Api.Word(s: $0.timestamp, e: $0.timestamp + $0.duration, w: $0.substring) }
                guard ws.count >= 2 else { continue }
                // نتأكّد إنّ اللغة صحيحة: ثقة متوسّطة معقولة
                let conf = res.bestTranscription.segments.map(\.confidence).reduce(0, +) / Float(max(1, ws.count))
                if conf < 0.35 && l != .tr { continue }
                return (l, [Api.Segment(s: ws[0].s, e: ws.last!.e, text: ws.map(\.w).joined(separator: " "), words: ws)])
            } catch { last = error }
        }
        throw last
    }
}

@main
struct MontageApp: App {
    @StateObject private var studio = Studio()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(studio)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(MT.hot)
        }
    }
}

enum Demo {
    static var projects: [Project] {
        func cue(_ s: Double, _ e: Double, _ t: String, _ tr: String) -> Cue {
            let ws = t.split(separator: " ").map(String.init)
            let step = (e - s) / Double(max(1, ws.count))
            let words = ws.enumerated().map { i, w in Api.Word(s: s + Double(i) * step, e: s + Double(i + 1) * step, w: w) }
            return Cue(s: s, e: e, text: t, tr: tr, words: words)
        }
        var a = Project(id: UUID(), file: "demo.mov", created: Date(), duration: 38, lang: .en, target: .ar)
        a.cues = [cue(0.4, 2.6, "You won't believe what happened next", "ما راح تصدّق شنو صار بعدين"),
                  cue(2.7, 5.1, "I opened the box and it was empty", "فتحت الصندوق وطلع فارغ"),
                  cue(5.2, 8.0, "So I called the store right away", "فدگيت على المحلّ فورًا"),
                  cue(8.1, 11.0, "And they said it was never shipped", "وگالولي ما انشحن أصلًا"),
                  cue(11.1, 14.3, "This is the craziest customer service ever", "هذي أغرب خدمة زبائن شفتها")]
        a.phase = .ready
        a.style.look = Shot.name == "export" ? .box : .tiktok
        var b = Project(id: UUID(), file: "b.mov", created: Date().addingTimeInterval(-7200), duration: 61, lang: .fa, target: .ar)
        b.phase = .ready; b.cues = [cue(0, 3, "سلام به همه", "هلا بالجميع")]
        b.style.look = .classic
        var c = Project(id: UUID(), file: "c.mov", created: Date().addingTimeInterval(-90_000), duration: 15)
        c.phase = Shot.name == "home" ? .listening : .ready
        return [a, b, c]
    }
}
