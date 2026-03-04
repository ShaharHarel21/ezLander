import Foundation
import Combine

/// Sends AI requests through the backend proxy instead of calling providers directly.
/// The proxy uses a server-side OpenAI API key and tracks token usage per user.
class ProxyAIService: ObservableObject {
    static let shared = ProxyAIService()

    private let baseURL = "https://ezlander.app/api/ai/chat"

    @Published var tokensUsed: Int = 0
    @Published var tokensLimit: Int = 0
    @Published var tokensRemaining: Int = 0
    @Published var tier: String = ""

    /// Selected model (user preference). Allowed: gpt-4o, gpt-4o-mini.
    @Published var selectedModel: String = "gpt-4o" {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "proxy_ai_model")
        }
    }

    private init() {
        selectedModel = UserDefaults.standard.string(forKey: "proxy_ai_model") ?? "gpt-4o"
    }

    // MARK: - JWT Token

    private var jwtToken: String? {
        KeychainService.shared.get(key: "proxy_jwt_token")
    }

    func saveJWT(_ token: String) {
        KeychainService.shared.save(key: "proxy_jwt_token", value: token)
    }

    func clearJWT() {
        KeychainService.shared.delete(key: "proxy_jwt_token")
    }

    var isAuthenticated: Bool {
        jwtToken != nil
    }

    // MARK: - Send Message (non-streaming)

    func sendMessage(_ text: String, conversationHistory: [ChatMessage]) async throws -> ChatMessage {
        guard let token = jwtToken else {
            throw ProxyAIError.notAuthenticated
        }

        let calendarContext = await CalendarContextService.shared.buildTodayContext()

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

        let requestBody: [String: Any] = [
            "model": selectedModel,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 4096,
            "stream": false
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxyAIError.invalidResponse
        }

        // Update usage from headers
        updateUsageFromHeaders(httpResponse)

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw ProxyAIError.notAuthenticated
        case 403:
            throw ProxyAIError.noSubscription
        case 429:
            throw ProxyAIError.quotaExceeded
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ProxyAIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        guard let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = responseJSON["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ProxyAIError.invalidResponse
        }

        return ChatMessage(role: .assistant, content: content)
    }

    // MARK: - Stream Message (SSE)

    func streamMessage(_ text: String, conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let token = self.jwtToken else {
                        continuation.finish(throwing: ProxyAIError.notAuthenticated)
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
                        "model": self.selectedModel,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 4096,
                        "stream": true
                    ]

                    var request = URLRequest(url: URL(string: self.baseURL)!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    request.timeoutInterval = 120

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ProxyAIError.invalidResponse)
                        return
                    }

                    self.updateUsageFromHeaders(httpResponse)

                    switch httpResponse.statusCode {
                    case 200:
                        break
                    case 401:
                        continuation.finish(throwing: ProxyAIError.notAuthenticated)
                        return
                    case 403:
                        continuation.finish(throwing: ProxyAIError.noSubscription)
                        return
                    case 429:
                        continuation.finish(throwing: ProxyAIError.quotaExceeded)
                        return
                    default:
                        continuation.finish(throwing: ProxyAIError.serverError(statusCode: httpResponse.statusCode, message: "Stream request failed"))
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

    // MARK: - Fetch Usage

    func fetchUsage() async {
        guard let token = jwtToken else { return }

        let usageURL = "https://ezlander.app/api/usage"
        var request = URLRequest(url: URL(string: usageURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                await MainActor.run {
                    self.tokensUsed = json["tokens_used"] as? Int ?? 0
                    self.tokensLimit = json["tokens_limit"] as? Int ?? 0
                    self.tokensRemaining = json["tokens_remaining"] as? Int ?? 0
                    self.tier = json["tier"] as? String ?? ""
                }
            }
        } catch {
            print("Failed to fetch usage: \(error)")
        }
    }

    // MARK: - Private

    private func updateUsageFromHeaders(_ response: HTTPURLResponse) {
        DispatchQueue.main.async {
            if let used = response.value(forHTTPHeaderField: "X-Tokens-Used"),
               let usedInt = Int(used) {
                self.tokensUsed = usedInt
            }
            if let limit = response.value(forHTTPHeaderField: "X-Tokens-Limit"),
               let limitInt = Int(limit) {
                self.tokensLimit = limitInt
            }
            if let remaining = response.value(forHTTPHeaderField: "X-Tokens-Remaining"),
               let remainingInt = Int(remaining) {
                self.tokensRemaining = remainingInt
            }
            if let tier = response.value(forHTTPHeaderField: "X-Tier") {
                self.tier = tier
            }
        }
    }
}

// MARK: - Errors

enum ProxyAIError: Error, LocalizedError {
    case notAuthenticated
    case noSubscription
    case quotaExceeded
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to use the AI assistant."
        case .noSubscription:
            return "An active subscription is required. Please subscribe to continue."
        case .quotaExceeded:
            return "You've reached your monthly token limit. Upgrade your plan for more tokens."
        case .invalidResponse:
            return "Received an unexpected response from the server."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}
