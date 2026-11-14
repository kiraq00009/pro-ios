import SwiftUI

// Emoji pool for card faces (index = symbol id).
private let kSymbols: [String] = [
    "🍉","🦊","🌙","⚡️","🌵","🐬","🍓","🎈",
    "🔥","🍋","🦉","🎲","🌸","🐸","⭐️","🍪",
    "🚀","🧩","🐝","🍄","🎸","🌈","🐙","🍩"
]

// MARK: - Match game view-model
final class MatchVM: ObservableObject {
    @Published var state: MatchState
    @Published var seconds = 0
    @Published var won = false
    @Published var started = false
    let size: GridSize
    let symbols: [String]
    private var gen = 0

    init(size: GridSize, seed: UInt64) {
        self.size = size
        self.state = MatchState(pairs: size.pairs, seed: seed)
        self.symbols = kSymbols
    }

    func face(_ i: Int) -> String {
        let id = state.cards[i]
        return symbols[id % symbols.count]
    }

    func tap(_ i: Int) {
        guard !won else { return }
        if !started { started = true }
        let ev = state.flip(i)
        switch ev {
        case .firstFlip:
            Haptic.tap
        case .matched:
            Haptic.ok
            objectWillChange.send()
            if state.isWon {
                finishWin()
            }
        case .mismatch:
            Haptic.bad
            objectWillChange.send()
            gen += 1
            let g = gen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
                guard let self = self, g == self.gen else { return }
                self.state.clearMismatch()
                self.objectWillChange.send()
            }
        case .ignored:
            break
        }
    }

    private func finishWin() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.won = true
            }
        }
    }

    // Seed a believable mid-game or finished board for screenshots.
    func seedForShot(matchedPairs: Int, moves extraMoves: Int, seconds secs: Int) {
        var idx = [Int: [Int]]()
        for (i, id) in state.cards.enumerated() { idx[id, default: []].append(i) }
        let ids = idx.keys.sorted()
        var done = 0
        for id in ids {
            if done >= matchedPairs { break }
            let p = idx[id]!
            _ = state.flip(p[0])
            _ = state.flip(p[1])
            done += 1
        }
        // Add a few extra "wrong" moves to make the counter realistic.
        var fake = extraMoves
        while fake > 0 {
            // flip an unmatched then clear via a mismatch cycle is complex;
            // simpler: leave moves == matchedPairs (already counted). Just bump time.
            fake -= 1
        }
        seconds = secs
        started = true
        if state.isWon { won = true }
    }
}

// MARK: - Match game view
struct MatchGameView: View {
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var store: Scores
    @StateObject private var vm: MatchVM
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(size: GridSize) {
        let seed: UInt64 = Shot.on ? 7 : UInt64.random(in: 1...UInt64.max)
        _vm = StateObject(wrappedValue: MatchVM(size: size, seed: seed))
    }

    var body: some View {
        VStack(spacing: 14) {
            topBar
            statsRow
            board
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onReceive(timer) { _ in
            if vm.started && !vm.won { vm.seconds += 1 }
        }
        .onChange(of: vm.won) { nowWon in
            if nowWon {
                store.submitMatch(size: vm.size, moves: vm.state.moves, time: vm.seconds)
            }
        }
        .onAppear(perform: applyShot)
        .overlay {
            if vm.won {
                WinView(size: vm.size, moves: vm.state.moves, time: vm.seconds,
                        bestMoves: store.bestMoves[vm.size.key],
                        onHome: { withAnimation { nav.screen = .home } },
                        onAgain: { withAnimation { nav.screen = .home }
                                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                       nav.screen = .match(vm.size)
                                   } })
            }
        }
    }

