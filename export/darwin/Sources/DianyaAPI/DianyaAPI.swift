// DianyaAPI - Swift Package for Dianya AI Transcription Services
//
// This module provides a Swift interface to the Dianya AI transcription API,
// wrapping the C FFI layer for use in iOS and macOS applications.

import Foundation
import Combine

/// Main namespace for DianyaAPI
public enum DianyaAPI {
    // All public types are exported through this namespace
}

// Re-export public types
public typealias TranscribeApi = DianyaAPI.TranscribeApi
public typealias TranscribeStream = DianyaAPI.TranscribeStream

// Note: TranscribeError is defined in ErrorModels.swift as a top-level type
// It can be used directly as TranscribeError without the DianyaAPI prefix
// To use it as DianyaAPI.TranscribeError, we need to import the module properly

