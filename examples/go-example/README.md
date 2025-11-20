## Dianya Go 示例

此目录演示如何在 Go 项目中复用仓库内 `export/go-lang` 提供的封装，完成离线转写接口与实时流式 API 的调用。

### 目录结构

- `go.mod`：示例 Go module，并通过 `replace dianyaapi => ../../export/go-lang` 直接引用仓库内封装。
- `main.go`：示例程序，包含上传/状态/分享/导出/翻译等 REST 调用，以及读取 WAV 文件模拟实时音频推流。
- `dist/<platform>`：从 `export/go-lang/dist/<platform>` 拷贝的 FFI 产物（`dianyaapi_ffi.h`、`libdianyaapi_ffi.*`），供运行时链接。

### 前置步骤

1. 在仓库根目录构建 Rust FFI 及 Go 封装：
   ```bash
   cmake -S export/go-lang -B export/go-lang/build
   cmake --build export/go-lang/build
   ```
2. 将生成的 `export/go-lang/dist/<platform>` 复制到 `go-example/dist/<platform>`（已在仓库中完成一次）。
3. 设置库搜索路径，使示例在运行时能够找到 `libdianyaapi_ffi`：
   - Linux:
     ```bash
     export LD_LIBRARY_PATH=$(pwd)/dist/Linux:$LD_LIBRARY_PATH
     ```
   - macOS: `export DYLD_LIBRARY_PATH=...`
   - Windows: 将 `dist\\Windows` 加入 `PATH`。

### 运行示例

```bash
cd go-example
go run .
```

程序将依次执行：
1. 上传 `data/one_sentence.wav`，打印任务 ID。
2. 查询状态、获取分享链接、导出 PDF、执行翻译示例。
3. 创建实时会话，读取同一 WAV 文件分片并通过 WebSocket 发送，输出服务端返回的 JSON。

> 默认使用仓库里演示用的 token 与 WAV 文件路径，可根据需要在 `main.go` 内更改。

### 注意事项

- 若要采集麦克风音频，可改写 `runStreamExample` 使用 PortAudio 或其他音频 SDK。
- 若计划将示例迁移到独立仓库，可将 `export/go-lang` 发布为私有模块或复制 `transcribe_*.go`。
- 对于生产环境请勿硬编码 token，推荐读取环境变量或配置文件。

