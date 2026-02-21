import Foundation

/// Protocol for LLM backends.
protocol LLMService: Sendable {
    /// Generate a complete response.
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int, temperature: Double) async throws -> String

    /// Generate a streaming response.
    func generateStream(prompt: String, systemPrompt: String?, maxTokens: Int, temperature: Double) -> AsyncThrowingStream<String, Error>
}

// MARK: - Ollama

struct OllamaService: LLMService {
    let baseURL: String
    let model: String

    init(baseURL: String = "http://localhost:11434", model: String = "llama3.2") {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.model = model
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int, temperature: Double) async throws -> String {
        var body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": temperature,
                "num_predict": maxTokens,
            ] as [String: Any],
        ]
        if let sys = systemPrompt { body["system"] = sys }

        let data = try await postJSON(url: "\(baseURL)/api/generate", body: body, timeout: 300)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = obj["response"] as? String else {
            throw LLMError.emptyResponse
        }
        return response
    }

    func generateStream(prompt: String, systemPrompt: String?, maxTokens: Int, temperature: Double) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var body: [String: Any] = [
                        "model": model,
                        "prompt": prompt,
                        "stream": true,
                        "options": [
                            "temperature": temperature,
                            "num_predict": maxTokens,
                        ] as [String: Any],
                    ]
                    if let sys = systemPrompt { body["system"] = sys }

                    let (bytes, _) = try await streamRequest(url: "\(baseURL)/api/generate", body: body)
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let token = obj["response"] as? String else { continue }
                        continuation.yield(token)
                        if obj["done"] as? Bool == true { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Claude API

struct ClaudeService: LLMService {
    let apiKey: String
    let model: String

    init(apiKey: String, model: String = "claude-sonnet-4-20250514") {
        self.apiKey = apiKey
        self.model = model
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int, temperature: Double) async throws -> String {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ],
        ]
        if let sys = systemPrompt { body["system"] = sys }

        guard let apiURL = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw LLMError.invalidURL("https://api.anthropic.com/v1/messages")
        }
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(response, data: data)

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw LLMError.emptyResponse
        }
        return text
    }

    func generateStream(prompt: String, systemPrompt: String?, maxTokens: Int, temperature: Double) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var body: [String: Any] = [
                        "model": model,
                        "max_tokens": maxTokens,
                        "stream": true,
                        "messages": [
                            ["role": "user", "content": prompt]
                        ],
                    ]
                    if let sys = systemPrompt { body["system"] = sys }

                    guard let apiURL = URL(string: "https://api.anthropic.com/v1/messages") else {
                        throw LLMError.invalidURL("https://api.anthropic.com/v1/messages")
                    }
                    var request = URLRequest(url: apiURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try checkHTTPResponse(response)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        if obj["type"] as? String == "content_block_delta",
                           let delta = obj["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            continuation.yield(text)
                        }
                        if obj["type"] as? String == "message_stop" { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - OpenAI

struct OpenAIService: LLMService {
    let apiKey: String
    let baseURL: String
    let model: String

    init(apiKey: String, baseURL: String = "https://api.openai.com/v1", model: String = "gpt-4o") {
        self.apiKey = apiKey
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.model = model
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int, temperature: Double) async throws -> String {
        var messages: [[String: String]] = []
        if let sys = systemPrompt { messages.append(["role": "system", "content": sys]) }
        messages.append(["role": "user", "content": prompt])

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature,
        ]

        let urlStr = "\(baseURL)/chat/completions"
        guard let apiURL = URL(string: urlStr) else { throw LLMError.invalidURL(urlStr) }
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPResponse(response, data: data)

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.emptyResponse
        }
        return content
    }

    func generateStream(prompt: String, systemPrompt: String?, maxTokens: Int, temperature: Double) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var messages: [[String: String]] = []
                    if let sys = systemPrompt { messages.append(["role": "system", "content": sys]) }
                    messages.append(["role": "user", "content": prompt])

                    let body: [String: Any] = [
                        "model": model,
                        "messages": messages,
                        "max_tokens": maxTokens,
                        "temperature": temperature,
                        "stream": true,
                    ]

                    let urlStr = "\(baseURL)/chat/completions"
                    guard let apiURL = URL(string: urlStr) else { throw LLMError.invalidURL(urlStr) }
                    var request = URLRequest(url: apiURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try checkHTTPResponse(response)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        if json == "[DONE]" { break }
                        guard let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Helpers

enum LLMError: LocalizedError {
    case emptyResponse
    case httpError(Int, String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "LLM returned empty response"
        case .httpError(let code, let msg):
            return "HTTP \(code): \(msg.prefix(200))"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        }
    }
}

private func postJSON(url: String, body: [String: Any], timeout: TimeInterval = 300) async throws -> Data {
    guard let parsedURL = URL(string: url) else { throw LLMError.invalidURL(url) }
    var request = URLRequest(url: parsedURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    request.timeoutInterval = timeout

    let (data, response) = try await URLSession.shared.data(for: request)
    try checkHTTPResponse(response, data: data)
    return data
}

private func streamRequest(url: String, body: [String: Any]) async throws -> (URLSession.AsyncBytes, URLResponse) {
    guard let parsedURL = URL(string: url) else { throw LLMError.invalidURL(url) }
    var request = URLRequest(url: parsedURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    return try await URLSession.shared.bytes(for: request)
}

private func checkHTTPResponse(_ response: URLResponse, data: Data? = nil) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard (200..<300).contains(http.statusCode) else {
        let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        throw LLMError.httpError(http.statusCode, body)
    }
}
