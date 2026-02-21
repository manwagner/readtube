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

    // MARK: - Additional service initialization tests

    func testClaudeServiceCustomModel() {
        let service = ClaudeService(apiKey: "key", model: "claude-opus-4-20250514")
        XCTAssertEqual(service.model, "claude-opus-4-20250514")
        XCTAssertEqual(service.apiKey, "key")
    }

    func testOllamaServiceCustomModel() {
        let service = OllamaService(baseURL: "http://gpu-server:11434", model: "mistral-7b")
        XCTAssertEqual(service.baseURL, "http://gpu-server:11434")
        XCTAssertEqual(service.model, "mistral-7b")
    }

    func testOpenAIServiceMultipleTrailingSlashes() {
        let service = OpenAIService(apiKey: "key", baseURL: "http://localhost:1234/v1///")
        XCTAssertEqual(service.baseURL, "http://localhost:1234/v1")
    }

    func testOllamaServiceMultipleTrailingSlashes() {
        let service = OllamaService(baseURL: "http://localhost:11434///")
        XCTAssertEqual(service.baseURL, "http://localhost:11434")
    }

    func testOpenAIServiceEmptyAPIKey() {
        let service = OpenAIService(apiKey: "")
        XCTAssertEqual(service.apiKey, "")
        XCTAssertEqual(service.model, "gpt-4o")
    }

    func testClaudeServiceEmptyAPIKey() {
        let service = ClaudeService(apiKey: "")
        XCTAssertEqual(service.apiKey, "")
    }

    // MARK: - LLMError comprehensive tests

    func testLLMErrorEmptyResponseDescription() {
        let error = LLMError.emptyResponse
        XCTAssertEqual(error.errorDescription, "LLM returned empty response")
    }

    func testLLMErrorHTTPErrorDescription() {
        let error = LLMError.httpError(401, "Unauthorized")
        XCTAssertEqual(error.errorDescription, "HTTP 401: Unauthorized")
    }

    func testLLMErrorInvalidURLDescription() {
        let error = LLMError.invalidURL("not valid")
        XCTAssertEqual(error.errorDescription, "Invalid URL: not valid")
    }

    func testLLMErrorHTTPErrorTruncatesAt200Chars() {
        let longBody = String(repeating: "a", count: 300)
        let error = LLMError.httpError(500, longBody)
        let desc = error.errorDescription!
        // Should truncate body to 200 chars
        XCTAssertTrue(desc.count < 220) // "HTTP 500: " + 200
    }

    // MARK: - Prompt template edge cases

    func testPromptWithSpecialCharacters() {
        let prompt = PromptTemplates.articlePrompt(
            title: "Title with <html> & \"quotes\"",
            channel: "Channel's Name",
            description: "Description with \nnewlines",
            chapters: "",
            transcript: "Transcript with special chars: <>&\""
        )
        XCTAssertTrue(prompt.contains("<html>"))
        XCTAssertTrue(prompt.contains("Channel's Name"))
        XCTAssertTrue(prompt.contains("newlines"))
    }

    func testPromptWithUnicodeContent() {
        let prompt = PromptTemplates.articlePrompt(
            title: "日本語タイトル",
            channel: "チャンネル",
            description: "説明",
            chapters: "",
            transcript: "こんにちは世界"
        )
        XCTAssertTrue(prompt.contains("日本語タイトル"))
        XCTAssertTrue(prompt.contains("こんにちは世界"))
    }

    func testPromptWithExactly50KTranscript() {
        let transcript = String(repeating: "a", count: 50_000)
        let prompt = PromptTemplates.articlePrompt(
            title: "T", channel: "C", description: "", chapters: "", transcript: transcript
        )
        // Should NOT truncate at exactly 50K
        XCTAssertTrue(prompt.contains(transcript))
    }

    func testChaptersPromptWithExactly50KTranscript() {
        let transcript = String(repeating: "b", count: 50_000)
        let prompt = PromptTemplates.articlePromptWithChapters(
            title: "T", channel: "C", description: "", transcript: transcript
        )
        XCTAssertTrue(prompt.contains(transcript))
    }

    func testSystemPromptIsNotEmpty() {
        XCTAssertFalse(PromptTemplates.systemPrompt.isEmpty)
        XCTAssertTrue(PromptTemplates.systemPrompt.count > 50)
    }

    func testPromptWithVeryLongDescription() {
        let longDesc = String(repeating: "description ", count: 1000)
        let prompt = PromptTemplates.articlePrompt(
            title: "T", channel: "C", description: longDesc, chapters: "", transcript: "text"
        )
        XCTAssertTrue(prompt.contains("description"))
        XCTAssertTrue(prompt.contains("text"))
    }

    // MARK: - OpenAI service rejects empty URL

    func testOpenAIServiceRejectsEmptyURL() async {
        let service = OpenAIService(apiKey: "key", baseURL: "", model: "model")
        do {
            _ = try await service.generate(prompt: "test", systemPrompt: nil, maxTokens: 10, temperature: 0.5)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is LLMError || error is URLError)
        }
    }

    func testOllamaServiceWithEmptyBaseURL() {
        let service = OllamaService(baseURL: "", model: "test")
        XCTAssertEqual(service.baseURL, "")
    }
}
