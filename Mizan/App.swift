import SwiftUI
import UIKit
@preconcurrency import WebKit

@main
struct MizanApp: App {
    var body: some Scene {
        WindowGroup {
            MZWebHost()
                .ignoresSafeArea()
        }
    }
}

/// المضيف: WKWebView يحمل نسخة ميزان المضمّنة داخل التطبيق (تشتغل بلا نت).
struct MZWebHost: UIViewRepresentable {
    func makeCoordinator() -> MZBridge { MZBridge() }

    func makeUIView(context: Context) -> WKWebView {
        let bridge = context.coordinator
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = WKWebsiteDataStore.default()
        cfg.setURLSchemeHandler(MZScheme(), forURLScheme: MZScheme.scheme)
        let ucc = WKUserContentController()
        ucc.add(MZWeakHandler(bridge), name: "mz")
        ucc.addUserScript(WKUserScript(source: MZStore.bootScript(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        cfg.userContentController = ucc

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = false
        web.backgroundColor = MZScheme.paper
        web.scrollView.backgroundColor = MZScheme.paper
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.allowsLinkPreview = false
        web.allowsBackForwardNavigationGestures = true
        web.navigationDelegate = bridge
        web.uiDelegate = bridge
        bridge.web = web
        if let url = URL(string: MZScheme.scheme + "://localhost/index.html") {
            web.load(URLRequest(url: url))
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// يمنع حلقة الاحتفاظ بين WKUserContentController والجسر.
final class MZWeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(c, didReceive: message)
    }
}
