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
    private let udKeyReferralCode = "referral_code"
    private let udKeyReferralCreditsDays = "referral_credits_days"
    private let udKeyReferralsCount = "referrals_count"

    // Notification posted when a previously active subscription becomes invalid
    static let subscriptionInvalidatedNotification = Notification.Name("SubscriptionInvalidated")

    @Published var isSubscribed: Bool = false
    @Published var subscribedEmail: String = ""
    @Published var plan: String = ""
    @Published var tier: String = ""
    @Published var tokensUsed: Int = 0
    @Published var tokensLimit: Int = 0
    @Published var tokensRemaining: Int = 0
    @Published var referralCode: String = ""
    @Published var referralCreditsDays: Int = 0
    @Published var referralsCount: Int = 0

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

        if response.requiresPassword == true {
            throw SubscriptionError.passwordRequired
        }

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
            tier = response.tier ?? ""
            tokensUsed = response.tokensUsed ?? 0
            tokensLimit = response.tokenLimit ?? 0
            tokensRemaining = response.tokensRemaining ?? 0
            referralCode = response.referralCode ?? ""
            referralCreditsDays = response.referralCreditsDays ?? 0
            referralsCount = response.referralsCount ?? 0
        }

        startReVerifyTimer()
    }

    func activateAdminSubscription(email: String, password: String) async throws {
        let response = try await verifyWithServer(email: email, password: password)

        guard response.isActive else {
            throw SubscriptionError.invalidPassword
        }

        KeychainService.shared.save(key: keychainKeyEmail, value: email)
        cacheValidation(response: response)

        await MainActor.run {
            isSubscribed = true
            subscribedEmail = email
            plan = response.plan ?? ""
            tier = response.tier ?? ""
            tokensUsed = response.tokensUsed ?? 0
            tokensLimit = response.tokenLimit ?? 0
            tokensRemaining = response.tokensRemaining ?? 0
            referralCode = response.referralCode ?? ""
            referralCreditsDays = response.referralCreditsDays ?? 0
            referralsCount = response.referralsCount ?? 0
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
        tier = ""
        tokensUsed = 0
        tokensLimit = 0
        tokensRemaining = 0
        referralCode = ""
        referralCreditsDays = 0
        referralsCount = 0
        ProxyAIService.shared.clearJWT()
        NotificationCenter.default.post(name: Self.subscriptionInvalidatedNotification, object: nil)
    }

    // MARK: - Admin Detection

    /// Check if the given email is a known admin email that requires password authentication.
    /// This allows the UI to immediately show the password field without a server round-trip.
    static func isAdminEmail(_ email: String) -> Bool {
        let trimmed = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "shahar@ezlander.app" || trimmed == "shahar.harel200@gmail.com" || trimmed.hasSuffix("@admin.ezlander.app")
    }

    // MARK: - Stored Check

    var hasStoredEmail: Bool {
        KeychainService.shared.get(key: keychainKeyEmail) != nil
    }

    // MARK: - Referral

    func fetchReferralCode() async throws {
        guard !subscribedEmail.isEmpty else { return }

        let url = URL(string: "https://ezlander.app/api/referral/code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": subscribedEmail])

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ReferralCodeResponse.self, from: data)

        await MainActor.run {
            self.referralCode = response.referralCode
            self.referralCreditsDays = response.referralCreditsDays
            self.referralsCount = response.referralsCount
            // Cache
            UserDefaults.standard.set(response.referralCode, forKey: udKeyReferralCode)
            UserDefaults.standard.set(response.referralCreditsDays, forKey: udKeyReferralCreditsDays)
            UserDefaults.standard.set(response.referralsCount, forKey: udKeyReferralsCount)
        }
    }

    // MARK: - Purchase URL

    func openPurchasePage() {
        if let url = URL(string: purchaseURL) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private func verifyWithServer(email: String, password: String? = nil) async throws -> SubscriptionResponse {
        guard let url = URL(string: verifyURL) else {
            throw SubscriptionError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        var body: [String: String] = ["email": email]
        if let password = password {
            body["password"] = password
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubscriptionError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Decode the 401 body to get message and isAdminEmail info
            if let decoded = try? JSONDecoder().decode(SubscriptionResponse.self, from: data) {
                return decoded
            }
            throw SubscriptionError.invalidPassword
        }

        guard httpResponse.statusCode == 200 else {
            // Try to extract a user-friendly message from the error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let serverMessage = json["message"] as? String {
                throw SubscriptionError.networkError(serverMessage)
            }
            throw SubscriptionError.networkError("Server returned \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(SubscriptionResponse.self, from: data)
    }

    private func loadCachedState() {
        subscribedEmail = KeychainService.shared.get(key: keychainKeyEmail) ?? ""
        plan = UserDefaults.standard.string(forKey: udKeyPlan) ?? ""
        referralCode = UserDefaults.standard.string(forKey: udKeyReferralCode) ?? ""
        referralCreditsDays = UserDefaults.standard.integer(forKey: udKeyReferralCreditsDays)
        referralsCount = UserDefaults.standard.integer(forKey: udKeyReferralsCount)
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
        if let referralCode = response.referralCode {
            UserDefaults.standard.set(referralCode, forKey: udKeyReferralCode)
        }
        if let referralCreditsDays = response.referralCreditsDays {
            UserDefaults.standard.set(referralCreditsDays, forKey: udKeyReferralCreditsDays)
        }
        if let referralsCount = response.referralsCount {
            UserDefaults.standard.set(referralsCount, forKey: udKeyReferralsCount)
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
        UserDefaults.standard.removeObject(forKey: udKeyReferralCode)
        UserDefaults.standard.removeObject(forKey: udKeyReferralCreditsDays)
        UserDefaults.standard.removeObject(forKey: udKeyReferralsCount)
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
    let requiresPassword: Bool?
    let isAdminEmail: Bool?
    let message: String?
    let referralCode: String?
    let referralCreditsDays: Int?
    let referralsCount: Int?
    let tier: String?
    let tokenLimit: Int?
    let tokensUsed: Int?
    let tokensRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case plan
        case expiresAt = "expires_at"
        case status
        case requiresPassword = "requires_password"
        case isAdminEmail = "is_admin_email"
        case message
        case referralCode = "referral_code"
        case referralCreditsDays = "referral_credits_days"
        case referralsCount = "referrals_count"
        case tier
        case tokenLimit = "token_limit"
        case tokensUsed = "tokens_used"
        case tokensRemaining = "tokens_remaining"
    }
}

struct ReferralCodeResponse: Codable {
    let referralCode: String
    let referralCreditsDays: Int
    let referralsCount: Int

    enum CodingKeys: String, CodingKey {
        case referralCode = "referral_code"
        case referralCreditsDays = "referral_credits_days"
        case referralsCount = "referrals_count"
    }
}

// MARK: - Errors

enum SubscriptionError: Error, LocalizedError {
    case noActiveSubscription
    case networkError(String)
    case invalidResponse
    case passwordRequired
    case invalidPassword

    var errorDescription: String? {
        switch self {
        case .noActiveSubscription:
            return "No active subscription found for this email. Please subscribe first."
        case .networkError(let message):
            return "Network error: \(message). Please check your connection."
        case .invalidResponse:
            return "Unexpected response from server."
        case .passwordRequired:
            return "Password required."
        case .invalidPassword:
            return "Invalid password."
        }
    }
}
