import Foundation
import SwiftData

@Model
final class Article {
    @Attribute(.unique) var videoID: String
    var title: String
    var channel: String
    var videoDescription: String
    var thumbnailURL: String?
    var duration: Int
    var url: String
    var transcript: String?
    var articleMarkdown: String?
    var articleHTML: String?
    var statusRaw: String
    var errorMessage: String?
    var source: Source?
    var createdAt: Date
    var updatedAt: Date

    var status: ArticleStatus {
        get { ArticleStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        videoID: String,
        title: String = "",
        channel: String = "",
        videoDescription: String = "",
        thumbnailURL: String? = nil,
        duration: Int = 0,
        url: String = "",
        status: ArticleStatus = .pending,
        source: Source? = nil
    ) {
        self.videoID = videoID
        self.title = title
        self.channel = channel
        self.videoDescription = videoDescription
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.url = url
        self.statusRaw = status.rawValue
        self.source = source
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
