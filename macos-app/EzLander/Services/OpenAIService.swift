import Foundation

class OpenAIService {
    static let shared = OpenAIService()

    private var apiKey: String = ""
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    // Cached calendar context
    private var cachedCalendarContext: String = ""

    private init() {
        reloadAPIKey()
    }

    func reloadAPIKey() {
        if let key = KeychainService.shared.get(key: "openai_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
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
        case gpt4o = "gpt-4o"
        case gpt4 = "gpt-4-turbo"
        case gpt35 = "gpt-3.5-turbo"

        var displayName: String {
            switch self {
            case .gpt4o: return "GPT-4o"
            case .gpt4: return "GPT-4 Turbo"
            case .gpt35: return "GPT-3.5 Turbo"
            }
        }
    }

    var currentModel: Model = .gpt4o

    func sendMessage(_ text: String, conversationHistory: [ChatMessage]) async throws -> ChatMessage {
        reloadAPIKey()

        guard !apiKey.isEmpty else {
            throw OpenAIError.noAPIKey
        }

        // Refresh calendar context
        cachedCalendarContext = await CalendarContextService.shared.buildTodayContext()

        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for message in conversationHistory {
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

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let responseJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        guard let choices = responseJSON["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        return ChatMessage(role: .assistant, content: content)
    }

    private var systemPrompt: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let currentTime = timeFormatter.string(from: Date())

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let weekdayName = DateFormatter().weekdaySymbols[weekday - 1]

        return """
        You are ezLander, a helpful AI assistant integrated into a macOS menu bar app. You help users manage their calendar and email.

        Today is \(weekdayName), \(today). Current time: \(currentTime).

        \(cachedCalendarContext)

        Be concise and helpful. Format responses in a readable way.
        When the user asks about their calendar, use the schedule information above to answer directly.
        """
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
