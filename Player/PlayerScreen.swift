import SwiftUI
import AVKit

/// محرّك التشغيل: يشغّل الرابط بتعريف المشغّل المطلوب، يحفظ موضع المشاهدة، ويتنقّل بين القنوات
@MainActor
final class Engine: ObservableObject {
    @Published var title = ""
    @Published var sub = ""
    @Published var failed = false
    @Published var buffering = true
    @Published var index = 0
    @Published var url = ""
    let player = AVPlayer()
    private var item: PlayItem
    private var ua = "VLC/3.0.20 LibVLC/3.0.20"
    private var statusObs: NSKeyValueObservation?
    private var bufObs: NSKeyValueObservation?
    private var timeObs: Any?
    private var gen = 0
    private var tries = 0
    var onSave: ((Double, Double) -> Void)?

    init(item: PlayItem) { self.item = item; title = item.title; sub = item.sub; index = item.index }

    var isLive: Bool { item.live }
    var channels: [Channel] { item.channels }

    func start(ua: String) {
        self.ua = ua
        player.allowsExternalPlayback = true
        timeObs = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 10, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor in self?.save() }
        }
        load(item.url, at: item.start)
    }
    func stop() {
        save(); gen += 1
        if let o = timeObs { player.removeTimeObserver(o); timeObs = nil }
        player.pause(); player.replaceCurrentItem(with: nil)
    }
    private func save() {
        guard !item.live, let it = player.currentItem else { return }
        let t = player.currentTime().seconds, d = it.duration.seconds
        if t.isFinite, d.isFinite, d > 0 { onSave?(t, d) }
    }

    private func load(_ s: String, at start: Double = 0) {
        gen += 1; let my = gen
        url = s; failed = false; buffering = true
        guard let u = URL(string: s) else { failed = true; buffering = false; return }
        let asset = AVURLAsset(url: u, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": ua]])
        let it = AVPlayerItem(asset: asset)
        statusObs = it.observe(\.status) { [weak self] it, _ in
            Task { @MainActor in
                guard let self, my == self.gen else { return }
                if it.status == .readyToPlay {
                    self.tries = 0
                    if start > 5 { self.player.seek(to: CMTime(seconds: start, preferredTimescale: 600)) }
                    self.player.play()
                } else if it.status == .failed { self.retry(s, start) }
            }
        }
        bufObs = it.observe(\.isPlaybackLikelyToKeepUp) { [weak self] it, _ in
            Task { @MainActor in guard let self, my == self.gen else { return }; self.buffering = !it.isPlaybackLikelyToKeepUp }
        }
        player.replaceCurrentItem(with: it)
        player.play()
    }
    /// القنوات تنقطع لحظات — نعيد المحاولة مرّتين قبل ما نعلن الفشل
    private func retry(_ s: String, _ start: Double) {
        tries += 1
        if tries > 2 { failed = true; buffering = false; return }
        let my = gen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if my == self.gen { self.load(s, at: start) } }
    }
    func again() { tries = 0; load(url, at: item.live ? 0 : max(0, player.currentTime().seconds.isFinite ? player.currentTime().seconds : item.start)) }

    func zap(_ step: Int) { guard item.live, !item.channels.isEmpty else { return }; tune((index + step + item.channels.count) % item.channels.count) }
    func tune(_ i: Int) {
        guard item.channels.indices.contains(i) else { return }
        index = i; tries = 0
        let c = item.channels[i]
        title = Core.clean(c.name); Haptic.tap()
        load(c.url)
    }
}

struct VideoBox: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let v = AVPlayerViewController()
        v.player = player; v.allowsPictureInPicturePlayback = true; v.canStartPictureInPictureAutomaticallyFromInline = true
        v.videoGravity = .resizeAspect
        return v
    }
    func updateUIViewController(_ v: AVPlayerViewController, context: Context) {}
}

struct PlayerScreen: View {
    let item: PlayItem
    @EnvironmentObject var lib: Library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var eng: Engine
    @State private var list = false

