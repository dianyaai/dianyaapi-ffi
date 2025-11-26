use common::Error;
use std::ffi::{c_char, c_int, CString};

#[repr(C)]
#[derive(Debug, Copy, Clone, Eq, PartialEq, Hash)]
pub enum ErrorCode {
    // Success = 0,
    WsError = 1,
    HttpError = 2,
    ServerError = 3,
    InvalidInput = 4,
    InvalidResponse = 5,
    InvalidToken = 6,
    InvalidApiKey = 7,
    JsonError = 8,
    OtherError = 9,
    UnknownError = -1,
}

/// FFI 错误信息结构体
#[repr(C)]
pub struct FfiError {
    /// 错误码
    pub code: ErrorCode,
    /// 错误信息（C 字符串，可能为 null）
    pub message: *mut c_char,
}

impl FfiError {
    pub fn new(code: ErrorCode, message: *mut c_char) -> Self {
        Self { code, message }
    }

    /// 填充错误信息到输出参数
    pub fn fill_error(out_error: *mut FfiError, err: Error) -> c_int {
        if !out_error.is_null() {
            let ffi_err: FfiError = err.into();
            unsafe {
                (*out_error).code = ffi_err.code;
                (*out_error).message = ffi_err.message;
            }
            ffi_err.code as c_int
        } else {
            ErrorCode::UnknownError as c_int
        }
    }
}

impl From<Error> for FfiError {
    fn from(e: Error) -> Self {
        let (code, message_str) = match e {
            Error::WsError(err) => (ErrorCode::WsError, format!("Websocket Error: {}", err)),
            Error::HttpError(err) => (ErrorCode::HttpError, format!("HTTP error: {}", err)),
            Error::ServerError(msg) => (ErrorCode::ServerError, format!("Server error: {}", msg)),
            Error::InvalidInput(msg) => {
                (ErrorCode::InvalidInput, format!("Invalid input: {}", msg))
            }
            Error::InvalidResponse(msg) => (
                ErrorCode::InvalidResponse,
                format!("Invalid response: {}", msg),
            ),
            Error::InvalidToken(msg) => {
                (ErrorCode::InvalidToken, format!("Invalid token: {}", msg))
            }
            Error::InvalidApiKey(msg) => (
                ErrorCode::InvalidApiKey,
                format!("Invalid api key: {}", msg),
            ),
            Error::JsonError(err) => (ErrorCode::JsonError, format!("JSON error: {}", err)),
            Error::OtherError(msg) => (ErrorCode::OtherError, format!("Other error: {}", msg)),
        };

        let message_cstr = match CString::new(message_str) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        };

        Self {
            code,
            message: message_cstr,
        }
    }
}

use crate::types_ffi::free_c_string;

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_error(e: *mut FfiError) {
    if e.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*e).message);
    }
}
