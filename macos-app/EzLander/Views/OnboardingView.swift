import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var email: String = ""
    @State private var showEmailInput: Bool = false
    @State private var isActivating: Bool = false
    @State private var errorMessage: String?
    @Binding var isOnboardingComplete: Bool

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "brain.head.profile",
            title: "Welcome to ezLander",
            description: "Your AI-powered assistant for calendar and email management, right in your menu bar."
        ),
        OnboardingStep(
            icon: "calendar.badge.plus",
            title: "Connect Your Calendar",
            description: "Link Google Calendar or Apple Calendar to let AI help manage your schedule.",
            action: .connectCalendar
        ),
        OnboardingStep(
            icon: "envelope.badge",
            title: "Connect Your Email",
            description: "Connect Gmail to draft, send, and search emails with AI assistance.",
            action: .connectEmail
        ),
        OnboardingStep(
            icon: "crown.fill",
            title: "Subscribe to ezLander Pro",
            description: "Get unlimited access to all features for just $10/month.",
            action: .subscribe
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.warmPrimary : Color.secondary.opacity(0.20))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
            .padding(.top, 20)

            Spacer()

            // Step content
            VStack(spacing: 24) {
                // Icon area
                Group {
                    if currentStep == 0 {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                    } else {
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 40))
                            .foregroundColor(.warmPrimary)
                    }
                }
                .frame(height: 80)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: currentStep)

                Text(steps[currentStep].title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(steps[currentStep].description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let action = steps[currentStep].action {
                    actionButton(for: action)
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)

            Spacer()

            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                            showEmailInput = false
                            errorMessage = nil
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                // Steps 1-3: Next/Skip buttons. Step 4 (subscribe): no skip
                if currentStep < steps.count - 1 {
                    Button("Skip") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(WarmGradientButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 400, height: 500)
    }

    @ViewBuilder
    private func actionButton(for action: OnboardingAction) -> some View {
        switch action {
        case .connectCalendar:
            VStack(spacing: 12) {
                Button(action: connectGoogleCalendar) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Connect Google Calendar")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: connectAppleCalendar) {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Connect Apple Calendar")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 48)

        case .connectEmail:
            Button(action: connectGmail) {
                HStack {
                    Image(systemName: "envelope")
                    Text("Connect Gmail")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 48)

        case .subscribe:
            VStack(spacing: 16) {
                // Subscribe button
                Button(action: {
                    SubscriptionService.shared.openPurchasePage()
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Subscribe — $10/month")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WarmGradientButtonStyle())
                .padding(.horizontal, 48)

                // Toggle email input
                if !showEmailInput {
                    Button(action: {
                        withAnimation { showEmailInput = true }
                    }) {
                        Text("I already subscribed")
                            .font(.caption)
                            .foregroundColor(.warmPrimary)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Email verification input
                    VStack(spacing: 8) {
                        HStack {
                            TextField("your@email.com", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isActivating)

                            Button(action: verifySubscription) {
                                if isActivating {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Text("Verify")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(email.isEmpty || isActivating)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 48)
                }
            }
        }
    }

    // MARK: - Actions

    private func connectGoogleCalendar() {
        Task {
            try? await GoogleCalendarService.shared.authorize()
        }
    }

    private func connectAppleCalendar() {
        AppleCalendarService.shared.requestAccess { _ in }
    }

    private func connectGmail() {
        Task {
            try? await GmailService.shared.authorize()
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
                    completeOnboarding()
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

// MARK: - Models
struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
    var action: OnboardingAction?
}

enum OnboardingAction {
    case connectCalendar
    case connectEmail
    case subscribe
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
