use crate::types_ffi::free_c_string;
use common::Error;
use std::ffi::{c_char, CString};
use transcribe::transcribe::SummaryCreator;

/// 创建总结任务结果
#[repr(C)]
pub struct FfiSummaryCreator {
    pub task_id: *mut c_char,
}

impl TryFrom<SummaryCreator> for FfiSummaryCreator {
    type Error = Error;
    fn try_from(v: SummaryCreator) -> Result<Self, Self::Error> {
        let task_id = CString::new(v.task_id)
            .map_err(|e| Error::OtherError(format!("Failed to create CString: {}", e)))?;
        Ok(Self {
            task_id: task_id.into_raw(),
        })
    }
}

#[no_mangle]
pub extern "C" fn transcribe_ffi_free_summary_creator(s: *mut FfiSummaryCreator) {
    if s.is_null() {
        return;
    }
    unsafe {
        free_c_string(&mut (*s).task_id);
    }
}
