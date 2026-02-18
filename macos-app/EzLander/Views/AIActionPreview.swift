import SwiftUI

// MARK: - AI Action Types
enum AIActionType: String, Codable {
    case createEvent = "create_event"
    case updateEvent = "update_event"
    case deleteEvent = "delete_event"
    case sendEmail = "send_email"
    case draftEmail = "draft_email"

    var icon: String {
        switch self {
        case .createEvent: return "calendar.badge.plus"
        case .updateEvent: return "calendar.badge.clock"
        case .deleteEvent: return "calendar.badge.minus"
        case .sendEmail: return "envelope.arrow.triangle.branch"
        case .draftEmail: return "envelope.badge.person.crop"
        }
    }

    var title: String {
        switch self {
        case .createEvent: return "Create Event"
        case .updateEvent: return "Update Event"
        case .deleteEvent: return "Delete Event"
        case .sendEmail: return "Send Email"
        case .draftEmail: return "Draft Email"
        }
    }

    var confirmText: String {
        switch self {
        case .createEvent: return "Create"
        case .updateEvent: return "Update"
        case .deleteEvent: return "Delete"
        case .sendEmail: return "Send"
        case .draftEmail: return "Save Draft"
        }
    }

    var isDestructive: Bool {
        self == .deleteEvent
    }
}

// MARK: - AI Action
struct AIAction: Identifiable, Codable {
    let id: UUID
    let type: AIActionType
    let eventData: EventActionData?
    let emailData: EmailActionData?
    let summary: String

    init(id: UUID = UUID(), type: AIActionType, eventData: EventActionData? = nil, emailData: EmailActionData? = nil, summary: String) {
        self.id = id
        self.type = type
        self.eventData = eventData
        self.emailData = emailData
        self.summary = summary
    }
}

struct EventActionData: Codable {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let description: String?
}

struct EmailActionData: Codable {
    let to: String
    let subject: String
    let body: String
}

// MARK: - AI Action Preview Card
struct AIActionPreviewCard: View {
    let action: AIAction
    let onConfirm: () -> Void
    let onDecline: () -> Void
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: action.type.icon)
                    .font(.title3)
                    .foregroundColor(.warmAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.type.title)
                        .font(.headline)
                    Text(action.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Content based on action type
            actionContent

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    onDecline()
                }) {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)

                Button(action: {
                    isProcessing = true
                    onConfirm()
                }) {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(action.type.confirmText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(action.type.isDestructive ? .red : .warmPrimary)
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.warmPrimary.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionContent: some View {
        switch action.type {
        case .createEvent, .updateEvent:
            if let eventData = action.eventData {
                eventPreview(eventData)
            }
        case .deleteEvent:
            if let eventData = action.eventData {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event to delete:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(eventData.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
            }
        case .sendEmail, .draftEmail:
            if let emailData = action.emailData {
                emailPreview(emailData)
            }
        }
    }

    private func eventPreview(_ data: EventActionData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Title") {
                Text(data.title)
                    .fontWeight(.medium)
            }

            LabeledContent("When") {
                VStack(alignment: .trailing) {
                    Text(formatDate(data.startDate))
                    Text(formatTime(data.startDate) + " - " + formatTime(data.endDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let location = data.location, !location.isEmpty {
                LabeledContent("Where") {
                    Text(location)
                }
            }

            if let description = data.description, !description.isEmpty {
                LabeledContent("Notes") {
                    Text(description)
                        .lineLimit(2)
                }
            }
        }
        .font(.subheadline)
    }

    private func emailPreview(_ data: EmailActionData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("To") {
                Text(data.to)
                    .fontWeight(.medium)
            }

            LabeledContent("Subject") {
                Text(data.subject)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(data.body)
                    .font(.subheadline)
                    .lineLimit(4)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
        }
        .font(.subheadline)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Action Result View
struct AIActionResultView: View {
    let success: Bool
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(success ? .green : .red)

            Text(message)
                .font(.subheadline)

            Spacer()
        }
        .padding()
        .background(success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 20) {
        AIActionPreviewCard(
            action: AIAction(
                type: .createEvent,
                eventData: EventActionData(
                    title: "Team Meeting",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3600),
                    location: "Conference Room A",
                    description: "Weekly sync with the team"
                ),
                summary: "Creating a new calendar event"
            ),
            onConfirm: {},
            onDecline: {}
        )

        AIActionPreviewCard(
            action: AIAction(
                type: .sendEmail,
                emailData: EmailActionData(
                    to: "john@example.com",
                    subject: "Meeting Follow-up",
                    body: "Hi John,\n\nThank you for the meeting today. Here are the action items we discussed..."
                ),
                summary: "Sending follow-up email"
            ),
            onConfirm: {},
            onDecline: {}
        )
    }
    .padding()
    .frame(width: 380)
}
