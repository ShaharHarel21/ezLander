import Foundation
import Combine

// MARK: - Reply Tone
enum ReplyTone: String, CaseIterable, Identifiable {
    case formal
    case casual
    case friendly
    case concise

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .formal: return "Formal"
        case .casual: return "Casual"
        case .friendly: return "Friendly"
        case .concise: return "Concise"
        }
    }

    var icon: String {
        switch self {
        case .formal: return "briefcase"
        case .casual: return "cup.and.saucer"
        case .friendly: return "face.smiling"
        case .concise: return "text.justify.left"
        }
    }
}

// MARK: - AI Model Selection
enum AIModel: String, CaseIterable, Identifiable {
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o (Smartest)"
        case .gpt4oMini: return "GPT-4o Mini (Fast)"
        }
    }

    var icon: String {
        switch self {
        case .gpt4o: return "brain"
        case .gpt4oMini: return "brain.head.profile"
        }
    }
}

// MARK: - AI Service Manager
class AIService: ObservableObject {
    static let shared = AIService()

    private let proxyService = ProxyAIService.shared

    @Published var selectedModel: AIModel {
        didSet {
            proxyService.selectedModel = selectedModel.rawValue
            UserDefaults.standard.set(selectedModel.rawValue, forKey: "ai_model")
        }
    }

    private init() {
        if let savedModel = UserDefaults.standard.string(forKey: "ai_model"),
           let model = AIModel(rawValue: savedModel) {
            selectedModel = model
        } else {
            selectedModel = .gpt4oMini
        }
        proxyService.selectedModel = selectedModel.rawValue
    }

    // MARK: - Send Message
    func sendMessage(_ text: String, conversationHistory: [ChatMessage]) async throws -> ChatMessage {
        return try await proxyService.sendMessage(text, conversationHistory: conversationHistory)
    }

    // MARK: - Stream Message
    func streamMessage(_ text: String, conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error>? {
        return proxyService.streamMessage(text, conversationHistory: conversationHistory)
    }

    // MARK: - Summarize Email
    func summarizeEmail(subject: String, body: String) async throws -> String {
        let prompt = "Summarize this email concisely in 2-3 sentences. Only return the summary, nothing else.\n\nSubject: \(subject)\n\n\(body)"
        let response = try await sendMessage(prompt, conversationHistory: [])
        return response.content
    }

    // MARK: - Suggest Reply
    func suggestReply(to subject: String, body: String, tone: ReplyTone) async throws -> String {
        let prompt = "Write a \(tone.displayName.lowercased()) reply to this email. Only return the reply text, no subject line or email headers.\n\nOriginal email subject: \(subject)\n\n\(body)"
        let response = try await sendMessage(prompt, conversationHistory: [])
        return response.content
    }

    // MARK: - Usage Info
    var tokensUsed: Int { proxyService.tokensUsed }
    var tokensLimit: Int { proxyService.tokensLimit }
    var tokensRemaining: Int { proxyService.tokensRemaining }
    var tier: String { proxyService.tier }

    var currentModelName: String { selectedModel.displayName }

    var isAuthenticated: Bool {
        proxyService.isAuthenticated
    }
}
