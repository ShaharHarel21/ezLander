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

                // AI Provider Section
                SettingsSection(title: "AI Provider") {
                    aiProviderView
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
            // Profile picture placeholder
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(viewModel.userName.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Hi, \(viewModel.userName)!")
                    .font(.headline)
                Text(viewModel.userEmail)
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

    // MARK: - AI Provider View
    private var aiProviderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("AI Model", selection: $viewModel.selectedAIProvider) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                        Text(provider.displayName)
                    }
                    .tag(provider)
                }
            }

            Divider()

            // Claude API Key
            HStack {
                Image(systemName: "brain.head.profile")
                    .frame(width: 24)
                Text("Claude API Key")
                Spacer()
                if viewModel.claudeConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Button("Remove") {
                        viewModel.removeClaudeKey()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Add Key") {
                        viewModel.showClaudeKeyInput = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if viewModel.showClaudeKeyInput {
                HStack {
                    SecureField("sk-ant-...", text: $viewModel.claudeKeyInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        viewModel.saveClaudeKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            // Kimi API Key
            HStack {
                Image(systemName: "sparkles")
                    .frame(width: 24)
                Text("Kimi API Key")
                Spacer()
                if viewModel.kimiConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Button("Remove") {
                        viewModel.removeKimiKey()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Add Key") {
                        viewModel.showKimiKeyInput = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if viewModel.showKimiKeyInput {
                HStack {
                    SecureField("sk-...", text: $viewModel.kimiKeyInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        viewModel.saveKimiKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
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
    @Published var userName: String = ""
    @Published var subscriptionStatus: SubscriptionStatus = .none
    @Published var googleCalendarConnected: Bool = false
    @Published var appleCalendarConnected: Bool = false
    @Published var gmailConnected: Bool = false
    @Published var defaultCalendar: CalendarType = .google
    @Published var launchAtLogin: Bool = false
    @Published var showNotifications: Bool = true

    // AI Provider settings
    @Published var selectedAIProvider: AIProvider = .claude {
        didSet {
            AIService.shared.currentProvider = selectedAIProvider
        }
    }
    @Published var claudeConfigured: Bool = false
    @Published var kimiConfigured: Bool = false
    @Published var showClaudeKeyInput: Bool = false
    @Published var showKimiKeyInput: Bool = false
    @Published var claudeKeyInput: String = ""
    @Published var kimiKeyInput: String = ""

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    init() {
        loadSettings()
    }

    func loadSettings() {
        // Load user info from UserDefaults
        userEmail = UserDefaults.standard.string(forKey: "user_email") ?? ""
        userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        isSignedIn = !userEmail.isEmpty

        // Check integration status
        googleCalendarConnected = OAuthService.shared.isSignedIn
        gmailConnected = OAuthService.shared.isSignedIn

        // Load AI provider settings
        selectedAIProvider = AIService.shared.currentProvider
        claudeConfigured = ClaudeService.shared.isConfigured
        kimiConfigured = KimiService.shared.isConfigured
    }

    // MARK: - AI Key Management
    func saveClaudeKey() {
        guard !claudeKeyInput.isEmpty else { return }
        let saved = KeychainService.shared.save(key: "anthropic_api_key", value: claudeKeyInput)
        print("SettingsViewModel: Claude key save result: \(saved)")
        claudeKeyInput = ""
        showClaudeKeyInput = false
        claudeConfigured = saved
        // Reload the key in the service
        ClaudeService.shared.reloadAPIKey()
        print("SettingsViewModel: Claude configured: \(ClaudeService.shared.isConfigured)")
    }

    func removeClaudeKey() {
        KeychainService.shared.delete(key: "anthropic_api_key")
        claudeConfigured = false
    }

    func saveKimiKey() {
        let trimmedKey = kimiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        let saved = KeychainService.shared.save(key: "kimi_api_key", value: trimmedKey)
        print("SettingsViewModel: Kimi key save result: \(saved), key length: \(trimmedKey.count)")
        kimiKeyInput = ""
        showKimiKeyInput = false
        kimiConfigured = saved
        // Reload the key in the service
        KimiService.shared.reloadAPIKey()
        print("SettingsViewModel: Kimi configured: \(KimiService.shared.isConfigured)")
    }

    func removeKimiKey() {
        KeychainService.shared.delete(key: "kimi_api_key")
        kimiConfigured = false
    }

    func signInWithGoogle() {
        Task {
            do {
                try await OAuthService.shared.signInWithGoogle()
                await MainActor.run {
                    loadSettings()
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
                    loadSettings()
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
                    loadSettings()
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
