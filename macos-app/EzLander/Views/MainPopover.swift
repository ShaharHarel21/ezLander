import SwiftUI

struct MainPopover: View {
    @StateObject private var viewModel = MainPopoverViewModel()
    @State private var selectedTab: Tab = .chat

    enum Tab {
        case chat, calendar, email, settings
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            contentView

            Divider()

            // Tab bar
            tabBar
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.accentColor)

            Text("ezLander")
                .font(.headline)

            Spacer()

            if viewModel.isSubscribed {
                Label("Pro", systemImage: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .chat:
            ChatView()
        case .calendar:
            CalendarQuickView()
        case .email:
            EmailQuickView()
        case .settings:
            SettingsView()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(tab: .chat, icon: "bubble.left.and.bubble.right.fill", label: "Chat")
            tabButton(tab: .calendar, icon: "calendar", label: "Calendar")
            tabButton(tab: .email, icon: "envelope.fill", label: "Email")
            tabButton(tab: .settings, icon: "gearshape.fill", label: "Settings")
        }
        .padding(.vertical, 8)
    }

    private func tabButton(tab: Tab, icon: String, label: String) -> some View {
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model
class MainPopoverViewModel: ObservableObject {
    @Published var isSubscribed: Bool = false

    private let subscriptionService = SubscriptionService.shared

    init() {
        checkSubscription()
    }

    func checkSubscription() {
        Task {
            let status = await subscriptionService.checkSubscriptionStatus()
            await MainActor.run {
                isSubscribed = status
            }
        }
    }
}

// MARK: - Quick Views
struct CalendarQuickView: View {
    var body: some View {
        VStack {
            Text("Upcoming Events")
                .font(.headline)
                .padding()

            List {
                Text("Loading events...")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct EmailQuickView: View {
    var body: some View {
        VStack {
            Text("Recent Emails")
                .font(.headline)
                .padding()

            List {
                Text("Loading emails...")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    MainPopover()
}
