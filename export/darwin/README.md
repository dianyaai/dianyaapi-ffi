# DianyaAPI Swift Package

Swift 封装库，用于在 iOS 和 macOS 应用中使用 Dianya AI 转写服务。

## 功能特性

- ✅ 完整的异步 API 支持（async/await）
- ✅ Combine 框架集成
- ✅ 线程安全保证
- ✅ 自动内存管理
- ✅ 完整的错误处理
- ✅ 实时转写 WebSocket 支持

## 平台要求

- iOS 13.0+
- macOS 10.15+
- Swift 5.5+

## 安装

### 使用 Swift Package Manager

1. 在 Xcode 中，选择 File > Add Packages...
2. 输入仓库 URL 或本地路径
3. 选择版本或分支
4. 添加到你的项目

### 使用 XCFramework

1. 运行构建脚本生成 XCFramework：
```bash
cd dianyaapi-ffi
./export/scripts/build-xcframework.sh
```

2. 在 Xcode 中：
   - 将生成的 `DianyaAPIFFI.xcframework` 拖入项目
   - 添加到 "Frameworks, Libraries, and Embedded Content"
   - 确保 "Embed & Sign" 选项已选中

## 快速开始

### 初始化

```swift
import DianyaAPI

let token = "Bearer your_token_here"
let api = DianyaAPI.TranscribeApi(token: token)
```

### 上传音频文件

```swift
do {
    let result = try await api.upload(
        filePath: "/path/to/audio.wav",
        transcribeOnly: false,
        shortASR: false,
        model: .quality
    )
    
    switch result {
    case .normal(let taskId):
        print("Upload successful, task ID: \(taskId)")
    case .oneSentence(let status, let message, let data):
        print("One-sentence result: \(data)")
    }
} catch {
    print("Upload failed: \(error)")
}
```

### 获取转写状态

```swift
do {
    let status = try await api.getStatus(taskId: "your_task_id")
    print("Status: \(status.status)")
    print("Details count: \(status.details.count)")
    
    for utterance in status.details {
        print("[\(utterance.startTime)-\(utterance.endTime)] Speaker \(utterance.speaker): \(utterance.text)")
    }
} catch {
    print("Failed to get status: \(error)")
}
```

### 导出转写结果

```swift
do {
    let data = try await api.export(
        taskId: "your_task_id",
        exportType: .transcript,
        exportFormat: .pdf
    )
    
    // Save to file
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("transcript.pdf")
    try data.write(to: url)
    print("Exported to: \(url.path)")
} catch {
    print("Export failed: \(error)")
}
```

### 翻译文本

```swift
do {
    let result = try await api.translateText(
        text: "Hello, world!",
        targetLang: .chineseSimplified
    )
    print("Translation: \(result.data)")
} catch {
    print("Translation failed: \(error)")
}
```

## 实时转写（WebSocket）

### 使用 Combine

```swift
import Combine

// Create session (static method)
let session = try await DianyaAPI.TranscribeStream.createSession(
    token: token,
    model: .speed
)
print("Session created: \(session.sessionId)")

// Create stream instance with session info
let stream = DianyaAPI.TranscribeStream(sessionInfo: session)

// Connect
try await stream.connect()

// Start receiving messages
stream.startReceiving()

// Subscribe to messages
var cancellables = Set<AnyCancellable>()
stream.messagePublisher
    .sink { completion in
        if case .failure(let error) = completion {
            print("Error: \(error)")
        }
    } receiveValue: { message in
        print("Received: \(message)")
        // Parse JSON and update UI
    }
    .store(in: &cancellables)

// Send audio data
let audioData = // ... your audio data
try await stream.sendAudio(audioData)

// When done, close session (static method)
let closeResult = try await DianyaAPI.TranscribeStream.closeSession(
    taskId: session.taskId,
    token: token
)
print("Session closed: \(closeResult.status)")

// Disconnect
stream.disconnect()
```

### 使用回调

```swift
// Create session (static method)
let session = try await DianyaAPI.TranscribeStream.createSession(
    token: token,
    model: .speed
)

// Create stream instance and connect
let stream = DianyaAPI.TranscribeStream(sessionInfo: session)
try await stream.connect()

// Start receiving with callback
stream.startReceiving { message in
    print("Received message: \(message)")
    // Update UI on main thread
}

// Send audio
try await stream.sendAudio(audioData)

// Clean up
stream.disconnect()
```

