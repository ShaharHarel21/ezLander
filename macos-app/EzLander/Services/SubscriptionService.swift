import Foundation
import StoreKit

class SubscriptionService {
    static let shared = SubscriptionService()

    private let verifyURL = "https://ezlander.app/api/license/verify"
    private let trialDays = 7

    private init() {}

    // MARK: - Subscription Status
    func checkSubscriptionStatus() async -> Bool {
        // Check trial first
        if isTrialActive() {
            return true
        }

        // Check cached subscription
        if let cachedExpiry = UserDefaults.standard.object(forKey: "subscription_expiry") as? Date {
            if cachedExpiry > Date() {
                return true
            }
        }

        // Verify with server
        guard let email = UserDefaults.standard.string(forKey: "user_email") else {
            return false
        }

        do {
            let status = try await verifySubscription(email: email)
            return status.isActive
        } catch {
            // If server is unavailable, use cached status with grace period
            if let cachedExpiry = UserDefaults.standard.object(forKey: "subscription_expiry") as? Date {
                let gracePeriod = cachedExpiry.addingTimeInterval(7 * 24 * 60 * 60) // 7 day grace
                return Date() < gracePeriod
            }
            return false
        }
    }

    // MARK: - Verify with Server
    private func verifySubscription(email: String) async throws -> SubscriptionStatusResponse {
        guard let url = URL(string: verifyURL) else {
            throw SubscriptionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubscriptionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw SubscriptionError.serverError(statusCode: httpResponse.statusCode)
        }

        let status = try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)

        // Cache the result
        if status.isActive, let expiryString = status.expiresAt {
            let formatter = ISO8601DateFormatter()
            if let expiry = formatter.date(from: expiryString) {
                UserDefaults.standard.set(expiry, forKey: "subscription_expiry")
            }
        }

        return status
    }

    // MARK: - Trial
    func startTrial() async {
        let trialStart = Date()
        let trialEnd = Calendar.current.date(byAdding: .day, value: trialDays, to: trialStart)!

        UserDefaults.standard.set(trialStart, forKey: "trial_start")
        UserDefaults.standard.set(trialEnd, forKey: "trial_end")
    }

    func isTrialActive() -> Bool {
        guard let trialEnd = UserDefaults.standard.object(forKey: "trial_end") as? Date else {
            return false
        }
        return Date() < trialEnd
    }

    func trialDaysRemaining() -> Int {
        guard let trialEnd = UserDefaults.standard.object(forKey: "trial_end") as? Date else {
            return 0
        }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: trialEnd).day ?? 0
        return max(0, days)
    }

    // MARK: - Subscription Details
    func getSubscriptionDetails() async -> SubscriptionDetails {
        if isTrialActive() {
            return SubscriptionDetails(
                type: .trial,
                isActive: true,
                daysRemaining: trialDaysRemaining()
            )
        }

        guard let email = UserDefaults.standard.string(forKey: "user_email") else {
            return SubscriptionDetails(type: .none, isActive: false)
        }

        do {
            let status = try await verifySubscription(email: email)
            return SubscriptionDetails(
                type: status.plan == "yearly" ? .yearly : .monthly,
                isActive: status.isActive,
                expiresAt: status.expiresAt.flatMap { ISO8601DateFormatter().date(from: $0) }
            )
        } catch {
            return SubscriptionDetails(type: .none, isActive: false)
        }
    }

    // MARK: - Open Purchase Page
    func openPurchasePage() {
        if let url = URL(string: "https://ezlander.app/pricing") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Open Customer Portal
    func openCustomerPortal() async {
        guard let email = UserDefaults.standard.string(forKey: "user_email") else {
            openPurchasePage()
            return
        }

        // Request portal URL from server
        do {
            let portalURL = try await getCustomerPortalURL(email: email)
            if let url = URL(string: portalURL) {
                NSWorkspace.shared.open(url)
            }
        } catch {
            openPurchasePage()
        }
    }

    private func getCustomerPortalURL(email: String) async throws -> String {
        guard let url = URL(string: "https://ezlander.app/api/stripe/portal") else {
            throw SubscriptionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(PortalResponse.self, from: data)
        return response.url
    }
}

// MARK: - Models
struct SubscriptionStatusResponse: Codable {
    let isActive: Bool
    let plan: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case plan
        case expiresAt = "expires_at"
    }
}

struct SubscriptionDetails {
    let type: SubscriptionType
    let isActive: Bool
    var daysRemaining: Int?
    var expiresAt: Date?
}

enum SubscriptionType {
    case none
    case trial
    case monthly
    case yearly
}

struct PortalResponse: Codable {
    let url: String
}

// MARK: - Errors
enum SubscriptionError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}
