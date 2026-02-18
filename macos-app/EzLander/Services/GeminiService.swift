import Foundation

class GeminiService {
    static let shared = GeminiService()

    private var apiKey: String = ""
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    // Cached calendar context
    private var cachedCalendarContext: String = ""

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

        // Refresh calendar context
        cachedCalendarContext = await CalendarContextService.shared.buildTodayContext()

        // Build contents array for Gemini format
        var contents: [[String: Any]] = []

        // Add system instruction
        contents.append([
            "role": "user",
            "parts": [["text": systemPrompt]]
        ])
        contents.append([
            "role": "model",
            "parts": [["text": "Understood. I'm ezLander, ready to help!"]]
        ])

        // Add conversation history
        for message in conversationHistory {
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

        let urlString = "\(baseURL)/\(currentModel.rawValue):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let responseJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]

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
