import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings: AppSettings?

    var body: some View {
        Group {
            if let settings = settings {
                settingsForm(settings)
            } else {
                ProgressView()
                    .onAppear { loadSettings() }
            }
        }
        .frame(width: 500, height: 520)
    }

    @ViewBuilder
    private func settingsForm(_ settings: AppSettings) -> some View {
        Form {
            // LLM Backend
            Section("LLM Backend") {
                Picker("Backend", selection: Binding(
                    get: { settings.llmBackend },
                    set: { settings.llmBackend = $0; save() }
                )) {
                    ForEach(LLMBackend.allCases, id: \.self) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }

                switch settings.llmBackend {
                case .ollama:
                    TextField("Ollama Base URL", text: Binding(
                        get: { settings.ollamaBaseURL },
                        set: { settings.ollamaBaseURL = $0; save() }
                    ))
                    TextField("Model", text: Binding(
                        get: { settings.ollamaModel },
                        set: { settings.ollamaModel = $0; save() }
                    ))

                case .claude:
                    SecureField("Anthropic API Key", text: Binding(
                        get: { settings.anthropicAPIKey },
                        set: { settings.anthropicAPIKey = $0; save() }
                    ))
                    TextField("Model", text: Binding(
                        get: { settings.anthropicModel },
                        set: { settings.anthropicModel = $0; save() }
                    ))

                case .openai:
                    SecureField("OpenAI API Key", text: Binding(
                        get: { settings.openaiAPIKey },
                        set: { settings.openaiAPIKey = $0; save() }
                    ))
                    TextField("Base URL", text: Binding(
                        get: { settings.openaiBaseURL },
                        set: { settings.openaiBaseURL = $0; save() }
                    ))
                    TextField("Model", text: Binding(
                        get: { settings.openaiModel },
                        set: { settings.openaiModel = $0; save() }
                    ))
                }
            }

            // Theme
            Section("Appearance") {
                Picker("Reader Theme", selection: Binding(
                    get: { settings.theme },
                    set: { settings.theme = $0; save() }
                )) {
                    ForEach(ThemeName.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
            }

            // Auto-fetch
            Section("Auto-Fetch") {
                Picker("Interval", selection: Binding(
                    get: { settings.autoFetchIntervalMinutes },
                    set: { settings.autoFetchIntervalMinutes = $0; save() }
                )) {
                    Text("Disabled").tag(0)
                    Text("Every 15 minutes").tag(15)
                    Text("Every 30 minutes").tag(30)
                    Text("Every hour").tag(60)
                    Text("Every 6 hours").tag(360)
                    Text("Every 24 hours").tag(1440)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func loadSettings() {
        settings = AppSettings.getOrCreate(context: modelContext)
    }

    private func save() {
        try? modelContext.save()
    }
}
