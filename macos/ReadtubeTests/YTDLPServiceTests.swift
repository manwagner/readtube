import XCTest
@testable import Readtube

final class YTDLPServiceTests: XCTestCase {
    /// Test that yt-dlp path can be resolved (requires yt-dlp to be installed or bundled).
    func testResolveYTDLPPath() async {
        do {
            let path = try await YTDLPService.shared.resolveYTDLPPath()
            XCTAssertFalse(path.isEmpty)
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        } catch {
            // yt-dlp not found — skip test in CI
            print("Skipping: yt-dlp not found (\(error))")
        }
    }
}
