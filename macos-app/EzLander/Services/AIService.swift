import Foundation
import Combine

// MARK: - AI Provider Enum
enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case openai = "openai"
    case claude = "claude"
    case gemini = "gemini"
    case kimi = "kimi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .claude: return "Claude"
        case .gemini: return "Google Gemini"
        case .kimi: return "Kimi (NVIDIA)"
        }
    }

    var icon: String {
        switch self {
        case .openai: return "brain"
        case .claude: return "brain.head.profile"
        case .gemini: return "sparkles"
        case .kimi: return "cpu"
        }
    }

    var keychainKey: String {
        switch self {
        case .openai: return "openai_api_key"
        case .claude: return "anthropic_api_key"
        case .gemini: return "gemini_api_key"
        case .kimi: return "kimi_api_key"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openai: return "sk-..."
        case .claude: return "sk-ant-..."
        case .gemini: return "AI..."
        case .kimi: return "nvapi-..."
        }
    }

    var helpURL: String {
        switch self {
        case .openai: return "https://platform.openai.com/api-keys"
        case .claude: return "https://console.anthropic.com/settings/keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        case .kimi: return "https://build.nvidia.com"
        }
    }

    var isConfigured: Bool {
        switch self {
        case .openai: return OpenAIService.shared.isConfigured
        case .claude: return ClaudeService.shared.isConfigured
        case .gemini: return GeminiService.shared.isConfigured
        case .kimi: return KimiService.shared.isConfigured
        }
    }
}

// MARK: - AI Service Manager
class AIService: ObservableObject {
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
        case .openai:
            return try await OpenAIService.shared.sendMessage(text, conversationHistory: conversationHistory)
        case .claude:
            return try await ClaudeService.shared.sendMessage(text, conversationHistory: conversationHistory)
        case .gemini:
            return try await GeminiService.shared.sendMessage(text, conversationHistory: conversationHistory)
        case .kimi:
            return try await KimiService.shared.sendMessage(text, conversationHistory: conversationHistory)
        }
    }

    // MARK: - Check if any provider is configured
    var hasAnyProviderConfigured: Bool {
        AIProvider.allCases.contains { $0.isConfigured }
    }

    // MARK: - Get configured providers
    var configuredProviders: [AIProvider] {
        AIProvider.allCases.filter { $0.isConfigured }
    }

    // MARK: - Save API Key
    func saveAPIKey(_ key: String, for provider: AIProvider) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        KeychainService.shared.save(key: provider.keychainKey, value: trimmedKey)

        // Reload the service
        switch provider {
        case .openai: OpenAIService.shared.reloadAPIKey()
        case .claude: ClaudeService.shared.reloadAPIKey()
        case .gemini: GeminiService.shared.reloadAPIKey()
        case .kimi: KimiService.shared.reloadAPIKey()
        }
    }

    // MARK: - Remove API Key
    func removeAPIKey(for provider: AIProvider) {
        KeychainService.shared.delete(key: provider.keychainKey)

        // Reload the service to clear the cached key
        switch provider {
        case .openai: OpenAIService.shared.reloadAPIKey()
        case .claude: ClaudeService.shared.reloadAPIKey()
        case .gemini: GeminiService.shared.reloadAPIKey()
        case .kimi: KimiService.shared.reloadAPIKey()
        }
    }
}
