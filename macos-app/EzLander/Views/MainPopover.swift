import SwiftUI

struct MainPopover: View {
    @StateObject private var viewModel = MainPopoverViewModel()
    @ObservedObject private var aiService = AIService.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedTab: Tab = .chat

    enum Tab: String {
        case chat, calendar, email, settings
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — hidden on the email tab for maximum reading space
            if selectedTab != .email {
                headerView
                Divider()
            }

            // Content
            contentView

            Divider()

            // Tab bar
            tabBar
        }
        .frame(width: 420, height: 520)
        .background(Color.surfacePrimary)
        .preferredColorScheme(themeManager.resolvedColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: MenuBarController.switchTabNotification)) { notification in
            if let tabName = notification.object as? String,
               let tab = Tab(rawValue: tabName) {
                selectedTab = tab
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 1) {
                Text("ezLander")
                    .font(.system(.headline, design: .rounded))
                if !viewModel.userName.isEmpty {
                    Text("Hi, \(viewModel.userName)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Provider pill
            Text(aiService.currentProvider.displayName)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.warmPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.warmPrimary.opacity(0.1))
                )

            if viewModel.isSubscribed {
                Text("PRO")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.proBadge)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.proBadge.opacity(0.15))
                    )
            }

            Button(action: { selectedTab = .settings }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundColor(selectedTab == .settings ? .warmPrimary : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(selectedTab == .settings ? Color.warmPrimary.opacity(0.1) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
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
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(tab: .chat, icon: "bubble.left.and.bubble.right.fill", label: "Chat")
            tabButton(tab: .calendar, icon: "calendar", label: "Calendar")
            tabButton(tab: .email, icon: "envelope.fill", label: "Email")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func tabButton(tab: Tab, icon: String, label: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))
                    .symbolEffect(.bounce, value: selectedTab == tab)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selectedTab == tab ? .warmPrimary : .secondary)
            .padding(.vertical, 8)
            .background {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.warmPrimary.opacity(0.1))
                }
            }
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
        isSubscribed = subscriptionService.isSubscribed
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
                let monthFromNow = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now.addingTimeInterval(30 * 24 * 3600)
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
        #if DEBUG
        print("CalendarQuick: \(message)")
        #endif
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
