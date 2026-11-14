import SwiftUI

// MARK: - HOME

struct HomeView: View {
    var go: (Tab) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                grid
                DawwirliButton()
                Text("كل الاقتراحات عامّة وبلا حرق. القرار النهائي إلكم 🍿")
                    .font(rnd(11)).foregroundStyle(DW.faint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(16)
            .padding(.top, 8)
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "popcorn.fill").font(.system(size: 20))
                    .foregroundStyle(DW.orange)
                Text("دورلي").font(rnd(14, weight: .bold)).foregroundStyle(DW.dim)
            }
            Text("ليلة فيلم")
                .font(rnd(46, weight: .black))
                .foregroundStyle(DW.grad)
            Text("ما تدرون شتشوفون؟ خلّينا نقرّر")
                .font(rnd(16, weight: .semibold))
                .foregroundStyle(DW.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(DW.card)
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(RadialGradient(colors: [DW.orange.opacity(0.28), .clear],
                                         center: .top, startRadius: 10, endRadius: 260))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(DW.stroke, lineWidth: 1)
        )
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            toolCard(.wheel, "عجلة الليلة", "دوّر واطلع نوع", "dial.medium.fill")
            toolCard(.duel, "هذا أو هذا", "صفّي للفائز", "arrow.left.arrow.right")
            toolCard(.vote, "تصويت المجموعة", "صوّتوا وشوفوا الفائز", "chart.bar.fill")
            toolCard(.guess, "خمّن", "لعبة معلومات أفلام", "questionmark.circle.fill")
        }
    }

    private func toolCard(_ t: Tab, _ title: String, _ sub: String, _ icon: String) -> some View {
        Button {
            Haptic.tap()
            go(t)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DW.grad).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                }
                Text(title).font(rnd(17, weight: .bold)).foregroundStyle(DW.text)
                Text(sub).font(rnd(12)).foregroundStyle(DW.dim)
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(14)
        }
        .buttonStyle(Press())
        .card(bg: DW.card, r: 20, stroke: DW.stroke)
    }
}

// MARK: - 1. WHEEL

struct WheelView: View {
    private let genres = Wheel.genres()
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var result: Genre? = nil

    private var slice: Double { 360.0 / Double(genres.count) }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Header(title: "عجلة الليلة", sub: "دوّرها وخلّيها تختار النوع عنكم")
                wheel
                Button(action: spin) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(spinning ? "تدور…" : "دوّر العجلة")
                            .font(rnd(18, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(DW.grad, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(spinning ? 0.6 : 1)
                }
                .buttonStyle(Press())
                .disabled(spinning)

                if let r = result {
                    resultCard(r)
                }
            }
            .padding(16)
        }
        .onAppear(perform: seedShot)
    }

    private var wheel: some View {
        ZStack {
            Circle().fill(AngularGradient(
                colors: [DW.orange, DW.orange2, Color(red: 0.9, green: 0.3, blue: 0.1),
                         DW.orange2, DW.orange, Color(red: 0.8, green: 0.25, blue: 0.08), DW.orange],
                center: .center))
            Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 2)

            ForEach(Array(genres.enumerated()), id: \.offset) { pair in
                labelSpoke(pair.element, index: pair.offset)
            }
            .rotationEffect(.degrees(rotation))

            // hub
            Circle().fill(DW.bg).frame(width: 64, height: 64)
                .overlay(Circle().stroke(DW.grad, lineWidth: 3))
            Image(systemName: "film.fill").foregroundStyle(DW.orange).font(.system(size: 22))
        }
        .frame(width: 300, height: 300)
        .overlay(alignment: .top) { pointer }
        .shadow(color: DW.orange.opacity(0.25), radius: 24, y: 10)
    }

    private var pointer: some View {
        Image(systemName: "triangle.fill")
            .font(.system(size: 26))
            .foregroundStyle(DW.text)
            .rotationEffect(.degrees(180))
            .offset(y: -8)
            .shadow(radius: 4)
    }

    private func labelSpoke(_ g: Genre, index: Int) -> some View {
        VStack(spacing: 2) {
            Text(g.emoji).font(.system(size: 20))
            Text(g.name).font(rnd(12, weight: .bold)).foregroundStyle(.black)
                .fixedSize()
        }
        .rotationEffect(.degrees(Double(index) * slice + slice / 2))
        .offset(y: -110)
        .rotationEffect(.degrees(Double(index) * slice))
    }

    private func resultCard(_ g: Genre) -> some View {
        VStack(spacing: 10) {
            Text("الليلة شوفوا…").font(rnd(14, weight: .semibold)).foregroundStyle(DW.dim)
            Text("\(g.emoji)  \(g.name)")
                .font(rnd(34, weight: .black)).foregroundStyle(DW.grad)
            Text(g.vibe).font(rnd(14)).foregroundStyle(DW.text)
                .multilineTextAlignment(.center)
            DawwirliButton(deepLink: nil).padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .card(bg: DW.card, r: 22, stroke: DW.orange.opacity(0.35))
        .transition(.scale.combined(with: .opacity))
    }

    private func spin() {
        guard !spinning else { return }
        spinning = true
        result = nil
        let seed = Int.random(in: 0..<1_000_000)
        let picked = Wheel.spin(seed: seed)
        let idx = genres.firstIndex(of: picked) ?? 0
        let target = -(Double(idx) * slice)
        let base = rotation - rotation.truncatingRemainder(dividingBy: 360)
        let newRotation = base + 360 * 6 + target
        withAnimation(.easeOut(duration: 2.6)) {
            rotation = newRotation
        }
        // haptic ticks while it slows down
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(i)) {
                if self.spinning { Haptic.tap() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            Haptic.ok()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.result = picked
            }
            self.spinning = false
            Store.lastWheel = picked.name
        }
    }

    private func seedShot() {
        guard Shot.on, Shot.isAny("wheel") else { return }
        let g = genres.first { $0.name == "إثارة" } ?? genres[0]
        let idx = genres.firstIndex(of: g) ?? 0
        rotation = -(Double(idx) * slice)
        result = g
    }
}

