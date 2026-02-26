import Foundation
import AuthenticationServices
import CommonCrypto

class OAuthService: NSObject {
    static let shared = OAuthService()

    private let googleClientId: String = {
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String, !clientId.isEmpty {
            return clientId
        }
        // Default client ID — move to Info.plist GOOGLE_CLIENT_ID for production builds
        return "224322597988-josm6rg0hukmuv12ip4qfdbo1f0mkmni.apps.googleusercontent.com"
    }()
    private let googleRedirectURI = "com.ezlander.app:/oauth2callback"

    private var authSession: ASWebAuthenticationSession?

    // PKCE parameters
    private var codeVerifier: String?

    // Apple Sign In
    private var appleSignInContinuation: CheckedContinuation<Void, Error>?

    // OAuth timeout — cancel abandoned sign-in flows to prevent Task leaks
    private var authTimeoutTask: Task<Void, Never>?
    private static let authTimeoutSeconds: UInt64 = 300 // 5 minutes

    // Token refresh deduplication — access synchronized via refreshLock
    private let refreshLock = NSLock()
    private var isRefreshing = false
    private var refreshWaiters: [CheckedContinuation<String, Error>] = []

    // User email from Google sign-in
    var userEmail: String? {
        UserDefaults.standard.string(forKey: "user_email")
    }

    // MARK: - Handle URL Callback
    func handleCallback(url: URL) {
        print("OAuthService: Received callback URL (scheme: \(url.scheme ?? "nil"))")
        authContinuation?.resume(returning: url)
        authContinuation = nil
    }

    // Continuation for handling OAuth callback
    private var authContinuation: CheckedContinuation<URL, Error>?

