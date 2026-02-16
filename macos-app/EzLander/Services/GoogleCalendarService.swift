import Foundation

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
        let accessToken = try await oauthService.getValidAccessToken()

        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startDate)
        let timeMax = formatter.string(from: endDate)

        let urlString = "\(baseURL)/calendars/primary/events?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=true&orderBy=startTime"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else {
            throw GoogleCalendarError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.apiError(statusCode: httpResponse.statusCode)
        }

        let eventsResponse = try JSONDecoder().decode(GoogleEventsResponse.self, from: data)

        return eventsResponse.items.map { googleEvent in
            CalendarEvent(
                id: googleEvent.id,
                title: googleEvent.summary ?? "Untitled",
                startDate: parseGoogleDateTime(googleEvent.start),
                endDate: parseGoogleDateTime(googleEvent.end),
                calendarType: .google,
                description: googleEvent.description,
                location: googleEvent.location
            )
        }
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
struct GoogleEventsResponse: Codable {
    let items: [GoogleEvent]
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

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from Google Calendar API"
        case .apiError(let code):
            return "Google Calendar API error: \(code)"
        }
    }
}
