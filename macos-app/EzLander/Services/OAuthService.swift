import Foundation
import AuthenticationServices

class OAuthService: NSObject {
    static let shared = OAuthService()

    private let googleClientId = "YOUR_GOOGLE_CLIENT_ID"
    private let googleRedirectURI = "com.ezlander.app:/oauth2callback"

    private var authSession: ASWebAuthenticationSession?

    // MARK: - Google Sign In
    func signInWithGoogle() async throws {
        let scopes = [
            "https://www.googleapis.com/auth/calendar",
            "https://www.googleapis.com/auth/gmail.send",
            "https://www.googleapis.com/auth/gmail.readonly",
            "email",
            "profile"
        ].joined(separator: " ")

        let authURL = URL(string: """
            https://accounts.google.com/o/oauth2/v2/auth?\
            client_id=\(googleClientId)&\
            redirect_uri=\(googleRedirectURI)&\
            response_type=code&\
            scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&\
            access_type=offline&\
            prompt=consent
            """.replacingOccurrences(of: "\n", with: ""))!

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.ezlander.app"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: OAuthError.unknownError)
                }
            }

            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false

            DispatchQueue.main.async {
                self.authSession?.start()
            }
        }

        // Extract authorization code
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.noAuthorizationCode
        }

        // Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(code: code)

        // Save tokens
        KeychainService.shared.save(key: "google_access_token", value: tokens.accessToken)
        if let refreshToken = tokens.refreshToken {
            KeychainService.shared.save(key: "google_refresh_token", value: refreshToken)
        }

        // Fetch user info
        try await fetchUserInfo(accessToken: tokens.accessToken)
    }

    // MARK: - Exchange Code for Tokens
    private func exchangeCodeForTokens(code: String) async throws -> TokenResponse {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": googleClientId,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": googleRedirectURI
        ].map { "\($0.key)=\($0.value)" }.joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
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
        NSApplication.shared.windows.first ?? ASPresentationAnchor()
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
