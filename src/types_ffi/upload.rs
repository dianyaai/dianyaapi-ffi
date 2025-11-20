use crate::types_ffi::free_c_string;
use common::Error;
use std::ffi::{c_char, CString};
use transcribe::transcribe::UploadResponse;

/// 上传结果 - 普通模式
#[repr(C)]
pub struct FfiUploadNormal {
    pub task_id: *mut c_char,
}

/// 上传结果 - 一句话模式
#[repr(C)]
pub struct FfiUploadOneSentence {
    pub status: *mut c_char,
    pub message: *mut c_char,
    pub data: *mut c_char,
}

/// 上传结果总览
#[repr(C)]
pub struct FfiUploadResponse {
    pub is_normal: bool,
    pub normal: FfiUploadNormal,
    pub one_sentence: FfiUploadOneSentence,
}

impl TryFrom<UploadResponse> for FfiUploadResponse {
    type Error = Error;
    fn try_from(v: UploadResponse) -> Result<Self, Self::Error> {
        match v {
            UploadResponse::Normal(normal) => {
                let task_id = CString::new(normal.task_id)
                    .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?
                    .into_raw();
                Ok(Self {
                    is_normal: true,
                    normal: FfiUploadNormal { task_id },
                    one_sentence: FfiUploadOneSentence {
                        status: std::ptr::null_mut(),
                        message: std::ptr::null_mut(),
                        data: std::ptr::null_mut(),
                    },
                })
            }
            UploadResponse::OneSentence(one_sentence) => {
                let status = CString::new(one_sentence.status)
                    .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?;
                let message = CString::new(one_sentence.message).map_err(|e| {
                    let _ = status;
                    Error::OtherError(format!("Failed to create CString: {}", e))
                })?;
                let data = CString::new(one_sentence.data).map_err(|e| {
                    let _ = status;
                    let _ = message;
                    Error::OtherError(format!("Failed to create CString: {}", e))
                })?;
                Ok(Self {
                    is_normal: false,
                    normal: FfiUploadNormal {
                        task_id: std::ptr::null_mut(),
                    },
                    one_sentence: FfiUploadOneSentence {
                        status: status.into_raw(),
                        message: message.into_raw(),
                        data: data.into_raw(),
                    },
                })
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_upload_response(s: *mut FfiUploadResponse) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).normal.task_id);

        free_c_string(&mut (*s).one_sentence.status);
        free_c_string(&mut (*s).one_sentence.message);
        free_c_string(&mut (*s).one_sentence.data);
    }
}
