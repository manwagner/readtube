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

    // MARK: - Content validation inside ZIP

    func testEPUBContentOPFContainsTitle() throws {
        let data = try EPUBGenerator.generate(
            title: "My Test Title",
            channel: "My Channel",
            articleURL: "https://example.com",
            markdown: "# Content"
        )

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-opf.epub")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let archive = Archive(url: tmpURL, accessMode: .read) else {
            XCTFail("Could not open EPUB")
            return
        }

        // Extract content.opf
        guard let entry = archive["OEBPS/content.opf"] else {
            XCTFail("Missing content.opf")
            return
        }
        var opfData = Data()
        _ = try archive.extract(entry) { opfData.append($0) }
        let opf = String(data: opfData, encoding: .utf8)!

        XCTAssertTrue(opf.contains("My Test Title"))
        XCTAssertTrue(opf.contains("My Channel"))
        XCTAssertTrue(opf.contains("Readtube"))
        XCTAssertTrue(opf.contains("dc:language"))
    }

    func testEPUBChapterContainsContent() throws {
        let data = try EPUBGenerator.generate(
            title: "Chapter Test",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: "# Heading\n\nThis is the article body with **bold** text."
        )

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-chapter.epub")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let archive = Archive(url: tmpURL, accessMode: .read) else {
            XCTFail("Could not open EPUB")
            return
        }

        guard let entry = archive["OEBPS/chapter_1.xhtml"] else {
            XCTFail("Missing chapter_1.xhtml")
            return
        }
        var chapterData = Data()
        _ = try archive.extract(entry) { chapterData.append($0) }
        let chapter = String(data: chapterData, encoding: .utf8)!

        XCTAssertTrue(chapter.contains("<h1>"))
        XCTAssertTrue(chapter.contains("Heading"))
        XCTAssertTrue(chapter.contains("<strong>bold</strong>"))
        XCTAssertTrue(chapter.contains("article body"))
    }

    func testEPUBNavContainsTitle() throws {
        let data = try EPUBGenerator.generate(
            title: "Nav Test Title",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: "Content"
        )

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-nav.epub")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let archive = Archive(url: tmpURL, accessMode: .read) else {
            XCTFail("Could not open EPUB")
            return
        }

        guard let entry = archive["OEBPS/nav.xhtml"] else {
            XCTFail("Missing nav.xhtml")
            return
        }
        var navData = Data()
        _ = try archive.extract(entry) { navData.append($0) }
        let nav = String(data: navData, encoding: .utf8)!

        XCTAssertTrue(nav.contains("Nav Test Title"))
        XCTAssertTrue(nav.contains("Table of Contents"))
        XCTAssertTrue(nav.contains("chapter_1.xhtml"))
    }

    func testEPUBContainsCSSFile() throws {
        let data = try EPUBGenerator.generate(
            title: "CSS Test",
            channel: "Channel",
            articleURL: "https://example.com",
            markdown: "Content"
        )

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-css.epub")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let archive = Archive(url: tmpURL, accessMode: .read) else {
            XCTFail("Could not open EPUB")
            return
        }

        guard let entry = archive["OEBPS/style/typography.css"] else {
            XCTFail("Missing typography.css")
            return
        }
        var cssData = Data()
        _ = try archive.extract(entry) { cssData.append($0) }
        let css = String(data: cssData, encoding: .utf8)!

        // Should contain some CSS content (at least the fallback)
        XCTAssertTrue(css.contains("body") || css.contains("font"))
    }

    func testEPUBTocNCXContainsTitle() throws {
        let data = try EPUBGenerator.generate(
            title: "TOC Title",
            channel: "Ch",
            articleURL: "https://example.com",
            markdown: "Content"
        )

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-toc.epub")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let archive = Archive(url: tmpURL, accessMode: .read) else {
            XCTFail("Could not open EPUB")
            return
        }

        guard let entry = archive["OEBPS/toc.ncx"] else {
            XCTFail("Missing toc.ncx")
            return
        }
        var ncxData = Data()
        _ = try archive.extract(entry) { ncxData.append($0) }
        let ncx = String(data: ncxData, encoding: .utf8)!

        XCTAssertTrue(ncx.contains("TOC Title"))
        XCTAssertTrue(ncx.contains("chapter_1.xhtml"))
    }

    func testEPUBContainerXMLValid() throws {
        let data = try EPUBGenerator.generate(
            title: "Container Test",
            channel: "Ch",
            articleURL: "https://example.com",
            markdown: "Content"
        )

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-container.epub")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let archive = Archive(url: tmpURL, accessMode: .read) else {
            XCTFail("Could not open EPUB")
            return
        }

        guard let entry = archive["META-INF/container.xml"] else {
            XCTFail("Missing container.xml")
            return
        }
        var containerData = Data()
        _ = try archive.extract(entry) { containerData.append($0) }
        let container = String(data: containerData, encoding: .utf8)!

        XCTAssertTrue(container.contains("OEBPS/content.opf"))
        XCTAssertTrue(container.contains("rootfile"))
    }

    // MARK: - XML escaping in EPUB

    func testEPUBEscapesXMLInMetadata() throws {
        let data = try EPUBGenerator.generate(
            title: "Title with <special> & \"chars\"",
            channel: "Channel's & Name",
            articleURL: "https://example.com/?a=1&b=2",
            markdown: "Content"
        )

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-escape.epub")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let archive = Archive(url: tmpURL, accessMode: .read) else {
            XCTFail("Could not open EPUB")
            return
        }

        guard let entry = archive["OEBPS/content.opf"] else {
            XCTFail("Missing content.opf")
            return
        }
        var opfData = Data()
        _ = try archive.extract(entry) { opfData.append($0) }
        let opf = String(data: opfData, encoding: .utf8)!

        // Verify XML-escaped content
        XCTAssertTrue(opf.contains("&lt;special&gt;"))
        XCTAssertTrue(opf.contains("&amp;"))
        XCTAssertTrue(opf.contains("&quot;chars&quot;"))
        XCTAssertTrue(opf.contains("&apos;"))
    }

    // MARK: - Multiple sequential EPUBs

    func testGenerateMultipleEPUBsSequentially() throws {
        for i in 1...5 {
            let data = try EPUBGenerator.generate(
                title: "Article \(i)",
                channel: "Channel \(i)",
                articleURL: "https://example.com/\(i)",
                markdown: "# Article \(i)\n\nContent for article \(i)."
            )
            XCTAssertTrue(data.count > 100)
            XCTAssertEqual(data[0], 0x50) // P
            XCTAssertEqual(data[1], 0x4B) // K
        }
    }

    // MARK: - EPUBError

    func testEPUBErrorDescriptions() {
        let archiveError = EPUBError.archiveFailed
        XCTAssertTrue(archiveError.localizedDescription.contains("archive"))

        let encodingError = EPUBError.encodingFailed
        XCTAssertTrue(encodingError.localizedDescription.contains("UTF-8"))
    }

    func testEPUBErrorArchiveFailedDescription() {
        let error = EPUBError.archiveFailed
        XCTAssertEqual(error.errorDescription, "Failed to create EPUB archive")
    }

    func testEPUBErrorEncodingFailedDescription() {
        let error = EPUBError.encodingFailed
        XCTAssertEqual(error.errorDescription, "Failed to encode content as UTF-8")
    }
}
