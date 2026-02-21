import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var pipeline: ArticlePipeline
    @State private var selectedArticle: Article?
    @State private var showSources = false

    var body: some View {
        NavigationSplitView {
            ArticleListView(selectedArticle: $selectedArticle)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 480)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showSources.toggle() } label: {
                            Label("Sources", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
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
        .sheet(isPresented: $showSources) {
            SourcesSheet()
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

/// Sources as a sheet instead of a separate navigation destination.
struct SourcesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sources")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            Divider()
            SourcesView()
        }
        .frame(width: 600, height: 500)
    }
}