// MARK: - 2. THIS-OR-THAT (knockout)

private let duelPacks: [(String, [String])] = [
    ("سهرة خفيفة", ["كوميدي هادئ", "رومنسي دافئ", "عائليّ مرح", "مغامرة بسيطة"]),
    ("ليلة حماس", ["أكشن متفجّر", "إثارة وتوتر", "خيال علميّ", "جريمة ولغز"]),
    ("جوّ الرعب", ["رعب كلاسيكي", "رعب نفسيّ", "غموض مخيف", "إثارة مرعبة"])
]

struct DuelView: View {
    @State private var options: [String] = []
    @State private var typing: String = ""
    @State private var bracket: Bracket? = nil
    @State private var match: (String, String)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Header(title: "هذا أو هذا", sub: "ضيف ترشيحاتكم وصفّوهم لين يبقى فائز واحد")
                if bracket == nil { setup } else { arena }
            }
            .padding(16)
        }
        .onAppear(perform: seedShot)
    }

    // --- setup ---
    private var setup: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                TextField("اكتب ترشيح…", text: $typing)
                    .font(rnd(15))
                    .padding(12)
                    .background(DW.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(DW.text)
                Button {
                    addTyped()
                } label: {
                    Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black).frame(width: 46, height: 46)
                        .background(DW.grad, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(Press())
            }

            if !options.isEmpty {
                chips
            }

            Text("أو اختاروا باقة جاهزة:").font(rnd(12)).foregroundStyle(DW.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(duelPacks.enumerated()), id: \.offset) { pair in
                packRow(pair.element.0, pair.element.1)
            }

            Button(action: start) {
                Text("يلا نبدي التصفية")
                    .font(rnd(17, weight: .bold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(DW.grad, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(options.count >= 2 ? 1 : 0.4)
            }
            .buttonStyle(Press())
            .disabled(options.count < 2)
        }
    }

    private var chips: some View {
        FlowChips(items: options) { item in
            withAnimation { options.removeAll { $0 == item } }
        }
    }

    private func packRow(_ name: String, _ items: [String]) -> some View {
        Button {
            Haptic.tap()
            withAnimation { options = items }
        } label: {
            HStack {
                Text(name).font(rnd(15, weight: .bold)).foregroundStyle(DW.text)
                Spacer()
                Text("\(items.count) ترشيحات").font(rnd(12)).foregroundStyle(DW.dim)
                Image(systemName: "chevron.left").foregroundStyle(DW.orange)
            }
            .padding(14)
        }
        .buttonStyle(Press())
        .card(bg: DW.card, r: 16, stroke: DW.stroke)
    }

    // --- arena ---
    private var arena: some View {
        VStack(spacing: 18) {
            if let b = bracket, let champ = b.champion {
                championCard(champ)
            } else if let m = match {
                Text("الجولة \(bracket?.round ?? 1)")
                    .font(rnd(13, weight: .semibold)).foregroundStyle(DW.dim)
                Text("أيّهما؟").font(rnd(26, weight: .heavy)).foregroundStyle(DW.text)
                optionCard(m.0)
                Text("أو").font(rnd(16, weight: .bold)).foregroundStyle(DW.orange)
                optionCard(m.1)
            }
            Button {
                Haptic.tap()
                reset()
            } label: {
                Text("من الأوّل").font(rnd(14, weight: .semibold)).foregroundStyle(DW.dim)
            }
            .buttonStyle(Press())
            .padding(.top, 6)
        }
    }

    private func optionCard(_ title: String) -> some View {
        Button {
            choose(title)
        } label: {
            HStack {
                Text(title).font(rnd(20, weight: .bold)).foregroundStyle(DW.text)
                Spacer()
                Image(systemName: "hand.tap.fill").foregroundStyle(DW.orange)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(Press())
        .card(bg: DW.card, r: 20, stroke: DW.orange.opacity(0.3))
    }

    private func championCard(_ champ: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy.fill").font(.system(size: 40)).foregroundStyle(DW.grad)
            Text("الفائز").font(rnd(14, weight: .semibold)).foregroundStyle(DW.dim)
            Text(champ).font(rnd(30, weight: .black)).foregroundStyle(DW.grad)
                .multilineTextAlignment(.center)
            Text("هذا اختيار الليلة ✨").font(rnd(13)).foregroundStyle(DW.dim)
            DawwirliButton().padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .card(bg: DW.card, r: 22, stroke: DW.orange.opacity(0.4))
    }

    // --- logic ---
    private func addTyped() {
        let t = typing.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !options.contains(t) else { return }
        Haptic.tap()
        withAnimation { options.append(t) }
        typing = ""
    }

    private func start() {
        guard options.count >= 2 else { return }
        Haptic.ok()
        var b = Bracket(options: options)
        match = b.next()
        bracket = b
    }

    private func choose(_ winner: String) {
        guard var b = bracket else { return }
        Haptic.tap()
        b.pick(winner)
        withAnimation { match = b.next() }
        bracket = b
    }

    private func reset() {
        withAnimation {
            bracket = nil
            match = nil
        }
    }

    private func seedShot() {
        guard Shot.on, Shot.isAny("duel"), bracket == nil else { return }
        options = ["أكشن متفجّر", "إثارة وتوتر", "خيال علميّ", "جريمة ولغز"]
        start()
    }
}

// MARK: - 3. GROUP VOTE

struct VoteView: View {
    @State private var options: [String] = ["كوميدي", "أكشن", "رعب"]
    @State private var typing: String = ""
    @State private var people: Int = 4
    @State private var votes: [Int] = []
    @State private var current: Int = 0
    @State private var phase: Phase = .setup

    enum Phase { case setup, voting, results }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Header(title: "تصويت المجموعة", sub: "مرّروا الهاتف وخلّي كل واحد يصوّت")
                switch phase {
                case .setup: setup
                case .voting: voting
                case .results: results
                }
            }
            .padding(16)
        }
        .onAppear(perform: seedShot)
    }

    // setup
    private var setup: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                TextField("اكتب خيار…", text: $typing)
                    .font(rnd(15)).padding(12)
                    .background(DW.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(DW.text)
                Button { addOption() } label: {
                    Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black).frame(width: 46, height: 46)
                        .background(DW.grad, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(Press())
            }
            if !options.isEmpty {
                FlowChips(items: options) { item in
                    withAnimation { options.removeAll { $0 == item } }
                }
            }
            stepper
            Button(action: startVote) {
                Text("ابدؤوا التصويت").font(rnd(17, weight: .bold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(DW.grad, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(options.count >= 2 ? 1 : 0.4)
            }
            .buttonStyle(Press())
            .disabled(options.count < 2)
        }
    }

    private var stepper: some View {
        HStack {
            Text("عدد الأشخاص").font(rnd(15, weight: .semibold)).foregroundStyle(DW.text)
            Spacer()
            Button { if people > 1 { people -= 1; Haptic.tap() } } label: {
                Image(systemName: "minus.circle.fill").font(.system(size: 28)).foregroundStyle(DW.orange)
            }.buttonStyle(Press())
            Text("\(people)").font(rnd(20, weight: .bold)).foregroundStyle(DW.text)
                .frame(minWidth: 34)
            Button { if people < 20 { people += 1; Haptic.tap() } } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundStyle(DW.orange)
            }.buttonStyle(Press())
        }
        .padding(14)
        .card(bg: DW.card, r: 16, stroke: DW.stroke)
    }

    // voting
    private var voting: some View {
        VStack(spacing: 14) {
            Text("دور الشخص \(current + 1) من \(people)")
                .font(rnd(15, weight: .bold)).foregroundStyle(DW.orange)
            Text("شنو تختار؟").font(rnd(24, weight: .heavy)).foregroundStyle(DW.text)
            ForEach(Array(options.enumerated()), id: \.offset) { pair in
                Button { castVote(pair.offset) } label: {
                    HStack {
                        Text(pair.element).font(rnd(18, weight: .bold)).foregroundStyle(DW.text)
                        Spacer()
                        Image(systemName: "circle").foregroundStyle(DW.faint)
                    }
                    .padding(18).frame(maxWidth: .infinity)
                }
                .buttonStyle(Press())
                .card(bg: DW.card, r: 16, stroke: DW.stroke)
            }
        }
    }

    // results
    private var results: some View {
        let t = Vote.tally(votes: votes, options: options.count)
        let maxC = max(1, t.counts.max() ?? 1)
        return VStack(spacing: 14) {
            winnerBanner(t.winnerIndices)
            ForEach(Array(options.enumerated()), id: \.offset) { pair in
                bar(label: pair.element, count: t.counts[pair.offset],
                    maxC: maxC, win: t.winnerIndices.contains(pair.offset))
            }
            HStack(spacing: 10) {
                Button {
                    Haptic.tap(); phase = .setup; votes = []
                } label: {
                    Text("من الأوّل").font(rnd(14, weight: .semibold)).foregroundStyle(DW.dim)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .card(bg: DW.card, r: 14, stroke: DW.stroke)
                }.buttonStyle(Press())
            }
            DawwirliButton().padding(.top, 2)
        }
    }

    private func winnerBanner(_ winners: [Int]) -> some View {
        let names = winners.map { options[$0] }
        let tie = winners.count > 1
        return VStack(spacing: 6) {
            Image(systemName: tie ? "equal.circle.fill" : "crown.fill")
                .font(.system(size: 34)).foregroundStyle(DW.grad)
            Text(tie ? "تعادل!" : "الفائز").font(rnd(14, weight: .semibold)).foregroundStyle(DW.dim)
            Text(names.isEmpty ? "ما أكو أصوات" : names.joined(separator: " + "))
                .font(rnd(26, weight: .black)).foregroundStyle(DW.grad)
                .multilineTextAlignment(.center)
            if tie { Text("دوّروا العجلة بين المتعادلين 😄").font(rnd(12)).foregroundStyle(DW.dim) }
        }
        .padding(18).frame(maxWidth: .infinity)
        .card(bg: DW.card, r: 20, stroke: DW.orange.opacity(0.35))
    }

    private func bar(label: String, count: Int, maxC: Int, win: Bool) -> some View {
        let frac = CGFloat(count) / CGFloat(maxC)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(rnd(15, weight: .bold)).foregroundStyle(win ? DW.orange : DW.text)
                Spacer()
                Text("\(count)").font(rnd(14, weight: .bold)).foregroundStyle(DW.dim)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DW.card2)
                    Capsule().fill(win ? AnyShapeStyle(DW.grad) : AnyShapeStyle(DW.orange.opacity(0.4)))
                        .frame(width: max(6, geo.size.width * frac))
                }
            }
            .frame(height: 16)
        }
        .padding(12)
        .card(bg: DW.card, r: 14, stroke: DW.stroke)
    }

    // logic
    private func addOption() {
        let t = typing.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !options.contains(t) else { return }
        Haptic.tap(); withAnimation { options.append(t) }; typing = ""
    }

    private func startVote() {
        guard options.count >= 2 else { return }
        Haptic.ok(); votes = []; current = 0; phase = .voting
    }

    private func castVote(_ idx: Int) {
        Haptic.tap()
        votes.append(idx)
        if votes.count >= people {
            withAnimation { phase = .results }
        } else {
            withAnimation { current += 1 }
        }
    }

    private func seedShot() {
        guard Shot.on, Shot.isAny("vote") else { return }
        options = ["كوميدي", "أكشن", "رعب", "خيال علميّ"]
        people = 7
        votes = [1, 1, 0, 1, 3, 1, 0]   // أكشن يفوز
        phase = .results
    }
}

