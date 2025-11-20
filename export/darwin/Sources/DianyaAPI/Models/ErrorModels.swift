import Foundation

/// Errors that can occur when using DianyaAPI
public enum TranscribeError: Error, LocalizedError, Equatable {
    case websocketError(String)
    case httpError(String)
    case serverError(String)
    case invalidInput(String)
    case invalidResponse(String)
    case invalidToken(String)
    case invalidApiKey(String)
    case jsonError(String)
    case otherError(String)
    
    /// Initialize from C ErrorCode and optional message
    public init?(code: ErrorCode, message: String?) {
        let errorMessage = message ?? "Unknown error"
        
        switch code {
        case .wsError:
            self = .websocketError(errorMessage)
        case .httpError:
            self = .httpError(errorMessage)
        case .serverError:
            self = .serverError(errorMessage)
        case .invalidInput:
            self = .invalidInput(errorMessage)
        case .invalidResponse:
            self = .invalidResponse(errorMessage)
        case .invalidToken:
            self = .invalidToken(errorMessage)
        case .invalidApiKey:
            self = .invalidApiKey(errorMessage)
        case .jsonError:
            self = .jsonError(errorMessage)
        case .otherError:
            self = .otherError(errorMessage)
        @unknown default:
            return nil
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .websocketError(let msg):
            return "WebSocket Error: \(msg)"
        case .httpError(let msg):
            return "HTTP Error: \(msg)"
        case .serverError(let msg):
            return "Server Error: \(msg)"
        case .invalidInput(let msg):
            return "Invalid Input: \(msg)"
        case .invalidResponse(let msg):
            return "Invalid Response: \(msg)"
        case .invalidToken(let msg):
            return "Invalid Token: \(msg)"
        case .invalidApiKey(let msg):
            return "Invalid API Key: \(msg)"
        case .jsonError(let msg):
            return "JSON Error: \(msg)"
        case .otherError(let msg):
            return "Other Error: \(msg)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .websocketError:
            return "A WebSocket connection error occurred. Check your network connection and try again."
        case .httpError:
            return "An HTTP request failed. Check your network connection and API endpoint."
        case .serverError:
            return "The server returned an error. The service may be temporarily unavailable."
        case .invalidInput:
            return "The provided input is invalid. Check your parameters and try again."
        case .invalidResponse:
            return "The server response could not be parsed. The API may have changed."
        case .invalidToken:
            return "The authentication token is invalid or expired. Please obtain a new token."
        case .invalidApiKey:
            return "The API key is invalid. Please check your API key configuration."
        case .jsonError:
            return "A JSON parsing error occurred. The response format may be incorrect."
        case .otherError:
            return "An unexpected error occurred. Please try again or contact support."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .websocketError:
            return "Verify your network connection and ensure the WebSocket endpoint is accessible."
        case .httpError:
            return "Check your internet connection and verify the API endpoint URL."
        case .serverError:
            return "Wait a moment and try again. If the problem persists, contact support."
        case .invalidInput:
            return "Review the API documentation and ensure all required parameters are provided correctly."
        case .invalidResponse:
            return "Check the API version compatibility and update your client if necessary."
        case .invalidToken:
            return "Refresh your authentication token and ensure it hasn't expired."
        case .invalidApiKey:
            return "Verify your API key in the dashboard and ensure it's correctly configured."
        case .jsonError:
            return "Check the response format and ensure the API version matches your client."
        case .otherError:
            return "Review the error message for details and try again. If the issue persists, contact support."
        }
    }
}

// MARK: - C ErrorCode Bridge

/// C ErrorCode enum (matching the C header)
@frozen
public enum ErrorCode: Int32 {
    case wsError = 1
    case httpError = 2
    case serverError = 3
    case invalidInput = 4
    case invalidResponse = 5
    case invalidToken = 6
    case invalidApiKey = 7
    case jsonError = 8
    case otherError = 9
}

