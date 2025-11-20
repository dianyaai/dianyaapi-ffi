import Foundation
import Combine
import os

extension DianyaAPI {
    /// WebSocket client for real-time transcription
    public class TranscribeStream {
        private static let label = "com.dianyaapi.stream"
        private let sessionInfo: SessionInfo
        private let queue = DispatchQueue(label: label, qos: .userInitiated)
        
        private var handle: TranscribeStreamPtr?
        private let receiveGroup = DispatchGroup()
        private static let logger = Logger(subsystem: "com.dianyaapi", category: "TranscribeStream")
        
        // Combine support
        private let messageSubject = PassthroughSubject<String, TranscribeError>()
        private var cancellables = Set<AnyCancellable>()
        private var receiveTask: Task<Void, Never>?
        
        /// Initialize with session information
        /// - Parameter sessionInfo: Session information from `createSession`
        public init(sessionInfo: SessionInfo) {
            self.sessionInfo = sessionInfo
        }
        
        deinit {
            disconnect()
        }
        
        // MARK: - Session Management (Static)
        
        /// Create a transcription session
        /// - Parameters:
        ///   - token: Bearer token
        ///   - model: Model type (default: .speed)
        /// - Returns: Session information
        public static func createSession(
            token: String,
            model: ModelType = .speed
        ) async throws -> SessionInfo {
            return try await FFIBridge.execute {
                var session = FfiSessionCreator(
                    task_id: nil,
                    session_id: nil,
                    usage_id: nil,
                    max_time: 0
                )
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_session_creator(&session)
                }
                
                let code = FFIBridge.withCString(model.toFfiString()) { modelPtr in
                    FFIBridge.withCString(token) { tokenPtr in
                        let result = transcribe_ffi_create_session(
                            modelPtr,
                            tokenPtr,
                            &session,
                            errorManager.getPointer()
                        )
                        return result
                    }
                }

                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)

