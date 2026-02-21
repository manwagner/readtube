import SwiftUI
import SwiftData

@main
struct ReadtubeApp: App {
    @StateObject private var pipeline = ArticlePipeline()

    let modelContainer: ModelContainer = {
        let schema = Schema([Article.self, Source.self, AppSettings.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pipeline)
                .frame(minWidth: 800, minHeight: 500)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1100, height: 700)

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}
