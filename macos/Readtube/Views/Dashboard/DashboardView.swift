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
    @State private var isErrorVisible = false

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
                    TextField("Paste a YouTube URL...", text: $urlInput)
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

                if isErrorVisible, let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer()
                        Button { withAnimation { isErrorVisible = false } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(10)

            Divider()

            // Search + filter
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                TextField("Search articles...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)

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
            .padding(.vertical, 8)

            Divider()

            // Article list
            if filteredArticles.isEmpty {
                emptyState
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.document")
                .font(.system(size: 44))
                .foregroundStyle(.quaternary)
            Text("No Articles Yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Paste a YouTube URL above to\ngenerate your first article")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func addURL() {
        let url = urlInput.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        do {
            try pipeline.enqueue(url: url, modelContext: modelContext)
            urlInput = ""
            withAnimation { isErrorVisible = false }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            withAnimation(.easeInOut(duration: 0.2)) { isErrorVisible = true }
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
        HStack(spacing: 10) {
            // Thumbnail or status icon
            thumbnailOrIcon
                .frame(width: 48, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(article.title.isEmpty ? article.videoID : article.title)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if !article.channel.isEmpty {
                        Text(article.channel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if article.status != .done {
                        statusBadge
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnailOrIcon: some View {
        if let thumbStr = article.thumbnailURL, let thumbURL = URL(string: thumbStr) {
            AsyncImage(url: thumbURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderIcon
                default:
                    placeholderIcon
                }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.controlBackgroundColor))
            Image(systemName: "play.rectangle")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            switch article.status {
            case .fetching, .transcribing, .generating:
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.5)
            case .error:
                Circle().fill(.red).frame(width: 6, height: 6)
            case .pending:
                Circle().fill(.secondary.opacity(0.4)).frame(width: 6, height: 6)
            case .done:
                EmptyView()
            }
            Text(article.status.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(article.status == .error ? .red : .orange)
        }
    }
}
