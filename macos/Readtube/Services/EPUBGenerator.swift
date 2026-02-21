import Foundation
import ZIPFoundation

/// Pure Swift EPUB creator. An EPUB is a ZIP of XHTML, CSS, and XML metadata.
enum EPUBGenerator {
    /// Generate an EPUB file at the given URL from a single article.
    static func generate(
        title: String,
        channel: String,
        articleURL: String,
        markdown: String,
        thumbnailURL: String? = nil
    ) throws -> Data {
        let articleHTML = MarkdownToHTML.convert(markdown)
        let safeTitle = escapeXML(title)
        let safeChannel = escapeXML(channel)
        let safeURL = escapeXML(articleURL)
        let identifier = "readtube-\(UUID().uuidString)"
        let date = ISO8601DateFormatter().string(from: Date())

        // Load typography CSS from bundle (fallback to embedded default)
        let typographyCSS = Bundle.main.url(forResource: "Typography", withExtension: "css")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            ?? "body { font-family: Georgia, serif; max-width: 65ch; margin: 0 auto; padding: 2em; }"

        // Download cover image if available
        var coverImageData: Data?
        if let thumbStr = thumbnailURL, let thumbURL = URL(string: thumbStr) {
            coverImageData = try? Data(contentsOf: thumbURL)
        }

        // Create a temp directory with the EPUB structure, then ZIP it
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("readtube-epub-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        // Write all EPUB files to the temp directory
        try write(tmpDir, "mimetype", "application/epub+zip")

        try fm.createDirectory(at: tmpDir.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        try write(tmpDir, "META-INF/container.xml", """
            <?xml version="1.0" encoding="UTF-8"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
              </rootfiles>
            </container>
            """)

        try fm.createDirectory(at: tmpDir.appendingPathComponent("OEBPS/style"), withIntermediateDirectories: true)
        try write(tmpDir, "OEBPS/style/typography.css", typographyCSS)

        // Cover image
        var coverManifest = ""
        var coverMeta = ""
        if let imgData = coverImageData {
            try imgData.write(to: tmpDir.appendingPathComponent("OEBPS/cover.jpg"))
            coverManifest = "<item id=\"cover-image\" href=\"cover.jpg\" media-type=\"image/jpeg\" properties=\"cover-image\"/>"
            coverMeta = "<meta name=\"cover\" content=\"cover-image\"/>"
        }

        // Chapter XHTML
        try write(tmpDir, "OEBPS/chapter_1.xhtml", """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml" lang="en">
            <head>
              <meta charset="UTF-8"/>
              <title>\(safeTitle)</title>
              <link rel="stylesheet" type="text/css" href="style/typography.css"/>
            </head>
            <body>
              <div class="intro">
                <p>Based on <strong>\(safeTitle)</strong> from <strong>\(safeChannel)</strong></p>
              </div>
              \(articleHTML)
              <p class="watch-link">Original video: \(safeURL)</p>
            </body>
            </html>
            """)

        // nav.xhtml
        try write(tmpDir, "OEBPS/nav.xhtml", """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en">
            <head><meta charset="UTF-8"/><title>Table of Contents</title></head>
            <body>
              <nav epub:type="toc" id="toc">
                <h1>Table of Contents</h1>
                <ol><li><a href="chapter_1.xhtml">\(safeTitle)</a></li></ol>
              </nav>
            </body>
            </html>
            """)

        // toc.ncx
        try write(tmpDir, "OEBPS/toc.ncx", """
            <?xml version="1.0" encoding="UTF-8"?>
            <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
              <head><meta name="dtb:uid" content="\(identifier)"/></head>
              <docTitle><text>\(safeTitle)</text></docTitle>
              <navMap>
                <navPoint id="chapter1" playOrder="1">
                  <navLabel><text>\(safeTitle)</text></navLabel>
                  <content src="chapter_1.xhtml"/>
                </navPoint>
              </navMap>
            </ncx>
            """)

        // content.opf
        try write(tmpDir, "OEBPS/content.opf", """
            <?xml version="1.0" encoding="UTF-8"?>
            <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="3.0">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="bookid">\(identifier)</dc:identifier>
                <dc:title>\(safeTitle)</dc:title>
                <dc:creator>\(safeChannel)</dc:creator>
                <dc:language>en</dc:language>
                <dc:date>\(date)</dc:date>
                <dc:publisher>Readtube</dc:publisher>
                <meta property="dcterms:modified">\(date)</meta>
                \(coverMeta)
              </metadata>
              <manifest>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
                <item id="style" href="style/typography.css" media-type="text/css"/>
                <item id="chapter1" href="chapter_1.xhtml" media-type="application/xhtml+xml"/>
                \(coverManifest)
              </manifest>
              <spine toc="ncx">
                <itemref idref="chapter1"/>
              </spine>
            </package>
            """)

        // Create ZIP (EPUB) from the directory
        return try createEPUBZip(from: tmpDir)
    }

    /// Create an EPUB ZIP from a directory structure.
    private static func createEPUBZip(from directory: URL) throws -> Data {
        let outputURL = directory.deletingLastPathComponent()
            .appendingPathComponent("output.epub")
        let fm = FileManager.default

        // Remove if exists
        try? fm.removeItem(at: outputURL)

        let archive: Archive
        do {
            archive = try Archive(url: outputURL, accessMode: .create)
        } catch {
            throw EPUBError.archiveFailed
        }

        // Add mimetype first (uncompressed, as required by EPUB spec)
        try archive.addEntry(with: "mimetype", relativeTo: directory, compressionMethod: .none)

        // Add all other files
        let paths = [
            "META-INF/container.xml",
            "OEBPS/content.opf",
            "OEBPS/toc.ncx",
            "OEBPS/nav.xhtml",
            "OEBPS/chapter_1.xhtml",
            "OEBPS/style/typography.css",
        ]

        for path in paths {
            let fileURL = directory.appendingPathComponent(path)
            if fm.fileExists(atPath: fileURL.path) {
                try archive.addEntry(with: path, relativeTo: directory, compressionMethod: .deflate)
            }
        }

        // Add cover if it exists
        let coverURL = directory.appendingPathComponent("OEBPS/cover.jpg")
        if fm.fileExists(atPath: coverURL.path) {
            try archive.addEntry(with: "OEBPS/cover.jpg", relativeTo: directory, compressionMethod: .deflate)
        }

        return try Data(contentsOf: outputURL)
    }

    // MARK: - Helpers

    private static func write(_ base: URL, _ path: String, _ content: String) throws {
        let url = base.appendingPathComponent(path)
        guard let data = content.data(using: .utf8) else {
            throw EPUBError.encodingFailed
        }
        try data.write(to: url)
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

enum EPUBError: LocalizedError {
    case archiveFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .archiveFailed:
            return "Failed to create EPUB archive"
        case .encodingFailed:
            return "Failed to encode content as UTF-8"
        }
    }
}
