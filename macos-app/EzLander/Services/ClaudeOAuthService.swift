import Foundation
import AppKit
import CommonCrypto

class ClaudeOAuthService {
    static let shared = ClaudeOAuthService()

    private let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let redirectURI = "com.ezlander.app:/oauth2callback"
    private let authorizeURL = "https://claude.ai/oauth/authorize"
    private let tokenURL = "https://console.anthropic.com/api/oauth/token"

    static let accessTokenKey = "claude_oauth_access_token"
    static let refreshTokenKey = "claude_oauth_refresh_token"
    private let expiresAtKey = "claude_oauth_expires_at"

    private var codeVerifier: String?
    private var authContinuation: CheckedContinuation<URL, Error>?
    private var isRefreshing = false

    private init() {}

    // MARK: - Public Interface

    var isSignedIn: Bool {
        KeychainService.shared.get(key: ClaudeOAuthService.refreshTokenKey) != nil
    }

    func signIn() async throws {
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        let authURLString = "\(authorizeURL)?" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&" +
            "response_type=code&" +
            "scope=user:inference&" +
            "code_challenge=\(challenge)&" +
            "code_challenge_method=S256&" +
            "state=claude"

        guard let authURL = URL(string: authURLString) else {
            throw ClaudeOAuthError.invalidURL
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.authContinuation = continuation
            DispatchQueue.main.async {
                NSWorkspace.shared.open(authURL)
            }
        }

        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw ClaudeOAuthError.noAuthorizationCode
        }

        let tokens = try await exchangeCodeForTokens(code: code)
        saveTokens(tokens)
    }

    func handleCallback(url: URL) {
        authContinuation?.resume(returning: url)
        authContinuation = nil
    }

    func getValidAccessToken() async throws -> String {
        guard let accessToken = KeychainService.shared.get(key: ClaudeOAuthService.accessTokenKey) else {
            throw ClaudeOAuthError.notSignedIn
        }

        let expiresAt = UserDefaults.standard.double(forKey: expiresAtKey)
        let bufferSeconds: TimeInterval = 300 // 5 minutes

        if expiresAt > 0 && Date().timeIntervalSince1970 >= (expiresAt - bufferSeconds) {
            return try await refreshAccessToken()
        }

        return accessToken
    }

    @discardableResult
    func refreshAccessToken() async throws -> String {
        guard !isRefreshing else {
            // Wait briefly and return current token if another refresh is in progress
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if let token = KeychainService.shared.get(key: ClaudeOAuthService.accessTokenKey) {
                return token
            }
            throw ClaudeOAuthError.tokenRefreshFailed
        }

        isRefreshing = true
        defer { isRefreshing = false }

        guard let refreshToken = KeychainService.shared.get(key: ClaudeOAuthService.refreshTokenKey) else {
            throw ClaudeOAuthError.notSignedIn
        }

        let body = "grant_type=refresh_token&refresh_token=\(refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&client_id=\(clientId)"

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ClaudeOAuthError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(ClaudeTokenResponse.self, from: data)
        saveTokens(tokenResponse)
        return tokenResponse.accessToken
    }

    func signOut() {
        KeychainService.shared.delete(key: ClaudeOAuthService.accessTokenKey)
        KeychainService.shared.delete(key: ClaudeOAuthService.refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: expiresAtKey)
    }

    // MARK: - Private

    private func exchangeCodeForTokens(code: String) async throws -> ClaudeTokenResponse {
        guard let verifier = codeVerifier else {
            throw ClaudeOAuthError.noCodeVerifier
        }

        let body = "grant_type=authorization_code&" +
            "code=\(code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&" +
            "code_verifier=\(verifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeOAuthError.tokenExchangeFailed(errorBody)
        }

        codeVerifier = nil
        return try JSONDecoder().decode(ClaudeTokenResponse.self, from: data)
    }

    private func saveTokens(_ tokens: ClaudeTokenResponse) {
        KeychainService.shared.save(key: ClaudeOAuthService.accessTokenKey, value: tokens.accessToken)
        if let refreshToken = tokens.refreshToken {
            KeychainService.shared.save(key: ClaudeOAuthService.refreshTokenKey, value: refreshToken)
        }
        let expiresAt = Date().timeIntervalSince1970 + Double(tokens.expiresIn)
        UserDefaults.standard.set(expiresAt, forKey: expiresAtKey)
    }

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
}

// MARK: - Token Response

struct ClaudeTokenResponse: Codable {
    let tokenType: String
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Errors

enum ClaudeOAuthError: Error, LocalizedError {
    case invalidURL
    case noAuthorizationCode
    case noCodeVerifier
    case tokenExchangeFailed(String)
    case tokenRefreshFailed
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid OAuth URL"
        case .noAuthorizationCode: return "No authorization code received"
        case .noCodeVerifier: return "Missing PKCE code verifier"
        case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
        case .tokenRefreshFailed: return "Failed to refresh access token"
        case .notSignedIn: return "Not signed in with Claude account"
        }
    }
}