// MARK: - 4. GUESS (trivia)

struct GuessView: View {
    @State private var deck: [Question] = []
    @State private var idx: Int = 0
    @State private var score: Int = 0
    @State private var streak: Int = 0
    @State private var best: Int = Store.highScore
    @State private var picked: Int? = nil
    @State private var timeLeft: Int = 15
    @State private var running = false
    private let total = 10
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Header(title: "خمّن", sub: "معلومات عامّة عن عالم الأفلام والمسلسلات")
                statsRow
                if deck.isEmpty {
                    startCard
                } else if idx >= deck.count {
                    finishCard
                } else {
                    questionCard(deck[idx])
                }
            }
            .padding(16)
        }
        .onReceive(timer) { _ in tick() }
        .onAppear(perform: begin)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat("النقاط", "\(score)", "star.fill")
            stat("المتتالية", "\(streak)🔥", "flame.fill")
            stat("الأفضل", "\(best)", "trophy.fill")
        }
    }

    private func stat(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(DW.orange).font(.system(size: 15))
            Text(value).font(rnd(18, weight: .bold)).foregroundStyle(DW.text)
            Text(label).font(rnd(10)).foregroundStyle(DW.dim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .card(bg: DW.card, r: 14, stroke: DW.stroke)
    }

    private var startCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.diamond.fill").font(.system(size: 44)).foregroundStyle(DW.grad)
            Text("جاهز للتحدّي؟").font(rnd(22, weight: .heavy)).foregroundStyle(DW.text)
            Text("\(total) أسئلة • كل جواب صح نقاط أكثر مع السرعة والمتتالية")
                .font(rnd(13)).foregroundStyle(DW.dim).multilineTextAlignment(.center)
            Button(action: begin) {
                Text("ابدأ").font(rnd(18, weight: .bold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(DW.grad, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }.buttonStyle(Press())
        }
        .padding(20).frame(maxWidth: .infinity)
        .card(bg: DW.card, r: 22, stroke: DW.stroke)
    }

    private func questionCard(_ q: Question) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text("سؤال \(idx + 1)/\(deck.count)").font(rnd(12, weight: .semibold)).foregroundStyle(DW.dim)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "timer").foregroundStyle(timeLeft <= 5 ? .red : DW.orange)
                    Text("\(timeLeft)").font(rnd(14, weight: .bold))
                        .foregroundStyle(timeLeft <= 5 ? .red : DW.text)
                }
            }
            Text(q.text).font(rnd(20, weight: .bold)).foregroundStyle(DW.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(.vertical, 6)

            ForEach(Array(q.options.enumerated()), id: \.offset) { pair in
                answerButton(q, option: pair.offset, text: pair.element)
            }

            if picked != nil, let e = q.explain {
                Text(e).font(rnd(12)).foregroundStyle(DW.dim)
                    .multilineTextAlignment(.center).padding(.top, 2)
            }
            if picked != nil {
                Button(action: nextQuestion) {
                    Text(idx + 1 >= deck.count ? "شوف النتيجة" : "السؤال الجاي")
                        .font(rnd(16, weight: .bold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(DW.grad, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }.buttonStyle(Press())
            }
        }
        .padding(18).frame(maxWidth: .infinity)
        .card(bg: DW.card, r: 22, stroke: DW.stroke)
    }

    private func answerButton(_ q: Question, option: Int, text: String) -> some View {
        let state = answerState(q, option: option)
        return Button {
            answer(q, option: option)
        } label: {
            HStack {
                Text(text).font(rnd(16, weight: .semibold)).foregroundStyle(state.fg)
                Spacer()
                if let ic = state.icon { Image(systemName: ic).foregroundStyle(state.fg) }
            }
            .padding(15).frame(maxWidth: .infinity)
            .background(state.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(state.border, lineWidth: 1))
        }
        .buttonStyle(Press())
        .disabled(picked != nil)
    }

    private struct AnswerStyle { let fg: Color; let bg: Color; let border: Color; let icon: String? }

    private func answerState(_ q: Question, option: Int) -> AnswerStyle {
        guard let p = picked else {
            return AnswerStyle(fg: DW.text, bg: DW.card2, border: DW.stroke, icon: nil)
        }
        if option == q.answer {
            return AnswerStyle(fg: .black, bg: Color.green.opacity(0.85),
                               border: .green, icon: "checkmark.circle.fill")
        }
        if option == p {
            return AnswerStyle(fg: .white, bg: Color.red.opacity(0.7),
                               border: .red, icon: "xmark.circle.fill")
        }
        return AnswerStyle(fg: DW.faint, bg: DW.card2.opacity(0.5), border: DW.stroke, icon: nil)
    }

    private var finishCard: some View {
        VStack(spacing: 12) {
            Image(systemName: score >= best && score > 0 ? "crown.fill" : "flag.checkered")
                .font(.system(size: 44)).foregroundStyle(DW.grad)
            Text(score >= best && score > 0 ? "رقم قياسي جديد!" : "خلصت!")
                .font(rnd(24, weight: .heavy)).foregroundStyle(DW.text)
            Text("نتيجتك: \(score) نقطة").font(rnd(18, weight: .bold)).foregroundStyle(DW.orange)
            Text("الأفضل: \(best)").font(rnd(13)).foregroundStyle(DW.dim)
            Button(action: begin) {
                Text("العب مرّة ثانية").font(rnd(17, weight: .bold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(DW.grad, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }.buttonStyle(Press())
            DawwirliButton()
        }
        .padding(20).frame(maxWidth: .infinity)
        .card(bg: DW.card, r: 22, stroke: DW.orange.opacity(0.35))
    }

    // logic
    private func begin() {
        if Shot.on && Shot.isAny("guess") { seedShot(); return }
        let seed = Int.random(in: 0..<1_000_000)
        deck = Trivia.quiz(seed: seed, count: total)
        idx = 0; score = 0; streak = 0; picked = nil; timeLeft = 15; running = true
        best = Store.highScore
    }

    private func tick() {
        guard running, picked == nil, !deck.isEmpty, idx < deck.count else { return }
        if timeLeft > 0 {
            timeLeft -= 1
            if timeLeft == 0 { timeUp() }
        }
    }

    private func timeUp() {
        picked = -1          // marks "timed out" -> nothing highlighted as chosen
        streak = 0
        Haptic.bad()
    }

    private func answer(_ q: Question, option: Int) {
        guard picked == nil else { return }
        picked = option
        if option == q.answer {
            streak += 1
            score += Trivia.points(correct: true, streak: streak - 1, timeLeft: timeLeft)
            Haptic.ok()
        } else {
            streak = 0
            Haptic.bad()
        }
    }

    private func nextQuestion() {
        Haptic.tap()
        withAnimation {
            idx += 1
            picked = nil
            timeLeft = 15
        }
        if idx >= deck.count { finish() }
    }

    private func finish() {
        running = false
        if score > best {
            best = score
            Store.highScore = score
        }
    }

    private func seedShot() {
        deck = Trivia.quiz(seed: 42, count: total)
        idx = 0
        score = 120
        streak = 4
        best = 240
        picked = nil
        timeLeft = 11
        running = false
    }
}

// MARK: - Shared: wrapping chips

struct FlowChips: View {
    let items: [String]
    var onRemove: (String) -> Void

    var body: some View {
        FlexLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Text(item).font(rnd(13, weight: .semibold)).foregroundStyle(DW.text)
                    Button { onRemove(item) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(DW.faint)
                    }.buttonStyle(Press())
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(DW.card2, in: Capsule())
                .overlay(Capsule().stroke(DW.stroke, lineWidth: 1))
            }
        }
    }
}

/// Simple wrapping layout for chips (iOS 16 Layout).
struct FlexLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 {
                x = 0
                y += lineH + lineSpacing
                lineH = 0
            }
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 {
                x = 0
                y += lineH + lineSpacing
                lineH = 0
            }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                    anchor: .topLeading, proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}
