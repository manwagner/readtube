import SwiftUI
import SwiftData

/// Article list shown in the sidebar — URL input, search, and scrollable article list.
struct ArticleListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var pipeline: ArticlePipeline
    @Binding var selectedArticle: Article?

    @State private var urlInput = ""
    @State private var searchText = ""
    @State private var statusFilter: ArticleStatus?
    @State private var errorMessage: String?

    @Query(sort: \Article.createdAt, order: .reverse) private var allArticles: [Article]

    private var filteredArticles: [Article] {
        var result = allArticles
        if let filter = statusFilter {
            result = result.filter { $0.status == filter }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.channel.lowercased().contains(query)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // URL input
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    TextField("YouTube URL", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addURL() }

                    Button { pasteFromClipboard() } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .help("Paste from clipboard")

                    Button("Add") { addURL() }
                        .buttonStyle(.borderedProminent)
                        .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let error = errorMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .lineLimit(2)
                        Spacer()
                        Button { errorMessage = nil } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.red)
                }
            }
            .padding(10)

            Divider()

            // Search + filter
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)

                Picker("", selection: $statusFilter) {
                    Text("All").tag(nil as ArticleStatus?)
                    ForEach(ArticleStatus.allCases, id: \.self) { status in
                        Text(status.rawValue.capitalized).tag(status as ArticleStatus?)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            // Article list
            if filteredArticles.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "newspaper")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("No Articles")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Paste a YouTube URL above")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(filteredArticles, selection: $selectedArticle) { article in
                    ArticleRow(article: article)
                        .tag(article)
                        .contextMenu {
                            if article.status == .done {
                                Button("Export Markdown") { exportMarkdown(article) }
                            }
                            if article.status == .error {
                                Button("Retry") {
                                    article.status = .pending
                                    article.errorMessage = nil
                                    article.updatedAt = Date()
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                if selectedArticle == article { selectedArticle = nil }
                                modelContext.delete(article)
                            }
                        }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Readtube")
    }

    // MARK: - Actions

    private func addURL() {
        let url = urlInput.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        do {
            try pipeline.enqueue(url: url, modelContext: modelContext)
            urlInput = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pasteFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string) {
            urlInput = str
        }
    }

    private func exportMarkdown(_ article: Article) {
        guard let md = article.articleMarkdown else { return }
        let panel = NSSavePanel()
        let safeTitle = article.title.prefix(50).filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
        panel.nameFieldStringValue = "\(safeTitle).md"
        panel.allowedContentTypes = [.plainText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? md.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

/// Compact article row for the sidebar list.
struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            statusDot
                .frame(width: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(article.title.isEmpty ? article.videoID : article.title)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(2)

                if !article.channel.isEmpty {
                    Text(article.channel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if article.status != .done {
                    Text(article.status.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(article.status == .error ? .red : .orange)
                }
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var statusDot: some View {
        switch article.status {
        case .done:
            Circle().fill(.green).frame(width: 8, height: 8)
        case .error:
            Circle().fill(.red).frame(width: 8, height: 8)
        case .pending:
            Circle().fill(.secondary.opacity(0.4)).frame(width: 8, height: 8)
        case .fetching, .transcribing, .generating:
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.6)
        }
    }
}
