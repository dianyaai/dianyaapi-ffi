use std::ffi::*;
use std::pin::Pin;
use std::sync::{Arc, Mutex};

use stream_cancel::Valved;
use tokio_stream::{Stream, StreamExt};
use transcribe::transcribe::{close_session, create_session, TranscribeWs};
use tungstenite::{Message, Utf8Bytes};

use crate::{error::FfiError, runtime::get_runtime, utils::*, FfiSessionCreator, FfiSessionEnder};

/// WebSocket 连接信息，包含连接实例和订阅流
/// 注意：这是一个不透明的指针类型，C 代码不应该直接访问其内部字段
#[repr(C)]
pub struct TranscribeStream {
    ws: Arc<Mutex<TranscribeWs>>,
    stream: Arc<Mutex<Valved<Pin<Box<dyn Stream<Item = Utf8Bytes> + Send>>>>>,
}

/// 创建实时转写会话
///
/// # 参数
/// - `model`: 模型类型字符串（"speed", "quality", "quality_v2"）
/// - `token`: Bearer token（C 字符串）
/// - `out_session`: 输出的会话信息结构体指针
///
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_create_session(
    model: *const c_char,
    token: *const c_char,
    out_session: *mut FfiSessionCreator,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(
        (model, token, out_session),
        out_error,
        |(model, token, out_session)| {
            if out_session.is_null() {
                return Err(common::Error::InvalidInput(
                    "Invalid output parameters".to_string(),
                ));
            }

            let model = parse_model_type(model)?;
            let token = parse_c_str(token, |s| Ok(s.to_string()))?;

            let session = get_runtime().block_on(create_session(model, &token))?;
            let ffi_session = FfiSessionCreator::try_from(session)?;

            unsafe {
                (*out_session).task_id = ffi_session.task_id;
                (*out_session).session_id = ffi_session.session_id;
                (*out_session).usage_id = ffi_session.usage_id;
                (*out_session).max_time = ffi_session.max_time;
            }

            Ok(())
        },
    )
}

/// 关闭实时转写会话
///
/// # 参数
/// - `task_id`: 任务ID（C 字符串）
/// - `token`: Bearer token（C 字符串）
/// - `timeout`: 超时时间（秒），0 表示使用默认值 30 秒
/// - `out_result`: 输出的会话关闭结果结构体指针
///
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_close_session(
    task_id: *const c_char,
    token: *const c_char,
    timeout: u64,
    out_result: *mut FfiSessionEnder,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(
        (task_id, token, timeout, out_result),
        out_error,
        |(task_id, token, timeout, out_result)| {
            if out_result.is_null() {
                return Err(common::Error::InvalidInput(
                    "Invalid output parameters".to_string(),
                ));
            }

            let task_id = parse_c_str(task_id, |s| Ok(s.to_string()))?;
            let token = parse_c_str(token, |s| Ok(s.to_string()))?;
            let timeout_opt = if timeout == 0 { None } else { Some(timeout) };

            let result = get_runtime().block_on(close_session(&task_id, &token, timeout_opt))?;
            let ffi_result = FfiSessionEnder::try_from(result)?;

            unsafe {
                (*out_result).status = ffi_result.status;
                (*out_result).duration = ffi_result.duration;
                (*out_result).has_duration = ffi_result.has_duration;
                (*out_result).error_code = ffi_result.error_code;
                (*out_result).has_error_code = ffi_result.has_error_code;
                (*out_result).message = ffi_result.message;
            }

            Ok(())
        },
    )
}

/// 创建 WebSocket 连接句柄
///
/// # 参数
/// - `session_id`: 会话ID（C 字符串）
///
/// # 返回
/// WebSocket 句柄，0 表示失败
#[no_mangle]
pub extern "C" fn transcribe_ffi_ws_create(
    session_id: *const c_char,
    handle: *mut *mut TranscribeStream,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute((session_id, handle), out_error, |(session_id, handle)| {
        if handle.is_null() {
            return Err(common::Error::InvalidInput(
                "Invalid input parameters".to_string(),
            ));
        }

        let session_id = parse_c_str(session_id, |s| Ok(s.to_string()))?;
        let mut ws = TranscribeWs::new(&session_id);
        let stream = ws.subscribe()?;
        let conn = Box::new(TranscribeStream {
            ws: Arc::new(Mutex::new(ws)),
            stream: Arc::new(Mutex::new(stream)),
        });

        unsafe {
            *handle = Box::into_raw(conn);
        }

        Ok(())
    })
}

/// 启动 WebSocket 连接
///
/// # 参数
/// - `handle`: WebSocket 句柄
///
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_ws_start(
    handle: *mut TranscribeStream,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(handle, out_error, |handle| {
        if handle.is_null() {
            return Err(common::Error::InvalidInput("Invalid handle".to_string()));
        }

        unsafe {
            let mut guard = (*handle).ws.lock().map_err(|e| {
                common::Error::OtherError(format!("Failed to acquire mutex lock: {}", e))
            })?;
            get_runtime().block_on(guard.start())?;
        }

        Ok(())
    })
}

