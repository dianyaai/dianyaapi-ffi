import Foundation

// MARK: - Core Models

/// A single utterance (speech segment) with timing and speaker information
public struct Utterance: Codable, Equatable {
    /// Start time in seconds
    public let startTime: Double
    /// End time in seconds
    public let endTime: Double
    /// Speaker identifier
    public let speaker: Int32
    /// Transcribed text
    public let text: String
    
    public init(startTime: Double, endTime: Double, speaker: Int32, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.speaker = speaker
        self.text = text
    }
}

/// Model type for transcription
public enum ModelType: String, Codable {
    case speed = "speed"
    case quality = "quality"
    case qualityV2 = "quality_v2"
}

/// Language for translation
public enum Language: String, Codable {
    case chineseSimplified = "zh"
    case englishUS = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
}

/// Task type for transcription
public enum TranscribeTaskType: String, Codable {
    case normalQuality = "normal_quality"
    case normalSpeed = "normal_speed"
    case shortAsrQuality = "short_asr_quality"
    case shortAsrSpeed = "short_asr_speed"
}

/// Task type for translation
public enum TranslateTaskType: String, Codable {
    case transcribe = "transcribe"
    case summary = "summary"
}

/// Export format
public enum ExportFormat: String, Codable {
    case pdf = "pdf"
    case txt = "txt"
    case docx = "docx"
}

/// Export type
public enum ExportType: String, Codable {
    case transcript = "transcript"
    case overview = "overview"
    case summary = "summary"
}

// MARK: - Upload Models

/// Upload result - can be either normal mode or one-sentence mode
public enum UploadResult: Equatable {
    case normal(taskId: String)
    case oneSentence(status: String, message: String, data: String)
}

// MARK: - Status Models

/// Callback history entry
public struct CallbackHistory: Codable, Equatable {
    public let timestamp: String
    public let status: String
    public let code: UInt32
    
    public init(timestamp: String, status: String, code: UInt32) {
        self.timestamp = timestamp
        self.status = status
        self.code = code
    }
}

/// Transcription status
public struct TranscribeStatus: Codable, Equatable {
    public let status: String
    public let overviewMd: String?
    public let summaryMd: String?
    public let details: [Utterance]
    public let message: String?
    public let usageId: String?
    public let taskId: String?
    public let keywords: [String]
    public let callbackHistory: [CallbackHistory]
    public let taskType: TranscribeTaskType?
    
    public init(
        status: String,
        overviewMd: String? = nil,
        summaryMd: String? = nil,
        details: [Utterance] = [],
        message: String? = nil,
        usageId: String? = nil,
        taskId: String? = nil,
        keywords: [String] = [],
        callbackHistory: [CallbackHistory] = [],
        taskType: TranscribeTaskType? = nil
    ) {
        self.status = status
        self.overviewMd = overviewMd
        self.summaryMd = summaryMd
        self.details = details
        self.message = message
        self.usageId = usageId
        self.taskId = taskId
        self.keywords = keywords
        self.callbackHistory = callbackHistory
        self.taskType = taskType
    }
}

// MARK: - Share Models

/// Share link result
public struct ShareLink: Codable, Equatable {
    public let shareUrl: String
    public let expirationDay: Int32
    public let expiredAt: String
    
    public init(shareUrl: String, expirationDay: Int32, expiredAt: String) {
        self.shareUrl = shareUrl
        self.expirationDay = expirationDay
        self.expiredAt = expiredAt
    }
}

// MARK: - Summary Models

/// Summary creator result
public struct SummaryCreator: Codable, Equatable {
    public let taskId: String
    
    public init(taskId: String) {
        self.taskId = taskId
    }
}

// MARK: - Translation Models

/// Text translation result
public struct TextTranslator: Codable, Equatable {
    public let status: String
    public let data: String
    
    public init(status: String, data: String) {
        self.status = status
        self.data = data
    }
}

/// Utterance translation result
public struct UtteranceTranslator: Codable, Equatable {
    public let status: String
    public let lang: Language
    public let details: [Utterance]
    
    public init(status: String, lang: Language, details: [Utterance]) {
        self.status = status
        self.lang = lang
        self.details = details
    }
}

/// Translation detail for a single utterance
public struct TranslateDetail: Codable, Equatable {
    public let utterance: Utterance
    public let translation: String
    
    public init(utterance: Utterance, translation: String) {
        self.utterance = utterance
        self.translation = translation
    }
}

/// Transcribe translation result
public struct TranscribeTranslator: Codable, Equatable {
    public let taskId: String
    public let taskType: TranslateTaskType
    public let status: String
    public let lang: Language
    public let message: String?
    public let details: [TranslateDetail]
    public let overviewMd: String?
    public let summaryMd: String?
    public let keywords: [String]
    
    public init(
        taskId: String,
        taskType: TranslateTaskType,
        status: String,
        lang: Language,
        message: String? = nil,
        details: [TranslateDetail] = [],
        overviewMd: String? = nil,
        summaryMd: String? = nil,
        keywords: [String] = []
    ) {
        self.taskId = taskId
        self.taskType = taskType
        self.status = status
        self.lang = lang
        self.message = message
        self.details = details
        self.overviewMd = overviewMd
        self.summaryMd = summaryMd
        self.keywords = keywords
    }
}

