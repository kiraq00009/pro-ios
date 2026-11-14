import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct HomeView: View {
    @EnvironmentObject var lib: Library
    @State private var q = ""
    @State private var importing = false
    @State private var recording = Shot.name == "record"
    @State private var help = false

    var list: [Note] { lib.notes.filter { Search.match($0, q) } }

    var body: some View {
        NavigationStack {
            ZStack {
                SD.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        if !lib.notes.isEmpty { savedCard }
                        actions
                        if lib.notes.isEmpty { empty } else {
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundStyle(SD.tx3)
                                TextField("دوّر بكلّ البصمات: سعر، موعد، اسم…", text: $q).font(rnd(15))
                            }.padding(12).card(SD.s1, 16)
                            ForEach(list) { n in
                                NavigationLink(value: n.id) { NoteRow(note: n) }.buttonStyle(Press())
                                    .contextMenu {
                                        Button { lib.update(n.id) { $0.starred.toggle() } } label: { Label(n.starred ? "شيل النجمة" : "نجّمها", systemImage: "star") }
                                        if n.state == .failed { Button { lib.process(n.id) } label: { Label("أعد المحاولة", systemImage: "arrow.clockwise") } }
                                        Button(role: .destructive) { lib.remove(n.id) } label: { Label("احذف", systemImage: "trash") }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 30)
                }
            }
            .navigationDestination(for: UUID.self) { id in NoteDetail(id: id) }
            .navigationDestination(isPresented: Binding(get: { lib.open != nil }, set: { if !$0 { lib.open = nil } })) {
                if let id = lib.open { NoteDetail(id: id) }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio, .movie, .audiovisualContent, UTType(filenameExtension: "opus") ?? .audio, UTType(filenameExtension: "ogg") ?? .audio], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r { urls.forEach { lib.importFile($0) } }
        }
        .sheet(isPresented: $recording) { RecordSheet().presentationDetents([.large]) }
        .sheet(isPresented: $help) { ShareHelp().presentationDetents([.medium]) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("صدى").font(rnd(30, .heavy)).foregroundStyle(.white)
                Text("اقرا البصمات بدل ما تسمعها").font(rnd(13, .medium)).foregroundStyle(SD.tx3)
            }
            Spacer()
            Button { help = true } label: {
                Image(systemName: "questionmark").font(rnd(16, .bold)).foregroundStyle(.white).frame(width: 40, height: 40).background(SD.s2, in: Circle())
            }
        }.padding(.top, 8)
    }

    private var savedCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(SD.lime.opacity(0.16)).frame(width: 54, height: 54)
                Image(systemName: "hourglass").font(.system(size: 22, weight: .bold)).foregroundStyle(SD.lime)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("وفّرت \(Fmt.saved(lib.totalSaved)) سماع").font(rnd(18, .heavy)).foregroundStyle(.white)
                Text("\(lib.notes.count) بصمة · \(Fmt.dur(lib.notes.reduce(0) { $0 + $1.duration })) صوت كلّها مقروءة").font(rnd(12)).foregroundStyle(SD.tx2)
            }
            Spacer()
        }
        .padding(16)
        .background(LinearGradient(colors: [SD.lime.opacity(0.14), SD.violet.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(SD.lime.opacity(0.25)))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button { recording = true } label: { tile("سجّل اجتماع", "record.circle.fill", SD.coral) }.buttonStyle(Press())
            Button { importing = true } label: { tile("افتح ملفّ", "folder.fill", SD.violet) }.buttonStyle(Press())
        }
    }

    private func tile(_ t: String, _ i: String, _ c: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: i).font(.system(size: 22, weight: .bold))
            Text(t).font(rnd(15, .bold))
        }
        .foregroundStyle(c).frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(c.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(c.opacity(0.3)))
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("دزّ أيّ بصمة لصدى").font(rnd(20, .heavy)).foregroundStyle(.white)
            step(1, "بواتساب أو تليكرام اضغط مطوّلًا على البصمة")
            step(2, "اختار «إعادة توجيه/مشاركة» ثمّ أيقونة المشاركة")
            step(3, "اختار «صدى» — يطلعلك النصّ والملخّص بثواني")
            Text("يشتغل بالعربي (حتى العراقي) والفارسي والإنكليزي، والبصمات الفارسيّة تنترجم للعربي تلقائيًّا.")
                .font(rnd(13)).foregroundStyle(SD.tx2).padding(.top, 4)
        }
        .padding(18).card(SD.s1, 22).padding(.top, 8)
    }

    private func step(_ n: Int, _ t: String) -> some View {
        HStack(spacing: 12) {
            Text("\(n)").font(rnd(15, .heavy)).foregroundStyle(.black).frame(width: 30, height: 30).background(SD.lime, in: Circle())
            Text(t).font(rnd(15, .medium)).foregroundStyle(.white)
        }
    }
}

