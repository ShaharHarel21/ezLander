import Foundation

// MARK: - AI Provider Enum
enum AIProvider: String, CaseIterable, Codable {
    case claude = "Claude"
    case kimi = "Kimi 2.5"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .kimi: return "sparkles"
        }
    }
}

// MARK: - AI Service Manager
class AIService {
    static let shared = AIService()

    @Published var currentProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(currentProvider.rawValue, forKey: "ai_provider")
        }
    }

    private init() {
        if let savedProvider = UserDefaults.standard.string(forKey: "ai_provider"),
           let provider = AIProvider(rawValue: savedProvider) {
            currentProvider = provider
        } else {
            currentProvider = .claude
        }
    }

    // MARK: - Send Message
    func sendMessage(_ text: String, conversationHistory: [ChatMessage]) async throws -> ChatMessage {
        switch currentProvider {
        case .claude:
            return try await ClaudeService.shared.sendMessage(text, conversationHistory: conversationHistory)
        case .kimi:
            return try await KimiService.shared.sendMessage(text, conversationHistory: conversationHistory)
        }
    }

    // MARK: - Check if current provider is configured
    var isConfigured: Bool {
        switch currentProvider {
        case .claude:
            return ClaudeService.shared.isConfigured
        case .kimi:
            return KimiService.shared.isConfigured
        }
    }

    // MARK: - Get configuration status for all providers
    func configurationStatus() -> [(provider: AIProvider, configured: Bool)] {
        return [
            (.claude, ClaudeService.shared.isConfigured),
            (.kimi, KimiService.shared.isConfigured)
        ]
    }
}
