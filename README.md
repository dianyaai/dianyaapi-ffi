# DianyaAPI FFI - Go/C/Swift 语言绑定

此 crate 提供了 Rust transcribe API 的 C FFI 接口，供 Go、C 和 Swift（通过 C FFI）调用。

## 概述

与 Python 的 pyo3 不同，Go 语言没有专门的 Rust 绑定 crate。Go 通过 **C FFI（Foreign Function Interface）** 调用 Rust 代码，这是标准且稳定的方式。

### 实现方式

1. **Rust 端**：创建 C 兼容的函数接口（使用 `#[no_mangle]` 和 `extern "C"`）
2. **生成 C 头文件**：使用 `cbindgen` 自动生成 C 头文件
3. **Go 端**：通过 `cgo` 调用这些 C 函数

## 构建

### 1. 构建 Rust 库

```bash
cd dianyaapi-ffi
cargo build --release
```

构建完成后，库文件位于 `target/release/libdianyaapi_ffi.so`（Linux）或 `target/release/libdianyaapi_ffi.a`（静态库）。

### 2. 生成 C 头文件

C 头文件会在构建时自动生成，位于 `include/dianyaapi_ffi.h`。

如果需要手动生成：

```bash
cbindgen --config cbindgen.toml --crate dianyaapi-ffi --output include/dianyaapi_ffi.h
```

## Go 使用示例

### 基本用法

```go
package main

/*
#cgo LDFLAGS: -L${SRCDIR}/../../target/release -ldianyaapi_ffi
#include "../../include/dianyaapi_ffi.h"
#include <stdlib.h>
*/
import "C"
import (
    "fmt"
    "unsafe"
)

func main() {
    token := "your_bearer_token"
    client := NewTranscribeClient(token)
    
    // 上传音频文件
    resp, err := client.Upload("/path/to/audio.wav", false, false, "quality")
    if err != nil {
        panic(err)
    }
    fmt.Printf("Task ID: %s\n", resp.TaskID)
}
```

完整示例请参考 `examples/go/main.go`。

## Swift 使用示例（iOS/macOS）

Swift 可以像 C 一样直接调用本 crate 暴露的 C 接口。你只需要在 Xcode 中引入头文件和库，然后在 Swift 代码里通过 Bridging Header 使用这些函数。

### 1. 在 Xcode 中集成

1. 将 `libdianyaapi_ffi.a`（或对应的 `.xcframework` / `.dylib`）加入目标的 **Link Binary With Libraries**。  
2. 将本仓库的 `include` 目录加入到 **Header Search Paths**。  
3. 创建或编辑 Swift Bridging Header，添加：

```c
#include "dianyaapi_ffi.h"
```

完成以上步骤后，Swift 就可以直接看到 `transcribe_ffi_*` 系列函数和 `Ffi*` 结构体。

### 2. 示例代码

项目在 `examples/swift_example.swift` 中提供了一个简单的 Swift 封装示例，参考了 `examples/go/main.go` 的用法，展示了：

- 上传音频文件：`transcribe_ffi_upload`  
- 获取任务状态：`transcribe_ffi_get_status`  
- 导出转写结果：`transcribe_ffi_export`  
- 获取分享链接：`transcribe_ffi_get_share_link`

你可以将该示例复制到 iOS/macOS 工程中，例如：

- 在 macOS Command Line Tool 工程里，新建 `swift_example.swift` 并在 `main.swift` 调用 `exampleUsage()`；  
- 在 iOS App 中，将示例里的 `TranscribeClient` 封装成一个 SDK 层，对外提供更高层的 Swift API。

> 注意：示例中的 `token`、音频文件路径等需要替换为你的实际值。

## C 语言使用示例

### 基本用法

```c
#include <stdio.h>
#include "../../include/dianyaapi_ffi.h"

int main() {
    const char* token = "your_bearer_token";
    char result[4096];
    size_t result_len = sizeof(result);
    
    int code = transcribe_ffi_upload(
        "/path/to/audio.wav",
        0, 0, "quality",
        token,
        result,
        &result_len
    );
    
    if (code == 0) {
        printf("Success: %.*s\n", (int)result_len, result);
    }
    
    return 0;
}
```

完整示例请参考 `examples/c/main.c`。

### 编译 C 示例

使用 Makefile：
```bash
cd examples/c
make
LD_LIBRARY_PATH=../../target/release:$LD_LIBRARY_PATH ./main
```

