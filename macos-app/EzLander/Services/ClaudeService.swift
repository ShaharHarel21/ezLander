import Foundation

class ClaudeService {
    static let shared = ClaudeService()

    private var apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

    // Cached calendar context (refreshed on each sendMessage call)
    private var cachedCalendarContext: String = ""

    private init() {
        // Load API key from: 1) Keychain, 2) Environment variable, 3) Empty (will fail gracefully)
        if let keychainKey = KeychainService.shared.get(key: "anthropic_api_key"), !keychainKey.isEmpty {
            apiKey = keychainKey
        } else if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            apiKey = envKey
        } else {
            apiKey = ""
        }
    }

    // Reload API key (called after saving new key)
    func reloadAPIKey() {
        if let keychainKey = KeychainService.shared.get(key: "anthropic_api_key"), !keychainKey.isEmpty {
            apiKey = keychainKey
        } else if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            apiKey = envKey
        } else {
            apiKey = ""
        }
    }

    // MARK: - Check if configured
    var isConfigured: Bool {
        if ClaudeOAuthService.shared.isSignedIn {
            return true
        }
        reloadAPIKey()
        return !apiKey.isEmpty
    }

    // MARK: - Auth Headers
    private func setAuthHeaders(on request: inout URLRequest) async throws {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        if ClaudeOAuthService.shared.isSignedIn {
            let token = try await ClaudeOAuthService.shared.getValidAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            reloadAPIKey()
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
    }

    // MARK: - Tools Definition
    private let tools: [[String: Any]] = [
        [
            "name": "create_calendar_event",
            "description": "Create a new calendar event. Extract a descriptive, specific title from the user's message — never use generic titles like 'New Event' or 'Event'.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "A descriptive event title extracted from the user's message. Examples: 'Dentist Appointment', 'Team Standup Meeting', 'Lunch with Sarah', 'Flight to NYC'. Never use generic titles like 'New Event'."],
                    "date": ["type": "string", "description": "Event date in YYYY-MM-DD format"],
                    "time": ["type": "string", "description": "Event start time in HH:MM format (24-hour)"],
                    "duration": ["type": "integer", "description": "Duration in minutes (default 60)"],
                    "calendar_type": ["type": "string", "enum": ["google", "apple"], "description": "Which calendar to use"],
                    "attendees": ["type": "array", "items": ["type": "string"], "description": "Array of attendee email addresses to invite"],
                    "add_video_call": ["type": "boolean", "description": "Whether to add a Google Meet video call link to the event"]
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
        ],
        [
            "name": "get_meeting_prep",
            "description": "Get meeting preparation context including event details, attendees, RSVP status, and recent email threads with attendees. Use when the user asks to prepare for a meeting.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "event_title": ["type": "string", "description": "The title or partial title of the meeting to prepare for"],
                    "date": ["type": "string", "description": "Optional date in YYYY-MM-DD format to narrow the search"]
                ],
                "required": ["event_title"]
            ]
        ]
    ]

    // MARK: - Send Message
    func sendMessage(_ text: String, conversationHistory: [ChatMessage]) async throws -> ChatMessage {
        // Refresh calendar context before each message
        cachedCalendarContext = await CalendarContextService.shared.buildTodayContext()

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
        try await setAuthHeaders(on: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        var (data, response) = try await URLSession.shared.data(for: request)

        guard var httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        // Retry once on 401 if using OAuth (token may have just expired)
        if httpResponse.statusCode == 401 && ClaudeOAuthService.shared.isSignedIn {
            _ = try await ClaudeOAuthService.shared.refreshAccessToken()
            try await setAuthHeaders(on: &request)
            (data, response) = try await URLSession.shared.data(for: request)
            httpResponse = response as! HTTPURLResponse
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

                    // Get the user's original message for context
                    let userMessage = originalMessages.last(where: { $0["role"] as? String == "user" })?["content"] as? String ?? ""

                    // Execute the tool
                    let result = try await executeToolCall(name: toolName, input: toolInput, userMessage: userMessage)

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
                    try await setAuthHeaders(on: &request)
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
    private func executeToolCall(name: String, input: [String: Any], userMessage: String = "") async throws -> String {
        switch name {
        case "create_calendar_event":
            return try await handleCreateCalendarEvent(input, userMessage: userMessage)
        case "list_calendar_events":
            return try await handleListCalendarEvents(input)
        case "send_email":
            return try await handleSendEmail(input)
        case "draft_email":
            return handleDraftEmail(input)
        case "search_emails":
            return try await handleSearchEmails(input)
        case "get_meeting_prep":
            return try await handleGetMeetingPrep(input)
        default:
            return "Unknown tool: \(name)"
        }
    }

    // MARK: - Tool Handlers
    private func handleCreateCalendarEvent(_ input: [String: Any], userMessage: String = "") async throws -> String {
        NSLog("ClaudeService: create_calendar_event called with input: \(input)")
        NSLog("ClaudeService: userMessage: \(userMessage)")

        var title = input["title"] as! String

        // If the AI gave a generic title, extract a better one from the user's message
        let genericTitles = ["new event", "event", "meeting", "untitled", "calendar event", "new meeting", "new calendar event"]
        if genericTitles.contains(title.lowercased().trimmingCharacters(in: .whitespaces)) && !userMessage.isEmpty {
            title = extractTitleFromMessage(userMessage)
            NSLog("ClaudeService: Extracted better title: '\(title)'")
        }
        let dateStr = input["date"] as! String
        let timeStr = input["time"] as! String
        let duration = input["duration"] as? Int ?? 60
        let calendarType = input["calendar_type"] as? String ?? "google"
        let attendeeEmails = input["attendees"] as? [String]
        let addVideoCall = input["add_video_call"] as? Bool ?? false

        // Build attendees
        var attendees: [EventAttendee]?
        if let emails = attendeeEmails, !emails.isEmpty {
            attendees = emails.map {
                EventAttendee(email: $0, responseStatus: .needsAction, isOrganizer: false, isSelf: false)
            }
        }

        // Build conference data if video call requested
        var confData: ConferenceData?
        if addVideoCall {
            confData = ConferenceData(
                conferenceId: nil,
                conferenceSolution: ConferenceSolution(name: "Google Meet", iconUri: nil),
                entryPoints: nil
            )
        }

        let event = CalendarEvent(
            id: UUID().uuidString,
            title: title,
            startDate: parseDateTime(date: dateStr, time: timeStr),
            endDate: parseDateTime(date: dateStr, time: timeStr).addingTimeInterval(TimeInterval(duration * 60)),
            calendarType: calendarType == "google" ? .google : .apple,
            attendees: attendees,
            conferenceData: addVideoCall ? confData : nil
        )

        if calendarType == "google" {
            try await GoogleCalendarService.shared.createEvent(event)
        } else {
            try await AppleCalendarService.shared.createEvent(event)
        }

        var resultMsg = "Successfully created event '\(title)' on \(dateStr) at \(timeStr)"
        if let emails = attendeeEmails, !emails.isEmpty {
            resultMsg += " with attendees: \(emails.joined(separator: ", "))"
        }
        if addVideoCall {
            resultMsg += " with Google Meet video call"
        }
        return resultMsg
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
            var line = "- \(event.title) on \(formatter.string(from: event.startDate))"
            if event.hasVideoCall {
                line += " (video call)"
            }
            if event.attendeeCount > 0 {
                let names = event.attendees?.compactMap { $0.displayName ?? $0.email }.prefix(3).joined(separator: ", ") ?? ""
                line += " with \(names)"
                if event.attendeeCount > 3 { line += " +\(event.attendeeCount - 3) more" }
            }
            if let loc = event.location, !loc.isEmpty {
                line += " @ \(loc)"
            }
            return line
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

    private func handleGetMeetingPrep(_ input: [String: Any]) async throws -> String {
        let eventTitle = input["event_title"] as! String
        let dateStr = input["date"] as? String

        var searchDate: Date?
        if let dateStr = dateStr {
            searchDate = parseDate(dateStr)
        }

        guard let event = await CalendarContextService.shared.findEvent(title: eventTitle, nearDate: searchDate) else {
            return "Could not find a meeting matching '\(eventTitle)' in the next 7 days."
        }

        let prep = await CalendarContextService.shared.buildMeetingPrepContext(for: event)
        return prep
    }

    // MARK: - Helpers
    private func extractTitleFromMessage(_ message: String) -> String {
        var text = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common action phrases to get the core subject
        let prefixes = [
            "create a new event for ", "create an event for ", "create event for ",
            "create a new event called ", "create an event called ", "create event called ",
            "add a new event for ", "add an event for ", "add event for ",
            "add a new event called ", "add an event called ", "add event called ",
            "schedule a ", "schedule an ", "schedule ",
            "set up a ", "set up an ", "set up ",
            "book a ", "book an ", "book ",
            "add a ", "add an ", "add ",
            "create a ", "create an ", "create ",
            "new event for ", "new event called ", "new event ",
            "remind me about ", "remind me to ", "remind me of ",
            "i have a ", "i have an ", "i have ",
            "put ", "make a ", "make an ", "make ",
        ]

        let lowerText = text.lowercased()
        for prefix in prefixes {
            if lowerText.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        // Remove trailing time/date phrases like "at 3pm", "tomorrow", "on friday", etc.
        let timePatterns = [
            " at \\d{1,2}(:\\d{2})?\\s*(am|pm|AM|PM)?.*$",
            " on (monday|tuesday|wednesday|thursday|friday|saturday|sunday).*$",
            " on \\d{1,2}(/|-)\\d{1,2}.*$",
            " tomorrow.*$",
            " today.*$",
            " next (monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month).*$",
            " this (monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month).*$",
            " for \\d+ (minutes|hours|hour|min).*$",
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
            }
        }

        // Clean up and capitalize
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
            .trimmingCharacters(in: .whitespaces)

        // Capitalize each word
        if !text.isEmpty {
            text = text.split(separator: " ").map { word in
                let lower = word.lowercased()
                // Don't capitalize small words unless first word
                let smallWords = ["a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with"]
                if smallWords.contains(lower) {
                    return String(word)
                }
                return word.prefix(1).uppercased() + word.dropFirst()
            }.joined(separator: " ")
            // Always capitalize first letter
            text = text.prefix(1).uppercased() + text.dropFirst()
        }

        // Fallback if extraction resulted in empty or very short string
        if text.count < 2 {
            return "New Event"
        }

        // Truncate if too long
        if text.count > 60 {
            text = String(text.prefix(60))
        }

        return text
    }

    private func parseDateTime(date: String, time: String) -> Date {
        NSLog("ClaudeService: Parsing date='\(date)' time='\(time)'")

        // Parse the date part
        let parsedDate = parseDate(date)

        // Parse the time part — try multiple formats the AI might use
        let cleanTime = time.trimmingCharacters(in: .whitespaces)
        let timeFormats = [
            "HH:mm",       // 15:00 (24-hour)
            "H:mm",        // 3:00 (24-hour single digit)
            "HH:mm:ss",    // 15:00:00
            "h:mm a",      // 3:00 PM
            "h:mma",       // 3:00PM
            "ha",          // 3PM
            "h a",         // 3 PM
            "h:mm",        // 3:00 (ambiguous, treat as 24h)
        ]

        var parsedHour: Int?
        var parsedMinute: Int = 0

        for format in timeFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let parsed = formatter.date(from: cleanTime) {
                let cal = Calendar.current
                parsedHour = cal.component(.hour, from: parsed)
                parsedMinute = cal.component(.minute, from: parsed)
                NSLog("ClaudeService: Parsed time with format '\(format)' → \(parsedHour!):\(parsedMinute)")
                break
            }
        }

        // Fallback: try to extract numbers manually (e.g. "15", "3pm", "3:30pm")
        if parsedHour == nil {
            let lower = cleanTime.lowercased()
            let isPM = lower.contains("pm")
            let isAM = lower.contains("am")
            let digits = lower.replacingOccurrences(of: "[^0-9:]", with: "", options: .regularExpression)

            let parts = digits.split(separator: ":")
            if let hour = Int(parts.first ?? "") {
                var h = hour
                if isPM && h < 12 { h += 12 }
                if isAM && h == 12 { h = 0 }
                parsedHour = h
                parsedMinute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
                NSLog("ClaudeService: Manual time parse → \(parsedHour!):\(parsedMinute)")
            }
        }

        guard let hour = parsedHour else {
            NSLog("ClaudeService: Failed to parse time '\(time)', using noon")
            // Use noon as fallback instead of current time
            let cal = Calendar.current
            var components = cal.dateComponents([.year, .month, .day], from: parsedDate)
            components.hour = 12
            components.minute = 0
            return cal.date(from: components) ?? parsedDate
        }

        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: parsedDate)
        components.hour = hour
        components.minute = parsedMinute
        let result = cal.date(from: components) ?? parsedDate
        NSLog("ClaudeService: Final parsed datetime: \(result)")
        return result
    }

    private func parseDate(_ dateString: String) -> Date {
        let clean = dateString.trimmingCharacters(in: .whitespaces)

        // Try multiple date formats
        let formats = [
            "yyyy-MM-dd",          // 2026-02-19
            "MM/dd/yyyy",          // 02/19/2026
            "dd/MM/yyyy",          // 19/02/2026
            "MMMM d, yyyy",       // February 19, 2026
            "MMM d, yyyy",        // Feb 19, 2026
            "yyyy-MM-dd'T'HH:mm", // 2026-02-19T15:00
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: clean) {
                return date
            }
        }

        NSLog("ClaudeService: Failed to parse date '\(dateString)', using today")
        return Date()
    }

    // MARK: - System Prompt
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

        You have access to the following tools:
        - create_calendar_event: Create new calendar events (supports attendees and Google Meet video calls)
        - list_calendar_events: List events for a date range
        - send_email: Send an email (use with caution, confirm with user first)
        - draft_email: Create a draft email for user review
        - search_emails: Search through emails
        - get_meeting_prep: Get detailed meeting preparation context with attendees and recent emails

        IMPORTANT — Creating calendar events:
        - Always extract a specific, descriptive title from the user's message. NEVER use generic titles like "New Event", "Event", or "Meeting".
        - Examples of good title extraction:
          - User says "schedule a dentist appointment tomorrow at 3pm" → title: "Dentist Appointment"
          - User says "remind me about the team standup at 9am" → title: "Team Standup"
          - User says "add lunch with Sarah on Friday" → title: "Lunch with Sarah"
          - User says "I have a flight to NYC next Monday at 6am" → title: "Flight to NYC"
          - User says "book a haircut for Saturday 2pm" → title: "Haircut"
        - Resolve relative dates like "tomorrow", "next Monday", "this Friday" using today's date.
        - If the user doesn't specify a duration, default to 60 minutes. Use shorter durations for quick things (haircut: 30min) and longer for things like flights.
        - If the date or time is ambiguous, ask for clarification before creating the event.
        - If the user mentions attendees (e.g., "with john@example.com"), include their emails in the attendees array.
        - If the user asks for a video call or mentions Zoom/Meet, set add_video_call to true.

        IMPORTANT — Calendar awareness:
        - You already have today's schedule injected above. When the user asks "what's on my calendar today?" or similar, answer directly from that context without needing to call list_calendar_events.
        - Only use list_calendar_events for date ranges you don't already have in context.
        - When discussing events, mention attendees, video calls, and locations when relevant.

        IMPORTANT — Meeting prep:
        - When the user asks to prepare for a meeting, use the get_meeting_prep tool to get detailed context.
        - Provide a concise briefing: who's attending, their RSVP status, key topics from recent emails, and the video call link.

        General guidelines:
        - Be concise and helpful
        - Always confirm before sending emails
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
