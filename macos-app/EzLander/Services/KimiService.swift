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

        for message in conversationHistory {
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

        NSLog("KimiService: Sending request to %@", baseURL)
        NSLog("KimiService: Authorization header set with Bearer token")

        print("KimiService: Request URL: \(baseURL)")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("Kimi API: Invalid response type")
            throw KimiError.invalidResponse
        }

        print("Kimi API Response Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            NSLog("KimiService: API Error %d: %@", httpResponse.statusCode, errorBody)

            // Parse error for better message
            var errorMessage = "Status \(httpResponse.statusCode)"
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let detail = errorData["detail"] as? String {
                    errorMessage = detail
                } else if let message = errorData["message"] as? String {
                    errorMessage = message
                } else if let title = errorData["title"] as? String {
                    errorMessage = title
                }
            }

            throw KimiError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let responseJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]

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
