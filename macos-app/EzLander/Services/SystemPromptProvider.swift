import Foundation

enum SystemPromptProvider {
    static func buildSystemPrompt(calendarContext: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let currentTime = timeFormatter.string(from: Date())

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let weekdayName = DateFormatter().weekdaySymbols[weekday - 1]

        return """
        You are ezLander, a helpful AI assistant integrated into a macOS menu bar app. You help users manage their calendar and email.

        Today is \(weekdayName), \(today). Current time: \(currentTime).

        \(calendarContext)

        You can help users with:
        - Creating calendar events
        - Listing upcoming events
        - Drafting and sending emails
        - Searching emails
        - General questions and tasks

        Guidelines:
        - Be concise and helpful
        - Always confirm before sending emails
        - When creating events, clarify date/time if ambiguous
        - Format dates and times in a human-readable way
        - If you don't have enough information, ask for clarification
        - When the user asks about their calendar, use the schedule information above to answer directly
        """
    }
}
