import XCTest

final class TranscriptParserTests: XCTestCase {

    // MARK: - Basic parsing

    func testParseJSON3Basic() throws {
        let json = """
        {
            "events": [
                {
                    "tStartMs": 0,
                    "dDurationMs": 5000,
                    "segs": [{"utf8": "Hello world"}]
                },
                {
                    "tStartMs": 5000,
                    "dDurationMs": 3000,
                    "segs": [{"utf8": "This is a test"}]
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertTrue(result.contains("Hello world"))
        XCTAssertTrue(result.contains("This is a test"))
    }

    func testParseJSON3JoinsWithSpaces() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 2000, "segs": [{"utf8": "First"}]},
                {"tStartMs": 2000, "dDurationMs": 2000, "segs": [{"utf8": "Second"}]},
                {"tStartMs": 4000, "dDurationMs": 2000, "segs": [{"utf8": "Third"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertEqual(result, "First Second Third")
    }

    // MARK: - Empty/whitespace handling

    func testParseJSON3SkipsEmpty() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 1000, "segs": [{"utf8": "  "}]},
                {"tStartMs": 1000, "dDurationMs": 2000, "segs": [{"utf8": "Content here"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertEqual(result, "Content here")
    }

    func testParseJSON3SkipsNewlineOnly() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 1000, "segs": [{"utf8": "\\n"}]},
                {"tStartMs": 1000, "dDurationMs": 2000, "segs": [{"utf8": "Real content"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertEqual(result, "Real content")
    }

    func testParseJSON3EmptyEvents() throws {
        let json = "{\"events\": []}"
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Multiple segments per event

    func testParseJSON3MultipleSegments() throws {
        let json = """
        {
            "events": [
                {
                    "tStartMs": 0,
                    "dDurationMs": 5000,
                    "segs": [
                        {"utf8": "Part "},
                        {"utf8": "one "},
                        {"utf8": "here"}
                    ]
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertTrue(result.contains("Part one here"))
    }

    // MARK: - Duplicate filtering

    func testParseJSON3DeduplicatesConsecutive() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 2000, "segs": [{"utf8": "Same line"}]},
                {"tStartMs": 2000, "dDurationMs": 2000, "segs": [{"utf8": "Same line"}]},
                {"tStartMs": 4000, "dDurationMs": 2000, "segs": [{"utf8": "Different"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        // Should contain "Same line" only once
        let count = result.components(separatedBy: "Same line").count - 1
        XCTAssertEqual(count, 1)
        XCTAssertTrue(result.contains("Different"))
    }

    // MARK: - Speaker labels

    func testParseJSON3SpeakerLabels() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 3000, "segs": [{"utf8": "[John] Hello everyone"}]},
                {"tStartMs": 3000, "dDurationMs": 3000, "segs": [{"utf8": "[Jane] Hi John"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertTrue(result.contains("**John:**"))
        XCTAssertTrue(result.contains("**Jane:**"))
        XCTAssertTrue(result.contains("Hello everyone"))
        XCTAssertTrue(result.contains("Hi John"))
    }

    // MARK: - Timestamp formatting

    func testFormatTimestampSeconds() {
        XCTAssertEqual(TranscriptParser.formatTimestamp(0), "0:00")
        XCTAssertEqual(TranscriptParser.formatTimestamp(5), "0:05")
        XCTAssertEqual(TranscriptParser.formatTimestamp(59), "0:59")
    }

    func testFormatTimestampMinutes() {
        XCTAssertEqual(TranscriptParser.formatTimestamp(60), "1:00")
        XCTAssertEqual(TranscriptParser.formatTimestamp(65), "1:05")
        XCTAssertEqual(TranscriptParser.formatTimestamp(599), "9:59")
    }

    func testFormatTimestampHours() {
        XCTAssertEqual(TranscriptParser.formatTimestamp(3600), "1:00:00")
        XCTAssertEqual(TranscriptParser.formatTimestamp(3661), "1:01:01")
        XCTAssertEqual(TranscriptParser.formatTimestamp(7200), "2:00:00")
    }

    // MARK: - Error handling

    func testInvalidJSON() {
        let data = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try TranscriptParser.parseJSON3(data))
    }

    func testMissingEventsKey() {
        let data = "{\"other\": \"data\"}".data(using: .utf8)!
        XCTAssertThrowsError(try TranscriptParser.parseJSON3(data))
    }

    func testEventsWithNoSegs() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 1000},
                {"tStartMs": 1000, "dDurationMs": 2000, "segs": [{"utf8": "Has content"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertEqual(result, "Has content")
    }
}
