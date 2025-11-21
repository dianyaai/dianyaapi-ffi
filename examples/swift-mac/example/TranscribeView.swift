//
//  TranscribeView.swift
//  example (macOS)
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
    @State private var partialResult: String = ""
    @StateObject private var audioRecorder = AudioRecorder()
    
    private let token = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzgzZTk5Y2YyIiwiZXhwIjoxNzY1MzU5Mjc4Ljk0ODk5fQ.JVL2o7u2IC-LhqFvSAmfE9oGVmnL7R4vfnxm_JA0V5k"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("实时转写测试（macOS）")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 12)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("输入音频")
                    .font(.headline)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("使用 Mac 麦克风进行实时转写")
                            .font(.subheadline)
                        Text("基于 AVAudioEngine + AVAudioConverter 转 16kHz PCM16")
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
            
            if !currentStatus.isEmpty {
                Text(currentStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
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
            .frame(maxHeight: 360)
            
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
            
            if !transcriptions.isEmpty {
                Button("清除结果") {
                    transcriptions.removeAll()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding(24)
        .onAppear {
            audioRecorder.ensureMicrophonePermissionStatus()
        }
        .onDisappear {
            stopTranscribing()
        }
    }
    
    private func startTranscribing() {
        guard !isTranscribing else { return }
        
        guard audioRecorder.hasPermission else {
            currentStatus = "❗️ 请先授予麦克风权限"
            audioRecorder.ensureMicrophonePermissionStatus()
            return
        }
        
        isTranscribing = true
        errorMessage = ""
        transcriptions.removeAll()
        currentStatus = "正在创建会话..."
        
        Task {
            do {
                let session = try await TranscribeStream.createSession(
                    token: token,
                    model: .speed
                )
                
                await MainActor.run {
                    sessionInfo = session
                    currentStatus = "✅ 会话创建成功，准备连接 WebSocket..."
                }
                
                let stream = TranscribeStream(sessionInfo: session)
                try await stream.connect()
                
                await MainActor.run {
                    transcribeStream = stream
                    currentStatus = "✅ WebSocket 已连接，等待音频..."
                    
                    stream.startReceiving { message in
                        handleMessage(message)
                    }
                    
                    audioRecorder.onAudioData = { [weak stream] data in
                        guard let stream = stream else { return }
                        Task {
                            try? await stream.sendAudio(data)
                        }
                    }
                }
                
                do {
                    try audioRecorder.startRecording()
                    await MainActor.run {
                        currentStatus = "🎤 麦克风已启动，正在转写..."
                    }
                } catch {
                    throw error
                }
                
            } catch {
                await MainActor.run {
                    isTranscribing = false
                    errorMessage = "启动失败: \(error.localizedDescription)"
                    currentStatus = ""
                }
            }
        }
    }
    
    private func stopTranscribing(dueToError: Bool = false) {
        guard isTranscribing else { return }
        isTranscribing = false
        
        if !dueToError {
            currentStatus = "正在停止转写..."
        }
        
        Task {
            audioRecorder.stopRecording()
            audioRecorder.onAudioData = nil
            transcribeStream?.stop()
            transcribeStream?.disconnect()
            
            if let sessionInfo {
                do {
                    let closeResult = try await TranscribeStream.closeSession(
                        taskId: sessionInfo.taskId,
                        token: token,
                        timeout: 0
                    )
                    await MainActor.run {
                        if !dueToError {
                            if let duration = closeResult.duration {
                                currentStatus = "✅ 转写已停止，用时 \(duration) 秒"
                            } else {
                                currentStatus = "✅ 转写已停止"
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        if !dueToError {
                            currentStatus = "⚠️ 关闭会话失败: \(error.localizedDescription)"
                        }
                        errorMessage = "关闭会话失败: \(error.localizedDescription)"
                    }
                }
            }
            
            await MainActor.run {
                transcribeStream = nil
                sessionInfo = nil
            }
        }
    }
    
    private func handleMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            print("⚠️ [TranscribeView] 无法解析消息: \(message)")
            return
        }
        
        switch type {
        case "stop":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.stopTranscribing()
            }
            
        case "error":
            if let errorData = json["data"] {
                let detail = "\(errorData)"
                errorMessage = "❌ 错误: \(detail)"
                stopTranscribing(dueToError: true)
            }
            
        case "asr_result":
            if let data = json["data"] as? [String: Any],
               let text = data["text"] as? String,
               !text.isEmpty {
                transcriptions.append("📝 \(text)")
                partialResult = ""
            }
            
        case "asr_result_partial":
            if let data = json["data"] as? [String: Any],
               let text = data["text"] as? String,
               !text.isEmpty {
                partialResult = text
            }
            
        default:
            print("ℹ️ [TranscribeView] 未知消息类型: \(type)")
        }
    }
}

#Preview {
    TranscribeView()
}

