## DianyaAPI FFI

Rust 实现的语音转写/翻译能力，通过 **C FFI** 暴露给 **Go / C / Swift(iOS/macOS)** 使用。

本仓库只关注「底层 FFI 能力」，更高层 SDK 封装（比如 Swift 的 `TranscribeClient`）都放在对应语言的示例里。

---

## 预编译产物

核心 Rust FFI 库目前为私有，仅通过 GitHub Actions 提供预编译产物。请从仓库的 GitHub Actions / Release 页面下载与你平台对应的压缩包，通常包含：

- **静态/动态库**：`libdianyaapi_ffi.*`
- **C 头文件**：`dianyaapi_ffi.h`（iOS/macOS 版本位于 `export/darwin/Sources/include`）

> 头文件由内部构建脚本自动生成；如果需要调整导出接口，请修改 `cbindgen.toml` 并在 CI 流水线中重新生成。

---

## 快速上手

### Go

- **示例入口**：`export/go-lang/transcribe_api.go`
- **编译并运行示例**（示意）：

```bash
go run ./export/go-lang
```

Go 侧通过 `cgo` 引用 `dianyaapi_ffi.h` 和 `libdianyaapi_ffi`，并提供一个简单的 `TranscribeClient` 封装（上传音频、查询状态、导出结果等）。

---

### Swift（iOS / macOS）

推荐使用已经打好的 `DianyaAPIFFI.xcframework`：

- **构建脚本**：`export/scripts/build-xcframework.sh`
- **Swift Package**：`export/darwin/Package.swift`

在你的 Xcode 工程中：

1. 通过 Swift Package 引入 `export/darwin` 目录或发行版目录；
2. 在 Swift 代码中使用 `DianyaAPI` 模块提供的封装（`TranscribeApi`、`TranscribeStream` 等）。

示例代码可参考：

- `export/darwin/Sources/DianyaAPI/TranscribeApi.swift`
- `export/darwin/Sources/DianyaAPI/TranscribeStream.swift`

---

### C

- **示例入口**：
- 转写示例：`examples/c/transcribe/main.c`
- 实时流式示例：`examples/c/stream/main.c`

典型编译方式：

```bash
cd examples/c/transcribe   # 离线转写示例
make                       # 或者参考对应目录下的 Makefile 手动编译

cd ../stream               # 实时流式示例
make
```

示例演示了如何在纯 C 程序中调用 `transcribe_ffi_upload` 及 WebSocket 相关的实时转写接口。

---

## 能力概览

底层 C FFI 暴露的核心能力包括（但不限于）：

- **离线转写**：`transcribe_ffi_upload`、`transcribe_ffi_get_status`、`transcribe_ffi_export`、`transcribe_ffi_get_share_link`
- **实时转写 / WebSocket**：`transcribe_ffi_create_session`、`transcribe_ffi_ws_*`
- **翻译**：`transcribe_ffi_translate_text`、`transcribe_ffi_translate_utterance`、`transcribe_ffi_translate_transcribe`

如需查看完整函数列表与参数说明，请直接打开头文件：

- `export/darwin/Sources/include/dianyaapi_ffi.h`
- 或原始版本：`export/darwin/Sources/include/dianyaapi_ffi_original.h`

---

## 开发者提示

- 如果要扩展新的 API，请在 `src/lib.rs` 中添加新的 `extern "C"` 函数，并同步更新头文件；
- Go / Swift / C 示例都尽量保持与 FFI 同步更新，建议优先参考对应语言的示例代码；
- 如果链接失败或找不到库，先确认已使用与你平台匹配的预编译库，并且运行环境能正确找到 `libdianyaapi_ffi`。
