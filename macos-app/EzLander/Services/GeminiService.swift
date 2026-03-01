import Foundation

class GeminiService {
    static let shared = GeminiService()

    private var apiKey: String = ""
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    private init() {
        reloadAPIKey()
    }

    func reloadAPIKey() {
        if let key = KeychainService.shared.get(key: "gemini_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            apiKey = key
        } else {
            apiKey = ""
        }
    }

    var isConfigured: Bool {
        reloadAPIKey()
        return !apiKey.isEmpty
    }

    // Available models
    enum Model: String, CaseIterable {
        case gemini2Flash = "gemini-2.0-flash"
        case gemini15Pro = "gemini-1.5-pro"
        case gemini15Flash = "gemini-1.5-flash"

        var displayName: String {
            switch self {
            case .gemini2Flash: return "Gemini 2.0 Flash"
            case .gemini15Pro: return "Gemini 1.5 Pro"
            case .gemini15Flash: return "Gemini 1.5 Flash"
            }
        }
    }

    var currentModel: Model = .gemini2Flash

    func sendMessage(_ text: String, conversationHistory: [ChatMessage]) async throws -> ChatMessage {
        reloadAPIKey()

        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        // Fetch calendar context via shared service (which caches internally)
        let calendarContext = await CalendarContextService.shared.buildTodayContext()
        let prompt = SystemPromptProvider.buildSystemPrompt(calendarContext: calendarContext)

        // Build contents array for Gemini format
        var contents: [[String: Any]] = []

        // Add system instruction
        contents.append([
            "role": "user",
            "parts": [["text": prompt]]
        ])
        contents.append([
            "role": "model",
            "parts": [["text": "Understood. I'm ezLander, ready to help!"]]
        ])

        // Add conversation history
        let recentHistory = Array(conversationHistory.suffix(20))
        for message in recentHistory {
            let role = message.role == .user ? "user" : "model"
            contents.append([
                "role": role,
                "parts": [["text": message.content]]
            ])
        }

        // Add current message
        contents.append([
            "role": "user",
            "parts": [["text": text]]
        ])

        let requestBody: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 4096
            ]
        ]

        let urlString = "\(baseURL)/\(currentModel.rawValue):generateContent"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, httpResponse) = try await APIRetryHelper.performRequest(request)

        guard httpResponse.statusCode == 200 else {
            let message = APIRetryHelper.userFriendlyMessage(statusCode: httpResponse.statusCode, data: data)
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        guard let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiError.invalidResponse
        }

        guard let candidates = responseJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        return ChatMessage(role: .assistant, content: text)
    }
}

enum GeminiError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Gemini API key not configured"
        case .invalidResponse:
            return "Invalid response from Gemini"
        case .apiError(let code, let message):
            return "Gemini error (\(code)): \(message)"
        }
    }
}

// MARK: - Streaming
extension GeminiService {
    /// Stream a response using Gemini's streamGenerateContent endpoint.
    func streamMessage(_ text: String, conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    self.reloadAPIKey()

                    guard !self.apiKey.isEmpty else {
                        continuation.finish(throwing: GeminiError.noAPIKey)
                        return
                    }

                    let calendarContext = await CalendarContextService.shared.buildTodayContext()
                    let prompt = SystemPromptProvider.buildSystemPrompt(calendarContext: calendarContext)

                    var contents: [[String: Any]] = []
                    contents.append(["role": "user", "parts": [["text": prompt]]])
                    contents.append(["role": "model", "parts": [["text": "Understood. I'm ezLander, ready to help!"]]])

                    let recentHistory = Array(conversationHistory.suffix(20))
                    for message in recentHistory {
                        let role = message.role == .user ? "user" : "model"
                        contents.append(["role": role, "parts": [["text": message.content]]])
                    }
                    contents.append(["role": "user", "parts": [["text": text]]])

                    let requestBody: [String: Any] = [
                        "contents": contents,
                        "generationConfig": [
                            "temperature": 0.7,
                            "maxOutputTokens": 4096
                        ]
                    ]

                    let urlString = "\(self.baseURL)/\(self.currentModel.rawValue):streamGenerateContent?alt=sse"
                    guard let url = URL(string: urlString) else {
                        continuation.finish(throwing: GeminiError.invalidResponse)
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(self.apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: GeminiError.apiError(statusCode: statusCode, message: "Stream request failed"))
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))

                        guard let data = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let candidates = json["candidates"] as? [[String: Any]],
                              let firstCandidate = candidates.first,
                              let content = firstCandidate["content"] as? [String: Any],
                              let parts = content["parts"] as? [[String: Any]],
                              let firstPart = parts.first,
                              let text = firstPart["text"] as? String else { continue }

                        continuation.yield(text)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
