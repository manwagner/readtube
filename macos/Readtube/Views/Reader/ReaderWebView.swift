import SwiftUI
import WebKit

/// NSViewRepresentable wrapper for WKWebView that renders article HTML with typography CSS.
struct ReaderWebView: NSViewRepresentable {
    let htmlContent: String
    let theme: ThemeName
    let title: String
    let channel: String
    let url: String
    @Binding var coordinatorRef: Coordinator?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isElementFullscreenEnabled = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        DispatchQueue.main.async { coordinatorRef = context.coordinator }
        loadContent(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadContent(in: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func loadContent(in webView: WKWebView) {
        let typographyCSS = loadResource("Typography", ext: "css") ?? ""
        let themeCSS = loadThemeCSS(theme)

        let template = loadResource("ReaderTemplate", ext: "html")
            ?? "<!DOCTYPE html><html><body>{{CONTENT}}</body></html>"

        let finalHTML = template
            .replacingOccurrences(of: "{{TYPOGRAPHY_CSS}}", with: typographyCSS)
            .replacingOccurrences(of: "{{THEME_CSS}}", with: themeCSS)
            .replacingOccurrences(of: "{{TITLE}}", with: escapeHTML(title))
            .replacingOccurrences(of: "{{CHANNEL}}", with: escapeHTML(channel))
            .replacingOccurrences(of: "{{URL}}", with: escapeHTML(url))
            .replacingOccurrences(of: "{{CONTENT}}", with: htmlContent)

        webView.loadHTMLString(finalHTML, baseURL: nil)
    }

    private func loadResource(_ name: String, ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func loadThemeCSS(_ theme: ThemeName) -> String {
        // Try loading from Themes/ subdirectory
        if let url = Bundle.main.url(forResource: theme.rawValue, withExtension: "css", subdirectory: "Themes") {
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        // Fallback: try flat resource
        return loadResource(theme.rawValue, ext: "css") ?? ""
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    class Coordinator {
        var webView: WKWebView?

        /// Export the current page as PDF.
        func exportPDF() async throws -> Data {
            guard let webView = webView else { throw ExportError.noWebView }
            let config = WKPDFConfiguration()
            config.rect = webView.bounds
            return try await webView.pdf(configuration: config)
        }
    }
}

enum ExportError: LocalizedError {
    case noWebView

    var errorDescription: String? {
        "WebView not available for export"
    }
}
