//
//  AudioRecorder.swift
//  example (macOS)
//
//  参考 iOS 示例与 https://juejin.cn/post/7011067424497729543 文档，
//  适配 macOS 麦克风权限与采样流程。
//

import AVFoundation
import Combine

class AudioRecorder: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    
    @Published var isRecording = false
    @Published var hasPermission = false
    
    private let targetSampleRate: Double = 16000   // ASR 需要 16kHz
    private let bufferSize: AVAudioFrameCount = 1024
    
    var onAudioData: ((Data) -> Void)?
    
    init() {
        requestMicrophonePermission()
    }
    
    private func updatePermissionState(_ granted: Bool, context: String) {
        DispatchQueue.main.async {
            self.hasPermission = granted
            if !granted {
                print("⚠️ [AudioRecorder] 麦克风权限未授予 (\(context))")
            }
        }
    }
    
    func requestMicrophonePermission() {
        #if os(macOS)
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            self?.updatePermissionState(granted, context: "macOS requestAccess")
        }
        #else
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.requestRecordPermission { [weak self] granted in
            self?.updatePermissionState(granted, context: "iOS requestRecordPermission")
        }
        #endif
    }
    
    func ensureMicrophonePermissionStatus() {
#if os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            updatePermissionState(true, context: "macOS authorized")
        case .notDetermined:
            requestMicrophonePermission()
        case .denied, .restricted:
            updatePermissionState(false, context: "macOS denied/restricted")
        @unknown default:
            updatePermissionState(false, context: "macOS unknown status")
        }
#else
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            updatePermissionState(true, context: "iOS granted")
        case .undetermined:
            requestMicrophonePermission()
        case .denied:
            updatePermissionState(false, context: "iOS denied")
        @unknown default:
            updatePermissionState(false, context: "iOS unknown status")
        }
#endif
    }
    
    func startRecording() throws {
        guard hasPermission else {
            throw AudioRecorderError.permissionDenied
        }
        guard !isRecording else { return }
        
        let engine = AVAudioEngine()
        let input = engine.inputNode
        
        engine.prepare()
        
        let inputFormat = input.outputFormat(forBus: 0)
        print("📊 [AudioRecorder] 输入格式 sampleRate=\(inputFormat.sampleRate) channels=\(inputFormat.channelCount)")
        
        var asbd = AudioStreamBasicDescription(
            mSampleRate: targetSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        guard let targetFormat = AVAudioFormat(streamDescription: &asbd) else {
            throw AudioRecorderError.formatError
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.formatError
        }
        converter.sampleRateConverterQuality = AVAudioQuality.high.rawValue
        
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }
            
            let ratio = inputFormat.sampleRate > 0 ? targetFormat.sampleRate / inputFormat.sampleRate : 1
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))
            
            guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
                return
            }
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, status in
                status.pointee = .haveData
                return buffer
            }
            
            converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
            if let error {
                print("❌ [AudioRecorder] 转换失败: \(error)")
                return
            }
            
            guard converted.format.commonFormat == .pcmFormatInt16,
                  let channelData = converted.int16ChannelData else {
                return
            }
            
            let frames = Int(converted.frameLength)
            let bytes = frames * MemoryLayout<Int16>.size
            let data = Data(bytes: channelData[0], count: bytes)
            self.onAudioData?(data)
        }
        
        do {
            try engine.start()
        } catch {
            print("❌ [AudioRecorder] 引擎启动失败: \(error)")
            throw AudioRecorderError.engineError
        }
        
        audioEngine = engine
        inputNode = input
        audioFormat = targetFormat
        isRecording = true
        print("✅ [AudioRecorder] 录音开始")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        audioFormat = nil
        isRecording = false
        print("🛑 [AudioRecorder] 录音停止")
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

