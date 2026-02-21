import XCTest

final class LLMServiceTests: XCTestCase {

    // MARK: - Prompt templates

    func testArticlePromptContainsAllFields() {
        let prompt = PromptTemplates.articlePrompt(
            title: "Test Title",
            channel: "Test Channel",
            description: "A test description",
            chapters: "- [0:00] Intro\n- [5:00] Main",
            transcript: "This is the transcript content."
        )
        XCTAssertTrue(prompt.contains("Test Title"))
        XCTAssertTrue(prompt.contains("Test Channel"))
        XCTAssertTrue(prompt.contains("A test description"))
        XCTAssertTrue(prompt.contains("Intro"))
        XCTAssertTrue(prompt.contains("This is the transcript content."))
        XCTAssertTrue(prompt.contains("magazine-style"))
    }

    func testArticlePromptWithChaptersContainsHeadingInstruction() {
        let prompt = PromptTemplates.articlePromptWithChapters(
            title: "Test",
            channel: "Ch",
            description: "Desc",
            transcript: "## Intro\n\nContent here"
        )
        XCTAssertTrue(prompt.contains("## headings"))
        XCTAssertTrue(prompt.contains("## Intro"))
        XCTAssertTrue(prompt.contains("Content here"))
    }

    func testTranscriptTruncationAt50K() {
        let longTranscript = String(repeating: "a", count: 60_000)
        let prompt = PromptTemplates.articlePrompt(
            title: "T",
            channel: "C",
            description: "",
            chapters: "",
            transcript: longTranscript
        )
        // The truncated transcript should be 50,000 chars + template overhead
        XCTAssertTrue(prompt.count < 51_000)
    }

    func testChaptersPromptAlsoTruncates() {
        let longTranscript = String(repeating: "b", count: 60_000)
        let prompt = PromptTemplates.articlePromptWithChapters(
            title: "T",
            channel: "C",
            description: "",
            transcript: longTranscript
        )
        XCTAssertTrue(prompt.count < 51_000)
    }

    func testSystemPromptContent() {
        let sp = PromptTemplates.systemPrompt
        XCTAssertTrue(sp.contains("magazine-style"))
        XCTAssertTrue(sp.contains("In this video"))
        XCTAssertTrue(sp.contains("markdown"))
    }

    func testEmptyFieldsStillProduceValidPrompt() {
        let prompt = PromptTemplates.articlePrompt(
            title: "",
            channel: "",
            description: "",
            chapters: "",
            transcript: ""
        )
        XCTAssertTrue(prompt.contains("Transform this transcript"))
    }

    // MARK: - LLMError descriptions

    func testLLMErrorDescriptions() {
        let empty = LLMError.emptyResponse
        XCTAssertTrue(empty.localizedDescription.contains("empty"))

        let http = LLMError.httpError(429, "Rate limited")
        XCTAssertTrue(http.localizedDescription.contains("429"))
        XCTAssertTrue(http.localizedDescription.contains("Rate limited"))

        let url = LLMError.invalidURL("bad://url")
        XCTAssertTrue(url.localizedDescription.contains("bad://url"))
    }

    func testHTTPErrorTruncatesLongBody() {
        let longBody = String(repeating: "x", count: 500)
        let error = LLMError.httpError(500, longBody)
        XCTAssertTrue(error.localizedDescription.count < 400)
    }

    // MARK: - Service initialization

    func testOllamaServiceDefaults() {
        let service = OllamaService()
        XCTAssertEqual(service.baseURL, "http://localhost:11434")
        XCTAssertEqual(service.model, "llama3.2")
    }

    func testOllamaServiceTrimsTrailingSlash() {
        let service = OllamaService(baseURL: "http://localhost:11434/")
        XCTAssertEqual(service.baseURL, "http://localhost:11434")
    }

    func testClaudeServiceDefaults() {
        let service = ClaudeService(apiKey: "test-key")
        XCTAssertEqual(service.apiKey, "test-key")
        XCTAssertTrue(service.model.contains("claude"))
    }

    func testOpenAIServiceDefaults() {
        let service = OpenAIService(apiKey: "test-key")
        XCTAssertEqual(service.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(service.model, "gpt-4o")
    }

    func testOpenAIServiceCustomBaseURL() {
        let service = OpenAIService(
            apiKey: "key",
            baseURL: "http://localhost:1234/v1/",
            model: "local-model"
        )
        XCTAssertEqual(service.baseURL, "http://localhost:1234/v1")
        XCTAssertEqual(service.model, "local-model")
    }
}