/// 发送文本消息到 WebSocket
///
/// # 参数
/// - `handle`: WebSocket 句柄
/// - `text`: 文本消息（C 字符串）
///
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_ws_write_txt(
    handle: *mut TranscribeStream,
    text: *const c_char,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute((handle, text), out_error, |(handle, text)| {
        if handle.is_null() || text.is_null() {
            return Err(common::Error::InvalidInput(
                "Invalid input parameters".to_string(),
            ));
        }

        let text_str = parse_c_str(text, |s| Ok(s.to_string()))?;

        unsafe {
            let mut guard = (*handle).ws.lock().map_err(|e| {
                common::Error::OtherError(format!("Failed to acquire mutex lock: {}", e))
            })?;
            get_runtime().block_on(guard.write(Message::Text(text_str.into())))?;
        }

        Ok(())
    })
}

/// 发送二进制数据到 WebSocket
///
/// # 参数
/// - `handle`: WebSocket 句柄
/// - `data`: 二进制数据指针
/// - `data_len`: 数据长度
///
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_ws_write_bytes(
    handle: *mut TranscribeStream,
    data: *const u8,
    data_len: usize,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(
        (handle, data, data_len),
        out_error,
        |(handle, data, data_len)| {
            if handle.is_null() || data.is_null() || data_len == 0 {
                return Err(common::Error::InvalidInput(
                    "Invalid input parameters".to_string(),
                ));
            }

            // 复制数据
            let bytes: Vec<u8> = unsafe { std::slice::from_raw_parts(data, data_len).to_vec() };

            unsafe {
                let mut guard = (*handle).ws.lock().map_err(|e| {
                    common::Error::OtherError(format!("Failed to acquire mutex lock: {}", e))
                })?;
                get_runtime().block_on(guard.write(Message::Binary(bytes.into())))?;
            }

            Ok(())
        },
    )
}

/// 停止 WebSocket 连接（不断开，但停止消息处理）
///
/// # 参数
/// - `handle`: WebSocket 句柄
///
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_ws_stop(
    handle: *mut TranscribeStream,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(handle, out_error, |handle| {
        if handle.is_null() {
            return Err(common::Error::InvalidInput("Invalid handle".to_string()));
        }

        unsafe {
            let mut ws = (*handle).ws.lock().map_err(|e| {
                common::Error::OtherError(format!("Failed to acquire mutex lock: {}", e))
            })?;
            ws.stop();
        }

        Ok(())
    })
}

/// 接收 WebSocket 消息（轮询方式）
///
/// # 参数
/// - `handle`: WebSocket 句柄
/// - `message_json`: 输出消息 JSON 的缓冲区指针
/// - `message_len`: 输入时为缓冲区大小，输出时为实际长度
/// - `timeout_ms`: 超时时间（毫秒），0 表示立即返回
///
/// # 返回
/// 错误码（0 表示成功）
#[no_mangle]
pub extern "C" fn transcribe_ffi_ws_receive(
    handle: *mut TranscribeStream,
    message_json: *mut c_char,
    message_len: *mut usize,
    timeout_ms: u64,
    out_error: *mut FfiError,
) -> c_int {
    ffi_execute(
        (handle, message_json, message_len, timeout_ms),
        out_error,
        |(handle, message_json, message_len, timeout_ms)| {
            if handle.is_null() || message_json.is_null() || message_len.is_null() {
                return Err(common::Error::InvalidInput(
                    "Invalid input parameters".to_string(),
                ));
            }

            let message = unsafe {
                let mut guard = (*handle).stream.lock().map_err(|e| {
                    common::Error::OtherError(format!("Failed to acquire stream mutex lock: {}", e))
                })?;

                let result = if timeout_ms == 0 {
                    get_runtime().block_on(async { guard.next().await })
                } else {
                    // 带超时
                    get_runtime().block_on(async {
                        use tokio::time::{sleep, Duration};
                        tokio::select! {
                            msg = guard.next() => msg,
                            _ = sleep(Duration::from_millis(timeout_ms)) => None,
                        }
                    })
                };
                result
            };

            match message {
                Some(text) => {
                    let text_str = text.to_string();
                    let len = text_str.len();
                    let buffer_size = unsafe { *message_len };

                    if len + 1 > buffer_size {
                        unsafe { *message_len = len + 1 };
                        return Err(common::Error::OtherError(format!(
                            "Buffer too small, need {} bytes",
                            len + 1
                        )));
                    }

                    unsafe {
                        let bytes = text_str.as_bytes();
                        std::ptr::copy_nonoverlapping(bytes.as_ptr(), message_json as *mut u8, len);
                        *message_json.add(len) = 0;
                        *message_len = len;
                    }
                }
                None => unsafe {
                    *message_len = 0;
                },
            }

            Ok(())
        },
    )
}

/// 释放 WebSocket 连接内存
///
/// # 参数
/// - `handle`: WebSocket 句柄指针
#[no_mangle]
pub extern "C" fn transcribe_ffi_ws_free(handle: *mut TranscribeStream) {
    if handle.is_null() {
        return;
    }
    
    unsafe {
        // 停止连接
        if let Ok(mut ws) = (*handle).ws.lock() {
            ws.stop();
        }
        // 释放内存
        let _ = Box::from_raw(handle);
    }
}
