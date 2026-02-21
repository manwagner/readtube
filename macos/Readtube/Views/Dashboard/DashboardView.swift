import SwiftUI
import SwiftData

struct DashboardView: View {
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
            // URL input bar
            HStack(spacing: 8) {
                TextField("Paste YouTube URL...", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addURL() }

                Button {
                    if let str = NSPasteboard.general.string(forType: .string) {
                        urlInput = str
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Paste from clipboard")

                Button("Add") { addURL() }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Dismiss") { errorMessage = nil }
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            // Search and filter bar
            HStack {
                TextField("Search articles...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Status", selection: $statusFilter) {
                    Text("All").tag(nil as ArticleStatus?)
                    ForEach(ArticleStatus.allCases, id: \.self) { status in
                        Text(status.rawValue.capitalized).tag(status as ArticleStatus?)
                    }
                }
                .frame(width: 140)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Article list
            if filteredArticles.isEmpty {
                ContentUnavailableView(
                    "No Articles",
                    systemImage: "newspaper",
                    description: Text("Paste a YouTube URL above to get started")
                )
            } else {
                List(filteredArticles, selection: $selectedArticle) { article in
                    ArticleCardView(article: article)
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
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Dashboard")
    }

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