struct NoteRow: View {
    let note: Note
    var icon: String {
        switch note.source {
        case "واتساب": return "message.fill"
        case "تليكرام": return "paperplane.fill"
        case "تسجيل": return "mic.fill"
        case "فيديو": return "film.fill"
        default: return "waveform"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(rnd(12, .bold)).foregroundStyle(SD.violet)
                Text(note.source).font(rnd(12, .semibold)).foregroundStyle(SD.tx3)
                if let l = note.lang { Text(l.flag).font(rnd(12)) }
                if note.starred { Image(systemName: "star.fill").font(rnd(11)).foregroundStyle(SD.lime) }
                Spacer()
                Text(agoText(note.created)).font(rnd(11)).foregroundStyle(SD.tx3)
                if note.duration > 0 { Text(Fmt.dur(note.duration)).font(rnd(11, .bold)).foregroundStyle(SD.tx2) }
            }
            Text(note.state == .done ? note.title : stateText).font(rnd(17, .bold)).foregroundStyle(.white).lineLimit(1)
            if note.state == .done, let s = note.summary?.summary, !s.isEmpty {
                Text(s).font(rnd(13)).foregroundStyle(SD.tx2).lineLimit(2).multilineTextAlignment(.leading)
            } else if note.state == .failed {
                Text(note.error ?? "").font(rnd(12)).foregroundStyle(SD.coral).lineLimit(2)
            } else if note.state != .done {
                ProgressView().tint(SD.lime).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(SD.s1, 18)
    }
    var stateText: String {
        switch note.state {
        case .waiting: return "بالدور…"
        case .transcribing: return "أكتب الكلام…"
        case .summarizing: return "ألخّص…"
        case .failed: return "ما نجح"
        case .done: return note.title
        }
    }
}

// MARK: - تفاصيل البصمة

struct NoteDetail: View {
    @EnvironmentObject var lib: Library
    @StateObject private var player = Player()
    let id: UUID
    @State private var showAr = Shot.name == "trans"
    @State private var copied = false

    var note: Note? { lib.notes.first { $0.id == id } }

    var body: some View {
        ZStack(alignment: .bottom) {
            SD.bg.ignoresSafeArea()
            if let n = note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        meta(n)
                        if n.state == .done || n.summary != nil { summary(n) }
                        else if n.state == .failed { failed(n) }
                        else { working(n) }
                        if !n.segments.isEmpty { transcript(n) }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 120)
                }
                if Audio.playable(lib.url(n)) || Shot.on { playerBar(n) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let n = note, n.state == .done {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: shareText(n)) { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
        .onAppear { if let n = note, !Shot.on { player.load(lib.url(n)) } }
        .onDisappear { player.stop() }
    }

    private func meta(_ n: Note) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(n.title).font(rnd(24, .heavy)).foregroundStyle(.white)
            HStack(spacing: 10) {
                Label(n.source, systemImage: "waveform").foregroundStyle(SD.violet)
                if n.duration > 0 { Text(Fmt.dur(n.duration)) }
                if let l = n.lang { Text("\(l.flag) \(l.name)") }
                Text(n.created.formatted(date: .abbreviated, time: .shortened))
            }.font(rnd(12, .semibold)).foregroundStyle(SD.tx3)
        }.padding(.top, 6)
    }