                let sessionInfo = session.toSwift()
                return sessionInfo
            }
        }
        
        /// Close the transcription session
        /// - Parameters:
        ///   - taskId: Task ID from session
        ///   - token: Bearer token
        ///   - timeout: Timeout in seconds (0 means use default 30 seconds)
        /// - Returns: Session close result
        public static func closeSession(
            taskId: String,
            token: String,
            timeout: UInt64 = 0
        ) async throws -> SessionCloseResult {
            return try await FFIBridge.execute {
                var result = FfiSessionEnder(
                    status: nil,
                    duration: 0,
                    has_duration: false,
                    error_code: 0,
                    has_error_code: false,
                    message: nil
                )
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_session_ender(&result)
                }
                
                let code = FFIBridge.withCString(taskId) { taskIdPtr in
                    FFIBridge.withCString(token) { tokenPtr in
                        let resultCode = transcribe_ffi_close_session(
                            taskIdPtr,
                            tokenPtr,
                            timeout,
                            &result,
                            errorManager.getPointer()
                        )

                        return resultCode
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)

                let closeResult = result.toSwift()
                return closeResult
            }
        }
        
        // MARK: - WebSocket Connection
        
        /// Connect to WebSocket using session ID from sessionInfo
        public func connect() async throws {
            return try await FFIBridge.execute {
                var wsHandle: TranscribeStreamPtr?
                let errorManager = FfiErrorManager()
                
                let code = FFIBridge.withCString(self.sessionInfo.sessionId) { sessionIdPtr in
                    transcribe_ffi_ws_create(
                        sessionIdPtr,
                        &wsHandle,
                        errorManager.getPointer()
                    )
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                
                guard let handle = wsHandle else {
                    throw TranscribeError.otherError("Failed to create WebSocket handle")
                }
                
                self.handle = handle
                
                // Start the WebSocket connection
                let startCode = transcribe_ffi_ws_start(handle, errorManager.getPointer())
                if startCode != 0 {
                    try FFIBridge.callFFI(errorCode: startCode, errorManager: errorManager)
                }
            }
        }
        
        /// Disconnect and close WebSocket
        public func disconnect() {
            var handleToRelease: TranscribeStreamPtr?
            queue.sync {
                guard let handle = self.handle else {
                    return
                }

                self.receiveTask?.cancel()
                self.receiveTask = nil
                self.handle = nil
                handleToRelease = handle
            }
            
            guard let handle = handleToRelease else { return }
            let subject = messageSubject
            let group = receiveGroup
            
            DispatchQueue.global(qos: .userInitiated).async {
                let errorManager = FfiErrorManager()
                let stopCode = transcribe_ffi_ws_stop(handle, errorManager.getPointer())
                
                if stopCode != 0 {
                    do {
                        try FFIBridge.callFFI(errorCode: stopCode, errorManager: errorManager)
                    } catch {
                        Self.logger.warning("stop() failed: \(String(describing: error), privacy: .public)")
                    }
                }
                
                // 等待所有正在进行的 receiveMessage 调用完成，最多等待 5 秒
                let result = group.wait(timeout: .now() + 5.0)
                if result == .timedOut {
                    Self.logger.warning("receiveGroup wait timed out, forcing release")
                }
                
                transcribe_ffi_ws_free(handle)
                
                subject.send(completion: .finished)
            }
        }
        
        /// Stop receiving messages (but keep connection open)
        public func stop() {
            queue.sync {
                guard let handle = self.handle else { return }
                let errorManager = FfiErrorManager()
                let code = transcribe_ffi_ws_stop(handle, errorManager.getPointer())
                if code != 0 {
                    do {
                        try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                    } catch {
                        Self.logger.warning("stop() failed: \(String(describing: error), privacy: .public)")
                    }
                }
                self.receiveTask?.cancel()
                self.receiveTask = nil
            }
        }
        
        // MARK: - Message Sending
        
        /// Send text message to WebSocket
        public func sendText(_ text: String) async throws {
            return try await FFIBridge.execute {
                guard let handle = self.handle else {
                    throw TranscribeError.otherError("WebSocket not connected")
                }
                
                let errorManager = FfiErrorManager()
                
                let code = FFIBridge.withCString(text) { textPtr in
                    transcribe_ffi_ws_write_txt(
                        handle,
                        textPtr,
                        errorManager.getPointer()
                    )
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
            }
        }
        
        /// Send audio data to WebSocket
        public func sendAudio(_ data: Data) async throws {
            return try await FFIBridge.execute {
                guard let handle = self.handle else {
                    throw TranscribeError.otherError("WebSocket not connected")
                }
                
                guard !data.isEmpty else {
                    return
                }
                
                let errorManager = FfiErrorManager()
                
                let code = data.withUnsafeBytes { bytes in
                    transcribe_ffi_ws_write_bytes(
                        handle,
                        bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        UInt(data.count),
                        errorManager.getPointer()
                    )
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
            }
        }
        
        // MARK: - Message Receiving - Combine
        
        /// Combine Publisher for receiving messages
        public var messagePublisher: AnyPublisher<String, TranscribeError> {
            return messageSubject.eraseToAnyPublisher()
        }
        
        /// Start receiving messages using Combine Publisher
        /// Messages will be published to `messagePublisher`
        public func startReceiving() {
            queue.async {
                guard self.handle != nil else {
                    self.messageSubject.send(completion: .failure(.otherError("WebSocket not connected")))
                    return
                }
                
                // Cancel any existing receive task
                self.receiveTask?.cancel()
                
                // Start new receive task
                self.receiveTask = Task { [weak self] in
                    guard let self = self else { return }
                    
                    while !Task.isCancelled {
                        do {
                            if let message = try await self.receiveMessage(timeout: 100) {
                                await MainActor.run {
                                    self.messageSubject.send(message)
                                }
                            }
                        } catch {
                            await MainActor.run {
                                if let error = error as? TranscribeError {
                                    self.messageSubject.send(completion: .failure(error))
                                } else {
                                    self.messageSubject.send(completion: .failure(.otherError(error.localizedDescription)))
                                }
                            }
                            break
                        }
                    }
                }
            }
        }
        
        // MARK: - Message Receiving - Callback
        
        /// Start receiving messages with callback
        /// - Parameter onMessage: Callback closure called on main thread when message is received
        public func startReceiving(onMessage: @escaping (String) -> Void) {
            queue.async {
                guard let handle = self.handle else {
                    DispatchQueue.main.async {
                        // Callback with error handling would be better, but keeping simple for now
                    }
                    return
                }
                
                // Cancel any existing receive task
                self.receiveTask?.cancel()
                
                // Start new receive task
                Self.logger.info("start receiving messages with callback")
                self.receiveTask = Task { [weak self] in
                    guard let self = self else { return }
                    
                    var messageCount = 0
                    var timeoutCount = 0
                    
                    Self.logger.info("Receive loop started, waiting for messages...")
                    while !Task.isCancelled {
                        do {
                            if let message = try await self.receiveMessage(timeout: 100) {
                                messageCount += 1
                                timeoutCount = 0 // 重置超时计数
                                Self.logger.debug("Received message #\(messageCount): \(message.prefix(200))...")
                                await MainActor.run {
                                    onMessage(message)
                                }
                            } else {
                                // 超时或没有消息
                                timeoutCount += 1
                            }
                        } catch {
                            Self.logger.error("Error receiving message: \(String(describing: error), privacy: .public)")
                            if let error = error as? TranscribeError {
                                Self.logger.error("Error type: \(String(describing: error), privacy: .public)")
                            }
                            // Stop on error
                            break
                        }
                    }
                    Self.logger.info("Message receiving task ended, received \(messageCount) messages, total timeouts: \(timeoutCount)")
                }
            }
        }
        
        // MARK: - Message Receiving - Async
        
        /// Receive a single message asynchronously
        /// - Parameter timeout: Timeout in seconds (0 = immediate return)
        /// - Returns: Received message JSON string, or nil if timeout
        public func receive(timeout: TimeInterval = 0) async throws -> String? {
            let timeoutMs = UInt64(timeout * 1000)
            return try await receiveMessage(timeout: timeoutMs)
        }
        
        // MARK: - Properties
        
        /// Get session information
        public var session: SessionInfo {
            return sessionInfo
        }
        
        // MARK: - Private Helpers
        
        private func receiveMessage(timeout: UInt64) async throws -> String? {
            receiveGroup.enter()
            do {
                let result = try await FFIBridge.execute {
                    guard let handle = self.handle else {
                        throw TranscribeError.otherError("WebSocket not connected")
                    }
                
                let bufferSize = 64 * 1024 // 64KB buffer
                var buffer = [CChar](repeating: 0, count: bufferSize)
                var messageLen: UInt = UInt(bufferSize)
                let errorManager = FfiErrorManager()
                
                let code: Int32 = withUnsafeMutablePointer(to: &messageLen) { messageLenPtr in
                    buffer.withUnsafeMutableBufferPointer { bufferPtr in
                        transcribe_ffi_ws_receive(
                            handle,
                            bufferPtr.baseAddress,
                            messageLenPtr,
                            timeout,
                            errorManager.getPointer()
                        )
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                
                if messageLen == 0 {
                    return (nil as String?)
                }
                
                let actualLength = Int(messageLen)
                guard actualLength > 0, actualLength <= bufferSize else {
                    Self.logger.warning("Invalid message length: \(messageLen), buffer size: \(bufferSize)")
                    return (nil as String?)
                }
                
                let messageData = buffer.withUnsafeBufferPointer { bufferPtr -> Data in
                    guard let baseAddress = bufferPtr.baseAddress else {
                        return Data()
                    }
                    return Data(bytes: UnsafeRawPointer(baseAddress), count: actualLength)
                }
                
                guard let message = String(data: messageData, encoding: .utf8) else {
                    Self.logger.warning("Unable to parse UTF-8 message")
                    return (nil as String?)
                }
                
                return message
                }
                self.receiveGroup.leave()
                return result
            } catch {
                self.receiveGroup.leave()
                throw error
            }
        }
        
        private static func timestamp() -> String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: Date())
        }
    }
}