或手动编译：
```bash
gcc -I../../include -L../../target/release -ldianyaapi_ffi main.c -o main
```

### 使用 CMake

项目提供了 CMake 配置文件，方便集成到 C/C++ 项目中：

```bash
mkdir build && cd build
cmake ..
cmake --build .
```

CMake 会自动：
- 检测库文件位置
- 设置包含目录
- 配置链接选项
- 设置运行时库路径（rpath）

详细说明请参考 `CMakeLists.txt`。

## API 函数

### 转写相关

#### transcribe_ffi_export

导出转写内容或总结内容。

**参数：**
- `task_id`: 任务ID（C 字符串）
- `export_type`: 导出类型（"transcript", "overview", "summary"）
- `export_format`: 导出格式（"pdf", "txt", "docx"）
- `token`: Bearer token
- `result_data`: 输出二进制数据的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_get_share_link

获取转写分享链接。

**参数：**
- `task_id`: 任务ID（C 字符串）
- `expiration_day`: 过期天数（0 表示使用默认值 7 天）
- `token`: Bearer token
- `result_json`: 输出 JSON 结果的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_get_status

获取转写任务状态。

**参数：**
- `task_id`: 任务ID（可为 NULL，如果提供 share_id）
- `share_id`: 分享链接ID（可为 NULL，如果提供 task_id）
- `token`: Bearer token
- `result_json`: 输出 JSON 结果的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_create_summary

创建总结任务。

**参数：**
- `utterances_json`: Utterance 列表的 JSON 字符串
- `token`: Bearer token
- `result_json`: 输出 JSON 结果的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_upload

上传音频文件进行转写。

**参数：**
- `filepath`: 音频文件路径（C 字符串）
- `transcribe_only`: 是否仅转写（1 = true, 0 = false）
- `short_asr`: 是否使用一句话转写模式（1 = true, 0 = false）
- `model`: 模型类型（"speed", "quality", "quality_v2"）
- `token`: Bearer token
- `result_json`: 输出 JSON 结果的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

### 实时转写相关

#### transcribe_ffi_create_session

创建实时转写会话。

**参数：**
- `model`: 模型类型（"speed", "quality", "quality_v2"）
- `token`: Bearer token
- `result_json`: 输出 JSON 结果的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_close_session

关闭实时转写会话。

**参数：**
- `task_id`: 任务ID（C 字符串）
- `token`: Bearer token
- `timeout`: 超时时间（秒），0 表示使用默认值 30 秒
- `result_json`: 输出 JSON 结果的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_ws_create

创建 WebSocket 连接句柄。

**参数：**
- `session_id`: 会话ID（C 字符串）

**返回：** WebSocket 句柄，0 表示失败

#### transcribe_ffi_ws_start

启动 WebSocket 连接。

**参数：**
- `handle`: WebSocket 句柄

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_ws_write_txt

发送文本消息到 WebSocket。

**参数：**
- `handle`: WebSocket 句柄
- `text`: 文本消息（C 字符串）

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_ws_write_bytes

发送二进制数据到 WebSocket。

**参数：**
- `handle`: WebSocket 句柄
- `data`: 二进制数据指针
- `data_len`: 数据长度

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_ws_stop

停止 WebSocket 连接。

**参数：**
- `handle`: WebSocket 句柄

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_ws_close

关闭并删除 WebSocket 连接。

**参数：**
- `handle`: WebSocket 句柄

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_ws_receive

接收 WebSocket 消息（轮询方式）。

**参数：**
- `handle`: WebSocket 句柄
- `message_json`: 输出消息 JSON 的缓冲区
- `message_len`: 输入时为缓冲区大小，输出时为实际长度
- `timeout_ms`: 超时时间（毫秒），0 表示立即返回

**返回：** 错误码（0 表示成功，1 表示无消息）

### 翻译相关

#### transcribe_ffi_translate_text

翻译文本。

**参数：**
- `text`: 要翻译的文本
- `target_lang`: 目标语言代码（"zh", "en", "ja", "ko", "fr", "de"）
- `token`: Bearer token
- `result_json`: 输出 JSON 结果的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_translate_utterance

翻译 utterances 列表。

**参数：**
- `utterances_json`: Utterance 列表的 JSON 字符串
- `target_lang`: 目标语言代码（"zh", "en", "ja", "ko", "fr", "de"）
- `token`: Bearer token
- `result_json`: 输出 JSON 结果的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

