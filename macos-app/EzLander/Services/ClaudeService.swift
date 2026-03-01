import Foundation

class ClaudeService {
    static let shared = ClaudeService()

    private var apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

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
        reloadAPIKey()
        return !apiKey.isEmpty
    }

    // MARK: - Tools Definition
    private let tools: [[String: Any]] = [
        [
            "name": "create_calendar_event",
            // Strengthened description: explicitly forbids pronouns as titles and instructs
            // Claude to ask for clarification when the user's message is too vague.
            "description": "Create a new calendar event. You MUST extract a descriptive, specific title from the user's message. NEVER use pronouns (that, this, it, those, these) or vague words (thing, stuff, something) as the event title. NEVER use generic titles like 'New Event' or 'Event'. If the user's message is too vague to extract a clear title (e.g. 'schedule that', 'remind me about this'), do NOT call this tool — instead respond asking the user for the event name.",
            "input_schema": [
                "type": "object",
                "properties": [
                    // Richer description that mirrors the system-prompt examples and explicitly
                    // calls out pronoun prohibition so the model sees it at schema-read time too.
                    "title": ["type": "string", "description": "A descriptive event title extracted from the user's message. Must be a noun phrase (e.g. 'Dentist Appointment', 'Team Standup Meeting', 'Lunch with Sarah', 'Flight to NYC'). NEVER use pronouns (that, this, it, those, these) or vague words (thing, stuff, something) as the title. NEVER use generic placeholders like 'New Event'."],
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
        // Fetch calendar context via shared service (which caches internally)
        let calendarContext = await CalendarContextService.shared.buildTodayContext()

        // Build messages array
        // Keep only last 20 messages to avoid exceeding context window
        let recentHistory = Array(conversationHistory.suffix(20))
        var messages: [[String: Any]] = recentHistory.map { message in
            ["role": message.role.rawValue, "content": message.content]
        }
        messages.append(["role": "user", "content": text])

        // Build request
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": buildSystemPrompt(calendarContext: calendarContext),
            "tools": tools,
            "messages": messages
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, httpResponse) = try await APIRetryHelper.performRequest(request)

        guard httpResponse.statusCode == 200 else {
            let message = APIRetryHelper.userFriendlyMessage(statusCode: httpResponse.statusCode, data: data)
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        guard let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.invalidResponse
        }

        // Parse response
        return try await parseResponse(responseJSON, originalMessages: messages, calendarContext: calendarContext)
    }

    // MARK: - Parse Response
    private func parseResponse(_ json: [String: Any], originalMessages: [[String: Any]], calendarContext: String) async throws -> ChatMessage {
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
                    guard let toolName = block["name"] as? String,
                          let toolInput = block["input"] as? [String: Any],
                          let toolId = block["id"] as? String else {
                        throw ClaudeError.invalidResponse
                    }

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
                        "system": buildSystemPrompt(calendarContext: calendarContext),
                        "tools": tools,
                        "messages": updatedMessages
                    ]

                    var request = URLRequest(url: URL(string: baseURL)!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.httpBody = try JSONSerialization.data(withJSONObject: finalRequestBody)

                    let (finalData, finalHttpResponse) = try await APIRetryHelper.performRequest(request)

                    guard finalHttpResponse.statusCode == 200 else {
                        let message = APIRetryHelper.userFriendlyMessage(statusCode: finalHttpResponse.statusCode, data: finalData)
                        throw ClaudeError.apiError(statusCode: finalHttpResponse.statusCode, message: message)
                    }

                    guard let finalJSON = try JSONSerialization.jsonObject(with: finalData) as? [String: Any] else {
                        throw ClaudeError.invalidResponse
                    }

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
            return try handleDraftEmail(input)
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
        guard var title = input["title"] as? String else {
            throw ClaudeError.invalidResponse
        }

        // Expanded list of titles that Claude should never use verbatim.
        // Includes generic placeholders AND pronouns/fillers that Claude occasionally
        // returns when the user's request is vague (e.g. "schedule that").
        let badTitles: Set<String> = [
            // Generic placeholders
            "new event", "event", "meeting", "untitled",
            "calendar event", "new meeting", "new calendar event",
            // Pronouns — Claude must not use these as titles (see tool description / system prompt)
            "that", "this", "it", "those", "these",
            "that's", "this is", "it's",
            // Vague fillers — singular and plural forms (BUG-3 fix: added plural/compound forms)
            "thing", "things", "stuff", "something",
            "that thing", "these things", "those things",
        ]

        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
        let isBadTitle = badTitles.contains(normalizedTitle)
            || EventParser.isPronounOrFiller(normalizedTitle)

        if isBadTitle {
            // Attempt to recover a better title from the user's original message.
            let recovered = userMessage.isEmpty
                ? ""
                : EventParser.extractTitleFromUserMessage(userMessage)

            if recovered.isEmpty {
                // The user's message is too vague — ask for clarification instead of
                // creating an event with a meaningless title.
                return "I couldn't determine a title for this event. Could you tell me what you'd like to call it?"
            }

            // Capitalise the recovered title (Title Case).
            title = recovered.split(separator: " ").map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }.joined(separator: " ")
        }
        guard let dateStr = input["date"] as? String,
              let timeStr = input["time"] as? String else {
            throw ClaudeError.invalidResponse
        }
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
            startDate: EventParser.parseDateTime(date: dateStr, time: timeStr),
            endDate: EventParser.parseDateTime(date: dateStr, time: timeStr).addingTimeInterval(TimeInterval(duration * 60)),
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
        guard let startDate = input["start_date"] as? String,
              let endDate = input["end_date"] as? String else {
            throw ClaudeError.invalidResponse
        }
        let calendarType = input["calendar_type"] as? String ?? "both"

        var events: [CalendarEvent] = []

        if calendarType == "google" || calendarType == "both" {
            let googleEvents = try await GoogleCalendarService.shared.listEvents(
                from: EventParser.parseDate(startDate),
                to: EventParser.parseDate(endDate)
            )
            events.append(contentsOf: googleEvents)
        }

        if calendarType == "apple" || calendarType == "both" {
            let appleEvents = try await AppleCalendarService.shared.listEvents(
                from: EventParser.parseDate(startDate),
                to: EventParser.parseDate(endDate)
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
        guard let to = input["to"] as? String,
              let subject = input["subject"] as? String,
              let body = input["body"] as? String else {
            throw ClaudeError.invalidResponse
        }

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

    private func handleDraftEmail(_ input: [String: Any]) throws -> String {
        guard let to = input["to"] as? String,
              let subject = input["subject"] as? String,
              let body = input["body"] as? String else {
            throw ClaudeError.invalidResponse
        }

        return """
        Draft email created:
        To: \(to)
        Subject: \(subject)

        \(body)

        Would you like me to send this email or make changes?
        """
    }

    private func handleSearchEmails(_ input: [String: Any]) async throws -> String {
        guard let query = input["query"] as? String else {
            throw ClaudeError.invalidResponse
        }

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
        guard let eventTitle = input["event_title"] as? String else {
            throw ClaudeError.invalidResponse
        }
        let dateStr = input["date"] as? String

        var searchDate: Date?
        if let dateStr = dateStr {
            searchDate = EventParser.parseDate(dateStr)
        }

        guard let event = await CalendarContextService.shared.findEvent(title: eventTitle, nearDate: searchDate) else {
            return "Could not find a meeting matching '\(eventTitle)' in the next 7 days."
        }

        let prep = await CalendarContextService.shared.buildMeetingPrepContext(for: event)
        return prep
    }

    // Event title extraction and date/time parsing extracted to EventParser utility

    // MARK: - System Prompt
    private func buildSystemPrompt(calendarContext: String) -> String {
        let base = SystemPromptProvider.buildSystemPrompt(calendarContext: calendarContext)

        // Claude-specific additions: tool use instructions
        let toolInstructions = """


        You have access to the following tools:
        - create_calendar_event: Create new calendar events (supports attendees and Google Meet video calls)
        - list_calendar_events: List events for a date range
        - send_email: Send an email (use with caution, confirm with user first)
        - draft_email: Create a draft email for user review
        - search_emails: Search through emails
        - get_meeting_prep: Get detailed meeting preparation context with attendees and recent emails

        IMPORTANT — Creating calendar events:
        - Always extract a specific, descriptive title from the user's message. NEVER use generic titles like "New Event", "Event", or "Meeting".
        - NEVER use pronouns (that, this, it, those, these) or vague words (thing, stuff, something) as the event title.
        - If the user's message is too vague to identify a clear event name — for example "schedule that", "remind me about this", or "add that thing" — do NOT call create_calendar_event. Instead, reply asking the user: "What would you like to call this event?"
        - Examples of GOOD title extraction:
          - User says "schedule a dentist appointment tomorrow at 3pm" → title: "Dentist Appointment"
          - User says "remind me about the team standup at 9am" → title: "Team Standup"
          - User says "add lunch with Sarah on Friday" → title: "Lunch with Sarah"
          - User says "I have a flight to NYC next Monday at 6am" → title: "Flight to NYC"
          - User says "book a haircut for Saturday 2pm" → title: "Haircut"
        - Examples of messages where you must ask for clarification BEFORE creating the event:
          - "Schedule that" → ask: "What would you like to call this event?"
          - "Remind me about that thing tomorrow" → ask: "What is the event you'd like me to add?"
          - "Add this on Monday" → ask: "Could you give me a name for this event?"
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
        """

        return base + toolInstructions
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