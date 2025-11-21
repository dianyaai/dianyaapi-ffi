# C 语言示例

此目录包含使用 DianyaAPI FFI 的 **两个 C 语言示例**：

- `transcribe/`：离线文件转写示例
- `stream/`：实时 WebSocket 流式转写示例

---

## 1. 获取预编译库

核心 Rust FFI 库由 GitHub Actions 构建并提供预编译产物。请从仓库的 GitHub Actions / Release 页面下载与你平台对应的压缩包（通常包含 `libdianyaapi_ffi.*` 以及 `dianyaapi_ffi.h`），并解压到你方便引用的目录（例如 `/opt/dianyaapi` 或项目内的 `third_party/dianyaapi`）。

---

## 2. 编译示例

两个示例目录都提供了 `Makefile`，可以直接在各自目录中编译：

```bash
cd examples/c/transcribe   # 离线转写示例
make

cd ../stream               # 实时流式示例
make
```

如需查看具体编译命令，可直接打开各目录下的 `Makefile`。

---

## 3. 运行示例

在对应示例目录中运行已编译的可执行文件。运行前需要确保动态库搜索路径包含你解压出的预编译库目录：

```bash
# 以 macOS / Linux 为例（假设预编译库位于 /path/to/dianyaapi_lib）
export DYLD_LIBRARY_PATH=/path/to/dianyaapi_lib:$DYLD_LIBRARY_PATH   # macOS
export LD_LIBRARY_PATH=/path/to/dianyaapi_lib:$LD_LIBRARY_PATH       # Linux

./<your_binary_name>
```

> 可执行文件名称取决于 `Makefile` 中的配置，一般是类似 `transcribe_demo` / `stream_demo` 的名称。

---

## 4. 注意事项

1. 确保你已经下载并解压了预编译的 `dianyaapi_ffi` 动态库（`.so` / `.dylib` / `.dll`）。
2. 确保运行时能找到库文件（通过 `DYLD_LIBRARY_PATH` / `LD_LIBRARY_PATH` 或配置 `rpath`）。
3. 根据你自己的环境修改示例代码中的 `token`、文件路径等参数。

