import SwiftUI

// MARK: - Onboarding Phase

private enum OnboardingPhase {
    case welcome
    case activate
}

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool

    @State private var phase: OnboardingPhase = .welcome
    @State private var email = ""
    @State private var password = ""
    @State private var referralCode = ""
    @State private var needsPassword = false
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var showReferralInput = false
    @State private var selectedPlan: PlanType = .yearly
    @State private var showSuccess = false
    @State private var iconFloat = false

    private enum PlanType {
        case monthly, yearly
    }

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)

            if showSuccess {
                successView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Group {
                    switch phase {
                    case .welcome:
                        welcomePhase
                    case .activate:
                        activatePhase
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .frame(width: 400, height: 500)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: phase)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showSuccess)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                iconFloat = true
            }
        }
    }

    // MARK: - Welcome Phase

    private var welcomePhase: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            // Hero: App icon with warm glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.warmPrimary.opacity(0.25),
                                Color.warmAccent.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 150, height: 150)
                    .blur(radius: 8)

                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .cornerRadius(16)
                    .shadow(color: Color.warmPrimary.opacity(0.25), radius: 12, y: 4)
                    .offset(y: iconFloat ? -3 : 3)
            }

            Text("Welcome to ezLander")
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 4)

            Text("Your AI-powered calendar & email assistant")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 2)

            // Pricing cards
            HStack(spacing: 12) {
                PlanCard(
                    title: "Monthly",
                    price: "$10",
                    period: "/month",
                    isSelected: selectedPlan == .monthly,
                    badge: nil
                ) {
                    withAnimation(.spring(response: 0.3)) { selectedPlan = .monthly }
                }

                PlanCard(
                    title: "Yearly",
                    price: "$99",
                    period: "/year",
                    isSelected: selectedPlan == .yearly,
                    badge: "Save 17%"
                ) {
                    withAnimation(.spring(response: 0.3)) { selectedPlan = .yearly }
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 22)

            // Subscribe button
            Button(action: subscribe) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13))
                    Text("Subscribe Now")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
            .buttonStyle(WarmGradientButtonStyle())
            .padding(.horizontal, 36)
            .padding(.top, 16)

            // Referral code toggle
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showReferralInput.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10))
                    Text("Have a referral code?")
                        .font(.caption)
                    Image(systemName: showReferralInput ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            if showReferralInput {
                TextField("Enter referral code", text: $referralCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            // Already subscribed link
            Button(action: {
                withAnimation {
                    phase = .activate
                }
            }) {
                Text("I already have a subscription")
                    .font(.callout)
                    .foregroundColor(.warmPrimary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Activate Phase

    private var activatePhase: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 36)

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.warmPrimary.opacity(0.12),
                                Color.warmAccent.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: needsPassword ? "lock.shield.fill" : "envelope.badge.shield.half.filled.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.warmPrimary, Color.warmAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(needsPassword ? "Admin Login" : "Activate Your Account")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 16)

            Text(needsPassword
                 ? "Enter your admin password to continue"
                 : "Enter the email you used to subscribe")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, 48)

            // Input fields
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("your@email.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isActivating || needsPassword)
                }

                if needsPassword {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isActivating)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let errorMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(errorMessage)
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                }

                Button(action: needsPassword ? authenticateAdmin : verifySubscription) {
                    HStack(spacing: 6) {
                        if isActivating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: needsPassword ? "lock.open.fill" : "checkmark.shield.fill")
                                .font(.system(size: 13))
                        }
                        Text(needsPassword ? "Authenticate" : "Verify & Activate")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
                .buttonStyle(WarmGradientButtonStyle())
                .disabled(email.isEmpty || (needsPassword && password.isEmpty) || isActivating)
                .padding(.top, 4)
            }
            .padding(.horizontal, 44)
            .padding(.top, 24)
            .animation(.spring(response: 0.35), value: needsPassword)
            .animation(.easeOut(duration: 0.2), value: errorMessage != nil)

            Spacer()

            // Back
            Button(action: {
                withAnimation {
                    phase = .welcome
                    needsPassword = false
                    errorMessage = nil
                    password = ""
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Back")
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.warmPrimary.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.warmPrimary, Color.warmAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("You're All Set!")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 12)

            Text("ezLander is ready to help manage\nyour calendar and email.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Button(action: completeOnboarding) {
                HStack(spacing: 6) {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
            .buttonStyle(WarmGradientButtonStyle())
            .padding(.horizontal, 64)
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Actions

    private func subscribe() {
        let trimmedCode = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCode.isEmpty,
           let url = URL(string: "https://ezlander.app/pricing?ref=\(trimmedCode)") {
            NSWorkspace.shared.open(url)
        } else if selectedPlan == .yearly,
                  let url = URL(string: "https://ezlander.app/pricing?plan=yearly") {
            NSWorkspace.shared.open(url)
        } else {
            SubscriptionService.shared.openPurchasePage()
        }
    }

    private func verifySubscription() {
        isActivating = true
        errorMessage = nil

        Task {
            do {
                try await SubscriptionService.shared.activateSubscription(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                await MainActor.run {
                    isActivating = false
                    showSuccess = true
                }
            } catch SubscriptionError.passwordRequired {
                await MainActor.run {
                    isActivating = false
                    needsPassword = true
                }
            } catch {
                await MainActor.run {
                    isActivating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func authenticateAdmin() {
        isActivating = true
        errorMessage = nil

        Task {
            do {
                try await SubscriptionService.shared.activateAdminSubscription(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                await MainActor.run {
                    isActivating = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isActivating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        isOnboardingComplete = true
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
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
                } else {
                    Color.clear
                        .frame(height: 15)
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isSelected ? Color.warmPrimary : .primary)
                    Text(period)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? Color.warmPrimary.opacity(0.08)
                          : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.warmPrimary : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
