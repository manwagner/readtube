import Foundation
import SwiftData

@Model
final class Source {
    @Attribute(.unique) var url: String
    var sourceTypeRaw: String
    var name: String
    var autoFetch: Bool
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \Article.source) var articles: [Article]

    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .video }
        set { sourceTypeRaw = newValue.rawValue }
    }

    init(
        url: String,
        sourceType: SourceType = .video,
        name: String = "",
        autoFetch: Bool = false
    ) {
        self.url = url
        self.sourceTypeRaw = sourceType.rawValue
        self.name = name
        self.autoFetch = autoFetch
        self.createdAt = Date()
        self.articles = []
    }
}
