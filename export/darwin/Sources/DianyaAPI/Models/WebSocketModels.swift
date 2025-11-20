import Foundation

// MARK: - WebSocket Models

/// Session information for real-time transcription
public struct SessionInfo: Codable, Equatable {
    /// Task ID
    public let taskId: String
    /// Session ID for WebSocket connection
    public let sessionId: String
    /// Usage ID
    public let usageId: String
    /// Maximum transcription time in seconds
    public let maxTime: Int32
    
    public init(taskId: String, sessionId: String, usageId: String, maxTime: Int32) {
        self.taskId = taskId
        self.sessionId = sessionId
        self.usageId = usageId
        self.maxTime = maxTime
    }
}

/// Session close result
public struct SessionCloseResult: Codable, Equatable {
    /// Status string
    public let status: String
    /// Session duration in seconds (if available)
    public let duration: Int32?
    /// Error code (if error occurred)
    public let errorCode: Int32?
    /// Error message (if error occurred)
    public let message: String?
    
    public init(status: String, duration: Int32? = nil, errorCode: Int32? = nil, message: String? = nil) {
        self.status = status
        self.duration = duration
        self.errorCode = errorCode
        self.message = message
    }
}

/// WebSocket connection state
public enum WebSocketState: Equatable {
    case disconnected
    case connecting
    case connected
    case stopping
    case error(TranscribeError)
    
    public static func == (lhs: WebSocketState, rhs: WebSocketState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected),
             (.stopping, .stopping):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

/// WebSocket message
public struct WebSocketMessage: Codable, Equatable {
    /// Message content as JSON string
    public let json: String
    
    public init(json: String) {
        self.json = json
    }
}

