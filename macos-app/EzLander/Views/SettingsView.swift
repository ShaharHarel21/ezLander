import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Account Section
                SettingsSection(title: "Account") {
                    if viewModel.isSignedIn {
                        signedInView
                    } else {
                        signInButtons
                    }
                }

                // Subscription Section
                SettingsSection(title: "Subscription") {
                    subscriptionView
                }

                // Integrations Section
                SettingsSection(title: "Integrations") {
                    integrationsView
                }

                // Preferences Section
                SettingsSection(title: "Preferences") {
                    preferencesView
                }

                // About Section
                SettingsSection(title: "About") {
                    aboutView
                }
            }
            .padding()
        }
    }

    // MARK: - Signed In View
    private var signedInView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(viewModel.userEmail)
                    .font(.headline)
                Text("Signed in")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Sign Out") {
                viewModel.signOut()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Sign In Buttons
    private var signInButtons: some View {
        VStack(spacing: 12) {
            Button(action: viewModel.signInWithGoogle) {
                HStack {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: viewModel.signInWithApple) {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Sign in with Apple")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
        }
    }

    // MARK: - Subscription View
    private var subscriptionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(viewModel.subscriptionStatus.displayName)
                        .font(.headline)
                    Text(viewModel.subscriptionStatus.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.subscriptionStatus == .active {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }

            if viewModel.subscriptionStatus != .active {
                Button("Upgrade to Pro") {
                    viewModel.openSubscriptionPage()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Manage Subscription") {
                    viewModel.openCustomerPortal()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Integrations View
    private var integrationsView: some View {
        VStack(spacing: 12) {
            IntegrationRow(
                name: "Google Calendar",
                icon: "calendar",
                isConnected: viewModel.googleCalendarConnected,
                onConnect: viewModel.connectGoogleCalendar,
                onDisconnect: viewModel.disconnectGoogleCalendar
            )

            IntegrationRow(
                name: "Apple Calendar",
                icon: "apple.logo",
                isConnected: viewModel.appleCalendarConnected,
                onConnect: viewModel.connectAppleCalendar,
                onDisconnect: viewModel.disconnectAppleCalendar
            )

            IntegrationRow(
                name: "Gmail",
                icon: "envelope",
                isConnected: viewModel.gmailConnected,
                onConnect: viewModel.connectGmail,
                onDisconnect: viewModel.disconnectGmail
            )
        }
    }

    // MARK: - Preferences View
    private var preferencesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Default Calendar", selection: $viewModel.defaultCalendar) {
                Text("Google Calendar").tag(CalendarType.google)
                Text("Apple Calendar").tag(CalendarType.apple)
            }

            Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)

            Toggle("Show Notifications", isOn: $viewModel.showNotifications)
        }
    }

    // MARK: - About View
    private var aboutView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Version")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }

            Button("Check for Updates") {
                viewModel.checkForUpdates()
            }
            .buttonStyle(.bordered)

            HStack(spacing: 16) {
                Link("Website", destination: URL(string: "https://ezlander.app")!)
                Link("Privacy Policy", destination: URL(string: "https://ezlander.app/privacy")!)
                Link("Terms", destination: URL(string: "https://ezlander.app/terms")!)
            }
            .font(.caption)
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            content
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
        }
    }
}

// MARK: - Integration Row
struct IntegrationRow: View {
    let name: String
    let icon: String
    let isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)

            Text(name)

            Spacer()

            if isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Button("Disconnect") {
                        onDisconnect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Button("Connect") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - View Model
class SettingsViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var subscriptionStatus: SubscriptionStatus = .none
    @Published var googleCalendarConnected: Bool = false
    @Published var appleCalendarConnected: Bool = false
    @Published var gmailConnected: Bool = false
    @Published var defaultCalendar: CalendarType = .google
    @Published var launchAtLogin: Bool = false
    @Published var showNotifications: Bool = true

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    init() {
        loadSettings()
    }

    func loadSettings() {
        // Load from UserDefaults/Keychain
    }

    func signInWithGoogle() {
        Task {
            do {
                try await OAuthService.shared.signInWithGoogle()
                await MainActor.run {
                    isSignedIn = true
                }
            } catch {
                print("Google sign in error: \(error)")
            }
        }
    }

    func signInWithApple() {
        // Sign in with Apple flow
    }

    func signOut() {
        OAuthService.shared.signOut()
        isSignedIn = false
        userEmail = ""
    }

    func openSubscriptionPage() {
        if let url = URL(string: "https://ezlander.app/pricing") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCustomerPortal() {
        // Open Stripe customer portal
    }

    func connectGoogleCalendar() {
        Task {
            do {
                try await GoogleCalendarService.shared.authorize()
                await MainActor.run {
                    googleCalendarConnected = true
                }
            } catch {
                print("Google Calendar connection error: \(error)")
            }
        }
    }

    func disconnectGoogleCalendar() {
        GoogleCalendarService.shared.signOut()
        googleCalendarConnected = false
    }

    func connectAppleCalendar() {
        AppleCalendarService.shared.requestAccess { [weak self] granted in
            DispatchQueue.main.async {
                self?.appleCalendarConnected = granted
            }
        }
    }

    func disconnectAppleCalendar() {
        appleCalendarConnected = false
    }

    func connectGmail() {
        Task {
            do {
                try await GmailService.shared.authorize()
                await MainActor.run {
                    gmailConnected = true
                }
            } catch {
                print("Gmail connection error: \(error)")
            }
        }
    }

    func disconnectGmail() {
        GmailService.shared.signOut()
        gmailConnected = false
    }

    func checkForUpdates() {
        // Sparkle update check
    }
}

// MARK: - Types
enum SubscriptionStatus {
    case none
    case trial
    case active
    case expired

    var displayName: String {
        switch self {
        case .none: return "Free"
        case .trial: return "Trial"
        case .active: return "Pro"
        case .expired: return "Expired"
        }
    }

    var description: String {
        switch self {
        case .none: return "Upgrade to unlock all features"
        case .trial: return "7 days remaining"
        case .active: return "All features unlocked"
        case .expired: return "Please renew your subscription"
        }
    }
}

enum CalendarType: String, CaseIterable {
    case google
    case apple
}

#Preview {
    SettingsView()
        .frame(width: 400, height: 600)
}
