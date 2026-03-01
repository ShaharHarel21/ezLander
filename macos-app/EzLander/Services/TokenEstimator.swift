import Foundation

/// Lightweight token estimation for displaying usage info.
/// Uses the ~4 chars per token heuristic (accurate within ~10% for English).
enum TokenEstimator {

    /// Estimate token count for a string.
    static func estimate(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    /// Estimate tokens for a conversation history.
    static func estimateConversation(_ messages: [ChatMessage]) -> Int {
        messages.reduce(0) { $0 + estimate($1.content) + 4 } // +4 per message overhead
    }

    /// Format a token count for display.
    static func format(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    /// Estimate cost in USD based on provider and token count.
    static func estimateCost(provider: AIProvider, inputTokens: Int, outputTokens: Int) -> Double {
        switch provider {
        case .openai:
            // GPT-4o pricing: $2.50/1M input, $10/1M output
            return (Double(inputTokens) * 2.5 + Double(outputTokens) * 10.0) / 1_000_000.0
        case .claude:
            // Claude Sonnet: $3/1M input, $15/1M output
            return (Double(inputTokens) * 3.0 + Double(outputTokens) * 15.0) / 1_000_000.0
        case .gemini:
            // Gemini 2.0 Flash: $0.10/1M input, $0.40/1M output
            return (Double(inputTokens) * 0.1 + Double(outputTokens) * 0.4) / 1_000_000.0
        case .kimi:
            // Kimi via NVIDIA: ~$0.50/1M input, $2/1M output (estimate)
            return (Double(inputTokens) * 0.5 + Double(outputTokens) * 2.0) / 1_000_000.0
        }
    }

    /// Format cost for display.
    static func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return "<$0.01"
        }
        return String(format: "$%.2f", cost)
    }
}
