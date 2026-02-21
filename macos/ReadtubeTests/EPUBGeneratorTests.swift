import XCTest
@testable import Readtube

final class EPUBGeneratorTests: XCTestCase {
    func testGenerateProducesData() throws {
        let data = try EPUBGenerator.generate(
            title: "Test Article",
            channel: "Test Channel",
            articleURL: "https://youtube.com/watch?v=test123",
            markdown: "# Hello\n\nThis is a test article with **bold** text."
        )
        // EPUB starts with PK (ZIP magic bytes)
        XCTAssertTrue(data.count > 100)
        XCTAssertEqual(data[0], 0x50) // P
        XCTAssertEqual(data[1], 0x4B) // K
    }

    func testEscapeXML() {
        // Test through the generator with special characters in title
        let data = try? EPUBGenerator.generate(
            title: "Title with <special> & \"chars\"",
            channel: "Channel's Name",
            articleURL: "https://example.com/?a=1&b=2",
            markdown: "Content"
        )
        XCTAssertNotNil(data)
    }
}
