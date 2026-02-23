import Foundation

/// Utility for parsing event-related data from natural language text and structured strings.
/// Extracted from ChatView and ClaudeService for testability and reuse.
enum EventParser {

    // MARK: - Parse Date + Time from structured strings (AI tool output)

    /// Parse a date string and time string into a combined Date.
    /// Used when the AI returns structured date/time values from tool calls.
    static func parseDateTime(date: String, time: String) -> Date {
        let parsedDate = parseDate(date)
        let cleanTime = time.trimmingCharacters(in: .whitespaces)

        let timeFormats = [
            "HH:mm",       // 15:00 (24-hour)
            "H:mm",        // 3:00 (24-hour single digit)
            "HH:mm:ss",    // 15:00:00
            "h:mm a",      // 3:00 PM
            "h:mma",       // 3:00PM
            "ha",          // 3PM
            "h a",         // 3 PM
            "h:mm",        // 3:00 (ambiguous, treat as 24h)
        ]

        var parsedHour: Int?
        var parsedMinute: Int = 0

        for format in timeFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let parsed = formatter.date(from: cleanTime) {
                let cal = Calendar.current
                parsedHour = cal.component(.hour, from: parsed)
                parsedMinute = cal.component(.minute, from: parsed)
                break
            }
        }

        // Fallback: extract numbers manually (e.g. "15", "3pm", "3:30pm")
        if parsedHour == nil {
            let lower = cleanTime.lowercased()
            let isPM = lower.contains("pm")
            let isAM = lower.contains("am")
            let digits = lower.replacingOccurrences(of: "[^0-9:]", with: "", options: .regularExpression)

            let parts = digits.split(separator: ":")
            if let hour = Int(parts.first ?? "") {
                var h = hour
                if isPM && h < 12 { h += 12 }
                if isAM && h == 12 { h = 0 }
                parsedHour = h
                parsedMinute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
            }
        }

