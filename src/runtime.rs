use std::sync::OnceLock;

/// 全局 Tokio runtime，用于执行异步操作
/// 使用 multi_thread runtime 以支持从任何线程调用 block_on
static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();

/// 获取或创建全局 runtime
pub(crate) fn get_runtime() -> &'static tokio::runtime::Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(4)
            .enable_all()
            .build()
            .expect("Failed to create Tokio runtime")
    })
}