    private func applyShot() {
        guard Shot.on else { return }
        if Shot.isAny("win") {
            vm.seedForShot(matchedPairs: vm.size.pairs, moves: 0, seconds: 42)
        } else if Shot.isAny("game") {
            vm.seedForShot(matchedPairs: 3, moves: 0, seconds: 24)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                withAnimation { nav.screen = .home }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Pal.text)
                    .frame(width: 40, height: 40)
                    .card(bg: Pal.surface, r: 12, stroke: Pal.faint)
            }
            .buttonStyle(Press())
            Spacer()
            Text("مطابقة — " + vm.size.title)
                .font(rnd(18, weight: .bold))
                .foregroundStyle(Pal.text)
            Spacer()
            Button {
                withAnimation { nav.screen = .home }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    nav.screen = .match(vm.size)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Pal.amber)
                    .frame(width: 40, height: 40)
                    .card(bg: Pal.surface, r: 12, stroke: Pal.faint)
            }
            .buttonStyle(Press())
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatPill(icon: "hand.tap.fill", label: "الحركات", value: ltr("\(vm.state.moves)"), color: Pal.amber)
            StatPill(icon: "timer", label: "الوقت", value: fmtTime(vm.seconds), color: Pal.sky)
            StatPill(icon: "checkmark.seal.fill", label: "أزواج",
                     value: ltr("\(vm.state.pairsMatched)/\(vm.state.totalPairs)"), color: Pal.mint)
        }
    }

    private var board: some View {
        GeometryReader { geo in
            let cols = vm.size.cols
            let spacing: CGFloat = 8
            let w = (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let side = min(w, 86)
            let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols)
            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(vm.state.cards.indices, id: \.self) { i in
                        CardCell(face: vm.face(i),
                                 up: vm.state.isFaceUp(i),
                                 matched: vm.state.matched.contains(i),
                                 side: side) {
                            vm.tap(i)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Stat pill
struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(rnd(12))
                    .foregroundStyle(Pal.dim)
            }
            Text(value)
                .font(rnd(20, weight: .bold))
                .foregroundStyle(Pal.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .card(bg: Pal.surface, r: 14, stroke: Pal.faint)
    }
}

// MARK: - A single flip card
struct CardCell: View {
    let face: String
    let up: Bool
    let matched: Bool
    let side: CGFloat
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            ZStack {
                back
                front
            }
            .frame(width: side, height: side)
            .rotation3DEffect(.degrees(up ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: up)
            .opacity(matched ? 0.6 : 1.0)
            .scaleEffect(matched ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.3), value: matched)
        }
        .buttonStyle(Press())
        .disabled(up)
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(colors: [Pal.surface2, Pal.surface],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Pal.faint, lineWidth: 1))
            .overlay(
                Image(systemName: "questionmark")
                    .font(.system(size: side * 0.3, weight: .bold))
                    .foregroundStyle(Pal.amber.opacity(0.35)))
            .opacity(up ? 0 : 1)
    }

    private var front: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(matched
                  ? AnyShapeStyle(LinearGradient(colors: [Pal.mint.opacity(0.35), Pal.surface],
                                                 startPoint: .top, endPoint: .bottom))
                  : AnyShapeStyle(LinearGradient(colors: [Pal.gold.opacity(0.25), Pal.surface],
                                                 startPoint: .top, endPoint: .bottom)))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(matched ? Pal.mint.opacity(0.7) : Pal.amber.opacity(0.5), lineWidth: 1.5))
            .overlay(
                Text(face)
                    .font(.system(size: side * 0.46)))
            .opacity(up ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }
}

