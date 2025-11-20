use crate::error::FfiError;
use common::Error;
use std::ffi::{c_char, c_int, CStr};
use transcribe::transcribe::{ExportFormat, ExportType};
use transcribe::types::{Language, ModelType};

pub fn parse_c_str<T, F: FnOnce(&str) -> Result<T, Error>>(
    s: *const c_char,
    f: F,
) -> Result<T, Error> {
    unsafe {
        if s.is_null() {
            return Err(Error::InvalidInput("s is null".to_string()));
        }

        let c_str = CStr::from_ptr(s);
        let str = c_str
            .to_str()
            .map_err(|e| Error::InvalidInput(e.to_string()))?;
        f(str)
    }
}

pub fn parse_model_type(s: *const c_char) -> Result<ModelType, Error> {
    parse_c_str(s, |s| match s.to_ascii_lowercase().as_str() {
        "speed" => Ok(ModelType::Speed),
        "quality" => Ok(ModelType::Quality),
        "quality_v2" => Ok(ModelType::QualityV2),
        _ => Err(Error::InvalidInput("Invalid model type".to_string())),
    })
}

pub fn parse_language(s: *const c_char) -> Result<Language, Error> {
    parse_c_str(s, |s| match s.to_ascii_lowercase().as_str() {
        "zh" => Ok(Language::ChineseSimplified),
        "en" => Ok(Language::EnglishUS),
        "ja" => Ok(Language::Japanese),
        "ko" => Ok(Language::Korean),
        "fr" => Ok(Language::French),
        "de" => Ok(Language::German),
        _ => Err(Error::InvalidInput("Invalid language".to_string())),
    })
}

pub fn parse_format_type(s: *const c_char) -> Result<ExportFormat, Error> {
    parse_c_str(s, |s| match s.to_ascii_lowercase().as_str() {
        "pdf" => Ok(ExportFormat::Pdf),
        "txt" => Ok(ExportFormat::Txt),
        "docx" => Ok(ExportFormat::Docx),
        _ => Err(Error::InvalidInput("Invalid format type".to_string())),
    })
}

pub fn parse_transcribe_export_type(s: *const c_char) -> Result<ExportType, Error> {
    parse_c_str(s, |s| match s.to_ascii_lowercase().as_str() {
        "transcript" => Ok(ExportType::Transcript),
        "overview" => Ok(ExportType::Overview),
        "summary" => Ok(ExportType::Summary),
        _ => Err(Error::InvalidInput("Invalid export type".to_string())),
    })
}

pub fn ffi_execute<T, F: FnOnce(T) -> Result<(), Error>>(
    params: T,
    error: *mut FfiError,
    f: F,
) -> c_int {
    match f(params) {
        Ok(()) => 0,
        Err(e) => FfiError::fill_error(error, e),
    }
}
