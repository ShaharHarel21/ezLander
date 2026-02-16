import Foundation

class ClaudeService {
    static let shared = ClaudeService()

    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

    private init() {
        // Load API key from Keychain or environment
        apiKey = KeychainService.shared.get(key: "anthropic_api_key") ?? ""
    }

    // MARK: - Tools Definition
    private let tools: [[String: Any]] = [
        [
            "name": "create_calendar_event",
            "description": "Create a new calendar event",
            "input_schema": [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "Event title"],
                    "date": ["type": "string", "description": "Event date in YYYY-MM-DD format"],
                    "time": ["type": "string", "description": "Event start time in HH:MM format (24-hour)"],
                    "duration": ["type": "integer", "description": "Duration in minutes"],
                    "calendar_type": ["type": "string", "enum": ["google", "apple"], "description": "Which calendar to use"]
                ],
                "required": ["title", "date", "time"]
            ]
        ],
        [
            "name": "list_calendar_events",
            "description": "List calendar events for a date range",
            "input_schema": [
                "type": "object",
                "properties": [
                    "start_date": ["type": "string", "description": "Start date in YYYY-MM-DD format"],
                    "end_date": ["type": "string", "description": "End date in YYYY-MM-DD format"],
                    "calendar_type": ["type": "string", "enum": ["google", "apple", "both"], "description": "Which calendar to query"]
                ],
                "required": ["start_date", "end_date"]
            ]
        ],
        [
            "name": "send_email",
            "description": "Send an email via Gmail",
            "input_schema": [
                "type": "object",
                "properties": [
                    "to": ["type": "string", "description": "Recipient email address"],
                    "subject": ["type": "string", "description": "Email subject"],
                    "body": ["type": "string", "description": "Email body (plain text)"]
                ],
                "required": ["to", "subject", "body"]
            ]
        ],
        [
            "name": "draft_email",
            "description": "Create an email draft for user review before sending",
            "input_schema": [
                "type": "object",
                "properties": [
                    "to": ["type": "string", "description": "Recipient email address"],
                    "subject": ["type": "string", "description": "Email subject"],
                    "body": ["type": "string", "description": "Email body (plain text)"]
                ],
                "required": ["to", "subject", "body"]
            ]
        ],
        [
            "name": "search_emails",
            "description": "Search emails in Gmail",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "Search query (Gmail search syntax)"]
                ],
                "required": ["query"]
            ]
        ]
    ]

    // MARK: - Send Message
    func sendMessage(_ text: String, conversationHistory: [ChatMessage]) async throws -> ChatMessage {
        // Build messages array
        var messages: [[String: Any]] = conversationHistory.map { message in
            ["role": message.role.rawValue, "content": message.content]
        }
        messages.append(["role": "user", "content": text])

        // Build request
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "tools": tools,
            "messages": messages
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let responseJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Parse response
        return try await parseResponse(responseJSON, originalMessages: messages)
    }

    // MARK: - Parse Response
    private func parseResponse(_ json: [String: Any], originalMessages: [[String: Any]]) async throws -> ChatMessage {
        guard let content = json["content"] as? [[String: Any]] else {
            throw ClaudeError.invalidResponse
        }

        var responseText = ""
        var toolCall: ToolCall?

        for block in content {
            if let type = block["type"] as? String {
                if type == "text", let text = block["text"] as? String {
                    responseText = text
                } else if type == "tool_use" {
                    let toolName = block["name"] as! String
                    let toolInput = block["input"] as! [String: Any]
                    let toolId = block["id"] as! String

                    // Execute the tool
                    let result = try await executeToolCall(name: toolName, input: toolInput)

                    // Create tool call for display
                    toolCall = ToolCall(
                        name: toolName,
                        parameters: toolInput.mapValues { "\($0)" }
                    )

                    // Continue conversation with tool result
                    var updatedMessages = originalMessages
                    updatedMessages.append([
                        "role": "assistant",
                        "content": content
                    ])
                    updatedMessages.append([
                        "role": "user",
                        "content": [
                            [
                                "type": "tool_result",
                                "tool_use_id": toolId,
                                "content": result
                            ]
                        ]
                    ])

                    // Get final response after tool use
                    let finalRequestBody: [String: Any] = [
                        "model": model,
                        "max_tokens": 4096,
                        "system": systemPrompt,
                        "tools": tools,
                        "messages": updatedMessages
                    ]

                    var request = URLRequest(url: URL(string: baseURL)!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.httpBody = try JSONSerialization.data(withJSONObject: finalRequestBody)

                    let (finalData, _) = try await URLSession.shared.data(for: request)
                    let finalJSON = try JSONSerialization.jsonObject(with: finalData) as! [String: Any]

                    if let finalContent = finalJSON["content"] as? [[String: Any]],
                       let textBlock = finalContent.first(where: { $0["type"] as? String == "text" }),
                       let text = textBlock["text"] as? String {
                        responseText = text
                    }
                }
            }
        }

        return ChatMessage(role: .assistant, content: responseText, toolCall: toolCall)
    }

    // MARK: - Execute Tool Call
    private func executeToolCall(name: String, input: [String: Any]) async throws -> String {
        switch name {
        case "create_calendar_event":
            return try await handleCreateCalendarEvent(input)
        case "list_calendar_events":
            return try await handleListCalendarEvents(input)
        case "send_email":
            return try await handleSendEmail(input)
        case "draft_email":
            return handleDraftEmail(input)
        case "search_emails":
            return try await handleSearchEmails(input)
        default:
            return "Unknown tool: \(name)"
        }
    }

    // MARK: - Tool Handlers
    private func handleCreateCalendarEvent(_ input: [String: Any]) async throws -> String {
        let title = input["title"] as! String
        let dateStr = input["date"] as! String
        let timeStr = input["time"] as! String
        let duration = input["duration"] as? Int ?? 60
        let calendarType = input["calendar_type"] as? String ?? "google"

        let event = CalendarEvent(
            id: UUID().uuidString,
            title: title,
            startDate: parseDateTime(date: dateStr, time: timeStr),
            endDate: parseDateTime(date: dateStr, time: timeStr).addingTimeInterval(TimeInterval(duration * 60)),
            calendarType: calendarType == "google" ? .google : .apple
        )

        if calendarType == "google" {
            try await GoogleCalendarService.shared.createEvent(event)
        } else {
            try await AppleCalendarService.shared.createEvent(event)
        }

        return "Successfully created event '\(title)' on \(dateStr) at \(timeStr)"
    }

    private func handleListCalendarEvents(_ input: [String: Any]) async throws -> String {
        let startDate = input["start_date"] as! String
        let endDate = input["end_date"] as! String
        let calendarType = input["calendar_type"] as? String ?? "both"

        var events: [CalendarEvent] = []

        if calendarType == "google" || calendarType == "both" {
            let googleEvents = try await GoogleCalendarService.shared.listEvents(
                from: parseDate(startDate),
                to: parseDate(endDate)
            )
            events.append(contentsOf: googleEvents)
        }

        if calendarType == "apple" || calendarType == "both" {
            let appleEvents = try await AppleCalendarService.shared.listEvents(
                from: parseDate(startDate),
                to: parseDate(endDate)
            )
            events.append(contentsOf: appleEvents)
        }

        if events.isEmpty {
            return "No events found between \(startDate) and \(endDate)"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let eventList = events.map { event in
            "- \(event.title) on \(formatter.string(from: event.startDate))"
        }.joined(separator: "\n")

        return "Found \(events.count) event(s):\n\(eventList)"
    }

    private func handleSendEmail(_ input: [String: Any]) async throws -> String {
        let to = input["to"] as! String
        let subject = input["subject"] as! String
        let body = input["body"] as! String

        let email = Email(
            id: UUID().uuidString,
            to: to,
            subject: subject,
            body: body,
            date: Date()
        )

        try await GmailService.shared.sendEmail(email)

        return "Successfully sent email to \(to) with subject '\(subject)'"
    }

    private func handleDraftEmail(_ input: [String: Any]) -> String {
        let to = input["to"] as! String
        let subject = input["subject"] as! String
        let body = input["body"] as! String

        return """
        Draft email created:
        To: \(to)
        Subject: \(subject)

        \(body)

        Would you like me to send this email or make changes?
        """
    }

    private func handleSearchEmails(_ input: [String: Any]) async throws -> String {
        let query = input["query"] as! String

        let emails = try await GmailService.shared.searchEmails(query: query)

        if emails.isEmpty {
            return "No emails found matching '\(query)'"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short

        let emailList = emails.prefix(5).map { email in
            "- [\(formatter.string(from: email.date))] \(email.subject) (from: \(email.from ?? "unknown"))"
        }.joined(separator: "\n")

        return "Found \(emails.count) email(s). Here are the most recent:\n\(emailList)"
    }

    // MARK: - Helpers
    private func parseDateTime(date: String, time: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(date) \(time)") ?? Date()
    }

    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }

    // MARK: - System Prompt
    private var systemPrompt: String {
        """
        You are ezLander, a helpful AI assistant integrated into a macOS menu bar app. You help users manage their calendar and email.

        You have access to the following tools:
        - create_calendar_event: Create new calendar events
        - list_calendar_events: List events for a date range
        - send_email: Send an email (use with caution, confirm with user first)
        - draft_email: Create a draft email for user review
        - search_emails: Search through emails

        Guidelines:
        - Be concise and helpful
        - Always confirm before sending emails
        - When creating events, clarify date/time if ambiguous
        - Format dates and times in a human-readable way
        - If you don't have enough information, ask for clarification
        """
    }
}

// MARK: - Errors
enum ClaudeError: Error, LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case toolExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .toolExecutionFailed(let reason):
            return "Tool execution failed: \(reason)"
        }
    }
}
