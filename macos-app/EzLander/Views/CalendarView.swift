import SwiftUI
import EventKit

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel.shared
    @State private var showingAddEvent = false
    @State private var selectedEvent: CalendarEvent?

    var body: some View {
        VStack(spacing: 0) {
            // Header with navigation
            calendarHeader

            Divider()

            // View mode toggle
            viewModeToggle

            // Calendar content
            if viewModel.viewMode == .month {
                monthView
            } else {
                weekView
            }

            Divider()

            // Selected day events
            selectedDayEvents
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
            EventEditorView(
                event: event,
                selectedDate: viewModel.selectedDate,
                onSave: { updatedEvent in
                    viewModel.updateEvent(updatedEvent)
                    selectedEvent = nil
                },
                onCancel: {
                    selectedEvent = nil
                },
                onDelete: {
                    viewModel.deleteEvent(event)
                    selectedEvent = nil
                }
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - Calendar Header
    private var calendarHeader: some View {
        HStack {
            Button(action: { viewModel.previousPeriod() }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            Text(viewModel.headerTitle)
                .font(.headline)

            Spacer()

            Button(action: { viewModel.nextPeriod() }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)

            Button(action: { viewModel.goToToday() }) {
                Text("Today")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: { showingAddEvent = true }) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button(action: { viewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - View Mode Toggle
    private var viewModeToggle: some View {
        Picker("View", selection: $viewModel.viewMode) {
            Text("Month").tag(CalendarViewMode.month)
            Text("Week").tag(CalendarViewMode.week)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Month View
    private var monthView: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
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
                        onTap: {
                            viewModel.selectDate(date)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Week View
    private var weekView: some View {
        VStack(spacing: 0) {
            // Day headers with dates
            HStack(spacing: 0) {
                ForEach(viewModel.weekDays, id: \.self) { date in
                    VStack(spacing: 2) {
                        Text(viewModel.dayOfWeek(date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(viewModel.dayNumber(date))
                            .font(.system(size: 14, weight: viewModel.isSameDay(date, Date()) ? .bold : .regular))
                            .foregroundColor(viewModel.isSameDay(date, Date()) ? .accentColor : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(viewModel.isSameDay(date, viewModel.selectedDate) ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                    .onTapGesture {
                        viewModel.selectDate(date)
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider()

            // Week events timeline
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(viewModel.weekEvents, id: \.id) { event in
                        WeekEventRow(event: event, onTap: {
                            selectedEvent = event
                        })
                    }

                    if viewModel.weekEvents.isEmpty && !viewModel.isLoading {
                        Text("No events this week")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Selected Day Events
    private var selectedDayEvents: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(viewModel.selectedDateFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("\(viewModel.selectedDayEvents.count) events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

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
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .foregroundColor(textColor)

            // Event indicators (max 3 dots)
            HStack(spacing: 2) {
                ForEach(0..<min(eventCount, 3), id: \.self) { _ in
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.8) : Color.accentColor)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(backgroundColor)
        .cornerRadius(4)
        .onTapGesture {
            onTap()
        }
    }

    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.5)
        }
        if isSelected {
            return .white
        }
        if isToday {
            return .accentColor
        }
        return .primary
    }

    private var backgroundColor: Color {
        if isSelected {
            return .accentColor
        }
        if isToday {
            return .accentColor.opacity(0.1)
        }
        return .clear
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

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(timeFormatter.string(from: event.startDate))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let location = event.location, !location.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Week Event Row
struct WeekEventRow: View {
    let event: CalendarEvent
    let onTap: () -> Void

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, h:mm a"
        return f
    }()

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(formatter.string(from: event.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .onTapGesture {
            onTap()
        }
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
        .frame(width: 350, height: 400)
        .onAppear {
            if let event = event {
                title = event.title
                startDate = event.startDate
                endDate = event.endDate
                location = event.location ?? ""
                notes = event.description ?? ""
                isAllDay = event.isAllDay
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

    private func saveEvent() {
        let newEvent = CalendarEvent(
            id: event?.id ?? UUID().uuidString,
            title: title,
            startDate: startDate,
            endDate: endDate,
            calendarType: .google,
            description: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location,
            isAllDay: isAllDay
        )
        onSave(newEvent)
    }
}

// MARK: - View Model
enum CalendarViewMode {
    case month
    case week
}

class CalendarViewModel: ObservableObject {
    static let shared = CalendarViewModel()

    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var viewMode: CalendarViewMode = .month
    @Published var events: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var error: String?

    private let calendar = Calendar.current
    private var hasLoadedOnce = false

    // Cache for event counts per day
    private var eventCountCache: [String: Int] = [:]

    init() {
        checkConnection()
    }

    func onAppear() {
        checkConnection()
        if isConnected && !hasLoadedOnce {
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
        formatter.dateFormat = viewMode == .month ? "MMMM yyyy" : "'Week of' MMM d"
        return formatter.string(from: currentMonth)
    }

    var selectedDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
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
        return "\(components.year!)-\(components.month!)-\(components.day!)"
    }

    func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let targetYear = calendar.component(.year, from: date)
        let targetMonth = calendar.component(.month, from: date)
        let targetDay = calendar.component(.day, from: date)

        let matching = events.filter { event in
            let eventYear = calendar.component(.year, from: event.startDate)
            let eventMonth = calendar.component(.month, from: event.startDate)
            let eventDay = calendar.component(.day, from: event.startDate)

            return eventYear == targetYear && eventMonth == targetMonth && eventDay == targetDay
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
        if viewMode == .month {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        } else {
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
            currentMonth = selectedDate
        }
        loadEvents()
    }

    func nextPeriod() {
        if viewMode == .month {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        } else {
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
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
                try await GoogleCalendarService.shared.deleteEvent(id: event.id)
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
