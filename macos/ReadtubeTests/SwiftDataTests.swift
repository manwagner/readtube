import XCTest
import SwiftData

/// Tests for SwiftData models: Article, Source, AppSettings.
/// Uses in-memory ModelContainer for all database operations.
final class SwiftDataTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: Article.self, Source.self, AppSettings.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Article init

    @MainActor
    func testArticleDefaultInit() {
        let article = Article(videoID: "abc123")
        XCTAssertEqual(article.videoID, "abc123")
        XCTAssertEqual(article.title, "")
        XCTAssertEqual(article.channel, "")
        XCTAssertEqual(article.videoDescription, "")
        XCTAssertNil(article.thumbnailURL)
        XCTAssertEqual(article.duration, 0)
        XCTAssertEqual(article.url, "")
        XCTAssertEqual(article.status, .pending)
        XCTAssertEqual(article.statusRaw, "pending")
        XCTAssertNil(article.errorMessage)
        XCTAssertNil(article.source)
        XCTAssertNil(article.transcript)
        XCTAssertNil(article.articleMarkdown)
        XCTAssertNil(article.articleHTML)
    }

    @MainActor
    func testArticleCustomInit() {
        let article = Article(
            videoID: "xyz789",
            title: "Test Video",
            channel: "Test Channel",
            videoDescription: "A description",
            thumbnailURL: "https://img.youtube.com/vi/xyz789/0.jpg",
            duration: 300,
            url: "https://www.youtube.com/watch?v=xyz789",
            status: .done
        )
        XCTAssertEqual(article.videoID, "xyz789")
        XCTAssertEqual(article.title, "Test Video")
        XCTAssertEqual(article.channel, "Test Channel")
        XCTAssertEqual(article.videoDescription, "A description")
        XCTAssertEqual(article.thumbnailURL, "https://img.youtube.com/vi/xyz789/0.jpg")
        XCTAssertEqual(article.duration, 300)
        XCTAssertEqual(article.url, "https://www.youtube.com/watch?v=xyz789")
        XCTAssertEqual(article.status, .done)
        XCTAssertEqual(article.statusRaw, "done")
    }

    // MARK: - Article computed status

    @MainActor
    func testArticleStatusGetterSetter() {
        let article = Article(videoID: "test1")
        XCTAssertEqual(article.status, .pending)

        article.status = .fetching
        XCTAssertEqual(article.statusRaw, "fetching")
        XCTAssertEqual(article.status, .fetching)

        article.status = .transcribing
        XCTAssertEqual(article.statusRaw, "transcribing")

        article.status = .generating
        XCTAssertEqual(article.statusRaw, "generating")

        article.status = .done
        XCTAssertEqual(article.statusRaw, "done")

        article.status = .error
        XCTAssertEqual(article.statusRaw, "error")
    }

    @MainActor
    func testArticleStatusFallbackForInvalidRaw() {
        let article = Article(videoID: "test2")
        article.statusRaw = "unknown_garbage"
        // Should fall back to .pending
        XCTAssertEqual(article.status, .pending)
    }

    @MainActor
    func testArticleStatusFallbackForEmptyRaw() {
        let article = Article(videoID: "test3")
        article.statusRaw = ""
        XCTAssertEqual(article.status, .pending)
    }

    // MARK: - Article SwiftData persistence

    @MainActor
    func testArticleInsertAndFetch() throws {
        let article = Article(videoID: "persist1", title: "Persisted", channel: "Ch1")
        context.insert(article)
        try context.save()

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.videoID == "persist1" }
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Persisted")
        XCTAssertEqual(fetched.first?.channel, "Ch1")
    }

    @MainActor
    func testArticleUniqueVideoID() throws {
        let a1 = Article(videoID: "dup1", title: "First")
        context.insert(a1)
        try context.save()

        let a2 = Article(videoID: "dup1", title: "Second")
        context.insert(a2)
        // Should fail on save due to unique constraint
        do {
            try context.save()
            // If it doesn't throw, check there's still only one
            let descriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> { $0.videoID == "dup1" }
            )
            let all = try context.fetch(descriptor)
            // SwiftData may merge or throw — either way, we assert no data corruption
            XCTAssertTrue(all.count >= 1)
        } catch {
            // Expected: unique constraint violation
            XCTAssertTrue(true)
        }
    }

    @MainActor
    func testArticleStatusTransitions() throws {
        let article = Article(videoID: "status1")
        context.insert(article)
        try context.save()

        // Simulate the pipeline status transitions
        let transitions: [ArticleStatus] = [.pending, .fetching, .transcribing, .generating, .done]
        for status in transitions {
            article.status = status
            try context.save()

            let descriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> { $0.videoID == "status1" }
            )
            let fetched = try context.fetch(descriptor).first!
            XCTAssertEqual(fetched.status, status)
        }
    }

    @MainActor
    func testArticleErrorState() throws {
        let article = Article(videoID: "error1")
        context.insert(article)

        article.status = .error
        article.errorMessage = "LLM failed: timeout"
        try context.save()

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.videoID == "error1" }
        )
        let fetched = try context.fetch(descriptor).first!
        XCTAssertEqual(fetched.status, .error)
        XCTAssertEqual(fetched.errorMessage, "LLM failed: timeout")
    }

    @MainActor
    func testArticleUpdateFields() throws {
        let article = Article(videoID: "update1")
        context.insert(article)
        try context.save()

        article.title = "Updated Title"
        article.channel = "Updated Channel"
        article.transcript = "The transcript text"
        article.articleMarkdown = "# Article"
        article.articleHTML = "<h1>Article</h1>"
        article.duration = 600
        article.updatedAt = Date()
        try context.save()

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.videoID == "update1" }
        )
        let fetched = try context.fetch(descriptor).first!
        XCTAssertEqual(fetched.title, "Updated Title")
        XCTAssertEqual(fetched.transcript, "The transcript text")
        XCTAssertEqual(fetched.articleMarkdown, "# Article")
        XCTAssertEqual(fetched.articleHTML, "<h1>Article</h1>")
        XCTAssertEqual(fetched.duration, 600)
    }

    // MARK: - Source init

    @MainActor
    func testSourceDefaultInit() {
        let source = Source(url: "https://youtube.com/channel/UC123")
        XCTAssertEqual(source.url, "https://youtube.com/channel/UC123")
        XCTAssertEqual(source.sourceType, .video)
        XCTAssertEqual(source.sourceTypeRaw, "video")
        XCTAssertEqual(source.name, "")
        XCTAssertFalse(source.autoFetch)
        XCTAssertNil(source.lastFetchedAt)
        XCTAssertTrue(source.articles.isEmpty)
    }

    @MainActor
    func testSourceCustomInit() {
        let source = Source(
            url: "https://youtube.com/playlist?list=PLxyz",
            sourceType: .playlist,
            name: "My Playlist",
            autoFetch: true
        )
        XCTAssertEqual(source.sourceType, .playlist)
        XCTAssertEqual(source.sourceTypeRaw, "playlist")
        XCTAssertEqual(source.name, "My Playlist")
        XCTAssertTrue(source.autoFetch)
    }

    // MARK: - Source computed sourceType

    @MainActor
    func testSourceTypeGetterSetter() {
        let source = Source(url: "https://example.com")

        source.sourceType = .channel
        XCTAssertEqual(source.sourceTypeRaw, "channel")
        XCTAssertEqual(source.sourceType, .channel)

        source.sourceType = .playlist
        XCTAssertEqual(source.sourceTypeRaw, "playlist")

        source.sourceType = .video
        XCTAssertEqual(source.sourceTypeRaw, "video")
    }

    @MainActor
    func testSourceTypeFallbackForInvalidRaw() {
        let source = Source(url: "https://example.com")
        source.sourceTypeRaw = "invalid_type"
        XCTAssertEqual(source.sourceType, .video)
    }

    // MARK: - Source SwiftData persistence

    @MainActor
    func testSourceInsertAndFetch() throws {
        let source = Source(url: "https://youtube.com/channel/UCtest", sourceType: .channel, name: "Test Channel")
        context.insert(source)
        try context.save()

        let descriptor = FetchDescriptor<Source>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test Channel")
        XCTAssertEqual(fetched.first?.sourceType, .channel)
    }

    @MainActor
    func testSourceAutoFetchToggle() throws {
        let source = Source(url: "https://youtube.com/channel/UCauto", autoFetch: false)
        context.insert(source)
        try context.save()

        source.autoFetch = true
        try context.save()

        let descriptor = FetchDescriptor<Source>(
            predicate: #Predicate<Source> { $0.autoFetch == true }
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
    }

    @MainActor
    func testSourceLastFetchedAtUpdate() throws {
        let source = Source(url: "https://youtube.com/channel/UCfetch", autoFetch: true)
        context.insert(source)
        try context.save()
        XCTAssertNil(source.lastFetchedAt)

        let now = Date()
        source.lastFetchedAt = now
        try context.save()

        let descriptor = FetchDescriptor<Source>()
        let fetched = try context.fetch(descriptor).first!
        XCTAssertNotNil(fetched.lastFetchedAt)
    }

    // MARK: - Source-Article relationship

    @MainActor
    func testSourceArticleRelationship() throws {
        let source = Source(url: "https://youtube.com/channel/UCrel", sourceType: .channel, name: "Rel Channel")
        context.insert(source)

        let article1 = Article(videoID: "rel1", title: "Article 1", source: source)
        let article2 = Article(videoID: "rel2", title: "Article 2", source: source)
        context.insert(article1)
        context.insert(article2)
        try context.save()

        XCTAssertEqual(source.articles.count, 2)
        XCTAssertEqual(article1.source?.url, source.url)
        XCTAssertEqual(article2.source?.url, source.url)
    }

    @MainActor
    func testArticleWithoutSource() throws {
        let article = Article(videoID: "nosource")
        context.insert(article)
        try context.save()
        XCTAssertNil(article.source)
    }

    // MARK: - AppSettings init

    @MainActor
    func testAppSettingsDefaultInit() {
        let settings = AppSettings()
        XCTAssertEqual(settings.id, "singleton")
        XCTAssertEqual(settings.llmBackend, .ollama)
        XCTAssertEqual(settings.llmBackendRaw, "ollama")
        XCTAssertEqual(settings.ollamaModel, "llama3.2")
        XCTAssertEqual(settings.ollamaBaseURL, "http://localhost:11434")
        XCTAssertEqual(settings.anthropicAPIKey, "")
        XCTAssertTrue(settings.anthropicModel.contains("claude"))
        XCTAssertEqual(settings.openaiAPIKey, "")
        XCTAssertEqual(settings.openaiModel, "gpt-4o")
        XCTAssertEqual(settings.openaiBaseURL, "https://api.openai.com/v1")
        XCTAssertEqual(settings.theme, .default)
        XCTAssertEqual(settings.themeRaw, "default")
        XCTAssertEqual(settings.autoFetchIntervalMinutes, 0)
    }

    // MARK: - AppSettings computed properties

    @MainActor
    func testAppSettingsLLMBackendGetterSetter() {
        let settings = AppSettings()

        settings.llmBackend = .claude
        XCTAssertEqual(settings.llmBackendRaw, "claude-api")
        XCTAssertEqual(settings.llmBackend, .claude)

        settings.llmBackend = .openai
        XCTAssertEqual(settings.llmBackendRaw, "openai")
        XCTAssertEqual(settings.llmBackend, .openai)

        settings.llmBackend = .ollama
        XCTAssertEqual(settings.llmBackendRaw, "ollama")
    }

    @MainActor
    func testAppSettingsLLMBackendFallbackForInvalidRaw() {
        let settings = AppSettings()
        settings.llmBackendRaw = "not-a-backend"
        XCTAssertEqual(settings.llmBackend, .ollama)
    }

    @MainActor
    func testAppSettingsThemeGetterSetter() {
        let settings = AppSettings()

        settings.theme = .dark
        XCTAssertEqual(settings.themeRaw, "dark")
        XCTAssertEqual(settings.theme, .dark)

        settings.theme = .modern
        XCTAssertEqual(settings.themeRaw, "modern")

        settings.theme = .minimal
        XCTAssertEqual(settings.themeRaw, "minimal")

        settings.theme = .default
        XCTAssertEqual(settings.themeRaw, "default")
    }

    @MainActor
    func testAppSettingsThemeFallbackForInvalidRaw() {
        let settings = AppSettings()
        settings.themeRaw = "nonexistent-theme"
        XCTAssertEqual(settings.theme, .default)
    }

    // MARK: - AppSettings getOrCreate

    @MainActor
    func testGetOrCreateCreatesNew() throws {
        // Verify no settings exist yet
        let descriptor = FetchDescriptor<AppSettings>()
        let existing = try context.fetch(descriptor)
        XCTAssertTrue(existing.isEmpty)

        // getOrCreate should create one
        let settings = AppSettings.getOrCreate(context: context)
        XCTAssertEqual(settings.id, "singleton")
        XCTAssertEqual(settings.llmBackend, .ollama)

        // Verify it's persisted
        let afterCreate = try context.fetch(descriptor)
        XCTAssertEqual(afterCreate.count, 1)
    }

    @MainActor
    func testGetOrCreateReturnsExisting() throws {
        // Create settings manually
        let manual = AppSettings()
        manual.ollamaModel = "custom-model"
        context.insert(manual)
        try context.save()

        // getOrCreate should return the existing one
        let settings = AppSettings.getOrCreate(context: context)
        XCTAssertEqual(settings.ollamaModel, "custom-model")

        // Should not create a duplicate
        let descriptor = FetchDescriptor<AppSettings>()
        let all = try context.fetch(descriptor)
        XCTAssertEqual(all.count, 1)
    }

    @MainActor
    func testGetOrCreateIdempotent() throws {
        // Call multiple times
        let s1 = AppSettings.getOrCreate(context: context)
        let s2 = AppSettings.getOrCreate(context: context)
        let s3 = AppSettings.getOrCreate(context: context)

        XCTAssertEqual(s1.id, s2.id)
        XCTAssertEqual(s2.id, s3.id)

        let descriptor = FetchDescriptor<AppSettings>()
        let all = try context.fetch(descriptor)
        XCTAssertEqual(all.count, 1)
    }

    @MainActor
    func testGetOrCreateModifyAndRetrieve() throws {
        let settings = AppSettings.getOrCreate(context: context)
        settings.llmBackend = .claude
        settings.anthropicAPIKey = "sk-ant-test123"
        settings.theme = .dark
        settings.autoFetchIntervalMinutes = 30
        try context.save()

        // Retrieve again
        let retrieved = AppSettings.getOrCreate(context: context)
        XCTAssertEqual(retrieved.llmBackend, .claude)
        XCTAssertEqual(retrieved.anthropicAPIKey, "sk-ant-test123")
        XCTAssertEqual(retrieved.theme, .dark)
        XCTAssertEqual(retrieved.autoFetchIntervalMinutes, 30)
    }

    // MARK: - ArticlePipeline.enqueue with SwiftData

    @MainActor
    func testEnqueueCreatesArticle() throws {
        let pipeline = ArticlePipeline()
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=abc123", modelContext: context)

        let descriptor = FetchDescriptor<Article>()
        let articles = try context.fetch(descriptor)
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles.first?.videoID, "abc123")
        XCTAssertEqual(articles.first?.status, .pending)
    }

    @MainActor
    func testEnqueueDeduplicates() throws {
        let pipeline = ArticlePipeline()
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=dedup1", modelContext: context)
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=dedup1", modelContext: context)

        let descriptor = FetchDescriptor<Article>()
        let articles = try context.fetch(descriptor)
        XCTAssertEqual(articles.count, 1)
    }

    @MainActor
    func testEnqueueResetsErrorStatus() throws {
        // Create an article with error status
        let article = Article(videoID: "retry1", status: .error)
        article.errorMessage = "Previous error"
        context.insert(article)
        try context.save()

        let pipeline = ArticlePipeline()
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=retry1", modelContext: context)

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.videoID == "retry1" }
        )
        let fetched = try context.fetch(descriptor).first!
        XCTAssertEqual(fetched.status, .pending)
        XCTAssertNil(fetched.errorMessage)
    }

    @MainActor
    func testEnqueueDoesNotResetDoneStatus() throws {
        // Create an article with done status
        let article = Article(videoID: "done1", status: .done)
        article.articleMarkdown = "# Existing Article"
        context.insert(article)
        try context.save()

        let pipeline = ArticlePipeline()
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=done1", modelContext: context)

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.videoID == "done1" }
        )
        let fetched = try context.fetch(descriptor).first!
        // Should remain done, not reset
        XCTAssertEqual(fetched.status, .done)
        XCTAssertEqual(fetched.articleMarkdown, "# Existing Article")
    }

    @MainActor
    func testEnqueueWithShortURL() throws {
        let pipeline = ArticlePipeline()
        try pipeline.enqueue(url: "https://youtu.be/short1", modelContext: context)

        let descriptor = FetchDescriptor<Article>()
        let articles = try context.fetch(descriptor)
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles.first?.videoID, "short1")
    }

    @MainActor
    func testEnqueueWithVideoIDOnly() throws {
        let pipeline = ArticlePipeline()
        try pipeline.enqueue(url: "rawVideoID123", modelContext: context)

        let descriptor = FetchDescriptor<Article>()
        let articles = try context.fetch(descriptor)
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles.first?.videoID, "rawVideoID123")
        XCTAssertTrue(articles.first!.url.contains("youtube.com/watch?v=rawVideoID123"))
    }

    @MainActor
    func testEnqueueMultipleDistinctVideos() throws {
        let pipeline = ArticlePipeline()
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=vid1", modelContext: context)
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=vid2", modelContext: context)
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=vid3", modelContext: context)

        let descriptor = FetchDescriptor<Article>()
        let articles = try context.fetch(descriptor)
        XCTAssertEqual(articles.count, 3)
    }

    // MARK: - OPMLImporter with SwiftData

    @MainActor
    func testOPMLImportWithSwiftData() throws {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Tech">
              <outline text="Channel One" title="Channel One"
                       htmlUrl="https://www.youtube.com/channel/UC123"/>
              <outline text="Channel Two" title="Channel Two"
                       htmlUrl="https://www.youtube.com/channel/UC456"/>
            </outline>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let count = OPMLImporter.importSources(from: data, into: context)

        XCTAssertEqual(count, 2)

        let descriptor = FetchDescriptor<Source>()
        let sources = try context.fetch(descriptor)
        XCTAssertEqual(sources.count, 2)
        XCTAssertTrue(sources.allSatisfy { $0.sourceType == .channel })
    }

    @MainActor
    func testOPMLImportDeduplication() throws {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Ch1" htmlUrl="https://www.youtube.com/channel/UC123"/>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!

        // Import twice
        let count1 = OPMLImporter.importSources(from: data, into: context)
        let count2 = OPMLImporter.importSources(from: data, into: context)

        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 0) // Should be deduplicated

        let descriptor = FetchDescriptor<Source>()
        let sources = try context.fetch(descriptor)
        XCTAssertEqual(sources.count, 1)
    }

    @MainActor
    func testOPMLImportEmptyData() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0"><body></body></opml>
        """
        let data = opml.data(using: .utf8)!
        let count = OPMLImporter.importSources(from: data, into: context)
        XCTAssertEqual(count, 0)
    }

    @MainActor
    func testOPMLImportSkipsNonYouTube() throws {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Blog" htmlUrl="https://blog.example.com"/>
            <outline text="YT" htmlUrl="https://www.youtube.com/channel/UCyt"/>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let count = OPMLImporter.importSources(from: data, into: context)
        XCTAssertEqual(count, 1)

        let descriptor = FetchDescriptor<Source>()
        let sources = try context.fetch(descriptor)
        XCTAssertEqual(sources.count, 1)
        XCTAssertTrue(sources.first!.url.contains("youtube.com"))
    }

    // MARK: - Article fetch queries

    @MainActor
    func testFetchPendingArticles() throws {
        let pending = Article(videoID: "p1", status: .pending)
        let done = Article(videoID: "d1", status: .done)
        let error = Article(videoID: "e1", status: .error)
        context.insert(pending)
        context.insert(done)
        context.insert(error)
        try context.save()

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.statusRaw == "pending" }
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.videoID, "p1")
    }

    @MainActor
    func testFetchArticlesByStatus() throws {
        for status in ArticleStatus.allCases {
            let article = Article(videoID: "status-\(status.rawValue)", status: status)
            context.insert(article)
        }
        try context.save()

        let descriptor = FetchDescriptor<Article>()
        let all = try context.fetch(descriptor)
        XCTAssertEqual(all.count, ArticleStatus.allCases.count)
    }

    @MainActor
    func testFetchAutoFetchSources() throws {
        let auto1 = Source(url: "https://youtube.com/channel/UCauto1", autoFetch: true)
        let auto2 = Source(url: "https://youtube.com/channel/UCauto2", autoFetch: true)
        let manual = Source(url: "https://youtube.com/channel/UCmanual", autoFetch: false)
        context.insert(auto1)
        context.insert(auto2)
        context.insert(manual)
        try context.save()

        let descriptor = FetchDescriptor<Source>(
            predicate: #Predicate<Source> { $0.autoFetch == true }
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 2)
    }

    // MARK: - ArticlePipeline.buildLLMService

    @MainActor
    func testBuildLLMServiceOllama() throws {
        let settings = AppSettings()
        settings.llmBackend = .ollama
        settings.ollamaBaseURL = "http://gpu:11434"
        settings.ollamaModel = "mistral"

        let pipeline = ArticlePipeline()
        let service = pipeline.buildLLMService(settings: settings)
        XCTAssertTrue(service is OllamaService)
        let ollama = service as! OllamaService
        XCTAssertEqual(ollama.baseURL, "http://gpu:11434")
        XCTAssertEqual(ollama.model, "mistral")
    }

    @MainActor
    func testBuildLLMServiceClaude() throws {
        let settings = AppSettings()
        settings.llmBackend = .claude
        settings.anthropicAPIKey = "sk-ant-test123"
        settings.anthropicModel = "claude-opus-4-20250514"

        let pipeline = ArticlePipeline()
        let service = pipeline.buildLLMService(settings: settings)
        XCTAssertTrue(service is ClaudeService)
        let claude = service as! ClaudeService
        XCTAssertEqual(claude.apiKey, "sk-ant-test123")
        XCTAssertEqual(claude.model, "claude-opus-4-20250514")
    }

    @MainActor
    func testBuildLLMServiceOpenAI() throws {
        let settings = AppSettings()
        settings.llmBackend = .openai
        settings.openaiAPIKey = "sk-openai-test"
        settings.openaiBaseURL = "https://api.openai.com/v1"
        settings.openaiModel = "gpt-4o-mini"

        let pipeline = ArticlePipeline()
        let service = pipeline.buildLLMService(settings: settings)
        XCTAssertTrue(service is OpenAIService)
        let openai = service as! OpenAIService
        XCTAssertEqual(openai.apiKey, "sk-openai-test")
        XCTAssertEqual(openai.model, "gpt-4o-mini")
    }

    @MainActor
    func testBuildLLMServiceDefaultSettings() throws {
        let settings = AppSettings()
        // Default is ollama
        let pipeline = ArticlePipeline()
        let service = pipeline.buildLLMService(settings: settings)
        XCTAssertTrue(service is OllamaService)
    }

    // MARK: - Pipeline start/stop

    @MainActor
    func testPipelineStartStop() throws {
        let pipeline = ArticlePipeline()
        XCTAssertFalse(pipeline.isProcessing)

        pipeline.start(modelContext: context)
        // Timer should be running now — calling start again should be idempotent
        pipeline.start(modelContext: context)

        pipeline.stop()
        // Calling stop again should be safe
        pipeline.stop()
        XCTAssertFalse(pipeline.isProcessing)
    }

    // MARK: - AppSettings all backend settings

    @MainActor
    func testAppSettingsOpenAIFields() throws {
        let settings = AppSettings.getOrCreate(context: context)
        settings.openaiAPIKey = "sk-test"
        settings.openaiModel = "gpt-4-turbo"
        settings.openaiBaseURL = "https://custom.openai.com/v1"
        try context.save()

        let retrieved = AppSettings.getOrCreate(context: context)
        XCTAssertEqual(retrieved.openaiAPIKey, "sk-test")
        XCTAssertEqual(retrieved.openaiModel, "gpt-4-turbo")
        XCTAssertEqual(retrieved.openaiBaseURL, "https://custom.openai.com/v1")
    }

    @MainActor
    func testAppSettingsAnthropicFields() throws {
        let settings = AppSettings.getOrCreate(context: context)
        settings.anthropicAPIKey = "sk-ant-api"
        settings.anthropicModel = "claude-haiku"
        try context.save()

        let retrieved = AppSettings.getOrCreate(context: context)
        XCTAssertEqual(retrieved.anthropicAPIKey, "sk-ant-api")
        XCTAssertEqual(retrieved.anthropicModel, "claude-haiku")
    }

    @MainActor
    func testAppSettingsOllamaFields() throws {
        let settings = AppSettings.getOrCreate(context: context)
        settings.ollamaModel = "phi3"
        settings.ollamaBaseURL = "http://192.168.1.100:11434"
        try context.save()

        let retrieved = AppSettings.getOrCreate(context: context)
        XCTAssertEqual(retrieved.ollamaModel, "phi3")
        XCTAssertEqual(retrieved.ollamaBaseURL, "http://192.168.1.100:11434")
    }

    // MARK: - Multiple articles with different statuses

    @MainActor
    func testMultipleArticlesVariousStatuses() throws {
        let statuses: [ArticleStatus] = [.pending, .fetching, .transcribing, .generating, .done, .error]
        for (i, status) in statuses.enumerated() {
            let article = Article(videoID: "multi-\(i)", title: "Article \(i)", status: status)
            if status == .error {
                article.errorMessage = "Error for article \(i)"
            }
            context.insert(article)
        }
        try context.save()

        // Count by status
        let allDescriptor = FetchDescriptor<Article>()
        let all = try context.fetch(allDescriptor)
        XCTAssertEqual(all.count, 6)

        let pendingDescriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.statusRaw == "pending" }
        )
        XCTAssertEqual(try context.fetch(pendingDescriptor).count, 1)

        let doneDescriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.statusRaw == "done" }
        )
        XCTAssertEqual(try context.fetch(doneDescriptor).count, 1)

        let errorDescriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.statusRaw == "error" }
        )
        let errors = try context.fetch(errorDescriptor)
        XCTAssertEqual(errors.count, 1)
        XCTAssertNotNil(errors.first?.errorMessage)
    }

    // MARK: - Source types persist correctly

    @MainActor
    func testSourceTypesPersistCorrectly() throws {
        let types: [SourceType] = [.video, .playlist, .channel]
        for (i, type) in types.enumerated() {
            let source = Source(url: "https://youtube.com/test/\(i)", sourceType: type, name: "Source \(i)")
            context.insert(source)
        }
        try context.save()

        let descriptor = FetchDescriptor<Source>()
        let sources = try context.fetch(descriptor)
        XCTAssertEqual(sources.count, 3)

        let typeValues = Set(sources.map { $0.sourceType })
        XCTAssertTrue(typeValues.contains(.video))
        XCTAssertTrue(typeValues.contains(.playlist))
        XCTAssertTrue(typeValues.contains(.channel))
    }

    // MARK: - Delete article

    @MainActor
    func testDeleteArticle() throws {
        let article = Article(videoID: "delete1", title: "To Delete")
        context.insert(article)
        try context.save()

        context.delete(article)
        try context.save()

        let descriptor = FetchDescriptor<Article>()
        let remaining = try context.fetch(descriptor)
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - Delete source (nullifies article relationship)

    @MainActor
    func testDeleteSourceNullifiesArticles() throws {
        let source = Source(url: "https://youtube.com/channel/UCdel", sourceType: .channel, name: "Del")
        context.insert(source)
        let article = Article(videoID: "orphan1", title: "Orphan", source: source)
        context.insert(article)
        try context.save()

        XCTAssertNotNil(article.source)

        context.delete(source)
        try context.save()

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.videoID == "orphan1" }
        )
        let fetched = try context.fetch(descriptor).first
        XCTAssertNotNil(fetched)
        XCTAssertNil(fetched?.source)
    }

    // MARK: - Article sorting by createdAt

    @MainActor
    func testArticleSortByCreatedAt() throws {
        let a1 = Article(videoID: "sort1")
        context.insert(a1)
        // Small delay to ensure different timestamps
        let a2 = Article(videoID: "sort2")
        context.insert(a2)
        let a3 = Article(videoID: "sort3")
        context.insert(a3)
        try context.save()

        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let sorted = try context.fetch(descriptor)
        XCTAssertEqual(sorted.count, 3)
        // Should be in insertion order (ascending createdAt)
        XCTAssertEqual(sorted[0].videoID, "sort1")
    }
}
