import Foundation

/// Video metadata returned by yt-dlp --dump-json
struct VideoInfo: Sendable {
    let videoID: String
    let title: String
    let channel: String
    let description: String
    let thumbnailURL: String?
    let duration: Int
    let url: String
    let chapters: [ChapterInfo]
}

struct ChapterInfo: Sendable {
    let title: String
    let startTime: Double
    let endTime: Double
}

/// Wraps the bundled yt-dlp binary for fetching video metadata and subtitles.
/// The binary is included in the app bundle (Resources/yt-dlp).
actor YTDLPService {
    static let shared = YTDLPService()

    /// Minimum duration to filter out YouTube Shorts
    private let minDuration = 60

    private var ytdlpPath: String?

    private init() {}

    // MARK: - yt-dlp path resolution

    /// Find the yt-dlp binary, checking the app bundle first.
    func resolveYTDLPPath() throws -> String {
        if let cached = ytdlpPath { return cached }

        // 1. Bundled in app Resources
        if let bundled = Bundle.main.path(forResource: "yt-dlp", ofType: nil) {
            ytdlpPath = bundled
            return bundled
        }

        // 2. Common Homebrew / system paths
        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                ytdlpPath = path
                return path
            }
        }

        // 3. `which yt-dlp`
        if let path = try? runProcess("/usr/bin/which", arguments: ["yt-dlp"]).trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            ytdlpPath = path
            return path
        }

        throw YTDLPError.notFound
    }

    // MARK: - Public API

    /// Get metadata for a single video URL.
    func getVideoInfo(url: String) async throws -> VideoInfo {
        let binary = try resolveYTDLPPath()
        let output = try runProcess(binary, arguments: [
            "--dump-json",
            "--no-playlist",
            "--quiet",
            "--no-warnings",
            url,
        ])
        guard let data = output.data(using: .utf8) else {
            throw YTDLPError.parseError("Empty output")
        }
        return try parseVideoJSON(data)
    }

    /// Get video IDs from a playlist (flat extraction).
    func getPlaylistVideoURLs(url: String, max: Int = 50) async throws -> [String] {
        let binary = try resolveYTDLPPath()
        let output = try runProcess(binary, arguments: [
            "--flat-playlist",
            "--dump-json",
            "--quiet",
            "--no-warnings",
            "--playlist-end", String(max),
            url,
        ])
        // Each line is a JSON object
        var urls: [String] = []
        for line in output.split(separator: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let videoID = obj["id"] as? String else { continue }
            urls.append("https://www.youtube.com/watch?v=\(videoID)")
        }
        return urls
    }

    /// Get the latest long-form video from a channel.
    func getLatestFromChannel(handle: String) async throws -> VideoInfo? {
        let channelURL = handle.hasPrefix("http")
            ? handle
            : "https://www.youtube.com/\(handle)/videos"

        let binary = try resolveYTDLPPath()
        let output = try runProcess(binary, arguments: [
            "--dump-json",
            "--quiet",
            "--no-warnings",
            "--playlist-end", "15",
            channelURL,
        ])

        for line in output.split(separator: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8) else { continue }
            if let info = try? parseVideoJSON(data), info.duration >= minDuration {
                return info
            }
        }
        return nil
    }

    /// Download subtitles for a video and return the transcript text.
    func getSubtitles(videoID: String, lang: String = "en") async throws -> String {
        let binary = try resolveYTDLPPath()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("readtube-subs-\(videoID)")

        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let outputTemplate = tmpDir.appendingPathComponent("%(id)s").path

        _ = try runProcess(binary, arguments: [
            "--write-sub",
            "--write-auto-sub",
            "--sub-lang", lang,
            "--sub-format", "json3",
            "--skip-download",
            "--quiet",
            "--no-warnings",
            "-o", outputTemplate,
            "https://www.youtube.com/watch?v=\(videoID)",
        ])

        // Find the subtitle file
        let files = try FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil)
        guard let subFile = files.first(where: { $0.pathExtension == "json3" }) else {
            throw YTDLPError.noSubtitles(videoID)
        }

        let data = try Data(contentsOf: subFile)
        return try TranscriptParser.parseJSON3(data)
    }

    // MARK: - JSON parsing

    private func parseVideoJSON(_ data: Data) throws -> VideoInfo {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YTDLPError.parseError("Invalid JSON")
        }

        let videoID = obj["id"] as? String ?? ""
        let title = obj["title"] as? String ?? "Unknown Title"
        let channel = obj["channel"] as? String ?? obj["uploader"] as? String ?? "Unknown"
        let description = obj["description"] as? String ?? ""
        let duration = obj["duration"] as? Int ?? 0

        // Thumbnail: use `thumbnail` field, or last item in `thumbnails` array
        var thumbnailURL = obj["thumbnail"] as? String
        if thumbnailURL == nil, let thumbs = obj["thumbnails"] as? [[String: Any]], let last = thumbs.last {
            thumbnailURL = last["url"] as? String
        }

        // Chapters
        var chapters: [ChapterInfo] = []
        if let rawChapters = obj["chapters"] as? [[String: Any]] {
            for ch in rawChapters {
                chapters.append(ChapterInfo(
                    title: ch["title"] as? String ?? "",
                    startTime: ch["start_time"] as? Double ?? 0,
                    endTime: ch["end_time"] as? Double ?? 0
                ))
            }
        }

        return VideoInfo(
            videoID: videoID,
            title: title,
            channel: channel,
            description: description,
            thumbnailURL: thumbnailURL,
            duration: duration,
            url: "https://www.youtube.com/watch?v=\(videoID)",
            chapters: chapters
        )
    }

    // MARK: - Process execution

    @discardableResult
    private func runProcess(_ path: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        // Read output before waitUntilExit to avoid pipe buffer deadlock
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        let output = String(data: outputData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw YTDLPError.processError(process.terminationStatus, errorMsg)
        }

        return output
    }
}

// MARK: - Errors

enum YTDLPError: LocalizedError {
    case notFound
    case processError(Int32, String)
    case parseError(String)
    case noSubtitles(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "yt-dlp not found. It should be bundled in the app."
        case .processError(let code, let msg):
            return "yt-dlp failed (exit \(code)): \(msg.prefix(200))"
        case .parseError(let msg):
            return "Failed to parse yt-dlp output: \(msg)"
        case .noSubtitles(let id):
            return "No subtitles found for video \(id)"
        }
    }
}
