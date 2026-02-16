import Foundation

class GmailService {
    static let shared = GmailService()

    private let baseURL = "https://www.googleapis.com/gmail/v1"
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

    // MARK: - Send Email
    func sendEmail(_ email: Email) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/messages/send")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build RFC 2822 message
        let rawMessage = buildRawMessage(email)
        let encodedMessage = rawMessage.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let body: [String: Any] = ["raw": encodedMessage]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Create Draft
    func createDraft(_ email: Email) async throws -> String {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/drafts")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let rawMessage = buildRawMessage(email)
        let encodedMessage = rawMessage.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let body: [String: Any] = [
            "message": ["raw": encodedMessage]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }

        let draftResponse = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return draftResponse["id"] as? String ?? ""
    }

    // MARK: - Search Emails
    func searchEmails(query: String, maxResults: Int = 10) async throws -> [Email] {
        let accessToken = try await oauthService.getValidAccessToken()

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "\(baseURL)/users/me/messages?q=\(encodedQuery)&maxResults=\(maxResults)")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }

        let listResponse = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let messages = listResponse["messages"] as? [[String: Any]] else {
            return []
        }

        // Fetch full message details for each
        var emails: [Email] = []
        for message in messages.prefix(maxResults) {
            if let messageId = message["id"] as? String {
                if let email = try? await getEmail(id: messageId) {
                    emails.append(email)
                }
            }
        }

        return emails
    }

    // MARK: - Get Email
    func getEmail(id: String) async throws -> Email {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/messages/\(id)?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Date")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }

        let messageResponse = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return parseEmailFromResponse(messageResponse)
    }

    // MARK: - List Recent Emails
    func listRecentEmails(maxResults: Int = 10) async throws -> [Email] {
        return try await searchEmails(query: "in:inbox", maxResults: maxResults)
    }

    // MARK: - Helpers
    private func buildRawMessage(_ email: Email) -> String {
        let userEmail = UserDefaults.standard.string(forKey: "user_email") ?? ""
        let userName = UserDefaults.standard.string(forKey: "user_name") ?? ""

        var message = ""
        message += "From: \(userName) <\(userEmail)>\r\n"
        message += "To: \(email.to)\r\n"
        message += "Subject: \(email.subject)\r\n"
        message += "MIME-Version: 1.0\r\n"
        message += "Content-Type: text/plain; charset=\"UTF-8\"\r\n"
        message += "\r\n"
        message += email.body

        return message
    }

    private func parseEmailFromResponse(_ response: [String: Any]) -> Email {
        let id = response["id"] as? String ?? ""

        var subject = ""
        var from: String?
        var to = ""
        var date = Date()

        if let payload = response["payload"] as? [String: Any],
           let headers = payload["headers"] as? [[String: Any]] {
            for header in headers {
                let name = header["name"] as? String ?? ""
                let value = header["value"] as? String ?? ""

                switch name.lowercased() {
                case "subject":
                    subject = value
                case "from":
                    from = value
                case "to":
                    to = value
                case "date":
                    date = parseEmailDate(value)
                default:
                    break
                }
            }
        }

        return Email(
            id: id,
            to: to,
            from: from,
            subject: subject,
            body: "",
            date: date
        )
    }

    private func parseEmailDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Errors
enum GmailError: Error, LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int)
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Gmail API"
        case .apiError(let code):
            return "Gmail API error: \(code)"
        case .notAuthorized:
            return "Gmail access not authorized"
        }
    }
}
