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
        }
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}
