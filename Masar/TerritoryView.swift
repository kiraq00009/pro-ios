import SwiftUI

/// منطقتي: خريطة كلّ خلاياك الحيّة ملوّنة حسب الطزاجة + أرقام الإمبراطوريّة
struct TerritoryView: View {
    @EnvironmentObject var store: MasarStore
    @State private var fitKey = 1
    @State private var rules = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                mapCard
                if store.activeCells == 0 {
                    EmptyCard(icon: "hexagon", title: "ما عندك منطقة بعد", sub: "ابدأ جولة من تبويب «جولة». كلّ خليّة (≈70 م) تعبر بيها تصير إلك، وإذا قفلت دائرة تاخذ كلّ الخلايا ما بداخلها.")
                } else {
                    stats
                    legend
                    fadeCard
                }
                rulesCard
            }
            .padding(18)
        }
        .background(MBackdrop())
        .onAppear { store.refresh(); fitKey += 1 }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("منطقتي").font(rnd(34, .black)).foregroundStyle(Color.white)
            Text("كلّ خليّة تذبل خلال 14 يوم إلّا إذا رجعت لها").font(rnd(13)).foregroundStyle(MT.tx3)
        }.padding(.top, 8)
    }

    private var mapCard: some View {
        MasarMap(routes: [], hexes: store.mapHexes, hexKey: store.revision, routeKey: 0, fitKey: fitKey, bottomPad: 30,
                 fallback: (store.origin ?? Demo.center).cl)
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(MT.mint.opacity(0.25)))
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill").foregroundStyle(MT.gold)
                    Text("\(Fmt.area(store.areaKm2)) كم²").font(rnd(16, .black)).foregroundStyle(Color.white)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, 14).frame(height: 38).background(.ultraThinMaterial, in: Capsule()).padding(12)
            }
            .overlay(alignment: .topTrailing) {
                Button { Haptic.tap(); fitKey += 1 } label: {
                    Image(systemName: "scope").font(.system(size: 15, weight: .black)).foregroundStyle(Color.white)
                        .frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle())
                }.buttonStyle(Press()).padding(12)
            }
    }

    private var stats: some View {
        let cols = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
        let ever = store.territory.everCount
        let rec = store.records
        return LazyVGrid(columns: cols, spacing: 9) {
            StatTile(value: "\(store.activeCells)", label: "خليّة حيّة", icon: "hexagon.fill", color: MT.mint)
            StatTile(value: Fmt.area(store.areaKm2), label: "كم² مساحة", icon: "map.fill", color: MT.cyan)
            StatTile(value: "\(ever)", label: "خليّة بالتاريخ", icon: "clock.arrow.circlepath", color: MT.violet)
            StatTile(value: "\(store.fadingSoon)", label: "تذبل ≤ 3 أيّام", icon: "hourglass", color: MT.gold)
            StatTile(value: String(format: "%.2f", rec.biggestLoop / 1e6), label: "أكبر دائرة كم²", icon: "lasso", color: MT.coral)
            StatTile(value: "\(rec.mostCells)", label: "أكثر خلايا بجولة", icon: "bolt.fill", color: MT.mint)
        }
    }

    private var legend: some View {
        let counts = toneCounts()
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "طزاجة الخلايا", icon: "drop.fill")
            HStack(spacing: 8) {
                swatch(1, "طازجة", "0–3 أيّام", counts[1])
                swatch(2, "جيّدة", "4–7", counts[2])
                swatch(3, "تذبل", "8–10", counts[3])
                swatch(4, "على وشك", "11–14", counts[4])
            }
        }.padding(16).card(MT.s1, 22)
    }

    private func swatch(_ tone: Int, _ t: String, _ d: String, _ n: Int) -> some View {
        VStack(spacing: 5) {
            HexShape().fill(MT.freshColor(tone).opacity(0.55)).overlay(HexShape().stroke(MT.freshColor(tone), lineWidth: 1.2))
                .frame(width: 30, height: 34)
            Text(t).font(rnd(12.5, .heavy)).foregroundStyle(Color.white)
            Text(d).font(rnd(10)).foregroundStyle(MT.tx3).environment(\.layoutDirection, .leftToRight)
            Text("\(n)").font(rnd(13, .black)).foregroundStyle(MT.freshColor(tone))
        }.frame(maxWidth: .infinity)
    }

    private func toneCounts() -> [Int] {
        var c = [0, 0, 0, 0, 0]
        for h in store.mapHexes where h.tone >= 0 && h.tone < 5 { c[h.tone] += 1 }
        return c
    }

    private var fadeCard: some View {
        let n = store.fadingSoon
        return HStack(spacing: 14) {
            Image(systemName: n > 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill").font(.system(size: 24, weight: .black))
                .foregroundStyle(n > 0 ? MT.gold : MT.mint)
                .frame(width: 54, height: 54).background(MT.s2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(n > 0 ? "\(n) خليّة على وشك أن تضيع منك" : "منطقتك بأمان").font(rnd(16, .black)).foregroundStyle(Color.white)
                Text(n > 0 ? "الخلايا البنفسجيّة الباهتة بالخريطة تنتهي خلال 3 أيّام — مرّ عليها بجولتك الجاية وترجع طازجة." : "ما في خلايا تذبل خلال الأيّام الثلاثة الجاية. كمّل وتوسّع!")
                    .font(rnd(12.5)).foregroundStyle(MT.tx2).lineSpacing(2)
            }
        }.padding(14).card(MT.s1, 22, stroke: (n > 0 ? MT.gold : MT.mint).opacity(0.25))
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { rules.toggle() } } label: {
                HStack {
                    SectionTitle(text: "كيف تعمل اللعبة؟", icon: "questionmark.circle.fill")
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .black)).foregroundStyle(MT.tx3)
                        .rotationEffect(.degrees(rules ? 180 : 0))
                }
            }.buttonStyle(Press())
            if rules {
                rule("hexagon.fill", MT.mint, "العالم مقسوم خلايا", "كلّ خليّة سداسيّة عرضها حوالي 70 متر. تمرّ بيها = تصير إلك.")
                rule("lasso", MT.gold, "اقفل دائرة", "إذا رجعت لنقطة مرّيت بيها قبل (والدائرة أطول من 250 م) تاخذ كلّ الخلايا اللي داخلها مرّة وحدة.")
                rule("hourglass", MT.violet, "الذبول", "الخليّة تبهت يوم بعد يوم وتروح بعد 14 يوم. رجعتك إلها ترجّعها طازجة.")
                rule("crown.fill", MT.coral, "الإمبراطوريّة", "مساحتك = الخلايا الحيّة بس. وسّعها وحافظ عليها حتى تفتح شارات ورُتب.")
            }
        }.padding(16).card(MT.s1, 22)
    }

    private func rule(_ icon: String, _ c: Color, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .black)).foregroundStyle(c)
                .frame(width: 42, height: 42).background(MT.s2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text(s).font(rnd(12.5)).foregroundStyle(MT.tx2).lineSpacing(2)
            }
        }
    }
}
