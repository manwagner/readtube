import XCTest
@testable import Readtube

final class TranscriptParserTests: XCTestCase {
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

    func testParseJSON3SkipsEmpty() throws {
        let json = """
        {
            "events": [
                {
                    "tStartMs": 0,
                    "dDurationMs": 1000,
                    "segs": [{"utf8": "  "}]
                },
                {
                    "tStartMs": 1000,
                    "dDurationMs": 2000,
                    "segs": [{"utf8": "Content here"}]
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try TranscriptParser.parseJSON3(data)
        XCTAssertEqual(result, "Content here")
    }

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

    func testFormatTimestamp() {
        XCTAssertEqual(TranscriptParser.formatTimestamp(0), "0:00")
        XCTAssertEqual(TranscriptParser.formatTimestamp(65), "1:05")
        XCTAssertEqual(TranscriptParser.formatTimestamp(3661), "1:01:01")
    }

    func testInvalidFormat() {
        let data = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try TranscriptParser.parseJSON3(data))
    }
}
