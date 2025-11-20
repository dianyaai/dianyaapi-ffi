import Foundation

extension DianyaAPI {
    /// Main API class for transcription services
    public class TranscribeApi {
        private static let label = "com.dianyaapi.transcribe"
        private let token: String
        private let queue = DispatchQueue(label: label, qos: .userInitiated)
        
        /// Initialize with Bearer token
        public init(token: String) {
            self.token = token
        }
        
        // MARK: - Upload
        
        /// Upload audio file for transcription
        public func upload(
            filePath: String,
            transcribeOnly: Bool = false,
            shortASR: Bool = false,
            model: ModelType = .quality
        ) async throws -> UploadResult {
            return try await FFIBridge.execute {
                var result = FfiUploadResponse(
                    is_normal: false,
                    normal: FfiUploadNormal(task_id: nil),
                    one_sentence: FfiUploadOneSentence(status: nil, message: nil, data: nil)
                )
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_upload_response(&result)
                }
                
                let code = FFIBridge.withCString(filePath) { filePathPtr in
                    FFIBridge.withCString(model.toFfiString()) { modelPtr in
                        FFIBridge.withCString(self.token) { tokenPtr in
                            transcribe_ffi_upload(
                                filePathPtr,
                                transcribeOnly,
                                shortASR,
                                modelPtr,
                                tokenPtr,
                                &result,
                                errorManager.getPointer()
                            )
                        }
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                return result.toSwift()
            }
        }
        
        // MARK: - Status
        
        /// Get transcription task status
        public func getStatus(
            taskId: String? = nil,
            shareId: String? = nil
        ) async throws -> TranscribeStatus {
            return try await FFIBridge.execute {
                var status = FfiTranscribeStatus(
                    status: nil,
                    overview_md: nil,
                    summary_md: nil,
                    details: nil,
                    details_len: 0,
                    message: nil,
                    usage_id: nil,
                    task_id: nil,
                    keywords: nil,
                    keywords_len: 0,
                    callback_history: nil,
                    callback_history_len: 0,
                    task_type: .normalQuality,
                    has_task_type: false
                )
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_transcribe_status(&status)
                }
                
                let code = FFIBridge.withOptionalCString(taskId) { taskIdPtr in
                    FFIBridge.withOptionalCString(shareId) { shareIdPtr in
                        FFIBridge.withCString(self.token) { tokenPtr in
                            transcribe_ffi_get_status(
                                taskIdPtr,
                                shareIdPtr,
                                tokenPtr,
                                &status,
                                errorManager.getPointer()
                            )
                        }
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                return status.toSwift()
            }
        }
        
        // MARK: - Export
        
        /// Export transcription result
        public func export(
            taskId: String,
            exportType: ExportType = .transcript,
            exportFormat: ExportFormat = .pdf,
            initialBufferSize: Int = 1024 * 1024 // 1MB initial buffer
        ) async throws -> Data {
            return try await FFIBridge.execute {
                var bufferSize = initialBufferSize
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                let errorManager = FfiErrorManager()
                
                let code = FFIBridge.withCString(taskId) { taskIdPtr in
                    FFIBridge.withCString(exportType.toFfiString()) { typePtr in
                        FFIBridge.withCString(exportFormat.toFfiString()) { formatPtr in
                            FFIBridge.withCString(self.token) { tokenPtr in
                                buffer.withUnsafeMutableBufferPointer { bufferPtr in
                                    var len = UInt(bufferSize)
                                    let result = transcribe_ffi_export(
                                        taskIdPtr,
                                        typePtr,
                                        formatPtr,
                                        tokenPtr,
                                        bufferPtr.baseAddress,
                                        &len,
                                        errorManager.getPointer()
                                    )
                                    
                                    // If buffer too small, resize and retry
                                    if result != 0, let error = errorManager.toSwiftError(),
                                       case .otherError(let msg) = error,
                                       msg.contains("Buffer too small") {
                                        // Extract required size from error message if possible
                                        // For now, just double the buffer and retry once
                                        bufferSize = Int(len)
                                        return -1 // Signal to retry
                                    }
                                    
                                    bufferSize = Int(len)
                                    return Int(result)
                                }
                            }
                        }
                    }
                }
                
                // If buffer was too small, retry with larger buffer
                if code == -1 {
                    bufferSize = bufferSize * 2
                    buffer = [UInt8](repeating: 0, count: bufferSize)
                    
                    let retryCode = FFIBridge.withCString(taskId) { taskIdPtr in
                        FFIBridge.withCString(exportType.toFfiString()) { typePtr in
                            FFIBridge.withCString(exportFormat.toFfiString()) { formatPtr in
                                FFIBridge.withCString(self.token) { tokenPtr in
                                    buffer.withUnsafeMutableBufferPointer { bufferPtr in
                                        var len = UInt(bufferSize)
                                        return transcribe_ffi_export(
                                            taskIdPtr,
                                            typePtr,
                                            formatPtr,
                                            tokenPtr,
                                            bufferPtr.baseAddress,
                                            &len,
                                            errorManager.getPointer()
                                        )
                                    }
                                }
                            }
                        }
                    }
                    
                    try FFIBridge.callFFI(errorCode: retryCode, errorManager: errorManager)
                    bufferSize = buffer.count
                } else {
                    try FFIBridge.callFFI(errorCode: Int32(code), errorManager: errorManager)
                }
                
                return Data(buffer.prefix(bufferSize))
            }
        }
        
        // MARK: - Share Link
        
        /// Get share link for transcription
        public func getShareLink(
            taskId: String,
            expirationDay: Int32 = 7
        ) async throws -> ShareLink {
            return try await FFIBridge.execute {
                var link = FfiShareLink(
                    share_url: nil,
                    expiration_day: 0,
                    expired_at: nil
                )
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_share_link(&link)
                }
                
                let code = FFIBridge.withCString(taskId) { taskIdPtr in
                    FFIBridge.withCString(self.token) { tokenPtr in
                        transcribe_ffi_get_share_link(
                            taskIdPtr,
                            expirationDay,
                            tokenPtr,
                            &link,
                            errorManager.getPointer()
                        )
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                return link.toSwift()
            }
        }
        
        // MARK: - Summary
        
        /// Create summary task from utterances
        public func createSummary(
            utterances: [Utterance]
        ) async throws -> SummaryCreator {
            return try await FFIBridge.execute {
                var summary = FfiSummaryCreator()
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_summary_creator(&summary)
                }
                
                // Convert utterances to C format
                let ffiUtterances = utterances.map { $0.toFfi() }
                let utterancePtrs: [FfiUtterance] = ffiUtterances
                
                // Free allocated C strings when done
                defer {
                    for utterance in ffiUtterances {
                        utterance.text?.deallocate()
                    }
                }
                
                let code = utterancePtrs.withUnsafeBufferPointer { utterancesPtr in
                    FFIBridge.withCString(self.token) { tokenPtr in
                        transcribe_ffi_create_summary(
                            utterancesPtr.baseAddress,
                            UInt(utterances.count),
                            tokenPtr,
                            &summary,
                            errorManager.getPointer()
                        )
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                return summary.toSwift()
            }
        }
        
        // MARK: - Translation
        
        /// Translate text
        public func translateText(
            text: String,
            targetLang: Language
        ) async throws -> TextTranslator {
            return try await FFIBridge.execute {
                var result = FfiTextTranslator()
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_text_translator(&result)
                }
                
                let code = FFIBridge.withCString(text) { textPtr in
                    FFIBridge.withCString(targetLang.toFfiString()) { langPtr in
                        FFIBridge.withCString(self.token) { tokenPtr in
                            transcribe_ffi_translate_text(
                                textPtr,
                                langPtr,
                                tokenPtr,
                                &result,
                                errorManager.getPointer()
                            )
                        }
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                return result.toSwift()
            }
        }
        
        /// Translate utterances
        public func translateUtterance(
            utterances: [Utterance],
            targetLang: Language
        ) async throws -> UtteranceTranslator {
            return try await FFIBridge.execute {
                var result = FfiUtteranceTranslator(
                    status: nil,
                    lang: .chineseSimplified,
                    details: nil,
                    details_len: 0
                )
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_utterance_translator(&result)
                }
                
                // Convert utterances to C format
                let ffiUtterances = utterances.map { $0.toFfi() }
                let utterancePtrs: [FfiUtterance] = ffiUtterances
                
                // Free allocated C strings when done
                defer {
                    for utterance in ffiUtterances {
                        utterance.text?.deallocate()
                    }
                }
                
                let code = utterancePtrs.withUnsafeBufferPointer { utterancesPtr in
                    FFIBridge.withCString(targetLang.toFfiString()) { langPtr in
                        FFIBridge.withCString(self.token) { tokenPtr in
                            transcribe_ffi_translate_utterance(
                                utterancesPtr.baseAddress,
                                UInt(utterances.count),
                                langPtr,
                                tokenPtr,
                                &result,
                                errorManager.getPointer()
                            )
                        }
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                return result.toSwift()
            }
        }
        
        /// Translate transcription task
        public func translateTranscribe(
            taskId: String,
            targetLang: Language
        ) async throws -> TranscribeTranslator {
            return try await FFIBridge.execute {
                var result = FfiTranscribeTranslator(
                    task_id: nil,
                    task_type: .transcribe,
                    status: nil,
                    lang: .chineseSimplified,
                    message: nil,
                    details: nil,
                    details_len: 0,
                    overview_md: nil,
                    summary_md: nil,
                    keywords: nil,
                    keywords_len: 0
                )
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_transcribe_translator(&result)
                }
                
                let code = FFIBridge.withCString(taskId) { taskIdPtr in
                    FFIBridge.withCString(targetLang.toFfiString()) { langPtr in
                        FFIBridge.withCString(self.token) { tokenPtr in
                            transcribe_ffi_translate_transcribe(
                                taskIdPtr,
                                langPtr,
                                tokenPtr,
                                &result,
                                errorManager.getPointer()
                            )
                        }
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                return result.toSwift()
            }
        }
        
        // MARK: - Callback
        
        /// Handle callback (server-side use)
        /// Note: This is typically used on the server side when receiving callbacks from the API
        public func handleCallback(
            request: FfiCallbackRequest,
            response: inout FfiCallbackResponse
        ) async throws -> FfiCallbackResponse {
            // Create a local copy to avoid capturing 'inout' parameter in escaping closure
            var localResponse = response
            
            let result = try await FFIBridge.execute {
                let errorManager = FfiErrorManager()
                
                defer {
                    transcribe_ffi_free_callback_response(&localResponse)
                }
                
                let code = FFIBridge.withCString(self.token) { tokenPtr in
                    withUnsafePointer(to: request) { requestPtr in
                        transcribe_ffi_callback(
                            requestPtr,
                            tokenPtr,
                            &localResponse,
                            errorManager.getPointer()
                        )
                    }
                }
                
                try FFIBridge.callFFI(errorCode: code, errorManager: errorManager)
                return localResponse
            }
            
            // Update the original inout parameter outside the closure
            response = result
            return result
        }
    }
}

