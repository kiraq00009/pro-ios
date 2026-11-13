import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var lib: Library
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Profile? = nil
    @State private var adding = false
    @State private var del: Profile? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let p = lib.current, p.kind == .xtream { account }
                    section("الاشتراكات")
                    ForEach(lib.profiles) { p in profileRow(p) }
                    Button { adding = true } label: {
                        Label("ضيف اشتراك", systemImage: "plus.circle.fill").font(rnd(15, .heavy)).foregroundStyle(PL.ac).frame(maxWidth: .infinity).frame(height: 50).card(PL.s1, 16, stroke: PL.ac.opacity(0.35))
                    }.buttonStyle(Press())

                    section("المكتبة")
                    VStack(spacing: 0) {
                        Button { Task { await lib.refresh() } } label: {
                            rowLabel("arrow.clockwise", "حدّث المكتبة", lib.loading ? (lib.progress.isEmpty ? "دا يحدّث…" : lib.progress) : updated, PL.ac)
                        }.buttonStyle(Press()).disabled(lib.loading)
                        Divider().overlay(Color(white: 1, opacity: 0.06))
                        Toggle(isOn: Binding(get: { lib.hideAdult }, set: { lib.setHideAdult($0) })) {
                            HStack(spacing: 12) {
                                icon("eye.slash.fill", PL.live)
                                VStack(alignment: .leading, spacing: 1) { Text("إخفاء أقسام البالغين").font(rnd(15, .heavy)).foregroundStyle(Color.white); Text("تختفي من القوائم والبحث").font(rnd(12)).foregroundStyle(PL.tx3) }
                            }
                        }.tint(PL.ac).padding(.horizontal, 12).padding(.vertical, 10)
                    }.card(PL.s1, 18)

                    Text("بلاير مشغّل فقط وما يوفّر أيّ محتوى. الاشتراك ومحتواه مسؤوليّة صاحبه.\nالأفلام بصيغة MKV تنفتح ببرنامج VLC.").font(rnd(11.5)).foregroundStyle(PL.tx3).lineSpacing(3)
                }.padding(18)
            }
            .background(PL.bg.ignoresSafeArea())
            .navigationTitle("الإعدادات").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("تمام") { dismiss() }.font(rnd(15, .heavy)) } }
            .sheet(item: $editing) { p in ProfileEditor(profile: p).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
            .sheet(isPresented: $adding) { ProfileEditor(profile: nil).environmentObject(lib).environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.dark) }
            .alert("تمسح «\(del?.name ?? "")»؟", isPresented: Binding(get: { del != nil }, set: { if !$0 { del = nil } })) {
                Button("امسحه", role: .destructive) { if let p = del { lib.remove(p) } }
                Button("إلغاء", role: .cancel) {}
            } message: { Text("مفضّلاتك ومواضع المشاهدة لهالاشتراك تنمسح وياه.") }
        }
    }

    private var updated: String { lib.content.at > 0 ? "آخر تحديث " + agoText(Date(timeIntervalSince1970: lib.content.at)) : "ما تحدّثت بعد" }
    private func section(_ t: String) -> some View { Text(t).font(rnd(16, .heavy)).foregroundStyle(Color.white).padding(.top, 4) }
    private func icon(_ n: String, _ c: Color) -> some View { Image(systemName: n).font(.system(size: 15, weight: .bold)).foregroundStyle(c).frame(width: 38, height: 38).background(c.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous)) }
    private func rowLabel(_ ic: String, _ t: String, _ s: String, _ c: Color) -> some View {
        HStack(spacing: 12) {
            icon(ic, c)
            VStack(alignment: .leading, spacing: 1) { Text(t).font(rnd(15, .heavy)).foregroundStyle(Color.white); Text(s).font(rnd(12)).foregroundStyle(PL.tx3).lineLimit(1) }
            Spacer()
        }.padding(.horizontal, 12).padding(.vertical, 10).contentShape(Rectangle())
    }

    private var account: some View {
        let a = lib.account
        let ok = a.status.lowercased() == "active"
        let days = a.exp.map { Int($0.timeIntervalSinceNow / 86400) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("حسابي").font(rnd(16, .heavy)).foregroundStyle(Color.white)
                Spacer()
                Tag(a.status.isEmpty ? "—" : (ok ? "فعّال" : a.status), ok ? PL.green : PL.live)
                if a.trial { Tag("تجريبيّ", PL.gold) }
            }
            HStack(spacing: 10) {
                stat(days.map { $0 < 0 ? "منتهي" : "\($0)" } ?? "∞", days.map { $0 < 0 ? "" : "يوم باقي" } ?? "بلا انتهاء", (days ?? 99) < 7 ? PL.live : PL.green)
                stat("\(a.active)/\(a.max)", "اتّصالات", a.max > 0 && a.active >= a.max ? PL.live : PL.ac)
                stat(a.exp.map { $0.formatted(.dateTime.day().month().year(.twoDigits)) } ?? "—", "ينتهي", PL.tx2)
            }
        }.padding(14).card(PL.s1, 20, stroke: (ok ? PL.green : PL.live).opacity(0.3))
    }
    private func stat(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) { Text(v).font(rnd(19, .black)).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.5); Text(l).font(rnd(11)).foregroundStyle(PL.tx3) }
            .frame(maxWidth: .infinity).padding(.vertical, 10).background(PL.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func profileRow(_ p: Profile) -> some View {
        let on = lib.current?.id == p.id
        return HStack(spacing: 12) {
            Button { if !on { lib.select(p, reload: false) } } label: {
                HStack(spacing: 12) {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(on ? PL.ac : PL.s3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(rnd(16, .heavy)).foregroundStyle(Color.white).lineLimit(1)
                        Text(p.kind == .xtream ? "Xtream · " + (URL(string: Core.normalize(server: p.server))?.host ?? p.server) : (p.kind == .m3u ? "قائمة M3U" : "نسخة تجريبيّة")).font(rnd(12)).foregroundStyle(PL.tx3).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(Press())
            if p.kind != .demo { Button { editing = p } label: { Image(systemName: "pencil").font(.system(size: 13, weight: .bold)).foregroundStyle(PL.tx2).frame(width: 36, height: 36).background(PL.s2, in: Circle()) }.buttonStyle(Press()) }
            Button { del = p } label: { Image(systemName: "trash").font(.system(size: 13, weight: .bold)).foregroundStyle(PL.live).frame(width: 36, height: 36).background(PL.live.opacity(0.12), in: Circle()) }.buttonStyle(Press())
        }.padding(12).card(PL.s1, 18, stroke: on ? PL.ac.opacity(0.45) : Color(white: 1, opacity: 0.07))
    }
}

/// إضافة أو تعديل اشتراك
struct ProfileEditor: View {
    let profile: Profile?
    @EnvironmentObject var lib: Library
    @Environment(\.dismiss) private var dismiss
    @State private var kind: SourceKind = .xtream
    @State private var name = ""
    @State private var server = ""
    @State private var user = ""
    @State private var pass = ""
    @State private var m3u = ""
    @State private var ua = "VLC/3.0.20 LibVLC/3.0.20"
    @State private var advanced = false

    private var valid: Bool {
        kind == .xtream ? (!Core.normalize(server: server).isEmpty && !user.isEmpty && !pass.isEmpty) : (URL(string: m3u.trimmingCharacters(in: .whitespaces))?.scheme?.hasPrefix("http") ?? false)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(profile == nil ? "اشتراك جديد" : "عدّل الاشتراك").font(rnd(26, .black)).foregroundStyle(Color.white)
                Picker("", selection: $kind) { Text("Xtream Codes").tag(SourceKind.xtream); Text("رابط M3U").tag(SourceKind.m3u) }.pickerStyle(.segmented)
                field("الاسم (اختياريّ)", $name, "tag.fill")
                if kind == .xtream {
                    field("عنوان السيرفر — مثلًا example.com:8080", $server, "server.rack", url: true)
                    field("اسم المستخدم", $user, "person.fill", url: true)
                    field("كلمة السرّ", $pass, "key.fill", url: true, secure: true)
                    Text("هذي البيانات ينطيها إلك مزوّد الاشتراك. تنحفظ على جهازك فقط.").font(rnd(12)).foregroundStyle(PL.tx3)
                } else {
                    field("رابط القائمة — https://…/list.m3u", $m3u, "link", url: true)
                    Text("إذا الرابط من نوع get.php (Xtream) نحوّله تلقائيًّا حتى تطلع الأفلام والمسلسلات مرتّبة.").font(rnd(12)).foregroundStyle(PL.tx3)
                }
                Button { withAnimation { advanced.toggle() } } label: { Label("خيارات متقدّمة", systemImage: advanced ? "chevron.up" : "chevron.down").font(rnd(13, .heavy)).foregroundStyle(PL.tx3) }.buttonStyle(.plain)
                if advanced {
                    field("User-Agent", $ua, "antenna.radiowaves.left.and.right", url: true)
                    Text("بعض المزوّدين ما يقبلون إلّا تعريف مشغّل معيّن. الافتراضيّ (VLC) يمشي ويّا أغلبهم.").font(rnd(12)).foregroundStyle(PL.tx3)
                }
                Button(action: save) {
                    Text(profile == nil ? "اربط وحمّل المكتبة" : "حفظ").font(rnd(17, .heavy)).foregroundStyle(Color.white).frame(maxWidth: .infinity).frame(height: 54)
                        .background(LinearGradient(colors: [PL.ac, PL.ac2], startPoint: .leading, endPoint: .trailing), in: Capsule())
                }.buttonStyle(Press()).disabled(!valid).opacity(valid ? 1 : 0.4).padding(.top, 6)
            }.padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PL.bg.ignoresSafeArea())
        .onAppear {
            if let p = profile { kind = p.kind == .m3u ? .m3u : .xtream; name = p.name; server = p.server; user = p.user; pass = p.pass; m3u = p.m3u; ua = p.ua }
            if Shot.name == "add" { server = "tv.example.com:8080"; user = "myuser"; pass = "secret"; name = "اشتراكي" }
        }
    }
    private func field(_ hint: String, _ text: Binding<String>, _ icon: String, url: Bool = false, secure: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(PL.ac).frame(width: 22)
            Group {
                if secure { SecureField("", text: text, prompt: Text(hint).foregroundColor(PL.tx3)) }
                else { TextField("", text: text, prompt: Text(hint).foregroundColor(PL.tx3)) }
            }
            .font(rnd(15, .bold)).foregroundStyle(Color.white)
            .textInputAutocapitalization(url ? .never : .sentences).autocorrectionDisabled(url).keyboardType(url && !secure ? .URL : .default)
            .environment(\.layoutDirection, url ? .leftToRight : .rightToLeft)
        }.padding(.horizontal, 14).frame(height: 52).background(PL.s2, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
    private func save() {
        var p = profile ?? Profile(name: "", kind: kind)
        p.kind = kind; p.ua = ua.trimmingCharacters(in: .whitespaces).isEmpty ? "VLC/3.0.20 LibVLC/3.0.20" : ua
        if kind == .m3u, let x = Core.xtream(fromM3U: m3u) { p.kind = .xtream; p.server = x.server; p.user = x.user; p.pass = x.pass; p.m3u = "" }
        else if kind == .xtream { p.server = Core.normalize(server: server); p.user = user.trimmingCharacters(in: .whitespaces); p.pass = pass.trimmingCharacters(in: .whitespaces) }
        else { p.m3u = m3u.trimmingCharacters(in: .whitespaces) }
        let host = URL(string: p.kind == .xtream ? p.server : p.m3u)?.host ?? ""
        p.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? (host.isEmpty ? "اشتراكي" : host) : name
        if profile == nil { lib.add(p) } else { lib.update(p) }
        Haptic.ok(); dismiss()
    }
}