// MARK: - Win overlay
struct WinView: View {
    let size: GridSize
    let moves: Int
    let time: Int
    let bestMoves: Int?
    let onHome: () -> Void
    let onAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Pal.heroGrad)
                        .frame(width: 100, height: 100)
                        .shadow(color: Pal.amber.opacity(0.6), radius: 26, y: 10)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("فزت!")
                    .font(rnd(42, weight: .heavy))
                    .foregroundStyle(Pal.text)
                Text("خلّصت " + size.title)
                    .font(rnd(16))
                    .foregroundStyle(Pal.dim)
                HStack(spacing: 14) {
                    ResultTile(label: "الحركات", value: ltr("\(moves)"), color: Pal.amber)
                    ResultTile(label: "الوقت", value: fmtTime(time), color: Pal.sky)
                }
                if let b = bestMoves {
                    Text("أفضل: " + ltr("\(b)") + " حركة")
                        .font(rnd(14, weight: .semibold))
                        .foregroundStyle(Pal.gold)
                }
                VStack(spacing: 10) {
                    Button(action: onAgain) {
                        Text("التالي")
                            .font(rnd(18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Pal.heroGrad)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(Press())
                    Button(action: onHome) {
                        Text("الرئيسية")
                            .font(rnd(16, weight: .semibold))
                            .foregroundStyle(Pal.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .card(bg: Pal.surface, r: 16, stroke: Pal.faint)
                    }
                    .buttonStyle(Press())
                }
                .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 360)
            .card(bg: Pal.bg2, r: 28, stroke: Pal.faint)
            .padding(24)
        }
    }
}

struct ResultTile: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(rnd(13))
                .foregroundStyle(Pal.dim)
            Text(value)
                .font(rnd(26, weight: .heavy))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card(bg: Pal.surface, r: 16, stroke: Pal.faint)
    }
}

// MARK: - Sequence (Simon) game
final class SeqVM: ObservableObject {
    enum Phase { case idle, watch, play, over }
    @Published var phase: Phase = .idle
    @Published var active: Int? = nil     // pad lit during playback
    @Published var flash: Int? = nil      // pad flashed on player tap
    @Published var round = 0
    @Published var input: [Int] = []
    @Published var target: [Int] = []
    @Published var wrong = false
    let pads = 4
    let seed: UInt64
    private var gen = 0

    init(seed: UInt64) { self.seed = seed }

    func start() {
        round = 1
        buildAndWatch()
    }

    private func buildAndWatch() {
        input = []
        target = sequenceNext(seed: seed, length: round, pads: pads)
        playback()
    }

    private func playback() {
        phase = .watch
        gen += 1
        let g = gen
        let seq = target
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            for pad in seq {
                if g != self.gen { return }
                self.active = pad
                Haptic.tap
                try? await Task.sleep(nanoseconds: 420_000_000)
                if g != self.gen { return }
                self.active = nil
                try? await Task.sleep(nanoseconds: 180_000_000)
            }
            if g != self.gen { return }
            self.phase = .play
        }
    }

    func tapPad(_ i: Int) {
        guard phase == .play else { return }
        flash = i
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            if self?.flash == i { self?.flash = nil }
        }
        input.append(i)
        if !checkSequence(input, target) {
            Haptic.bad
            wrong = true
            phase = .over
            return
        }
        Haptic.tap
        if sequenceComplete(input, target) {
            Haptic.ok
            round += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.buildAndWatch()
            }
        }
    }

    // longest sequence fully reproduced
    var score: Int { max(0, round - 1) }

    func seedForShot() {
        round = 4
        target = sequenceNext(seed: seed, length: round, pads: pads)
        input = Array(target.prefix(1))
        phase = .watch
        active = target.count > 1 ? target[1] : target[0]
    }
}

struct SequenceGameView: View {
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var store: Scores
    @StateObject private var vm = SeqVM(seed: Shot.on ? 1234 : UInt64.random(in: 1...UInt64.max))

    private let padColors: [Color] = [Pal.amber, Pal.sky, Pal.mint, Pal.violet]

