use std::ffi::*;
use transcribe::{
    transcribe::{
        callback, create_summary, export, get_share_link, status, upload, CallbackRequest,
    },
    translate::{translate_text, translate_transcribe, translate_utterance},
    types::Utterance,
};

use crate::{
    error::FfiError, runtime::get_runtime, utils::*, FfiCallbackRequest, FfiCallbackResponse,
    FfiShareLink, FfiSummaryCreator, FfiTextTranslator, FfiTranscribeStatus,
    FfiTranscribeTranslator, FfiUploadResponse, FfiUtterance, FfiUtteranceTranslator,
};
use common::Error;

/// 导出转写内容或总结内容
///
/// # 参数
/// - `task_id`: 任务ID（C 字符串）
/// - `export_type`: 导出类型字符串（"transcript", "overview", "summary"）
/// - `export_format`: 导出格式字符串（"pdf", "txt", "docx"）
/// - `token`: Bearer token（C 字符串）
/// - `result_data`: 输出二进制数据的缓冲区指针
/// - `result_len`: 输入时为缓冲区大小，输出时为实际长度
/// - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_export(
    task_id: *const c_char,
    export_type: *const c_char,
    export_format: *const c_char,
    token: *const c_char,
    result_data: *mut u8,
    result_len: *mut usize,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(out_error, || {
        if result_data.is_null() || result_len.is_null() {
            return Err(Error::InvalidInput("Invalid input parameters".to_string()));
        }

        let task_id = parse_c_str(task_id, |s| Ok(s.to_string()))?;
        let export_type = parse_transcribe_export_type(export_type)?;
        let export_format = parse_format_type(export_format)?;
        let token = parse_c_str(token, |s| Ok(s.to_string()))?;

        let data = get_runtime().block_on(export(&task_id, export_type, export_format, &token))?;
        let len = data.len();
        let buffer_size = unsafe { *result_len };

        if len > buffer_size {
            unsafe { *result_len = len };
            return Err(Error::InvalidInput(format!(
                "Buffer too small, need {} bytes",
                len
            )));
        }

        unsafe {
            std::ptr::copy_nonoverlapping(data.as_ptr(), result_data, len);
            *result_len = len;
        }

        Ok(())
    })
}

/// 获取转写分享链接
///
/// # 参数
/// - `task_id`: 任务ID（C 字符串）
/// - `expiration_day`: 过期天数（0 表示使用默认值 7 天）
/// - `token`: Bearer token（C 字符串）
/// - `out_link`: 输出分享链接结构体指针
/// - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_get_share_link(
    task_id: *const c_char,
    expiration_day: i32,
    token: *const c_char,
    out_link: *mut FfiShareLink,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(out_error, || {
        if out_link.is_null() {
            return Err(Error::InvalidInput("Invalid input parameters".to_string()));
        }

        let task_id = parse_c_str(task_id, |s| Ok(s.to_string()))?;
        let token = parse_c_str(token, |s| Ok(s.to_string()))?;
        let expiration_opt = if expiration_day == 0 {
            None
        } else {
            Some(expiration_day)
        };

        let link = get_runtime().block_on(get_share_link(&task_id, expiration_opt, &token))?;
        let ffi_link = FfiShareLink::try_from(link)?;

        unsafe {
            (*out_link).share_url = ffi_link.share_url;
            (*out_link).expiration_day = ffi_link.expiration_day;
            (*out_link).expired_at = ffi_link.expired_at;
        }

        Ok(())
    })
}

