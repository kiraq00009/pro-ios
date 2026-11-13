import SwiftUI

/// معالج بطولة جديدة: النوع ⇠ اللاعبين ⇠ الخيارات ⇠ قرعة الفرق
struct CreateView: View {
    let done: (Tournament) -> Void
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var name = ""
    @State private var format: Format = .league
    @State private var picked: Set<UUID> = []
    @State private var twoLegs = false
    @State private var drawClubs = true
    @State private var draft: Tournament? = nil
    @State private var revealed = 0

    private var minPlayers: Int { format == .groups ? 6 : 2 }
    private var order: [UUID] { store.members.map { $0.id }.filter { picked.contains($0) } }
    private var matchCount: Int {
        let n = picked.count
        switch format {
        case .league: return n * (n - 1) / 2 * (twoLegs ? 2 : 1)
        case .cup: return max(0, n - 1)
        case .groups:
            let gc = n >= 12 ? 4 : 2
            var total = 0
            for g in 0..<gc { let k = n / gc + (g < n % gc ? 1 : 0); total += k * (k - 1) / 2 * (twoLegs ? 2 : 1) }
            return total + gc * 2 - 1
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { if step == 0 || draft != nil { dismiss() } else { withAnimation { step -= 1 } } } label: {
                    Image(systemName: step == 0 || draft != nil ? "xmark" : "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.white).frame(width: 40, height: 40).background(DR.s2, in: Circle())
                }.buttonStyle(Press())
                Spacer()
                HStack(spacing: 6) { ForEach(0..<3, id: \.self) { i in Capsule().fill(i <= step ? DR.green : DR.s3).frame(width: i == step ? 26 : 10, height: 6) } }
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }.padding(.horizontal, 18).padding(.top, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if draft != nil { drawStep } else if step == 0 { formatStep } else if step == 1 { playersStep } else { optionsStep }
                }.padding(20)
            }.scrollDismissesKeyboard(.immediately)

            if draft == nil {
                BigButton(title: step == 2 ? "ابدي البطولة" : "التالي", icon: step == 2 ? "flag.checkered" : "") { next() }
                    .opacity(canNext ? 1 : 0.4).disabled(!canNext).padding(.horizontal, 20).padding(.bottom, 14)
            }
        }
        .background(DR.bg.ignoresSafeArea())
        .onAppear {
            guard Shot.on else { return }
            name = "كأس الربع"
            picked = Set(store.members.prefix(6).map { $0.id })
            if Shot.name == "create2" { step = 1 }
            if Shot.name == "create3" { step = 2; format = .groups; picked = Set(store.members.map { $0.id }) }
        }
    }

    private var canNext: Bool {
        switch step {
        case 0: return true
        case 1: return picked.count >= minPlayers
        default: return true
        }
    }
    private func next() {
        Haptic.tap()
        if step < 2 { withAnimation { step += 1 }; return }
        var clubs: [String: String] = [:]
        if drawClubs { let pool = DR.clubs.shuffled(); for (i, id) in order.enumerated() { clubs[id.uuidString] = pool[i % pool.count] } }
        let title = name.trimmingCharacters(in: .whitespaces).isEmpty ? DR.formatName(format) + " " + Date().formatted(date: .abbreviated, time: .omitted) : name
        let t = Engine.make(name: title, format: format, legs: twoLegs ? 2 : 1, members: order, clubs: clubs)
        store.add(t)
        if drawClubs { withAnimation { draft = t }; reveal() } else { Haptic.ok(); done(t) }
    }
    private func reveal() {
        guard let t = draft, revealed < t.members.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { revealed += 1 }; Haptic.thud(); reveal() }
    }

    // ── ١: الاسم والنوع
    private var formatStep: some View {
        Group {
            title("بطولة جديدة", "سمّها واختار نوعها")
            TextField("", text: $name, prompt: Text("اسم البطولة — مثلًا: دوري الخميس").foregroundColor(DR.tx3)).font(rnd(17, .heavy)).foregroundStyle(Color.white)
                .padding(.horizontal, 16).frame(height: 54).background(DR.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            kind(.league, "list.number", "دوري", "الكلّ يلاعب الكلّ، والأكثر نقاطًا هو البطل", "من لاعبين")
            kind(.cup, "trophy.fill", "كأس خروج مغلوب", "اللي يخسر يطلع — لحدّ ما يبقى واحد", "من لاعبين")
            kind(.groups, "square.grid.2x2.fill", "مجموعات + إقصاء", "مجموعات أوّلًا، وأوّل اثنين من كلّ مجموعة يكمّلون", "من ٦ لاعبين")
        }
    }
    private func kind(_ f: Format, _ icon: String, _ t: String, _ s: String, _ min: String) -> some View {
        let on = format == f
        return Button { Haptic.tap(); format = f } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(on ? DR.onGreen : DR.green).frame(width: 52, height: 52)
                    .background(on ? DR.green : DR.green.opacity(0.13), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) { Text(t).font(rnd(17, .heavy)).foregroundStyle(Color.white); Pill(text: min, tint: DR.tx2) }
                    Text(s).font(rnd(12.5)).foregroundStyle(DR.tx3).lineSpacing(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 20)).foregroundStyle(on ? DR.green : DR.s3)
            }
            .padding(14).card(DR.s1, 20, stroke: on ? DR.green.opacity(0.6) : Color(white: 1, opacity: 0.07))
        }.buttonStyle(Press())
    }

    // ── ٢: اللاعبين
    private var playersStep: some View {
        Group {
            title("منو يلعب؟", picked.count < minPlayers ? "اختار \(minPlayers) لاعبين على الأقلّ" : "\(picked.count) لاعبين — لحدّ ١٦")
            MemberPicker(selected: $picked)
        }
    }

    // ── ٣: الخيارات
    private var optionsStep: some View {
        Group {
            title("آخر شي", "\(picked.count) لاعبين · \(matchCount) مباراة")
            if format != .cup {
                toggle($twoLegs, "arrow.left.arrow.right", "ذهاب وإياب", "كلّ اثنين يتقابلون مرّتين")
            }
            toggle($drawClubs, "dice.fill", "قرعة الفرق", "كلّ لاعب يطلعله نادي أو منتخب عشوائيّ يلعب بيه")
            VStack(alignment: .leading, spacing: 10) {
                Text("الخلاصة").font(rnd(14, .heavy)).foregroundStyle(DR.tx2)
                row("النوع", DR.formatName(format))
                row("اللاعبين", "\(picked.count)")
                row("عدد المباريات", "\(matchCount)")
                if format == .groups { row("المجموعات", picked.count >= 12 ? "٤ مجموعات" : "مجموعتين") }
            }.padding(16).card(DR.s1, 20)
        }
    }
    private func toggle(_ b: Binding<Bool>, _ icon: String, _ t: String, _ s: String) -> some View {
        Toggle(isOn: b) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(DR.green).frame(width: 40, height: 40).background(DR.green.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) { Text(t).font(rnd(16, .heavy)).foregroundStyle(Color.white); Text(s).font(rnd(12)).foregroundStyle(DR.tx3) }
            }
        }.tint(DR.green).padding(14).card(DR.s1, 20)
    }
    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(rnd(14)).foregroundStyle(DR.tx3); Spacer(); Text(v).font(rnd(15, .heavy)).foregroundStyle(Color.white) }
    }
    private func title(_ t: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(t).font(rnd(28, .black)).foregroundStyle(Color.white); Text(s).font(rnd(14)).foregroundStyle(DR.tx3) }
    }

    // ── القرعة
    private var drawStep: some View {
        let t = draft!
        return Group {
            title("قرعة الفرق", "كلّ واحد وحظّه")
            ForEach(Array(t.members.enumerated()), id: \.element) { i, id in
                HStack(spacing: 12) {
                    Avatar(name: store.name(id), color: store.tint(id), size: 40)
                    Text(store.name(id)).font(rnd(17, .heavy)).foregroundStyle(Color.white)
                    Spacer()
                    if i < revealed {
                        Text(t.club(id)).font(rnd(15, .black)).foregroundStyle(DR.gold).padding(.horizontal, 12).frame(height: 34).background(DR.gold.opacity(0.14), in: Capsule())
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    } else { Image(systemName: "questionmark").font(.system(size: 14, weight: .black)).foregroundStyle(DR.tx3).frame(width: 34, height: 34).background(DR.s3, in: Circle()) }
                }.padding(12).card(DR.s1, 18)
            }
            BigButton(title: "يلّا نلعب", icon: "play.fill") { Haptic.ok(); done(t) }.opacity(revealed >= t.members.count ? 1 : 0.35).disabled(revealed < t.members.count).padding(.top, 6)
        }
    }
}
