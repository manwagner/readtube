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

    // MARK: - ArticleStatus Codable

    func testArticleStatusEncodeDecode() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for status in ArticleStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(ArticleStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - SourceType Codable

    func testSourceTypeEncodeDecode() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for sourceType in SourceType.allCases {
            let data = try encoder.encode(sourceType)
            let decoded = try decoder.decode(SourceType.self, from: data)
            XCTAssertEqual(decoded, sourceType)
        }
    }

    func testSourceTypeFromInvalidRaw() {
        XCTAssertNil(SourceType(rawValue: "invalid"))
        XCTAssertNil(SourceType(rawValue: ""))
    }

    // MARK: - LLMBackend Codable

    func testLLMBackendEncodeDecode() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for backend in LLMBackend.allCases {
            let data = try encoder.encode(backend)
            let decoded = try decoder.decode(LLMBackend.self, from: data)
            XCTAssertEqual(decoded, backend)
        }
    }

    // MARK: - ThemeName Codable

    func testThemeNameEncodeDecode() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for theme in ThemeName.allCases {
            let data = try encoder.encode(theme)
            let decoded = try decoder.decode(ThemeName.self, from: data)
            XCTAssertEqual(decoded, theme)
        }
    }

    func testThemeNameFromInvalidRaw() {
        XCTAssertNil(ThemeName(rawValue: "invalid"))
        XCTAssertNil(ThemeName(rawValue: ""))
    }

    // MARK: - ThemeName cssFileName format

    func testThemeNameCSSFileNameHasExtension() {
        for theme in ThemeName.allCases {
            XCTAssertTrue(theme.cssFileName.hasSuffix(".css"))
            XCTAssertTrue(theme.cssFileName.count > 4) // at least "x.css"
        }
    }

    // MARK: - LLMBackend display names are non-empty

    func testLLMBackendDisplayNamesAreNonEmpty() {
        for backend in LLMBackend.allCases {
            XCTAssertFalse(backend.displayName.isEmpty)
        }
    }

    // MARK: - ThemeName display names are non-empty

    func testThemeNameDisplayNamesAreNonEmpty() {
        for theme in ThemeName.allCases {
            XCTAssertFalse(theme.displayName.isEmpty)
        }
    }

    // MARK: - Enum case counts are stable

    func testArticleStatusCaseCountStable() {
        XCTAssertEqual(ArticleStatus.allCases.count, 6, "If you add a status, update this test")
    }

    func testSourceTypeCaseCountStable() {
        XCTAssertEqual(SourceType.allCases.count, 3, "If you add a source type, update this test")
    }

    func testLLMBackendCaseCountStable() {
        XCTAssertEqual(LLMBackend.allCases.count, 3, "If you add a backend, update this test")
    }

    func testThemeNameCaseCountStable() {
        XCTAssertEqual(ThemeName.allCases.count, 4, "If you add a theme, update this test")
    }
}
