import Foundation

/// RAII-style wrapper for automatically freeing C resources
internal class AutoFree<T> {
    private let value: T
    private let freeFunc: (T) -> Void
    
    init(_ value: T, freeFunc: @escaping (T) -> Void) {
        self.value = value
        self.freeFunc = freeFunc
    }
    
    func get() -> T {
        return value
    }
    
    deinit {
        freeFunc(value)
    }
}

/// Helper for managing C string pointers
internal class CStringManager {
    let pointer: UnsafeMutablePointer<CChar>?
    
    init?(from string: String) {
        guard let cString = string.cString(using: .utf8) else {
            return nil
        }
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: cString.count)
        buffer.initialize(from: cString, count: cString.count)
        self.pointer = buffer
    }
    
    init(pointer: UnsafeMutablePointer<CChar>?) {
        self.pointer = pointer
    }
    
    func toString() -> String? {
        guard let pointer = pointer else { return nil }
        return String(cString: pointer)
    }
    
    deinit {
        pointer?.deallocate()
    }
}

/// Helper for managing C error structures
internal class FfiErrorManager {
    private var error: FfiError
    
    init() {
        self.error = FfiError(code: .otherError, message: nil)
    }
    
    func getPointer() -> UnsafeMutablePointer<FfiError> {
        return withUnsafeMutablePointer(to: &error) { $0 }
    }
    
    func toSwiftError() -> TranscribeError? {
        let code = ErrorCode(rawValue: error.code.rawValue) ?? .otherError
        let message = error.message.map { String(cString: $0) }
        return TranscribeError(code: code, message: message)
    }
    
    deinit {
        transcribe_ffi_free_error(&error)
    }
}

/// Helper for managing C structure pointers that need freeing
internal func withAutoFree<T, R>(
    _ value: UnsafeMutablePointer<T>,
    freeFunc: @escaping (UnsafeMutablePointer<T>) -> Void,
    _ body: (UnsafeMutablePointer<T>) throws -> R
) rethrows -> R {
    defer {
        freeFunc(value)
    }
    return try body(value)
}

/// Helper for managing optional C structure pointers
internal func withAutoFreeOptional<T, R>(
    _ value: UnsafeMutablePointer<T>?,
    freeFunc: @escaping (UnsafeMutablePointer<T>) -> Void,
    _ body: (UnsafeMutablePointer<T>?) throws -> R
) rethrows -> R {
    defer {
        if let value = value {
            freeFunc(value)
        }
    }
    return try body(value)
}

