import Foundation

class CalendarContextService {
    static let shared = CalendarContextService()

    private init() {}

    // MARK: - Context Cache
    private var cachedContext: String = ""
    private var lastCacheTime: Date?
    private let cacheDuration: TimeInterval = 120 // 2 minutes

    // MARK: - Weekly Context Cache
    private var cachedWeekContext: String = ""
    private var lastWeekCacheTime: Date?

    // MARK: - Build Today & Tomorrow Context (for AI system prompt injection)
    func buildTodayContext() async -> String {
        // Return cached context if still fresh
        if let lastTime = lastCacheTime, Date().timeIntervalSince(lastTime) < cacheDuration, !cachedContext.isEmpty {
            return cachedContext
        }
        // Otherwise fetch fresh
        let context = await fetchFreshContext()
        cachedContext = context
        lastCacheTime = Date()
        return context
    }

    // MARK: - Build Week Context (Mon-Sun grouped by day)
    func buildWeekContext() async -> String {
        // Return cached weekly context if still fresh
        if let lastTime = lastWeekCacheTime, Date().timeIntervalSince(lastTime) < cacheDuration, !cachedWeekContext.isEmpty {
            return cachedWeekContext
        }

        let context = await fetchWeekContext()
        cachedWeekContext = context
        lastWeekCacheTime = Date()
        return context
    }

