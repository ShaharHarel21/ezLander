import Foundation

struct User: Codable {
    let id: String
    var email: String
    var name: String
    var picture: String?
    var subscription: UserSubscription?
    var preferences: UserPreferences

    init(id: String, email: String, name: String, picture: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.picture = picture
        self.preferences = UserPreferences()
    }
}

// MARK: - Subscription
struct UserSubscription: Codable {
    let plan: Plan
    let status: Status
    let startDate: Date
    let expiresAt: Date?
    let stripeCustomerId: String?

    enum Plan: String, Codable {
        case trial
        case monthly
        case yearly
    }

    enum Status: String, Codable {
        case active
        case canceled
        case expired
        case pastDue = "past_due"
    }

    var isActive: Bool {
        switch status {
        case .active:
            if let expiresAt = expiresAt {
                return Date() < expiresAt
            }
            return true
        default:
            return false
        }
    }

    var daysRemaining: Int? {
        guard let expiresAt = expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day
        return max(0, days ?? 0)
    }
}

// MARK: - Preferences
struct UserPreferences: Codable {
    var defaultCalendar: CalendarEvent.CalendarSource = .google
    var launchAtLogin: Bool = false
    var showNotifications: Bool = true
    var theme: Theme = .system
    var aiModel: AIModel = .claude35Sonnet
    var sendConfirmation: Bool = true

    enum Theme: String, Codable {
        case light
        case dark
        case system
    }

    enum AIModel: String, Codable {
        case claude35Sonnet = "claude-sonnet-4-20250514"
        case claude35Opus = "claude-3-opus-20240229"
    }
}

// MARK: - User Manager
class UserManager: ObservableObject {
    static let shared = UserManager()

    @Published var currentUser: User?
    @Published var isSignedIn: Bool = false

    private let userDefaultsKey = "current_user"

    private init() {
        loadUser()
    }

    func loadUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        currentUser = user
        isSignedIn = true
    }

    func saveUser(_ user: User) {
        currentUser = user
        isSignedIn = true

        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func updatePreferences(_ preferences: UserPreferences) {
        guard var user = currentUser else { return }
        user.preferences = preferences
        saveUser(user)
    }

    func signOut() {
        currentUser = nil
        isSignedIn = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        KeychainService.shared.clearAll()
    }
}
