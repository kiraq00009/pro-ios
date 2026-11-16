import SwiftUI

/// إضافة/تعديل مصروف: لوحة أرقام كبيرة + الأصناف + ملاحظة + الوقت
struct JEditor: View {
    @EnvironmentObject var store: JStore
    @Environment(\.dismiss) private var dismiss

    let existing: Expense?
    let via: Via
    var onSaved: (Expense) -> Void

    @State private var digits: String
    @State private var cat: String
    @State private var note: String
    @State private var date: Date
    @State private var catTouched: Bool
    @State private var askDelete = false
    @FocusState private var noteFocus: Bool

    init(existing: Expense?, draft: Draft?, via: Via, onSaved: @escaping (Expense) -> Void) {
        self.existing = existing
        self.via = via
        self.onSaved = onSaved
        var a = 0.0
        var c = "other"
        var n = ""
        var d = Date()
        var touched = false
        if let e = existing {
            a = e.amount; c = e.cat; n = e.note; d = e.date; touched = true
        } else if let dr = draft {
            a = dr.amount ?? 0
            c = dr.cat
            n = dr.note
            touched = dr.cat != "other"
            if dr.dayOffset != 0 {
                d = Calendar.current.date(byAdding: .day, value: dr.dayOffset, to: Date()) ?? Date()
            }
        }
        let ds: String
        if a <= 0 {
            ds = ""
        } else if a == a.rounded() {
            ds = String(Int(a))
        } else {
            ds = String(format: "%.2f", a)
        }
        _digits = State(initialValue: ds)
        _cat = State(initialValue: c)
        _note = State(initialValue: n)
        _date = State(initialValue: d)
        _catTouched = State(initialValue: touched)
    }

    private var amount: Double { Double(digits) ?? 0 }

