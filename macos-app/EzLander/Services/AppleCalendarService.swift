import Foundation
import EventKit

class AppleCalendarService {
    static let shared = AppleCalendarService()

    private let eventStore = EKEventStore()
    private var hasAccess = false

    private init() {}

    // MARK: - Authorization
    func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                self?.hasAccess = granted
                completion(granted)
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                self?.hasAccess = granted
                completion(granted)
            }
        }
    }

    func checkAuthorizationStatus() -> EKAuthorizationStatus {
        if #available(macOS 14.0, *) {
            return EKEventStore.authorizationStatus(for: .event)
        } else {
            return EKEventStore.authorizationStatus(for: .event)
        }
    }

    var isAuthorized: Bool {
        let status = checkAuthorizationStatus()
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    // MARK: - List Events
    func listEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        guard isAuthorized else {
            throw AppleCalendarError.notAuthorized
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        return events.map { ekEvent in
            CalendarEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title ?? "Untitled",
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                calendarType: .apple,
                description: ekEvent.notes,
                location: ekEvent.location
            )
        }
    }

    // MARK: - Create Event
    func createEvent(_ event: CalendarEvent) async throws {
        guard isAuthorized else {
            throw AppleCalendarError.notAuthorized
        }

        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.notes = event.description
        ekEvent.location = event.location
        ekEvent.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(ekEvent, span: .thisEvent)
    }

    // MARK: - Update Event
    func updateEvent(_ event: CalendarEvent) async throws {
        guard isAuthorized else {
            throw AppleCalendarError.notAuthorized
        }

        guard let ekEvent = eventStore.event(withIdentifier: event.id) else {
            throw AppleCalendarError.eventNotFound
        }

        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.notes = event.description
        ekEvent.location = event.location

        try eventStore.save(ekEvent, span: .thisEvent)
    }

    // MARK: - Delete Event
    func deleteEvent(id: String) async throws {
        guard isAuthorized else {
            throw AppleCalendarError.notAuthorized
        }

        guard let ekEvent = eventStore.event(withIdentifier: id) else {
            throw AppleCalendarError.eventNotFound
        }

        try eventStore.remove(ekEvent, span: .thisEvent)
    }

    // MARK: - Get Calendars
    func getCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    // MARK: - Get Default Calendar
    func getDefaultCalendar() -> EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }
}

// MARK: - Errors
enum AppleCalendarError: Error, LocalizedError {
    case notAuthorized
    case eventNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access not authorized. Please grant access in System Settings."
        case .eventNotFound:
            return "Event not found"
        case .saveFailed:
            return "Failed to save event"
        }
    }
}
