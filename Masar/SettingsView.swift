import SwiftUI
import UIKit
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var store: MasarStore
    @EnvironmentObject var tracker: Tracker
    let close: () -> Void
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("الإعدادات").font(rnd(30, .black)).foregroundStyle(Color.white)
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color.white)
                            .frame(width: 40, height: 40).background(MT.s2, in: Circle())
                    }.buttonStyle(Press())
                }.padding(.top, 12)

                group("أنت", "person.fill") {
                    stepRow("وزنك", "لحساب السعرات بدقّة", value: "\(Int(store.weight)) كغ") {
                        Stepper("", value: $store.weight, in: 30...180, step: 1).labelsHidden()
                    }
                    Divider().overlay(Color.white.opacity(0.06))
                    stepRow("هدف الأسبوع", "كم كيلو تريد تتحرّك بالأسبوع", value: "\(Int(store.weeklyGoal)) كم") {
                        Stepper("", value: $store.weeklyGoal, in: 3...200, step: 1).labelsHidden()
                    }
                }

                group("أثناء الجولة", "figure.run") {
                    toggleRow("التنبيه الصوتي", "صوت عربي يخبرك بالوقت والمعدّل كلّ كيلو وعند قفل الدائرة", $store.voiceOn)
                    Button { tracker.testVoice(store) } label: {
                        Label("جرّب الصوت", systemImage: "speaker.wave.2.fill").font(rnd(14, .heavy)).foregroundStyle(MT.mint)
                    }.buttonStyle(Press()).padding(.vertical, 4)
                    Divider().overlay(Color.white.opacity(0.06))
                    toggleRow("الشاشة تبقى شغّالة", "حتى تشوف الخريطة طول الجولة (يستهلك بطاريّة أكثر)", $store.keepAwake)
                }

                group("الموقع", "location.fill") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("إذن الموقع").font(rnd(15, .heavy)).foregroundStyle(Color.white)
                            Text(authText).font(rnd(12)).foregroundStyle(MT.tx3)
                        }
                        Spacer()
                        Circle().fill(tracker.authorized ? MT.mint : MT.gold).frame(width: 10, height: 10)
                    }
                    if tracker.auth == .notDetermined {
                        small("اسمح بالموقع") { tracker.requestPermission() }
                    } else if tracker.auth == .authorizedWhenInUse {
                        small("فعّل «دائمًا» (اختياري)") { tracker.requestAlways() }
                        Text("التتبّع بالخلفيّة يشتغل أثناء الجولة حتى بإذن «أثناء الاستخدام». «دائمًا» اختياري بس.").font(rnd(11.5)).foregroundStyle(MT.tx3)
                    } else if tracker.auth == .denied || tracker.auth == .restricted {
                        small("افتح إعدادات الجهاز") {
                            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                        }
                    }
                }

                group("البيانات", "externaldrive.fill") {
                    info("الجولات", "\(store.sessions.count)")
                    info("خلايا محفوظة", "\(store.territory.everCount)")
                    info("حجم الخليّة", "≈ \(Int(store.grid.width)) م")
                    Text("كلّ شيء يبقى على جهازك فقط — بدون حسابات ولا إنترنت.").font(rnd(11.5)).foregroundStyle(MT.tx3)
                    Button { confirmReset = true } label: {
                        Label("امسح كلّ البيانات", systemImage: "trash.fill").font(rnd(14, .heavy)).foregroundStyle(MT.red)
                    }.buttonStyle(Press()).padding(.top, 4)
                }

                Text("مسار 1.0 · مدينتك ساحة لعب").font(rnd(11.5)).foregroundStyle(MT.tx3).frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .background(MBackdrop())
        .confirmationDialog("نمسح كلّ شيء؟", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("امسح الجولات والمنطقة", role: .destructive) { store.resetAll(); Haptic.thud() }
            Button("لا", role: .cancel) {}
        } message: {
            Text("ستُحذف كلّ الجولات وكلّ الخلايا ولا يمكن استرجاعها.")
        }
    }

    private var authText: String {
        switch tracker.auth {
        case .authorizedAlways: return "دائمًا ✓"
        case .authorizedWhenInUse: return "أثناء الاستخدام ✓"
        case .denied: return "مرفوض — فعّله من الإعدادات"
        case .restricted: return "مقيّد على هذا الجهاز"
        case .notDetermined: return "ما انطلب بعد"
        @unknown default: return "غير معروف"
        }
    }

    private func group<C: View>(_ title: String, _ icon: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: title, icon: icon)
            content()
        }.padding(16).card(MT.s1, 22)
    }

    private func stepRow<C: View>(_ t: String, _ s: String, value: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text(s).font(rnd(11.5)).foregroundStyle(MT.tx3)
            }
            Spacer()
            Text(value).font(rnd(15, .black)).foregroundStyle(MT.mint).environment(\.layoutDirection, .rightToLeft)
            control()
        }
    }

    private func toggleRow(_ t: String, _ s: String, _ b: Binding<Bool>) -> some View {
        Toggle(isOn: b) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(rnd(15, .heavy)).foregroundStyle(Color.white)
                Text(s).font(rnd(11.5)).foregroundStyle(MT.tx3)
            }
        }.tint(MT.mint)
    }

    private func small(_ t: String, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); act() } label: {
            Text(t).font(rnd(14, .black)).foregroundStyle(MT.ink).padding(.horizontal, 16).frame(height: 40).background(MT.brand, in: Capsule())
        }.buttonStyle(Press())
    }

    private func info(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t).font(rnd(14, .bold)).foregroundStyle(MT.tx2)
            Spacer()
            Text(v).font(rnd(14, .black)).foregroundStyle(Color.white)
        }
    }
}