    var body: some View {
        ZStack {
            JB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 16) {
                        amountView
                        JCatPicker(selected: $cat) { catTouched = true }
                        noteField
                        dateRow
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                }
                .scrollDismissesKeyboard(.interactively)
                if !noteFocus {
                    JKeypad(digits: $digits)
                        .padding(.horizontal, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                saveButton
            }
        }
        .animation(.easeOut(duration: 0.2), value: noteFocus)
        .onChange(of: note) { v in
            if catTouched { return }
            let toks = SpeechParse.tokens(v).norm
            if let g = SpeechParse.guessCat(toks) { cat = g }
        }
        .confirmationDialog("تمسح هذا المصروف؟", isPresented: $askDelete, titleVisibility: .visible) {
            Button("امسح", role: .destructive) {
                if let e = existing {
                    store.delete(e.id)
                    Haptic.thud()
                }
                dismiss()
            }
            Button("لا", role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack {
            Button("إلغاء") { dismiss() }
                .font(rnd(16, .medium)).foregroundColor(JB.tx2)
            Spacer()
            Text(existing == nil ? titleFor(via) : "تعديل").font(rnd(17, .bold)).foregroundColor(JB.tx)
            Spacer()
            if existing != nil {
                Button {
                    askDelete = true
                } label: {
                    Image(systemName: "trash").font(.system(size: 17, weight: .semibold)).foregroundColor(JB.coral)
                }
            } else {
                Text("إلغاء").font(rnd(16, .medium)).opacity(0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func titleFor(_ v: Via) -> String {
        switch v {
        case .type: return "مصروف جديد"
        case .voice: return "تأكيد المصروف"
        case .scan: return "تأكيد الوصل"
        }
    }

    private var amountView: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(digits.isEmpty ? "0" : Money.s(amount))
                    .font(rnd(52, .bold))
                    .foregroundColor(digits.isEmpty ? JB.tx2.opacity(0.5) : JB.tx)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentTransition(.numericText())
                Text(store.currency).font(rnd(18, .medium)).foregroundColor(JB.tx2)
            }
            .environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 8) {
                ForEach([1000.0, 5000.0, 10000.0, 25000.0], id: \.self) { q in
                    Button {
                        Haptic.tap()
                        digits = String(Int(amount + q))
                    } label: {
                        Text("+" + Money.short(q))
                            .font(rnd(12.5, .semibold)).foregroundColor(JB.mint)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(JB.mint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(Press())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var noteField: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.alignright").foregroundColor(JB.tx2)
            TextField("", text: $note, prompt: Text("على شنو؟ (مثلًا: غدا، تكسي، رصيد)").foregroundColor(JB.tx2.opacity(0.7)))
                .font(rnd(16))
                .foregroundColor(JB.tx)
                .focused($noteFocus)
                .submitLabel(.done)
                .onSubmit { noteFocus = false }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .card(JB.card, 16)
    }

    private var dateRow: some View {
        HStack {
            Image(systemName: "calendar").foregroundColor(JB.tx2)
            Text("الوقت").font(rnd(15)).foregroundColor(JB.tx2)
            Spacer()
            DatePicker("", selection: $date, in: ...Date().addingTimeInterval(86400 * 30))
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ar"))
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .card(JB.card, 16)
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(existing == nil ? "احفظ" : "احفظ التعديل")
                .font(rnd(17, .bold))
                .foregroundColor(amount > 0 ? JB.mintInk : JB.tx2)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(amount > 0 ? AnyShapeStyle(JB.mintGrad) : AnyShapeStyle(JB.card2))
                )
        }
        .buttonStyle(Press())
        .disabled(amount <= 0)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private func save() {
        guard amount > 0 else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = trimmed.isEmpty ? Cats.get(cat).name : trimmed
        var e = existing ?? Expense(amount: amount, cat: cat, note: n, date: date, via: via)
        e.amount = amount
        e.cat = cat
        e.note = n
        e.date = date
        store.update(e)
        onSaved(e)
        dismiss()
    }
}

/// شريط الأصناف
struct JCatPicker: View {
    @Binding var selected: String
    var onPick: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Cats.all, id: \.id) { c in
                        JCatChip(cat: c, on: c.id == selected)
                            .id(c.id)
                            .onTapGesture {
                                Haptic.tap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = c.id }
                                onPick()
                            }
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) { v in
                withAnimation { proxy.scrollTo(v, anchor: .center) }
            }
        }
    }
}

struct JCatChip: View {
    let cat: Cat
    let on: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(cat.emoji).font(.system(size: 17))
            Text(cat.name).font(rnd(14, on ? .bold : .medium))
        }
        .foregroundColor(on ? JB.tx : JB.tx2)
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(on ? JB.color(cat.id).opacity(0.22) : JB.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(on ? JB.color(cat.id).opacity(0.8) : JB.line, lineWidth: on ? 1.5 : 1)
        )
    }
}

/// لوحة أرقام كبيرة
struct JKeypad: View {
    @Binding var digits: String
    private let keys: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "000", "0", "del"]

    var body: some View {
        let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(keys, id: \.self) { k in
                Button {
                    press(k)
                } label: {
                    keyLabel(k)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(JB.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(Press())
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func keyLabel(_ k: String) -> some View {
        if k == "del" {
            Image(systemName: "delete.left").font(.system(size: 20, weight: .semibold)).foregroundColor(JB.tx2)
        } else {
            Text(k).font(rnd(24, .semibold)).foregroundColor(JB.tx)
        }
    }

    private func press(_ k: String) {
        Haptic.tap()
        if k == "del" {
            if !digits.isEmpty { digits.removeLast() }
            if digits.hasSuffix(".") { digits.removeLast() }
            return
        }
        if digits.contains(".") {
            // مبلغ بكسور من الصوت/الوصل: نبدي من جديد
            digits = ""
        }
        if digits.isEmpty && (k == "0" || k == "000") { return }
        if digits.count + k.count > 12 { return }
        digits += k
    }
}