    private func summary(_ n: Note) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let s = n.summary {
                VStack(alignment: .leading, spacing: 8) {
                    Label("الخلاصة", systemImage: "sparkles").font(rnd(14, .heavy)).foregroundStyle(SD.lime)
                    Text(s.summary).font(rnd(17, .semibold)).foregroundStyle(.white).lineSpacing(4).textSelection(.enabled)
                }
                if !s.points.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("أهمّ النقاط").font(rnd(13, .heavy)).foregroundStyle(SD.tx3)
                        ForEach(Array(s.points.enumerated()), id: \.offset) { _, p in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(SD.violet).frame(width: 6, height: 6).padding(.top, 8)
                                Text(p).font(rnd(15)).foregroundStyle(SD.tx2)
                            }
                        }
                    }
                }
                if !s.actions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("مواعيد وأرقام ومطلوب منك").font(rnd(13, .heavy)).foregroundStyle(SD.tx3)
                        ForEach(Array(s.actions.enumerated()), id: \.offset) { _, a in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle").foregroundStyle(SD.coral)
                                Text(a).font(rnd(14, .semibold)).foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(10).background(SD.coral.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                HStack {
                    Button {
                        UIPasteboard.general.string = shareText(n); copied = true; Haptic.tap()
                    } label: { Label(copied ? "انسخت" : "انسخ الكلّ", systemImage: copied ? "checkmark" : "doc.on.doc") }
                    Spacer()
                    if let e = s.engine { Text(engineName(e)).font(rnd(11)).foregroundStyle(SD.tx3) }
                }.font(rnd(13, .bold)).foregroundStyle(SD.lime)
            }
        }
        .padding(16).card(SD.s1, 22)
    }

    private func working(_ n: Note) -> some View {
        HStack(spacing: 12) {
            ProgressView().tint(SD.lime)
            VStack(alignment: .leading, spacing: 3) {
                Text(n.state == .summarizing ? "ألخّص الكلام…" : "أكتب الكلام اللي بالبصمة…").font(rnd(16, .bold)).foregroundStyle(.white)
                Text("البصمة الطويلة تاخذ وقت أكثر — تگدر تطلع وترجع").font(rnd(12)).foregroundStyle(SD.tx3)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).card(SD.s1, 20)
    }

    private func failed(_ n: Note) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ما نجح التفريغ", systemImage: "exclamationmark.triangle.fill").font(rnd(16, .bold)).foregroundStyle(SD.coral)
            Text(n.error ?? "").font(rnd(14)).foregroundStyle(SD.tx2)
            Button { lib.process(n.id) } label: {
                Text("أعد المحاولة").font(rnd(15, .heavy)).foregroundStyle(.black).padding(.horizontal, 20).padding(.vertical, 10).background(SD.lime, in: Capsule())
            }
        }.padding(16).card(SD.s1, 20)
    }

    private func transcript(_ n: Note) -> some View {
        let cur = n.segmentIndex(at: player.time)
        let hasTr = n.translation != nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("الكلام كامل").font(rnd(14, .heavy)).foregroundStyle(SD.tx3)
                Spacer()
                if hasTr {
                    Picker("", selection: $showAr) {
                        Text("الأصل").tag(false)
                        Text("بالعربي").tag(true)
                    }.pickerStyle(.segmented).frame(width: 170)
                } else if let l = n.lang, l != .ar {
                    Button { lib.translate(n.id) } label: { Label("ترجم للعربي", systemImage: "character.bubble") }.font(rnd(13, .bold))
                }
            }
            ForEach(Array(n.segments.enumerated()), id: \.offset) { i, s in
                let active = player.playing && cur == i
                HStack(alignment: .top, spacing: 10) {
                    Text(Fmt.dur(s.s)).font(rnd(11, .bold)).foregroundStyle(active ? SD.lime : SD.tx3).frame(width: 40, alignment: .leading)
                    Text(showAr && hasTr ? (n.translation?[safe: i] ?? s.text) : s.text)
                        .font(rnd(16, active ? .bold : .regular)).foregroundStyle(active ? .white : SD.tx2)
                        .environment(\.layoutDirection, (showAr || (n.lang?.rtl ?? true)) ? .rightToLeft : .leftToRight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 6).padding(.horizontal, 8)
                .background(active ? SD.lime.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
                .onTapGesture { player.seek(s.s) }
            }
        }
        .padding(16).card(SD.s1, 22)
    }

    private func playerBar(_ n: Note) -> some View {
        let total = max(player.duration, n.duration, 1)
        return VStack(spacing: 8) {
            ProgressView(value: min(player.time, total), total: total).tint(SD.lime)
            HStack {
                Text(Fmt.dur(player.time)).font(rnd(12, .bold)).foregroundStyle(SD.tx3)
                Spacer()
                Button { player.seek(max(0, player.time - 10)) } label: { Image(systemName: "gobackward.10") }
                Button { player.toggle() } label: {
                    Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 54, height: 54).background(SD.lime, in: Circle())
                }.padding(.horizontal, 18)
                Button { player.seek(player.time + 10) } label: { Image(systemName: "goforward.10") }
                Spacer()
                Button { player.cycleRate() } label: {
                    Text(player.rate == 1 ? "1×" : (player.rate == 1.5 ? "1.5×" : "2×")).font(rnd(13, .heavy)).frame(width: 44)
                }
            }
            .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 26)
        .background(.ultraThinMaterial)
    }

    private func engineName(_ e: String) -> String {
        switch e {
        case "gemini": return "ملخّص ذكيّ"
        case "local": return "ملخّص موديلنا"
        case "device", "basic": return "ملخّص سريع على الجهاز"
        default: return ""
        }
    }

    private func shareText(_ n: Note) -> String {
        var t = "🎙 \(n.title)\n"
        if let s = n.summary {
            t += "\n\(s.summary)\n"
            if !s.points.isEmpty { t += "\n" + s.points.map { "• \($0)" }.joined(separator: "\n") + "\n" }
            if !s.actions.isEmpty { t += "\n✅ " + s.actions.joined(separator: "\n✅ ") + "\n" }
        }
        t += "\n— النصّ —\n" + n.text
        return t
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - التسجيل

struct RecordSheet: View {
    @EnvironmentObject var lib: Library
    @Environment(\.dismiss) var dismiss
    @StateObject private var rec = Recorder()
    @State private var denied = false
    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 40)

    var body: some View {
        ZStack {
            SD.bg.ignoresSafeArea()
            VStack(spacing: 26) {
                HStack {
                    Button("إلغاء") { _ = rec.stop(); dismiss() }.foregroundStyle(SD.tx2)
                    Spacer()
                }.padding(.horizontal, 20).padding(.top, 14)
                Spacer()
                Text(Fmt.dur(Shot.on ? 1_934 : rec.time)).font(.system(size: 64, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                Text(rec.paused ? "موقّف مؤقّتًا" : (rec.on || Shot.on ? "أسجّل… تگدر تقفل الشاشة" : "اضغط حتى تبدي")).font(rnd(15, .semibold)).foregroundStyle(SD.tx3)
                HStack(alignment: .center, spacing: 4) {
                    ForEach(0..<bars.count, id: \.self) { i in
                        Capsule().fill(SD.coral.opacity(0.4 + Double(bars[i]) * 0.6)).frame(width: 4, height: 8 + bars[i] * 70)
                    }
                }.frame(height: 90)
                Spacer()
                if denied { Text("اسمح للمايك من الإعدادات").foregroundStyle(SD.coral) }
                HStack(spacing: 40) {
                    if rec.on {
                        Button { rec.pause() } label: {
                            Image(systemName: rec.paused ? "play.fill" : "pause.fill").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 64, height: 64).background(SD.s2, in: Circle())
                        }
                    }
                    Button {
                        if rec.on {
                            if let r = rec.stop() {
                                let keep = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
                                try? FileManager.default.moveItem(at: r.0, to: keep)
                                lib.addRecording(keep, duration: r.1)
                            }
                            dismiss()
                        } else {
                            Task { denied = !(await rec.start()) }
                        }
                    } label: {
                        ZStack {
                            Circle().stroke(SD.coral.opacity(0.4), lineWidth: 5).frame(width: 92, height: 92)
                            if rec.on { RoundedRectangle(cornerRadius: 8).fill(SD.coral).frame(width: 34, height: 34) }
                            else { Circle().fill(SD.coral).frame(width: 72, height: 72) }
                        }
                    }
                }
                Text("الاجتماعات والمحاضرات تنكتب وتتلخّص لحالها").font(rnd(12)).foregroundStyle(SD.tx3).padding(.bottom, 26)
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            let v: CGFloat = Shot.on ? CGFloat.random(in: 0.1...0.9) : CGFloat(rec.paused ? 0.05 : rec.level)
            bars.removeFirst(); bars.append(rec.on || Shot.on ? v : 0.08)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

struct ShareHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("شلون أستعمل صدى؟").font(rnd(22, .heavy)).foregroundStyle(.white)
            Label("بصمة واتساب: اضغط عليها مطوّلًا ← مشاركة ← صدى", systemImage: "message.fill")
            Label("تليكرام: اضغط البصمة ← مشاركة ← صدى", systemImage: "paperplane.fill")
            Label("اجتماع أو محاضرة: «سجّل اجتماع» ويكمل حتى لو قفلت الشاشة", systemImage: "mic.fill")
            Label("أيّ ملفّ صوت أو فيديو: «افتح ملفّ»", systemImage: "folder.fill")
            Label("اضغط أيّ جملة بالنصّ حتى تسمعها من مكانها", systemImage: "hand.tap.fill")
            Spacer()
        }
        .font(rnd(15, .medium)).foregroundStyle(SD.tx2).padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(SD.s1)
    }
}
