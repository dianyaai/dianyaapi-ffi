# C 语言示例

此目录包含使用 DianyaAPI FFI 的 C 语言示例代码。

## 编译

### 使用 Makefile

```bash
make
```

### 使用 CMake

```bash
mkdir build && cd build
cmake ../..
cmake --build .
```

### 手动编译

```bash
gcc -I../../include -L../../target/release -ldianyaapi_ffi main.c -o main
```

## 运行

在运行之前，确保 Rust 库已构建：

```bash
cd ../..
cargo build --release
```

然后运行示例：

```bash
# Linux
LD_LIBRARY_PATH=../../target/release:$LD_LIBRARY_PATH ./main

# macOS
DYLD_LIBRARY_PATH=../../target/release:$DYLD_LIBRARY_PATH ./main

# Windows
set PATH=%PATH%;..\..\target\release && main.exe
```

或使用 Makefile：

```bash
make run
```

## 注意事项

1. 确保 `target/release/libdianyaapi_ffi.so`（或对应的库文件）已构建
2. 确保运行时能找到库文件（通过 `LD_LIBRARY_PATH` 或 `rpath`）
3. 修改 `main.c` 中的 `token` 和 `filepath` 为实际值

