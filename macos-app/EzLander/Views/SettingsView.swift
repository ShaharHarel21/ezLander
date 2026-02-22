import SwiftUI

// MARK: - Settings Category
enum SettingsCategory: String, CaseIterable, Identifiable {
    case accountSubscription
    case integrations
    case aiProviders
    case general
    case keyboardShortcuts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accountSubscription: return "Account & Subscription"
        case .integrations: return "Integrations"
        case .aiProviders: return "AI Providers"
        case .general: return "General"
        case .keyboardShortcuts: return "Keyboard Shortcuts"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .accountSubscription: return "person.crop.circle"
        case .integrations: return "link"
        case .aiProviders: return "brain"
        case .general: return "gearshape"
        case .keyboardShortcuts: return "command"
        case .about: return "info.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .accountSubscription: return .warmPrimary
        case .integrations: return .green
        case .aiProviders: return .warmAccent
        case .general: return .gray
        case .keyboardShortcuts: return .warmHighlight
        case .about: return .blue
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var activeCategory: SettingsCategory?

    var body: some View {
        ZStack {
            if activeCategory == nil {
                mainListView
                    .transition(.move(edge: .leading))
            } else {
                detailView(for: activeCategory!)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeCategory)
        .clipped()
    }

    // MARK: - Main List
    private var mainListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileCard(viewModel: viewModel)
                    .onTapGesture { activeCategory = .accountSubscription }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()
                    .padding(.horizontal, 16)

                VStack(spacing: 1) {
                    ForEach(SettingsCategory.allCases) { category in
                        SettingsCategoryRow(
                            category: category,
                            subtitle: subtitleForCategory(category),
                            onTap: { activeCategory = category }
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func subtitleForCategory(_ category: SettingsCategory) -> String? {
        switch category {
        case .accountSubscription:
            return viewModel.subscriptionStatus.displayName
        case .integrations:
            let count = viewModel.connectedIntegrationCount
            return count > 0 ? "\(count) connected" : "None connected"
        case .aiProviders:
            return viewModel.selectedAIProvider.displayName
        case .general:
            return nil
        case .keyboardShortcuts:
            return nil
        case .about:
            return "v\(viewModel.appVersion)"
        }
    }

    // MARK: - Detail View Dispatch
    @ViewBuilder
    private func detailView(for category: SettingsCategory) -> some View {
        SettingsDetailContainer(title: category.title, onBack: { activeCategory = nil }) {
            switch category {
            case .accountSubscription:
                AccountSubscriptionDetailView(viewModel: viewModel)
            case .integrations:
                IntegrationsDetailView(viewModel: viewModel)
            case .aiProviders:
                AIProvidersDetailView(viewModel: viewModel)
            case .general:
                GeneralDetailView(viewModel: viewModel)
            case .keyboardShortcuts:
                KeyboardShortcutsSettingsView()
            case .about:
                AboutDetailView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Profile Card
struct ProfileCard: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        HStack(spacing: 12) {
            if viewModel.isSignedIn {
                profileAvatar
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 2) {
                if viewModel.isSignedIn {
                    Text(viewModel.userName)
                        .font(.headline)
                    Text(viewModel.userEmail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Sign In")
                        .font(.headline)
                    Text("Sign in to sync your data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let pictureURL = viewModel.userPicture, let url = URL(string: pictureURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.warmPrimary.opacity(0.15))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(viewModel.userName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.warmPrimary)
            )
    }
}

// MARK: - Category Row
struct SettingsCategoryRow: View {
    let category: SettingsCategory
    let subtitle: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(category.iconColor)
                    .cornerRadius(6)

                Text(category.title)
                    .foregroundColor(.primary)

                Spacer()

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Container
struct SettingsDetailContainer<Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack(spacing: 8) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Settings")
                            .font(.subheadline)
                    }
                    .foregroundColor(.warmPrimary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(title)
                    .font(.headline)

                Spacer()

                // Invisible spacer to center the title
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Settings")
                        .font(.subheadline)
                }
                .opacity(0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                content
                    .padding(16)
            }
        }
    }
}

// MARK: - Account & Subscription Detail
struct AccountSubscriptionDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Account
            if viewModel.isSignedIn {
                signedInSection
            } else {
                signInSection
            }

            Divider()

            // Subscription
            subscriptionSection
        }
    }

    private var signedInSection: some View {
        HStack {
            if let pictureURL = viewModel.userPicture, let url = URL(string: pictureURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.warmPrimary.opacity(0.15))
                        .overlay(
                            Text(String(viewModel.userName.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundColor(.warmPrimary)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.warmPrimary.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(viewModel.userName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.warmPrimary)
                    )
            }

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

    private var signInSection: some View {
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

    private var subscriptionSection: some View {
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
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
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
}

// MARK: - Integrations Detail
struct IntegrationsDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
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
}

// MARK: - AI Providers Detail
struct AIProvidersDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Active Provider", selection: $viewModel.selectedAIProvider) {
                ForEach(AIProvider.allCases) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                        Text(provider.displayName)
                        if provider.isConfigured {
                            Text("Active")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .tag(provider)
                }
            }

            Text("Configure your API keys below. You can switch between providers anytime.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            ForEach(AIProvider.allCases) { provider in
                if provider.supportsOAuth {
                    ClaudeAuthRow(
                        provider: provider,
                        useOAuth: $viewModel.claudeUseOAuth,
                        isOAuthConnected: provider.isOAuthConnected,
                        isAPIKeyConfigured: KeychainService.shared.get(key: provider.keychainKey) != nil,
                        isConnecting: viewModel.isClaudeOAuthConnecting,
                        showInput: viewModel.showKeyInput[provider] ?? false,
                        keyInput: Binding(
                            get: { viewModel.keyInputs[provider] ?? "" },
                            set: { viewModel.keyInputs[provider] = $0 }
                        ),
                        onSignInOAuth: { viewModel.signInWithClaudeOAuth() },
                        onSignOutOAuth: { viewModel.signOutClaudeOAuth() },
                        onAddKey: { viewModel.showKeyInput[provider] = true },
                        onSaveKey: { viewModel.saveAPIKey(for: provider) },
                        onRemoveKey: { viewModel.removeAPIKey(for: provider) },
                        onGetKey: { viewModel.openKeyURL(for: provider) }
                    )
                } else {
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
    }
}

// MARK: - General Detail
struct GeneralDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Default Calendar", selection: $viewModel.defaultCalendar) {
                Text("Google Calendar").tag(CalendarType.google)
                Text("Apple Calendar").tag(CalendarType.apple)
            }

            Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)

            Toggle("Show Notifications", isOn: $viewModel.showNotifications)
        }
    }
}

// MARK: - About Detail
struct AboutDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @StateObject private var updateService = UpdateService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Version")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }

            if updateService.updateAvailable {
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
                    } else if updateService.isInstalling {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Installing... app will reopen shortly")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Install & Reopen") {
                            Task {
                                await updateService.downloadAndInstall()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                HStack {
                    Button("Check for Updates") {
                        Task {
                            await updateService.checkForUpdates()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(updateService.isCheckingForUpdates)

                    if updateService.isCheckingForUpdates {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if updateService.checkedOnce {
                        Text("Up to date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            HStack(spacing: 16) {
                if let websiteURL = URL(string: "https://ezlander.app") {
                    Link("Website", destination: websiteURL)
                }
                if let privacyURL = URL(string: "https://ezlander.app/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                }
                if let termsURL = URL(string: "https://ezlander.app/terms") {
                    Link("Terms", destination: termsURL)
                }
            }
            .font(.caption)
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
                    Text("Connected")
                        .font(.caption)
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

// MARK: - Claude Auth Row
struct ClaudeAuthRow: View {
    let provider: AIProvider
    @Binding var useOAuth: Bool
    let isOAuthConnected: Bool
    let isAPIKeyConfigured: Bool
    let isConnecting: Bool
    let showInput: Bool
    @Binding var keyInput: String
    let onSignInOAuth: () -> Void
    let onSignOutOAuth: () -> Void
    let onAddKey: () -> Void
    let onSaveKey: () -> Void
    let onRemoveKey: () -> Void
    let onGetKey: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: provider.icon)
                    .frame(width: 24)
                    .foregroundColor(.warmAccent)

                Text(provider.displayName)
                    .fontWeight(.medium)

                Spacer()

                if isOAuthConnected || isAPIKeyConfigured {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Picker("", selection: $useOAuth) {
                Text("API Key").tag(false)
                Text("Claude Account").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if useOAuth {
                if isOAuthConnected {
                    HStack {
                        Text("Connected to Claude")
                            .font(.caption)
                            .foregroundColor(.green)
                        Spacer()
                        Button("Disconnect") {
                            onSignOutOAuth()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    HStack {
                        Button("Sign in with Claude") {
                            onSignInOAuth()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isConnecting)

                        if isConnecting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

                    Text("Use your Claude Pro/Max subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                if isAPIKeyConfigured {
                    HStack {
                        Spacer()
                        Button("Remove") {
                            onRemoveKey()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    HStack {
                        Button("Get Key") { onGetKey() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                        Button("Add Key") { onAddKey() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }

                if showInput {
                    HStack {
                        SecureField(provider.keyPlaceholder, text: $keyInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Save") { onSaveKey() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(keyInput.isEmpty)
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
                    .foregroundColor(.warmAccent)

                Text(provider.displayName)
                    .fontWeight(.medium)

                Spacer()

                if isConfigured {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                    Button("Remove") {
                        onRemoveKey()
                    }
                    .buttonStyle(.bordered)
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
    @Published var userPicture: String? = nil
    @Published var subscriptionStatus: SubscriptionStatus = .none
    @Published var googleCalendarConnected: Bool = false
    @Published var appleCalendarConnected: Bool = false
    @Published var gmailConnected: Bool = false
    @Published var defaultCalendar: CalendarType = .google {
        didSet {
            UserDefaults.standard.set(defaultCalendar.rawValue, forKey: "default_calendar")
        }
    }
    @Published var launchAtLogin: Bool = false {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launch_at_login")
        }
    }
    @Published var showNotifications: Bool = true {
        didSet {
            UserDefaults.standard.set(showNotifications, forKey: "show_notifications")
        }
    }

    // AI Provider settings
    @Published var selectedAIProvider: AIProvider = .claude {
        didSet {
            AIService.shared.currentProvider = selectedAIProvider
        }
    }

    // Dynamic key management for all providers
    @Published var showKeyInput: [AIProvider: Bool] = [:]
    @Published var keyInputs: [AIProvider: String] = [:]

    // Claude OAuth
    @Published var claudeUseOAuth: Bool = false
    @Published var isClaudeOAuthConnecting: Bool = false

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var connectedIntegrationCount: Int {
        [googleCalendarConnected, appleCalendarConnected, gmailConnected]
            .filter { $0 }.count
    }

    init() {
        loadSettings()
    }

    func loadSettings() {
        // Load user info from UserDefaults
        userEmail = UserDefaults.standard.string(forKey: "user_email") ?? ""
        userName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        userPicture = UserDefaults.standard.string(forKey: "user_picture")

        // Check if signed in via Google or Apple
        isSignedIn = OAuthService.shared.isSignedIn

        // If signed in but no name, set a default
        if isSignedIn && userName.isEmpty {
            userName = "User"
        }

        // Check integration status (Google services require Google sign in)
        googleCalendarConnected = OAuthService.shared.isSignedInWithGoogle
        gmailConnected = OAuthService.shared.isSignedInWithGoogle

        // Load preferences
        if let savedCalendar = UserDefaults.standard.string(forKey: "default_calendar"),
           let calType = CalendarType(rawValue: savedCalendar) {
            defaultCalendar = calType
        }
        launchAtLogin = UserDefaults.standard.bool(forKey: "launch_at_login")
        showNotifications = UserDefaults.standard.object(forKey: "show_notifications") as? Bool ?? true

        // Load AI provider settings
        selectedAIProvider = AIService.shared.currentProvider
        claudeUseOAuth = ClaudeOAuthService.shared.isSignedIn
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

    func signInWithClaudeOAuth() {
        isClaudeOAuthConnecting = true
        Task {
            do {
                try await ClaudeOAuthService.shared.signIn()
                await MainActor.run {
                    claudeUseOAuth = true
                    isClaudeOAuthConnecting = false
                    objectWillChange.send()
                }
            } catch {
                await MainActor.run {
                    isClaudeOAuthConnecting = false
                }
                print("Claude OAuth error: \(error)")
            }
        }
    }

    func signOutClaudeOAuth() {
        ClaudeOAuthService.shared.signOut()
        claudeUseOAuth = false
        objectWillChange.send()
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
        .frame(width: 400, height: 500)
}
