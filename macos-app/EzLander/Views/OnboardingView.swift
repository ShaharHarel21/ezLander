import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
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
            title: "Start Your Free Trial",
            description: "Get 7 days of unlimited access. No credit card required.",
            action: .startTrial
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.warmPrimary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            Spacer()

            // Step content
            VStack(spacing: 24) {
                if currentStep == 0 {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                } else {
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.warmPrimary, Color.warmAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

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

            Spacer()

            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

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
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
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

        case .startTrial:
            Button(action: startTrial) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Start Free Trial")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 48)
        }
    }

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

    private func startTrial() {
        Task {
            await SubscriptionService.shared.startTrial()
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
    case startTrial
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
