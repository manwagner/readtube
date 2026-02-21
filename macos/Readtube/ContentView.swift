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
                        .help("Manage channels & playlists")
                    }
                }
        } detail: {
            if let article = selectedArticle, article.status == .done {
                ReaderView(article: article)
            } else if let article = selectedArticle {
                processingView(article)
            } else {
                emptyDetailView
            }
        }
        .sheet(isPresented: $showSources) {
            SourcesSheet()
        }
        .onAppear {
            pipeline.start(modelContext: modelContext)
        }
    }

    // MARK: - Detail states

    private func processingView(_ article: Article) -> some View {
        VStack(spacing: 16) {
            statusIcon(for: article.status)
                .font(.system(size: 48))

            Text(article.title.isEmpty ? article.videoID : article.title)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            statusLabel(for: article.status)

            if let error = article.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 60)
                    .multilineTextAlignment(.center)
            }

            if article.status == .error {
                Button("Retry") {
                    article.status = .pending
                    article.errorMessage = nil
                    article.updatedAt = Date()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }

    private var emptyDetailView: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.pages")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Select an article to read")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Or paste a YouTube URL in the sidebar")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
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

    @ViewBuilder
    private func statusLabel(for status: ArticleStatus) -> some View {
        switch status {
        case .pending:
            Text("Waiting to process...")
                .foregroundStyle(.secondary)
        case .fetching:
            Text("Fetching video info...")
                .foregroundStyle(.orange)
        case .transcribing:
            Text("Getting transcript...")
                .foregroundStyle(.orange)
        case .generating:
            Text("Generating article...")
                .foregroundStyle(.orange)
        case .done:
            Text("Done")
                .foregroundStyle(.green)
        case .error:
            Text("Something went wrong")
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
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            Divider()
            SourcesView()
        }
        .frame(width: 640, height: 520)
    }
}
