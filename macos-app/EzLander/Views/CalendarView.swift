import SwiftUI
import EventKit

struct CalendarView: View {
    @ObservedObject private var viewModel = CalendarViewModel.shared
    @State private var showingAddEvent = false
    @State private var selectedEvent: CalendarEvent?
    @State private var editingEvent: CalendarEvent?

    var body: some View {
        VStack(spacing: 0) {
            // Header with navigation
            calendarHeader

            Divider()

            // View mode toggle
            viewModeToggle

            // Up Next — shows next 3 upcoming events with relative time
            if viewModel.viewMode == .month {
                upNextSection
            }

            // Calendar content with animated transitions
            Group {
                switch viewModel.viewMode {
                case .month:
                    monthView
                case .week:
                    weekView
                case .day:
                    dayView
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
            .animation(.spring(response: 0.32, dampingFraction: 0.80), value: viewModel.viewMode)

            // Selected day events (only in month view — week/day views show events inline)
            if viewModel.viewMode == .month {
                Divider()
                selectedDayEvents
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditorView(
                event: nil,
                selectedDate: viewModel.selectedDate,
                onSave: { event in
                    viewModel.createEvent(event)
                    showingAddEvent = false
                },
                onCancel: {
                    showingAddEvent = false
                }
            )
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(
                event: event,
                onEdit: {
                    let eventToEdit = event
                    selectedEvent = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editingEvent = eventToEdit
                    }
                },
                onDismiss: {
                    selectedEvent = nil
                },
                onMeetingPrep: {
                    selectedEvent = nil
                    // Post notification for meeting prep
                    NotificationCenter.default.post(
                        name: Notification.Name("MeetingPrepRequested"),
                        object: event
                    )
                }
            )
        }
        .sheet(item: $editingEvent) { event in
            EventEditorView(
                event: event,
                selectedDate: viewModel.selectedDate,
                onSave: { updatedEvent in
                    viewModel.updateEvent(updatedEvent)
                    editingEvent = nil
                },
                onCancel: {
                    editingEvent = nil
                },
                onDelete: {
                    viewModel.deleteEvent(event)
                    editingEvent = nil
                }
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - Calendar Header
    private var calendarHeader: some View {
        HStack(spacing: 12) {
            // Navigation arrows
            HStack(spacing: 2) {
                Button(action: { viewModel.previousPeriod() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.nextPeriod() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
            }

            Text(viewModel.headerTitle)
                .font(.system(.headline, design: .rounded))

            Spacer()

            // Today pill
            Button(action: { viewModel.goToToday() }) {
                Text("Today")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.warmPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.warmPrimary.opacity(0.1)))
            }
            .buttonStyle(.plain)

            // Add event
            Button(action: { showingAddEvent = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [.warmPrimary, .warmAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
            }
            .buttonStyle(.plain)

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - View Mode Toggle
    private var viewModeToggle: some View {
        HStack(spacing: 2) {
            ForEach([CalendarViewMode.month, .week, .day], id: \.self) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.viewMode = mode
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModeIcon(mode))
                            .font(.system(size: 10))
                        Text(viewModeLabel(mode))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(viewModel.viewMode == mode ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background {
                        if viewModel.viewMode == mode {
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [.warmPrimary, .warmAccent], startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: .warmPrimary.opacity(0.3), radius: 4, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    private func viewModeIcon(_ mode: CalendarViewMode) -> String {
        switch mode {
        case .month: return "square.grid.3x3"
        case .week: return "rectangle.split.3x1"
        case .day: return "rectangle.portrait"
        }
    }

    private func viewModeLabel(_ mode: CalendarViewMode) -> String {
        switch mode {
        case .month: return "Month"
        case .week: return "Week"
        case .day: return "Day"
        }
    }

    // MARK: - Up Next
    private var upNextSection: some View {
        let upcoming = viewModel.upcomingEvents
        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("UP NEXT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(upcoming.prefix(4), id: \.id) { event in
                                UpNextCard(event: event) {
                                    selectedEvent = event
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 6)

                Divider()
            }
        }
    }

    // MARK: - Month View
    private var monthView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Day headers
                HStack(spacing: 0) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(viewModel.monthDays, id: \.self) { date in
                        DayCell(
                            date: date,
                            isSelected: viewModel.isSameDay(date, viewModel.selectedDate),
                            isToday: viewModel.isSameDay(date, Date()),
                            isCurrentMonth: viewModel.isCurrentMonth(date),
                            eventCount: viewModel.eventCountForDate(date),
                            events: viewModel.eventsForDate(date),
                            onTap: {
                                viewModel.selectDate(date)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Week View
    private var weekView: some View {
        let hourHeight: CGFloat = 52
        let totalHeight: CGFloat = hourHeight * 24

        return VStack(spacing: 0) {
            // Day column headers aligned with grid columns
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 46)

                ForEach(viewModel.weekDays, id: \.self) { date in
                    VStack(spacing: 2) {
                        Text(viewModel.dayOfWeek(date))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        ZStack {
                            Circle()
                                .fill(viewModel.isSameDay(date, Date()) ? Color.warmPrimary : Color.clear)
                                .frame(width: 24, height: 24)

                            Text(viewModel.dayNumber(date))
                                .font(.system(size: 13, weight: viewModel.isSameDay(date, Date()) ? .bold : .regular))
                                .foregroundColor(viewModel.isSameDay(date, Date()) ? .white : .primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        Group {
                            if viewModel.isSameDay(date, Date()) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.warmPrimary.opacity(0.1))
                                    .padding(.horizontal, 2)
                            } else if viewModel.isSameDay(date, viewModel.selectedDate) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.warmPrimary.opacity(0.1))
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .onTapGesture {
                        viewModel.selectDate(date)
                    }
                }
            }

            // All-day events row aligned with day columns
            let hasAllDay = viewModel.weekDays.contains { !viewModel.eventsForDate($0).filter { $0.isAllDay }.isEmpty }
            if hasAllDay {
                Divider()

                HStack(alignment: .top, spacing: 0) {
                    Text("All day")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 46, alignment: .trailing)
                        .padding(.trailing, 4)

                    ForEach(viewModel.weekDays, id: \.self) { date in
                        VStack(spacing: 1) {
                            ForEach(viewModel.eventsForDate(date).filter { $0.isAllDay }, id: \.id) { event in
                                Text(event.title)
                                    .font(.system(size: 8, weight: .medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 1)
                                    .frame(maxWidth: .infinity)
                                    .background((event.calendarColor.map { Color(hex: $0) } ?? Color.warmAccent).opacity(0.2))
                                    .cornerRadius(2)
                                    .onTapGesture { selectedEvent = event }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Columnar time grid
            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        // Hour labels column
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(hourLabel(hour))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .frame(width: 42, height: hourHeight, alignment: .topTrailing)
                                    .padding(.trailing, 4)
                                    .id(hour)
                            }
                        }

                        // Day columns
                        ForEach(viewModel.weekDays, id: \.self) { date in
                            ZStack(alignment: .topLeading) {
                                // Hourly grid lines
                                VStack(spacing: 0) {
                                    ForEach(0..<24, id: \.self) { _ in
                                        VStack(spacing: 0) {
                                            Divider()
                                            Spacer()
                                        }
                                        .frame(height: hourHeight)
                                    }
                                }

                                // Timed events
                                ForEach(viewModel.eventsForDate(date).filter { !$0.isAllDay }, id: \.id) { event in
                                    WeekColumnEventBlock(event: event) {
                                        selectedEvent = event
                                    }
                                    .frame(height: max(20, eventHeightForDuration(event, hourHeight: hourHeight)))
                                    .padding(.horizontal, 1)
                                    .offset(y: yPositionForTime(event.startDate, hourHeight: hourHeight))
                                }

                                // Current time indicator
                                if viewModel.isSameDay(date, viewModel.currentTime) {
                                    HStack(spacing: 0) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 6, height: 6)
                                        Rectangle()
                                            .fill(Color.red)
                                            .frame(height: 1)
                                    }
                                    .offset(y: yPositionForTime(viewModel.currentTime, hourHeight: hourHeight) - 3)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: totalHeight)
                            .clipped()
                        }
                    }
                }
                .onAppear {
                    scrollToRelevantHour(proxy: proxy)
                }
                .onChange(of: viewModel.selectedDate) { _ in
                    scrollToRelevantHour(proxy: proxy)
                }
            }
        }
    }

    // MARK: - Day View
    private var dayView: some View {
        let hourHeight: CGFloat = 52
        let totalHeight: CGFloat = hourHeight * 24
        let allDayEvents = viewModel.selectedDayEvents.filter { $0.isAllDay }

        return VStack(spacing: 0) {
            // All-day events section
            if !allDayEvents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All Day")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 50)

                    ForEach(allDayEvents, id: \.id) { event in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.warmAccent)
                                .frame(width: 3, height: 16)
                            Text(event.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.leading, 50)
                        .padding(.trailing, 8)
                        .onTapGesture { selectedEvent = event }
                    }
                }
                .padding(.vertical, 6)

                Divider()
            }

            // Timeline
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Hour grid lines and labels
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                HStack(alignment: .top, spacing: 4) {
                                    Text(hourLabel(hour))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .frame(width: 42, alignment: .trailing)

                                    VStack(spacing: 0) {
                                        Divider()
                                        Spacer()
                                    }
                                }
                                .frame(height: hourHeight)
                                .id(hour)
                            }
                        }

                        // Events overlay
                        ForEach(viewModel.selectedDayEvents.filter { !$0.isAllDay }, id: \.id) { event in
                            let yOffset = yPositionForTime(event.startDate, hourHeight: hourHeight)
                            let eventHeight = max(hourHeight / 2, eventHeightForDuration(event, hourHeight: hourHeight))

                            DayEventBlock(event: event) {
                                selectedEvent = event
                            }
                            .frame(height: eventHeight)
                            .padding(.leading, 50)
                            .padding(.trailing, 8)
                            .offset(y: yOffset)
                        }

                        // Current time indicator
                        if viewModel.isSameDay(viewModel.selectedDate, viewModel.currentTime) {
                            let timeY = yPositionForTime(viewModel.currentTime, hourHeight: hourHeight)
                            CurrentTimeIndicator()
                                .offset(y: timeY)
                        }
                    }
                    .frame(height: totalHeight)
                }
                .onAppear {
                    scrollToRelevantHour(proxy: proxy)
                }
                .onChange(of: viewModel.selectedDate) { _ in
                    scrollToRelevantHour(proxy: proxy)
                }
            }
        }
    }

    private func scrollToRelevantHour(proxy: ScrollViewProxy) {
        let scrollHour: Int
        if viewModel.isSameDay(viewModel.selectedDate, Date()) {
            scrollHour = max(0, Calendar.current.component(.hour, from: Date()) - 1)
        } else {
            scrollHour = 8
        }
        proxy.scrollTo(scrollHour, anchor: .top)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }

    private func yPositionForTime(_ date: Date, hourHeight: CGFloat) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
    }

    private func eventHeightForDuration(_ event: CalendarEvent, hourHeight: CGFloat) -> CGFloat {
        let durationHours = event.duration / 3600.0
        return CGFloat(durationHours) * hourHeight
    }

    // MARK: - Selected Day Events
    private var selectedDayEvents: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Date badge
                VStack(spacing: 0) {
                    Text(viewModel.selectedDayOfWeek)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.warmPrimary)
                        .textCase(.uppercase)
                    Text(viewModel.selectedDayNumber)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.warmPrimary.opacity(0.1))
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.selectedDateFormatted)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Text("\(viewModel.selectedDayEvents.count) event\(viewModel.selectedDayEvents.count == 1 ? "" : "s")")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            if !viewModel.isConnected {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Connect Google Calendar to see events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Connect") {
                        viewModel.connect()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let error = viewModel.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        viewModel.refresh()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.selectedDayEvents, id: \.id) { event in
                            EventRow(event: event, onTap: {
                                selectedEvent = event
                            })
                        }

                        if viewModel.selectedDayEvents.isEmpty && !viewModel.isLoading {
                            Text("No events on this day")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .padding()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 120)
            }
        }
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let eventCount: Int
    let events: [CalendarEvent]
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 1) {
            // Day number with today circle
            ZStack {
                if isToday && !isSelected {
                    Circle()
                        .fill(Color.warmPrimary)
                        .frame(width: 22, height: 22)
                }
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundColor(todayCircleTextColor)
            }
            .frame(height: 22)

            // Mini event bars (max 2, with "+N" overflow)
            VStack(spacing: 1) {
                ForEach(Array(events.prefix(2).enumerated()), id: \.element.id) { _, event in
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(eventBarColor(event))
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                }

                if eventCount > 2 {
                    Text("+\(eventCount - 2)")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .frame(height: 8)
                } else if eventCount <= 2 {
                    // Spacer to keep consistent height
                    Color.clear.frame(height: eventCount == 0 ? 14 : 8)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(dayCellBackground)
        .clipShape(RoundedRectangle(cornerRadius: isSelected ? 10 : 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isSelected ? 10 : 6, style: .continuous)
                .strokeBorder(isHovered && !isSelected ? Color.warmPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(color: isSelected ? Color.warmPrimary.opacity(0.2) : .clear, radius: 4, y: 2)
        .animation(.spring(response: 0.25, dampingFraction: 0.70), value: isSelected)
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var dayCellBackground: some View {
        if isSelected {
            LinearGradient(colors: [.warmPrimary, .warmAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if isCurrentMonth && eventCount >= 3 {
            Color.warmPrimary.opacity(0.08)
        } else {
            Color.clear
        }
    }

    private func eventBarColor(_ event: CalendarEvent) -> Color {
        if isSelected { return .white.opacity(0.7) }
        if let hex = event.calendarColor {
            return Color(hex: hex)
        }
        return .eventDot
    }

    private var todayCircleTextColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.5)
        }
        if isSelected {
            return .white
        }
        if isToday {
            return .white // White text on coral circle
        }
        return .primary
    }

}

// MARK: - Up Next Card
struct UpNextCard: View {
    let event: CalendarEvent
    let onTap: () -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(calendarColor)
                    .frame(width: 6, height: 6)
                Text(relativeTime)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isImminent ? .warmPrimary : .secondary)
            }

            Text(event.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)

            if !event.isAllDay {
                Text(timeFormatter.string(from: event.startDate))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if event.hasVideoCall {
                HStack(spacing: 3) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                    Text(event.conferenceName ?? "Join")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.warmPrimary)
            }
        }
        .padding(10)
        .frame(width: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isImminent ? Color.warmPrimary.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
        .onTapGesture { onTap() }
    }

    private var calendarColor: Color {
        if let hex = event.calendarColor { return Color(hex: hex) }
        return .warmAccent
    }

    private var isImminent: Bool {
        event.startDate.timeIntervalSinceNow < 3600 && event.startDate.timeIntervalSinceNow > 0
    }

    private var relativeTime: String {
        let interval = event.startDate.timeIntervalSinceNow
        if interval < 0 { return "Now" }
        if interval < 60 { return "Now" }
        if interval < 3600 { return "In \(Int(interval / 60))m" }
        if interval < 86400 { return "In \(Int(interval / 3600))h" }
        let days = Int(interval / 86400)
        if days == 1 { return "Tomorrow" }
        return "In \(days)d"
    }
}

// MARK: - Event Row
struct EventRow: View {
    let event: CalendarEvent
    let onTap: () -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Color bar with rounded ends
            RoundedRectangle(cornerRadius: 2)
                .fill(calendarBarColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if event.isAllDay {
                        Text("All Day")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.warmPrimary)
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(timeFormatter.string(from: event.startDate))
                                .font(.system(size: 11, design: .rounded))
                        }
                        .foregroundColor(.secondary)
                    }

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 9))
                            Text(location)
                                .font(.system(size: 11, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Attendee avatars (stacked circles)
            if event.attendeeCount > 0 {
                HStack(spacing: -4) {
                    ForEach(0..<min(event.attendeeCount, 3), id: \.self) { i in
                        Circle()
                            .fill(Color.warmPrimary.opacity(0.2 + Double(i) * 0.15))
                            .overlay(
                                Text(event.attendees?[safe: i]?.initials.prefix(1) ?? "?")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.warmPrimary)
                            )
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.surfacePrimary, lineWidth: 1.5))
                    }
                    if event.attendeeCount > 3 {
                        Circle()
                            .fill(Color.warmPrimary.opacity(0.1))
                            .overlay(
                                Text("+\(event.attendeeCount - 3)")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.warmPrimary)
                            )
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.surfacePrimary, lineWidth: 1.5))
                    }
                }
            }

            // Join button for video calls
            if event.hasVideoCall {
                Button(action: {
                    if let url = event.effectiveJoinURL {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                        Text("Join")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [.warmPrimary, .warmAccent], startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: .warmPrimary.opacity(0.3), radius: 4, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(isHovered ? 0.1 : 0.04), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 6 : 2, y: isHovered ? 3 : 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .onTapGesture { onTap() }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    private var calendarBarColor: Color {
        if let hex = event.calendarColor {
            return Color(hex: hex)
        }
        return .warmAccent
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Week Column Event Block
struct WeekColumnEventBlock: View {
    let event: CalendarEvent
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(barColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(2)

                if event.hasVideoCall {
                    Image(systemName: "video.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.warmPrimary)
                }
            }
            .padding(.leading, 2)
            .padding(.vertical, 1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(barColor.opacity(0.15))
        .cornerRadius(3)
        .onTapGesture { onTap() }
    }

    private var barColor: Color {
        if let hex = event.calendarColor {
            return Color(hex: hex)
        }
        return .warmAccent
    }
}

// MARK: - Current Time Indicator
struct CurrentTimeIndicator: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .padding(.leading, 42)

            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
    }
}

// MARK: - Day Event Block
struct DayEventBlock: View {
    let event: CalendarEvent
    let onTap: () -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(calendarBarColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)

                    if event.hasVideoCall {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.warmPrimary)
                    }
                }

                Text("\(timeFormatter.string(from: event.startDate)) – \(timeFormatter.string(from: event.endDate))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 6)
            .padding(.vertical, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.warmPrimary.opacity(0.12))
        )
        .cornerRadius(8)
        .onTapGesture { onTap() }
    }

    private var calendarBarColor: Color {
        if let hex = event.calendarColor {
            return Color(hex: hex)
        }
        return .warmAccent
    }
}

// MARK: - Event Editor View
struct EventEditorView: View {
    let event: CalendarEvent?
    let selectedDate: Date
    let onSave: (CalendarEvent) -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)?

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var isAllDay: Bool = false
    @State private var attendeeEmails: [String] = []
    @State private var newAttendeeEmail: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(event == nil ? "New Event" : "Edit Event")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveEvent()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(title.isEmpty)
            }
            .padding()

            Divider()

            // Form
            Form {
                TextField("Title", text: $title)

                Toggle("All Day", isOn: $isAllDay)

                DatePicker("Start", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])

                DatePicker("End", selection: $endDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])

                TextField("Location", text: $location)

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)

                // Attendees section
                Section("Attendees") {
                    ForEach(attendeeEmails.indices, id: \.self) { index in
                        HStack {
                            Text(attendeeEmails[index])
                                .font(.subheadline)
                            Spacer()
                            Button(action: {
                                attendeeEmails.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("Add attendee email", text: $newAttendeeEmail)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                addAttendee()
                            }
                        Button(action: addAttendee) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.warmPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(newAttendeeEmail.isEmpty)
                    }
                }

                if event != nil, let onDelete = onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Event")
                            Spacer()
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 350, height: 480)
        .onAppear {
            if let event = event {
                title = event.title
                startDate = event.startDate
                endDate = event.endDate
                location = event.location ?? ""
                notes = event.description ?? ""
                isAllDay = event.isAllDay
                attendeeEmails = event.attendees?.map { $0.email } ?? []
            } else {
                // Set start time to nearest hour
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day, .hour], from: selectedDate)
                components.hour = calendar.component(.hour, from: Date())
                if let date = calendar.date(from: components) {
                    startDate = date
                    endDate = calendar.date(byAdding: .hour, value: 1, to: date) ?? date
                }
            }
        }
    }

    private func addAttendee() {
        let email = newAttendeeEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, email.contains("@") else { return }
        attendeeEmails.append(email)
        newAttendeeEmail = ""
    }

    private func saveEvent() {
        let attendees: [EventAttendee]? = attendeeEmails.isEmpty ? nil : attendeeEmails.map {
            EventAttendee(email: $0, responseStatus: .needsAction, isOrganizer: false, isSelf: false)
        }

        let newEvent = CalendarEvent(
            id: event?.id ?? UUID().uuidString,
            title: title,
            startDate: startDate,
            endDate: endDate,
            calendarType: .google,
            description: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location,
            isAllDay: isAllDay,
            attendees: attendees
        )
        onSave(newEvent)
    }
}

