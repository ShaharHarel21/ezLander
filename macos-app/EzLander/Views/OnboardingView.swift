import SwiftUI

private enum AccessMode: String, CaseIterable, Identifiable {
    case signIn
    case createAccount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn: return "Sign In"
        case .createAccount: return "Create Account"
        }
    }

    var subtitle: String {
        switch self {
        case .signIn:
            return "Use the email tied to your subscription."
        case .createAccount:
            return "Create your ezLander account with the same billing email."
        }
    }
}

private enum AccessTier {
    case pro
    case max
}

struct OnboardingView: View {
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var proxyService = ProxyAIService.shared

    @State private var accessMode: AccessMode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var referralCode = ""
    @State private var isYearly = true
    @State private var selectedTier: AccessTier = .pro
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                statusMessage

                if shouldShowSubscriptionRefresh {
                    subscriptionRefreshCard
                } else {
                    authCard
                }

                pricingCard
            }
            .padding(20)
        }
        .background(Color.surfacePrimary)
        .onAppear {
            if email.isEmpty {
                email = subscriptionService.accountEmail.isEmpty
                    ? subscriptionService.subscribedEmail
                    : subscriptionService.accountEmail
            }
        }
    }

    private var shouldShowSubscriptionRefresh: Bool {
        proxyService.isAuthenticated && !subscriptionService.isSubscribed
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.warmPrimary.opacity(0.22),
                                Color.warmAccent.opacity(0.10),
                                .clear
                            ],
                            center: .center,
                            startRadius: 16,
                            endRadius: 84
                        )
                    )
                    .frame(width: 150, height: 150)
                    .blur(radius: 10)

                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)
                    .cornerRadius(16)
                    .shadow(color: Color.warmPrimary.opacity(0.24), radius: 10, y: 4)
            }

            Text(shouldShowSubscriptionRefresh ? "Finish Unlocking ezLander" : "Welcome to ezLander")
                .font(.system(size: 24, weight: .bold))

            Text("Sign in inside the app. Active subscribers get included AI access with no API keys and no model setup.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let infoMessage {
            statusPill(text: infoMessage, color: Color.green, icon: "checkmark.circle.fill")
        } else if let errorMessage {
            statusPill(text: errorMessage, color: Color.red, icon: "exclamationmark.triangle.fill")
        }
    }

    private func statusPill(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }

    private var authCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Access", selection: $accessMode) {
                ForEach(AccessMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                Text(accessMode.title)
                    .font(.headline)
                Text(accessMode.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 10) {
                if accessMode == .createAccount {
                    TextField("Your name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isWorking)
                }

                TextField("you@example.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isWorking)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isWorking)
            }

            Button(action: submit) {
                HStack(spacing: 8) {
                    if isWorking {
                        ProgressView()
                            .scaleEffect(0.75)
                    } else {
                        Image(systemName: accessMode == .signIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                            .font(.system(size: 13))
                    }
                    Text(accessMode == .signIn ? "Sign In" : "Create Account")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(WarmGradientButtonStyle())
            .disabled(isWorking || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || (accessMode == .createAccount && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

            Text("After you sign in, ezLander checks your subscription automatically and unlocks the app here in the popover.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var subscriptionRefreshCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Signed in as")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(subscriptionService.accountName.isEmpty ? "ezLander Account" : subscriptionService.accountName)
                    .font(.headline)
                Text(subscriptionService.accountEmail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Your account is connected. Start or renew a subscription below, then refresh access here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: refreshAccess) {
                    if isWorking {
                        ProgressView()
                            .scaleEffect(0.75)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    } else {
                        Text("Refresh Access")
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                }
                .buttonStyle(WarmGradientButtonStyle())
                .disabled(isWorking)

                Button("Sign Out") {
                    subscriptionService.deactivateSubscription()
                    infoMessage = nil
                    errorMessage = nil
                    password = ""
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Subscription")
                .font(.headline)

            HStack(spacing: 12) {
                AccessPlanCard(
                    title: "Pro",
                    price: isYearly ? "$8.25" : "$10",
                    period: "/month",
                    badge: "2M tokens",
                    isSelected: selectedTier == .pro
                ) {
                    selectedTier = .pro
                }

                AccessPlanCard(
                    title: "Max",
                    price: isYearly ? "$16.58" : "$20",
                    period: "/month",
                    badge: "5M tokens",
                    isSelected: selectedTier == .max
                ) {
                    selectedTier = .max
                }
            }

            HStack(spacing: 8) {
                Text("Monthly")
                    .font(.caption)
                    .foregroundColor(!isYearly ? .primary : .secondary)

                Toggle("", isOn: $isYearly)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(0.75)

                Text("Yearly")
                    .font(.caption)
                    .foregroundColor(isYearly ? .primary : .secondary)

                if isYearly {
                    Text("Save 17%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                }
            }

            TextField("Referral code (optional)", text: $referralCode)
                .textFieldStyle(.roundedBorder)
                .disabled(isWorking)

            Button(action: subscribe) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13))
                    Text(subscriptionService.isSubscribed ? "Manage Subscription" : "Subscribe Now")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(WarmGradientButtonStyle())
            .disabled(isWorking)

            Text("Billing opens on ezlander.app, then you return here and tap Refresh Access.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func submit() {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        isWorking = true
        errorMessage = nil
        infoMessage = nil

        Task {
            do {
                if accessMode == .signIn {
                    try await subscriptionService.signInToApp(email: normalizedEmail, password: password)
                    await MainActor.run {
                        isWorking = false
                        infoMessage = "Subscription active. ezLander is unlocked."
                    }
                } else {
                    try await subscriptionService.registerAppAccount(name: trimmedName, email: normalizedEmail, password: password)
                    await MainActor.run {
                        isWorking = false
                        infoMessage = "Account created and subscription verified."
                    }
                }
            } catch AppSessionError.noActiveSubscription {
                await MainActor.run {
                    isWorking = false
                    infoMessage = "Your account is ready. Subscribe below, then tap Refresh Access."
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorMessage = friendlyMessage(for: error)
                }
            }
        }
    }

    private func refreshAccess() {
        let targetEmail = subscriptionService.accountEmail.isEmpty
            ? email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            : subscriptionService.accountEmail

        guard !targetEmail.isEmpty else {
            errorMessage = "Sign in first so ezLander knows which subscription to refresh."
            return
        }

        isWorking = true
        errorMessage = nil
        infoMessage = nil

        Task {
            do {
                try await subscriptionService.activateSubscription(email: targetEmail)
                await MainActor.run {
                    isWorking = false
                    infoMessage = "Subscription active. ezLander is unlocked."
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorMessage = friendlyMessage(for: error)
                }
            }
        }
    }

    private func subscribe() {
        let tierKey = selectedTier == .pro ? "pro" : "max"
        let billingKey = isYearly ? "yearly" : "monthly"
        let trimmedCode = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)

        var urlString = "https://ezlander.app/pricing?plan=\(tierKey)_\(billingKey)"
        if !trimmedCode.isEmpty {
            urlString += "&ref=\(trimmedCode)"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let sessionError = error as? AppSessionError {
            return sessionError.localizedDescription
        }
        if let subscriptionError = error as? SubscriptionError {
            switch subscriptionError {
            case .noActiveSubscription:
                return "No active subscription found for this account yet."
            case .networkError:
                return "Couldn’t reach ezLander. Check your connection and try again."
            case .invalidResponse:
                return "ezLander returned an unexpected response. Try again in a moment."
            case .passwordRequired, .invalidPassword:
                return "Admin sign-in requires valid admin credentials."
            }
        }

        return error.localizedDescription
    }
}

private struct AccessPlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(badge)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
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

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(isSelected ? .warmPrimary : .primary)
                    Text(period)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.warmPrimary.opacity(0.08) : Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.warmPrimary : Color.secondary.opacity(0.18), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
        .frame(width: 420, height: 520)
}
