import Foundation
import os.log

private let logger = Logger(subsystem: "com.ezlander.app", category: "GoogleCalendar")

class GoogleCalendarService {
    static let shared = GoogleCalendarService()

    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let oauthService = OAuthService.shared

    private init() {}

    // MARK: - Authorization
    func authorize() async throws {
        try await oauthService.signInWithGoogle()
    }

    func signOut() {
        oauthService.signOut()
    }

    var isAuthorized: Bool {
        oauthService.isSignedIn
    }

    // MARK: - List Events
    func listEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        NSLog("GoogleCalendarService: Fetching events from \(startDate) to \(endDate)")

        // First check if we have a token
        guard oauthService.isSignedInWithGoogle else {
            NSLog("GoogleCalendarService: Not signed in with Google!")
            throw GoogleCalendarError.notAuthenticated
        }

        let accessToken = try await oauthService.getValidAccessToken()
        NSLog("GoogleCalendarService: Got access token: \(String(accessToken.prefix(20)))...")

        // Fetch all calendars first
        let calendars = try await listCalendars(accessToken: accessToken)
        NSLog("GoogleCalendarService: Found \(calendars.count) calendars")

        var allEvents: [GoogleEvent] = []

        // Fetch events from ALL calendars
        for calendar in calendars {
            NSLog("GoogleCalendarService: Fetching events from calendar: \(calendar.summary ?? calendar.id)")
            do {
                let calEvents = try await fetchEventsFromCalendar(
                    calendarId: calendar.id,
                    accessToken: accessToken,
                    from: startDate,
                    to: endDate
                )
                NSLog("GoogleCalendarService: Found \(calEvents.count) events in \(calendar.summary ?? calendar.id)")
                allEvents.append(contentsOf: calEvents)
            } catch {
                NSLog("GoogleCalendarService: Error fetching from \(calendar.summary ?? calendar.id): \(error)")
                // Continue with other calendars
            }
        }

        NSLog("GoogleCalendarService: Total events from all calendars: \(allEvents.count)")

        // Convert to CalendarEvent and sort by start date
        let events = allEvents.map { googleEvent in
            CalendarEvent(
                id: googleEvent.id,
                title: googleEvent.summary ?? "Untitled",
                startDate: parseGoogleDateTime(googleEvent.start),
                endDate: parseGoogleDateTime(googleEvent.end),
                calendarType: .google,
                description: googleEvent.description,
                location: googleEvent.location
            )
        }.sorted { $0.startDate < $1.startDate }

        // Log events by date for debugging
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var eventsByDate: [String: Int] = [:]
        for event in events {
            let dateKey = dateFormatter.string(from: event.startDate)
            eventsByDate[dateKey, default: 0] += 1
        }
        NSLog("GoogleCalendarService: Events by date: \(eventsByDate)")

        return events
    }

    // MARK: - Create Event
    func createEvent(_ event: CalendarEvent) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/calendars/primary/events")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let googleEvent = GoogleEventRequest(
            summary: event.title,
            description: event.description,
            location: event.location,
            start: GoogleDateTime(dateTime: formatISO8601(event.startDate), timeZone: TimeZone.current.identifier),
            end: GoogleDateTime(dateTime: formatISO8601(event.endDate), timeZone: TimeZone.current.identifier)
        )

        request.httpBody = try JSONEncoder().encode(googleEvent)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw GoogleCalendarError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Update Event
    func updateEvent(_ event: CalendarEvent) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/calendars/primary/events/\(event.id)")!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let googleEvent = GoogleEventRequest(
            summary: event.title,
            description: event.description,
            location: event.location,
            start: GoogleDateTime(dateTime: formatISO8601(event.startDate), timeZone: TimeZone.current.identifier),
            end: GoogleDateTime(dateTime: formatISO8601(event.endDate), timeZone: TimeZone.current.identifier)
        )

        request.httpBody = try JSONEncoder().encode(googleEvent)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Delete Event
    func deleteEvent(id: String) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/calendars/primary/events/\(id)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - List All Calendars
    private func listCalendars(accessToken: String) async throws -> [GoogleCalendar] {
        let url = URL(string: "\(baseURL)/users/me/calendarList")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        let listResponse = try JSONDecoder().decode(GoogleCalendarListResponse.self, from: data)
        return listResponse.items ?? []
    }

    // MARK: - Fetch Events from Specific Calendar
    private func fetchEventsFromCalendar(calendarId: String, accessToken: String, from startDate: Date, to endDate: Date) async throws -> [GoogleEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timeMin = formatter.string(from: startDate)
        let timeMax = formatter.string(from: endDate)

        // Properly encode the calendar ID
        let encodedCalendarId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId

        var components = URLComponents(string: "\(baseURL)/calendars/\(encodedCalendarId)/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "250") // Increased from 50
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return []
        }

        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                NSLog("GoogleCalendarService: Error fetching calendar \(calendarId): \(errorString)")
            }
            return []
        }

        let eventsResponse = try JSONDecoder().decode(GoogleEventsResponse.self, from: data)
        return eventsResponse.eventItems
    }

    // MARK: - Helpers
    private func parseGoogleDateTime(_ dateTime: GoogleDateTimeResponse) -> Date {
        if let dateTimeStr = dateTime.dateTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: dateTimeStr) ?? Date()
        } else if let dateStr = dateTime.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateStr) ?? Date()
        }
        return Date()
    }

    private func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

// MARK: - API Models
struct GoogleCalendarListResponse: Codable {
    let items: [GoogleCalendar]?
}

struct GoogleCalendar: Codable {
    let id: String
    let summary: String?
    let primary: Bool?
}

struct GoogleEventsResponse: Codable {
    let items: [GoogleEvent]?

    // Handle missing items key
    var eventItems: [GoogleEvent] {
        items ?? []
    }
}

struct GoogleEvent: Codable {
    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let start: GoogleDateTimeResponse
    let end: GoogleDateTimeResponse
}

struct GoogleDateTimeResponse: Codable {
    let dateTime: String?
    let date: String?
    let timeZone: String?
}

struct GoogleEventRequest: Codable {
    let summary: String
    let description: String?
    let location: String?
    let start: GoogleDateTime
    let end: GoogleDateTime
}

struct GoogleDateTime: Codable {
    let dateTime: String
    let timeZone: String
}

// MARK: - Errors
enum GoogleCalendarError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case apiErrorWithMessage(statusCode: Int, message: String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from Google Calendar API"
        case .apiError(let code):
            return "Google Calendar API error: \(code)"
        case .apiErrorWithMessage(let code, let message):
            // Try to extract a readable error
            if let data = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                return "Error \(code): \(errorMessage)"
            }
            return "Error \(code): \(message)"
        case .notAuthenticated:
            return "Not signed in with Google. Please connect Google Calendar in Settings."
        }
    }
}
