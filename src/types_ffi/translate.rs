use crate::types_ffi::{
    free_c_string, free_string_array, free_translate_detail_array, free_utterance_array,
    FfiUtterance,
};
use common::Error;
use std::ffi::{c_char, CString};
use transcribe::translate::TaskType;
use transcribe::types::{Language, TextTranslator, TranscribeTranslator, UtteranceTranslator};

/// 翻译语言
#[repr(C)]
pub enum FfiLanguage {
    ChineseSimplified,
    EnglishUS,
    Japanese,
    Korean,
    French,
    German,
}

impl From<Language> for FfiLanguage {
    fn from(value: Language) -> Self {
        match value {
            Language::ChineseSimplified => Self::ChineseSimplified,
            Language::EnglishUS => Self::EnglishUS,
            Language::Japanese => Self::Japanese,
            Language::Korean => Self::Korean,
            Language::French => Self::French,
            Language::German => Self::German,
        }
    }
}

/// 翻译任务类型（转写 / 总结）
#[repr(C)]
pub enum FfiTranslateTaskType {
    Transcribe,
    Summary,
}

impl From<TaskType> for FfiTranslateTaskType {
    fn from(value: TaskType) -> Self {
        match value {
            TaskType::Transcribe => Self::Transcribe,
            TaskType::Summary => Self::Summary,
        }
    }
}

/// 具体翻译详情（单条）
#[repr(C)]
pub struct FfiTranslateDetail {
    pub utterance: FfiUtterance,
    pub translation: *mut c_char,
}

/// 转写翻译结果
#[repr(C)]
pub struct FfiTranscribeTranslator {
    pub task_id: *mut c_char,
    pub task_type: FfiTranslateTaskType,
    pub status: *mut c_char,
    pub lang: FfiLanguage,

    pub message: *mut c_char,

    pub details: *mut FfiTranslateDetail,
    pub details_len: usize,

    pub overview_md: *mut c_char,
    pub summary_md: *mut c_char,

    pub keywords: *mut *mut c_char,
    pub keywords_len: usize,
}

impl TryFrom<TranscribeTranslator> for FfiTranscribeTranslator {
    type Error = Error;
    fn try_from(v: TranscribeTranslator) -> Result<Self, Self::Error> {
        let lang = v.lang; // 保存 lang，因为后面需要用到
        let task_id = CString::new(v.task_id)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?
            .into_raw();
        let status = CString::new(v.status)
            .map_err(|e| {
                unsafe {
                    let _ = CString::from_raw(task_id);
                }
                Error::OtherError(format!("Failed to create CString: {}", e))
            })?
            .into_raw();
        let task_type = v.task_type.into();
        let lang_ffi = lang.into();

        let message = v
            .message
            .map(|s| {
                CString::new(s).map_err(|e| {
                    unsafe {
                        let _ = CString::from_raw(task_id);
                        let _ = CString::from_raw(status);
                    }
                    Error::OtherError(format!("Failed to create CString: {}", e))
                })
            })
            .transpose()?
            .map(|s| s.into_raw())
            .unwrap_or(std::ptr::null_mut());

        // details
        let (details_ptr, details_len) = if let Some(details_list) = v.details {
            let details: Vec<FfiTranslateDetail> = details_list
                .into_iter()
                .map(|d| -> Result<FfiTranslateDetail, Error> {
                    let translation = d.get_translation(lang).unwrap_or_default();
                    let utterance = FfiUtterance::try_from(d.utterance)?;
                    let translation_c = CString::new(translation).map_err(|e| {
                        unsafe {
                            let _ = CString::from_raw(utterance.text);
                        }
                        Error::OtherError(format!("Failed to create CString: {}", e))
                    })?;
                    Ok(FfiTranslateDetail {
                        utterance,
                        translation: translation_c.into_raw(),
                    })
                })
                .collect::<Result<Vec<_>, Error>>()?;
            let details_len = details.len();
            let details_ptr = if details_len > 0 {
                let boxed = details.into_boxed_slice();
                Box::into_raw(boxed) as *mut FfiTranslateDetail
            } else {
                std::ptr::null_mut()
            };
            (details_ptr, details_len)
        } else {
            (std::ptr::null_mut(), 0)
        };

        let overview_md = v
            .overview_md
            .map(|s| {
                CString::new(s).map_err(|e| {
                    unsafe {
                        let _ = CString::from_raw(task_id);
                        let _ = CString::from_raw(status);
                        if !message.is_null() {
                            let _ = CString::from_raw(message);
                        }
                    }
                    Error::OtherError(format!("Failed to create CString: {}", e))
                })
            })
            .transpose()?
            .map(|s| s.into_raw())
            .unwrap_or(std::ptr::null_mut());

        let summary_md = v
            .summary_md
            .map(|s| {
                CString::new(s).map_err(|e| {
                    unsafe {
                        let _ = CString::from_raw(task_id);
                        let _ = CString::from_raw(status);
                        if !message.is_null() {
                            let _ = CString::from_raw(message);
                        }
                        if !overview_md.is_null() {
                            let _ = CString::from_raw(overview_md);
                        }
                    }
                    Error::OtherError(format!("Failed to create CString: {}", e))
                })
            })
            .transpose()?
            .map(|s| s.into_raw())
            .unwrap_or(std::ptr::null_mut());

        // keywords
        let (keywords_ptr, keywords_len) = if let Some(keywords_list) = v.keywords {
            let keywords: Vec<*mut c_char> = keywords_list
                .into_iter()
                .filter_map(|kw| CString::new(kw).ok().map(|s| s.into_raw()))
                .collect();
            let keywords_len = keywords.len();
            let keywords_ptr = if keywords_len > 0 {
                let boxed = keywords.into_boxed_slice();
                Box::into_raw(boxed) as *mut *mut c_char
            } else {
                std::ptr::null_mut()
            };
            (keywords_ptr, keywords_len)
        } else {
            (std::ptr::null_mut(), 0)
        };

        Ok(Self {
            task_id,
            task_type,
            status,
            lang: lang_ffi,
            message,
            details: details_ptr,
            details_len,
            overview_md,
            summary_md,
            keywords: keywords_ptr,
            keywords_len,
        })
    }
}

