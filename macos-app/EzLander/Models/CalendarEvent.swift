import Foundation

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

    enum CalendarSource: String, Codable {
        case google
        case apple
    }

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