### 使用异步接收

```swift
// Create session and stream
let session = try await DianyaAPI.TranscribeStream.createSession(
    token: token,
    model: .speed
)
let stream = DianyaAPI.TranscribeStream(sessionInfo: session)
try await stream.connect()

// Receive single message with timeout
if let message = try await stream.receive(timeout: 5.0) {
    print("Message: \(message)")
} else {
    print("Timeout or no message")
}
```

## API 参考

### TranscribeApi

#### 上传和状态

- `upload(filePath:transcribeOnly:shortASR:model:)` - 上传音频文件
- `getStatus(taskId:shareId:)` - 获取任务状态
- `export(taskId:exportType:exportFormat:)` - 导出转写结果
- `getShareLink(taskId:expirationDay:)` - 获取分享链接

#### 总结

- `createSummary(utterances:)` - 创建总结任务

#### 翻译

- `translateText(text:targetLang:)` - 翻译文本
- `translateUtterance(utterances:targetLang:)` - 翻译话语列表
- `translateTranscribe(taskId:targetLang:)` - 翻译转写任务

### TranscribeStream

#### 会话管理（静态方法）

- `createSession(token:model:)` - 创建转写会话
- `closeSession(taskId:token:timeout:)` - 关闭会话

#### 连接管理

- `connect()` - 连接 WebSocket（使用 sessionInfo 中的 sessionId）
- `disconnect()` - 断开连接
- `stop()` - 停止接收消息（不断开连接）

#### 消息发送

- `sendText(_:)` - 发送文本消息
- `sendAudio(_:)` - 发送音频数据

#### 消息接收

- `messagePublisher` - Combine Publisher
- `startReceiving()` - 开始接收（Combine）
- `startReceiving(onMessage:)` - 开始接收（回调）
- `receive(timeout:)` - 异步接收单条消息

## 数据模型

### Utterance

```swift
struct Utterance {
    let startTime: Double    // 开始时间（秒）
    let endTime: Double      // 结束时间（秒）
    let speaker: Int32       // 说话人编号
    let text: String         // 转写文本
}
```

### TranscribeStatus

```swift
struct TranscribeStatus {
    let status: String
    let overviewMd: String?
    let summaryMd: String?
    let details: [Utterance]
    let keywords: [String]
    // ... 更多字段
}
```

### SessionInfo

```swift
struct SessionInfo {
    let taskId: String
    let sessionId: String
    let usageId: String
    let maxTime: Int32
}
```

## 错误处理

所有 API 方法都可能抛出 `TranscribeError`：

```swift
enum TranscribeError: Error {
    case websocketError(String)
    case httpError(String)
    case serverError(String)
    case invalidInput(String)
    case invalidResponse(String)
    case invalidToken(String)
    case invalidApiKey(String)
    case jsonError(String)
    case otherError(String)
}
```

错误包含详细的描述和恢复建议：

```swift
do {
    try await api.upload(...)
} catch let error as TranscribeError {
    print("Error: \(error.localizedDescription)")
    print("Suggestion: \(error.recoverySuggestion ?? "")")
}
```

## 线程安全

所有 API 调用都是线程安全的，可以在任何线程上调用。内部使用 `DispatchQueue` 确保 FFI 调用的线程安全。

## 内存管理

所有 C 资源都会自动管理，无需手动释放。使用 `defer` 和 RAII 模式确保资源正确释放。

## 构建 XCFramework

运行构建脚本：

```bash
cd dianyaapi-ffi
./export/scripts/build-xcframework.sh
```

脚本会：
1. 编译 Rust 代码为静态库（iOS arm64, iOS Simulator arm64, macOS arm64 + x86_64）
2. 创建 Framework 结构
3. 合并为 XCFramework
4. 验证架构完整性

输出位置：`xcframework/DianyaAPIFFI.xcframework`

## 许可证

请参考项目根目录的许可证文件。

## 支持

如有问题或建议，请提交 Issue 或联系支持团队。

