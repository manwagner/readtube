import XCTest
import SwiftData

/// Integration tests that verify services work together correctly.
final class IntegrationTests: XCTestCase {

    // MARK: - TranscriptParser → ArticlePipeline chapter splitting

    @MainActor
    func testTranscriptToChapteredArticle() {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 2000, "segs": [{"utf8": "Welcome to the show"}]},
                {"tStartMs": 2000, "dDurationMs": 2000, "segs": [{"utf8": "Today we discuss AI"}]},
                {"tStartMs": 4000, "dDurationMs": 2000, "segs": [{"utf8": "It is very interesting"}]},
                {"tStartMs": 6000, "dDurationMs": 2000, "segs": [{"utf8": "Thanks for watching"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let transcript = try! TranscriptParser.parseJSON3(data)

        let pipeline = ArticlePipeline()
        let chapters = [
            ChapterInfo(title: "Introduction", startTime: 0, endTime: 4),
            ChapterInfo(title: "Conclusion", startTime: 4, endTime: 8),
        ]
        let result = pipeline.buildChapteredTranscript(transcript: transcript, chapters: chapters)

        XCTAssertTrue(result.contains("## Introduction"))
        XCTAssertTrue(result.contains("## Conclusion"))
        // All transcript words should be present in the chaptered output
        XCTAssertTrue(result.contains("Welcome"))
        XCTAssertTrue(result.contains("watching"))
    }

    // MARK: - MarkdownToHTML → EPUBGenerator

    func testMarkdownToEPUBPipeline() throws {
        let markdown = """
        # Test Article

        This is a **bold** statement.

        ## Section Two

        A paragraph with a [link](https://example.com).

        > A meaningful quote

        - Point 1
        - Point 2
        """

        // Step 1: Convert markdown to HTML
        let html = MarkdownToHTML.convert(markdown)
        XCTAssertTrue(html.contains("<h1>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<blockquote>"))

        // Step 2: Generate EPUB from the markdown
        let data = try EPUBGenerator.generate(
            title: "Integration Test",
            channel: "Test Channel",
            articleURL: "https://youtube.com/watch?v=test",
            markdown: markdown
        )

        // Step 3: Verify EPUB is valid
        XCTAssertTrue(data.count > 100)
        XCTAssertEqual(data[0], 0x50) // P
        XCTAssertEqual(data[1], 0x4B) // K
    }

    // MARK: - Prompt generation with transcript

    func testPromptTemplateWithRealTranscript() {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 5000, "segs": [{"utf8": "Hello everyone welcome back"}]},
                {"tStartMs": 5000, "dDurationMs": 5000, "segs": [{"utf8": "to another episode of our show"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let transcript = try! TranscriptParser.parseJSON3(data)

        let prompt = PromptTemplates.articlePrompt(
            title: "Episode 42",
            channel: "MyChannel",
            description: "A great episode",
            chapters: "",
            transcript: transcript
        )

        XCTAssertTrue(prompt.contains("Episode 42"))
        XCTAssertTrue(prompt.contains("MyChannel"))
        XCTAssertTrue(prompt.contains("Hello everyone"))
        XCTAssertTrue(prompt.contains("Transform this transcript"))
    }

    @MainActor
    func testChapteredPromptTemplateWithRealTranscript() {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 5000, "segs": [{"utf8": "Welcome to the intro"}]},
                {"tStartMs": 5000, "dDurationMs": 5000, "segs": [{"utf8": "Now the main content"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let transcript = try! TranscriptParser.parseJSON3(data)

        let pipeline = ArticlePipeline()
        let chapters = [
            ChapterInfo(title: "Intro", startTime: 0, endTime: 5),
            ChapterInfo(title: "Main", startTime: 5, endTime: 10),
        ]
        let chaptered = pipeline.buildChapteredTranscript(transcript: transcript, chapters: chapters)

        let prompt = PromptTemplates.articlePromptWithChapters(
            title: "Test Video",
            channel: "Channel",
            description: "",
            transcript: chaptered
        )

        XCTAssertTrue(prompt.contains("## Intro"))
        XCTAssertTrue(prompt.contains("## headings"))
    }

    // MARK: - Video ID extraction edge cases

    @MainActor
    func testVideoIDFromEmbedURL() {
        let pipeline = ArticlePipeline()
        // Standard watch URLs
        XCTAssertEqual(pipeline.extractVideoID(from: "https://youtube.com/watch?v=abc123"), "abc123")
        XCTAssertEqual(pipeline.extractVideoID(from: "http://www.youtube.com/watch?v=xyz"), "xyz")
        // Short URLs
        XCTAssertEqual(pipeline.extractVideoID(from: "https://youtu.be/short123"), "short123")
        // With extra parameters
        XCTAssertEqual(pipeline.extractVideoID(from: "https://youtube.com/watch?v=id1&list=PLxyz&index=3"), "id1")
        // Invalid
        XCTAssertNil(pipeline.extractVideoID(from: "not-a-url"))
        XCTAssertNil(pipeline.extractVideoID(from: "https://vimeo.com/12345"))
    }

    // MARK: - E2E: yt-dlp → TranscriptParser (requires yt-dlp)

    func testYTDLPVideoInfoAndSubtitles() async throws {
        do {
            _ = try await YTDLPService.shared.resolveYTDLPPath()
        } catch {
            print("Skipping e2e: yt-dlp not available")
            return
        }

        // Fetch video info
        let info = try await YTDLPService.shared.getVideoInfo(
            url: "https://www.youtube.com/watch?v=jNQXAC9IVRw"
        )
        XCTAssertEqual(info.videoID, "jNQXAC9IVRw")
        XCTAssertFalse(info.title.isEmpty)
        XCTAssertTrue(info.duration > 0)

        // Fetch subtitles and parse
        let transcript = try await YTDLPService.shared.getSubtitles(videoID: "jNQXAC9IVRw")
        XCTAssertFalse(transcript.isEmpty)

        // Build a prompt from the results
        let prompt = PromptTemplates.articlePrompt(
            title: info.title,
            channel: info.channel,
            description: "",
            chapters: "",
            transcript: transcript
        )
        XCTAssertTrue(prompt.contains(info.title))
        XCTAssertTrue(prompt.count > 200)
    }

    // MARK: - LLM service URL validation

    func testOpenAIServiceRejectsEmptyURL() async {
        let service = OpenAIService(apiKey: "key", baseURL: "", model: "model")
        do {
            _ = try await service.generate(prompt: "test", systemPrompt: nil, maxTokens: 10, temperature: 0.5)
            XCTFail("Should have thrown")
        } catch {
            // Expected: either invalid URL or network error
            XCTAssertTrue(error is LLMError || error is URLError)
        }
    }

    func testOllamaServiceWithInvalidBaseURL() {
        // Empty base URL should produce invalid URL error
        let service = OllamaService(baseURL: "", model: "test")
        XCTAssertEqual(service.baseURL, "")
        XCTAssertEqual(service.model, "test")
    }

    // MARK: - Full pipeline integration (no network)

    func testFullPipelineTranscriptToEPUB() throws {
        // Step 1: Parse transcript
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 5000, "segs": [{"utf8": "Welcome to this episode about Swift programming"}]},
                {"tStartMs": 5000, "dDurationMs": 5000, "segs": [{"utf8": "Today we will discuss SwiftUI and how it changes development"}]},
                {"tStartMs": 10000, "dDurationMs": 5000, "segs": [{"utf8": "SwiftUI is a declarative framework for building user interfaces"}]},
                {"tStartMs": 15000, "dDurationMs": 5000, "segs": [{"utf8": "It works across all Apple platforms including macOS iOS and more"}]},
                {"tStartMs": 20000, "dDurationMs": 5000, "segs": [{"utf8": "Thanks for watching and dont forget to subscribe"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let transcript = try TranscriptParser.parseJSON3(data)
        XCTAssertFalse(transcript.isEmpty)
        XCTAssertTrue(transcript.contains("Swift programming"))

        // Step 2: Build prompt from transcript
        let prompt = PromptTemplates.articlePrompt(
            title: "SwiftUI Deep Dive",
            channel: "iOS Dev Weekly",
            description: "A comprehensive look at SwiftUI",
            chapters: "",
            transcript: transcript
        )
        XCTAssertTrue(prompt.contains("SwiftUI Deep Dive"))
        XCTAssertTrue(prompt.contains("Welcome to this episode"))

        // Step 3: Simulate LLM response (markdown article)
        let articleMD = """
        # SwiftUI: A Deep Dive

        SwiftUI has revolutionized how we build user interfaces across Apple platforms.

        ## The Declarative Approach

        SwiftUI introduces a **declarative** paradigm for UI development. Instead of
        imperatively constructing views, developers describe *what* the UI should look like.

        > "SwiftUI is a declarative framework for building user interfaces"

        ## Platform Support

        SwiftUI works across all Apple platforms:
        - macOS
        - iOS
        - watchOS
        - tvOS

        ## Conclusion

        The framework continues to evolve, making it easier than ever to build beautiful apps.
        """

        // Step 4: Convert markdown to HTML
        let html = MarkdownToHTML.convert(articleMD)
        XCTAssertTrue(html.contains("<h1>SwiftUI: A Deep Dive</h1>"))
        XCTAssertTrue(html.contains("<strong>declarative</strong>"))
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<em>what</em>"))

        // Step 5: Generate EPUB
        let epubData = try EPUBGenerator.generate(
            title: "SwiftUI Deep Dive",
            channel: "iOS Dev Weekly",
            articleURL: "https://youtube.com/watch?v=test",
            markdown: articleMD
        )

        // Step 6: Verify EPUB
        XCTAssertTrue(epubData.count > 100)
        XCTAssertEqual(epubData[0], 0x50) // ZIP magic
        XCTAssertEqual(epubData[1], 0x4B)
    }

    // MARK: - Chapter-aware pipeline

    @MainActor
    func testChapterAwarePipelineIntegration() throws {
        // Step 1: Parse transcript
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 5000, "segs": [{"utf8": "Welcome to part one of our series"}]},
                {"tStartMs": 5000, "dDurationMs": 5000, "segs": [{"utf8": "We will cover the basics today"}]},
                {"tStartMs": 10000, "dDurationMs": 5000, "segs": [{"utf8": "Now lets move to the advanced section"}]},
                {"tStartMs": 15000, "dDurationMs": 5000, "segs": [{"utf8": "Here we cover performance optimization"}]},
                {"tStartMs": 20000, "dDurationMs": 5000, "segs": [{"utf8": "To summarize everything we learned"}]},
                {"tStartMs": 25000, "dDurationMs": 5000, "segs": [{"utf8": "Thanks for watching see you next time"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let transcript = try TranscriptParser.parseJSON3(data)

        // Step 2: Split by chapters
        let chapters = [
            ChapterInfo(title: "Introduction", startTime: 0, endTime: 10),
            ChapterInfo(title: "Advanced Topics", startTime: 10, endTime: 20),
            ChapterInfo(title: "Summary", startTime: 20, endTime: 30),
        ]

        let pipeline = ArticlePipeline()
        let chaptered = pipeline.buildChapteredTranscript(transcript: transcript, chapters: chapters)

        XCTAssertTrue(chaptered.contains("## Introduction"))
        XCTAssertTrue(chaptered.contains("## Advanced Topics"))
        XCTAssertTrue(chaptered.contains("## Summary"))

        // Step 3: Build chaptered prompt
        let prompt = PromptTemplates.articlePromptWithChapters(
            title: "SwiftUI Series Part 1",
            channel: "Dev Channel",
            description: "First episode",
            transcript: chaptered
        )

        XCTAssertTrue(prompt.contains("SwiftUI Series Part 1"))
        XCTAssertTrue(prompt.contains("## Introduction"))
        XCTAssertTrue(prompt.contains("## headings"))

        // Step 4: Generate EPUB from the transcript content
        let epubData = try EPUBGenerator.generate(
            title: "SwiftUI Series Part 1",
            channel: "Dev Channel",
            articleURL: "https://youtube.com/watch?v=chapter_test",
            markdown: chaptered
        )
        XCTAssertTrue(epubData.count > 100)
    }

    // MARK: - Special characters through full pipeline

    func testSpecialCharactersThroughPipeline() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 5000, "segs": [{"utf8": "Tom & Jerry's <awesome> show"}]},
                {"tStartMs": 5000, "dDurationMs": 5000, "segs": [{"utf8": "Features \\\"quotes\\\" and 'apostrophes'"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let transcript = try TranscriptParser.parseJSON3(data)

        // Transcript should preserve special characters
        XCTAssertTrue(transcript.contains("&"))
        XCTAssertTrue(transcript.contains("<awesome>"))

        // MarkdownToHTML should escape them
        let html = MarkdownToHTML.convert(transcript)
        XCTAssertTrue(html.contains("&amp;"))

        // EPUB should handle escaped XML
        let epubData = try EPUBGenerator.generate(
            title: "Tom & Jerry's Show",
            channel: "Classic's & More",
            articleURL: "https://example.com?a=1&b=2",
            markdown: transcript
        )
        XCTAssertTrue(epubData.count > 100)
    }

    // MARK: - Large document through pipeline

    func testLargeDocumentThroughPipeline() throws {
        // Build a large transcript
        var events: [[String: Any]] = []
        for i in 0..<200 {
            events.append([
                "tStartMs": i * 3000,
                "dDurationMs": 3000,
                "segs": [["utf8": "This is sentence number \(i) in our long video about technology and innovation in the modern world"]]
            ] as [String: Any])
        }
        let obj: [String: Any] = ["events": events]
        let jsonData = try JSONSerialization.data(withJSONObject: obj)
        let transcript = try TranscriptParser.parseJSON3(jsonData)

        XCTAssertTrue(transcript.count > 10000)

        // Convert to markdown and then HTML
        let md = "# Large Article\n\n" + transcript
        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<h1>Large Article</h1>"))
        XCTAssertTrue(html.contains("sentence number 0"))
        XCTAssertTrue(html.contains("sentence number 199"))

        // Generate EPUB
        let epubData = try EPUBGenerator.generate(
            title: "Large Video Transcript",
            channel: "Tech Channel",
            articleURL: "https://example.com",
            markdown: md
        )
        XCTAssertTrue(epubData.count > 1000)
    }

    // MARK: - Video ID through pipeline

    @MainActor
    func testVideoIDExtractionInPipelineContext() {
        let pipeline = ArticlePipeline()
        let urls = [
            ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ"),
            ("https://youtu.be/dQw4w9WgXcQ", "dQw4w9WgXcQ"),
            ("https://m.youtube.com/watch?v=abc123", "abc123"),
            ("https://youtube.com/watch?v=xyz&t=42s&list=PLabc", "xyz"),
        ]

        for (url, expected) in urls {
            let extracted = pipeline.extractVideoID(from: url)
            XCTAssertEqual(extracted, expected, "Failed for URL: \(url)")
        }
    }

    // MARK: - Timestamp formatting in context

    func testTimestampFormattingRanges() {
        // Verify timestamps across common video durations
        XCTAssertEqual(TranscriptParser.formatTimestamp(0), "0:00")
        XCTAssertEqual(TranscriptParser.formatTimestamp(30), "0:30")
        XCTAssertEqual(TranscriptParser.formatTimestamp(90), "1:30")
        XCTAssertEqual(TranscriptParser.formatTimestamp(600), "10:00")
        XCTAssertEqual(TranscriptParser.formatTimestamp(3600), "1:00:00")
        XCTAssertEqual(TranscriptParser.formatTimestamp(5400), "1:30:00")
    }

    // MARK: - Empty chapters fallback

    @MainActor
    func testEmptyChaptersFallbackToRegularPrompt() {
        let pipeline = ArticlePipeline()
        let chapters: [ChapterInfo] = []
        let transcript = "Hello world this is a test"

        // When chapters are empty, we should use the regular prompt
        let chaptered = pipeline.buildChapteredTranscript(transcript: transcript, chapters: chapters)
        XCTAssertTrue(chaptered.isEmpty, "Empty chapters should produce empty result")

        // So we'd fall back to the regular prompt
        let prompt = PromptTemplates.articlePrompt(
            title: "Test",
            channel: "Ch",
            description: "",
            chapters: "",
            transcript: transcript
        )
        XCTAssertTrue(prompt.contains("Hello world"))
        XCTAssertTrue(prompt.contains("Transform this transcript"))
    }

    // MARK: - E2E: yt-dlp playlist (requires yt-dlp)

    func testYTDLPPlaylistVideoURLs() async throws {
        do {
            _ = try await YTDLPService.shared.resolveYTDLPPath()
        } catch {
            print("Skipping e2e: yt-dlp not available")
            return
        }

        // Use a small public playlist
        let urls = try await YTDLPService.shared.getPlaylistVideoURLs(
            url: "https://www.youtube.com/playlist?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf",
            max: 3
        )
        // This is a public playlist; it should return some URLs
        XCTAssertTrue(urls.count > 0 && urls.count <= 3)
        for url in urls {
            XCTAssertTrue(url.contains("youtube.com/watch?v="))
        }
    }

    // MARK: - Markdown features in EPUB context

    func testMarkdownListsInEPUB() throws {
        let md = """
        # Article with Lists

        Key points:

        - **First point**: Important insight
        - **Second point**: Another insight
        - **Third point**: Final insight

        Numbered steps:

        1. Start here
        2. Continue
        3. Finish
        """

        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<ol>"))

        let epub = try EPUBGenerator.generate(
            title: "Lists Article",
            channel: "Ch",
            articleURL: "https://example.com",
            markdown: md
        )
        XCTAssertTrue(epub.count > 100)
    }

    // MARK: - Real E2E: yt-dlp → TranscriptParser → Chapters → Prompt → MD → HTML → EPUB

    func testFullE2EPipelineWithRealVideo() async throws {
        do {
            _ = try await YTDLPService.shared.resolveYTDLPPath()
        } catch {
            print("Skipping e2e: yt-dlp not available")
            return
        }

        // Step 1: Fetch real video info
        let info = try await YTDLPService.shared.getVideoInfo(
            url: "https://www.youtube.com/watch?v=jNQXAC9IVRw"
        )
        XCTAssertEqual(info.videoID, "jNQXAC9IVRw")
        XCTAssertFalse(info.title.isEmpty)
        XCTAssertFalse(info.channel.isEmpty)
        XCTAssertTrue(info.duration > 0)

        // Step 2: Fetch real subtitles
        let transcript = try await YTDLPService.shared.getSubtitles(videoID: info.videoID)
        XCTAssertFalse(transcript.isEmpty)
        XCTAssertTrue(transcript.count > 10)

        // Step 3: Build prompt
        let prompt = PromptTemplates.articlePrompt(
            title: info.title,
            channel: info.channel,
            description: info.description,
            chapters: "",
            transcript: transcript
        )
        XCTAssertTrue(prompt.contains(info.title))
        XCTAssertTrue(prompt.contains("Transform this transcript"))

        // Step 4: Simulate LLM response (we can't call a real LLM in tests)
        let simulatedArticle = """
        # \(info.title)

        This video by **\(info.channel)** covers an important moment in internet history.

        ## Key Points

        The video demonstrates the early days of YouTube and online video sharing.

        > \(String(transcript.prefix(100)))

        ## Conclusion

        This video remains one of the most significant uploads in YouTube's history.
        """

        // Step 5: Convert to HTML
        let html = MarkdownToHTML.convert(simulatedArticle)
        XCTAssertTrue(html.contains("<h1>"))
        XCTAssertTrue(html.contains("<strong>"))
        XCTAssertTrue(html.contains("<blockquote>"))

        // Step 6: Generate EPUB
        let epubData = try EPUBGenerator.generate(
            title: info.title,
            channel: info.channel,
            articleURL: info.url,
            markdown: simulatedArticle,
            thumbnailURL: info.thumbnailURL
        )

        // Step 7: Verify EPUB
        XCTAssertTrue(epubData.count > 100)
        XCTAssertEqual(epubData[0], 0x50) // ZIP magic
        XCTAssertEqual(epubData[1], 0x4B)
    }

    func testE2ESubtitleParsingPreservesContent() async throws {
        do {
            _ = try await YTDLPService.shared.resolveYTDLPPath()
        } catch {
            print("Skipping e2e: yt-dlp not available")
            return
        }

        // Fetch subtitles from Rick Astley - well-known to have auto-generated subs
        let transcript = try await YTDLPService.shared.getSubtitles(videoID: "dQw4w9WgXcQ")

        // Should be a substantial transcript
        XCTAssertTrue(transcript.count > 200)
        // Should not contain JSON artifacts
        XCTAssertFalse(transcript.contains("\"utf8\""))
        XCTAssertFalse(transcript.contains("\"segs\""))
        XCTAssertFalse(transcript.contains("\"events\""))
        // Should be readable text
        XCTAssertFalse(transcript.isEmpty)
    }

    func testE2EVideoInfoContainsExpectedFields() async throws {
        do {
            _ = try await YTDLPService.shared.resolveYTDLPPath()
        } catch {
            print("Skipping e2e: yt-dlp not available")
            return
        }

        let info = try await YTDLPService.shared.getVideoInfo(
            url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )

        XCTAssertEqual(info.videoID, "dQw4w9WgXcQ")
        XCTAssertTrue(info.title.contains("Rick") || info.title.contains("rick") || info.title.contains("Never") || info.title.contains("never"))
        XCTAssertFalse(info.channel.isEmpty)
        XCTAssertTrue(info.duration > 100) // ~3.5 min video
        XCTAssertNotNil(info.thumbnailURL)
        XCTAssertTrue(info.url.contains("youtube.com"))
    }

    func testE2ETranscriptToHTMLQuality() async throws {
        do {
            _ = try await YTDLPService.shared.resolveYTDLPPath()
        } catch {
            print("Skipping e2e: yt-dlp not available")
            return
        }

        let transcript = try await YTDLPService.shared.getSubtitles(videoID: "jNQXAC9IVRw")

        // Wrap in markdown and convert
        let md = "# Video Transcript\n\n\(transcript)"
        let html = MarkdownToHTML.convert(md)

        XCTAssertTrue(html.contains("<h1>Video Transcript</h1>"))
        XCTAssertTrue(html.contains("<p>"))
        // HTML should be longer than raw text (tags add length)
        XCTAssertTrue(html.count >= transcript.count)
    }

    // MARK: - E2E: Pipeline with SwiftData

    @MainActor
    func testE2EEnqueueAndVerifyInDatabase() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Article.self, Source.self, AppSettings.self,
            configurations: config
        )
        let context = ModelContext(container)

        let pipeline = ArticlePipeline()

        // Enqueue multiple videos
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=jNQXAC9IVRw", modelContext: context)
        try pipeline.enqueue(url: "https://youtu.be/dQw4w9WgXcQ", modelContext: context)
        try pipeline.enqueue(url: "abc123", modelContext: context) // raw video ID

        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let articles = try context.fetch(descriptor)
        XCTAssertEqual(articles.count, 3)

        // All should be pending
        XCTAssertTrue(articles.allSatisfy { $0.status == .pending })

        // Video IDs extracted correctly
        let ids = Set(articles.map(\.videoID))
        XCTAssertTrue(ids.contains("jNQXAC9IVRw"))
        XCTAssertTrue(ids.contains("dQw4w9WgXcQ"))
        XCTAssertTrue(ids.contains("abc123"))
    }

    @MainActor
    func testE2EOPMLImportThenEnqueue() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Article.self, Source.self, AppSettings.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Import OPML
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Tech Channels">
              <outline text="Channel A" htmlUrl="https://www.youtube.com/channel/UCA"/>
              <outline text="Channel B" htmlUrl="https://www.youtube.com/channel/UCB"/>
            </outline>
          </body>
        </opml>
        """
        let count = OPMLImporter.importSources(from: opml.data(using: .utf8)!, into: context)
        XCTAssertEqual(count, 2)

        // Verify sources exist
        let sourceDescriptor = FetchDescriptor<Source>()
        let sources = try context.fetch(sourceDescriptor)
        XCTAssertEqual(sources.count, 2)
        XCTAssertTrue(sources.allSatisfy { $0.sourceType == .channel })

        // Now enqueue a video
        let pipeline = ArticlePipeline()
        try pipeline.enqueue(url: "https://www.youtube.com/watch?v=test1", modelContext: context)

        let articleDescriptor = FetchDescriptor<Article>()
        let articles = try context.fetch(articleDescriptor)
        XCTAssertEqual(articles.count, 1)
    }

    @MainActor
    func testE2ESettingsConfigureLLMService() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Article.self, Source.self, AppSettings.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Configure settings
        let settings = AppSettings.getOrCreate(context: context)
        settings.llmBackend = .claude
        settings.anthropicAPIKey = "sk-ant-test"
        settings.anthropicModel = "claude-sonnet-4-20250514"
        try context.save()

        // Verify buildLLMService uses these settings
        let pipeline = ArticlePipeline()
        let service = pipeline.buildLLMService(settings: settings)
        XCTAssertTrue(service is ClaudeService)

        // Switch to OpenAI
        settings.llmBackend = .openai
        settings.openaiAPIKey = "sk-openai"
        try context.save()

        let service2 = pipeline.buildLLMService(settings: settings)
        XCTAssertTrue(service2 is OpenAIService)
    }

    func testMarkdownCodeBlocksInEPUB() throws {
        let md = """
        # Code Tutorial

        Here's a Swift example:

        ```swift
        struct ContentView: View {
            var body: some View {
                Text("Hello, World!")
            }
        }
        ```

        And Python:

        ```python
        def hello():
            print("world")
        ```
        """

        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("language-swift"))
        XCTAssertTrue(html.contains("language-python"))

        let epub = try EPUBGenerator.generate(
            title: "Code Tutorial",
            channel: "Dev Channel",
            articleURL: "https://example.com",
            markdown: md
        )
        XCTAssertTrue(epub.count > 100)
    }
}
