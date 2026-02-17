import Foundation
import AuthenticationServices
import CommonCrypto

class OAuthService: NSObject {
    static let shared = OAuthService()

    private let googleClientId = "224322597988-josm6rg0hukmuv12ip4qfdbo1f0mkmni.apps.googleusercontent.com"
    private let googleRedirectURI = "com.ezlander.app:/oauth2callback"

    private var authSession: ASWebAuthenticationSession?

    // PKCE parameters
    private var codeVerifier: String?

    // MARK: - Handle URL Callback
    func handleCallback(url: URL) {
        print("OAuthService: Received callback URL: \(url)")
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
            "https://www.googleapis.com/auth/gmail.send",
            "https://www.googleapis.com/auth/gmail.readonly",
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

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.authContinuation = continuation

            // Open in default browser
            DispatchQueue.main.async {
                NSWorkspace.shared.open(authURL)
            }
        }

        // Extract authorization code
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.noAuthorizationCode
        }

        print("OAuthService: Got authorization code, exchanging for tokens...")

        // Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(code: code)

        // Save tokens
        KeychainService.shared.save(key: "google_access_token", value: tokens.accessToken)
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

        let body = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.tokenExchangeFailed
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("OAuthService: Token exchange failed: \(errorBody)")
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
    }

    // MARK: - Refresh Token
    func refreshAccessToken() async throws -> String {
        guard let refreshToken = KeychainService.shared.get(key: "google_refresh_token") else {
            throw OAuthError.noRefreshToken
        }

        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": googleClientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ].map { "\($0.key)=\($0.value)" }.joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenRefreshFailed
        }

        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        KeychainService.shared.save(key: "google_access_token", value: tokens.accessToken)

        return tokens.accessToken
    }

    // MARK: - Get Valid Access Token
    func getValidAccessToken() async throws -> String {
        guard let accessToken = KeychainService.shared.get(key: "google_access_token") else {
            throw OAuthError.notSignedIn
        }

        // Check if token is valid by making a test request
        let url = URL(string: "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=\(accessToken)")!
        let (_, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return accessToken
        }

        // Token expired, refresh it
        return try await refreshAccessToken()
    }

    // MARK: - Sign Out
    func signOut() {
        KeychainService.shared.delete(key: "google_access_token")
        KeychainService.shared.delete(key: "google_refresh_token")
        UserDefaults.standard.removeObject(forKey: "user_email")
        UserDefaults.standard.removeObject(forKey: "user_name")
    }

    // MARK: - Check Sign In Status
    var isSignedIn: Bool {
        KeychainService.shared.get(key: "google_access_token") != nil
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
        case .noRefreshToken:
            return "No refresh token available"
        case .notSignedIn:
            return "User is not signed in"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
