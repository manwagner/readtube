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
}
