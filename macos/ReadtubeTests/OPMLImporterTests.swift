import XCTest

final class OPMLImporterTests: XCTestCase {

    // MARK: - OPML parsing (no SwiftData needed — test the XML parser directly)

    func testParseBasicOPML() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Tech" title="Tech">
              <outline text="Channel One" title="Channel One"
                       htmlUrl="https://www.youtube.com/channel/UC123"
                       xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC123"/>
              <outline text="Channel Two" title="Channel Two"
                       htmlUrl="https://www.youtube.com/channel/UC456"
                       xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UC456"/>
            </outline>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()

        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries[0].url.contains("youtube.com/channel/UC123"))
        XCTAssertTrue(entries[1].url.contains("youtube.com/channel/UC456"))
    }

    func testParseFeedURLExtractsChannelID() {
        // Only xmlUrl, no htmlUrl — should extract channel_id
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Channel"
                     xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCxyz789"/>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].url, "https://www.youtube.com/channel/UCxyz789")
    }

    func testSkipsNonYouTubeEntries() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Blog" htmlUrl="https://blog.example.com"/>
            <outline text="YT Channel" htmlUrl="https://www.youtube.com/channel/UC123"/>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()

        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].url.contains("youtube.com"))
    }

    func testEmptyOPML() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0"><body></body></opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()
        XCTAssertTrue(entries.isEmpty)
    }

    func testOPMLWithTextAttributeOnly() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Channel Name" htmlUrl="https://www.youtube.com/channel/UC789"/>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "Channel Name")
    }

    func testOPMLWithNestedGroups() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Tech" title="Tech">
              <outline text="Programming" title="Programming">
                <outline text="Ch1" htmlUrl="https://www.youtube.com/channel/UC111"/>
              </outline>
              <outline text="Hardware" title="Hardware">
                <outline text="Ch2" htmlUrl="https://www.youtube.com/channel/UC222"/>
              </outline>
            </outline>
            <outline text="Science" title="Science">
              <outline text="Ch3" htmlUrl="https://www.youtube.com/channel/UC333"/>
            </outline>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()

        XCTAssertEqual(entries.count, 3)
    }

    func testOPMLWithMalformedXML() {
        let opml = "this is not XML at all"
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()
        XCTAssertTrue(entries.isEmpty)
    }

    func testOPMLWithXmlUrlButNoChannelId() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Channel"
                     xmlUrl="https://www.youtube.com/feeds/videos.xml?playlist_id=PLxyz"/>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()

        // Should fall back to using the xmlUrl directly
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].url, "https://www.youtube.com/feeds/videos.xml?playlist_id=PLxyz")
    }

    func testOPMLWithUnicodeNames() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="日本語チャンネル" title="日本語チャンネル"
                     htmlUrl="https://www.youtube.com/channel/UCjp"/>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "日本語チャンネル")
    }

    func testOPMLManyEntries() {
        var body = ""
        for i in 0..<50 {
            body += "<outline text=\"Channel \(i)\" htmlUrl=\"https://www.youtube.com/channel/UC\(i)\"/>\n"
        }
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            \(body)
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()

        XCTAssertEqual(entries.count, 50)
    }

    func testPrefersHTMLOverXMLUrl() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
          <body>
            <outline text="Channel"
                     htmlUrl="https://www.youtube.com/channel/UChtml"
                     xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCxml"/>
          </body>
        </opml>
        """
        let data = opml.data(using: .utf8)!
        let parser = TestOPMLParser(data: data)
        let entries = parser.parse()

        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].url.contains("UChtml"))
    }
}

/// Expose the private OPML parser for testing.
private class TestOPMLParser: NSObject, XMLParserDelegate {
    struct Entry {
        let title: String
        let url: String
    }

    private let data: Data
    private var entries: [Entry] = []

    init(data: Data) {
        self.data = data
    }

    func parse() -> [Entry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        guard elementName == "outline" else { return }

        let title = attributeDict["title"] ?? attributeDict["text"] ?? ""
        let htmlURL = attributeDict["htmlUrl"] ?? ""
        let xmlURL = attributeDict["xmlUrl"] ?? ""

        var url = ""
        if htmlURL.contains("youtube.com") {
            url = htmlURL
        } else if xmlURL.contains("youtube.com") {
            if let match = xmlURL.range(of: #"channel_id=([A-Za-z0-9_-]+)"#, options: .regularExpression) {
                let fullMatch = String(xmlURL[match])
                let channelID = fullMatch.replacingOccurrences(of: "channel_id=", with: "")
                url = "https://www.youtube.com/channel/\(channelID)"
            } else {
                url = xmlURL
            }
        }

        if !url.isEmpty {
            entries.append(Entry(title: title, url: url))
        }
    }
}
