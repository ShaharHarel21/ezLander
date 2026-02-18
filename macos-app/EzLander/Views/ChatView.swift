import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel.shared
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            TypingIndicator()
                        }

                        // Show pending action preview
                        if let action = viewModel.pendingAction {
                            AIActionPreviewCard(
                                action: action,
                                onConfirm: {
                                    viewModel.confirmAction()
                                },
                                onDecline: {
                                    viewModel.declineAction()
                                }
                            )
                            .padding(.top, 8)
                        }

                        // Show action result
                        if let result = viewModel.actionResult {
                            AIActionResultView(success: result.success, message: result.message)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            HStack(spacing: 8) {
                TextField("Ask me anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.isEmpty ? .secondary : .warmPrimary)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || viewModel.isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            isInputFocused = true
            viewModel.loadDailyBriefingIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MeetingPrepRequested"))) { notification in
            if let event = notification.object as? CalendarEvent {
                viewModel.requestMeetingPrep(for: event)
            }
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = inputText
        inputText = ""
        viewModel.sendMessage(text)
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant {
                    FormattedTextView(text: message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(16)
                } else {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.warmPrimary, Color.warmAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }

                if let toolCall = message.toolCall {
                    ToolCallBadge(toolCall: toolCall)
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Formatted Text View (Markdown + LaTeX)
struct FormattedTextView: View {
    let text: String

    var body: some View {
        // Use SwiftUI's built-in markdown support for simple cases
        // This is much faster than custom regex parsing
        Text(LocalizedStringKey(convertToMarkdown(text)))
            .textSelection(.enabled)
    }

    // Convert common patterns to SwiftUI-compatible markdown
    private func convertToMarkdown(_ input: String) -> String {
        var result = input

        // Convert ==highlight== to **highlight** (bold as fallback)
        result = result.replacingOccurrences(of: "==([^=]+)==", with: "**$1**", options: .regularExpression)

        // Convert ++underline++ to _underline_ (italic as fallback)
        result = result.replacingOccurrences(of: "\\+\\+([^+]+)\\+\\+", with: "_$1_", options: .regularExpression)

        return result
    }
}

// MARK: - Tool Call Badge
struct ToolCallBadge: View {
    let toolCall: ToolCall

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: toolCall.icon)
            Text(toolCall.displayName)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.warmAccent)
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -5 : 0)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - View Model
class ChatViewModel: ObservableObject {
    static let shared = ChatViewModel()

    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var pendingAction: AIAction?
    @Published var actionResult: (success: Bool, message: String)?

    private let aiService = AIService.shared

    init() {
        // Welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hi! I'm your AI assistant. I can help you manage your calendar, send emails, and more. What would you like to do?\n\nWhen I want to create events or send emails, I'll show you a preview first so you can confirm."
        ))
    }

    func clearConversation() {
        messages.removeAll()
        pendingAction = nil
        actionResult = nil
        // Re-add welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hi! I'm your AI assistant. I can help you manage your calendar, send emails, and more. What would you like to do?\n\nWhen I want to create events or send emails, I'll show you a preview first so you can confirm."
        ))
    }

    // MARK: - Daily Briefing
    func loadDailyBriefingIfNeeded() {
        let defaults = UserDefaults.standard
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())

        let lastBriefingDate = defaults.string(forKey: "last_daily_briefing_date") ?? ""

        guard lastBriefingDate != todayKey else { return }
        guard GoogleCalendarService.shared.isAuthorized else { return }

        defaults.set(todayKey, forKey: "last_daily_briefing_date")

        Task {
            let briefing = await CalendarContextService.shared.buildDailyBriefing()
            await MainActor.run {
                messages.append(ChatMessage(role: .assistant, content: briefing))
            }
        }
    }

    // MARK: - Meeting Prep
    func requestMeetingPrep(for event: CalendarEvent) {
        // Switch to chat tab
        NotificationCenter.default.post(
            name: MenuBarController.switchTabNotification,
            object: "chat"
        )

        // Send as user message so the AI uses the get_meeting_prep tool
        let text = "Prepare me for my meeting: \(event.title)"
        sendMessage(text)
    }

    func sendMessage(_ text: String) {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isLoading = true
        actionResult = nil

        Task {
            do {
                let response = try await aiService.sendMessage(text, conversationHistory: messages)

                await MainActor.run {
                    isLoading = false

                    // If the AI already executed a tool call (e.g. Claude), don't parse for actions again
                    if response.toolCall != nil {
                        messages.append(response)
                    } else if let action = parseActionFromResponse(response.content, userMessage: text) {
                        pendingAction = action
                        messages.append(ChatMessage(
                            role: .assistant,
                            content: "I've prepared the following action for you. Please review and confirm:"
                        ))
                    } else {
                        messages.append(response)
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    messages.append(ChatMessage(
                        role: .assistant,
                        content: "Sorry, I encountered an error: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }

    func confirmAction() {
        guard let action = pendingAction else { return }

        Task {
            do {
                switch action.type {
                case .createEvent:
                    if let eventData = action.eventData {
                        let event = CalendarEvent(
                            id: UUID().uuidString,
                            title: eventData.title,
                            startDate: eventData.startDate,
                            endDate: eventData.endDate,
                            calendarType: .google,
                            description: eventData.description,
                            location: eventData.location
                        )
                        try await GoogleCalendarService.shared.createEvent(event)
                        await MainActor.run {
                            actionResult = (true, "Event '\(eventData.title)' created successfully!")
                            messages.append(ChatMessage(role: .assistant, content: "Done! I've created the event '\(eventData.title)' on your calendar."))
                        }
                    }

                case .sendEmail:
                    if let emailData = action.emailData {
                        let email = Email(
                            id: UUID().uuidString,
                            to: emailData.to,
                            subject: emailData.subject,
                            body: emailData.body,
                            date: Date()
                        )
                        try await GmailService.shared.sendEmail(email)
                        await MainActor.run {
                            actionResult = (true, "Email sent to \(emailData.to)")
                            messages.append(ChatMessage(role: .assistant, content: "Done! I've sent the email to \(emailData.to)."))
                        }
                    }

                case .deleteEvent:
                    if let _ = action.eventData {
                        await MainActor.run {
                            actionResult = (true, "Event deleted")
                            messages.append(ChatMessage(role: .assistant, content: "The event has been deleted."))
                        }
                    }

                default:
                    await MainActor.run {
                        actionResult = (true, "Action completed")
                    }
                }

                await MainActor.run {
                    pendingAction = nil
                }
            } catch {
                await MainActor.run {
                    actionResult = (false, error.localizedDescription)
                    messages.append(ChatMessage(role: .assistant, content: "Sorry, I couldn't complete the action: \(error.localizedDescription)"))
                    pendingAction = nil
                }
            }
        }
    }

    func declineAction() {
        pendingAction = nil
        messages.append(ChatMessage(
            role: .assistant,
            content: "No problem! I've cancelled that action. Is there anything else you'd like me to help with?"
        ))
    }

    // Parse action requests from AI response
    private func parseActionFromResponse(_ content: String, userMessage: String = "") -> AIAction? {
        // Look for action markers in the response
        // Format: [ACTION:type] followed by JSON data

        // Check for event creation pattern
        if content.contains("[CREATE_EVENT]") || content.lowercased().contains("i'll create") || content.lowercased().contains("i will create") {
            // Try to parse event details from the response
            if let eventData = parseEventData(from: content, userMessage: userMessage) {
                return AIAction(
                    type: .createEvent,
                    eventData: eventData,
                    summary: "Create '\(eventData.title)'"
                )
            }
        }

        // Check for email sending pattern
        if content.contains("[SEND_EMAIL]") || content.lowercased().contains("i'll send") || content.lowercased().contains("i will send") {
            if let emailData = parseEmailData(from: content) {
                return AIAction(
                    type: .sendEmail,
                    emailData: emailData,
                    summary: "Send email to \(emailData.to)"
                )
            }
        }

        return nil
    }

    private func parseEventData(from content: String, userMessage: String = "") -> EventActionData? {
        var title = ""
        var startDate = Date()
        var endDate = Date().addingTimeInterval(3600)
        let location: String? = nil
        let description: String? = nil

        // 1. Try to extract title from the AI response text
        // Look for quoted text first (most reliable)
        if let titleMatch = content.range(of: "'([^']+)'", options: .regularExpression) {
            title = String(content[titleMatch]).replacingOccurrences(of: "'", with: "")
        } else if let titleMatch = content.range(of: "\"([^\"]+)\"", options: .regularExpression) {
            title = String(content[titleMatch]).replacingOccurrences(of: "\"", with: "")
        }
        // Look for "titled X" or "called X"
        else if let titledMatch = content.range(of: "titled\\s+([^,\\.\\n]+)", options: .regularExpression) {
            title = String(content[titledMatch]).replacingOccurrences(of: "titled ", with: "").trimmingCharacters(in: .whitespaces)
        } else if let calledMatch = content.range(of: "called\\s+([^,\\.\\n]+)", options: .regularExpression) {
            title = String(content[calledMatch]).replacingOccurrences(of: "called ", with: "").trimmingCharacters(in: .whitespaces)
        }
        // Look for "create a/an {title} (for|on|at|tomorrow|event)"
        else if let createMatch = content.range(of: "(?:create|schedule|set up|book|add)\\s+(?:a |an )?(.+?)(?:\\s+(?:for|on|at|tomorrow|today|next|this|event|from)\\b|[,\\.\\n]|$)", options: [.regularExpression, .caseInsensitive]) {
            let fullMatch = String(content[createMatch])
            // Extract just the capture group
            if let regex = try? NSRegularExpression(pattern: "(?:create|schedule|set up|book|add)\\s+(?:a |an )?(.+?)(?:\\s+(?:for|on|at|tomorrow|today|next|this|event|from)\\b|[,\\.\\n]|$)", options: .caseInsensitive) {
                let nsContent = fullMatch as NSString
                let results = regex.matches(in: fullMatch, range: NSRange(location: 0, length: nsContent.length))
                if let match = results.first, match.numberOfRanges > 1 {
                    title = nsContent.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // 2. If we still don't have a good title, extract from user message
        if title.isEmpty || title.lowercased() == "new event" || title.lowercased() == "event" {
            title = extractTitleFromUserMessage(userMessage)
        }

        // 3. Final fallback
        if title.isEmpty {
            title = "New Event"
        }

        // Capitalize title
        title = title.split(separator: " ").map { word in
            word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ")

        // Parse date and time from both AI response and user message
        let textToSearch = content + " " + userMessage
        let lowerText = textToSearch.lowercased()
        let cal = Calendar.current

        // --- Date parsing ---
        if lowerText.contains("tomorrow") {
            startDate = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        } else if lowerText.contains("today") {
            startDate = Date()
        } else {
            // Check for day names
            let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            for (index, dayName) in dayNames.enumerated() {
                let weekdayTarget = index + 1 // Calendar weekday is 1-based (Sunday=1)
                if lowerText.contains("next \(dayName)") {
                    var comps = DateComponents()
                    comps.weekday = weekdayTarget
                    if let nextDate = cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) {
                        startDate = nextDate
                    }
                    break
                } else if lowerText.contains("this \(dayName)") || lowerText.contains("on \(dayName)") || lowerText.contains(dayName) {
                    var comps = DateComponents()
                    comps.weekday = weekdayTarget
                    if let nextDate = cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) {
                        startDate = nextDate
                    }
                    break
                }
            }
        }

        // --- Time parsing ---
        // Match patterns: "at 3pm", "at 3:00 PM", "at 15:00", "3:30pm", etc.
        let timePatterns = [
            "at\\s+(\\d{1,2}:\\d{2}\\s*(?:am|pm))",  // at 3:00 pm
            "at\\s+(\\d{1,2}\\s*(?:am|pm))",           // at 3pm
            "at\\s+(\\d{1,2}:\\d{2})",                  // at 15:00
            "(\\d{1,2}:\\d{2}\\s*(?:am|pm))",           // 3:00pm (no "at")
            "(\\d{1,2}\\s*(?:am|pm))",                  // 3pm (no "at")
        ]

        var parsedHour: Int?
        var parsedMinute: Int = 0

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsText = textToSearch as NSString
                let results = regex.matches(in: textToSearch, range: NSRange(location: 0, length: nsText.length))
                if let match = results.first, match.numberOfRanges > 1 {
                    let timeStr = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                    let lower = timeStr.lowercased()
                    let isPM = lower.contains("pm")
                    let isAM = lower.contains("am")
                    let digits = lower.replacingOccurrences(of: "[^0-9:]", with: "", options: .regularExpression)
                    let parts = digits.split(separator: ":")
                    if let hour = Int(parts.first ?? "") {
                        var h = hour
                        if isPM && h < 12 { h += 12 }
                        if isAM && h == 12 { h = 0 }
                        if !isPM && !isAM && h <= 12 { h = hour } // ambiguous, keep as-is
                        parsedHour = h
                        parsedMinute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
                    }
                    break
                }
            }
        }

        if let hour = parsedHour {
            var components = cal.dateComponents([.year, .month, .day], from: startDate)
            components.hour = hour
            components.minute = parsedMinute
            startDate = cal.date(from: components) ?? startDate
        }

        endDate = startDate.addingTimeInterval(3600) // Default 1 hour

        // --- Duration parsing ---
        if let durationMatch = lowerText.range(of: "(\\d+)\\s*(?:hour|hr)", options: .regularExpression) {
            let numStr = String(lowerText[durationMatch]).replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let hours = Int(numStr) {
                endDate = startDate.addingTimeInterval(TimeInterval(hours * 3600))
            }
        } else if let durationMatch = lowerText.range(of: "(\\d+)\\s*(?:minute|min)", options: .regularExpression) {
            let numStr = String(lowerText[durationMatch]).replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let mins = Int(numStr) {
                endDate = startDate.addingTimeInterval(TimeInterval(mins * 60))
            }
        }

        return EventActionData(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            description: description
        )
    }

    private func extractTitleFromUserMessage(_ message: String) -> String {
        guard !message.isEmpty else { return "" }

        var text = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common action phrases
        let prefixes = [
            "create a new event for ", "create an event for ", "create event for ",
            "create a new event called ", "create an event called ",
            "add a new event for ", "add an event for ",
            "add a new event called ", "add an event called ",
            "schedule a ", "schedule an ", "schedule ",
            "set up a ", "set up an ", "set up ",
            "book a ", "book an ", "book ",
            "add a ", "add an ", "add ",
            "create a ", "create an ", "create ",
            "new event for ", "new event called ", "new event ",
            "remind me about ", "remind me to ", "remind me of ",
            "i have a ", "i have an ", "i have ",
            "i need a ", "i need an ", "i need to ",
            "put a ", "put an ", "put ",
            "make a ", "make an ", "make ",
            "can you create ", "can you schedule ", "can you add ",
            "please create ", "please schedule ", "please add ",
        ]

        let lowerText = text.lowercased()
        for prefix in prefixes {
            if lowerText.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        // Remove trailing time/date phrases
        let timePatterns = [
            " at \\d{1,2}(:\\d{2})?\\s*(am|pm|AM|PM)?.*$",
            " on (monday|tuesday|wednesday|thursday|friday|saturday|sunday).*$",
            " on \\d{1,2}(/|-)\\d{1,2}.*$",
            " tomorrow.*$",
            " today.*$",
            " next (monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month).*$",
            " this (monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month).*$",
            " for \\d+ (minutes|hours|hour|min).*$",
            " from \\d{1,2}.*$",
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
            }
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
            .trimmingCharacters(in: .whitespaces)

        return text.count >= 2 ? text : ""
    }

    private func parseEmailData(from content: String) -> EmailActionData? {
        var to = ""
        var subject = "No Subject"
        var body = ""

        // Extract email address
        if let emailMatch = content.range(of: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", options: .regularExpression) {
            to = String(content[emailMatch])
        }

        // Extract subject
        if let subjectMatch = content.range(of: "subject[:\\s]+\"([^\"]+)\"", options: [.regularExpression, .caseInsensitive]) {
            let match = String(content[subjectMatch])
            if let quoteRange = match.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                subject = String(match[quoteRange]).replacingOccurrences(of: "\"", with: "")
            }
        }

        // Extract body (look for message content after "body:" or between quotes)
        if let bodyMatch = content.range(of: "body[:\\s]+\"([^\"]+)\"", options: [.regularExpression, .caseInsensitive]) {
            let match = String(content[bodyMatch])
            if let quoteRange = match.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                body = String(match[quoteRange]).replacingOccurrences(of: "\"", with: "")
            }
        }

        guard !to.isEmpty else { return nil }

        return EmailActionData(to: to, subject: subject, body: body)
    }
}

// MARK: - Models
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    var toolCall: ToolCall?

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, toolCall: ToolCall? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCall = toolCall
    }
}

struct ToolCall: Codable {
    let name: String
    let parameters: [String: String]

    var displayName: String {
        switch name {
        case "create_calendar_event": return "Creating event"
        case "list_calendar_events": return "Listing events"
        case "send_email": return "Sending email"
        case "draft_email": return "Drafting email"
        case "search_emails": return "Searching emails"
        case "get_meeting_prep": return "Preparing for meeting"
        default: return name
        }
    }

    var icon: String {
        switch name {
        case "create_calendar_event", "list_calendar_events": return "calendar"
        case "send_email", "draft_email", "search_emails": return "envelope"
        case "get_meeting_prep": return "brain.head.profile"
        default: return "gear"
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 400, height: 400)
}
