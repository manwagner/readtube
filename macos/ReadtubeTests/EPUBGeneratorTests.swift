import XCTest
import ZIPFoundation

final class EPUBGeneratorTests: XCTestCase {

    // MARK: - Basic generation

    func testGenerateProducesValidZIP() throws {
        let data = try EPUBGenerator.generate(
            title: "Test Article",
            channel: "Test Channel",
            articleURL: "https://youtube.com/watch?v=test123",
            markdown: "# Hello\n\nThis is a test article with **bold** text."
        )
        XCTAssertTrue(data.count > 100)
        XCTAssertEqual(data[0], 0x50) // P
        XCTAssertEqual(data[1], 0x4B) // K
    }

    func testGenerateContainsMimetype() throws {
        let data = try EPUBGenerator.generate(
            title: "Test",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: "Content"
        )
        let mimeBytes = Array("application/epub+zip".utf8)
        let dataBytes = Array(data)
        var found = false
        for i in 0...(dataBytes.count - mimeBytes.count) {
            if Array(dataBytes[i..<(i + mimeBytes.count)]) == mimeBytes {
                found = true
                break
            }
        }
        XCTAssertTrue(found, "EPUB should contain mimetype string")
    }

    // MARK: - ZIP structure validation

    func testEPUBContainsRequiredFiles() throws {
        let data = try EPUBGenerator.generate(
            title: "Structure Test",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: "# Test\n\nContent"
        )

        // Write to temp file and open as archive
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.epub")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let archive = Archive(url: tmpURL, accessMode: .read) else {
            XCTFail("Could not open EPUB as ZIP archive")
            return
        }

        // Collect all entry paths
        var paths: Set<String> = []
        for entry in archive {
            paths.insert(entry.path)
        }

        // Verify required EPUB structure
        XCTAssertTrue(paths.contains("mimetype"), "Missing mimetype")
        XCTAssertTrue(paths.contains("META-INF/container.xml"), "Missing container.xml")
        XCTAssertTrue(paths.contains("OEBPS/content.opf"), "Missing content.opf")
        XCTAssertTrue(paths.contains("OEBPS/toc.ncx"), "Missing toc.ncx")
        XCTAssertTrue(paths.contains("OEBPS/nav.xhtml"), "Missing nav.xhtml")
        XCTAssertTrue(paths.contains("OEBPS/chapter_1.xhtml"), "Missing chapter")
        XCTAssertTrue(paths.contains("OEBPS/style/typography.css"), "Missing CSS")
    }

    func testMimetypeIsFirstEntry() throws {
        let data = try EPUBGenerator.generate(
            title: "Order Test",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: "Content"
        )

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-order.epub")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let archive = Archive(url: tmpURL, accessMode: .read) else {
            XCTFail("Could not open EPUB")
            return
        }

        // First entry should be mimetype (EPUB spec requirement)
        let firstEntry = archive.first(where: { _ in true })
        XCTAssertEqual(firstEntry?.path, "mimetype")
    }

    // MARK: - Special characters

    func testSpecialCharactersInTitle() {
        let data = try? EPUBGenerator.generate(
            title: "Title with <special> & \"chars\" and 'quotes'",
            channel: "Channel's & Name",
            articleURL: "https://example.com/?a=1&b=2",
            markdown: "Content with <html> tags & ampersands"
        )
        XCTAssertNotNil(data)
        if let data = data {
            XCTAssertEqual(data[0], 0x50)
            XCTAssertEqual(data[1], 0x4B)
        }
    }

    func testUnicodeContent() throws {
        let data = try EPUBGenerator.generate(
            title: "日本語タイトル",
            channel: "チャンネル",
            articleURL: "https://example.com",
            markdown: "# 見出し\n\nこんにちは世界"
        )
        XCTAssertTrue(data.count > 100)
    }

    // MARK: - Empty content

    func testEmptyMarkdown() throws {
        let data = try EPUBGenerator.generate(
            title: "Empty",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: ""
        )
        XCTAssertTrue(data.count > 0)
    }

    // MARK: - Without thumbnail

    func testGenerateWithoutThumbnail() throws {
        let data = try EPUBGenerator.generate(
            title: "No Thumb",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: "# Article\n\nContent here",
            thumbnailURL: nil
        )
        XCTAssertTrue(data.count > 100)
    }

    // MARK: - Large content

    func testLargeArticle() throws {
        let largeMD = (1...50).map { "## Section \($0)\n\n" + String(repeating: "Lorem ipsum. ", count: 100) }.joined(separator: "\n\n")
        let data = try EPUBGenerator.generate(
            title: "Large Article",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: largeMD
        )
        XCTAssertTrue(data.count > 1000)
    }

    // MARK: - Markdown with complex formatting

    func testMarkdownWithCodeBlocks() throws {
        let md = """
        # Code Article

        Here is some code:

        ```python
        def hello():
            print("world")
        ```

        And more text.
        """
        let data = try EPUBGenerator.generate(
            title: "Code Article",
            channel: "Dev Channel",
            articleURL: "https://example.com",
            markdown: md
        )
        XCTAssertTrue(data.count > 100)
    }

    func testMarkdownWithLists() throws {
        let md = """
        # List Article

        - Item one
        - Item two
        - Item three

        1. First
        2. Second
        3. Third
        """
        let data = try EPUBGenerator.generate(
            title: "List Article",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: md
        )
        XCTAssertTrue(data.count > 100)
    }

    // MARK: - EPUBError

    func testEPUBErrorDescriptions() {
        let archiveError = EPUBError.archiveFailed
        XCTAssertTrue(archiveError.localizedDescription.contains("archive"))

        let encodingError = EPUBError.encodingFailed
        XCTAssertTrue(encodingError.localizedDescription.contains("UTF-8"))
    }
}
