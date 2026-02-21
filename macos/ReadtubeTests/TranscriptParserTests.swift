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

    // MARK: - Unicode and special characters

    func testParseJSON3Unicode() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 3000, "segs": [{"utf8": "こんにちは世界"}]},
                {"tStartMs": 3000, "dDurationMs": 3000, "segs": [{"utf8": "Привет мир"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertTrue(result.contains("こんにちは世界"))
        XCTAssertTrue(result.contains("Привет мир"))
    }

    func testParseJSON3Emojis() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 3000, "segs": [{"utf8": "That's great 😊"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertTrue(result.contains("😊"))
    }

    func testParseJSON3SpecialCharacters() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 3000, "segs": [{"utf8": "Tom & Jerry's <show>"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertTrue(result.contains("Tom & Jerry's <show>"))
    }

    // MARK: - Large transcripts

    func testParseJSON3LargeTranscript() throws {
        var events: [[String: Any]] = []
        for i in 0..<500 {
            events.append([
                "tStartMs": i * 2000,
                "dDurationMs": 2000,
                "segs": [["utf8": "Word number \(i)"]]
            ] as [String: Any])
        }
        let obj: [String: Any] = ["events": events]
        let data = try JSONSerialization.data(withJSONObject: obj)
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertTrue(result.contains("Word number 0"))
        XCTAssertTrue(result.contains("Word number 499"))
        XCTAssertTrue(result.count > 5000)
    }

    // MARK: - Multiple speaker labels

    func testParseJSON3MultipleSpeakers() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 3000, "segs": [{"utf8": "[Host] Welcome to the show"}]},
                {"tStartMs": 3000, "dDurationMs": 3000, "segs": [{"utf8": "[Guest] Thanks for having me"}]},
                {"tStartMs": 6000, "dDurationMs": 3000, "segs": [{"utf8": "[Host] Let's begin"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        // Count speaker labels
        let hostCount = result.components(separatedBy: "**Host:**").count - 1
        let guestCount = result.components(separatedBy: "**Guest:**").count - 1
        XCTAssertEqual(hostCount, 2)
        XCTAssertEqual(guestCount, 1)
    }

    func testParseJSON3SpeakerFollowedByRegularText() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 3000, "segs": [{"utf8": "[Speaker] Hello"}]},
                {"tStartMs": 3000, "dDurationMs": 3000, "segs": [{"utf8": "Regular text follows"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertTrue(result.contains("**Speaker:**"))
        XCTAssertTrue(result.contains("Regular text follows"))
    }

    // MARK: - Edge cases in segments

    func testParseJSON3EmptySegsArray() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 1000, "segs": []},
                {"tStartMs": 1000, "dDurationMs": 2000, "segs": [{"utf8": "Real content"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertEqual(result, "Real content")
    }

    func testParseJSON3SegWithMissingUtf8Key() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 1000, "segs": [{"other": "data"}]},
                {"tStartMs": 1000, "dDurationMs": 2000, "segs": [{"utf8": "Has utf8"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertEqual(result, "Has utf8")
    }

    func testParseJSON3EventMissingDuration() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "segs": [{"utf8": "No duration field"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertEqual(result, "No duration field")
    }

    func testParseJSON3EventMissingStartMs() throws {
        let json = """
        {
            "events": [
                {"dDurationMs": 2000, "segs": [{"utf8": "No start time"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertEqual(result, "No start time")
    }

    // MARK: - Timestamp formatting edge cases

    func testFormatTimestampLargeValues() {
        XCTAssertEqual(TranscriptParser.formatTimestamp(86400), "24:00:00")
        XCTAssertEqual(TranscriptParser.formatTimestamp(36000), "10:00:00")
    }

    func testFormatTimestampDecimalSeconds() {
        // Should truncate to integer seconds
        XCTAssertEqual(TranscriptParser.formatTimestamp(1.5), "0:01")
        XCTAssertEqual(TranscriptParser.formatTimestamp(59.9), "0:59")
        XCTAssertEqual(TranscriptParser.formatTimestamp(60.5), "1:00")
    }

    // MARK: - Error descriptions

    func testTranscriptParserErrorDescription() {
        let error = TranscriptParserError.invalidFormat
        XCTAssertEqual(error.errorDescription, "Invalid JSON3 subtitle format")
    }

    // MARK: - Non-duplicate consecutive different text

    func testParseJSON3DifferentConsecutiveTextsNotDeduplicated() throws {
        let json = """
        {
            "events": [
                {"tStartMs": 0, "dDurationMs": 1000, "segs": [{"utf8": "First"}]},
                {"tStartMs": 1000, "dDurationMs": 1000, "segs": [{"utf8": "Second"}]},
                {"tStartMs": 2000, "dDurationMs": 1000, "segs": [{"utf8": "First"}]}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        // "First" appears at positions 0 and 2 (not consecutive), both should be kept
        let count = result.components(separatedBy: "First").count - 1
        XCTAssertEqual(count, 2)
    }
}
