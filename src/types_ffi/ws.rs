use crate::types_ffi::free_c_string;
use common::Error;
use std::ffi::{c_char, CString};
use transcribe::transcribe::{SessionCreator, SessionEnder};

/// Session 创建结果
#[repr(C)]
pub struct FfiSessionCreator {
    pub task_id: *mut c_char,
    pub session_id: *mut c_char,
    pub usage_id: *mut c_char,
    pub max_time: i32,
}

/// Session 关闭结果
#[repr(C)]
pub struct FfiSessionEnder {
    pub status: *mut c_char,
    pub duration: i32,
    pub has_duration: bool,
    pub error_code: i32,
    pub has_error_code: bool,
    pub message: *mut c_char,
}

impl TryFrom<SessionCreator> for FfiSessionCreator {
    type Error = Error;
    fn try_from(v: SessionCreator) -> Result<Self, Self::Error> {
        let task_id = CString::new(v.task_id)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?;
        let session_id = CString::new(v.session_id).map_err(|e| {
            let _ = task_id;
            Error::OtherError(format!("Failed to create CString: {}", e))
        })?;
        let usage_id = CString::new(v.usage_id).map_err(|e| {
            let _ = task_id;
            let _ = session_id;
            Error::OtherError(format!("Failed to create CString: {}", e))
        })?;
        Ok(Self {
            task_id: task_id.into_raw(),
            session_id: session_id.into_raw(),
            usage_id: usage_id.into_raw(),
            max_time: v.max_time,
        })
    }
}

impl TryFrom<SessionEnder> for FfiSessionEnder {
    type Error = Error;
    fn try_from(v: SessionEnder) -> Result<Self, Self::Error> {
        let status = CString::new(v.status)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?;
        let (duration, has_duration) = match v.duration {
            Some(d) => (d, true),
            None => (0, false),
        };
        let (error_code, has_error_code) = match v.error_code {
            Some(e) => (e, true),
            None => (0, false),
        };
        let message = v
            .message
            .map(|m| {
                CString::new(m).map_err(|e| {
                    let _ = status;
                    Error::OtherError(format!("Failed to create CString: {}", e))
                })
            })
            .transpose()?
            .map(|s| s.into_raw())
            .unwrap_or(std::ptr::null_mut());
        Ok(Self {
            status: status.into_raw(),
            duration,
            has_duration,
            error_code,
            has_error_code,
            message,
        })
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_session_creator(s: *mut FfiSessionCreator) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).task_id);
        free_c_string(&mut (*s).session_id);
        free_c_string(&mut (*s).usage_id);
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_session_ender(s: *mut FfiSessionEnder) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).status);
        free_c_string(&mut (*s).message);
    }
}