/// 获取转写任务状态
///
/// # 参数
/// - `task_id`: 任务ID（可为 NULL，如果提供 share_id）
/// - `share_id`: 分享链接ID（可为 NULL，如果提供 task_id）
/// - `token`: Bearer token（C 字符串）
/// - `out_status`: 输出状态结构体指针
/// - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_get_status(
    task_id: *const c_char,
    share_id: *const c_char,
    token: *const c_char,
    out_status: *mut FfiTranscribeStatus,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(out_error, || {
        if out_status.is_null() {
            return Err(Error::InvalidInput("Invalid input parameters".to_string()));
        }

        let task_id_opt = if task_id.is_null() {
            None
        } else {
            Some(parse_c_str(task_id, |s| Ok(s.to_string()))?)
        };
        let share_id_opt = if share_id.is_null() {
            None
        } else {
            Some(parse_c_str(share_id, |s| Ok(s.to_string()))?)
        };
        let token = parse_c_str(token, |s| Ok(s.to_string()))?;

        let status_response = get_runtime().block_on(status(
            task_id_opt.as_deref(),
            share_id_opt.as_deref(),
            &token,
        ))?;

        let ffi_status = FfiTranscribeStatus::try_from(status_response)?;

        unsafe {
            (*out_status).status = ffi_status.status;
            (*out_status).overview_md = ffi_status.overview_md;
            (*out_status).summary_md = ffi_status.summary_md;
            (*out_status).details = ffi_status.details;
            (*out_status).details_len = ffi_status.details_len;
            (*out_status).message = ffi_status.message;
            (*out_status).usage_id = ffi_status.usage_id;
            (*out_status).task_id = ffi_status.task_id;
            (*out_status).keywords = ffi_status.keywords;
            (*out_status).keywords_len = ffi_status.keywords_len;
            (*out_status).callback_history = ffi_status.callback_history;
            (*out_status).callback_history_len = ffi_status.callback_history_len;
            (*out_status).task_type = ffi_status.task_type;
            (*out_status).has_task_type = ffi_status.has_task_type;
        }

        Ok(())
    })
}

/// 创建总结任务
///
/// # 参数
/// - `utterances`: Utterance 数组指针
/// - `utterances_len`: Utterance 数组长度
/// - `token`: Bearer token（C 字符串）
/// - `out_summary`: 输出总结任务信息结构体指针
/// - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_create_summary(
    utterances: *const FfiUtterance,
    utterances_len: usize,
    token: *const c_char,
    out_summary: *mut FfiSummaryCreator,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(out_error, || {
        if utterances.is_null() || utterances_len == 0 || out_summary.is_null() {
            return Err(Error::InvalidInput("Invalid input parameters".to_string()));
        }

        let token = parse_c_str(token, |s| Ok(s.to_string()))?;

        let utterances: Vec<Utterance> = unsafe {
            std::slice::from_raw_parts(utterances, utterances_len)
                .into_iter()
                .map(|u| Utterance {
                    start_time: u.start_time,
                    end_time: u.end_time,
                    speaker: u.speaker,
                    text: CStr::from_ptr(u.text).to_string_lossy().to_string(),
                })
                .collect()
        };

        let response = get_runtime().block_on(create_summary(utterances, &token))?;
        let ffi_summary = FfiSummaryCreator::try_from(response)?;

        unsafe {
            (*out_summary).task_id = ffi_summary.task_id;
        }

        Ok(())
    })
}

/// 上传音频文件进行转写
///
/// # 参数
/// - `filepath`: 音频文件路径（C 字符串）
/// - `transcribe_only`: 是否仅转写（1 = true, 0 = false）
/// - `short_asr`: 是否使用一句话转写模式（1 = true, 0 = false）
/// - `model`: 模型类型字符串（"speed", "quality", "quality_v2"）
/// - `token`: Bearer token（C 字符串）
/// - `out_result`: 输出上传结果结构体指针
/// - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_upload(
    filepath: *const c_char,
    transcribe_only: bool,
    short_asr: bool,
    model: *const c_char,
    token: *const c_char,
    out_result: *mut FfiUploadResponse,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(out_error, || {
        if out_result.is_null() {
            return Err(Error::InvalidInput("Invalid output parameters".to_string()));
        }
        let filepath = parse_c_str(filepath, |s| Ok(s.to_string()))?;
        let model = parse_model_type(model)?;
        let token = parse_c_str(token, |s| Ok(s.to_string()))?;

        let result =
            get_runtime().block_on(upload(&filepath, transcribe_only, short_asr, model, &token))?;

        let ffi_result = FfiUploadResponse::try_from(result)?;
        unsafe {
            (*out_result).is_normal = ffi_result.is_normal;
            (*out_result).normal = ffi_result.normal;
            (*out_result).one_sentence = ffi_result.one_sentence;
        }

        Ok(())
    })
}

/// 翻译文本
///
/// # 参数
/// - `text`: 要翻译的文本（C 字符串）
/// - `target_lang`: 目标语言代码（"zh", "en", "ja", "ko", "fr", "de"）
/// - `token`: Bearer token（C 字符串）
/// - `out_result`: 输出文本翻译结果结构体指针
/// - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_translate_text(
    text: *const c_char,
    target_lang: *const c_char,
    token: *const c_char,
    out_result: *mut FfiTextTranslator,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(out_error, || {
        if out_result.is_null() {
            return Err(Error::InvalidInput("Invalid input parameters".to_string()));
        }

        let text = parse_c_str(text, |s| Ok(s.to_string()))?;
        let lang = parse_language(target_lang)?;
        let token = parse_c_str(token, |s| Ok(s.to_string()))?;
        let result = get_runtime().block_on(translate_text(&text, lang, &token))?;
        let result = FfiTextTranslator::try_from(result)?;
        unsafe {
            (*out_result).status = result.status;
            (*out_result).data = result.data;
        }

        Ok(())
    })
}

