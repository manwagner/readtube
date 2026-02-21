import XCTest

/// Tests for enum types, model defaults, and computed properties.
final class ModelTests: XCTestCase {

    // MARK: - ArticleStatus

    func testArticleStatusAllCases() {
        let cases = ArticleStatus.allCases
        XCTAssertEqual(cases.count, 6)
        XCTAssertTrue(cases.contains(.pending))
        XCTAssertTrue(cases.contains(.fetching))
        XCTAssertTrue(cases.contains(.transcribing))
        XCTAssertTrue(cases.contains(.generating))
        XCTAssertTrue(cases.contains(.done))
        XCTAssertTrue(cases.contains(.error))
    }

    func testArticleStatusRawValues() {
        XCTAssertEqual(ArticleStatus.pending.rawValue, "pending")
        XCTAssertEqual(ArticleStatus.done.rawValue, "done")
        XCTAssertEqual(ArticleStatus.error.rawValue, "error")
    }

    func testArticleStatusFromInvalidRaw() {
        XCTAssertNil(ArticleStatus(rawValue: "invalid"))
        XCTAssertNil(ArticleStatus(rawValue: ""))
    }

    // MARK: - SourceType

    func testSourceTypeAllCases() {
        let cases = SourceType.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.video))
        XCTAssertTrue(cases.contains(.playlist))
        XCTAssertTrue(cases.contains(.channel))
    }

    func testSourceTypeRawValues() {
        XCTAssertEqual(SourceType.video.rawValue, "video")
        XCTAssertEqual(SourceType.playlist.rawValue, "playlist")
        XCTAssertEqual(SourceType.channel.rawValue, "channel")
    }

    // MARK: - LLMBackend

    func testLLMBackendAllCases() {
        let cases = LLMBackend.allCases
        XCTAssertEqual(cases.count, 3)
    }

    func testLLMBackendRawValues() {
        XCTAssertEqual(LLMBackend.ollama.rawValue, "ollama")
        XCTAssertEqual(LLMBackend.claude.rawValue, "claude-api")
        XCTAssertEqual(LLMBackend.openai.rawValue, "openai")
    }

    func testLLMBackendDisplayNames() {
        XCTAssertEqual(LLMBackend.ollama.displayName, "Ollama")
        XCTAssertEqual(LLMBackend.claude.displayName, "Claude API")
        XCTAssertEqual(LLMBackend.openai.displayName, "OpenAI")
    }

    func testLLMBackendFromInvalidRaw() {
        XCTAssertNil(LLMBackend(rawValue: "not-a-backend"))
    }

    // MARK: - ThemeName

    func testThemeNameAllCases() {
        let cases = ThemeName.allCases
        XCTAssertEqual(cases.count, 4)
    }

    func testThemeNameDisplayNames() {
        XCTAssertEqual(ThemeName.default.displayName, "Default")
        XCTAssertEqual(ThemeName.dark.displayName, "Dark")
        XCTAssertEqual(ThemeName.modern.displayName, "Modern")
        XCTAssertEqual(ThemeName.minimal.displayName, "Minimal")
    }

    func testThemeNameCSSFileNames() {
        XCTAssertEqual(ThemeName.default.cssFileName, "default.css")
        XCTAssertEqual(ThemeName.dark.cssFileName, "dark.css")
        XCTAssertEqual(ThemeName.modern.cssFileName, "modern.css")
        XCTAssertEqual(ThemeName.minimal.cssFileName, "minimal.css")
    }

    // MARK: - TranscriptParserError

    func testTranscriptParserErrorDescription() {
        let error = TranscriptParserError.invalidFormat
        XCTAssertTrue(error.localizedDescription.contains("Invalid"))
        XCTAssertTrue(error.localizedDescription.contains("JSON3"))
    }

}
