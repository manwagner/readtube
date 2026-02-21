import Foundation
import SwiftData

/// Orchestrates the full pipeline: URL → metadata → transcript → LLM article → rendered HTML.
/// All SwiftData access stays on the main actor to avoid thread-safety issues.
@MainActor
final class ArticlePipeline: ObservableObject {
    @Published var isProcessing = false

    private var timer: Timer?
    private var activeTasks: Set<String> = []
    private let maxConcurrent = 2

    func start(modelContext: ModelContext) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPending(modelContext: modelContext)
                self?.pollAutoFetchSources(modelContext: modelContext)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }

    /// Manually enqueue a URL for processing.
    func enqueue(url: String, modelContext: ModelContext) throws {
        let videoID = extractVideoID(from: url) ?? url
        let urlStr = videoID.contains("youtube.com") ? url : "https://www.youtube.com/watch?v=\(videoID)"

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.videoID == videoID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            if existing.status == .error {
                existing.status = .pending
                existing.errorMessage = nil
                existing.updatedAt = Date()
            }
            return
        }

        let article = Article(videoID: videoID, url: urlStr)
        modelContext.insert(article)
        try modelContext.save()
    }

    // MARK: - Polling

    private func pollPending(modelContext: ModelContext) {
        guard activeTasks.count < maxConcurrent else { return }

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.statusRaw == "pending" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let articles = try? modelContext.fetch(descriptor),
              let article = articles.first(where: { !activeTasks.contains($0.videoID) }) else {
            return
        }

        let videoID = article.videoID
        activeTasks.insert(videoID)
        isProcessing = true

        Task { @MainActor in
            await processArticle(videoID: videoID, modelContext: modelContext)
            activeTasks.remove(videoID)
            isProcessing = !activeTasks.isEmpty
        }
    }

    // MARK: - Auto-fetch sources

    private var lastAutoFetchCheck = Date.distantPast

    private func pollAutoFetchSources(modelContext: ModelContext) {
        // Only check every 60 seconds to avoid hammering the DB
        guard Date().timeIntervalSince(lastAutoFetchCheck) >= 60 else { return }
        lastAutoFetchCheck = Date()

        let settings = AppSettings.getOrCreate(context: modelContext)
        let intervalMinutes = settings.autoFetchIntervalMinutes
        guard intervalMinutes > 0 else { return }

        let interval = TimeInterval(intervalMinutes * 60)
        let descriptor = FetchDescriptor<Source>(
            predicate: #Predicate<Source> { $0.autoFetch == true }
        )
        guard let sources = try? modelContext.fetch(descriptor) else { return }

        for source in sources {
            let lastFetch = source.lastFetchedAt ?? .distantPast
            guard Date().timeIntervalSince(lastFetch) >= interval else { continue }

            source.lastFetchedAt = Date()
            do { try modelContext.save() } catch { print("Failed to save lastFetchedAt: \(error)") }

            Task { @MainActor in
                await fetchSource(source, modelContext: modelContext)
            }
        }
    }

    private func fetchSource(_ source: Source, modelContext: ModelContext) async {
        do {
            let urls: [String]
            switch source.sourceType {
            case .playlist:
                urls = try await YTDLPService.shared.getPlaylistVideoURLs(url: source.url)
            case .channel:
                if let info = try await YTDLPService.shared.getLatestFromChannel(handle: source.url) {
                    urls = [info.url]
                } else {
                    urls = []
                }
            case .video:
                urls = [source.url]
            }

            for url in urls {
                try enqueue(url: url, modelContext: modelContext)
            }
        } catch {
            print("Auto-fetch failed for \(source.url): \(error)")
        }
    }

    // MARK: - Pipeline

    private func processArticle(videoID: String, modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.videoID == videoID }
        )
        guard let article = try? modelContext.fetch(descriptor).first else { return }
        let url = article.url.isEmpty ? "https://www.youtube.com/watch?v=\(videoID)" : article.url

        // Step 1: Fetch video info
        setStatus(article, .fetching, modelContext: modelContext)
        let info: VideoInfo
        do {
            info = try await YTDLPService.shared.getVideoInfo(url: url)
        } catch {
            setError(article, "Fetch failed: \(error.localizedDescription)", modelContext: modelContext)
            return
        }

        article.title = info.title
        article.channel = info.channel
        article.videoDescription = info.description
        article.thumbnailURL = info.thumbnailURL
        article.duration = info.duration
        article.url = info.url
        article.updatedAt = Date()

        // Step 2: Fetch transcript
        setStatus(article, .transcribing, modelContext: modelContext)
        let transcript: String
        do {
            transcript = try await YTDLPService.shared.getSubtitles(videoID: info.videoID)
        } catch {
            setError(article, "Transcript failed: \(error.localizedDescription)", modelContext: modelContext)
            return
        }

        article.transcript = transcript
        article.updatedAt = Date()

        // Step 3: Generate article via LLM
        setStatus(article, .generating, modelContext: modelContext)

        let settings = AppSettings.getOrCreate(context: modelContext)
        let llm = buildLLMService(settings: settings)

        let prompt: String
        let chapters = info.chapters
        if !chapters.isEmpty {
            let structuredTranscript = buildChapteredTranscript(transcript: transcript, chapters: chapters)
            prompt = PromptTemplates.articlePromptWithChapters(
                title: info.title,
                channel: info.channel,
                description: info.description,
                transcript: structuredTranscript
            )
        } else {
            prompt = PromptTemplates.articlePrompt(
                title: info.title,
                channel: info.channel,
                description: info.description,
                chapters: "",
                transcript: transcript
            )
        }

        let articleMD: String
        do {
            articleMD = try await llm.generate(
                prompt: prompt,
                systemPrompt: PromptTemplates.systemPrompt,
                maxTokens: 4096,
                temperature: 0.7
            )
        } catch {
            setError(article, "LLM failed: \(error.localizedDescription)", modelContext: modelContext)
            return
        }

        if articleMD.isEmpty {
            setError(article, "LLM returned empty article", modelContext: modelContext)
            return
        }

        // Step 4: Render markdown to HTML
        let articleHTML = MarkdownToHTML.convert(articleMD)

        article.articleMarkdown = articleMD
        article.articleHTML = articleHTML
        article.status = .done
        article.errorMessage = nil
        article.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("Failed to save completed article: \(error)")
        }
    }

    // MARK: - Helpers

    private func setStatus(_ article: Article, _ status: ArticleStatus, modelContext: ModelContext) {
        article.status = status
        article.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("Failed to save status \(status): \(error)")
        }
    }

    private func setError(_ article: Article, _ message: String, modelContext: ModelContext) {
        article.status = .error
        article.errorMessage = message
        article.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("Failed to save error state: \(error)")
        }
    }

    /// Build the appropriate LLM service based on settings.
    nonisolated func buildLLMService(settings: AppSettings) -> any LLMService {
        switch settings.llmBackend {
        case .ollama:
            return OllamaService(baseURL: settings.ollamaBaseURL, model: settings.ollamaModel)
        case .claude:
            return ClaudeService(apiKey: settings.anthropicAPIKey, model: settings.anthropicModel)
        case .openai:
            return OpenAIService(apiKey: settings.openaiAPIKey, baseURL: settings.openaiBaseURL, model: settings.openaiModel)
        }
    }

    /// Split transcript by chapter timestamps (proportional word distribution).
    nonisolated func buildChapteredTranscript(transcript: String, chapters: [ChapterInfo]) -> String {
        let words = transcript.split(separator: " ")
        let totalWords = words.count
        let totalDuration = chapters.map(\.endTime).max() ?? 1.0

        var parts: [String] = []
        var wordIndex = 0

        for chapter in chapters {
            let duration = chapter.endTime - chapter.startTime
            let proportion = totalDuration > 0 ? duration / totalDuration : 1.0 / Double(chapters.count)
            let chapterWordCount = Int(Double(totalWords) * proportion)
            let endIndex = min(wordIndex + chapterWordCount, totalWords)
            let chapterText = words[wordIndex..<endIndex].joined(separator: " ")
            parts.append("## \(chapter.title)\n\n\(chapterText)")
            wordIndex = endIndex
        }

        if wordIndex < totalWords, !parts.isEmpty {
            let remaining = words[wordIndex...].joined(separator: " ")
            parts[parts.count - 1] += " " + remaining
        }

        return parts.joined(separator: "\n\n")
    }

    /// Extract video ID from various YouTube URL formats.
    nonisolated func extractVideoID(from url: String) -> String? {
        if let range = url.range(of: "v=") {
            let start = range.upperBound
            let end = url[start...].firstIndex(of: "&") ?? url.endIndex
            let id = String(url[start..<end])
            return id.isEmpty ? nil : id
        }
        if url.contains("youtu.be/") {
            let parts = url.split(separator: "/")
            if let last = parts.last {
                let id = String(last.prefix(while: { $0 != "?" }))
                return id.isEmpty ? nil : id
            }
        }
        return nil
    }
}
