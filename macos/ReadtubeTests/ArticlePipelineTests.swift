import XCTest

final class ArticlePipelineTests: XCTestCase {

    // MARK: - Video ID extraction

    @MainActor
    func testExtractVideoIDFromStandardURL() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(id, "dQw4w9WgXcQ")
    }

    @MainActor
    func testExtractVideoIDFromShortURL() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://youtu.be/dQw4w9WgXcQ")
        XCTAssertEqual(id, "dQw4w9WgXcQ")
    }

    @MainActor
    func testExtractVideoIDWithExtraParams() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://www.youtube.com/watch?v=abc123&t=42s")
        XCTAssertEqual(id, "abc123")
    }

    @MainActor
    func testExtractVideoIDFromShortURLWithParams() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://youtu.be/abc123?t=42")
        XCTAssertEqual(id, "abc123")
    }

    @MainActor
    func testExtractVideoIDReturnsNilForInvalid() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://example.com/page")
        XCTAssertNil(id)
    }

    @MainActor
    func testExtractVideoIDReturnsNilForEmpty() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "")
        XCTAssertNil(id)
    }

    // MARK: - Chapter splitting

    @MainActor
    func testBuildChapteredTranscript() {
        let pipeline = ArticlePipeline()
        let chapters = [
            ChapterInfo(title: "Intro", startTime: 0, endTime: 60),
            ChapterInfo(title: "Main", startTime: 60, endTime: 180),
            ChapterInfo(title: "Outro", startTime: 180, endTime: 240),
        ]
        let transcript = (1...240).map { "word\($0)" }.joined(separator: " ")
        let result = pipeline.buildChapteredTranscript(transcript: transcript, chapters: chapters)

        XCTAssertTrue(result.contains("## Intro"))
        XCTAssertTrue(result.contains("## Main"))
        XCTAssertTrue(result.contains("## Outro"))
        let sections = result.components(separatedBy: "## ").filter { !$0.isEmpty }
        XCTAssertEqual(sections.count, 3)
    }

    @MainActor
    func testBuildChapteredTranscriptSingleChapter() {
        let pipeline = ArticlePipeline()
        let chapters = [
            ChapterInfo(title: "Full Video", startTime: 0, endTime: 100),
        ]
        let result = pipeline.buildChapteredTranscript(
            transcript: "one two three four five",
            chapters: chapters
        )
        XCTAssertTrue(result.contains("## Full Video"))
        XCTAssertTrue(result.contains("one two three four five"))
    }

    @MainActor
    func testBuildChapteredTranscriptEmptyTranscript() {
        let pipeline = ArticlePipeline()
        let chapters = [
            ChapterInfo(title: "Ch1", startTime: 0, endTime: 60),
        ]
        let result = pipeline.buildChapteredTranscript(transcript: "", chapters: chapters)
        XCTAssertTrue(result.contains("## Ch1"))
    }
}
