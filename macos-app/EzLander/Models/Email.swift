import Foundation

struct Email: Identifiable, Codable {
    let id: String
    var to: String
    var from: String?
    var subject: String
    var body: String
    var date: Date
    var isRead: Bool = false
    var labels: [String] = []
    var threadId: String?
    var attachments: [Attachment] = []

    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        }
        return formatter.string(from: date)
    }

    var snippet: String {
        String(body.prefix(100)).replacingOccurrences(of: "\n", with: " ")
    }

    var senderName: String {
        guard let from = from else { return "Unknown" }
        // Parse "Name <email>" format
        if let nameEnd = from.firstIndex(of: "<") {
            return String(from[..<nameEnd]).trimmingCharacters(in: .whitespaces)
        }
        return from
    }

    var senderEmail: String {
        guard let from = from else { return "" }
        // Parse "Name <email>" format
        if let start = from.firstIndex(of: "<"),
           let end = from.firstIndex(of: ">") {
            return String(from[from.index(after: start)..<end])
        }
        return from
    }
}

// MARK: - Attachment
struct Attachment: Identifiable, Codable {
    let id: String
    let filename: String
    let mimeType: String
    let size: Int

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var icon: String {
        switch mimeType {
        case _ where mimeType.contains("image"):
            return "photo"
        case _ where mimeType.contains("pdf"):
            return "doc.fill"
        case _ where mimeType.contains("zip") || mimeType.contains("compressed"):
            return "doc.zipper"
        case _ where mimeType.contains("spreadsheet") || mimeType.contains("excel"):
            return "tablecells"
        case _ where mimeType.contains("presentation") || mimeType.contains("powerpoint"):
            return "rectangle.on.rectangle"
        default:
            return "doc"
        }
    }
}

// MARK: - Email Draft
struct EmailDraft: Identifiable {
    let id: String
    var to: String
    var subject: String
    var body: String
    var createdAt: Date

    init(to: String = "", subject: String = "", body: String = "") {
        self.id = UUID().uuidString
        self.to = to
        self.subject = subject
        self.body = body
        self.createdAt = Date()
    }

    func toEmail() -> Email {
        Email(
            id: id,
            to: to,
            subject: subject,
            body: body,
            date: Date()
        )
    }
}
