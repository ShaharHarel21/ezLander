import Foundation

class OpenAIService {
    static let shared = OpenAIService()

    private var apiKey: String = ""
    private(set) var isUsingOAuth: Bool = false
    // Pre-built URL — avoids force-unwrap URL(string:)! at every call site.
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    private init() {
        reloadAPIKey()
    }

    func reloadAPIKey() {
        // Prefer OAuth token over manual API key
        if let oauthToken = KeychainService.shared.get(key: "openai_oauth_access_token"), !oauthToken.isEmpty {
            apiKey = oauthToken
            isUsingOAuth = true
        } else if let key = KeychainService.shared.get(key: "openai_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            apiKey = key
            isUsingOAuth = false
        } else {
            apiKey = ""
            isUsingOAuth = false
        }
    }

    // NOTE: Callers that need a fresh key should call reloadAPIKey() explicitly first.
    // Embedding reloadAPIKey() here caused a side-effectful getter which is
    // not safe to call from concurrent contexts.
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }

    var hasOAuthToken: Bool {
        KeychainService.shared.get(key: "openai_oauth_access_token") != nil
    }

    var hasAPIKey: Bool {
        if let key = KeychainService.shared.get(key: "openai_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return !key.isEmpty
        }
        return false
    }

    // Available models
    enum Model: String, CaseIterable {
        case gpt4o = "gpt-4o"
        case gpt4oMini = "gpt-4o-mini"
        case o3Mini = "o3-mini"

        var displayName: String {
            switch self {
            case .gpt4o: return "GPT-4o"
            case .gpt4oMini: return "GPT-4o Mini"
            case .o3Mini: return "o3 Mini"
            }
        }
    }

    var currentModel: Model = .gpt4o

    func sendMessage(_ text: String, conversationHistory: [ChatMessage]) async throws -> ChatMessage {
        reloadAPIKey()

        // If using OAuth, refresh the token if needed before making the request
        if isUsingOAuth {
            let freshToken = try await OAuthService.shared.getValidOpenAIAccessToken()
            apiKey = freshToken
        }

        guard !apiKey.isEmpty else {
            throw OpenAIError.noAPIKey
        }

        // Fetch calendar context via shared service (which caches internally)
        let calendarContext = await CalendarContextService.shared.buildTodayContext()

        var messages: [[String: Any]] = [
            ["role": "system", "content": SystemPromptProvider.buildSystemPrompt(calendarContext: calendarContext)]
        ]

        // Keep only last 20 messages to avoid exceeding context window
        let recentHistory = Array(conversationHistory.suffix(20))
        for message in recentHistory {
            messages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        messages.append(["role": "user", "content": text])

        let requestBody: [String: Any] = [
            "model": currentModel.rawValue,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 4096
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, httpResponse) = try await APIRetryHelper.performRequest(request)

        guard httpResponse.statusCode == 200 else {
            let message = APIRetryHelper.userFriendlyMessage(statusCode: httpResponse.statusCode, data: data)
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        guard let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAIError.invalidResponse
        }

        guard let choices = responseJSON["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        return ChatMessage(role: .assistant, content: content)
    }
}

enum OpenAIError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .apiError(let code, let message):
            return "OpenAI error (\(code)): \(message)"
        }
    }
}

// MARK: - Streaming
extension OpenAIService {
    /// Stream a response, yielding text chunks as they arrive.
    func streamMessage(_ text: String, conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    self.reloadAPIKey()

                    // Use a local variable for the token to avoid mutating shared state
                    // from inside an unstructured Task (data race on self.apiKey).
                    var effectiveApiKey = self.apiKey
                    if self.isUsingOAuth {
                        let freshToken = try await OAuthService.shared.getValidOpenAIAccessToken()
                        effectiveApiKey = freshToken
                        self.apiKey = freshToken  // persist for subsequent non-streaming calls
                    }

                    guard !effectiveApiKey.isEmpty else {
                        continuation.finish(throwing: OpenAIError.noAPIKey)
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
                        "model": self.currentModel.rawValue,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 4096,
                        "stream": true
                    ]

                    var request = URLRequest(url: self.baseURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(effectiveApiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: OpenAIError.apiError(statusCode: statusCode, message: "Stream request failed"))
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
