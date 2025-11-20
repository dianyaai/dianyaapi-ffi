use crate::types_ffi::{
    free_c_string, free_callback_history_array, free_string_array, free_utterance_array,
};
use crate::FfiUtterance;
use common::Error;
use std::ffi::{c_char, CStr, CString};
use transcribe::transcribe::{CallbackRequest, CallbackResponse, TaskType, TranscribeStatus};
use transcribe::types::SummaryContent;
use transcribe::Utterance;

/// 状态中任务类型
#[repr(C)]
pub enum FfiTranscribeTaskType {
    NormalQuality,
    NormalSpeed,
    ShortAsrQuality,
    ShortAsrSpeed,
}

impl From<TaskType> for FfiTranscribeTaskType {
    fn from(t: TaskType) -> Self {
        match t {
            TaskType::NormalQuality => Self::NormalQuality,
            TaskType::NormalSpeed => Self::NormalSpeed,
            TaskType::ShortAsrQuality => Self::ShortAsrQuality,
            TaskType::ShortAsrSpeed => Self::ShortAsrSpeed,
        }
    }
}

#[repr(C)]
pub struct FfiSummaryContent {
    pub short: *const c_char,
    pub long: *const c_char,
    pub all: *const c_char,
    pub keywords: *const *const c_char,
    pub keywords_len: usize,
}
pub struct FfiCallbackRequest {
    pub task_id: *const c_char,
    pub status: *const c_char,
    pub code: u16,
    pub utterances: *const FfiUtterance,
    pub utterances_len: usize,
    pub summary: *const FfiSummaryContent,
    pub duration: *const u32,
    pub message: *const c_char,
}

impl From<&FfiCallbackRequest> for CallbackRequest {
    fn from(req: &FfiCallbackRequest) -> Self {
        unsafe {
            Self {
                task_id: CStr::from_ptr(req.task_id).to_string_lossy().to_string(),
                status: CStr::from_ptr(req.status).to_string_lossy().to_string(),
                code: req.code,
                utterances: std::slice::from_raw_parts(req.utterances, req.utterances_len)
                    .into_iter()
                    .map(|u| Utterance {
                        start_time: u.start_time,
                        end_time: u.end_time,
                        speaker: u.speaker,
                        text: CStr::from_ptr(u.text).to_string_lossy().to_string(),
                    })
                    .collect(),
                summary: if req.summary.is_null() {
                    None
                } else {
                    Some(SummaryContent {
                        short: CStr::from_ptr((*req.summary).short)
                            .to_string_lossy()
                            .to_string(),
                        long: CStr::from_ptr((*req.summary).long)
                            .to_string_lossy()
                            .to_string(),
                        all: CStr::from_ptr((*req.summary).all)
                            .to_string_lossy()
                            .to_string(),
                        keywords: std::slice::from_raw_parts(
                            (*req.summary).keywords,
                            (*req.summary).keywords_len,
                        )
                        .into_iter()
                        .map(|&k| CStr::from_ptr(k as _).to_string_lossy().to_string())
                        .collect(),
                    })
                },
                duration: if req.duration.is_null() {
                    None
                } else {
                    Some(*req.duration)
                },
                message: if req.message.is_null() {
                    None
                } else {
                    Some(CStr::from_ptr(req.message).to_string_lossy().to_string())
                },
            }
        }
    }
}

/// 回调历史
#[repr(C)]
pub struct FfiCallbackHistory {
    pub timestamp: *mut c_char,
    pub status: *mut c_char,
    pub code: u32,
}

impl TryFrom<transcribe::transcribe::CallbackHistory> for FfiCallbackHistory {
    type Error = Error;
    fn try_from(v: transcribe::transcribe::CallbackHistory) -> Result<Self, Self::Error> {
        let timestamp = CString::new(v.timestamp)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?;
        let status = CString::new(v.status).map_err(|e| {
            let _ = timestamp;
            Error::OtherError(format!("Failed to create CString: {}", e))
        })?;
        Ok(Self {
            timestamp: timestamp.into_raw(),
            status: status.into_raw(),
            code: v.code,
        })
    }
}

/// 转写状态
#[repr(C)]
pub struct FfiTranscribeStatus {
    pub status: *mut c_char,
    pub overview_md: *mut c_char,
    pub summary_md: *mut c_char,

