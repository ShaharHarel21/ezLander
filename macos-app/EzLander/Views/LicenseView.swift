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
    @Binding var isLicenseActivated: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .cornerRadius(12)

            Spacer().frame(height: 20)

            // Title
            Text("Subscription Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("Your subscription has expired. Renew or verify your email to continue.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            // Referral code input
            VStack(alignment: .leading, spacing: 4) {
                Text("Have a referral code?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter referral code", text: $referralCode)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 48)

            Spacer().frame(height: 12)

            // Subscribe button
            Button(action: {
                let trimmedCode = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedCode.isEmpty,
                   let url = URL(string: "https://ezlander.app/pricing?ref=\(trimmedCode)") {
                    NSWorkspace.shared.open(url)
                } else {
                    SubscriptionService.shared.openPurchasePage()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Renew Subscription — $10/month")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(WarmGradientButtonStyle())
            .padding(.horizontal, 48)

            Spacer().frame(height: 24)

            // Email verification
            VStack(alignment: .leading, spacing: 8) {
                Text("Already subscribed? Enter your email:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("your@email.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isActivating || needsPassword)

                    Button(action: activate) {
                        if isActivating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Text("Verify")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || isActivating || needsPassword)
                }

                if needsPassword {
                    HStack {
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isActivating)

                        Button(action: authenticateAdmin) {
                            if isActivating {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            } else {
                                Text("Authenticate")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(password.isEmpty || isActivating)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 400, height: 500)
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
}

#Preview {
    LicenseView(isLicenseActivated: .constant(false))
}
