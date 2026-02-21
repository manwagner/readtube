import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: String
    var llmBackendRaw: String
    var ollamaModel: String
    var ollamaBaseURL: String
    var anthropicAPIKey: String
    var anthropicModel: String
    var openaiAPIKey: String
    var openaiModel: String
    var openaiBaseURL: String
    var themeRaw: String
    var autoFetchIntervalMinutes: Int

    var llmBackend: LLMBackend {
        get { LLMBackend(rawValue: llmBackendRaw) ?? .ollama }
        set { llmBackendRaw = newValue.rawValue }
    }

    var theme: ThemeName {
        get { ThemeName(rawValue: themeRaw) ?? .default }
        set { themeRaw = newValue.rawValue }
    }

    init() {
        self.id = "singleton"
        self.llmBackendRaw = LLMBackend.ollama.rawValue
        self.ollamaModel = "llama3.2"
        self.ollamaBaseURL = "http://localhost:11434"
        self.anthropicAPIKey = ""
        self.anthropicModel = "claude-sonnet-4-20250514"
        self.openaiAPIKey = ""
        self.openaiModel = "gpt-4o"
        self.openaiBaseURL = "https://api.openai.com/v1"
        self.themeRaw = ThemeName.default.rawValue
        self.autoFetchIntervalMinutes = 0
    }

    static func getOrCreate(context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>(
            predicate: #Predicate { $0.id == "singleton" }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        do {
            try context.save()
        } catch {
            print("Failed to save initial settings: \(error)")
        }
        return settings
    }
}
