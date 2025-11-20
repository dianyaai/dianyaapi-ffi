import Foundation

// MARK: - C to Swift Type Converters

internal extension FfiUtterance {
    func toSwift() -> Utterance {
        let text = self.text.map { String(cString: $0) } ?? ""
        return Utterance(
            startTime: self.start_time,
            endTime: self.end_time,
            speaker: self.speaker,
            text: text
        )
    }
}

internal extension FfiTranscribeStatus {
    func toSwift() -> TranscribeStatus {
        let status = self.status.map { String(cString: $0) } ?? ""
        let overviewMd = self.overview_md.map { String(cString: $0) }
        let summaryMd = self.summary_md.map { String(cString: $0) }
        let message = self.message.map { String(cString: $0) }
        let usageId = self.usage_id.map { String(cString: $0) }
        let taskId = self.task_id.map { String(cString: $0) }
        
        // Convert details array
        var details: [Utterance] = []
        if let detailsPtr = self.details, self.details_len > 0 {
            let detailsSlice = UnsafeBufferPointer(
                start: detailsPtr,
                count: Int(self.details_len)
            )
            details = detailsSlice.map { $0.toSwift() }
        }
        
        // Convert keywords array
        var keywords: [String] = []
        if let keywordsPtr = self.keywords, self.keywords_len > 0 {
            let keywordsSlice = UnsafeBufferPointer(
                start: keywordsPtr,
                count: Int(self.keywords_len)
            )
            keywords = keywordsSlice.compactMap { ptr in
                ptr.map { String(cString: $0) }
            }
        }
        
        // Convert callback history array
        var callbackHistory: [CallbackHistory] = []
        if let historyPtr = self.callback_history, self.callback_history_len > 0 {
            let historySlice = UnsafeBufferPointer(
                start: historyPtr,
                count: Int(self.callback_history_len)
            )
            callbackHistory = historySlice.map { item in
                CallbackHistory(
                    timestamp: item.timestamp.map { String(cString: $0) } ?? "",
                    status: item.status.map { String(cString: $0) } ?? "",
                    code: item.code
                )
            }
        }
        
        let taskType: TranscribeTaskType? = self.has_task_type ? {
            switch self.task_type {
            case .normalQuality:
                return .normalQuality
            case .normalSpeed:
                return .normalSpeed
            case .shortAsrQuality:
                return .shortAsrQuality
            case .shortAsrSpeed:
                return .shortAsrSpeed
            @unknown default:
                return nil
            }
        }() : nil
        
        return TranscribeStatus(
            status: status,
            overviewMd: overviewMd,
            summaryMd: summaryMd,
            details: details,
            message: message,
            usageId: usageId,
            taskId: taskId,
            keywords: keywords,
            callbackHistory: callbackHistory,
            taskType: taskType
        )
    }
}

internal extension FfiSessionCreator {
    func toSwift() -> SessionInfo {
        let taskId = self.task_id.map { String(cString: $0) } ?? ""
        let sessionId = self.session_id.map { String(cString: $0) } ?? ""
        let usageId = self.usage_id.map { String(cString: $0) } ?? ""
        
        return SessionInfo(
            taskId: taskId,
            sessionId: sessionId,
            usageId: usageId,
            maxTime: self.max_time
        )
    }
}

internal extension FfiSessionEnder {
    func toSwift() -> SessionCloseResult {
        let status = self.status.map { String(cString: $0) } ?? ""
        let duration = self.has_duration ? self.duration : nil
        let errorCode = self.has_error_code ? self.error_code : nil
        let message = self.message.map { String(cString: $0) }
        
        return SessionCloseResult(
            status: status,
            duration: duration,
            errorCode: errorCode,
            message: message
        )
    }
}

internal extension FfiShareLink {
    func toSwift() -> ShareLink {
        let shareUrl = self.share_url.map { String(cString: $0) } ?? ""
        let expiredAt = self.expired_at.map { String(cString: $0) } ?? ""
        
        return ShareLink(
            shareUrl: shareUrl,
            expirationDay: self.expiration_day,
            expiredAt: expiredAt
        )
    }
}

internal extension FfiUploadResponse {
    func toSwift() -> UploadResult {
        if self.is_normal {
            let taskId = self.normal.task_id.map { String(cString: $0) } ?? ""
            return UploadResult.normal(taskId: taskId)
        } else {
            let status = self.one_sentence.status.map { String(cString: $0) } ?? ""
            let message = self.one_sentence.message.map { String(cString: $0) } ?? ""
            let data = self.one_sentence.data.map { String(cString: $0) } ?? ""
            return UploadResult.oneSentence(
                status: status,
                message: message,
                data: data
            )
        }
    }
}

internal extension FfiSummaryCreator {
    func toSwift() -> SummaryCreator {
        let taskId = self.task_id.map { String(cString: $0) } ?? ""
        return SummaryCreator(taskId: taskId)
    }
}

