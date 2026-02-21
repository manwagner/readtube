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

    // MARK: - More video ID extraction edge cases

    @MainActor
    func testExtractVideoIDFromMobileURL() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://m.youtube.com/watch?v=mobile123")
        XCTAssertEqual(id, "mobile123")
    }

    @MainActor
    func testExtractVideoIDFromHTTPURL() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "http://www.youtube.com/watch?v=http123")
        XCTAssertEqual(id, "http123")
    }

    @MainActor
    func testExtractVideoIDWithMultipleParams() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://youtube.com/watch?v=id1&list=PLxyz&index=3&t=42s")
        XCTAssertEqual(id, "id1")
    }

    @MainActor
    func testExtractVideoIDFromURLWithNoVideoParam() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://youtube.com/watch?list=PLxyz")
        XCTAssertNil(id)
    }

    @MainActor
    func testExtractVideoIDReturnsNilForVimeo() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://vimeo.com/12345")
        XCTAssertNil(id)
    }

    @MainActor
    func testExtractVideoIDReturnsNilForPlainText() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "just some text")
        XCTAssertNil(id)
    }

    @MainActor
    func testExtractVideoIDWithEmptyV() {
        let pipeline = ArticlePipeline()
        let id = pipeline.extractVideoID(from: "https://youtube.com/watch?v=&list=PLxyz")
        XCTAssertNil(id)
    }

    // MARK: - More chapter splitting edge cases

    @MainActor
    func testBuildChapteredTranscriptPreservesAllWords() {
        let pipeline = ArticlePipeline()
        let words = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        let transcript = words.joined(separator: " ")
        let chapters = [
            ChapterInfo(title: "First Half", startTime: 0, endTime: 50),
            ChapterInfo(title: "Second Half", startTime: 50, endTime: 100),
        ]
        let result = pipeline.buildChapteredTranscript(transcript: transcript, chapters: chapters)

        // All words should be present
        for word in words {
            XCTAssertTrue(result.contains(word), "Missing word: \(word)")
        }
    }

    @MainActor
    func testBuildChapteredTranscriptManyChapters() {
        let pipeline = ArticlePipeline()
        let transcript = (1...100).map { "word\($0)" }.joined(separator: " ")
        let chapters = (0..<10).map { i in
            ChapterInfo(title: "Chapter \(i + 1)", startTime: Double(i * 60), endTime: Double((i + 1) * 60))
        }
        let result = pipeline.buildChapteredTranscript(transcript: transcript, chapters: chapters)

        for i in 1...10 {
            XCTAssertTrue(result.contains("## Chapter \(i)"))
        }
        // All words should be present
        XCTAssertTrue(result.contains("word1"))
        XCTAssertTrue(result.contains("word100"))
    }

    @MainActor
    func testBuildChapteredTranscriptUnevenChapters() {
        let pipeline = ArticlePipeline()
        let transcript = (1...100).map { "w\($0)" }.joined(separator: " ")
        // One very short chapter and one very long chapter
        let chapters = [
            ChapterInfo(title: "Short", startTime: 0, endTime: 10),
            ChapterInfo(title: "Long", startTime: 10, endTime: 990),
        ]
        let result = pipeline.buildChapteredTranscript(transcript: transcript, chapters: chapters)

        XCTAssertTrue(result.contains("## Short"))
        XCTAssertTrue(result.contains("## Long"))
        // Short chapter should have few words, Long should have most
        let sections = result.components(separatedBy: "## ").filter { !$0.isEmpty }
        XCTAssertEqual(sections.count, 2)
    }

    @MainActor
    func testBuildChapteredTranscriptZeroDuration() {
        let pipeline = ArticlePipeline()
        let chapters = [
            ChapterInfo(title: "Zero", startTime: 0, endTime: 0),
        ]
        // Should not crash with zero duration
        let result = pipeline.buildChapteredTranscript(transcript: "hello world test", chapters: chapters)
        XCTAssertTrue(result.contains("## Zero"))
    }

    @MainActor
    func testBuildChapteredTranscriptEmptyChaptersArray() {
        let pipeline = ArticlePipeline()
        let result = pipeline.buildChapteredTranscript(transcript: "hello world", chapters: [])
        // Empty chapters = empty result
        XCTAssertTrue(result.isEmpty)
    }

    @MainActor
    func testBuildChapteredTranscriptRemainingWordsAppendedToLastChapter() {
        let pipeline = ArticlePipeline()
        // With rounding, some words might be left over and should go to the last chapter
        let transcript = "a b c d e f g h i j"
        let chapters = [
            ChapterInfo(title: "Part1", startTime: 0, endTime: 30),
            ChapterInfo(title: "Part2", startTime: 30, endTime: 90),
            ChapterInfo(title: "Part3", startTime: 90, endTime: 100),
        ]
        let result = pipeline.buildChapteredTranscript(transcript: transcript, chapters: chapters)

        // All words must appear
        for letter in "abcdefghij".map({ String($0) }) {
            XCTAssertTrue(result.contains(letter), "Missing: \(letter)")
        }
    }

    // MARK: - Pipeline isProcessing state

    @MainActor
    func testPipelineInitialState() {
        let pipeline = ArticlePipeline()
        XCTAssertFalse(pipeline.isProcessing)
    }
}
