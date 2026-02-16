import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
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
                        .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || viewModel.isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            isInputFocused = true
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
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.role == .user ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)

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
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: animationOffset
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .onAppear {
            animationOffset = -5
        }
    }
}

// MARK: - View Model
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false

    private let claudeService = ClaudeService.shared

    init() {
        // Welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hi! I'm your AI assistant. I can help you manage your calendar, send emails, and more. What would you like to do?"
        ))
    }

    func sendMessage(_ text: String) {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isLoading = true

        Task {
            do {
                let response = try await claudeService.sendMessage(text, conversationHistory: messages)

                await MainActor.run {
                    isLoading = false
                    messages.append(response)
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
        default: return name
        }
    }

    var icon: String {
        switch name {
        case "create_calendar_event", "list_calendar_events": return "calendar"
        case "send_email", "draft_email", "search_emails": return "envelope"
        default: return "gear"
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 400, height: 400)
}
