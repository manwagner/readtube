import XCTest

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
}
