import Foundation
import Dispatch

/// Thread-safe wrapper for C FFI function calls
internal class FFIBridge {
    /// Serial queue for FFI calls to ensure thread safety
    private static let ffiQueue = DispatchQueue(label: "com.dianyaapi.ffi", qos: .userInitiated)
    
    /// Execute FFI call on background queue
    static func execute<T>(_ block: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            ffiQueue.async {
                do {
                    let result = try block()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Convert Swift String to C string, execute block, then free
    static func withCString<T>(_ string: String, _ body: (UnsafePointer<CChar>) throws -> T) rethrows -> T {
        return try string.withCString { cString in
            try body(cString)
        }
    }
    
    /// Convert optional Swift String to C string
    static func withOptionalCString<T>(_ string: String?, _ body: (UnsafePointer<CChar>?) throws -> T) rethrows -> T {
        if let string = string {
            return try string.withCString { cString in
                try body(cString)
            }
        } else {
            return try body(nil)
        }
    }
    
    /// Call FFI function and handle error
    static func callFFI(
        errorCode: Int32,
        errorManager: FfiErrorManager
    ) throws {
        guard errorCode == 0 else {
            if let swiftError = errorManager.toSwiftError() {
                print("❌ [FFIBridge] FFI 调用返回错误: \(swiftError)")
                throw swiftError
            } else {
                let error = TranscribeError.otherError("Unknown error with code: \(errorCode)")
                print("❌ [FFIBridge] FFI 调用返回未知错误码: \(errorCode)")
                throw error
            }
        }
    }
}

// MARK: - C Structure Definitions (matching C header)

internal struct FfiError {
    var code: ErrorCode
    var message: UnsafeMutablePointer<CChar>?
}

internal struct FfiShareLink {
    var share_url: UnsafeMutablePointer<CChar>?
    var expiration_day: Int32
    var expired_at: UnsafeMutablePointer<CChar>?
}

internal struct FfiUtterance {
    var start_time: Double
    var end_time: Double
    var speaker: Int32
    var text: UnsafeMutablePointer<CChar>?
}

internal struct FfiCallbackHistory {
    var timestamp: UnsafeMutablePointer<CChar>?
    var status: UnsafeMutablePointer<CChar>?
    var code: UInt32
}

internal struct FfiTranscribeStatus {
    var status: UnsafeMutablePointer<CChar>?
    var overview_md: UnsafeMutablePointer<CChar>?
    var summary_md: UnsafeMutablePointer<CChar>?
    var details: UnsafeMutablePointer<FfiUtterance>?
    var details_len: UInt
    var message: UnsafeMutablePointer<CChar>?
    var usage_id: UnsafeMutablePointer<CChar>?
    var task_id: UnsafeMutablePointer<CChar>?
    var keywords: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
    var keywords_len: UInt
    var callback_history: UnsafeMutablePointer<FfiCallbackHistory>?
    var callback_history_len: UInt
    var task_type: FfiTranscribeTaskType
    var has_task_type: Bool
}

internal struct FfiSummaryCreator {
    var task_id: UnsafeMutablePointer<CChar>?
}

internal struct FfiUploadNormal {
    var task_id: UnsafeMutablePointer<CChar>?
}

internal struct FfiUploadOneSentence {
    var status: UnsafeMutablePointer<CChar>?
    var message: UnsafeMutablePointer<CChar>?
    var data: UnsafeMutablePointer<CChar>?
}

internal struct FfiUploadResponse {
    var is_normal: Bool
    var normal: FfiUploadNormal
    var one_sentence: FfiUploadOneSentence
}

internal struct FfiTextTranslator {
    var status: UnsafeMutablePointer<CChar>?
    var data: UnsafeMutablePointer<CChar>?
}

internal struct FfiUtteranceTranslator {
    var status: UnsafeMutablePointer<CChar>?
    var lang: FfiLanguage
    var details: UnsafeMutablePointer<FfiUtterance>?
    var details_len: UInt
}

internal struct FfiTranslateDetail {
    var utterance: FfiUtterance
    var translation: UnsafeMutablePointer<CChar>?
}

internal struct FfiTranscribeTranslator {
    var task_id: UnsafeMutablePointer<CChar>?
    var task_type: FfiTranslateTaskType
    var status: UnsafeMutablePointer<CChar>?
    var lang: FfiLanguage
    var message: UnsafeMutablePointer<CChar>?
    var details: UnsafeMutablePointer<FfiTranslateDetail>?
    var details_len: UInt
    var overview_md: UnsafeMutablePointer<CChar>?
    var summary_md: UnsafeMutablePointer<CChar>?
    var keywords: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
    var keywords_len: UInt
}

public struct FfiCallbackResponse {
    var status: UnsafeMutablePointer<CChar>?
}

internal struct FfiSessionCreator {
    var task_id: UnsafeMutablePointer<CChar>?
    var session_id: UnsafeMutablePointer<CChar>?
    var usage_id: UnsafeMutablePointer<CChar>?
    var max_time: Int32
}

internal struct FfiSessionEnder {
    var status: UnsafeMutablePointer<CChar>?
    var duration: Int32
    var has_duration: Bool
    var error_code: Int32
    var has_error_code: Bool
    var message: UnsafeMutablePointer<CChar>?
}

// MARK: - C Enum Definitions

internal enum FfiTranscribeTaskType: UInt32 {
    case normalQuality = 0
    case normalSpeed = 1
    case shortAsrQuality = 2
    case shortAsrSpeed = 3
}

internal enum FfiLanguage: UInt32 {
    case chineseSimplified = 0
    case englishUS = 1
    case japanese = 2
    case korean = 3
    case french = 4
    case german = 5
}

internal enum FfiTranslateTaskType: UInt32 {
    case transcribe = 0
    case summary = 1
}

// MARK: - Opaque C Types

/// Opaque pointer to TranscribeStream (C struct)
internal typealias TranscribeStreamPtr = OpaquePointer

// MARK: - C Function Declarations

@_silgen_name("transcribe_ffi_free_error")
internal func transcribe_ffi_free_error(_ e: UnsafeMutablePointer<FfiError>)

@_silgen_name("transcribe_ffi_export")
internal func transcribe_ffi_export(
    _ task_id: UnsafePointer<CChar>?,
    _ export_type: UnsafePointer<CChar>?,
    _ export_format: UnsafePointer<CChar>?,
    _ token: UnsafePointer<CChar>?,
    _ result_data: UnsafeMutablePointer<UInt8>?,
    _ result_len: UnsafeMutablePointer<UInt>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_get_share_link")
internal func transcribe_ffi_get_share_link(
    _ task_id: UnsafePointer<CChar>?,
    _ expiration_day: Int32,
    _ token: UnsafePointer<CChar>?,
    _ out_link: UnsafeMutablePointer<FfiShareLink>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_get_status")
internal func transcribe_ffi_get_status(
    _ task_id: UnsafePointer<CChar>?,
    _ share_id: UnsafePointer<CChar>?,
    _ token: UnsafePointer<CChar>?,
    _ out_status: UnsafeMutablePointer<FfiTranscribeStatus>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_create_summary")
internal func transcribe_ffi_create_summary(
    _ utterances: UnsafePointer<FfiUtterance>?,
    _ utterances_len: UInt,
    _ token: UnsafePointer<CChar>?,
    _ out_summary: UnsafeMutablePointer<FfiSummaryCreator>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_upload")
internal func transcribe_ffi_upload(
    _ filepath: UnsafePointer<CChar>?,
    _ transcribe_only: Bool,
    _ short_asr: Bool,
    _ model: UnsafePointer<CChar>?,
    _ token: UnsafePointer<CChar>?,
    _ out_result: UnsafeMutablePointer<FfiUploadResponse>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_translate_text")
internal func transcribe_ffi_translate_text(
    _ text: UnsafePointer<CChar>?,
    _ target_lang: UnsafePointer<CChar>?,
    _ token: UnsafePointer<CChar>?,
    _ out_result: UnsafeMutablePointer<FfiTextTranslator>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_translate_utterance")
internal func transcribe_ffi_translate_utterance(
    _ utterances: UnsafePointer<FfiUtterance>?,
    _ utterances_len: UInt,
    _ target_lang: UnsafePointer<CChar>?,
    _ token: UnsafePointer<CChar>?,
    _ out_result: UnsafeMutablePointer<FfiUtteranceTranslator>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_translate_transcribe")
internal func transcribe_ffi_translate_transcribe(
    _ task_id: UnsafePointer<CChar>?,
    _ target_lang: UnsafePointer<CChar>?,
    _ token: UnsafePointer<CChar>?,
    _ out_result: UnsafeMutablePointer<FfiTranscribeTranslator>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_callback")
internal func transcribe_ffi_callback(
    _ request: UnsafePointer<FfiCallbackRequest>?,
    _ token: UnsafePointer<CChar>?,
    _ out_response: UnsafeMutablePointer<FfiCallbackResponse>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_create_session")
internal func transcribe_ffi_create_session(
    _ model: UnsafePointer<CChar>?,
    _ token: UnsafePointer<CChar>?,
    _ out_session: UnsafeMutablePointer<FfiSessionCreator>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_close_session")
internal func transcribe_ffi_close_session(
    _ task_id: UnsafePointer<CChar>?,
    _ token: UnsafePointer<CChar>?,
    _ timeout: UInt64,
    _ out_result: UnsafeMutablePointer<FfiSessionEnder>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_ws_create")
internal func transcribe_ffi_ws_create(
    _ session_id: UnsafePointer<CChar>?,
    _ handle: UnsafeMutablePointer<TranscribeStreamPtr?>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_ws_start")
internal func transcribe_ffi_ws_start(
    _ handle: TranscribeStreamPtr?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_ws_write_txt")
internal func transcribe_ffi_ws_write_txt(
    _ handle: TranscribeStreamPtr?,
    _ text: UnsafePointer<CChar>?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_ws_write_bytes")
internal func transcribe_ffi_ws_write_bytes(
    _ handle: TranscribeStreamPtr?,
    _ data: UnsafePointer<UInt8>?,
    _ data_len: UInt,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_ws_stop")
internal func transcribe_ffi_ws_stop(
    _ handle: TranscribeStreamPtr?,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_ws_receive")
internal func transcribe_ffi_ws_receive(
    _ handle: TranscribeStreamPtr?,
    _ message_json: UnsafeMutablePointer<CChar>?,
    _ message_len: UnsafeMutablePointer<UInt>?,
    _ timeout_ms: UInt64,
    _ out_error: UnsafeMutablePointer<FfiError>?
) -> Int32

@_silgen_name("transcribe_ffi_ws_free")
internal func transcribe_ffi_ws_free(_ handle: TranscribeStreamPtr?)

@_silgen_name("transcribe_ffi_free_share_link")
internal func transcribe_ffi_free_share_link(_ s: UnsafeMutablePointer<FfiShareLink>)

@_silgen_name("transcribe_ffi_free_transcribe_status")
internal func transcribe_ffi_free_transcribe_status(_ s: UnsafeMutablePointer<FfiTranscribeStatus>)

@_silgen_name("transcribe_ffi_free_callback_response")
internal func transcribe_ffi_free_callback_response(_ s: UnsafeMutablePointer<FfiCallbackResponse>)

@_silgen_name("transcribe_ffi_free_summary_creator")
internal func transcribe_ffi_free_summary_creator(_ s: UnsafeMutablePointer<FfiSummaryCreator>)

@_silgen_name("transcribe_ffi_free_text_translator")
internal func transcribe_ffi_free_text_translator(_ s: UnsafeMutablePointer<FfiTextTranslator>)

@_silgen_name("transcribe_ffi_free_utterance_translator")
internal func transcribe_ffi_free_utterance_translator(_ s: UnsafeMutablePointer<FfiUtteranceTranslator>)

@_silgen_name("transcribe_ffi_free_transcribe_translator")
internal func transcribe_ffi_free_transcribe_translator(_ s: UnsafeMutablePointer<FfiTranscribeTranslator>)

@_silgen_name("transcribe_ffi_free_upload_response")
internal func transcribe_ffi_free_upload_response(_ s: UnsafeMutablePointer<FfiUploadResponse>)

@_silgen_name("transcribe_ffi_free_session_creator")
internal func transcribe_ffi_free_session_creator(_ s: UnsafeMutablePointer<FfiSessionCreator>)

@_silgen_name("transcribe_ffi_free_session_ender")
internal func transcribe_ffi_free_session_ender(_ s: UnsafeMutablePointer<FfiSessionEnder>)

// Note: FfiCallbackRequest is opaque in C header, we'll need to handle it differently
public struct FfiCallbackRequest {
    // Opaque type - not directly accessible
}

