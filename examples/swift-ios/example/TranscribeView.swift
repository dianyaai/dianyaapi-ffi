//
//  TranscribeView.swift
//  example
//
//  Created by Jesse on 2025/11/19.
//

import SwiftUI
import Combine

struct TranscribeView: View {
    @State private var isTranscribing = false
    @State private var transcriptions: [String] = []
    @State private var currentStatus: String = ""
    @State private var errorMessage: String = ""
    @State private var sessionInfo: SessionInfo?
    @State private var transcribeStream: TranscribeStream?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var partialResult: String = ""
    @StateObject private var audioRecorder = AudioRecorder()
    
    // Token from config
    private let token = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzgzZTk5Y2YyIiwiZXhwIjoxNzY1MzU5Mjc4Ljk0ODk5fQ.JVL2o7u2IC-LhqFvSAmfE9oGVmnL7R4vfnxm_JA0V5k"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("实时转写测试")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // 麦克风输入说明
            VStack(alignment: .leading, spacing: 8) {
                Text("输入音频")
                    .font(.headline)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("使用麦克风进行实时转写")
                            .font(.subheadline)
                        Text("点击开始转写后将使用系统麦克风录制音频")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "mic.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // 状态信息
            if !currentStatus.isEmpty {
                Text(currentStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // 错误消息
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // 转写结果
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !partialResult.isEmpty {
                        Text("🔄 部分结果：\(partialResult)")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(8)
                    }
                    if transcriptions.isEmpty && partialResult.isEmpty {
                        Text("转写结果将显示在这里...")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(transcriptions.enumerated()), id: \.offset) { index, text in
                            Text(text)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(index % 2 == 0 ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 400)
            
            // 控制按钮
            HStack(spacing: 20) {
                Button(action: startTranscribing) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("开始转写")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTranscribing ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isTranscribing)
                
                Button(action: { stopTranscribing() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("停止转写")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTranscribing ? Color.red : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!isTranscribing)
            }
            .padding(.horizontal)
            
            // 清除按钮
            if !transcriptions.isEmpty {
                Button("清除结果") {
                    transcriptions.removeAll()
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .onDisappear {
            stopTranscribing()
        }
    }
    
    private func startTranscribing() {
        print("🚀 [TranscribeView] startTranscribing() 开始")
        
        isTranscribing = true
        errorMessage = ""
        transcriptions.removeAll()
        currentStatus = "正在创建会话..."
        
        Task {
            do {
                print("📡 [TranscribeView] 步骤 1: 创建会话...")
                // 1. 创建会话
                let session = try await TranscribeStream.createSession(
                    token: token,
                    model: .speed
                )
                print("✅ [TranscribeView] 会话创建成功: taskId=\(session.taskId), sessionId=\(session.sessionId)")
                
                await MainActor.run {
                    self.sessionInfo = session
                    currentStatus = "✅ 会话创建成功，正在连接 WebSocket..."
                }
                
                print("🔌 [TranscribeView] 步骤 2: 创建并连接 WebSocket...")
                // 2. 创建 WebSocket 客户端
                let stream = TranscribeStream(sessionInfo: session)
                
                try await stream.connect()
                print("✅ [TranscribeView] WebSocket 连接成功")
                
                await MainActor.run {
                    self.transcribeStream = stream
                    currentStatus = "✅ WebSocket 已连接，开始接收转写结果..."
                    
                    print("📨 [TranscribeView] 步骤 3: 开始接收消息...")
                    stream.startReceiving { message in
                        print("📩 [TranscribeView] 收到消息: \(message.prefix(100))...")
                        self.handleMessage(message)
                    }
                    
                    // 3. 设置音频数据回调，将音频数据发送到 WebSocket
                    // 使用 weak 捕获 stream（类类型）避免循环引用
                    self.audioRecorder.onAudioData = { [weak stream] data in
                        guard let stream = stream else { return }
                        
                        Task {
                            do {
                                try await stream.sendAudio(data)
                                // 每100次发送打印一次日志，避免日志过多
                                // print("✅ [TranscribeView] 音频数据发送成功: \(data.count) 字节")
                            } catch {
                                print("❌ [TranscribeView] 发送音频数据失败: \(error)")
                            }
                        }
                    }
                }
                
                print("🎤 [TranscribeView] 步骤 4: 启动麦克风输入...")
                await MainActor.run {
                    currentStatus = "🎤 正在启动麦克风..."
                }
                
                // 4. 启动麦克风输入
                do {
                    try audioRecorder.startRecording()
                    print("✅ [TranscribeView] 麦克风输入已启动")
                    
                    await MainActor.run {
                        currentStatus = "🎤 麦克风已启动，正在转写..."
                    }
                } catch {
                    throw error
                }
                
            } catch {
                print("❌ [TranscribeView] 启动转写失败: \(error)")
                await MainActor.run {
                    isTranscribing = false
                    errorMessage = "启动转写失败: \(error.localizedDescription)"
                    currentStatus = ""
                }
            }
        }
    }
    
    private func stopTranscribing(dueToError: Bool = false) {
        print("🛑 [TranscribeView] stopTranscribing() 开始")
        guard isTranscribing else {
            print("⚠️ [TranscribeView] 未在转写中")
            return
        }
        
        // 立即设置 isTranscribing = false，防止重复调用
        isTranscribing = false
        
        if !dueToError {
            currentStatus = "正在停止转写..."
        }
        print("🛑 [TranscribeView] 停止麦克风输入...")
        
        Task {
            // 停止麦克风输入
            print("🛑 [TranscribeView] 停止麦克风输入...")
            audioRecorder.stopRecording()
            audioRecorder.onAudioData = nil
            
            // 停止 WebSocket 接收
            print("🛑 [TranscribeView] 停止 WebSocket 接收...")
            transcribeStream?.stop()
            
            // 断开连接
            print("🔌 [TranscribeView] 断开 WebSocket 连接...")
            transcribeStream?.disconnect()
            
            // 关闭会话
            if let sessionInfo = sessionInfo {
                print("🔒 [TranscribeView] 关闭会话: taskId=\(sessionInfo.taskId)")
                do {
                    let closeResult = try await TranscribeStream.closeSession(
                        taskId: sessionInfo.taskId,
                        token: token,
                        timeout: 0
                    )
                    print("✅ [TranscribeView] 会话关闭成功: status=\(closeResult.status)")
                    
                    await MainActor.run {
                        if !dueToError {
                            if let duration = closeResult.duration {
                                currentStatus = "✅ 转写已停止，持续时间: \(duration)秒"
                            } else {
                                currentStatus = "✅ 转写已停止"
                            }
                        }
                    }
                } catch {
                    print("❌ [TranscribeView] 关闭会话失败: \(error)")
                    await MainActor.run {
                        if !dueToError {
                            currentStatus = "⚠️ 关闭会话时出错: \(error.localizedDescription)"
                        }
                        errorMessage = "关闭会话失败: \(error.localizedDescription)"
                    }
                }
            } else {
                print("⚠️ [TranscribeView] 没有会话信息")
            }
            
            await MainActor.run {
                // isTranscribing 已在 stopTranscribing() 开始时设置为 false
                transcribeStream = nil
                sessionInfo = nil
                print("✅ [TranscribeView] 转写已完全停止")
            }
        }
    }
    
    private func handleMessage(_ message: String) {
        print("📨 [TranscribeView] handleMessage() 收到完整消息: \(message)")
        
        // 解析 JSON 消息
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msgType = json["type"] as? String else {
            print("⚠️ [TranscribeView] 无法解析消息: \(message)")
            return
        }
        
        print("📋 [TranscribeView] 消息类型: \(msgType)")
        
        switch msgType {
        case "stop":
            print("🛑 [TranscribeView] 收到停止信号")
            // 如果已经在停止过程中，不再重复调用 stopTranscribing()
            guard isTranscribing else {
                print("⚠️ [TranscribeView] 已在停止过程中，忽略重复的停止信号")
                return
            }
            currentStatus = "🛑 收到停止信号"
            // 延迟调用，确保当前消息处理完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                stopTranscribing()
            }
            
                case "error":
            print("❌ [TranscribeView] 收到错误消息")
            if let errorData = json["data"] {
                let errorString = "\(errorData)"
                print("❌ [TranscribeView] 错误详情: \(errorString)")
                errorMessage = "❌ 错误: \(errorString)"
            }
            
        case "asr_result":
            print("✅ [TranscribeView] 收到最终转写结果")
            if let data = json["data"] as? [String: Any],
               let text = data["text"] as? String,
               !text.isEmpty {
                print("📝 [TranscribeView] 转写文本: \(text)")
                transcriptions.append("📝 \(text)")
                partialResult = ""
            } else {
                print("⚠️ [TranscribeView] asr_result 数据格式不正确: \(json)")
            }
            
        case "asr_result_partial":
            print("🔄 [TranscribeView] 收到部分转写结果")
            // 部分结果，可以选择显示或忽略
            if let data = json["data"] as? [String: Any],
               let text = data["text"] as? String,
               !text.isEmpty {
                print("📝 [TranscribeView] 部分文本: \(text)")
                partialResult = text
            }
            
        default:
            print("📩 [TranscribeView] 未知消息类型: \(msgType), 完整消息: \(message)")
        }
    }
    
}

#Preview {
    TranscribeView()
}

