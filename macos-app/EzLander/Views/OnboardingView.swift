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
                        .fill(index < currentStep ? Color.warmPrimary :
                              index == currentStep ? Color.warmPrimary.opacity(0.70) :
                              Color.secondary.opacity(0.20))
                        .frame(width: index == currentStep ? 11 : 8,
                               height: index == currentStep ? 11 : 8)
                        .overlay(
                            index == currentStep ?
                                AnyView(Circle().strokeBorder(Color.warmPrimary.opacity(0.50), lineWidth: 0.75)) :
                                AnyView(EmptyView())
                        )
                        .shadow(color: index <= currentStep ? Color.warmPrimary.opacity(0.40) : .clear, radius: 5)
                        .animation(.spring(response: 0.30, dampingFraction: 0.55), value: currentStep)
                }
            }
            .padding(.top, 20)

            Spacer()

            // Step content
            VStack(spacing: 24) {
                // Icon area with glass container
                ZStack {
                    // Concentric rings (outermost first, behind glass circle)
                    Circle()
                        .strokeBorder(Color.warmAccent.opacity(0.15), lineWidth: 1.0)
                        .frame(width: 136, height: 136)
                    Circle()
                        .strokeBorder(Color.warmPrimary.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 118, height: 118)

                    // Glass background circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.warmSoft.opacity(0.10)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.20), lineWidth: 1.0))
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.warmPrimary.opacity(0.15), radius: 20)

                    // Icon on top
                    if currentStep == 0 {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                    } else {
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.warmPrimary, Color.warmAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
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
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 20).fill(Color.warmSoft.opacity(0.06))
                    RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.10), radius: 20)
            )
            .padding(.horizontal, 16)

            Spacer()

            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 12).fill(Color.warmSoft.opacity(0.06)))
                    )
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
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
                    .buttonStyle(WarmGradientButtonStyle())
                    .shadow(color: Color.warmPrimary.opacity(0.30), radius: 12)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(WarmGradientButtonStyle())
                    .shadow(color: Color.warmPrimary.opacity(0.30), radius: 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow))
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
                    .padding(.vertical, 6)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 14).fill(Color.warmSoft.opacity(0.10))
                        RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                    }
                )
                .buttonStyle(.plain)
                .foregroundColor(.primary)

                Button(action: connectAppleCalendar) {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Connect Apple Calendar")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 14).fill(Color.warmSoft.opacity(0.10))
                        RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                    }
                )
                .buttonStyle(.plain)
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 48)

        case .connectEmail:
            Button(action: connectGmail) {
                HStack {
                    Image(systemName: "envelope")
                    Text("Connect Gmail")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14).fill(Color.warmSoft.opacity(0.10))
                    RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                }
            )
            .buttonStyle(.plain)
            .foregroundColor(.primary)
            .padding(.horizontal, 48)

        case .startTrial:
            Button(action: startTrial) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Start Free Trial")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(WarmGradientButtonStyle())
            .shadow(color: Color.warmPrimary.opacity(0.30), radius: 12)
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
