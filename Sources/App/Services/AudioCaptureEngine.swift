import AVFoundation
import CoreAudio
import Foundation

// C callback for CoreAudio property listener — must be a free function
private func audioDevicesChanged(
    _ objectID: AudioObjectID,
    _ numberAddresses: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData else { return noErr }
    let engine = Unmanaged<AudioCaptureEngine>.fromOpaque(clientData).takeUnretainedValue()
    // Small delay to let macOS finish the audio route switch
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        engine.handleDeviceChange()
    }
    return noErr
}

final class AudioCaptureEngine {
    var onAudioData: ((Data) -> Void)?
    var onAudioLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var isEngineRunning = false
    private var isCapturing = false
    private var currentDeviceUID: String?
    private var listenersInstalled = false
    private var selfPointer: UnsafeMutableRawPointer?

    deinit {
        removeDeviceChangeListeners()
    }

    /// Start the audio engine and begin sending audio data.
    func start(deviceUID: String? = nil) throws {
        let uid = deviceUID ?? currentDeviceUID
        currentDeviceUID = uid

        if isEngineRunning {
            if uid != currentDeviceUID {
                reinitialize()
            }
            isCapturing = true
            return
        }

        if let uid {
            setInputDevice(uid: uid)
        }

        installTapAndConverter()

        engine.prepare()
        try engine.start()
        isEngineRunning = true
        isCapturing = true

        installDeviceChangeListeners()
    }

    /// Stop sending audio data and release the microphone.
    func stop() {
        isCapturing = false

        engine.inputNode.removeTap(onBus: 0)

        if isEngineRunning {
            engine.stop()
            isEngineRunning = false
        }

        converter = nil
        outputFormat = nil
    }

    // MARK: - Device change handling

    fileprivate func handleDeviceChange() {
        let wasCapturing = isCapturing
        reinitialize()
        if wasCapturing {
            isCapturing = true
        }
    }

    private func installDeviceChangeListeners() {
        guard !listenersInstalled else { return }
        listenersInstalled = true

        selfPointer = Unmanaged.passUnretained(self).toOpaque()

        // Listen for default input device changes
        var defaultInputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddr,
            audioDevicesChanged,
            selfPointer
        )

        // Listen for device list changes (connect/disconnect)
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddr,
            audioDevicesChanged,
            selfPointer
        )

        // Also listen for AVAudioEngine configuration changes as backup
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.handleDeviceChange()
            }
        }
    }

    private func removeDeviceChangeListeners() {
        guard listenersInstalled, let ptr = selfPointer else { return }

        var defaultInputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddr,
            audioDevicesChanged,
            ptr
        )

        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddr,
            audioDevicesChanged,
            ptr
        )

        NotificationCenter.default.removeObserver(self, name: .AVAudioEngineConfigurationChange, object: engine)

        listenersInstalled = false
        selfPointer = nil
    }

    private func reinitialize() {
        isCapturing = false

        engine.inputNode.removeTap(onBus: 0)

        if isEngineRunning {
            engine.stop()
            isEngineRunning = false
        }

        if let uid = currentDeviceUID {
            setInputDevice(uid: uid)
        }

        installTapAndConverter()

        engine.prepare()
        try? engine.start()
        isEngineRunning = true
    }

    private func installTapAndConverter() {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        )!

        self.outputFormat = outputFormat
        self.converter = AVAudioConverter(from: inputFormat, to: outputFormat)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self, self.isCapturing else { return }
            self.computeAudioLevel(buffer: buffer)
            self.handle(buffer: buffer)
        }
    }

    private func setInputDevice(uid: String) {
        var deviceID: AudioDeviceID = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var cfUID = uid as CFString
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            UInt32(MemoryLayout<CFString>.size),
            &cfUID,
            &dataSize,
            &deviceID
        )

        guard status == noErr, deviceID != 0 else { return }

        let audioUnit = engine.inputNode.audioUnit!
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }

    private func computeAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        let samples = channelData[0]
        var sumOfSquares: Float = 0
        for i in 0..<frames {
            let sample = samples[i]
            sumOfSquares += sample * sample
        }

        let rms = sqrtf(sumOfSquares / Float(frames))
        let db = 20 * log10f(max(rms, 1e-7))
        let normalized = max(0, min(1, (db + 60) / 60))

        onAudioLevel?(normalized)
    }

    private func handle(buffer: AVAudioPCMBuffer) {
        guard let converter, let outputFormat else { return }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 256
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            return
        }

        var providedInput = false
        var conversionError: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if providedInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            providedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &conversionError, withInputFrom: inputBlock)

        guard conversionError == nil,
              let audioBuffer = convertedBuffer.audioBufferList.pointee.mBuffers.mData
        else {
            return
        }

        let data = Data(bytes: audioBuffer, count: Int(convertedBuffer.audioBufferList.pointee.mBuffers.mDataByteSize))
        onAudioData?(data)
    }
}
