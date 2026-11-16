import UIKit
@preconcurrency import WebKit

/// نسخة احتياطيّة من الدفاتر بملفّ داخل التطبيق (Documents/mizan-state.json).
enum MZStore {
    static var file: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("mizan-state.json")
    }

    static func write(_ json: String) {
        guard json.count > 2, let d = json.data(using: .utf8) else { return }
        try? d.write(to: file, options: .atomic)
    }

    /// يشتغل قبل كود الصفحة: يرجّع الدفاتر إذا تخزين المتصفّح فاضي، ويعلّم وضع الصور.
    static func bootScript() -> String {
        var js = "window.MZ_NATIVE=1;"
        let shot = ProcessInfo.processInfo.environment["SHOT"] ?? ""
        if !shot.isEmpty, shot.allSatisfy({ $0.isLetter || $0.isNumber }) {
            js += "window.MZ_SHOT='" + shot + "';"
        }
        if let d = try? Data(contentsOf: file),
           (try? JSONSerialization.jsonObject(with: d)) is [String: Any],
           let s = String(data: d, encoding: .utf8) {
            js += "(function(){try{if(!localStorage.getItem('mizan.books')){var o=" + s
                + ";for(var k in o){if(typeof o[k]==='string')localStorage.setItem(k,o[k]);}}}catch(e){}})();"
        }
        return js
    }
}

/// الجسر بين الصفحة والآيفون: مشاركة، طباعة، روابط خارجيّة، حفظ احتياطيّ.
@MainActor
final class MZBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    weak var web: WKWebView?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let op = body["op"] as? String else { return }
        switch op {
        case "snap":
            if let s = body["data"] as? String {
                DispatchQueue.global(qos: .utility).async { MZStore.write(s) }
            }
        case "share":
            let name = (body["name"] as? String) ?? "mizan.txt"
            let text = (body["text"] as? String) ?? ""
            share(name: name, text: text)
        case "print":
            printPage(title: (body["title"] as? String) ?? "ميزان")
        default:
            break
        }
    }

    private func topVC() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let wins: [UIWindow] = scenes.flatMap { $0.windows }
        let win: UIWindow? = wins.first(where: { $0.isKeyWindow }) ?? wins.first
        var vc: UIViewController? = win?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }

    private func share(name: String, text: String) {
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("share", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(safe.isEmpty ? "mizan.txt" : safe)
        do { try Data(text.utf8).write(to: url, options: .atomic) } catch { return }
        guard let vc = topVC() else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = av.popoverPresentationController {
            pop.sourceView = vc.view
            pop.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 1, height: 1)
        }
        vc.present(av, animated: true)
    }

    private func printPage(title: String) {
        guard let web = web else { return }
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = title
        let pc = UIPrintInteractionController.shared
        pc.printInfo = info
        pc.printFormatter = web.viewPrintFormatter()
        pc.present(animated: true) { [weak web] _, _, _ in
            web?.evaluateJavaScript("window.dispatchEvent(new Event('afterprint'))", completionHandler: nil)
        }
    }

    // روابط خارجيّة (واتساب، مواقع) تنفتح برّا التطبيق
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let s = url.scheme?.lowercased() ?? ""
        if s == MZScheme.scheme || s == "about" || s == "blob" || s == "data" {
            decisionHandler(.allow)
            return
        }
        let mainFrame: Bool = navigationAction.targetFrame?.isMainFrame ?? true
        if mainFrame {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { UIApplication.shared.open(url) }
        return nil
    }

    // إذا انطفى محرّك الصفحة بالخلفيّة، نعيد التحميل
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard let vc = topVC() else { completionHandler(); return }
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "تمام", style: .default) { _ in completionHandler() })
        vc.present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard let vc = topVC() else { completionHandler(false); return }
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "إلغاء", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "نعم", style: .default) { _ in completionHandler(true) })
        vc.present(a, animated: true)
    }
}
