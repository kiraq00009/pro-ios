import SwiftUI

@main
struct JaybiApp: App {
    @StateObject private var store = JStore()

    var body: some Scene {
        WindowGroup {
            JRoot()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
    }
}

struct JRoot: View {
    @EnvironmentObject var store: JStore

    var body: some View {
        Group {
            if Shot.on {
                JShotRouter()
            } else if store.onboarded {
                JHome()
            } else {
                JOnboard()
            }
        }
        .tint(JB.mint)
    }
}

/// صور الشاشات: كلّ اسم يفتح شاشته ببيانات تجريبيّة
struct JShotRouter: View {
    @EnvironmentObject var store: JStore

    var body: some View {
        switch Shot.name {
        case "voice":
            JVoiceView(onSaved: { _ in })
        case "scan":
            JScanView(onSaved: { _ in })
        case "add":
            JEditor(existing: nil, draft: Draft(amount: 18000, cat: "food", note: "غدا شاورما", dayOffset: 0), via: .type, onSaved: { _ in })
        case "report":
            JReport()
        case "onboard":
            JOnboard()
        case "settings":
            JSettings()
        default:
            JHome()
        }
    }
}