/// 文本翻译结果
#[repr(C)]
pub struct FfiTextTranslator {
    pub status: *mut c_char,
    pub data: *mut c_char,
}

impl TryFrom<TextTranslator> for FfiTextTranslator {
    type Error = common::Error;
    fn try_from(v: TextTranslator) -> Result<Self, Self::Error> {
        let status = CString::new(v.status)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?
            .into_raw();
        let data = CString::new(v.data)
            .map_err(|e| {
                unsafe {
                    let _ = CString::from_raw(status);
                }
                Error::OtherError(format!("Failed to create CString: {}", e))
            })?
            .into_raw();
        Ok(Self { status, data })
    }
}

/// Utterance 翻译结果
#[repr(C)]
pub struct FfiUtteranceTranslator {
    pub status: *mut c_char,
    pub lang: FfiLanguage,
    pub details: *mut FfiUtterance,
    pub details_len: usize,
}

impl TryFrom<UtteranceTranslator> for FfiUtteranceTranslator {
    type Error = Error;
    fn try_from(v: UtteranceTranslator) -> Result<Self, Self::Error> {
        let status = CString::new(v.status)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?
            .into_raw();
        let lang = v.lang.into();
        let details = v
            .details
            .into_iter()
            .map(FfiUtterance::try_from)
            .collect::<Result<Vec<_>, Error>>()?;
        let details_len = details.len();
        let details_ptr = if details_len > 0 {
            let boxed = details.into_boxed_slice();
            Box::into_raw(boxed) as *mut FfiUtterance
        } else {
            std::ptr::null_mut()
        };

        Ok(Self {
            status,
            lang,
            details: details_ptr,
            details_len,
        })
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_text_translator(s: *mut FfiTextTranslator) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).status);
        free_c_string(&mut (*s).data);
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_utterance_translator(s: *mut FfiUtteranceTranslator) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).status);
        free_utterance_array(
            std::ptr::addr_of_mut!((*s).details),
            std::ptr::addr_of_mut!((*s).details_len),
        );
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_transcribe_translator(s: *mut FfiTranscribeTranslator) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).task_id);
        free_c_string(&mut (*s).status);
        free_c_string(&mut (*s).message);
        free_c_string(&mut (*s).overview_md);
        free_c_string(&mut (*s).summary_md);

        free_translate_detail_array(
            std::ptr::addr_of_mut!((*s).details),
            std::ptr::addr_of_mut!((*s).details_len),
        );
        free_string_array(
            std::ptr::addr_of_mut!((*s).keywords),
            std::ptr::addr_of_mut!((*s).keywords_len),
        );
    }
}
