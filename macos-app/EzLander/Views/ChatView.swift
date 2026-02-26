import SwiftUI

struct ChatView: View {
    @ObservedObject private var viewModel = ChatViewModel.shared
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat header with clear button
            HStack {
                Spacer()
                Button(action: { viewModel.clearConversation() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("New Chat")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .padding(.top, 6)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)

                            // Show action preview card inline after the message that triggered it
                            if message.id == viewModel.pendingActionMessageId, let action = viewModel.pendingAction {
                                AIActionPreviewCard(
                                    action: action,
                                    onConfirm: { editedAction in
                                        viewModel.confirmAction(editedAction)
                                    },
                                    onDecline: {
                                        viewModel.declineAction()
                                    }
                                )
                                .padding(.top, 4)
                            }

                            // Show action result inline after the result message
                            if message.id == viewModel.actionResultMessageId, let result = viewModel.actionResult {
                                AIActionResultView(success: result.success, message: result.message)
                                    .padding(.top, 4)
                            }
                        }

                        if viewModel.isLoading {
                            TypingIndicator()
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

            Rectangle()
                .fill(Color.glassSeparator)
                .frame(height: 0.5)

            // Quick action buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickActionButton(icon: "calendar", label: "Today's Schedule") {
                        viewModel.sendMessage("What's on my calendar today?")
                    }
                    QuickActionButton(icon: "envelope", label: "Draft Email") {
                        viewModel.sendMessage("Help me draft an email")
                    }
                    QuickActionButton(icon: "magnifyingglass", label: "Search Emails") {
                        viewModel.sendMessage("Search my recent emails")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Input area
            HStack(spacing: 8) {
                TextField("Ask me anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                    )
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
            .background(
                ZStack {
                    Rectangle().fill(.regularMaterial)
                    Rectangle().fill(Color.warmSoft.opacity(0.06))
                    Rectangle().fill(Color.white.opacity(0.10)).frame(height: 0.5).frame(maxHeight: .infinity, alignment: .top)
                }
            )
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

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(Color.warmPrimary.opacity(0.10))
                    Capsule().strokeBorder(Color.warmPrimary.opacity(0.22), lineWidth: 0.5)
                }
            )
            .foregroundColor(.warmPrimary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    @State private var appeared = false

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
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 18).fill(Color.warmSoft.opacity(0.10))
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(
                                        LinearGradient(colors: [.white.opacity(0.40), .white.opacity(0.08)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 0.75
                                    )
                            }
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                LinearGradient(
                                    colors: [Color.warmPrimary, Color.warmAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LinearGradient(
                                    colors: [.white.opacity(0.22), .clear, .clear],
                                    startPoint: .topLeading, endPoint: .center
                                ))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(.white.opacity(0.20), lineWidth: 0.75)
                        )
                        .shadow(color: Color.warmPrimary.opacity(0.28), radius: 10, x: 0, y: 3)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                if let toolCall = message.toolCall {
                    ToolCallBadge(toolCall: toolCall)
                }
            }
            .scaleEffect(appeared ? 1.0 : 0.85, anchor: message.role == .user ? .bottomTrailing : .bottomLeading)
            .opacity(appeared ? 1.0 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(.spring(response: 0.35, dampingFraction: 0.70), value: appeared)
            .onAppear { appeared = true }

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
        .background(
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color.warmSoft.opacity(0.08))
                Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            }
        )
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

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
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18).fill(Color.warmSoft.opacity(0.10))
                RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            if !reduceMotion {
                animating = true
            }
        }
    }
}

// MARK: - View Model
class ChatViewModel: ObservableObject {
    static let shared = ChatViewModel()

    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var pendingAction: AIAction?
    @Published var pendingActionMessageId: UUID?
    @Published var actionResult: (success: Bool, message: String)?
    @Published var actionResultMessageId: UUID?

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
        pendingActionMessageId = nil
        actionResult = nil
        actionResultMessageId = nil
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
                        let actionMsg = ChatMessage(
                            role: .assistant,
                            content: "I've prepared the following action for you. Please review and confirm:"
                        )
                        pendingActionMessageId = actionMsg.id
                        messages.append(actionMsg)
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

    func confirmAction(_ editedAction: AIAction? = nil) {
        guard let action = editedAction ?? pendingAction else { return }
        let resultMsgId = pendingActionMessageId

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
                            let resultMsg = ChatMessage(role: .assistant, content: "Done! I've created the event '\(eventData.title)' on your calendar.")
                            actionResult = (true, "Event '\(eventData.title)' created successfully!")
                            actionResultMessageId = resultMsg.id
                            messages.append(resultMsg)
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
                            let resultMsg = ChatMessage(role: .assistant, content: "Done! I've sent the email to \(emailData.to).")
                            actionResult = (true, "Email sent to \(emailData.to)")
                            actionResultMessageId = resultMsg.id
                            messages.append(resultMsg)
                        }
                    }

                case .deleteEvent:
                    if let _ = action.eventData {
                        await MainActor.run {
                            let resultMsg = ChatMessage(role: .assistant, content: "The event has been deleted.")
                            actionResult = (true, "Event deleted")
                            actionResultMessageId = resultMsg.id
                            messages.append(resultMsg)
                        }
                    }

                default:
                    await MainActor.run {
                        actionResult = (true, "Action completed")
                    }
                }

                await MainActor.run {
                    pendingAction = nil
                    pendingActionMessageId = nil
                }
            } catch {
                await MainActor.run {
                    let resultMsg = ChatMessage(role: .assistant, content: "Sorry, I couldn't complete the action: \(error.localizedDescription)")
                    actionResult = (false, error.localizedDescription)
                    actionResultMessageId = resultMsg.id
                    messages.append(resultMsg)
                    pendingAction = nil
                    pendingActionMessageId = nil
                }
            }
        }
    }

    func declineAction() {
        pendingAction = nil
        pendingActionMessageId = nil
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
            if let eventData = EventParser.parseEventData(from: content, userMessage: userMessage) {
                return AIAction(
                    type: .createEvent,
                    eventData: eventData,
                    summary: "Create '\(eventData.title)'"
                )
            }
        }

        // Check for email sending pattern
        if content.contains("[SEND_EMAIL]") || content.lowercased().contains("i'll send") || content.lowercased().contains("i will send") {
            if let emailData = EmailParser.parseEmailData(from: content) {
                return AIAction(
                    type: .sendEmail,
                    emailData: emailData,
                    summary: "Send email to \(emailData.to)"
                )
            }
        }

        return nil
    }

    // Event and email parsing logic has been extracted to EventParser and EmailParser utilities
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
