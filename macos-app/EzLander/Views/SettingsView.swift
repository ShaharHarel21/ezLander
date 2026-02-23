import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var updateService = UpdateService.shared
    @State private var selectedSettingsTab: SettingsTab = .account

    enum SettingsTab: String, CaseIterable {
        case account
        case ai
        case integrations
        case general

        var label: String {
            switch self {
            case .account: return "Account"
            case .ai: return "AI"
            case .integrations: return "Integrations"
            case .general: return "General"
            }
        }

        var icon: String {
            switch self {
            case .account: return "person.crop.circle"
            case .ai: return "cpu"
            case .integrations: return "link"
            case .general: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: { selectedSettingsTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(selectedSettingsTab == tab ? .warmPrimary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .overlay(alignment: .bottom) {
                // Active tab underline
                GeometryReader { geo in
                    let tabWidth = geo.size.width / CGFloat(SettingsTab.allCases.count)
                    let tabIndex = CGFloat(SettingsTab.allCases.firstIndex(of: selectedSettingsTab) ?? 0)
                    Rectangle()
                        .fill(Color.warmPrimary)
                        .frame(width: tabWidth * 0.6, height: 2)
                        .cornerRadius(1)
                        .offset(x: tabWidth * tabIndex + tabWidth * 0.2)
                        .animation(.easeInOut(duration: 0.2), value: selectedSettingsTab)
                }
                .frame(height: 2)
            }

            Divider()

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedSettingsTab {
                    case .account:
                        accountTabContent
                    case .ai:
                        aiTabContent
                    case .integrations:
                        integrationsTabContent
                    case .general:
                        generalTabContent
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Account Tab
    private var accountTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Account") {
                if viewModel.isSignedIn {
                    signedInView
                } else {
                    signInButtons
                }
            }

            SettingsSection(title: "Subscription") {
                subscriptionView
            }
        }
    }

    // MARK: - AI Tab
    private var aiTabContent: some View {
        SettingsSection(title: "AI Provider") {
            aiProviderView
        }
    }

    // MARK: - Integrations Tab
    private var integrationsTabContent: some View {
        SettingsSection(title: "Integrations") {
            integrationsView
        }
    }

    // MARK: - General Tab
    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Preferences") {
                preferencesView
            }

            SettingsSection(title: "Menu Bar Icon") {
                menuBarIconPicker
            }

            SettingsSection(title: "Email Swipe Actions") {
                swipeActionsView
            }

            SettingsSection(title: "Keyboard Shortcuts") {
                keyboardShortcutsView
            }

            SettingsSection(title: "About") {
                aboutView
            }
        }
    }

    // MARK: - Signed In View
    private var signedInView: some View {
        HStack {
            // Profile picture
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

    // MARK: - Sign In Buttons
    private var signInButtons: some View {
        VStack(spacing: 12) {
            Button(action: viewModel.signInWithGoogle) {
                HStack {
                    if viewModel.isSigningIn {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "globe")
                    }
                    Text("Sign in with Google")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isSigningIn)

            Button(action: viewModel.signInWithApple) {
                HStack {
                    if viewModel.isSigningIn {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "apple.logo")
                    }
                    Text("Sign in with Apple")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(viewModel.isSigningIn)
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

    // MARK: - Menu Bar Icon Picker
    private var menuBarIconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose an icon for the menu bar")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(MenuBarIconOption.allCases) { option in
                    Button(action: { viewModel.selectedMenuBarIcon = option }) {
                        VStack(spacing: 4) {
                            Image(systemName: option.rawValue)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .background(
                                    viewModel.selectedMenuBarIcon == option
                                        ? Color.warmPrimary.opacity(0.15)
                                        : Color.clear
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            viewModel.selectedMenuBarIcon == option
                                                ? Color.warmPrimary
                                                : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                            Text(option.displayName)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(viewModel.selectedMenuBarIcon == option ? .warmPrimary : .primary)
                }
            }
        }
    }

    // MARK: - Swipe Actions View
    private var swipeActionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Swipe Right", selection: $viewModel.swipeRightAction) {
                ForEach(EmailSwipeAction.allCases) { action in
                    Label(action.displayName, systemImage: action.icon).tag(action)
                }
            }

            Picker("Swipe Left", selection: $viewModel.swipeLeftAction) {
                ForEach(EmailSwipeAction.allCases) { action in
                    Label(action.displayName, systemImage: action.icon).tag(action)
                }
            }
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
    @State private var showSaveSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: provider.icon)
                    .frame(width: 24)
                    .foregroundColor(.warmAccent)

                Text(provider.displayName)
                    .fontWeight(.medium)

                Spacer()

                if showSaveSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Saved")
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
                } else if isConfigured {
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
                        withAnimation {
                            showSaveSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showSaveSuccess = false
                            }
                        }
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
    @Published var isSigningIn: Bool = false
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
    @Published var selectedMenuBarIcon: MenuBarIconOption = .starFill {
        didSet {
            UserDefaults.standard.set(selectedMenuBarIcon.rawValue, forKey: "menu_bar_icon")
            NotificationCenter.default.post(name: Notification.Name("MenuBarIconChanged"), object: nil)
        }
    }
    @Published var swipeRightAction: EmailSwipeAction = .archive {
        didSet {
            UserDefaults.standard.set(swipeRightAction.rawValue, forKey: "swipe_right_action")
        }
    }
    @Published var swipeLeftAction: EmailSwipeAction = .delete {
        didSet {
            UserDefaults.standard.set(swipeLeftAction.rawValue, forKey: "swipe_left_action")
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

        // Check Apple Calendar: persisted disconnect flag + actual OS authorization
        let intentionallyDisconnected = UserDefaults.standard.bool(forKey: "apple_calendar_disconnected")
        appleCalendarConnected = !intentionallyDisconnected && AppleCalendarService.shared.isAuthorized

        // Load preferences
        if let savedCalendar = UserDefaults.standard.string(forKey: "default_calendar"),
           let calType = CalendarType(rawValue: savedCalendar) {
            defaultCalendar = calType
        }
        launchAtLogin = UserDefaults.standard.bool(forKey: "launch_at_login")
        showNotifications = UserDefaults.standard.object(forKey: "show_notifications") as? Bool ?? true

        // Load menu bar icon preference
        if let savedIcon = UserDefaults.standard.string(forKey: "menu_bar_icon"),
           let icon = MenuBarIconOption(rawValue: savedIcon) {
            selectedMenuBarIcon = icon
        }

        // Load swipe action preferences
        if let savedRight = UserDefaults.standard.string(forKey: "swipe_right_action"),
           let action = EmailSwipeAction(rawValue: savedRight) {
            swipeRightAction = action
        }
        if let savedLeft = UserDefaults.standard.string(forKey: "swipe_left_action"),
           let action = EmailSwipeAction(rawValue: savedLeft) {
            swipeLeftAction = action
        }

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
        isSigningIn = true
        Task {
            do {
                try await OAuthService.shared.signInWithGoogle()
                await MainActor.run {
                    isSigningIn = false
                    loadSettings()
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                }
                print("Google sign in error: \(error)")
            }
        }
    }

    func signInWithApple() {
        isSigningIn = true
        Task {
            do {
                try await OAuthService.shared.signInWithApple()
                await MainActor.run {
                    isSigningIn = false
                    loadSettings()
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                }
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
        UserDefaults.standard.set(false, forKey: "apple_calendar_disconnected")
        AppleCalendarService.shared.requestAccess { [weak self] granted in
            DispatchQueue.main.async {
                self?.appleCalendarConnected = granted
            }
        }
    }

    func disconnectAppleCalendar() {
        UserDefaults.standard.set(true, forKey: "apple_calendar_disconnected")
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
