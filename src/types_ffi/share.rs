use crate::types_ffi::free_c_string;
use common::Error;
use std::ffi::{c_char, CString};
use transcribe::transcribe::ShareLink;

/// 分享链接结果
#[repr(C)]
pub struct FfiShareLink {
    pub share_url: *mut c_char,
    pub expiration_day: i32,
    pub expired_at: *mut c_char,
}

impl TryFrom<ShareLink> for FfiShareLink {
    type Error = Error;
    fn try_from(v: ShareLink) -> Result<Self, Self::Error> {
        let share_url = CString::new(v.share_url)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?;
        let expired_at = CString::new(v.expired_at).map_err(|e| {
            let _ = share_url;
            Error::OtherError(format!("Failed to create CString: {}", e))
        })?;
        Ok(Self {
            share_url: share_url.into_raw(),
            expiration_day: v.expiration_day,
            expired_at: expired_at.into_raw(),
        })
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_share_link(s: *mut FfiShareLink) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).share_url);
        free_c_string(&mut (*s).expired_at);
    }
}
