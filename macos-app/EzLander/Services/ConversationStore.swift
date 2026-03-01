import Foundation
import Combine

/// Represents a saved conversation with metadata.
struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date
    var provider: String

    init(title: String = "New Chat", messages: [ChatMessage] = [], provider: String = "claude") {
        self.id = UUID()
        self.title = title
        self.messages = messages
        self.createdAt = Date()
        self.updatedAt = Date()
        self.provider = provider
    }

    /// Auto-generate a title from the first user message.
    mutating func autoTitle() {
        if let firstUser = messages.first(where: { $0.role == .user }) {
            let text = firstUser.content.prefix(50)
            title = text.count < firstUser.content.count ? "\(text)…" : String(text)
        }
    }
}

/// Manages multiple conversations with persistence.
class ConversationStore: ObservableObject {
    static let shared = ConversationStore()

    @Published var conversations: [Conversation] = []
    @Published var activeConversationId: UUID?

    private let storageKey = "saved_conversations"
    private let maxConversations = 50

    private init() {
        loadConversations()
    }

    var activeConversation: Conversation? {
        conversations.first { $0.id == activeConversationId }
    }

    // MARK: - CRUD

    func createConversation(provider: String = "claude") -> Conversation {
        var conversation = Conversation(provider: provider)
        conversations.insert(conversation, at: 0)
        activeConversationId = conversation.id
        trimIfNeeded()
        save()
        return conversation
    }

    func updateMessages(_ messages: [ChatMessage], for id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].messages = messages
        conversations[index].updatedAt = Date()

        // Auto-title if still "New Chat"
        if conversations[index].title == "New Chat" {
            conversations[index].autoTitle()
        }
        save()
    }

    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if activeConversationId == id {
            activeConversationId = conversations.first?.id
        }
        save()
    }

    func renameConversation(_ id: UUID, to newTitle: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = newTitle
        save()
    }

    // MARK: - Export

    /// Export a conversation as plain text.
    func exportAsText(_ conversation: Conversation) -> String {
        var text = "# \(conversation.title)\n"
        text += "Date: \(formatDate(conversation.createdAt))\n"
        text += "Provider: \(conversation.provider)\n\n"

        for msg in conversation.messages {
            let role = msg.role == .user ? "You" : "ezLander"
            text += "[\(role)]\n\(msg.content)\n\n"
        }
        return text
    }

    /// Export a conversation as JSON.
    func exportAsJSON(_ conversation: Conversation) -> Data? {
        try? JSONEncoder().encode(conversation)
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Conversation].self, from: data) else {
            return
        }
        conversations = saved
        activeConversationId = conversations.first?.id
    }

    private func trimIfNeeded() {
        if conversations.count > maxConversations {
            conversations = Array(conversations.prefix(maxConversations))
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
