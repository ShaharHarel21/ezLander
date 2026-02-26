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
    let onConfirm: (AIAction) -> Void
    let onDecline: () -> Void
    @State private var isProcessing = false
    @State private var isEditing = false

    // Editable event fields
    @State private var editableEventTitle: String = ""
    @State private var editableEventLocation: String = ""
    @State private var editableEventDescription: String = ""

    // Editable email fields
    @State private var editableEmailTo: String = ""
    @State private var editableEmailSubject: String = ""
    @State private var editableEmailBody: String = ""

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
            HStack(spacing: 8) {
                Button(action: { onDecline() }) {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.red.opacity(0.25), lineWidth: 0.5))
                )
                .disabled(isProcessing)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isEditing.toggle()
                    }
                }) {
                    Label(isEditing ? "Done" : "Edit",
                          systemImage: isEditing ? "checkmark" : "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)

                Button(action: {
                    isProcessing = true
                    onConfirm(buildEditedAction())
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
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 18).fill(Color.warmAccent.opacity(0.06))
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [Color.warmPrimary.opacity(0.30), Color.warmAccent.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            }
            .shadow(color: Color.warmPrimary.opacity(0.15), radius: 16, x: 0, y: 4)
        )
        .onAppear {
            if let e = action.eventData {
                editableEventTitle = e.title
                editableEventLocation = e.location ?? ""
                editableEventDescription = e.description ?? ""
            }
            if let m = action.emailData {
                editableEmailTo = m.to
                editableEmailSubject = m.subject
                editableEmailBody = m.body
            }
        }
    }

    // Builds a new AIAction from the current (possibly edited) field values
    private func buildEditedAction() -> AIAction {
        let newEventData = action.eventData.map { original in
            EventActionData(
                title: editableEventTitle.isEmpty ? original.title : editableEventTitle,
                startDate: original.startDate,
                endDate: original.endDate,
                location: editableEventLocation.isEmpty ? nil : editableEventLocation,
                description: editableEventDescription.isEmpty ? nil : editableEventDescription
            )
        }
        let newEmailData = action.emailData.map { _ in
            EmailActionData(
                to: editableEmailTo,
                subject: editableEmailSubject,
                body: editableEmailBody
            )
        }
        return AIAction(
            id: action.id,
            type: action.type,
            eventData: newEventData,
            emailData: newEmailData,
            summary: action.summary
        )
    }

    @ViewBuilder
    private var actionContent: some View {
        switch action.type {
        case .createEvent, .updateEvent:
            if action.eventData != nil {
                eventPreview
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
            if action.emailData != nil {
                emailPreview
            }
        }
    }

    private var eventPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Title") {
                if isEditing {
                    TextField("Title", text: $editableEventTitle)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(editableEventTitle)
                        .fontWeight(.medium)
                }
            }

            if let data = action.eventData {
                LabeledContent("When") {
                    VStack(alignment: .trailing) {
                        Text(formatDate(data.startDate))
                        Text(formatTime(data.startDate) + " - " + formatTime(data.endDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            LabeledContent("Where") {
                if isEditing {
                    TextField("Location (optional)", text: $editableEventLocation)
                        .textFieldStyle(.roundedBorder)
                } else if !editableEventLocation.isEmpty {
                    Text(editableEventLocation)
                }
            }

            LabeledContent("Notes") {
                if isEditing {
                    TextField("Notes (optional)", text: $editableEventDescription)
                        .textFieldStyle(.roundedBorder)
                } else if !editableEventDescription.isEmpty {
                    Text(editableEventDescription)
                        .lineLimit(2)
                }
            }
        }
        .font(.subheadline)
    }

    private var emailPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("To") {
                if isEditing {
                    TextField("Recipient", text: $editableEmailTo)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(editableEmailTo)
                        .fontWeight(.medium)
                }
            }

            LabeledContent("Subject") {
                if isEditing {
                    TextField("Subject", text: $editableEmailSubject)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(editableEmailSubject)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if isEditing {
                    TextEditor(text: $editableEmailBody)
                        .font(.subheadline)
                        .frame(minHeight: 72)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                } else {
                    Text(editableEmailBody)
                        .font(.subheadline)
                        .lineLimit(4)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                }
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
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12).fill(success ? Color.green.opacity(0.10) : Color.red.opacity(0.10))
                GeometryReader { geo in
                    Rectangle()
                        .fill(success ? Color.green : Color.red)
                        .frame(width: 3, height: geo.size.height)
                        .cornerRadius(1.5)
                }
            }
        )
        .cornerRadius(12)
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
            onConfirm: { _ in },
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
            onConfirm: { _ in },
            onDecline: {}
        )
    }
    .padding()
    .frame(width: 380)
}
