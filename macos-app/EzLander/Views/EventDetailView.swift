import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent
    let onEdit: () -> Void
    let onDismiss: () -> Void
    var onMeetingPrep: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Back") { onDismiss() }
                    .buttonStyle(.borderless)

                Spacer()

                Text("Event Details")
                    .font(.headline)

                Spacer()

                Button("Edit") { onEdit() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title with calendar color bar
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(calendarBarColor)
                            .frame(width: 4, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.title3)
                                .fontWeight(.semibold)

                            if let calName = event.calendarName {
                                Text(calName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Time section
                    timeSection

                    // Join Meeting button
                    if let joinURL = event.effectiveJoinURL {
                        joinMeetingButton(url: joinURL)
                    }

                    // Location
                    if let location = event.location, !location.isEmpty {
                        detailRow(icon: "mappin.and.ellipse", title: "Location", value: location)
                    }

                    // Attendees
                    if let attendees = event.attendees, !attendees.isEmpty {
                        attendeesSection(attendees)
                    }

                    // Description/Notes
                    if let desc = event.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Notes", systemImage: "doc.text")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            Text(desc)
                                .font(.subheadline)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                        }
                    }

                    // AI Meeting Prep button
                    if event.attendeeCount > 0 || event.hasVideoCall {
                        Button(action: {
                            onMeetingPrep?()
                        }) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text("AI Meeting Prep")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.warmGradient)
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
        }
        .frame(width: 350, height: 420)
    }

    // MARK: - Calendar Bar Color
    private var calendarBarColor: Color {
        if let hex = event.calendarColor {
            return Color(hex: hex)
        }
        return .warmAccent
    }

    // MARK: - Time Section
    private var timeSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                if event.isAllDay {
                    Text("All Day")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(event.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(event.formattedDate)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(event.formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if event.durationMinutes > 0 {
                        Text(formatDuration(event.durationMinutes))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Join Meeting Button
    private func joinMeetingButton(url: URL) -> some View {
        Button(action: {
            NSWorkspace.shared.open(url)
        }) {
            HStack {
                Image(systemName: "video.fill")
                Text("Join \(event.conferenceName ?? "Meeting")")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.warmPrimary)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Row
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Attendees Section
    private func attendeesSection(_ attendees: [EventAttendee]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Attendees (\(attendees.count))", systemImage: "person.2")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                ForEach(attendees) { attendee in
                    attendeeRow(attendee)
                }
            }
        }
    }

    private func attendeeRow(_ attendee: EventAttendee) -> some View {
        HStack(spacing: 8) {
            // Avatar circle with initials
            ZStack {
                Circle()
                    .fill(Color.warmAccent.opacity(0.2))
                    .frame(width: 28, height: 28)
                Text(attendee.initials)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.warmAccent)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(attendee.displayName ?? attendee.email)
                        .font(.subheadline)
                        .lineLimit(1)

                    if attendee.isOrganizer {
                        Text("Organizer")
                            .font(.caption2)
                            .foregroundColor(.warmAccent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.warmAccent.opacity(0.15))
                            .cornerRadius(3)
                    }
                }

                if attendee.displayName != nil {
                    Text(attendee.email)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // RSVP status icon
            Image(systemName: attendee.statusIcon)
                .foregroundColor(attendee.statusColor)
                .font(.system(size: 14))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
}
