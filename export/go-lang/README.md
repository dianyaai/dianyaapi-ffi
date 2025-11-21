## Dianya Go Bindings

该目录提供基于 C FFI 的 Go 语言封装，分为 `transcribe_api.go`（REST/HTTP 能力）与 `transcribe_stream.go`（实时流式能力）两个文件。通过 `cgo` 直接调用 `libdianyaapi_ffi`，既可访问离线转写 API，也能驱动实时 WebSocket 会话。

### 目录结构

- `transcribe_api.go`：封装上传、导出、状态、翻译、会话创建/关闭等 API。
- `transcribe_stream.go`：封装实时 WebSocket 连接、发送音频包、接收结果等操作。
- `go.mod`：最小 Go module 定义（`module dianyaapi`）。
- `CMakeLists.txt`：一键构建脚本，串联 Rust 构建、产物拷贝和 Go 代码编译。
- `cmake/copy_artifacts.cmake`：负责把头文件与不同平台的动态/静态库复制到 `dist/<platform>`。
- `dist/<platform>`：`cmake --build` 之后生成的分发目录，包含：
  - `dianyaapi_ffi` 共享库（`.so`/`.dylib`/`.dll`）及静态库（`.a`/`.lib`，如存在）
  - `dianyaapi_ffi.h` 头文件

> 提示：`Client` 是无状态封装，每次调用 API 时都需要显式传入 Bearer Token，便于多 Token 共存或按调用区分凭证。

### 构建要求

- Go >= 1.21
- Rust toolchain（仅仓库维护者 / CI 使用；普通使用者如果只消费预编译库可不安装）
- CMake >= 3.16
- 平台对应的 C/C++ 工具链（Linux: gcc/clang，macOS: Xcode CLI，Windows: MSVC 或 MinGW）

### 获取预编译库与集成

核心 FFI 库由 GitHub Actions 构建并提供预编译产物。推荐做法是：

1. 从仓库的 GitHub Actions / Release 页面下载与你平台对应的 `dist/<platform>` 压缩包；
2. 解压后，确保其中包含：
   - `libdianyaapi_ffi.*`（动态/静态库）
   - `dianyaapi_ffi.h` 头文件
3. 将 `dist/<platform>` 放到你工程约定的位置，并确保 `#cgo CFLAGS` / `#cgo LDFLAGS` 能找到这些头文件与库。

对于仓库维护者或在 CI 中从源码构建时，可以使用本目录下的 `CMakeLists.txt` 串联完整流程，例如：

```bash
cd dianyaapi-ffi/export/go-lang
cmake -S . -B build
cmake --build build
```

上述命令会依次执行：
1. 构建 `dianyaapi-ffi` FFI 动态/静态库；
2. 将头文件和可用的 `.so/.dylib/.dll/.a/.lib` 复制到 `dist/<platform>`；
3. 通过 `go build ./...` 验证 Go 封装可成功编译。

对普通使用者而言，通常只需要使用 CI 生成好的 `dist/<platform>`，无需本地安装 Rust 或显式执行构建命令。

### 运行/链接提示

默认情况下，`transcribe_api.go` / `transcribe_stream.go` 的 `#cgo LDFLAGS` 指向 `${SRCDIR}/../../target/release`。在二次开发或集成阶段：

- 如果直接在仓库内开发，可保持 `libdianyaapi_ffi` 位于 `dianyaapi-ffi/target/release`，并设置
  - Linux: `export LD_LIBRARY_PATH=/path/to/dianyaapi-ffi/target/release:$LD_LIBRARY_PATH`
  - macOS: `export DYLD_LIBRARY_PATH=/path/to/dianyaapi-ffi/target/release:$DYLD_LIBRARY_PATH`
  - Windows: 将 `dianyaapi-ffi\\target\\release` 加入 `PATH`
- 如果将产物复制到 `dist/<platform>`，可在构建/运行前设定 `CGO_LDFLAGS` 或把该目录加入上述库搜索路径。

### 使用示例

```go
package main

import (
	"log"
	"time"

	"dianyaapi"
)

func main() {
	client := dianyaapi.NewClient()
	token := "Bearer <your-token>"

	session, err := dianyaapi.CreateSession("speed", token)
	if err != nil {
		log.Fatalf("create session failed: %v", err)
	}

	stream, err := dianyaapi.NewStream(session.SessionID)
	if err != nil {
		log.Fatalf("create stream failed: %v", err)
	}
	defer stream.Close()

	if err := stream.Start(); err != nil {
		log.Fatalf("start stream failed: %v", err)
	}

	// 将 PCM 数据写入
	// _ = stream.SendBytes(audioChunk)

	msg, ok, err := stream.Receive(2 * time.Second)
	if err != nil {
		log.Fatalf("receive failed: %v", err)
	}
	if ok {
		log.Printf("transcribe result: %s", msg)
	}

	if _, err := dianyaapi.CloseSession(session.TaskID, token, 0); err != nil {
		log.Printf("close session warning: %v", err)
	}
}
```

### 常见问题

1. **找不到 `libdianyaapi_ffi`**：确认已经获取了与你平台匹配的预编译 `libdianyaapi_ffi`（例如来自 GitHub Actions / Release），或在 CI / 本地完整执行了 CMake 构建流程；同时设置好系统的库搜索路径。
2. **Windows 下链接错误**：确保 `clang-cl` 或 `MSVC` 可用，并把 `dianyaapi_ffi.dll` 与 `dianyaapi_ffi.lib` 一起放入 `dist/Windows`。
3. **Go 构建时头文件不可见**：确认 `#cgo CFLAGS` 中 `-I${SRCDIR}/../../include` 对应的目录存在，且 `dianyaapi_ffi.h` 已复制。

如需扩展更多 API，可参考 `src/transcribe_api.rs` / `transcribe_stream.rs`，在 Go 端直接新增对应的 `cgo` 封装函数。

