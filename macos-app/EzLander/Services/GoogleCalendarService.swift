import Foundation
import os.log

private let logger = Logger(subsystem: "com.ezlander.app", category: "GoogleCalendar")

class GoogleCalendarService {
    static let shared = GoogleCalendarService()

    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let oauthService = OAuthService.shared

    private init() {}

    /// Execute an authenticated request, automatically refreshing the token on 401 and retrying once.
    private func performAuthenticatedRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var req = request
        let (data, httpResponse) = try await APIRetryHelper.performRequest(req)

        guard httpResponse.statusCode == 401 else {
            return (data, httpResponse)
        }

        // Token expired mid-session — refresh and retry once
        #if DEBUG
        NSLog("GoogleCalendarService: Got 401, refreshing token and retrying...")
        #endif
        let newToken = try await oauthService.refreshAccessToken()
        req.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
        return try await APIRetryHelper.performRequest(req, maxRetries: 0)
    }

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
        #if DEBUG
        NSLog("GoogleCalendarService: Fetching events from \(startDate) to \(endDate)")
        #endif

        // First check if we have a token
        guard oauthService.isSignedInWithGoogle else {
            #if DEBUG
            NSLog("GoogleCalendarService: Not signed in with Google!")
            #endif
            throw GoogleCalendarError.notAuthenticated
        }

        let accessToken = try await oauthService.getValidAccessToken()
        #if DEBUG
        NSLog("GoogleCalendarService: Got access token (redacted)")
        #endif

        // Fetch all calendars first
        let calendars = try await listCalendars(accessToken: accessToken)
        #if DEBUG
        NSLog("GoogleCalendarService: Found \(calendars.count) calendars")
        #endif

        var allEvents: [CalendarEvent] = []

        // Fetch events from ALL calendars, converting inside the loop
        for calendar in calendars {
            #if DEBUG
            NSLog("GoogleCalendarService: Fetching events from calendar: \(calendar.summary ?? calendar.id)")
            #endif
            do {
                let calEvents = try await fetchEventsFromCalendar(
                    calendarId: calendar.id,
                    accessToken: accessToken,
                    from: startDate,
                    to: endDate
                )
                #if DEBUG
                NSLog("GoogleCalendarService: Found \(calEvents.count) events in \(calendar.summary ?? calendar.id)")
                #endif

                // Convert GoogleEvent -> CalendarEvent with calendar metadata
                let converted = calEvents.compactMap { googleEvent -> CalendarEvent? in
                    guard googleEvent.status != "cancelled" else { return nil }
                    guard let start = googleEvent.start, let end = googleEvent.end else { return nil }

                    // Build attendees
                    let attendees = googleEvent.attendees?.map { ga -> EventAttendee in
                        EventAttendee(
                            email: ga.email,
                            displayName: ga.displayName,
                            responseStatus: EventAttendee.ResponseStatus(rawValue: ga.responseStatus ?? "needsAction") ?? .needsAction,
                            isOrganizer: ga.organizer ?? false,
                            isSelf: ga.self_ ?? false
                        )
                    }

                    // Build organizer
                    var organizerAttendee: EventAttendee?
                    if let org = googleEvent.organizer {
                        organizerAttendee = EventAttendee(
                            email: org.email ?? "",
                            displayName: org.displayName,
                            responseStatus: .accepted,
                            isOrganizer: true,
                            isSelf: org.self_ ?? false
                        )
                    }

                    // Build conference data
                    var confData: ConferenceData?
                    if let gc = googleEvent.conferenceData {
                        let solution = gc.conferenceSolution.map {
                            ConferenceSolution(name: $0.name, iconUri: $0.iconUri)
                        }
                        let entryPoints = gc.entryPoints?.map {
                            ConferenceEntryPoint(entryPointType: $0.entryPointType, uri: $0.uri, label: $0.label)
                        }
                        confData = ConferenceData(
                            conferenceId: gc.conferenceId,
                            conferenceSolution: solution,
                            entryPoints: entryPoints
                        )
                    }

                    // Determine meeting link (priority: hangoutLink > conferenceData > description > location)
                    var meetingLink: URL?
                    if let hangout = googleEvent.hangoutLink, let url = URL(string: hangout) {
                        meetingLink = url
                    }
                    // conferenceData joinURL and description/location regex are handled by effectiveJoinURL computed property

                    return CalendarEvent(
                        id: googleEvent.id,
                        title: googleEvent.summary ?? "Untitled",
                        startDate: parseGoogleDateTime(start),
                        endDate: parseGoogleDateTime(end),
                        calendarType: .google,
                        description: googleEvent.description,
                        location: googleEvent.location,
                        isAllDay: isAllDayEvent(googleEvent),
                        attendees: attendees,
                        meetingLink: meetingLink,
                        organizer: organizerAttendee,
                        calendarColor: calendar.backgroundColor,
                        calendarName: calendar.summary,
                        googleCalendarId: calendar.id,
                        conferenceData: confData,
                        htmlLink: googleEvent.htmlLink
                    )
                }

                allEvents.append(contentsOf: converted)
            } catch {
                #if DEBUG
                NSLog("GoogleCalendarService: Error fetching from \(calendar.summary ?? calendar.id): \(error)")
                #endif
                // Continue with other calendars
            }
        }

        #if DEBUG
        NSLog("GoogleCalendarService: Total events from all calendars: \(allEvents.count)")
        #endif

        let sortedEvents = allEvents.sorted { $0.startDate < $1.startDate }

        #if DEBUG
        // Log events by date for debugging
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var eventsByDate: [String: Int] = [:]
        for event in sortedEvents {
            let dateKey = dateFormatter.string(from: event.startDate)
            eventsByDate[dateKey, default: 0] += 1
        }
        NSLog("GoogleCalendarService: Events by date: \(eventsByDate)")
        #endif

        return sortedEvents
    }

    // MARK: - Create Event
    func createEvent(_ event: CalendarEvent) async throws {
        #if DEBUG
        NSLog("GoogleCalendarService: Creating event '\(event.title)' from \(event.startDate) to \(event.endDate)")
        #endif

        guard oauthService.isSignedInWithGoogle else {
            #if DEBUG
            NSLog("GoogleCalendarService: Not signed in with Google!")
            #endif
            throw GoogleCalendarError.notAuthenticated
        }

        let accessToken = try await oauthService.getValidAccessToken()

        var conferenceDataForCreate: Int? = nil
        // Check if we should request conference data creation
        if event.conferenceData != nil || event.meetingLink != nil {
            conferenceDataForCreate = 1
        }

        let url: URL
        if conferenceDataForCreate != nil {
            var components = URLComponents(string: "\(baseURL)/calendars/primary/events")!
            components.queryItems = [
                URLQueryItem(name: "conferenceDataVersion", value: "1")
            ]
            url = components.url!
        } else {
            url = URL(string: "\(baseURL)/calendars/primary/events")!
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let googleEvent = GoogleEventRequest(
            summary: event.title,
            description: event.description,
            location: event.location,
            start: GoogleDateTime(dateTime: formatISO8601(event.startDate), timeZone: TimeZone.current.identifier),
            end: GoogleDateTime(dateTime: formatISO8601(event.endDate), timeZone: TimeZone.current.identifier),
            attendees: event.attendees?.map { GoogleAttendeeRequest(email: $0.email) },
            conferenceData: conferenceDataForCreate != nil ? GoogleConferenceDataRequest(
                createRequest: GoogleCreateConferenceRequest(
                    requestId: UUID().uuidString,
                    conferenceSolutionKey: GoogleConferenceSolutionKey(type: "hangoutsMeet")
                )
            ) : nil
        )

        request.httpBody = try JSONEncoder().encode(googleEvent)

        #if DEBUG
        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            NSLog("GoogleCalendarService: Request body: \(bodyString)")
        }
        #endif

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let message = APIRetryHelper.userFriendlyMessage(statusCode: httpResponse.statusCode, data: data)
            throw GoogleCalendarError.apiErrorWithMessage(statusCode: httpResponse.statusCode, message: message)
        }

        #if DEBUG
        NSLog("GoogleCalendarService: Event created successfully")
        #endif
    }

    // MARK: - Update Event
    func updateEvent(_ event: CalendarEvent) async throws {
        #if DEBUG
        NSLog("GoogleCalendarService: Updating event '\(event.title)' (\(event.id))")
        #endif

        let accessToken = try await oauthService.getValidAccessToken()

        let calendarId = (event.googleCalendarId ?? "primary")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "primary"
        let url = URL(string: "\(baseURL)/calendars/\(calendarId)/events/\(event.id)")!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let googleEvent = GoogleEventRequest(
            summary: event.title,
            description: event.description,
            location: event.location,
            start: GoogleDateTime(dateTime: formatISO8601(event.startDate), timeZone: TimeZone.current.identifier),
            end: GoogleDateTime(dateTime: formatISO8601(event.endDate), timeZone: TimeZone.current.identifier),
            attendees: event.attendees?.map { GoogleAttendeeRequest(email: $0.email) },
            conferenceData: nil
        )

        request.httpBody = try JSONEncoder().encode(googleEvent)

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            let message = APIRetryHelper.userFriendlyMessage(statusCode: httpResponse.statusCode, data: data)
            throw GoogleCalendarError.apiErrorWithMessage(statusCode: httpResponse.statusCode, message: message)
        }

        #if DEBUG
        NSLog("GoogleCalendarService: Event updated successfully")
        #endif
    }

    // MARK: - Delete Event
    func deleteEvent(id: String) async throws {
        try await deleteEvent(id: id, calendarId: nil)
    }

    func deleteEvent(id: String, calendarId: String?) async throws {
        #if DEBUG
        NSLog("GoogleCalendarService: Deleting event \(id)")
        #endif

        let accessToken = try await oauthService.getValidAccessToken()

        let resolvedCalendarId = (calendarId ?? "primary")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "primary"
        let url = URL(string: "\(baseURL)/calendars/\(resolvedCalendarId)/events/\(id)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            let message = APIRetryHelper.userFriendlyMessage(statusCode: httpResponse.statusCode, data: data)
            throw GoogleCalendarError.apiErrorWithMessage(statusCode: httpResponse.statusCode, message: message)
        }

        #if DEBUG
        NSLog("GoogleCalendarService: Event deleted successfully")
        #endif
    }

    // MARK: - List All Calendars
    private func listCalendars(accessToken: String) async throws -> [GoogleCalendar] {
        let url = URL(string: "\(baseURL)/users/me/calendarList")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
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
            URLQueryItem(name: "maxResults", value: "250")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                #if DEBUG
                NSLog("GoogleCalendarService: Error fetching calendar \(calendarId): \(errorString)")
                #endif
            }
            return []
        }

        let eventsResponse = try JSONDecoder().decode(GoogleEventsResponse.self, from: data)
        return eventsResponse.eventItems
    }

    // MARK: - Helpers
    private func parseGoogleDateTime(_ dateTime: GoogleDateTimeResponse) -> Date {
        if let dateTimeStr = dateTime.dateTime {
            // Try with fractional seconds first, then without
            let formatterWithFrac = ISO8601DateFormatter()
            formatterWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFrac.date(from: dateTimeStr) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateTimeStr) {
                return date
            }

            #if DEBUG
            NSLog("GoogleCalendarService: Failed to parse dateTime: \(dateTimeStr)")
            #endif
            return Date()
        } else if let dateStr = dateTime.date {
            // All-day events: "2026-02-17" — parse in local timezone
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone.current
            return formatter.date(from: dateStr) ?? Date()
        }
        return Date()
    }

    private func isAllDayEvent(_ event: GoogleEvent) -> Bool {
        return event.start?.date != nil && event.start?.dateTime == nil
    }

    private func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