internal extension FfiTextTranslator {
    func toSwift() -> TextTranslator {
        let status = self.status.map { String(cString: $0) } ?? ""
        let data = self.data.map { String(cString: $0) } ?? ""
        return TextTranslator(status: status, data: data)
    }
}

internal extension FfiUtteranceTranslator {
    func toSwift() -> UtteranceTranslator {
        let status = self.status.map { String(cString: $0) } ?? ""
        
        var details: [Utterance] = []
        if let detailsPtr = self.details, self.details_len > 0 {
            let detailsSlice = UnsafeBufferPointer(
                start: detailsPtr,
                count: Int(self.details_len)
            )
            details = detailsSlice.map { $0.toSwift() }
        }
        
        let lang: Language = {
            switch self.lang {
            case .chineseSimplified:
                return .chineseSimplified
            case .englishUS:
                return .englishUS
            case .japanese:
                return .japanese
            case .korean:
                return .korean
            case .french:
                return .french
            case .german:
                return .german
            @unknown default:
                return .chineseSimplified
            }
        }()
        
        return UtteranceTranslator(
            status: status,
            lang: lang,
            details: details
        )
    }
}

internal extension FfiTranscribeTranslator {
    func toSwift() -> TranscribeTranslator {
        let taskId = self.task_id.map { String(cString: $0) } ?? ""
        let status = self.status.map { String(cString: $0) } ?? ""
        let message = self.message.map { String(cString: $0) }
        let overviewMd = self.overview_md.map { String(cString: $0) }
        let summaryMd = self.summary_md.map { String(cString: $0) }
        
        let taskType: TranslateTaskType = {
            switch self.task_type {
            case .transcribe:
                return .transcribe
            case .summary:
                return .summary
            @unknown default:
                return .transcribe
            }
        }()
        
        let lang: Language = {
            switch self.lang {
            case .chineseSimplified:
                return .chineseSimplified
            case .englishUS:
                return .englishUS
            case .japanese:
                return .japanese
            case .korean:
                return .korean
            case .french:
                return .french
            case .german:
                return .german
            @unknown default:
                return .chineseSimplified
            }
        }()
        
        var details: [TranslateDetail] = []
        if let detailsPtr = self.details, self.details_len > 0 {
            let detailsSlice = UnsafeBufferPointer(
                start: detailsPtr,
                count: Int(self.details_len)
            )
            details = detailsSlice.map { item in
                let utterance = item.utterance.toSwift()
                let translation = item.translation.map { String(cString: $0) } ?? ""
                return TranslateDetail(
                    utterance: utterance,
                    translation: translation
                )
            }
        }
        
        var keywords: [String] = []
        if let keywordsPtr = self.keywords, self.keywords_len > 0 {
            let keywordsSlice = UnsafeBufferPointer(
                start: keywordsPtr,
                count: Int(self.keywords_len)
            )
            keywords = keywordsSlice.compactMap { ptr in
                ptr.map { String(cString: $0) }
            }
        }
        
        return TranscribeTranslator(
            taskId: taskId,
            taskType: taskType,
            status: status,
            lang: lang,
            message: message,
            details: details,
            overviewMd: overviewMd,
            summaryMd: summaryMd,
            keywords: keywords
        )
    }
}

// MARK: - Swift to C Type Converters

internal extension Utterance {
    func toFfi() -> FfiUtterance {
        let textCString = self.text.utf8CString
        let textPtr = UnsafeMutablePointer<CChar>.allocate(capacity: textCString.count)
        textCString.withUnsafeBufferPointer { buffer in
            if let baseAddress = buffer.baseAddress {
                textPtr.initialize(from: baseAddress, count: textCString.count)
            }
        }
        
        return FfiUtterance(
            start_time: self.startTime,
            end_time: self.endTime,
            speaker: self.speaker,
            text: textPtr
        )
    }
}

internal extension ModelType {
    func toFfiString() -> String {
        switch self {
        case .speed:
            return "speed"
        case .quality:
            return "quality"
        case .qualityV2:
            return "quality_v2"
        }
    }
}

internal extension Language {
    func toFfiString() -> String {
        switch self {
        case .chineseSimplified:
            return "zh"
        case .englishUS:
            return "en"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        case .french:
            return "fr"
        case .german:
            return "de"
        }
    }
}

internal extension ExportType {
    func toFfiString() -> String {
        switch self {
        case .transcript:
            return "transcript"
        case .overview:
            return "overview"
        case .summary:
            return "summary"
        }
    }
}

internal extension ExportFormat {
    func toFfiString() -> String {
        switch self {
        case .pdf:
            return "pdf"
        case .txt:
            return "txt"
        case .docx:
            return "docx"
        }
    }
}