    init(item: PlayItem) { self.item = item; _eng = StateObject(wrappedValue: Engine(item: item)) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoBox(player: eng.player).ignoresSafeArea()
            if eng.buffering && !eng.failed { ProgressView().tint(Color.white).scaleEffect(1.4).allowsHitTesting(false) }
            if eng.failed { failure }
            VStack {
                HStack(spacing: 8) {
                    chipButton("xmark") { eng.stop(); dismiss() }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(eng.title).font(rnd(14.5, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                        if eng.isLive { HStack(spacing: 4) { Circle().fill(PL.live).frame(width: 6, height: 6); Text("مباشر").font(rnd(10.5, .heavy)).foregroundStyle(PL.live) } }
                        else if !eng.sub.isEmpty { Text(eng.sub).font(rnd(11)).foregroundStyle(PL.tx2) }
                    }.padding(.horizontal, 12).frame(height: 40).background(.ultraThinMaterial, in: Capsule())
                    Spacer(minLength: 0)
                    if eng.isLive && eng.channels.count > 1 {
                        chipButton("chevron.up") { eng.zap(-1) }
                        chipButton("chevron.down") { eng.zap(1) }
                        chipButton("list.bullet") { list = true }
                    }
                }
                .padding(.horizontal, 14).padding(.top, 54)
                Spacer()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            let it = item
            eng.onSave = { t, d in lib.savePos(Resume(t: t, d: d, at: Date().timeIntervalSince1970, name: it.title + (it.sub.isEmpty ? "" : " — " + it.sub), poster: it.poster, kind: "v", id: it.key, url: it.url), key: it.key) }
            if !Shot.on { eng.start(ua: lib.current?.ua ?? "VLC/3.0.20 LibVLC/3.0.20") }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; eng.stop() }
        .sheet(isPresented: $list) {
            ChannelPicker(channels: eng.channels, current: eng.index) { i in list = false; eng.tune(i); lib.touch(channel: eng.channels[i].id) }
                .environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark).presentationDetents([.medium, .large])
        }
    }

    private func chipButton(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(Color.white).frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle()) }.buttonStyle(Press())
    }

    private var failure: some View {
        let ok = Core.playable(eng.url)
        return VStack(spacing: 12) {
            Image(systemName: ok ? "wifi.exclamationmark" : "film.stack").font(.system(size: 40)).foregroundStyle(PL.gold)
            Text(ok ? "ما اشتغل" : "هالصيغة ما يشغّلها الآيفون").font(rnd(20, .black)).foregroundStyle(Color.white)
            Text(ok ? (eng.isLive ? "القناة واقفة هسه، أو اتّصالات اشتراكك كلّها مشغولة." : "الملفّ ما يردّ هسه، أو اتّصالات اشتراكك كلّها مشغولة.")
                    : "الملفّ بصيغة ما يدعمها مشغّل آبل (مثل MKV). افتحه ببرنامج VLC.").font(rnd(13.5)).foregroundStyle(PL.tx2).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button { eng.again() } label: { Text("جرّب مرّة ثانية").font(rnd(14, .heavy)).foregroundStyle(Color.white).padding(.horizontal, 18).frame(height: 44).background(PL.ac, in: Capsule()) }.buttonStyle(Press())
                if let v = Core.vlcLink(eng.url) { Button { openURL(v) } label: { Text("افتح بـVLC").font(rnd(14, .heavy)).foregroundStyle(Color.black).padding(.horizontal, 18).frame(height: 44).background(PL.gold, in: Capsule()) }.buttonStyle(Press()) }
            }
        }.padding(24).frame(maxWidth: 340).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous)).padding(.horizontal, 24)
    }
}

/// قائمة القنوات داخل المشغّل (للتبديل السريع)
struct ChannelPicker: View {
    let channels: [Channel]; let current: Int
    let pick: (Int) -> Void
    @State private var q = ""
    var body: some View {
        let list = Array(channels.enumerated()).filter { q.count < 2 || Core.matches($0.element.name, q) }
        VStack(spacing: 10) {
            Text("القنوات").font(rnd(20, .black)).foregroundStyle(Color.white).padding(.top, 18)
            SearchField(text: $q, hint: "دوّر على قناة…").padding(.horizontal, 16)
            ScrollViewReader { sp in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(list, id: \.element.id) { i, c in
                            Button { pick(i) } label: {
                                HStack(spacing: 12) {
                                    Text("\(i + 1)").font(rnd(12, .heavy)).foregroundStyle(PL.tx3).frame(width: 34)
                                    Art(url: c.logo, title: c.name).frame(width: 52, height: 36).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    Text(Core.clean(c.name)).font(rnd(15, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                                    Spacer(minLength: 0)
                                    if i == current { Image(systemName: "play.fill").font(.system(size: 12)).foregroundStyle(PL.live) }
                                }.padding(.horizontal, 10).padding(.vertical, 7).background(i == current ? PL.s2 : PL.s1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }.buttonStyle(Press()).id(i)
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 12)
                }.onAppear { sp.scrollTo(current, anchor: .center) }
            }
        }.background(PL.bg.ignoresSafeArea())
    }
}
