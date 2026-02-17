import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var updateService = UpdateService.shared

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

                // Keyboard Shortcuts Section
                SettingsSection(title: "Keyboard Shortcuts") {
                    keyboardShortcutsView
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
            // Provider selector
            Picker("Active Provider", selection: $viewModel.selectedAIProvider) {
                ForEach(AIProvider.allCases) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                        Text(provider.displayName)
                        if provider.isConfigured {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    .tag(provider)
                }
            }

            Text("Configure your API keys below. You can switch between providers anytime.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // API Keys for each provider
            ForEach(AIProvider.allCases) { provider in
                APIKeyRow(
                    provider: provider,
                    isConfigured: provider.isConfigured,
                    showInput: viewModel.showKeyInput[provider] ?? false,
                    keyInput: Binding(
                        get: { viewModel.keyInputs[provider] ?? "" },
                        set: { viewModel.keyInputs[provider] = $0 }
                    ),
                    onAddKey: { viewModel.showKeyInput[provider] = true },
                    onSaveKey: { viewModel.saveAPIKey(for: provider) },
                    onRemoveKey: { viewModel.removeAPIKey(for: provider) },
                    onGetKey: { viewModel.openKeyURL(for: provider) }
                )
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

    // MARK: - Keyboard Shortcuts View
    private var keyboardShortcutsView: some View {
        KeyboardShortcutsSettingsView()
    }

    // MARK: - About View
    private var aboutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Version")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }

            // Update section
            if updateService.isCheckingForUpdates {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Checking for updates...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if updateService.updateAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        Text("Version \(updateService.latestVersion ?? "") available!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if updateService.isDownloading {
                        ProgressView(value: updateService.downloadProgress)
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Button("Download Update") {
                            Task {
                                await updateService.downloadAndInstall()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else if updateService.checkedOnce && !updateService.updateAvailable {
                // Already checked and up to date
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You have the latest version")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Check for Updates") {
                    Task {
                        await updateService.checkForUpdates()
                    }
                }
                .buttonStyle(.bordered)
            }

            Divider()

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
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            } else {
                Button("Connect") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - API Key Row
struct APIKeyRow: View {
    let provider: AIProvider
    let isConfigured: Bool
    let showInput: Bool
    @Binding var keyInput: String
    let onAddKey: () -> Void
    let onSaveKey: () -> Void
    let onRemoveKey: () -> Void
    let onGetKey: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: provider.icon)
                    .frame(width: 24)
                    .foregroundColor(.accentColor)

                Text(provider.displayName)
                    .fontWeight(.medium)

                Spacer()

                if isConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Button("Remove") {
                        onRemoveKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                } else {
                    Button("Get Key") {
                        onGetKey()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Add Key") {
                        onAddKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                }
            }

            if showInput {
                HStack {
                    SecureField(provider.keyPlaceholder, text: $keyInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        onSaveKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(keyInput.isEmpty)
                }
            }
        }
        .padding(.vertical, 4)
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

    // Dynamic key management for all providers
    @Published var showKeyInput: [AIProvider: Bool] = [:]
    @Published var keyInputs: [AIProvider: String] = [:]

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

        // Check if signed in via Google or Apple
        isSignedIn = OAuthService.shared.isSignedIn

        // If signed in but no name, set a default
        if isSignedIn && userName.isEmpty {
            userName = "User"
        }

        // Check integration status (Google services require Google sign in)
        googleCalendarConnected = OAuthService.shared.isSignedInWithGoogle
        gmailConnected = OAuthService.shared.isSignedInWithGoogle

        // Load AI provider settings
        selectedAIProvider = AIService.shared.currentProvider
    }

    // MARK: - AI Key Management
    func saveAPIKey(for provider: AIProvider) {
        guard let key = keyInputs[provider], !key.isEmpty else { return }
        AIService.shared.saveAPIKey(key, for: provider)
        keyInputs[provider] = ""
        showKeyInput[provider] = false
        objectWillChange.send()
    }

    func removeAPIKey(for provider: AIProvider) {
        AIService.shared.removeAPIKey(for: provider)
        objectWillChange.send()
    }

    func openKeyURL(for provider: AIProvider) {
        if let url = URL(string: provider.helpURL) {
            NSWorkspace.shared.open(url)
        }
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
        Task {
            do {
                try await OAuthService.shared.signInWithApple()
                await MainActor.run {
                    loadSettings()
                }
            } catch {
                print("Apple sign in error: \(error)")
            }
        }
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