// MARK: - API Response Models

struct GoogleCalendarListResponse: Codable {
    let items: [GoogleCalendar]?
}

struct GoogleCalendar: Codable {
    let id: String
    let summary: String?
    let primary: Bool?
    let backgroundColor: String?
    let foregroundColor: String?
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
    let start: GoogleDateTimeResponse?
    let end: GoogleDateTimeResponse?
    let status: String?
    let attendees: [GoogleAttendee]?
    let hangoutLink: String?
    let conferenceData: GoogleConferenceData?
    let htmlLink: String?
    let creator: GooglePerson?
    let organizer: GooglePerson?
    let colorId: String?
}

struct GoogleAttendee: Codable {
    let email: String
    let displayName: String?
    let responseStatus: String?
    let organizer: Bool?
    let self_: Bool?

    enum CodingKeys: String, CodingKey {
        case email, displayName, responseStatus, organizer
        case self_ = "self"
    }
}

struct GooglePerson: Codable {
    let email: String?
    let displayName: String?
    let self_: Bool?

    enum CodingKeys: String, CodingKey {
        case email, displayName
        case self_ = "self"
    }
}

struct GoogleConferenceData: Codable {
    let conferenceId: String?
    let conferenceSolution: GoogleConferenceSolution?
    let entryPoints: [GoogleConferenceEntryPoint]?
}

struct GoogleConferenceSolution: Codable {
    let name: String?
    let iconUri: String?
}

struct GoogleConferenceEntryPoint: Codable {
    let entryPointType: String?
    let uri: String?
    let label: String?
}

struct GoogleDateTimeResponse: Codable {
    let dateTime: String?
    let date: String?
    let timeZone: String?
}

// MARK: - API Request Models

struct GoogleEventRequest: Codable {
    let summary: String
    let description: String?
    let location: String?
    let start: GoogleDateTime
    let end: GoogleDateTime
    let attendees: [GoogleAttendeeRequest]?
    let conferenceData: GoogleConferenceDataRequest?
}

struct GoogleAttendeeRequest: Codable {
    let email: String
}

struct GoogleConferenceDataRequest: Codable {
    let createRequest: GoogleCreateConferenceRequest
}

struct GoogleCreateConferenceRequest: Codable {
    let requestId: String
    let conferenceSolutionKey: GoogleConferenceSolutionKey
}

struct GoogleConferenceSolutionKey: Codable {
    let type: String
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
