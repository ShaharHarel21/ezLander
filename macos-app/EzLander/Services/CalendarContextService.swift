import Foundation

class CalendarContextService {
    static let shared = CalendarContextService()

    private init() {}

    // MARK: - Build Today Context (for AI system prompt injection)
    func buildTodayContext() async -> String {
        guard GoogleCalendarService.shared.isAuthorized else {
            return "Calendar: Not connected to Google Calendar."
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return "Calendar: Unable to determine today's date range."
        }

        do {
            let events = try await GoogleCalendarService.shared.listEvents(from: startOfDay, to: endOfDay)
            if events.isEmpty {
                return "Calendar: No events scheduled for today."
            }

            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            var lines: [String] = ["Today's schedule (\(events.count) event\(events.count == 1 ? "" : "s")):"]
            for event in events {
                var line = "- "
                if event.isAllDay {
                    line += "[All Day] "
                } else {
                    line += "[\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))] "
                }
                line += event.title
                if event.hasVideoCall {
                    line += " (video call)"
                }
                if event.attendeeCount > 0 {
                    line += " (\(event.attendeeCount) attendees)"
                }
                if let loc = event.location, !loc.isEmpty {
                    line += " @ \(loc)"
                }
                lines.append(line)
            }
            return lines.joined(separator: "\n")
        } catch {
            return "Calendar: Error fetching today's events."
        }
    }

    // MARK: - Build Upcoming Context (next 24 hours)
    func buildUpcomingContext() async -> String {
        guard GoogleCalendarService.shared.isAuthorized else { return "" }

        let now = Date()
        guard let tomorrow = Calendar.current.date(byAdding: .hour, value: 24, to: now) else { return "" }

        do {
            let events = try await GoogleCalendarService.shared.listEvents(from: now, to: tomorrow)
            let futureEvents = events.filter { $0.startDate > now }

            if futureEvents.isEmpty { return "No upcoming events in the next 24 hours." }

            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "E h:mm a"

            var lines: [String] = ["Upcoming events:"]
            for event in futureEvents.prefix(10) {
                var line = "- "
                if event.isAllDay {
                    line += "[All Day] "
                } else if Calendar.current.isDateInToday(event.startDate) {
                    line += "[\(timeFormatter.string(from: event.startDate))] "
                } else {
                    line += "[\(dateFormatter.string(from: event.startDate))] "
                }
                line += event.title
                if event.hasVideoCall { line += " (video call)" }
                lines.append(line)
            }
            return lines.joined(separator: "\n")
        } catch {
            return ""
        }
    }

    // MARK: - Build Meeting Prep Context
    func buildMeetingPrepContext(for event: CalendarEvent) async -> String {
        var sections: [String] = []

        // Event details
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .short

        var details = "Meeting: \(event.title)\n"
        details += "When: \(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))\n"
        if let loc = event.location, !loc.isEmpty {
            details += "Where: \(loc)\n"
        }
        if event.hasVideoCall, let name = event.conferenceName {
            details += "Video Call: \(name)\n"
        }
        if let desc = event.description, !desc.isEmpty {
            details += "Notes: \(desc)\n"
        }
        sections.append(details)

        // Attendees
        if let attendees = event.attendees, !attendees.isEmpty {
            var attendeeSection = "Attendees (\(attendees.count)):\n"
            for attendee in attendees {
                let name = attendee.displayName ?? attendee.email
                let status = attendee.responseStatus.rawValue
                var line = "- \(name) (\(status))"
                if attendee.isOrganizer { line += " [organizer]" }
                if attendee.isSelf { line += " [you]" }
                attendeeSection += "\(line)\n"
            }
            sections.append(attendeeSection)

            // Recent email context with attendees (limit to 3 attendees, 3 emails each)
            let externalAttendees = attendees.filter { !$0.isSelf }.prefix(3)
            if !externalAttendees.isEmpty && GmailService.shared.isAuthorized {
                var emailContext = "Recent email threads with attendees:\n"
                var hasEmails = false

                for attendee in externalAttendees {
                    do {
                        let emails = try await GmailService.shared.searchEmails(query: "from:\(attendee.email) OR to:\(attendee.email)", maxResults: 3)
                        if !emails.isEmpty {
                            hasEmails = true
                            let name = attendee.displayName ?? attendee.email
                            emailContext += "\n  With \(name):\n"
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateStyle = .short
                            for email in emails {
                                emailContext += "  - [\(dateFormatter.string(from: email.date))] \(email.subject)\n"
                            }
                        }
                    } catch {
                        // Skip email context on error
                    }
                }

                if hasEmails {
                    sections.append(emailContext)
                }
            }
        }

        return sections.joined(separator: "\n")
    }

    // MARK: - Build Daily Briefing
    func buildDailyBriefing() async -> String {
        guard GoogleCalendarService.shared.isAuthorized else {
            return "Good morning! Connect your Google Calendar in Settings to get a daily briefing."
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return "Good morning! I couldn't load your calendar."
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        let todayStr = dateFormatter.string(from: Date())

        do {
            let events = try await GoogleCalendarService.shared.listEvents(from: startOfDay, to: endOfDay)

            if events.isEmpty {
                return "Good morning! Today is **\(todayStr)**. You have a clear schedule today -- no events planned."
            }

            var briefing = "Good morning! Here's your briefing for **\(todayStr)**:\n\n"
            briefing += "You have **\(events.count) event\(events.count == 1 ? "" : "s")** today:\n\n"

            // Find "up next" -- next event that hasn't started yet
            let now = Date()
            let upNext = events.first(where: { $0.startDate > now })

            for event in events {
                var line = ""
                if event.isAllDay {
                    line += "All Day"
                } else {
                    line += "\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))"
                }
                line += " · **\(event.title)**"

                if event.hasVideoCall {
                    line += " · Video call"
                }
                if event.attendeeCount > 0 {
                    line += " · \(event.attendeeCount) attendee\(event.attendeeCount == 1 ? "" : "s")"
                }
                if let loc = event.location, !loc.isEmpty {
                    line += " · \(loc)"
                }

                if let next = upNext, next.id == event.id {
                    line += " ← **Up Next**"
                }

                briefing += "- \(line)\n"
            }

            // Summary stats
            let videoCallCount = events.filter { $0.hasVideoCall }.count
            if videoCallCount > 0 {
                briefing += "\nYou have \(videoCallCount) video call\(videoCallCount == 1 ? "" : "s") today."
            }

            return briefing
        } catch {
            return "Good morning! Today is **\(todayStr)**. I had trouble loading your calendar, but you can ask me about your schedule anytime."
        }
    }

    // MARK: - Find Event by Title (for meeting prep tool)
    func findEvent(title: String, nearDate: Date? = nil) async -> CalendarEvent? {
        let searchDate = nearDate ?? Date()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: searchDate)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }

        do {
            let events = try await GoogleCalendarService.shared.listEvents(from: start, to: end)
            // Find best match by title
            let lowered = title.lowercased()
            return events.first(where: { $0.title.lowercased().contains(lowered) })
                ?? events.first(where: { lowered.contains($0.title.lowercased()) })
        } catch {
            return nil
        }
    }
}
