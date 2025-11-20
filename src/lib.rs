//! C FFI 包装层，用于 Go 语言调用
//!
//! 此模块将 Rust 的异步 API 包装为同步的 C 兼容函数，供 Go 通过 cgo 调用。

mod error;
mod runtime;
mod transcribe_api;
mod transcribe_stream;
mod types_ffi;
mod utils;

pub use error::*;
pub use types_ffi::*;
