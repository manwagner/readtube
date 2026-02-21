import SwiftUI
import SwiftData

struct ReaderView: View {
    let article: Article
    @Environment(\.modelContext) private var modelContext
    @State private var currentTheme: ThemeName = .default
    @State private var coordinator: ReaderWebView.Coordinator?
    @State private var exportError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Theme picker
                Picker("Theme", selection: $currentTheme) {
                    ForEach(ThemeName.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Spacer()

                // Export menu
                Menu {
                    Section("Document") {
                        Button { exportEPUB() } label: {
                            Label("EPUB", systemImage: "book")
                        }
                        Button { exportPDF() } label: {
                            Label("PDF", systemImage: "doc.richtext")
                        }
                    }
                    Section("Source") {
                        Button { exportMarkdown() } label: {
                            Label("Markdown", systemImage: "text.document")
                        }
                        Button { exportHTML() } label: {
                            Label("HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Open in YouTube
                if let url = URL(string: article.url) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("YouTube", systemImage: "play.rectangle.fill")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Web reader
            ReaderWebView(
                htmlContent: article.articleHTML ?? "",
                theme: currentTheme,
                title: article.title,
                channel: article.channel,
                url: article.url,
                coordinatorRef: $coordinator
            )
        }
        .navigationTitle(article.title)
        .onAppear {
            let settings = AppSettings.getOrCreate(context: modelContext)
            currentTheme = settings.theme
        }
        .onChange(of: currentTheme) {
            let settings = AppSettings.getOrCreate(context: modelContext)
            settings.theme = currentTheme
            do { try modelContext.save() } catch { print("Failed to save theme: \(error)") }
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Export

    private func exportEPUB() {
        guard let md = article.articleMarkdown else { return }
        let panel = NSSavePanel()
        let safeTitle = safeName(article.title)
        panel.nameFieldStringValue = "\(safeTitle).epub"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                do {
                    let data = try EPUBGenerator.generate(
                        title: article.title,
                        channel: article.channel,
                        articleURL: article.url,
                        markdown: md,
                        thumbnailURL: article.thumbnailURL
                    )
                    try data.write(to: url)
                } catch {
                    exportError = "EPUB: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        let safeTitle = safeName(article.title)
        panel.nameFieldStringValue = "\(safeTitle).pdf"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                guard let coordinator = coordinator else {
                    exportError = "PDF: WebView not ready"
                    return
                }
                do {
                    let data = try await coordinator.exportPDF()
                    try data.write(to: url)
                } catch {
                    exportError = "PDF: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportMarkdown() {
        guard let md = article.articleMarkdown else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(safeName(article.title)).md"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? md.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func exportHTML() {
        guard let html = article.articleHTML else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(safeName(article.title)).html"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let typographyCSS = Bundle.main.url(forResource: "Typography", withExtension: "css")
                    .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
                let fullHTML = """
                    <!DOCTYPE html>
                    <html lang="en">
                    <head>
                        <meta charset="UTF-8">
                        <title>\(article.title)</title>
                        <style>\(typographyCSS)</style>
                    </head>
                    <body>
                        \(html)
                    </body>
                    </html>
                    """
                try? fullHTML.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func safeName(_ title: String) -> String {
        let cleaned = title.filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
        return String(cleaned.prefix(50)).trimmingCharacters(in: .whitespaces)
    }
}
