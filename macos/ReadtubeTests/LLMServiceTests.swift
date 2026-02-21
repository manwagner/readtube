import XCTest
@testable import Readtube

final class LLMServiceTests: XCTestCase {
    func testPromptTemplateGeneration() {
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
    }

    func testPromptTemplateChapters() {
        let prompt = PromptTemplates.articlePromptWithChapters(
            title: "Test",
            channel: "Ch",
            description: "Desc",
            transcript: "## Intro\n\nContent here"
        )

        XCTAssertTrue(prompt.contains("## headings"))
        XCTAssertTrue(prompt.contains("## Intro"))
    }

    func testTranscriptTruncation() {
        let longTranscript = String(repeating: "word ", count: 20_000)
        let prompt = PromptTemplates.articlePrompt(
            title: "T",
            channel: "C",
            description: "",
            chapters: "",
            transcript: longTranscript
        )
        // The prompt template truncates to 50,000 chars
        XCTAssertTrue(prompt.count < longTranscript.count + 500)
    }

    func testSystemPromptContent() {
        let sp = PromptTemplates.systemPrompt
        XCTAssertTrue(sp.contains("magazine-style"))
        XCTAssertTrue(sp.contains("In this video"))
    }
}
