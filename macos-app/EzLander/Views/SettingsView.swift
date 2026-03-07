import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var updateService = UpdateService.shared
    @ObservedObject private var themeManager = ThemeManager.shared
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
                        .overlay(alignment: .bottom) {
                            if selectedSettingsTab == tab {
                                Rectangle()
                                    .fill(Color.warmPrimary)
                                    .frame(height: 2)
                            }
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.70), value: selectedSettingsTab)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

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
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedSettingsTab)
            }
        }
    }

    // MARK: - Account Tab
    private var accountTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Subscription") {
                licenseInfoView
            }

            if !viewModel.referralCode.isEmpty {
                SettingsSection(title: "Referrals") {
                    referralInfoView
                }
            }
        }
    }

    // MARK: - Referral Info View
    private var referralInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Referral code row
            HStack {
                Text(viewModel.referralCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)

                Spacer()

                Button(viewModel.codeCopied ? "Copied!" : "Copy") {
                    viewModel.copyReferralCode()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Share") {
                    viewModel.shareReferralCode()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // Stats row
            HStack(spacing: 16) {
                VStack {
                    Text("\(viewModel.referralsCount)")
                        .font(.headline)
                    Text("Referrals")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(viewModel.referralCreditsDays)")
                        .font(.headline)
                    Text("Days Earned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(max(0, 12 - viewModel.referralsCount))")
                        .font(.headline)
                    Text("Slots Left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Share your code with friends. When they subscribe, you earn 7 days of free access!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - AI Tab
    private var aiTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "AI Access") {
                aiModelView
            }

            SettingsSection(title: "Usage") {
                usageView
            }
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
            SettingsSection(title: "Appearance") {
                themePickerView
            }

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

    // MARK: - License Info View
    private var licenseInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(viewModel.accountName.isEmpty ? "Signed in" : viewModel.accountName)
                        .font(.headline)
                    Text(viewModel.licenseEmail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Active")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
            }

            Text("ezLander AI is included with your subscription. Billing is managed through ezlander.app.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Button("Billing & Plans") {
                    viewModel.manageSubscription()
                }
                .buttonStyle(.bordered)

                Button("Sign Out on This Mac") {
                    viewModel.signOutOfEzLander()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
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

    // MARK: - AI Model View
    private var aiModelView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Managed AI", systemImage: "brain")
                .font(.headline)

            Text("All AI requests are processed through ezLander's managed server-side setup. No API key or model selection is required in the app.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Usage View
    private var usageView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tier badge
            if !viewModel.tier.isEmpty {
                HStack {
                    Text(viewModel.tier.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.warmPrimary, Color.warmAccent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )

                    Spacer()

                    if viewModel.tokensLimit > 0 {
                        Text("\(viewModel.formattedTokensUsed) / \(viewModel.formattedTokensLimit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Progress bar
            if viewModel.tokensLimit > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: viewModel.usagePercentage > 0.9
                                        ? [.red, .orange]
                                        : [Color.warmPrimary, Color.warmAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(viewModel.usagePercentage, 1.0), height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(viewModel.formattedTokensRemaining) tokens remaining this month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Theme Picker View
    private var themePickerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose how ezLander appears")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Theme", selection: $themeManager.selectedMode) {
                ForEach(ThemeMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
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
                .tint(Color.warmPrimary)

            Toggle("Show Notifications", isOn: $viewModel.showNotifications)
                .tint(Color.warmPrimary)
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
                    let isSelected = viewModel.selectedMenuBarIcon == option
                    Button(action: { viewModel.selectedMenuBarIcon = option }) {
                        VStack(spacing: 4) {
                            Image(systemName: option.displayIcon)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isSelected ? Color.warmPrimary.opacity(0.12) : Color.clear)
                                )
                                .animation(.easeInOut(duration: 0.15), value: isSelected)
                            Text(option.displayName)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(isSelected ? .warmPrimary : .primary)
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
                .padding(10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.10))
                        HStack {
                            RoundedRectangle(cornerRadius: 1.5).fill(Color.green).frame(width: 3)
                            Spacer()
                        }.clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                )
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
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(8)

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
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

// MARK: - View Model
class SettingsViewModel: ObservableObject {
    @Published var accountName: String = ""
    @Published var licenseEmail: String = ""
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
    @Published var selectedMenuBarIcon: MenuBarIconOption = .ezLander {
        didSet {
            UserDefaults.standard.set(selectedMenuBarIcon.rawValue, forKey: "menu_bar_icon")
            NotificationCenter.default.post(name: MenuBarController.menuBarIconChangedNotification, object: nil)
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

    // Referral
    @Published var referralCode: String = ""
    @Published var referralCreditsDays: Int = 0
    @Published var referralsCount: Int = 0
    @Published var codeCopied: Bool = false

    // Usage
    @Published var tier: String = ""
    @Published var tokensUsed: Int = 0
    @Published var tokensLimit: Int = 0
    @Published var tokensRemaining: Int = 0

    var formattedTokensUsed: String { formatTokenCount(tokensUsed) }
    var formattedTokensLimit: String { formatTokenCount(tokensLimit) }
    var formattedTokensRemaining: String { formatTokenCount(tokensRemaining) }

    var usagePercentage: CGFloat {
        guard tokensLimit > 0 else { return 0 }
        return CGFloat(tokensUsed) / CGFloat(tokensLimit)
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000.0
            return String(format: "%.1fM", millions)
        } else if count >= 1_000 {
            let thousands = Double(count) / 1_000.0
            return String(format: "%.0fK", thousands)
        }
        return "\(count)"
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    init() {
        loadSettings()
    }

    func loadSettings() {
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

        // Load usage info
        tier = SubscriptionService.shared.tier
        tokensUsed = SubscriptionService.shared.tokensUsed
        tokensLimit = SubscriptionService.shared.tokensLimit
        tokensRemaining = SubscriptionService.shared.tokensRemaining

        // Fetch fresh usage data
        Task {
            await ProxyAIService.shared.fetchUsage()
            await MainActor.run {
                tokensUsed = ProxyAIService.shared.tokensUsed
                tokensLimit = ProxyAIService.shared.tokensLimit
                tokensRemaining = ProxyAIService.shared.tokensRemaining
                tier = ProxyAIService.shared.tier
            }
        }

        // Load subscription info
        accountName = SubscriptionService.shared.accountName
        licenseEmail = SubscriptionService.shared.subscribedEmail

        // Load referral info
        referralCode = SubscriptionService.shared.referralCode
        referralCreditsDays = SubscriptionService.shared.referralCreditsDays
        referralsCount = SubscriptionService.shared.referralsCount

        if referralCode.isEmpty && !licenseEmail.isEmpty {
            Task {
                try? await SubscriptionService.shared.fetchReferralCode()
                await MainActor.run {
                    referralCode = SubscriptionService.shared.referralCode
                    referralCreditsDays = SubscriptionService.shared.referralCreditsDays
                    referralsCount = SubscriptionService.shared.referralsCount
                }
            }
        }
    }

    func signOutOfEzLander() {
        SubscriptionService.shared.deactivateSubscription()
    }

    func manageSubscription() {
        SubscriptionService.shared.openPurchasePage()
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

    // MARK: - Referral

    func copyReferralCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(referralCode, forType: .string)
        codeCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.codeCopied = false
        }
    }

    func shareReferralCode() {
        let shareText = "Check out ezLander! Use my referral code \(referralCode) for a 14-day free trial: https://ezlander.app/pricing?ref=\(referralCode)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(shareText, forType: .string)
    }

}

// MARK: - Types
enum CalendarType: String, CaseIterable {
    case google
    case apple
}

#Preview {
    SettingsView()
        .frame(width: 400, height: 600)
}
