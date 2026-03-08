import AVFoundation
import CoreAudio
import Foundation

final class AudioCaptureEngine {
    var onAudioData: ((Data) -> Void)?
    var onAudioLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var isEngineRunning = false
    private var isCapturing = false

    /// Call once at app launch to start the engine silently.
    /// The engine stays running forever — no audio disruption.
    func prepare(deviceUID: String? = nil) {
        guard !isEngineRunning else { return }

        if let uid = deviceUID {
            setInputDevice(uid: uid)
        }

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

        engine.prepare()
        try? engine.start()
        isEngineRunning = true
    }

    /// Start sending audio data. Engine must already be running via prepare().
    func start(deviceUID: String? = nil) throws {
        if !isEngineRunning {
            prepare(deviceUID: deviceUID)
        }
        isCapturing = true
    }

    /// Stop sending audio data. Engine keeps running silently.
    func stop() {
        isCapturing = false
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