        guard let hour = parsedHour else {
            // Use noon as fallback
            let cal = Calendar.current
            var components = cal.dateComponents([.year, .month, .day], from: parsedDate)
            components.hour = 12
            components.minute = 0
            return cal.date(from: components) ?? parsedDate
        }

        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: parsedDate)
        components.hour = hour
        components.minute = parsedMinute
        return cal.date(from: components) ?? parsedDate
    }

    /// Parse a date string in various formats into a Date.
    static func parseDate(_ dateString: String) -> Date {
        let clean = dateString.trimmingCharacters(in: .whitespaces)

        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "MMMM d, yyyy",
            "MMM d, yyyy",
            "yyyy-MM-dd'T'HH:mm",
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: clean) {
                return date
            }
        }

        return Date()
    }

    // MARK: - Parse Event Data from natural language (AI response text)

    /// Parse event data from a freeform AI response and/or user message.
    /// Returns nil if no event data can be extracted.
    static func parseEventData(from content: String, userMessage: String = "") -> EventActionData? {
        var title = extractTitleFromAIResponse(content)

        // If AI response didn't yield a good title, try the user message
        if title.isEmpty || title.lowercased() == "new event" || title.lowercased() == "event" {
            title = extractTitleFromUserMessage(userMessage)
        }

        if title.isEmpty {
            title = "New Event"
        }

        // Capitalize title
        title = title.split(separator: " ").map { word in
            word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ")

        // Parse date and time
        let textToSearch = content + " " + userMessage
        let lowerText = textToSearch.lowercased()
        let cal = Calendar.current

        var startDate = Date()

        // --- Date parsing ---
        if lowerText.contains("tomorrow") {
            startDate = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        } else if !lowerText.contains("today") {
            let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            for (index, dayName) in dayNames.enumerated() {
                let weekdayTarget = index + 1
                if lowerText.contains("next \(dayName)") || lowerText.contains("this \(dayName)") || lowerText.contains("on \(dayName)") || lowerText.contains(dayName) {
                    var comps = DateComponents()
                    comps.weekday = weekdayTarget
                    if let nextDate = cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) {
                        startDate = nextDate
                    }
                    break
                }
            }
        }

        // --- Time parsing ---
        let timePatterns = [
            "at\\s+(\\d{1,2}:\\d{2}\\s*(?:am|pm))",
            "at\\s+(\\d{1,2}\\s*(?:am|pm))",
            "at\\s+(\\d{1,2}:\\d{2})",
            "(\\d{1,2}:\\d{2}\\s*(?:am|pm))",
            "(\\d{1,2}\\s*(?:am|pm))",
        ]

        var parsedHour: Int?
        var parsedMinute: Int = 0

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsText = textToSearch as NSString
                let results = regex.matches(in: textToSearch, range: NSRange(location: 0, length: nsText.length))
                if let match = results.first, match.numberOfRanges > 1 {
                    let timeStr = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                    let lower = timeStr.lowercased()
                    let isPM = lower.contains("pm")
                    let isAM = lower.contains("am")
                    let digits = lower.replacingOccurrences(of: "[^0-9:]", with: "", options: .regularExpression)
                    let parts = digits.split(separator: ":")
                    if let hour = Int(parts.first ?? "") {
                        var h = hour
                        if isPM && h < 12 { h += 12 }
                        if isAM && h == 12 { h = 0 }
                        if !isPM && !isAM && h <= 12 { h = hour }
                        parsedHour = h
                        parsedMinute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
                    }
                    break
                }
            }
        }

        if let hour = parsedHour {
            var components = cal.dateComponents([.year, .month, .day], from: startDate)
            components.hour = hour
            components.minute = parsedMinute
            startDate = cal.date(from: components) ?? startDate
        }

        var endDate = startDate.addingTimeInterval(3600)

        // --- Duration parsing ---
        if let durationMatch = lowerText.range(of: "(\\d+)\\s*(?:hour|hr)", options: .regularExpression) {
            let numStr = String(lowerText[durationMatch]).replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let hours = Int(numStr) {
                endDate = startDate.addingTimeInterval(TimeInterval(hours * 3600))
            }
        } else if let durationMatch = lowerText.range(of: "(\\d+)\\s*(?:minute|min)", options: .regularExpression) {
            let numStr = String(lowerText[durationMatch]).replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let mins = Int(numStr) {
                endDate = startDate.addingTimeInterval(TimeInterval(mins * 60))
            }
        }

        return EventActionData(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: nil,
            description: nil
        )
    }

    // MARK: - Title Extraction

    /// Extract an event title from AI response text (looks for quoted text, "titled X", etc.)
    static func extractTitleFromAIResponse(_ content: String) -> String {
        // Look for quoted text first (most reliable)
        if let titleMatch = content.range(of: "'([^']+)'", options: .regularExpression) {
            return String(content[titleMatch]).replacingOccurrences(of: "'", with: "")
        }
        if let titleMatch = content.range(of: "\"([^\"]+)\"", options: .regularExpression) {
            return String(content[titleMatch]).replacingOccurrences(of: "\"", with: "")
        }
        // Look for "titled X" or "called X"
        if let titledMatch = content.range(of: "titled\\s+([^,\\.\\n]+)", options: .regularExpression) {
            return String(content[titledMatch]).replacingOccurrences(of: "titled ", with: "").trimmingCharacters(in: .whitespaces)
        }
        if let calledMatch = content.range(of: "called\\s+([^,\\.\\n]+)", options: .regularExpression) {
            return String(content[calledMatch]).replacingOccurrences(of: "called ", with: "").trimmingCharacters(in: .whitespaces)
        }
        // Look for "create a/an {title} (for|on|at|...)"
        if let _ = content.range(of: "(?:create|schedule|set up|book|add)\\s+(?:a |an )?(.+?)(?:\\s+(?:for|on|at|tomorrow|today|next|this|event|from)\\b|[,\\.\\n]|$)", options: [.regularExpression, .caseInsensitive]) {
            if let regex = try? NSRegularExpression(pattern: "(?:create|schedule|set up|book|add)\\s+(?:a |an )?(.+?)(?:\\s+(?:for|on|at|tomorrow|today|next|this|event|from)\\b|[,\\.\\n]|$)", options: .caseInsensitive) {
                let nsContent = content as NSString
                let results = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
                if let match = results.first, match.numberOfRanges > 1 {
                    return nsContent.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }

    /// Extract an event title from the user's original message by stripping action phrases and time references.
    static func extractTitleFromUserMessage(_ message: String) -> String {
        guard !message.isEmpty else { return "" }

        var text = message.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = [
            "create a new event for ", "create an event for ", "create event for ",
            "create a new event called ", "create an event called ",
            "add a new event for ", "add an event for ",
            "add a new event called ", "add an event called ",
            "schedule a ", "schedule an ", "schedule ",
            "set up a ", "set up an ", "set up ",
            "book a ", "book an ", "book ",
            "add a ", "add an ", "add ",
            "create a ", "create an ", "create ",
            "new event for ", "new event called ", "new event ",
            "remind me about ", "remind me to ", "remind me of ",
            "i have a ", "i have an ", "i have ",
            "i need a ", "i need an ", "i need to ",
            "put a ", "put an ", "put ",
            "make a ", "make an ", "make ",
            "can you create ", "can you schedule ", "can you add ",
            "please create ", "please schedule ", "please add ",
        ]

        let lowerText = text.lowercased()
        for prefix in prefixes {
            if lowerText.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        let timePatterns = [
            " at \\d{1,2}(:\\d{2})?\\s*(am|pm|AM|PM)?.*$",
            " on (monday|tuesday|wednesday|thursday|friday|saturday|sunday).*$",
            " on \\d{1,2}(/|-)\\d{1,2}.*$",
            " tomorrow.*$",
            " today.*$",
            " next (monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month).*$",
            " this (monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month).*$",
            " for \\d+ (minutes|hours|hour|min).*$",
            " from \\d{1,2}.*$",
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
            }
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
            .trimmingCharacters(in: .whitespaces)

        return text.count >= 2 ? text : ""
    }
}
