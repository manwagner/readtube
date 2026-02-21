import SwiftUI
import SwiftData

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case sources = "Sources"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "newspaper"
        case .sources: return "antenna.radiowaves.left.and.right"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var pipeline: ArticlePipeline
    @State private var selectedSidebar: SidebarItem? = .dashboard
    @State private var selectedArticle: Article?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebar)
        } content: {
            switch selectedSidebar {
            case .dashboard:
                DashboardView(selectedArticle: $selectedArticle)
            case .sources:
                SourcesView()
            case nil:
                Text("Select an item")
                    .foregroundStyle(.secondary)
            }
        } detail: {
            if let article = selectedArticle, article.status == .done {
                ReaderView(article: article)
            } else if let article = selectedArticle {
                VStack(spacing: 12) {
                    statusIcon(for: article.status)
                        .font(.largeTitle)
                    Text(article.title.isEmpty ? article.videoID : article.title)
                        .font(.headline)
                    Text(article.status.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                    if let error = article.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                    }
                    if article.status == .error {
                        Button("Retry") {
                            article.status = .pending
                            article.errorMessage = nil
                            article.updatedAt = Date()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Select an article to read")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            pipeline.start(modelContext: modelContext)
        }
    }

    @ViewBuilder
    private func statusIcon(for status: ArticleStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .fetching, .transcribing, .generating:
            ProgressView()
                .controlSize(.large)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}