// MARK: - View Model
enum CalendarViewMode: Equatable, Hashable {
    case month
    case week
    case day
}

@MainActor
class CalendarViewModel: ObservableObject {
    static let shared = CalendarViewModel()

    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var viewMode: CalendarViewMode = .month
    @Published var events: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var error: String?
    @Published var currentTime: Date = Date()

    private let calendar = Calendar.current
    private var hasLoadedOnce = false
    private var timeTimer: Timer?

    // Cache for event counts per day
    private var eventCountCache: [String: Int] = [:]

    init() {
        checkConnection()
        startTimeTimer()
    }

    deinit {
        timeTimer?.invalidate()
    }

    private func startTimeTimer() {
        timeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentTime = Date()
            }
        }
    }

    func onAppear() {
        checkConnection()
        if isConnected && (!hasLoadedOnce || events.isEmpty) {
            loadEvents()
        }
    }

    func checkConnection() {
        isConnected = OAuthService.shared.isSignedInWithGoogle
    }

    func connect() {
        Task {
            do {
                try await GoogleCalendarService.shared.authorize()
                await MainActor.run {
                    isConnected = true
                    loadEvents()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    var headerTitle: String {
        let formatter = DateFormatter()
        switch viewMode {
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: currentMonth)
        case .week:
            formatter.dateFormat = "'Week of' MMM d"
            return formatter.string(from: currentMonth)
        case .day:
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    var selectedDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }

    var selectedDayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: selectedDate)
    }

    var selectedDayNumber: String {
        "\(calendar.component(.day, from: selectedDate))"
    }

    // MARK: - Month Days
    var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }

        var days: [Date] = []
        var current = monthFirstWeek.start

        while current < monthLastWeek.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        return days
    }

    // MARK: - Week Days
    var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfMonth, for: selectedDate) else {
            return []
        }

        var days: [Date] = []
        var current = weekInterval.start

        for _ in 0..<7 {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        return days
    }

    var weekEvents: [CalendarEvent] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfMonth, for: selectedDate) else {
            return []
        }
        return events.filter { event in
            event.startDate >= weekInterval.start && event.startDate < weekInterval.end
        }.sorted { $0.startDate < $1.startDate }
    }

    var selectedDayEvents: [CalendarEvent] {
        eventsForDate(selectedDate)
    }

    /// Next upcoming events (not past, sorted by start time)
    var upcomingEvents: [CalendarEvent] {
        let now = Date()
        return events
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Helpers
    func eventCountForDate(_ date: Date) -> Int {
        let key = dateKey(date)
        if let cached = eventCountCache[key] {
            return cached
        }
        let count = eventsForDate(date).count
        eventCountCache[key] = count
        return count
    }

    private func dateKey(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year)-\(month)-\(day)"
    }

    func eventsForDate(_ date: Date) -> [CalendarEvent] {
        guard let dayStart = calendar.dateInterval(of: .day, for: date) else {
            return []
        }
        let dayEnd = dayStart.end

        let matching = events.filter { event in
            // Event overlaps with this day if it starts before day ends AND ends after day starts
            return event.startDate < dayEnd && event.endDate > dayStart.start
        }
        return matching.sorted { $0.startDate < $1.startDate }
    }

    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let year1 = calendar.component(.year, from: date1)
        let month1 = calendar.component(.month, from: date1)
        let day1 = calendar.component(.day, from: date1)

        let year2 = calendar.component(.year, from: date2)
        let month2 = calendar.component(.month, from: date2)
        let day2 = calendar.component(.day, from: date2)

        return year1 == year2 && month1 == month2 && day1 == day2
    }

    func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }

    func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    func dayNumber(_ date: Date) -> String {
        "\(calendar.component(.day, from: date))"
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    // MARK: - Navigation
    func previousPeriod() {
        switch viewMode {
        case .month:
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
            currentMonth = selectedDate
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            currentMonth = selectedDate
        }
        loadEvents()
    }

    func nextPeriod() {
        switch viewMode {
        case .month:
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
            currentMonth = selectedDate
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            currentMonth = selectedDate
        }
        loadEvents()
    }

    func goToToday() {
        selectedDate = Date()
        currentMonth = Date()
        loadEvents()
    }

    // MARK: - Data Operations
    func loadEvents() {
        guard isConnected else {
            NSLog("CalendarViewModel: Not connected, skipping load")
            return
        }

        isLoading = true
        error = nil
        hasLoadedOnce = true

        // Clear cache when reloading
        eventCountCache.removeAll()

        Task {
            do {
                // Load 3 months of events centered on current month
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
                let start = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
                let end = calendar.date(byAdding: .month, value: 2, to: startOfMonth)!

                NSLog("CalendarViewModel: Loading events from \(start) to \(end)")

                let fetchedEvents = try await GoogleCalendarService.shared.listEvents(from: start, to: end)

                NSLog("CalendarViewModel: Loaded \(fetchedEvents.count) events")

                // Log first few events for debugging
                for (index, event) in fetchedEvents.prefix(5).enumerated() {
                    NSLog("CalendarViewModel: Event \(index): \(event.title) on \(event.startDate)")
                }

                await MainActor.run {
                    self.events = fetchedEvents
                    self.isLoading = false
                    self.eventCountCache.removeAll() // Clear cache after loading new events
                }
            } catch {
                NSLog("CalendarViewModel: Error loading events: \(error)")
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func refresh() {
        checkConnection()
        if isConnected {
            loadEvents()
        }
    }

    func createEvent(_ event: CalendarEvent) {
        Task {
            do {
                try await GoogleCalendarService.shared.createEvent(event)
                await MainActor.run {
                    loadEvents()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    func updateEvent(_ event: CalendarEvent) {
        Task {
            do {
                try await GoogleCalendarService.shared.updateEvent(event)
                await MainActor.run {
                    loadEvents()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    func deleteEvent(_ event: CalendarEvent) {
        Task {
            do {
                try await GoogleCalendarService.shared.deleteEvent(id: event.id, calendarId: event.googleCalendarId)
                await MainActor.run {
                    loadEvents()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    CalendarView()
        .frame(width: 400, height: 500)
}
