import SwiftUI

struct MainPopover: View {
    @StateObject private var viewModel = MainPopoverViewModel()
    @State private var selectedTab: Tab = .chat

    enum Tab: String {
        case chat, calendar, email, settings
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            contentView

            Divider()

            // Tab bar
            tabBar
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: MenuBarController.switchTabNotification)) { notification in
            if let tabName = notification.object as? String,
               let tab = Tab(rawValue: tabName) {
                selectedTab = tab
            }
        }
    }

    private var headerView: some View {
        HStack {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text("ezLander")
                    .font(.headline)
                if !viewModel.userName.isEmpty {
                    Text("Hi, \(viewModel.userName)!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if viewModel.isSubscribed {
                Label("Pro", systemImage: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.proBadge)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.proBadge.opacity(0.15))
                    .cornerRadius(8)
            }

            Button(action: { selectedTab = .settings }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(selectedTab == .settings ? .warmPrimary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .chat:
            ChatView()
        case .calendar:
            CalendarView()
        case .email:
            EmailView()
        case .settings:
            SettingsView()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(tab: .chat, icon: "bubble.left.and.bubble.right.fill", label: "Chat")
            tabButton(tab: .calendar, icon: "calendar", label: "Calendar")
            tabButton(tab: .email, icon: "envelope.fill", label: "Email")
        }
        .padding(.vertical, 8)
    }

    private func tabButton(tab: Tab, icon: String, label: String) -> some View {
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selectedTab == tab ? .warmPrimary : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model
class MainPopoverViewModel: ObservableObject {
    @Published var isSubscribed: Bool = false
    @Published var userName: String = ""
    @Published var userEmail: String = ""

    private let subscriptionService = SubscriptionService.shared

    init() {
        loadUserInfo()
        checkSubscription()
    }

    func loadUserInfo() {
        userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        userEmail = UserDefaults.standard.string(forKey: "user_email") ?? ""
    }

    func checkSubscription() {
        Task {
            let status = await subscriptionService.checkSubscriptionStatus()
            await MainActor.run {
                isSubscribed = status
            }
        }
    }
}

// MARK: - Quick Views
struct CalendarQuickView: View {
    @StateObject private var viewModel = CalendarQuickViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Upcoming Events")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
            }
            .padding()

            if !viewModel.isConnected {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Google Calendar not connected")
                        .foregroundColor(.secondary)
                    Button("Connect Google Calendar") {
                        viewModel.connect()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else if viewModel.isLoading {
                ProgressView("Loading events...")
                    .frame(maxHeight: .infinity)
            } else if viewModel.events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No upcoming events")
                        .foregroundColor(.secondary)
                    if let error = viewModel.error {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Text("Connected: \(viewModel.isConnected ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(viewModel.events, id: \.id) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                        Text(viewModel.formatDate(event.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            viewModel.loadEvents()
        }
    }
}

class CalendarQuickViewModel: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var error: String?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init() {
        logToFile("CalendarQuickViewModel init")
        checkConnection()
        logToFile("After checkConnection, isConnected: \(isConnected)")
    }

    func checkConnection() {
        // Must be signed in with Google specifically for Google Calendar
        let signedIn = OAuthService.shared.isSignedInWithGoogle
        logToFile("checkConnection: OAuthService.isSignedInWithGoogle = \(signedIn)")
        isConnected = signedIn
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

    func loadEvents() {
        logToFile("loadEvents called, isConnected: \(isConnected)")

        guard isConnected else {
            logToFile("Not connected, skipping load")
            return
        }

        isLoading = true
        logToFile("Loading events...")
        Task {
            do {
                let now = Date()
                let monthFromNow = Calendar.current.date(byAdding: .month, value: 1, to: now)!
                logToFile("Fetching from \(now) to \(monthFromNow)")
                let fetchedEvents = try await GoogleCalendarService.shared.listEvents(from: now, to: monthFromNow)
                logToFile("Got \(fetchedEvents.count) events")
                await MainActor.run {
                    self.events = fetchedEvents
                    self.isLoading = false
                }
            } catch {
                logToFile("Error: \(error)")
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func logToFile(_ message: String) {
        // Use Documents folder which is accessible in sandbox
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let logPath = documentsPath.appendingPathComponent("ezlander_calendar.log")

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logPath)
            }
        }
    }

    func refresh() {
        checkConnection()
        loadEvents()
    }

    func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

struct EmailQuickView: View {
    @StateObject private var viewModel = EmailQuickViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Emails")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
            }
            .padding()

            if !viewModel.isConnected {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Gmail not connected")
                        .foregroundColor(.secondary)
                    Button("Connect Gmail") {
                        viewModel.connect()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else if viewModel.isLoading {
                ProgressView("Loading emails...")
                    .frame(maxHeight: .infinity)
            } else if viewModel.emails.isEmpty {
                VStack {
                    Image(systemName: "envelope")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recent emails")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(viewModel.emails, id: \.id) { email in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(email.subject)
                            .font(.headline)
                            .lineLimit(1)
                        HStack {
                            Text(email.from ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(viewModel.formatDate(email.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            viewModel.loadEmails()
        }
    }
}

class EmailQuickViewModel: ObservableObject {
    @Published var emails: [Email] = []
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var error: String?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    init() {
        checkConnection()
    }

    func checkConnection() {
        // Must be signed in with Google specifically for Gmail
        isConnected = OAuthService.shared.isSignedInWithGoogle
    }

    func connect() {
        Task {
            do {
                try await GmailService.shared.authorize()
                await MainActor.run {
                    isConnected = true
                    loadEmails()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    func loadEmails() {
        guard isConnected else { return }

        isLoading = true
        Task {
            do {
                let fetchedEmails = try await GmailService.shared.listRecentEmails(maxResults: 10)
                await MainActor.run {
                    self.emails = fetchedEmails
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func refresh() {
        checkConnection()
        loadEmails()
    }

    func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

#Preview {
    MainPopover()
}