/// 翻译 utterances 列表
///
/// # 参数
/// - `utterances`: Utterance 数组指针
/// - `utterances_len`: Utterance 数组长度
/// - `target_lang`: 目标语言代码（"zh", "en", "ja", "ko", "fr", "de"）
/// - `token`: Bearer token（C 字符串）
/// - `out_result`: 输出 utterance 翻译结果结构体指针
/// - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_translate_utterance(
    utterances: *const FfiUtterance,
    utterances_len: usize,
    target_lang: *const c_char,
    token: *const c_char,
    out_result: *mut FfiUtteranceTranslator,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(out_error, || {
        if utterances.is_null() || utterances_len == 0 || out_result.is_null() {
            return Err(Error::InvalidInput("Invalid input".to_string()));
        }

        let utterances: Vec<Utterance> = unsafe {
            std::slice::from_raw_parts(utterances, utterances_len)
                .into_iter()
                .map(|u| Utterance {
                    start_time: u.start_time,
                    end_time: u.end_time,
                    speaker: u.speaker,
                    text: CStr::from_ptr(u.text).to_string_lossy().to_string(),
                })
                .collect()
        };

        let lang = parse_language(target_lang)?;
        let token = parse_c_str(token, |s| Ok(s.to_string()))?;
        let result = get_runtime().block_on(translate_utterance(utterances, lang, &token))?;
        let result = FfiUtteranceTranslator::try_from(result)?;
        unsafe {
            (*out_result).status = result.status;
            (*out_result).lang = result.lang;
            (*out_result).details = result.details;
            (*out_result).details_len = result.details_len;
        }

        Ok(())
    })
}

/// 获取转写任务的翻译结果
///
/// # 参数
/// - `task_id`: 任务ID（C 字符串）
/// - `target_lang`: 目标语言代码（"zh", "en", "ja", "ko", "fr", "de"）
/// - `token`: Bearer token（C 字符串）
/// - `out_result`: 输出转写翻译结果结构体指针
/// - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_translate_transcribe(
    task_id: *const c_char,
    target_lang: *const c_char,
    token: *const c_char,
    out_result: *mut FfiTranscribeTranslator,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(out_error, || {
        if out_result.is_null() {
            return Err(Error::InvalidInput("out_result is null".to_string()));
        }

        let task_id = parse_c_str(task_id, |s| Ok(s.to_string()))?;
        let lang = parse_language(target_lang)?;
        let token = parse_c_str(token, |s| Ok(s.to_string()))?;
        let result = get_runtime().block_on(translate_transcribe(&task_id, lang, &token))?;

        let result = FfiTranscribeTranslator::try_from(result)?;
        unsafe {
            (*out_result).task_id = result.task_id;
            (*out_result).task_type = result.task_type;
            (*out_result).status = result.status;
            (*out_result).lang = result.lang;
            (*out_result).message = result.message;
            (*out_result).details = result.details;
            (*out_result).details_len = result.details_len;
            (*out_result).overview_md = result.overview_md;
            (*out_result).summary_md = result.summary_md;
            (*out_result).keywords = result.keywords;
            (*out_result).keywords_len = result.keywords_len;
        }

        Ok(())
    })
}

/// 处理转写任务状态回调（服务器端使用）
///
/// # 参数
/// - `request`: 回调请求结构体指针
/// - `token`: Bearer token（C 字符串）
/// - `out_response`: 输出回调响应结构体指针
/// - `out_error`: 错误信息输出指针，如果为 null 则不填充错误信息
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_callback(
    request: *const FfiCallbackRequest,
    token: *const c_char,
    out_response: *mut FfiCallbackResponse,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(out_error, || {
        if request.is_null() || out_response.is_null() {
            return Err(Error::InvalidInput("Invalid input parameters".to_string()));
        }

        let token = parse_c_str(token, |s| Ok(s.to_string()))?;
        let request = CallbackRequest::from(unsafe { &*request });
        let result = get_runtime().block_on(callback(&request, &token))?;
        let ffi_response = FfiCallbackResponse::try_from(result)?;
        unsafe {
            (*out_response).status = ffi_response.status;
        }

        Ok(())
    })
}
