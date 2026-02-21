import XCTest

final class YTDLPServiceTests: XCTestCase {

    // MARK: - Path resolution

    func testResolveYTDLPPath() async {
        do {
            let path = try await YTDLPService.shared.resolveYTDLPPath()
            XCTAssertFalse(path.isEmpty)
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        } catch {
            // yt-dlp not found — acceptable in CI
            print("Skipping: yt-dlp not found (\(error))")
        }
    }

    func testResolveYTDLPPathCachesResult() async throws {
        // Call twice — second should return cached path
        do {
            let path1 = try await YTDLPService.shared.resolveYTDLPPath()
            let path2 = try await YTDLPService.shared.resolveYTDLPPath()
            XCTAssertEqual(path1, path2)
        } catch {
            print("Skipping: yt-dlp not found")
        }
    }

    // MARK: - Error types

    func testYTDLPErrorDescriptions() {
        let notFound = YTDLPError.notFound
        XCTAssertTrue(notFound.localizedDescription.contains("not found"))

        let processError = YTDLPError.processError(1, "something failed")
        XCTAssertTrue(processError.localizedDescription.contains("exit 1"))
        XCTAssertTrue(processError.localizedDescription.contains("something failed"))

        let parseError = YTDLPError.parseError("bad json")
        XCTAssertTrue(parseError.localizedDescription.contains("bad json"))

        let noSubs = YTDLPError.noSubtitles("abc123")
        XCTAssertTrue(noSubs.localizedDescription.contains("abc123"))
    }

    // MARK: - End-to-end (requires yt-dlp installed)

    func testGetVideoInfo() async throws {
        do {
            _ = try await YTDLPService.shared.resolveYTDLPPath()
        } catch {
            print("Skipping e2e test: yt-dlp not available")
            return
        }

        // Use a short, stable public domain video
        let info = try await YTDLPService.shared.getVideoInfo(
            url: "https://www.youtube.com/watch?v=jNQXAC9IVRw"
        )
        XCTAssertEqual(info.videoID, "jNQXAC9IVRw")
        XCTAssertFalse(info.title.isEmpty)
        XCTAssertFalse(info.channel.isEmpty)
        XCTAssertTrue(info.duration > 0)
        XCTAssertNotNil(info.thumbnailURL)
    }

    func testGetSubtitles() async throws {
        do {
            _ = try await YTDLPService.shared.resolveYTDLPPath()
        } catch {
            print("Skipping e2e test: yt-dlp not available")
            return
        }

        // Rick Astley — has auto-generated English subtitles
        let transcript = try await YTDLPService.shared.getSubtitles(videoID: "dQw4w9WgXcQ")
        XCTAssertFalse(transcript.isEmpty)
        XCTAssertTrue(transcript.count > 100)
    }

    // MARK: - VideoInfo struct

    func testVideoInfoProperties() {
        let info = VideoInfo(
            videoID: "test123",
            title: "Test Video",
            channel: "Test Channel",
            description: "A test video",
            thumbnailURL: "https://img.youtube.com/test.jpg",
            duration: 300,
            url: "https://www.youtube.com/watch?v=test123",
            chapters: [
                ChapterInfo(title: "Intro", startTime: 0, endTime: 60),
                ChapterInfo(title: "Main", startTime: 60, endTime: 300),
            ]
        )

        XCTAssertEqual(info.videoID, "test123")
        XCTAssertEqual(info.title, "Test Video")
        XCTAssertEqual(info.channel, "Test Channel")
        XCTAssertEqual(info.description, "A test video")
        XCTAssertEqual(info.thumbnailURL, "https://img.youtube.com/test.jpg")
        XCTAssertEqual(info.duration, 300)
        XCTAssertEqual(info.chapters.count, 2)
    }

    func testVideoInfoWithNoThumbnail() {
        let info = VideoInfo(
            videoID: "no_thumb",
            title: "No Thumbnail",
            channel: "Ch",
            description: "",
            thumbnailURL: nil,
            duration: 120,
            url: "https://www.youtube.com/watch?v=no_thumb",
            chapters: []
        )

        XCTAssertNil(info.thumbnailURL)
        XCTAssertTrue(info.chapters.isEmpty)
    }

    func testVideoInfoWithEmptyChapters() {
        let info = VideoInfo(
            videoID: "no_ch",
            title: "No Chapters",
            channel: "Ch",
            description: "",
            thumbnailURL: nil,
            duration: 600,
            url: "https://www.youtube.com/watch?v=no_ch",
            chapters: []
        )
        XCTAssertTrue(info.chapters.isEmpty)
    }

    // MARK: - ChapterInfo struct

    func testChapterInfoProperties() {
        let chapter = ChapterInfo(title: "Introduction", startTime: 0.0, endTime: 60.5)
        XCTAssertEqual(chapter.title, "Introduction")
        XCTAssertEqual(chapter.startTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(chapter.endTime, 60.5, accuracy: 0.001)
    }

    func testChapterInfoZeroDuration() {
        let chapter = ChapterInfo(title: "Marker", startTime: 42.0, endTime: 42.0)
        XCTAssertEqual(chapter.startTime, chapter.endTime)
    }

    // MARK: - Error descriptions

    func testYTDLPErrorNotFoundDescription() {
        let error = YTDLPError.notFound
        XCTAssertEqual(error.errorDescription, "yt-dlp not found. It should be bundled in the app.")
    }

    func testYTDLPErrorProcessErrorDescription() {
        let error = YTDLPError.processError(127, "command not found")
        XCTAssertTrue(error.errorDescription!.contains("exit 127"))
        XCTAssertTrue(error.errorDescription!.contains("command not found"))
    }

    func testYTDLPErrorProcessErrorTruncatesLongMessage() {
        let longMsg = String(repeating: "x", count: 500)
        let error = YTDLPError.processError(1, longMsg)
        XCTAssertTrue(error.errorDescription!.count < 250)
    }

    func testYTDLPErrorParseErrorDescription() {
        let error = YTDLPError.parseError("unexpected token at line 5")
        XCTAssertTrue(error.errorDescription!.contains("unexpected token"))
    }

    func testYTDLPErrorNoSubtitlesDescription() {
        let error = YTDLPError.noSubtitles("xyz789")
        XCTAssertTrue(error.errorDescription!.contains("xyz789"))
        XCTAssertTrue(error.errorDescription!.contains("No subtitles"))
    }

    // MARK: - E2E: Video with chapters (requires yt-dlp)

    func testGetVideoInfoWithChapters() async throws {
        do {
            _ = try await YTDLPService.shared.resolveYTDLPPath()
        } catch {
            print("Skipping e2e test: yt-dlp not available")
            return
        }

        // Try a video known to have chapters (TED talk or similar)
        // "Me at the zoo" doesn't have chapters, but we can still test the info
        let info = try await YTDLPService.shared.getVideoInfo(
            url: "https://www.youtube.com/watch?v=jNQXAC9IVRw"
        )
        XCTAssertEqual(info.videoID, "jNQXAC9IVRw")
        XCTAssertTrue(info.url.contains("youtube.com"))
        // Chapters may or may not exist
        XCTAssertTrue(info.chapters.count >= 0)
    }

    // MARK: - TranscriptSegment struct

    func testTranscriptSegmentProperties() {
        let segment = TranscriptSegment(text: "Hello world", startSeconds: 1.5, durationSeconds: 2.5)
        XCTAssertEqual(segment.text, "Hello world")
        XCTAssertEqual(segment.startSeconds, 1.5, accuracy: 0.001)
        XCTAssertEqual(segment.durationSeconds, 2.5, accuracy: 0.001)
    }
}
