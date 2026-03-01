import Foundation

class KimiService {
    static let shared = KimiService()

    private var apiKey: String
    // NVIDIA's hosted Kimi K2.5 endpoint
    private let baseURL = "https://integrate.api.nvidia.com/v1/chat/completions"
    private let model = "moonshotai/kimi-k2.5"

    private init() {
        // Load API key from Keychain or environment
        if let keychainKey = KeychainService.shared.get(key: "kimi_api_key"), !keychainKey.isEmpty {
            apiKey = keychainKey
        } else if let envKey = ProcessInfo.processInfo.environment["KIMI_API_KEY"], !envKey.isEmpty {
            apiKey = envKey
        } else {
            apiKey = ""
        }
    }

    // Reload API key (called after saving new key)
    func reloadAPIKey() {
        if let keychainKey = KeychainService.shared.get(key: "kimi_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), !keychainKey.isEmpty {
            apiKey = keychainKey
            print("KimiService: Authentication configured")
        } else {
            apiKey = ""
            print("KimiService: No API key found in Keychain")
        }
    }

    // MARK: - Send Message
    func sendMessage(_ text: String, conversationHistory: [ChatMessage]) async throws -> ChatMessage {
        // Reload key in case it was just added
        reloadAPIKey()

        guard !apiKey.isEmpty else {
            throw KimiError.noAPIKey
        }

        // Fetch calendar context via shared service (which caches internally)
        let calendarContext = await CalendarContextService.shared.buildTodayContext()

        // Build messages array
        var messages: [[String: Any]] = [
            ["role": "system", "content": SystemPromptProvider.buildSystemPrompt(calendarContext: calendarContext)]
        ]

        let recentHistory = Array(conversationHistory.suffix(20))
        for message in recentHistory {
            messages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        messages.append(["role": "user", "content": text])

        // Build request for NVIDIA API (OpenAI-compatible)
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.6,
            "max_tokens": 4096,
            "stream": false,
            "chat_template_kwargs": ["thinking": false]  // Use instant mode
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, httpResponse) = try await APIRetryHelper.performRequest(request)

        guard httpResponse.statusCode == 200 else {
            let message = APIRetryHelper.userFriendlyMessage(statusCode: httpResponse.statusCode, data: data)
            throw KimiError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        guard let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KimiError.invalidResponse
        }

        // Parse response (OpenAI-compatible format)
        guard let choices = responseJSON["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw KimiError.invalidResponse
        }

        return ChatMessage(role: .assistant, content: content)
    }

    // MARK: - Check if configured
    var isConfigured: Bool {
        reloadAPIKey()
        return !apiKey.isEmpty
    }
}

// MARK: - Errors
enum KimiError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Kimi API key not configured"
        case .invalidResponse:
            return "Invalid response from Kimi API"
        case .apiError(let code, let message):
            return "Kimi API error (\(code)): \(message)"
        }
    }
}

// MARK: - Streaming
extension KimiService {
    /// Stream a response using NVIDIA's OpenAI-compatible SSE endpoint.
    func streamMessage(_ text: String, conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    self.reloadAPIKey()

                    guard !self.apiKey.isEmpty else {
                        continuation.finish(throwing: KimiError.noAPIKey)
                        return
                    }

                    let calendarContext = await CalendarContextService.shared.buildTodayContext()

                    var messages: [[String: Any]] = [
                        ["role": "system", "content": SystemPromptProvider.buildSystemPrompt(calendarContext: calendarContext)]
                    ]
                    let recentHistory = Array(conversationHistory.suffix(20))
                    for message in recentHistory {
                        messages.append(["role": message.role.rawValue, "content": message.content])
                    }
                    messages.append(["role": "user", "content": text])

                    let requestBody: [String: Any] = [
                        "model": self.model,
                        "messages": messages,
                        "temperature": 0.6,
                        "max_tokens": 4096,
                        "stream": true,
                        "chat_template_kwargs": ["thinking": false]
                    ]

                    var request = URLRequest(url: URL(string: self.baseURL)!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: KimiError.apiError(statusCode: statusCode, message: "Stream request failed"))
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        if jsonStr == "[DONE]" { break }

                        guard let data = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
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