/// التعريف بأوّل فتح
struct OnboardView: View {
    @EnvironmentObject var tracker: Tracker
    let done: () -> Void
    @State private var page = 0

    private let pages: [(String, String, String, Color)] = [
        ("hexagon.fill", "مدينتك صارت لعبة", "العالم مقسوم خلايا سداسيّة عرض كلّ وحدة 70 متر. امشِ أو اركض أو سوق درّاجتك — كلّ خليّة تعبرها تصير إلك.", MT.mint),
        ("lasso", "اقفل الدائرة", "ارجع لنقطة مرّيت بيها وتنقفل دائرة: كلّ الخلايا داخلها تصير ملكك مرّة وحدة. كلّما كبرت الدائرة كبرت إمبراطوريّتك.", MT.gold),
        ("hourglass", "حافظ على منطقتك", "الخلايا تذبل خلال 14 يوم. ارجع لها حتى ترجع طازجة، واجمع الشارات والرتب وكسّر أرقامك.", MT.violet),
        ("location.fill", "نحتاج موقعك", "حتى نرسم طريقك ونحسب المسافة والخلايا. التتبّع يشتغل بس أثناء الجولة، وكلّ شيء يبقى على جهازك.", MT.cyan)
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(0..<pages.count, id: \.self) { i in
                    pageView(i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 7) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule().fill(i == page ? MT.mint : Color.white.opacity(0.18)).frame(width: i == page ? 22 : 7, height: 7)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
            .padding(.bottom, 18)
            PrimaryButton(title: page < pages.count - 1 ? "التالي" : "اسمح بالموقع وابدأ", icon: page < pages.count - 1 ? "arrow.left" : "location.fill") {
                if page < pages.count - 1 { withAnimation { page += 1 } } else { tracker.requestPermission(); done() }
            }
            .padding(.horizontal, 24)
            Button("تخطّي") { done() }.font(rnd(14, .bold)).foregroundStyle(MT.tx3).padding(.vertical, 14)
        }
        .background(MBackdrop())
    }

    private func pageView(_ i: Int) -> some View {
        let p = pages[i]
        return VStack(spacing: 22) {
            Spacer()
            ZStack {
                ForEach(0..<3, id: \.self) { k in
                    HexShape().stroke(p.3.opacity(0.35 - Double(k) * 0.1), lineWidth: 1.5)
                        .frame(width: 150 + CGFloat(k) * 46, height: 170 + CGFloat(k) * 52)
                }
                HexShape().fill(LinearGradient(colors: [p.3, p.3.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 136).shadow(color: p.3.opacity(0.6), radius: 26)
                Image(systemName: p.0).font(.system(size: 50, weight: .black)).foregroundStyle(MT.ink)
            }
            .frame(height: 300)
            Text(p.1).font(rnd(30, .black)).foregroundStyle(Color.white).multilineTextAlignment(.center)
            Text(p.2).font(rnd(16)).foregroundStyle(MT.tx2).multilineTextAlignment(.center).lineSpacing(5).padding(.horizontal, 30)
            Spacer()
        }
    }
}
