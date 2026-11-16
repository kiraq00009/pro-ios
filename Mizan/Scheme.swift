import UIKit
@preconcurrency import WebKit

/// يخدم ملفّات الويب المضمّنة من مجلّد web داخل التطبيق عبر mizan://localhost/…
final class MZScheme: NSObject, WKURLSchemeHandler {
    static let scheme = "mizan"
    static let paper = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0x12 / 255.0, green: 0x15 / 255.0, blue: 0x14 / 255.0, alpha: 1)
            : UIColor(red: 0xF5 / 255.0, green: 0xF3 / 255.0, blue: 0xEE / 255.0, alpha: 1)
    }

    private let root: URL = {
        let base = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        return base.appendingPathComponent("web", isDirectory: true)
    }()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let rel = String(path.drop(while: { $0 == "/" }))
        let file = root.appendingPathComponent(rel).standardizedFileURL
        let rootPath = root.standardizedFileURL.path
        guard file.path.hasPrefix(rootPath), let data = try? Data(contentsOf: file) else {
            respond(urlSchemeTask, url: url, code: 404, mime: "text/plain", data: Data("not found".utf8))
            return
        }
        respond(urlSchemeTask, url: url, code: 200, mime: MZScheme.mime(file.pathExtension), data: data)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func respond(_ task: WKURLSchemeTask, url: URL, code: Int, mime: String, data: Data) {
        let headers: [String: String] = [
            "Content-Type": mime,
            "Content-Length": String(data.count),
            "Cache-Control": "no-cache",
        ]
        if let r = HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: headers) {
            task.didReceive(r)
        } else {
            task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: "utf-8"))
        }
        task.didReceive(data)
        task.didFinish()
    }

    static func mime(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "ttf": return "font/ttf"
        case "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }
}