#### transcribe_ffi_translate_transcribe

获取转写任务的翻译结果。

**参数：**
- `task_id`: 任务ID（C 字符串）
- `target_lang`: 目标语言代码（"zh", "en", "ja", "ko", "fr", "de"）
- `token`: Bearer token
- `result_json`: 输出 JSON 结果的缓冲区
- `result_len`: 输入时为缓冲区大小，输出时为实际长度

**返回：** 错误码（0 表示成功）

### 工具函数

#### transcribe_ffi_free_string

释放由 Rust 分配的内存（如果需要）。

## 错误码

- `0` (Success): 成功
- `1` (InvalidInput): 无效输入
- `2` (NetworkError): 网络错误
- `3` (ParseError): 解析错误
- `4` (ServerError): 服务器错误
- `5` (InvalidToken): 无效的 token
- `6` (InvalidApiKey): 无效的 API key
- `7` (UnknownError): 未知错误

## 注意事项

1. **异步处理**：Rust 的异步函数被包装为同步函数，内部使用全局 Tokio runtime 执行。

2. **内存管理**：
   - Go 端负责分配结果缓冲区
   - 如果缓冲区太小，函数会返回错误，并设置 `result_len` 为所需大小
   - 所有 C 字符串参数由 Go 端管理内存

3. **线程安全**：全局 runtime 是线程安全的，可以在多个 Go goroutine 中并发调用。

4. **库路径**：确保 Go 程序能找到编译好的 Rust 库文件。可以通过以下方式：
   - 将库文件放在系统库路径
   - 使用 `LD_LIBRARY_PATH` 环境变量
   - 在 `#cgo LDFLAGS` 中指定完整路径

## 与 Python pyo3 的对比

| 特性 | Python (pyo3) | Go (C FFI) |
|------|---------------|------------|
| 绑定方式 | 专用 crate (pyo3) | C FFI + cgo |
| 类型转换 | 自动 | 手动（C 类型） |
| 异步支持 | 原生支持 | 需要包装为同步 |
| 内存管理 | 自动 | 手动管理 |
| 成熟度 | 非常成熟 | 标准方式 |

## 扩展 API

如果需要添加更多 API 函数：

1. 在 `src/lib.rs` 中添加新的 `#[no_mangle] pub extern "C"` 函数
2. 使用 `get_runtime().block_on()` 包装异步调用
3. 重新构建库和头文件
4. 在 Go 代码中添加对应的包装函数

## 故障排除

### 链接错误

如果遇到链接错误，检查：
- 库文件路径是否正确
- 库文件是否已构建（`cargo build --release`）
- `LDFLAGS` 是否正确设置

### 运行时错误

如果运行时找不到库：
```bash
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/path/to/target/release
```

### 缓冲区大小

如果返回错误码 1（InvalidInput），检查 `result_len` 是否表示需要更大的缓冲区。

## CMake 支持

项目提供了 `CMakeLists.txt` 文件，方便在 C/C++ 项目中使用。

### 使用方式

1. **作为子项目（推荐）**：
```cmake
add_subdirectory(dianyaapi-ffi)
target_link_libraries(your_target PRIVATE dianyaapi_ffi)
```

2. **独立构建示例**：
```bash
cd dianyaapi-ffi
mkdir build && cd build
cmake ..
cmake --build .
```

### CMake 特性

- 自动检测库文件（`.so`, `.dylib`, `.dll`）
- 自动设置包含目录
- 自动配置运行时库路径（rpath）
- 支持安装规则

### 评估结果

**是否需要 CMake？**

✅ **推荐使用**，原因：
1. **跨平台支持**：CMake 可以自动处理不同操作系统的库文件扩展名和路径
2. **简化集成**：C/C++ 项目可以轻松集成 FFI 库
3. **自动化配置**：自动设置包含目录、链接选项和运行时路径
4. **标准工具**：CMake 是 C/C++ 生态系统的标准构建工具

**替代方案**：
- **Makefile**：已提供，适合简单项目
- **pkg-config**：可以创建 `.pc` 文件，但需要额外配置
- **手动编译**：适合一次性使用

对于 Go 语言，CMake 不是必需的，因为 Go 的 cgo 可以直接使用 `#cgo` 指令。

## 许可证

与主项目相同。

