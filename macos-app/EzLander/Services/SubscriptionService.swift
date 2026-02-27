import Foundation
import AppKit
import Combine

class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    private let verifyURL = "https://ezlander.app/api/license/verify"
    private let purchaseURL = "https://ezlander.app/pricing"
    private let reVerifyInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let offlineGracePeriod: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    // Keychain keys
    private let keychainKeyEmail = "subscription_email"

    // UserDefaults keys
    private let udKeyValidatedAt = "subscription_validated_at"
    private let udKeyIsActive = "subscription_is_active"
    private let udKeyPlan = "subscription_plan"
    private let udKeyExpiresAt = "subscription_expiry"

    // Notification posted when a previously active subscription becomes invalid
    static let subscriptionInvalidatedNotification = Notification.Name("SubscriptionInvalidated")

    @Published var isSubscribed: Bool = false
    @Published var subscribedEmail: String = ""
    @Published var plan: String = ""

    private var reVerifyTimer: Timer?

    private init() {
        loadCachedState()
    }

    // MARK: - Check on Launch

    func checkSubscriptionOnLaunch() async -> Bool {
        guard let storedEmail = KeychainService.shared.get(key: keychainKeyEmail) else {
            await MainActor.run { isSubscribed = false }
            return false
        }

        // Check if last validation is recent enough
        if let validatedAt = UserDefaults.standard.object(forKey: udKeyValidatedAt) as? Date {
            let elapsed = Date().timeIntervalSince(validatedAt)
            if elapsed < reVerifyInterval {
                let cached = UserDefaults.standard.bool(forKey: udKeyIsActive)
                await MainActor.run { isSubscribed = cached }
                if cached { startReVerifyTimer() }
                return cached
            }
        }

        // Re-verify with server
        do {
            let response = try await verifyWithServer(email: storedEmail)
            if response.isActive {
                cacheValidation(response: response)
                await MainActor.run { isSubscribed = true }
                startReVerifyTimer()
                return true
            } else {
                cacheInvalid()
                await MainActor.run { isSubscribed = false }
                return false
            }
        } catch {
            // Network error — use cached result with grace period
            if let validatedAt = UserDefaults.standard.object(forKey: udKeyValidatedAt) as? Date {
                let elapsed = Date().timeIntervalSince(validatedAt)
                if elapsed < offlineGracePeriod && UserDefaults.standard.bool(forKey: udKeyIsActive) {
                    await MainActor.run { isSubscribed = true }
                    startReVerifyTimer()
                    return true
                }
            }
            await MainActor.run { isSubscribed = false }
            return false
        }
    }

    // MARK: - Activate

    func activateSubscription(email: String) async throws {
        let response = try await verifyWithServer(email: email)

        guard response.isActive else {
            throw SubscriptionError.noActiveSubscription
        }

        // Store email in Keychain
        KeychainService.shared.save(key: keychainKeyEmail, value: email)

        // Cache validation
        cacheValidation(response: response)

        // Update published state
        await MainActor.run {
            isSubscribed = true
            subscribedEmail = email
            plan = response.plan ?? ""
        }

        startReVerifyTimer()
    }

    // MARK: - Re-verify

    func reVerifySubscription() async -> Bool {
        guard let storedEmail = KeychainService.shared.get(key: keychainKeyEmail) else {
            await MainActor.run { isSubscribed = false }
            return false
        }

        do {
            let response = try await verifyWithServer(email: storedEmail)
            if response.isActive {
                cacheValidation(response: response)
                return true
            } else {
                cacheInvalid()
                clearStored()
                await MainActor.run { isSubscribed = false }
                NotificationCenter.default.post(name: Self.subscriptionInvalidatedNotification, object: nil)
                return false
            }
        } catch {
            // Network error — keep current state
            return isSubscribed
        }
    }

    // MARK: - Deactivate

    func deactivateSubscription() {
        clearStored()
        reVerifyTimer?.invalidate()
        reVerifyTimer = nil
        isSubscribed = false
        subscribedEmail = ""
        plan = ""
        NotificationCenter.default.post(name: Self.subscriptionInvalidatedNotification, object: nil)
    }

    // MARK: - Stored Check

    var hasStoredEmail: Bool {
        KeychainService.shared.get(key: keychainKeyEmail) != nil
    }

    // MARK: - Purchase URL

    func openPurchasePage() {
        if let url = URL(string: purchaseURL) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private func verifyWithServer(email: String) async throws -> SubscriptionResponse {
        guard let url = URL(string: verifyURL) else {
            throw SubscriptionError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubscriptionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw SubscriptionError.networkError("Server returned \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(SubscriptionResponse.self, from: data)
    }

    private func loadCachedState() {
        subscribedEmail = KeychainService.shared.get(key: keychainKeyEmail) ?? ""
        plan = UserDefaults.standard.string(forKey: udKeyPlan) ?? ""
    }

    private func cacheValidation(response: SubscriptionResponse) {
        UserDefaults.standard.set(Date(), forKey: udKeyValidatedAt)
        UserDefaults.standard.set(true, forKey: udKeyIsActive)
        if let plan = response.plan {
            UserDefaults.standard.set(plan, forKey: udKeyPlan)
        }
        if let expiresAt = response.expiresAt {
            UserDefaults.standard.set(expiresAt, forKey: udKeyExpiresAt)
        }
    }

    private func cacheInvalid() {
        UserDefaults.standard.set(Date(), forKey: udKeyValidatedAt)
        UserDefaults.standard.set(false, forKey: udKeyIsActive)
    }

    private func clearStored() {
        KeychainService.shared.delete(key: keychainKeyEmail)
        UserDefaults.standard.removeObject(forKey: udKeyValidatedAt)
        UserDefaults.standard.removeObject(forKey: udKeyIsActive)
        UserDefaults.standard.removeObject(forKey: udKeyPlan)
        UserDefaults.standard.removeObject(forKey: udKeyExpiresAt)
    }

    private func startReVerifyTimer() {
        reVerifyTimer?.invalidate()
        reVerifyTimer = Timer.scheduledTimer(withTimeInterval: reVerifyInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                _ = await self?.reVerifySubscription()
            }
        }
    }
}

// MARK: - Response Model

struct SubscriptionResponse: Codable {
    let isActive: Bool
    let plan: String?
    let expiresAt: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case plan
        case expiresAt = "expires_at"
        case status
    }
}

// MARK: - Errors

enum SubscriptionError: Error, LocalizedError {
    case noActiveSubscription
    case networkError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noActiveSubscription:
            return "No active subscription found for this email. Please subscribe first."
        case .networkError(let message):
            return "Network error: \(message). Please check your connection."
        case .invalidResponse:
            return "Unexpected response from server."
        }
    }
}
