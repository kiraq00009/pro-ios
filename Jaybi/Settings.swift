import SwiftUI

/// الإعدادات: الميزانيّة + العملة + التصدير + المسح
struct JSettings: View {
    @EnvironmentObject var store: JStore
    @Environment(\.dismiss) private var dismiss
    @State private var budgetText = ""
    @State private var askClear = false
    @State private var csv: URL?
    @FocusState private var focus: Bool

    var body: some View {
        ZStack {
            JB.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("الإعدادات").font(rnd(24, .bold)).foregroundColor(JB.tx)
                        Spacer()
                        Button("تمّ") { commit(); dismiss() }
                            .font(rnd(16, .bold)).foregroundColor(JB.mint)
                    }
                    .padding(.top, 20)

                    section("ميزانيّة الشهر") {
                        HStack {
                            TextField("", text: $budgetText, prompt: Text("مثلًا 1000000").foregroundColor(JB.tx2.opacity(0.6)))
                                .keyboardType(.numberPad)
                                .font(rnd(20, .bold))
                                .foregroundColor(JB.tx)
                                .focused($focus)
                                .environment(\.layoutDirection, .leftToRight)
                                .multilineTextAlignment(.trailing)
                            Text(store.currency).font(rnd(16)).foregroundColor(JB.tx2)
                        }
                        Text("خلّيها فاضية إذا ما تريد ميزانيّة. جيبي يحسبلك شكد تگدر تصرف باليوم ويحذّرك قبل ما تخلص.")
                            .font(rnd(12.5)).foregroundColor(JB.tx2).lineSpacing(3)
                    }

                    section("العملة") {
                        let cols = [GridItem(.adaptive(minimum: 96), spacing: 8)]
                        LazyVGrid(columns: cols, spacing: 8) {
                            ForEach(0..<Money.currencies.count, id: \.self) { i in
                                let c = Money.currencies[i]
                                Button {
                                    Haptic.tap()
                                    store.currency = c.0
                                    store.save()
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(c.0).font(rnd(17, .bold))
                                        Text(c.1).font(rnd(10.5)).lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                    .foregroundColor(store.currency == c.0 ? JB.mintInk : JB.tx)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(store.currency == c.0 ? AnyShapeStyle(JB.mintGrad) : AnyShapeStyle(JB.card2))
                                    )
                                }
                                .buttonStyle(Press())
                            }
                        }
                    }

                    section("بياناتك") {
                        if let u = csv {
                            ShareLink(item: u) {
                                rowLabel("صدّر كلّ المصاريف (Excel)", "square.and.arrow.up", JB.tx)
                            }
                        }
                        Button {
                            askClear = true
                        } label: {
                            rowLabel("امسح كلّ المصاريف", "trash", JB.coral)
                        }
                        Text(String(store.items.count) + " مصروف محفوظ على جهازك فقط. جيبي ما يرفع شي للإنترنت.")
                            .font(rnd(12.5)).foregroundColor(JB.tx2)
                    }

                    section("شلون أستعمله؟") {
                        tip("mic.fill", "احچي", "«صرفت خمسة وعشرين ألف عشا» — يفهم المبلغ والصنف واليوم (البارحة، أوّل أمس).")
                        tip("doc.text.viewfinder", "صوّر", "صوّر الوصل، يلگى المجموع واسم المحلّ.")
                        tip("keyboard", "اكتب", "لوحة أرقام كبيرة، والصنف يتخمّن من الملاحظة.")
                        tip("hand.draw", "عدّل وامسح", "اضغط على أيّ مصروف حتى تعدّله، أو اسحبه حتى تمسحه.")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            budgetText = store.budget > 0 ? String(Int(store.budget)) : ""
            csv = store.csvFile()
        }
        .onChange(of: focus) { f in
            if !f { commit() }
        }
        .confirmationDialog("تمسح كلّ المصاريف؟ ما ترجع.", isPresented: $askClear, titleVisibility: .visible) {
            Button("امسح الكلّ", role: .destructive) {
                store.clearAll()
                Haptic.thud()
                csv = store.csvFile()
            }
            Button("لا", role: .cancel) {}
        }
    }

    private func commit() {
        let digits = AR.norm(budgetText).filter { AR.isDigit($0) }
        store.budget = Double(digits) ?? 0
        store.save()
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(rnd(13.5, .semibold)).foregroundColor(JB.tx2)
            VStack(alignment: .leading, spacing: 12) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(JB.card, 20)
        }
    }

    private func rowLabel(_ t: String, _ icon: String, _ c: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(c)
            Text(t).font(rnd(15.5, .semibold)).foregroundColor(c)
            Spacer()
        }
        .frame(height: 30)
    }

    private func tip(_ icon: String, _ t: String, _ d: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundColor(JB.mint).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(rnd(14.5, .bold)).foregroundColor(JB.tx)
                Text(d).font(rnd(13)).foregroundColor(JB.tx2).lineSpacing(2)
            }
        }
    }
}

