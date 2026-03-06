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

}
