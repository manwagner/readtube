import Foundation
import SwiftData

/// Import YouTube channel sources from OPML files.
enum OPMLImporter {
    /// Parse OPML XML data and insert YouTube sources into the model context.
    /// Returns the number of sources imported.
    @discardableResult
    static func importSources(from data: Data, into context: ModelContext) -> Int {
        let parser = OPMLParser(data: data)
        let entries = parser.parse()

        var count = 0
        for entry in entries {
            guard !entry.url.isEmpty else { continue }

            // Check for duplicates
            let url = entry.url
            let descriptor = FetchDescriptor<Source>(
                predicate: #Predicate<Source> { $0.url == url }
            )
            if let existing = try? context.fetch(descriptor), !existing.isEmpty {
                continue
            }

            let source = Source(
                url: entry.url,
                sourceType: .channel,
                name: entry.title
            )
            context.insert(source)
            count += 1
        }

        do {
            try context.save()
        } catch {
            print("Failed to save imported sources: \(error)")
        }
        return count
    }
}

// MARK: - OPML XML Parser

private struct OPMLEntry {
    let title: String
    let url: String
}

private class OPMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var entries: [OPMLEntry] = []

    init(data: Data) {
        self.data = data
    }

    func parse() -> [OPMLEntry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        guard elementName == "outline" else { return }

        let title = attributeDict["title"] ?? attributeDict["text"] ?? ""
        let htmlURL = attributeDict["htmlUrl"] ?? ""
        let xmlURL = attributeDict["xmlUrl"] ?? ""

        var url = ""

        // Prefer htmlUrl if it's a YouTube URL
        if htmlURL.contains("youtube.com") {
            url = htmlURL
        } else if xmlURL.contains("youtube.com") {
            // Convert feed URL to channel URL
            // e.g. https://www.youtube.com/feeds/videos.xml?channel_id=UC...
            if let match = xmlURL.range(of: #"channel_id=([A-Za-z0-9_-]+)"#, options: .regularExpression) {
                // Extract just the channel_id value
                let fullMatch = String(xmlURL[match])
                let channelID = fullMatch.replacingOccurrences(of: "channel_id=", with: "")
                url = "https://www.youtube.com/channel/\(channelID)"
            } else {
                url = xmlURL
            }
        }

        if !url.isEmpty {
            entries.append(OPMLEntry(title: title, url: url))
        }
    }
}