/// أوّل مرّة: ترحيب + ميزانيّة + عملة
struct JOnboard: View {
    @EnvironmentObject var store: JStore
    @State private var budgetText = ""
    @State private var appear = false

    var body: some View {
        ZStack {
            JB.bg.ignoresSafeArea()
            RadialGradient(colors: [JB.mint.opacity(0.22), .clear], center: .top, startRadius: 10, endRadius: 420)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous).fill(JB.mintGrad).frame(width: 84, height: 84)
                        Image(systemName: "wallet.pass.fill").font(.system(size: 38, weight: .semibold)).foregroundColor(JB.mintInk)
                    }
                    .shadow(color: JB.mint.opacity(0.4), radius: 20, y: 10)
                    .scaleEffect(appear ? 1 : 0.6)
                    .opacity(appear ? 1 : 0)
                    .padding(.top, 40)

                    Text("جيبي").font(rnd(40, .bold)).foregroundColor(JB.tx)
                    Text("سجّل مصاريفك بثانيتين، واعرف وين تروح فلوسك.")
                        .font(rnd(18, .medium)).foregroundColor(JB.tx2).lineSpacing(4)

                    VStack(spacing: 10) {
                        feature("mic.fill", "احچي", "«دفعت عشرة آلاف تكسي» وخلص")
                        feature("doc.text.viewfinder", "صوّر الوصل", "يقرا المجموع لحاله")
                        feature("keyboard", "اكتب", "لوحة أرقام سريعة")
                    }
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ميزانيّتك الشهريّة (اختياري)").font(rnd(14, .semibold)).foregroundColor(JB.tx2)
                        HStack {
                            TextField("", text: $budgetText, prompt: Text("مثلًا 1000000").foregroundColor(JB.tx2.opacity(0.6)))
                                .keyboardType(.numberPad)
                                .font(rnd(20, .bold))
                                .foregroundColor(JB.tx)
                                .environment(\.layoutDirection, .leftToRight)
                                .multilineTextAlignment(.trailing)
                            Menu {
                                ForEach(0..<Money.currencies.count, id: \.self) { i in
                                    Button(Money.currencies[i].0 + "  " + Money.currencies[i].1) { store.currency = Money.currencies[i].0 }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(store.currency).font(rnd(16, .bold))
                                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(JB.mint)
                                .padding(.horizontal, 10)
                                .frame(height: 34)
                                .background(JB.mint.opacity(0.12), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .card(JB.card, 18)
                    }
                    .padding(.top, 8)

                    JMintButton(title: "يلّا نبدي", system: "arrow.left") {
                        let digits = AR.norm(budgetText).filter { AR.isDigit($0) }
                        store.budget = Double(digits) ?? 0
                        withAnimation { store.onboarded = true }
                        store.save()
                    }
                    .padding(.top, 10)

                    Text("كلّ شي ينحفظ على تلفونك بس.")
                        .font(rnd(12)).foregroundColor(JB.tx2.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appear = true }
        }
    }

    private func feature(_ icon: String, _ t: String, _ d: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(JB.mint)
                .frame(width: 44, height: 44)
                .background(JB.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(rnd(16, .bold)).foregroundColor(JB.tx)
                Text(d).font(rnd(13)).foregroundColor(JB.tx2)
            }
            Spacer()
        }
        .padding(10)
        .card(JB.card, 18)
    }
}
