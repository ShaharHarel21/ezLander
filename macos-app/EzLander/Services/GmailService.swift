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
    func listRecentEmails(maxResults: Int = 20) async throws -> [Email] {
        return try await searchEmails(query: "in:inbox", maxResults: maxResults)
    }

    // MARK: - Get Full Email with Body
    func getFullEmail(id: String) async throws -> Email {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/messages/\(id)?format=full")!

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
        return parseFullEmailFromResponse(messageResponse)
    }

    // MARK: - Get Full Email with HTML
    func getFullEmailWithHtml(id: String) async throws -> (plain: String, html: String?) {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/messages/\(id)?format=full")!

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

        if let payload = messageResponse["payload"] as? [String: Any] {
            let (plain, html) = extractBothBodiesFromPayload(payload)
            return (plain, html)
        }

        return ("", nil)
    }

    // MARK: - Delete Email (Move to Trash)
    func deleteEmail(id: String) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/messages/\(id)/trash")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Archive Email (Remove from Inbox)
    func archiveEmail(id: String) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/messages/\(id)/modify")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["removeLabelIds": ["INBOX"]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Mark as Read
    func markAsRead(id: String) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/messages/\(id)/modify")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["removeLabelIds": ["UNREAD"]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Mark as Unread
    func markAsUnread(id: String) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/messages/\(id)/modify")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["addLabelIds": ["UNREAD"]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - List Labels
    func listLabels() async throws -> [GmailLabel] {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/labels")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }

        let labelsResponse = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let labels = labelsResponse["labels"] as? [[String: Any]] else {
            return []
        }

        return labels.compactMap { label in
            guard let id = label["id"] as? String,
                  let name = label["name"] as? String,
                  let type = label["type"] as? String else { return nil }
            return GmailLabel(id: id, name: name, type: type)
        }
    }

    // MARK: - Move Email to Label
    func moveEmail(id: String, addLabelIds: [String], removeLabelIds: [String]) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/users/me/messages/\(id)/modify")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]
        if !addLabelIds.isEmpty {
            body["addLabelIds"] = addLabelIds
        }
        if !removeLabelIds.isEmpty {
            body["removeLabelIds"] = removeLabelIds
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GmailError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Reply to Email
    func replyToEmail(originalEmail: Email, replyBody: String) async throws {
        let accessToken = try await oauthService.getValidAccessToken()

        NSLog("GmailService: Starting reply to email ID: \(originalEmail.id)")
        NSLog("GmailService: Original email from: \(originalEmail.from ?? "nil")")
        NSLog("GmailService: Original email threadId: \(originalEmail.threadId ?? "nil")")

        // First, get the Message-ID header from the original email
        let messageId = try await getMessageIdHeader(emailId: originalEmail.id, accessToken: accessToken)
        NSLog("GmailService: Got Message-ID header: \(messageId ?? "nil")")

        let url = URL(string: "\(baseURL)/users/me/messages/send")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let rawMessage = try buildReplyMessage(originalEmail: originalEmail, replyBody: replyBody, messageId: messageId)
        NSLog("GmailService: Built reply message, length: \(rawMessage.count)")
        NSLog("GmailService: Raw message preview:\n\(String(rawMessage.prefix(500)))")

        let encodedMessage = rawMessage.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // Try with threadId first, then without if it fails
        var body: [String: Any] = ["raw": encodedMessage]
        let hasThreadId = originalEmail.threadId != nil
        if let threadId = originalEmail.threadId {
            body["threadId"] = threadId
            NSLog("GmailService: Including threadId: \(threadId)")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var (data, response) = try await URLSession.shared.data(for: request)

        guard var httpResponse = response as? HTTPURLResponse else {
            throw GmailError.invalidResponse
        }

        // If 404 with threadId, retry without it (thread may have been deleted)
        if httpResponse.statusCode == 404 && hasThreadId {
            NSLog("GmailService: Got 404 with threadId, retrying without threadId...")
            body.removeValue(forKey: "threadId")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            (data, response) = try await URLSession.shared.data(for: request)
            httpResponse = response as! HTTPURLResponse
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            NSLog("GmailService: Reply failed with status \(httpResponse.statusCode): \(errorBody)")
            throw GmailError.apiErrorWithMessage(statusCode: httpResponse.statusCode, message: errorBody)
        }

        NSLog("GmailService: Reply sent successfully")
    }

    private func getMessageIdHeader(emailId: String, accessToken: String) async throws -> String? {
        let url = URL(string: "\(baseURL)/users/me/messages/\(emailId)?format=metadata&metadataHeaders=Message-ID")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let payload = json["payload"] as? [String: Any],
           let headers = payload["headers"] as? [[String: Any]] {
            for header in headers {
                if let name = header["name"] as? String, name.lowercased() == "message-id",
                   let value = header["value"] as? String {
                    return value
                }
            }
        }

        return nil
    }

    // MARK: - Helpers
    private func buildReplyMessage(originalEmail: Email, replyBody: String, messageId: String?) throws -> String {
        // Get user email from OAuth or UserDefaults - MUST exist
        guard let userEmail = OAuthService.shared.userEmail ?? UserDefaults.standard.string(forKey: "user_email"),
              !userEmail.isEmpty else {
            NSLog("GmailService: ERROR - No user email found, cannot send reply")
            throw GmailError.notAuthorized
        }

        // Get the sender's email - MUST exist to reply
        guard let replyToFull = originalEmail.from, !replyToFull.isEmpty else {
            NSLog("GmailService: ERROR - Original email has no 'from' field, cannot reply")
            throw GmailError.invalidResponse
        }

        let userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        let replyToEmail = extractEmailAddress(from: replyToFull)

        NSLog("GmailService: Building reply - From: \(userEmail), To: \(replyToEmail)")

        let subject = originalEmail.subject.hasPrefix("Re:") ? originalEmail.subject : "Re: \(originalEmail.subject)"

        var message = ""
        if !userName.isEmpty {
            message += "From: \(userName) <\(userEmail)>\r\n"
        } else {
            message += "From: \(userEmail)\r\n"
        }
        message += "To: \(replyToEmail)\r\n"
        message += "Subject: \(subject)\r\n"

        // Add threading headers if we have the message ID
        if let msgId = messageId {
            message += "In-Reply-To: \(msgId)\r\n"
            message += "References: \(msgId)\r\n"
        }

        message += "MIME-Version: 1.0\r\n"
        message += "Content-Type: text/plain; charset=\"UTF-8\"\r\n"
        message += "\r\n"
        message += replyBody

        return message
    }

    private func extractEmailAddress(from string: String) -> String {
        // Handle "Name <email@example.com>" format
        if let start = string.firstIndex(of: "<"),
           let end = string.firstIndex(of: ">") {
            let emailStart = string.index(after: start)
            return String(string[emailStart..<end])
        }
        // Already just an email
        return string.trimmingCharacters(in: .whitespaces)
    }

    private func parseFullEmailFromResponse(_ response: [String: Any]) -> Email {
        let id = response["id"] as? String ?? ""
        let threadId = response["threadId"] as? String
        let labelIds = response["labelIds"] as? [String] ?? []

        var subject = ""
        var from: String?
        var to = ""
        var date = Date()
        var body = ""

        if let payload = response["payload"] as? [String: Any] {
            // Parse headers
            if let headers = payload["headers"] as? [[String: Any]] {
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

            // Parse body
            body = extractBodyFromPayload(payload)
        }

        return Email(
            id: id,
            to: to,
            from: from,
            subject: subject,
            body: body,
            date: date,
            isRead: !labelIds.contains("UNREAD"),
            labels: labelIds,
            threadId: threadId
        )
    }

    private func extractBodyFromPayload(_ payload: [String: Any]) -> String {
        // Check for direct body data
        if let body = payload["body"] as? [String: Any],
           let data = body["data"] as? String {
            return decodeBase64URL(data)
        }

        // Check parts for multipart messages
        if let parts = payload["parts"] as? [[String: Any]] {
            for part in parts {
                let mimeType = part["mimeType"] as? String ?? ""

                // Prefer text/plain
                if mimeType == "text/plain" {
                    if let body = part["body"] as? [String: Any],
                       let data = body["data"] as? String {
                        return decodeBase64URL(data)
                    }
                }

                // Recursively check nested parts
                if let nestedParts = part["parts"] as? [[String: Any]] {
                    let result = extractBodyFromPayload(["parts": nestedParts])
                    if !result.isEmpty {
                        return result
                    }
                }
            }

            // Fall back to text/html if no plain text
            for part in parts {
                let mimeType = part["mimeType"] as? String ?? ""
                if mimeType == "text/html" {
                    if let body = part["body"] as? [String: Any],
                       let data = body["data"] as? String {
                        let html = decodeBase64URL(data)
                        return stripHTML(html)
                    }
                }
            }
        }

        return ""
    }

    private func extractBothBodiesFromPayload(_ payload: [String: Any]) -> (plain: String, html: String?) {
        var plainText: String?
        var htmlText: String?

        // Check for direct body data (single part)
        if let mimeType = payload["mimeType"] as? String {
            if let body = payload["body"] as? [String: Any],
               let data = body["data"] as? String {
                let decoded = decodeBase64URL(data)
                if mimeType == "text/plain" {
                    plainText = decoded
                } else if mimeType == "text/html" {
                    htmlText = decoded
                }
            }
        }

        // Check parts for multipart messages
        if let parts = payload["parts"] as? [[String: Any]] {
            for part in parts {
                let mimeType = part["mimeType"] as? String ?? ""

                if mimeType == "text/plain" {
                    if let body = part["body"] as? [String: Any],
                       let data = body["data"] as? String {
                        plainText = decodeBase64URL(data)
                    }
                } else if mimeType == "text/html" {
                    if let body = part["body"] as? [String: Any],
                       let data = body["data"] as? String {
                        htmlText = decodeBase64URL(data)
                    }
                } else if mimeType.hasPrefix("multipart/") {
                    // Recursively check nested parts
                    if let nestedParts = part["parts"] as? [[String: Any]] {
                        let (nestedPlain, nestedHtml) = extractBothBodiesFromPayload(["parts": nestedParts])
                        if plainText == nil && !nestedPlain.isEmpty {
                            plainText = nestedPlain
                        }
                        if htmlText == nil && nestedHtml != nil {
                            htmlText = nestedHtml
                        }
                    }
                }
            }
        }

        // If we only have HTML, create plain text version
        let finalPlain = plainText ?? (htmlText != nil ? stripHTML(htmlText!) : "")

        return (finalPlain, htmlText)
    }

    private func decodeBase64URL(_ string: String) -> String {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }

        guard let data = Data(base64Encoded: base64),
              let decoded = String(data: data, encoding: .utf8) else {
            return ""
        }
        return decoded
    }

    private func stripHTML(_ html: String) -> String {
        var text = html
        // Remove script and style tags with content
        text = text.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        // Replace br and p tags with newlines
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
        // Remove all other tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        // Clean up extra whitespace
        text = text.replacingOccurrences(of: "\n\\s*\n\\s*\n", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
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
        let threadId = response["threadId"] as? String
        let labelIds = response["labelIds"] as? [String] ?? []

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
            date: date,
            isRead: !labelIds.contains("UNREAD"),
            labels: labelIds,
            threadId: threadId
        )
    }

    private func parseEmailDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Gmail Label
struct GmailLabel: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String

    var displayName: String {
        // Clean up system label names
        switch id {
        case "INBOX": return "Inbox"
        case "STARRED": return "Starred"
        case "IMPORTANT": return "Important"
        case "SENT": return "Sent"
        case "DRAFT": return "Drafts"
        case "SPAM": return "Spam"
        case "TRASH": return "Trash"
        case "UNREAD": return "Unread"
        case "CATEGORY_PERSONAL": return "Personal"
        case "CATEGORY_SOCIAL": return "Social"
        case "CATEGORY_PROMOTIONS": return "Promotions"
        case "CATEGORY_UPDATES": return "Updates"
        case "CATEGORY_FORUMS": return "Forums"
        default: return name
        }
    }

    var icon: String {
        switch id {
        case "INBOX": return "tray"
        case "STARRED": return "star"
        case "IMPORTANT": return "exclamationmark.circle"
        case "SENT": return "paperplane"
        case "DRAFT": return "doc.text"
        case "SPAM": return "xmark.bin"
        case "TRASH": return "trash"
        default: return "folder"
        }
    }

    /// Labels that make sense as move targets
    var isMoveTarget: Bool {
        // Exclude non-movable system labels
        let excluded = ["UNREAD", "SENT", "DRAFT", "CATEGORY_PERSONAL",
                        "CATEGORY_SOCIAL", "CATEGORY_PROMOTIONS",
                        "CATEGORY_UPDATES", "CATEGORY_FORUMS"]
        return !excluded.contains(id)
    }
}

// MARK: - Errors
enum GmailError: Error, LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int)
    case apiErrorWithMessage(statusCode: Int, message: String)
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Gmail API"
        case .apiError(let code):
            return "Gmail API error: \(code)"
        case .apiErrorWithMessage(let code, let message):
            // Try to parse JSON error
            if let data = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                return "Gmail error: \(errorMessage)"
            }
            return "Gmail API error \(code): \(message)"
        case .notAuthorized:
            return "Gmail access not authorized"
        }
    }
}