    // MARK: - Fetch Week Context
    private func fetchWeekContext() async -> String {
        let calendar = Calendar.current
        let now = Date()

        // Find Monday of this week
        let weekday = calendar.component(.weekday, from: now)
        // .weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now)),
              let sundayEnd = calendar.date(byAdding: .day, value: 7, to: monday) else {
            return ""
        }

        guard GoogleCalendarService.shared.isAuthorized || AppleCalendarService.shared.isAuthorized else {
            return ""
        }

        do {
            let events: [CalendarEvent]
            if GoogleCalendarService.shared.isAuthorized {
                events = try await GoogleCalendarService.shared.listEvents(from: monday, to: sundayEnd)
            } else {
                events = try await AppleCalendarService.shared.listEvents(from: monday, to: sundayEnd)
            }

            if events.isEmpty {
                return "This week's schedule: No events."
            }

            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE, MMM d"

            // Group events by day
            var dayGroups: [(String, [CalendarEvent])] = []
            for dayOffset in 0..<7 {
                guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: monday) else { continue }
                let dayLabel = dayFormatter.string(from: dayStart)
                let isToday = calendar.isDateInToday(dayStart)
                let label = isToday ? "\(dayLabel) (Today)" : dayLabel
                let dayEvents = events.filter { calendar.isDate($0.startDate, inSameDayAs: dayStart) }
                if !dayEvents.isEmpty {
                    dayGroups.append((label, dayEvents))
                }
            }

            var lines: [String] = ["This week's schedule:"]
            for (dayLabel, dayEvents) in dayGroups {
                lines.append("\n\(dayLabel):")
                for event in dayEvents {
                    var line = "  - "
                    if event.isAllDay {
                        line += "[All Day] "
                    } else {
                        line += "[\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))] "
                    }
                    line += event.title
                    if event.hasVideoCall { line += " (video call)" }
                    if event.attendeeCount > 0 { line += " (\(event.attendeeCount) attendees)" }
                    if let loc = event.location, !loc.isEmpty { line += " @ \(loc)" }
                    lines.append(line)
                }
            }
            return lines.joined(separator: "\n")
        } catch {
            return ""
        }
    }

    // MARK: - Fetch Fresh Context (today + tomorrow + upcoming countdown)
    private func fetchFreshContext() async -> String {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfDay) else {
            return "Calendar: Unable to determine date range."
        }

        guard GoogleCalendarService.shared.isAuthorized || AppleCalendarService.shared.isAuthorized else {
            return "Calendar: Not connected to any calendar."
        }

        do {
            let allEvents: [CalendarEvent]
            if GoogleCalendarService.shared.isAuthorized {
                allEvents = try await GoogleCalendarService.shared.listEvents(from: startOfDay, to: endOfTomorrow)
            } else {
                allEvents = try await AppleCalendarService.shared.listEvents(from: startOfDay, to: endOfTomorrow)
            }

            let todayEvents = allEvents.filter { calendar.isDateInToday($0.startDate) }
            let tomorrowEvents = allEvents.filter { calendar.isDateInTomorrow($0.startDate) }

            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            var lines: [String] = []

            // Upcoming event countdown
            let nextEvent = todayEvents.first(where: { !$0.isAllDay && $0.startDate > now })
            if let next = nextEvent {
                let minutesUntil = Int(next.startDate.timeIntervalSince(now) / 60)
                if minutesUntil < 60 {
                    lines.append("Next: \(next.title) in \(minutesUntil) minutes")
                } else {
                    let hours = minutesUntil / 60
                    let mins = minutesUntil % 60
                    if mins > 0 {
                        lines.append("Next: \(next.title) in \(hours)h \(mins)m")
                    } else {
                        lines.append("Next: \(next.title) in \(hours) hour\(hours == 1 ? "" : "s")")
                    }
                }
                lines.append("")
            }

            // Today's events
            if todayEvents.isEmpty {
                lines.append("Today's schedule: No events scheduled.")
            } else {
                lines.append("Today's schedule (\(todayEvents.count) event\(todayEvents.count == 1 ? "" : "s")):")
                for event in todayEvents {
                    lines.append(formatEventLine(event, timeFormatter: timeFormatter))
                }
            }

            // Tomorrow's events
            if !tomorrowEvents.isEmpty {
                lines.append("")
                lines.append("Tomorrow (\(tomorrowEvents.count) event\(tomorrowEvents.count == 1 ? "" : "s")):")
                for event in tomorrowEvents {
                    lines.append(formatEventLine(event, timeFormatter: timeFormatter))
                }
            }

            return lines.joined(separator: "\n")
        } catch {
            return "Calendar: Error fetching events."
        }
    }

    // MARK: - Format Event Line
    private func formatEventLine(_ event: CalendarEvent, timeFormatter: DateFormatter) -> String {
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
        return line
    }

    // MARK: - Build Upcoming Context (next 24 hours)
    func buildUpcomingContext() async -> String {
        guard GoogleCalendarService.shared.isAuthorized || AppleCalendarService.shared.isAuthorized else { return "" }

        let now = Date()
        guard let tomorrow = Calendar.current.date(byAdding: .hour, value: 24, to: now) else { return "" }

        do {
            let events: [CalendarEvent]
            if GoogleCalendarService.shared.isAuthorized {
                events = try await GoogleCalendarService.shared.listEvents(from: now, to: tomorrow)
            } else {
                events = try await AppleCalendarService.shared.listEvents(from: now, to: tomorrow)
            }
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
        guard GoogleCalendarService.shared.isAuthorized || AppleCalendarService.shared.isAuthorized else {
            return "Good morning! Connect your calendar in Settings to get a daily briefing."
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
            let events: [CalendarEvent]
            if GoogleCalendarService.shared.isAuthorized {
                events = try await GoogleCalendarService.shared.listEvents(from: startOfDay, to: endOfDay)
            } else {
                events = try await AppleCalendarService.shared.listEvents(from: startOfDay, to: endOfDay)
            }

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
            let events: [CalendarEvent]
            if GoogleCalendarService.shared.isAuthorized {
                events = try await GoogleCalendarService.shared.listEvents(from: start, to: end)
            } else if AppleCalendarService.shared.isAuthorized {
                events = try await AppleCalendarService.shared.listEvents(from: start, to: end)
            } else {
                return nil
            }
            // Find best match by title
            let lowered = title.lowercased()
            return events.first(where: { $0.title.lowercased().contains(lowered) })
                ?? events.first(where: { lowered.contains($0.title.lowercased()) })
        } catch {
            return nil
        }
    }
}
