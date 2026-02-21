import Foundation

enum ArticleStatus: String, Codable, CaseIterable {
    case pending
    case fetching
    case transcribing
    case generating
    case done
    case error
}

enum SourceType: String, Codable, CaseIterable {
    case video
    case playlist
    case channel
}

enum LLMBackend: String, Codable, CaseIterable {
    case ollama
    case claude = "claude-api"
    case openai

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .claude: return "Claude API"
        case .openai: return "OpenAI"
        }
    }
}

enum ThemeName: String, Codable, CaseIterable {
    case `default`
    case dark
    case modern
    case minimal

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .dark: return "Dark"
        case .modern: return "Modern"
        case .minimal: return "Minimal"
        }
    }

    var cssFileName: String {
        "\(rawValue).css"
    }
}
