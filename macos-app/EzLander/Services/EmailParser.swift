import Foundation

/// Utility for parsing email-related data from text and structured strings.
/// Extracted from ChatView and GmailService for testability and reuse.
enum EmailParser {

    // MARK: - Parse Email Data from AI response text

    /// Parse email data (to, subject, body) from a freeform AI response.
    /// Returns nil if no email address can be found.
    static func parseEmailData(from content: String) -> EmailActionData? {
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

        // Extract body
        if let bodyMatch = content.range(of: "body[:\\s]+\"([^\"]+)\"", options: [.regularExpression, .caseInsensitive]) {
            let match = String(content[bodyMatch])
            if let quoteRange = match.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                body = String(match[quoteRange]).replacingOccurrences(of: "\"", with: "")
            }
        }

        guard !to.isEmpty else { return nil }

        return EmailActionData(to: to, subject: subject, body: body)
    }

    // MARK: - Extract Email Address

    /// Extract a bare email address from a string like "Name <email@example.com>".
    static func extractEmailAddress(from string: String) -> String {
        if let start = string.firstIndex(of: "<"),
           let end = string.firstIndex(of: ">") {
            let emailStart = string.index(after: start)
            return String(string[emailStart..<end])
        }
        return string.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Parse Email Date

    /// Parse an email date header string (RFC 2822 format) into a Date.
    static func parseEmailDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "EEE, d MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "d MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss z",
            "EEE, d MMM yyyy HH:mm:ss +0000",
            "yyyy-MM-dd'T'HH:mm:ssZ",
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return Date()
    }
}
