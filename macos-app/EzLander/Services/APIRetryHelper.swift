import Foundation

enum APIRetryHelper {
    /// Retryable HTTP status codes (server errors and rate limiting)
    static let retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]

    /// Execute an async API call with exponential backoff retry logic.
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (default 2, so 3 total attempts)
    ///   - baseDelay: Initial delay in seconds before first retry (default 1.0)
    ///   - operation: The async throwing closure to execute
    /// - Returns: The result of the operation
    static func withRetry<T>(
        maxRetries: Int = 2,
        baseDelay: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry on the last attempt
                guard attempt < maxRetries else { break }

                // Only retry on transient/retryable errors
                guard isRetryable(error) else { break }

                // Exponential backoff: 1s, 2s, 4s...
                let delay = baseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? APIError.invalidResponse
    }

    /// Execute a URLSession request with retry logic, returning (Data, HTTPURLResponse).
    /// Automatically retries on retryable status codes.
    static func performRequest(
        _ request: URLRequest,
        maxRetries: Int = 2,
        baseDelay: TimeInterval = 1.0
    ) async throws -> (Data, HTTPURLResponse) {
        var lastData: Data?
        var lastResponse: HTTPURLResponse?
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                // Success or non-retryable error — return immediately
                if httpResponse.statusCode < 400 || !retryableStatusCodes.contains(httpResponse.statusCode) {
                    return (data, httpResponse)
                }

                // Retryable status code — save and retry
                lastData = data
                lastResponse = httpResponse
            } catch let error where !(error is APIError) {
                // Network-level errors (timeout, connection reset, etc.) are retryable
                lastError = error
                guard attempt < maxRetries else { break }
                let delay = baseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            }

            guard attempt < maxRetries else { break }

            let delay = baseDelay * pow(2.0, Double(attempt))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Return the last response if we have one (retryable status code exhausted retries)
        if let data = lastData, let response = lastResponse {
            return (data, response)
        }

        throw lastError ?? APIError.invalidResponse
    }

    /// Check if an error is transient and worth retrying
    private static func isRetryable(_ error: Error) -> Bool {
        // URLSession errors that are transient
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotConnectToHost, .cannotFindHost:
                return true
            default:
                return false
            }
        }
        return false
    }

    /// Parse an API error response into a user-friendly message
    static func userFriendlyMessage(statusCode: Int, data: Data?) -> String {
        switch statusCode {
        case 401:
            return "Authentication expired. Please sign in again."
        case 403:
            return "Access denied. Please check your permissions."
        case 404:
            return "The requested resource was not found."
        case 429:
            return "Too many requests. Please wait a moment and try again."
        case 500...599:
            return "The server encountered an error. Please try again later."
        default:
            // Try to extract a message from the response body
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Common error formats
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    return message
                }
                if let message = json["message"] as? String {
                    return message
                }
                if let detail = json["detail"] as? String {
                    return detail
                }
            }
            return "Request failed (error \(statusCode)). Please try again."
        }
    }
}

/// Shared API error type for common cases
enum APIError: Error, LocalizedError {
    case invalidResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .networkError(let message):
            return message
        }
    }
}
