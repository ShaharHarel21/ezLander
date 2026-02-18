import Foundation
import SwiftUI

// MARK: - Event Attendee
struct EventAttendee: Codable, Identifiable {
    var id: String { email }
    let email: String
    var displayName: String?
    var responseStatus: ResponseStatus
    var isOrganizer: Bool
    var isSelf: Bool

    enum ResponseStatus: String, Codable {
        case accepted
        case declined
        case tentative
        case needsAction
    }

    var statusIcon: String {
        switch responseStatus {
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .tentative: return "questionmark.circle.fill"
        case .needsAction: return "circle"
        }
    }

    var statusColor: Color {
        switch responseStatus {
        case .accepted: return .green
        case .declined: return .red
        case .tentative: return .orange
        case .needsAction: return .secondary
        }
    }

    var initials: String {
        let name = displayName ?? email
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Conference Data
struct ConferenceData: Codable {
    let conferenceId: String?
    let conferenceSolution: ConferenceSolution?
    let entryPoints: [ConferenceEntryPoint]?

    var joinURL: URL? {
        guard let videoEntry = entryPoints?.first(where: { $0.entryPointType == "video" }),
              let uri = videoEntry.uri else { return nil }
        return URL(string: uri)
    }

    var phoneNumber: String? {
        entryPoints?.first(where: { $0.entryPointType == "phone" })?.uri
    }
}

struct ConferenceSolution: Codable {
    let name: String?
    let iconUri: String?
}

struct ConferenceEntryPoint: Codable {
    let entryPointType: String?
    let uri: String?
    let label: String?
}

// MARK: - Calendar Event
struct CalendarEvent: Identifiable, Codable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var calendarType: CalendarSource
    var description: String?
    var location: String?
    var isAllDay: Bool = false
    var recurrence: RecurrenceRule?

    // New fields (all optional — won't break existing code)
    var attendees: [EventAttendee]?
    var meetingLink: URL?
    var organizer: EventAttendee?
    var calendarColor: String?
    var calendarName: String?
    var conferenceData: ConferenceData?
    var htmlLink: String?

    enum CalendarSource: String, Codable {
        case google
        case apple
    }

    // MARK: - Existing Computed Properties
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: startDate)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(startDate)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(startDate)
    }

    var isPast: Bool {
        endDate < Date()
    }

    // MARK: - New Computed Properties
    var hasVideoCall: Bool {
        effectiveJoinURL != nil
    }

    var effectiveJoinURL: URL? {
        // Priority: explicit meetingLink > conferenceData > description regex > location regex
        if let link = meetingLink { return link }
        if let link = conferenceData?.joinURL { return link }
        if let desc = description, let link = CalendarEvent.extractMeetingLink(from: desc) { return link }
        if let loc = location, let link = CalendarEvent.extractMeetingLink(from: loc) { return link }
        return nil
    }

    var conferenceName: String? {
        if let name = conferenceData?.conferenceSolution?.name { return name }
        if let url = effectiveJoinURL?.absoluteString {
            if url.contains("zoom.us") { return "Zoom" }
            if url.contains("meet.google.com") { return "Google Meet" }
            if url.contains("teams.microsoft.com") { return "Microsoft Teams" }
            if url.contains("webex.com") { return "Webex" }
        }
        return nil
    }

    var attendeeCount: Int {
        attendees?.count ?? 0
    }

    var acceptedAttendees: [EventAttendee] {
        attendees?.filter { $0.responseStatus == .accepted } ?? []
    }

    var organizerName: String? {
        organizer?.displayName ?? organizer?.email
    }

    // MARK: - Meeting Link Extraction
    static func extractMeetingLink(from text: String) -> URL? {
        let patterns = [
            "https?://[\\w.-]*zoom\\.us/j/[^\\s<>\"]+",
            "https?://meet\\.google\\.com/[a-z-]+",
            "https?://teams\\.microsoft\\.com/l/meetup-join/[^\\s<>\"]+",
            "https?://[\\w.-]*webex\\.com/[^\\s<>\"]+"
        ]

        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let urlString = String(text[range])
                if let url = URL(string: urlString) {
                    return url
                }
            }
        }
        return nil
    }
}

// MARK: - Recurrence
struct RecurrenceRule: Codable {
    let frequency: Frequency
    let interval: Int
    let endDate: Date?
    let count: Int?

    enum Frequency: String, Codable {
        case daily
        case weekly
        case monthly
        case yearly
    }
}

// MARK: - Calendar Event Protocol
protocol CalendarEventProvider {
    func listEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent]
    func createEvent(_ event: CalendarEvent) async throws
    func updateEvent(_ event: CalendarEvent) async throws
    func deleteEvent(id: String) async throws
}

extension GoogleCalendarService: CalendarEventProvider {}
extension AppleCalendarService: CalendarEventProvider {}
