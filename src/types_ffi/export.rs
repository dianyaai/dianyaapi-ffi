use transcribe::transcribe::{ExportFormat, ExportType};

#[repr(C)]
pub enum FfiTranscribeExportType {
    /// 转写内容（注意：总结任务不支持此类型）
    Transcript,
    /// 概览内容
    Overview,
    /// 总结内容
    Summary,
}

impl From<ExportType> for FfiTranscribeExportType {
    fn from(t: ExportType) -> Self {
        match t {
            ExportType::Transcript => Self::Transcript,
            ExportType::Overview => Self::Overview,
            ExportType::Summary => Self::Summary,
        }
    }
}

#[repr(C)]
pub enum FfiTranscribeExportFormat {
    Pdf,
    /// TXT 文本格式
    Txt,
    /// DOCX Word 文档格式
    Docx,
}

impl From<ExportFormat> for FfiTranscribeExportFormat {
    fn from(f: ExportFormat) -> Self {
        match f {
            ExportFormat::Pdf => Self::Pdf,
            ExportFormat::Txt => Self::Txt,
            ExportFormat::Docx => Self::Docx,
        }
    }
}
