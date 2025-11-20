mod export;
pub use export::*;
mod share;
pub use share::*;
mod status;
pub use status::*;
mod summary;
pub use summary::*;
mod translate;
pub use translate::*;
mod upload;
pub use upload::*;
mod ws;
pub use ws::*;

use common::Error;
use std::ffi::{c_char, CStr, CString};
use transcribe::types::Utterance;

/// Utterance 映射到 C 结构体
#[repr(C)]
pub struct FfiUtterance {
    pub start_time: f64,
    pub end_time: f64,
    pub speaker: i32,
    pub text: *mut c_char,
}

impl From<FfiUtterance> for Utterance {
    fn from(v: FfiUtterance) -> Self {
        Self {
            start_time: v.start_time,
            end_time: v.end_time,
            speaker: v.speaker,
            text: unsafe { CStr::from_ptr(v.text).to_string_lossy().to_string() },
        }
    }
}

impl TryFrom<Utterance> for FfiUtterance {
    type Error = Error;
    fn try_from(v: Utterance) -> Result<Self, Self::Error> {
        Ok(Self {
            start_time: v.start_time,
            end_time: v.end_time,
            speaker: v.speaker,
            text: CString::new(v.text)
                .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?
                .into_raw(),
        })
    }
}

/// 释放 C 字符串
pub(crate) unsafe fn free_c_string(p: *mut *mut c_char) {
    if !p.is_null() && !(*p).is_null() {
        let _ = CString::from_raw(*p);
        *p = std::ptr::null_mut();
    }
}

/// 释放字符串数组
pub(crate) unsafe fn free_string_array(ptr: *mut *mut *mut c_char, len: *mut usize) {
    array_call(ptr, len, |ptr, len| {
        let slice = std::slice::from_raw_parts_mut(*ptr, *len);
        for s in slice.iter_mut() {
            free_c_string(s);
        }
        let _ = Box::from_raw(slice);
    })
}

/// 释放 Utterance 数组
pub(crate) unsafe fn free_utterance_array(ptr: *mut *mut FfiUtterance, len: *mut usize) {
    array_call(ptr, len, |ptr, len| {
        let slice = std::slice::from_raw_parts_mut(*ptr, *len);
        for u in slice.iter_mut() {
            free_c_string(&mut u.text);
        }
        let _ = Box::from_raw(slice);
    })
}

/// 释放回调历史数组
pub(crate) unsafe fn free_callback_history_array(
    ptr: *mut *mut FfiCallbackHistory,
    len: *mut usize,
) {
    array_call(ptr, len, |ptr, len| {
        let slice = std::slice::from_raw_parts_mut(*ptr, *len);
        for h in slice.iter_mut() {
            free_c_string(&mut h.timestamp);
            free_c_string(&mut h.status);
        }
        let _ = Box::from_raw(slice);
    })
}

/// 释放翻译详情数组
pub(crate) unsafe fn free_translate_detail_array(
    ptr: *mut *mut FfiTranslateDetail,
    len: *mut usize,
) {
    array_call(ptr, len, |ptr, len| {
        let slice = std::slice::from_raw_parts_mut(*ptr, *len);
        for d in slice.iter_mut() {
            free_c_string(&mut d.utterance.text);
            free_c_string(&mut d.translation);
        }
        let _ = Box::from_raw(slice);
    })
}

unsafe fn array_call<T>(
    ptr: *mut *mut T,
    len: *mut usize,
    f: impl FnOnce(*mut *mut T, *mut usize),
) {
    if ptr.is_null() || (*ptr).is_null() || len.is_null() || *len == 0 {
        if !ptr.is_null() {
            *ptr = std::ptr::null_mut();
        }
        if !len.is_null() {
            *len = 0;
        }
        return;
    }

    let _ = f(ptr, len);
    // let _ = Box::from_raw(slice);
    *ptr = std::ptr::null_mut();
    *len = 0;
}