    // MARK: - PKCE Helpers
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Google Sign In
    func signInWithGoogle() async throws {
        // Generate PKCE code verifier and challenge
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        let scopes = [
            "https://www.googleapis.com/auth/calendar",
            "https://www.googleapis.com/auth/gmail.modify",
            "https://www.googleapis.com/auth/contacts.other.readonly",
            "email",
            "profile"
        ].joined(separator: " ")

        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth?" +
            "client_id=\(googleClientId)&" +
            "redirect_uri=\(googleRedirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&" +
            "response_type=code&" +
            "scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&" +
            "access_type=offline&" +
            "prompt=consent&" +
            "code_challenge=\(challenge)&" +
            "code_challenge_method=S256"

        guard let authURL = URL(string: authURLString) else {
            throw OAuthError.unknownError
        }

        print("OAuthService: Opening Google OAuth URL in browser...")

        // Cancel any previously abandoned auth flow before starting a new one
        cancelPendingAuth()

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.authContinuation = continuation

            // Set a timeout to prevent leaked continuations if user abandons the flow
            self.authTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.authTimeoutSeconds * 1_000_000_000)
                guard !Task.isCancelled else { return }
                print("OAuthService: OAuth flow timed out after \(Self.authTimeoutSeconds)s")
                self?.cancelPendingAuth()
            }

            // Open in default browser
            DispatchQueue.main.async {
                NSWorkspace.shared.open(authURL)
            }
        }

        // Auth succeeded — cancel the timeout
        authTimeoutTask?.cancel()
        authTimeoutTask = nil

        // Extract authorization code
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.noAuthorizationCode
        }

        print("OAuthService: Got authorization code, exchanging for tokens...")

        // Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(code: code)

        // Save tokens and expiry
        KeychainService.shared.save(key: "google_access_token", value: tokens.accessToken)
        UserDefaults.standard.set(Date().timeIntervalSince1970 + Double(tokens.expiresIn), forKey: "google_token_expiry")
        if let refreshToken = tokens.refreshToken {
            KeychainService.shared.save(key: "google_refresh_token", value: refreshToken)
        }

        print("OAuthService: Tokens saved, fetching user info...")

        // Fetch user info
        try await fetchUserInfo(accessToken: tokens.accessToken)

        print("OAuthService: Sign in complete!")
    }

    // MARK: - Exchange Code for Tokens
    private func exchangeCodeForTokens(code: String) async throws -> TokenResponse {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyParams = [
            "client_id": googleClientId,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": googleRedirectURI
        ]

        // Include PKCE code verifier
        if let verifier = codeVerifier {
            bodyParams["code_verifier"] = verifier
        }

        var components = URLComponents()
        components.queryItems = bodyParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, httpResponse) = try await APIRetryHelper.performRequest(request)

        if httpResponse.statusCode != 200 {
            print("OAuthService: Token exchange failed with status \(httpResponse.statusCode)")
            throw OAuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: - Fetch User Info
    private func fetchUserInfo(accessToken: String) async throws {
        let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let userInfo = try JSONDecoder().decode(GoogleUserInfo.self, from: data)

        UserDefaults.standard.set(userInfo.email, forKey: "user_email")
        UserDefaults.standard.set(userInfo.name, forKey: "user_name")
        if let picture = userInfo.picture {
            UserDefaults.standard.set(picture, forKey: "user_picture")
        }
    }

    // MARK: - Refresh Token
    func refreshAccessToken() async throws -> String {
        guard let refreshToken = KeychainService.shared.get(key: "google_refresh_token") else {
            print("OAuthService: No refresh token found in keychain")
            throw OAuthError.noRefreshToken
        }

        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: googleClientId),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, httpResponse) = try await APIRetryHelper.performRequest(request)

        guard httpResponse.statusCode == 200 else {
            // Parse Google's error response for diagnostics
            var googleError: String?
            var googleErrorDesc: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                googleError = json["error"] as? String
                googleErrorDesc = json["error_description"] as? String
            }
            print("OAuthService: Token refresh failed — status \(httpResponse.statusCode), error: \(googleError ?? "unknown"), description: \(googleErrorDesc ?? "none")")

            // If the refresh token itself is invalid/revoked, clear it so the user
            // is prompted to re-authenticate instead of hitting the same error forever
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                if googleError == "invalid_grant" {
                    print("OAuthService: Refresh token revoked or expired — clearing stored tokens")
                    KeychainService.shared.delete(key: "google_access_token")
                    KeychainService.shared.delete(key: "google_refresh_token")
                    UserDefaults.standard.removeObject(forKey: "google_token_expiry")
                    throw OAuthError.refreshTokenRevoked
                }
            }

            throw OAuthError.tokenRefreshFailed
        }

        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        KeychainService.shared.save(key: "google_access_token", value: tokens.accessToken)
        UserDefaults.standard.set(Date().timeIntervalSince1970 + Double(tokens.expiresIn), forKey: "google_token_expiry")

        print("OAuthService: Token refreshed successfully, expires in \(tokens.expiresIn)s")
        return tokens.accessToken
    }

    // MARK: - Get Valid Access Token
    func getValidAccessToken() async throws -> String {
        guard let accessToken = KeychainService.shared.get(key: "google_access_token") else {
            throw OAuthError.notSignedIn
        }

        // Check locally stored expiry — use a 5-minute safety margin to avoid
        // using a token that's about to expire mid-request
        let expiryTime = UserDefaults.standard.double(forKey: "google_token_expiry")
        if expiryTime > 0 && Date().timeIntervalSince1970 < expiryTime - 300 {
            // Token still valid (with 5-minute safety margin)
            return accessToken
        }

        print("OAuthService: Access token expired or expiring soon, refreshing...")

        // Token expired — refresh it, but deduplicate concurrent refresh calls
        let shouldWait: Bool = refreshLock.withLock {
            if isRefreshing {
                return true
            }
            isRefreshing = true
            return false
        }

        if shouldWait {
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    refreshLock.withLock {
                        refreshWaiters.append(continuation)
                    }
                }
            } onCancel: { [self] in
                // Remove this continuation from waiters and resume with cancellation error
                refreshLock.withLock {
                    // We can't identify the exact continuation, so drain all waiters
                    // on cancellation — the active refresh will re-populate for non-cancelled tasks
                    let waiters = refreshWaiters
                    refreshWaiters.removeAll()
                    for waiter in waiters {
                        waiter.resume(throwing: CancellationError())
                    }
                }
            }
        }

        do {
            let newToken = try await refreshAccessToken()
            let waiters: [CheckedContinuation<String, Error>] = refreshLock.withLock {
                isRefreshing = false
                let w = refreshWaiters
                refreshWaiters.removeAll()
                return w
            }
            waiters.forEach { $0.resume(returning: newToken) }
            return newToken
        } catch {
            let waiters: [CheckedContinuation<String, Error>] = refreshLock.withLock {
                isRefreshing = false
                let w = refreshWaiters
                refreshWaiters.removeAll()
                return w
            }
            waiters.forEach { $0.resume(throwing: error) }
            throw error
        }
    }

    // MARK: - Cancel Pending Auth
    func cancelPendingAuth() {
        authTimeoutTask?.cancel()
        authTimeoutTask = nil
        authContinuation?.resume(throwing: OAuthError.unknownError)
        authContinuation = nil
    }

    // MARK: - Sign Out
    func signOut() {
        cancelPendingAuth()
        // Clear Google tokens
        KeychainService.shared.delete(key: "google_access_token")
        KeychainService.shared.delete(key: "google_refresh_token")
        UserDefaults.standard.removeObject(forKey: "google_token_expiry")
        // Clear Apple Sign In
        KeychainService.shared.delete(key: "apple_user_id")
        // Clear user info
        UserDefaults.standard.removeObject(forKey: "user_email")
        UserDefaults.standard.removeObject(forKey: "user_name")
        UserDefaults.standard.removeObject(forKey: "user_picture")
    }

    // MARK: - Verify Apple Sign In Status
    func verifyAppleSignInStatus() async -> Bool {
        guard let userID = KeychainService.shared.get(key: "apple_user_id") else {
            return false
        }

        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userID)
            switch state {
            case .authorized:
                return true
            case .revoked, .notFound:
                // User revoked access or not found, clear the stored ID
                KeychainService.shared.delete(key: "apple_user_id")
                return false
            case .transferred:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("OAuthService: Error checking Apple Sign In status: \(error)")
            return false
        }
    }

    // MARK: - Check Sign In Status
    var isSignedIn: Bool {
        KeychainService.shared.get(key: "google_access_token") != nil ||
        KeychainService.shared.get(key: "apple_user_id") != nil
    }

    var isSignedInWithGoogle: Bool {
        KeychainService.shared.get(key: "google_access_token") != nil
    }

    var isSignedInWithApple: Bool {
        KeychainService.shared.get(key: "apple_user_id") != nil
    }

    // MARK: - Sign in with Apple
    func signInWithApple() async throws {
        // Cancel any previously abandoned Apple sign-in flow
        if appleSignInContinuation != nil {
            print("OAuthService: Cancelling previous Apple Sign In continuation")
            appleSignInContinuation?.resume(throwing: OAuthError.unknownError)
            appleSignInContinuation = nil
        }

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.appleSignInContinuation = continuation
            controller.performRequests()
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension OAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // For menu bar apps, we need to find any available window or create one
        if let window = NSApplication.shared.keyWindow {
            return window
        }
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            return window
        }
        // Create a temporary window for authentication
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.center()
        return window
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension OAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Extract user information
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email

            // Save user identifier for future verification
            KeychainService.shared.save(key: "apple_user_id", value: userIdentifier)

            // Save user info if available (only provided on first sign in)
            if let email = email {
                UserDefaults.standard.set(email, forKey: "user_email")
            }

            if fullName?.givenName != nil {
                let name = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                UserDefaults.standard.set(name.isEmpty ? "Apple User" : name, forKey: "user_name")
            }

            print("OAuthService: Apple Sign In successful")
            appleSignInContinuation?.resume(returning: ())
            appleSignInContinuation = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("OAuthService: Apple Sign In failed: \(error.localizedDescription)")
        appleSignInContinuation?.resume(throwing: error)
        appleSignInContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension OAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = NSApplication.shared.keyWindow {
            return window
        }
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            return window
        }
        // Create a temporary window for authentication
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        return window
    }
}

// MARK: - Models
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct GoogleUserInfo: Codable {
    let id: String
    let email: String
    let name: String
    let picture: String?
}

// MARK: - Errors
enum OAuthError: Error, LocalizedError {
    case noAuthorizationCode
    case tokenExchangeFailed
    case tokenRefreshFailed
    case refreshTokenRevoked
    case noRefreshToken
    case notSignedIn
    case unknownError

    var errorDescription: String? {
        switch self {
        case .noAuthorizationCode:
            return "No authorization code received"
        case .tokenExchangeFailed:
            return "Failed to exchange code for tokens"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .refreshTokenRevoked:
            return "Your Google session has expired. Please sign in again in Settings."
        case .noRefreshToken:
            return "No refresh token available. Please sign in again in Settings."
        case .notSignedIn:
            return "User is not signed in"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