    pub details: *mut FfiUtterance,
    pub details_len: usize,

    pub message: *mut c_char,
    pub usage_id: *mut c_char,
    pub task_id: *mut c_char,

    pub keywords: *mut *mut c_char,
    pub keywords_len: usize,

    pub callback_history: *mut FfiCallbackHistory,
    pub callback_history_len: usize,

    pub task_type: FfiTranscribeTaskType,
    pub has_task_type: bool,
}

/// 转写状态回调响应
#[repr(C)]
pub struct FfiCallbackResponse {
    pub status: *mut c_char,
}

impl TryFrom<CallbackResponse> for FfiCallbackResponse {
    type Error = Error;
    fn try_from(v: CallbackResponse) -> Result<Self, Self::Error> {
        let status = CString::new(v.status)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?;
        Ok(Self {
            status: status.into_raw(),
        })
    }
}

impl TryFrom<TranscribeStatus> for FfiTranscribeStatus {
    type Error = Error;
    fn try_from(v: TranscribeStatus) -> Result<Self, Self::Error> {
        // 基础字符串字段
        let status_c = CString::new(v.status)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?;
        let overview_md_c = v
            .overview_md
            .map(|v| {
                CString::new(v)
                    .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))
            })
            .transpose()?;
        let summary_md_c = v
            .summary_md
            .map(|v| {
                CString::new(v)
                    .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))
            })
            .transpose()?;

        // details -> FfiUtterance 数组
        let details: Vec<FfiUtterance> = v
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

        // message / usage_id / task_id
        let message_c = v
            .message
            .map(|v| {
                CString::new(v)
                    .ok()
                    .map(|s| s.into_raw())
                    .unwrap_or(std::ptr::null_mut())
            })
            .unwrap_or(std::ptr::null_mut());
        let usage_id_c = v
            .usage_id
            .map(|v| {
                CString::new(v)
                    .ok()
                    .map(|s| s.into_raw())
                    .unwrap_or(std::ptr::null_mut())
            })
            .unwrap_or(std::ptr::null_mut());
        let task_id_c = v
            .task_id
            .map(|v| {
                CString::new(v)
                    .ok()
                    .map(|s| s.into_raw())
                    .unwrap_or(std::ptr::null_mut())
            })
            .unwrap_or(std::ptr::null_mut());

        // keywords
        let keywords: Vec<*mut c_char> = v
            .keywords
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

        // callback_history
        let histories: Vec<FfiCallbackHistory> = v
            .callback_history
            .into_iter()
            .map(FfiCallbackHistory::try_from)
            .collect::<Result<Vec<_>, Error>>()?;
        let history_len = histories.len();
        let history_ptr = if history_len > 0 {
            let boxed = histories.into_boxed_slice();
            Box::into_raw(boxed) as *mut FfiCallbackHistory
        } else {
            std::ptr::null_mut()
        };

        // task_type
        let (task_type, has_task_type) = match v.task_type {
            Some(t) => (FfiTranscribeTaskType::from(t), true),
            None => (FfiTranscribeTaskType::NormalQuality, false),
        };

        Ok(Self {
            status: status_c.into_raw(),
            overview_md: overview_md_c
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            summary_md: summary_md_c
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            details: details_ptr,
            details_len,
            message: message_c,
            usage_id: usage_id_c,
            task_id: task_id_c,
            keywords: keywords_ptr,
            keywords_len,
            callback_history: history_ptr,
            callback_history_len: history_len,
            task_type,
            has_task_type,
        })
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_transcribe_status(s: *mut FfiTranscribeStatus) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).status);
        free_c_string(&mut (*s).overview_md);
        free_c_string(&mut (*s).summary_md);
        free_c_string(&mut (*s).message);
        free_c_string(&mut (*s).usage_id);
        free_c_string(&mut (*s).task_id);

        free_utterance_array(
            std::ptr::addr_of_mut!((*s).details),
            std::ptr::addr_of_mut!((*s).details_len),
        );
        free_string_array(
            std::ptr::addr_of_mut!((*s).keywords),
            std::ptr::addr_of_mut!((*s).keywords_len),
        );
        free_callback_history_array(
            std::ptr::addr_of_mut!((*s).callback_history),
            std::ptr::addr_of_mut!((*s).callback_history_len),
        );
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_callback_response(s: *mut FfiCallbackResponse) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).status);
    }
}
