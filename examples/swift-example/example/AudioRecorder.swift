//
//  AudioRecorder.swift
//  example
//
//  Created by Jesse on 2025/11/19.
//  支持 iOS 和 macOS 的统一音频录制实现
//

import AVFoundation
import Combine

class AudioRecorder: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    
    @Published var isRecording = false
    @Published var hasPermission = false
    
    private let targetSampleRate: Double = 16000  // ASR 需要 16kHz
    private let channels: UInt32 = 1
    private let bufferSize: AVAudioFrameCount = 1024
    
    var onAudioData: ((Data) -> Void)?
    
    init() {
        requestMicrophonePermission()
    }
    
    func requestMicrophonePermission() {
        #if os(iOS)
        // iOS: 使用 AVAudioSession
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if !granted {
                    print("⚠️ 麦克风权限未授予")
                }
            }
        }
        #elseif os(macOS)
        // macOS: 使用 AVCaptureDevice
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if !granted {
                    print("⚠️ 麦克风权限未授予")
                }
            }
        }
        #endif
    }
    
    func ensureMicrophonePermissionStatus() {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            DispatchQueue.main.async {
                self.hasPermission = true
            }
        case .undetermined:
            requestMicrophonePermission()
        case .denied:
            DispatchQueue.main.async {
                self.hasPermission = false
            }
        @unknown default:
            DispatchQueue.main.async {
                self.hasPermission = false
            }
        }
        #elseif os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            DispatchQueue.main.async {
                self.hasPermission = true
            }
        case .notDetermined:
            requestMicrophonePermission()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.hasPermission = false
            }
        @unknown default:
            DispatchQueue.main.async {
                self.hasPermission = false
            }
        }
        #endif
    }
    
    func startRecording() throws {
        print("🎤 [AudioRecorder] startRecording() 开始")
        
        guard hasPermission else {
            print("❌ [AudioRecorder] 麦克风权限未授予")
            throw AudioRecorderError.permissionDenied
        }
        
        guard !isRecording else {
            print("⚠️ [AudioRecorder] 已经在录制中")
            return
        }
        
        // 创建音频引擎
        let engine = AVAudioEngine()
        let input = engine.inputNode

        engine.prepare()

        // 获取输入格式
        let inputFormat = input.outputFormat(forBus: 0)
        print("📊 [AudioRecorder] 输入音频格式: 采样率=\(inputFormat.sampleRate), 声道数=\(inputFormat.channelCount), 格式=\(inputFormat.commonFormat)")
        
        // 配置目标音频格式：16kHz, 单声道, PCM 16位（参考 ASRDemo2）
        var outputAudioDescription = AudioStreamBasicDescription(
            mSampleRate: targetSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,  // 16-bit = 2 bytes
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,  // 16-bit = 2 bytes
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        guard let targetFormat = AVAudioFormat(streamDescription: &outputAudioDescription) else {
            print("❌ [AudioRecorder] 无法创建目标音频格式 (16kHz, 单声道, PCM Int16)")
            throw AudioRecorderError.formatError
        }
        
        print("📊 [AudioRecorder] 目标音频格式配置:")
        print("   - 采样率: \(targetFormat.sampleRate) Hz (16kHz)")
        print("   - 声道数: \(targetFormat.channelCount) (单声道)")
        print("   - 位深度: 16bit (PCM Int16)")
        print("   - 格式: \(targetFormat.commonFormat)")
        
        // 创建音频转换器
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        guard let converter = converter else {
            print("❌ [AudioRecorder] 无法创建音频转换器")
            throw AudioRecorderError.formatError
        }
        
        // 明确设置采样率转换器质量
        converter.sampleRateConverterQuality = AVAudioQuality.high.rawValue
        print("✅ [AudioRecorder] 音频转换器创建成功，采样率转换质量: high")
        
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            guard let self = self, self.isRecording else { return }
            
            // 转换格式（总是需要转换，因为采样率不同）
            // 输出缓冲区容量需要根据采样率比例计算
            let ratio = inputFormat.sampleRate > 0 ? targetFormat.sampleRate / inputFormat.sampleRate : 1.0
            let outputFrameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))
            
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
                print("❌ [AudioRecorder] 无法创建转换后的音频缓冲区")
                return
            }
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
            
            if let error = error {
                print("❌ [AudioRecorder] 音频转换错误: \(error)")
                return
            }
            
            // 提取PCM数据
            guard convertedBuffer.format.commonFormat == .pcmFormatInt16,
                  let channelData = convertedBuffer.int16ChannelData else {
                print("⚠️ [AudioRecorder] 转换后的缓冲区格式不正确")
                return
            }
            
            let frameLength = Int(convertedBuffer.frameLength)
            let byteCount = frameLength * MemoryLayout<Int16>.size
            let data = Data(bytes: channelData[0], count: byteCount)
            // print("🎤 [AudioRecorder] 获取到麦克风数据，长度: \(data.count) 字节 (\(frameLength) 帧)")
            self.onAudioData?(data)
        }
        
        do {
            try engine.start()
            print("✅ [AudioRecorder] 音频引擎启动成功")
        } catch {
            print("❌ [AudioRecorder] 音频引擎启动失败: \(error)")
            print("❌ [AudioRecorder] 错误详情: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ [AudioRecorder] 错误码: \(nsError.code), 域: \(nsError.domain)")
            }
            throw AudioRecorderError.engineError
        }
        
        self.audioEngine = engine
        self.inputNode = input
        self.audioFormat = targetFormat
        self.isRecording = true
        print("✅ [AudioRecorder] 录音已开始，isRecording = true")
    }
    
    func stopRecording() {
        print("🛑 [AudioRecorder] stopRecording() 开始")
        guard isRecording else {
            print("⚠️ [AudioRecorder] 未在录制中")
            return
        }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        audioFormat = nil
        isRecording = false
        print("✅ [AudioRecorder] 录音已停止")
    }
}

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case formatError
    case engineError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "麦克风权限未授予"
        case .formatError:
            return "音频格式错误"
        case .engineError:
            return "音频引擎错误"
        }
    }
}

