import SwiftUI

/// Shown to returning users whose subscription has expired.
/// First-time users see OnboardingView instead.
struct LicenseView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var referralCode: String = ""
    @State private var needsPassword: Bool = false
    @State private var isActivating: Bool = false
    @State private var errorMessage: String?
    @State private var showReferralField: Bool = false
    @State private var selectedTier: TierType = .pro
    @State private var isYearly: Bool = false
    @Binding var isLicenseActivated: Bool

    private enum TierType {
        case pro, max
    }

    var body: some View {
        VStack(spacing: 0) {
            // Warm gradient accent bar
            LinearGradient(
                colors: [Color.warmPrimary, Color.warmAccent],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // App icon
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .cornerRadius(12)
                        .shadow(color: Color.warmPrimary.opacity(0.25), radius: 8, y: 4)

                    Spacer().frame(height: 14)

                    // Welcome text
                    Text("Welcome Back!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.warmPrimary, Color.warmAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Spacer().frame(height: 6)

                    Text("We missed you! Reactivate to pick up\nright where you left off.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Spacer().frame(height: 20)

                    // Tier selection
                    HStack(spacing: 10) {
                        PricingCard(
                            title: "Pro",
                            price: isYearly ? "$8.25" : "$10",
                            period: "/month",
                            isSelected: selectedTier == .pro,
                            badge: "2M tokens"
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTier = .pro
                            }
                        }

                        PricingCard(
                            title: "Max",
                            price: isYearly ? "$16.58" : "$20",
                            period: "/month",
                            isSelected: selectedTier == .max,
                            badge: "5M tokens"
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTier = .max
                            }
                        }
                    }
                    .padding(.horizontal, 32)

                    // Monthly/Yearly toggle
                    HStack(spacing: 8) {
                        Text("Monthly")
                            .font(.caption)
                            .foregroundColor(!isYearly ? .primary : .secondary)
                        Toggle("", isOn: $isYearly)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .scaleEffect(0.7)
                        Text("Yearly")
                            .font(.caption)
                            .foregroundColor(isYearly ? .primary : .secondary)
                        if isYearly {
                            Text("Save 17%")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.top, 4)

                    Spacer().frame(height: 14)

                    // Subscribe button
                    Button(action: openPurchasePage) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.subheadline)
                            Text("Reactivate Subscription")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(WarmGradientButtonStyle())
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 10)

                    // Referral code toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showReferralField.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "ticket")
                                .font(.caption)
                            Text("Have a referral code?")
                                .font(.caption)
                            Image(systemName: showReferralField ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundColor(.warmPrimary)
                    }
                    .buttonStyle(.plain)

                    if showReferralField {
                        TextField("Enter referral code", text: $referralCode)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 64)
                            .padding(.top, 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer().frame(height: 16)

                    // Divider
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                        Text("Already subscribed?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize()
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 14)

                    // Email verification
                    VStack(spacing: 8) {
                        // Email row
                        HStack(spacing: 8) {
                            Image(systemName: "envelope")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                                .frame(width: 16)
                            TextField("your@email.com", text: $email)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .disabled(isActivating || needsPassword)

                            Button(action: activate) {
                                Group {
                                    if isActivating && !needsPassword {
                                        ProgressView()
                                            .scaleEffect(0.55)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Text("Verify")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                }
                                .frame(width: 48)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.warmPrimary)
                            .controlSize(.small)
                            .disabled(email.isEmpty || isActivating || needsPassword)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        )

                        // Password row (admin accounts)
                        if needsPassword {
                            HStack(spacing: 8) {
                                Image(systemName: "lock")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 13))
                                    .frame(width: 16)
                                SecureField("Admin password", text: $password)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .disabled(isActivating)

                                Button(action: authenticateAdmin) {
                                    Group {
                                        if isActivating {
                                            ProgressView()
                                                .scaleEffect(0.55)
                                                .frame(width: 14, height: 14)
                                        } else {
                                            Text("Login")
                                                .font(.system(size: 11, weight: .medium))
                                        }
                                    }
                                    .frame(width: 48)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.warmPrimary)
                                .controlSize(.small)
                                .disabled(password.isEmpty || isActivating)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Error message
                        if let errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.caption)
                                Text(friendlyError(errorMessage))
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundColor(Color.warmPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.warmPrimary.opacity(0.08))
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 20)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 400, height: 500)
        .animation(.easeInOut(duration: 0.25), value: needsPassword)
        .animation(.easeInOut(duration: 0.25), value: errorMessage == nil)
        .animation(.easeInOut(duration: 0.2), value: showReferralField)
    }

    // MARK: - Actions

    private func openPurchasePage() {
        let tierKey = selectedTier == .pro ? "pro" : "max"
        let billingKey = isYearly ? "yearly" : "monthly"
        let planParam = "\(tierKey)_\(billingKey)"
        let trimmedCode = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)

        var urlString = "https://ezlander.app/pricing?plan=\(planParam)"
        if !trimmedCode.isEmpty {
            urlString += "&ref=\(trimmedCode)"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func activate() {
        isActivating = true
        errorMessage = nil

        Task {
            do {
                try await SubscriptionService.shared.activateSubscription(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                await MainActor.run {
                    isActivating = false
                    isLicenseActivated = true
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
                    isLicenseActivated = true
                }
            } catch {
                await MainActor.run {
                    isActivating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func friendlyError(_ error: String) -> String {
        if error.contains("No active subscription") {
            return "We couldn't find an active subscription for this email. Try subscribing above!"
        } else if error.contains("Invalid password") {
            return "That password doesn't look right. Give it another try?"
        } else if error.contains("Network error") || error.contains("connection") {
            return "Having trouble connecting. Check your internet and try again."
        } else if error.contains("Unexpected response") {
            return "Something went wrong on our end. Please try again in a moment."
        }
        return error
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let title: String
    let price: String
    let period: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.warmAccent)
                        .cornerRadius(4)
                } else {
                    Color.clear.frame(height: 15)
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(price)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? Color.warmPrimary : .primary)
                    Text(period)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.warmPrimary.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.warmPrimary : Color.secondary.opacity(0.2),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LicenseView(isLicenseActivated: .constant(false))
}