    var body: some View {
        VStack(spacing: 18) {
            topBar
            statusRow
            padGrid
            bottomBar
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .onAppear {
            if Shot.on { vm.seedForShot() }
        }
        .onChange(of: vm.phase) { ph in
            if ph == .over {
                store.submitSeq(vm.score)
            }
        }
        .overlay {
            if vm.phase == .over {
                seqOver
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                withAnimation { nav.screen = .home }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Pal.text)
                    .frame(width: 40, height: 40)
                    .card(bg: Pal.surface, r: 12, stroke: Pal.faint)
            }
            .buttonStyle(Press())
            Spacer()
            Text("تسلسل")
                .font(rnd(18, weight: .bold))
                .foregroundStyle(Pal.text)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            StatPill(icon: "number", label: "الجولة", value: ltr("\(max(1, vm.round))"), color: Pal.amber)
            StatPill(icon: "star.fill", label: "أفضل", value: ltr("\(store.seqBest)"), color: Pal.gold)
        }
    }

    private var padGrid: some View {
        VStack(spacing: 14) {
            Text(statusText)
                .font(rnd(16, weight: .semibold))
                .foregroundStyle(vm.phase == .play ? Pal.mint : Pal.dim)
                .padding(.bottom, 2)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    Pad(color: padColors[i],
                        lit: vm.active == i || vm.flash == i,
                        enabled: vm.phase == .play) {
                        vm.tapPad(i)
                    }
                }
            }
        }
    }

    private var statusText: String {
        switch vm.phase {
        case .idle: return "اضغط ابدأ"
        case .watch: return "راقب التسلسل"
        case .play: return "عيد التسلسل"
        case .over: return "انتهت"
        }
    }

    private var bottomBar: some View {
        Group {
            if vm.phase == .idle {
                Button {
                    vm.start()
                } label: {
                    Text("ابدأ")
                        .font(rnd(20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [Pal.sky, Pal.violet], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(Press())
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(Pal.sky)
                    Text("طول التسلسل: " + ltr("\(vm.target.count)"))
                        .font(rnd(14))
                        .foregroundStyle(Pal.dim)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var seqOver: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Pal.sky)
                Text("انتهت")
                    .font(rnd(34, weight: .heavy))
                    .foregroundStyle(Pal.text)
                Text("نتيجتك")
                    .font(rnd(14))
                    .foregroundStyle(Pal.dim)
                Text(ltr("\(vm.score)"))
                    .font(rnd(48, weight: .heavy))
                    .foregroundStyle(Pal.gold)
                Text("أفضل: " + ltr("\(store.seqBest)"))
                    .font(rnd(14, weight: .semibold))
                    .foregroundStyle(Pal.dim)
                VStack(spacing: 10) {
                    Button {
                        withAnimation { nav.screen = .sequence }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            nav.screen = .sequence
                        }
                        vm.wrong = false
                        vm.phase = .idle
                        vm.round = 0
                        vm.start()
                    } label: {
                        Text("مرة ثانية")
                            .font(rnd(18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(LinearGradient(colors: [Pal.sky, Pal.violet], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(Press())
                    Button {
                        withAnimation { nav.screen = .home }
                    } label: {
                        Text("الرئيسية")
                            .font(rnd(16, weight: .semibold))
                            .foregroundStyle(Pal.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .card(bg: Pal.surface, r: 16, stroke: Pal.faint)
                    }
                    .buttonStyle(Press())
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .card(bg: Pal.bg2, r: 28, stroke: Pal.faint)
            .padding(24)
        }
    }
}

struct Pad: View {
    let color: Color
    let lit: Bool
    let enabled: Bool
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            RoundedRectangle(cornerRadius: 22)
                .fill(color.opacity(lit ? 1.0 : 0.30))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(color.opacity(lit ? 1.0 : 0.5), lineWidth: lit ? 3 : 1.5))
                .frame(height: 120)
                .shadow(color: color.opacity(lit ? 0.7 : 0), radius: lit ? 24 : 0)
                .scaleEffect(lit ? 1.04 : 1.0)
                .animation(.easeOut(duration: 0.12), value: lit)
        }
        .buttonStyle(Press())
        .disabled(!enabled)
    }
}
