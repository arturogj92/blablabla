import AVFoundation
import ApplicationServices
import CoreGraphics
import Foundation
import AppKit

enum MicrophoneAuthStatus {
    case granted
    case denied
    case undetermined
}

struct PermissionStatus {
    let microphoneGranted: Bool
    let microphoneStatus: MicrophoneAuthStatus
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool

    var allGranted: Bool {
        microphoneGranted && accessibilityGranted && inputMonitoringGranted
    }
}

@MainActor
final class PermissionManager {
    func currentStatus() -> PermissionStatus {
        let micStatus = microphoneAuthStatus
        return PermissionStatus(
            microphoneGranted: micStatus == .granted,
            microphoneStatus: micStatus,
            accessibilityGranted: AXIsProcessTrusted(),
            inputMonitoringGranted: CGPreflightListenEventAccess()
        )
    }

    func requestMicrophoneAccess() async -> Bool {
        if microphoneAuthStatus == .granted {
            return true
        }

        let avAudioGranted = await AVAudioApplication.requestRecordPermission()
        if avAudioGranted || microphoneAuthStatus == .granted {
            return true
        }

        let captureGranted = await AVCaptureDevice.requestAccess(for: .audio)
        return captureGranted || microphoneAuthStatus == .granted
    }

    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func requestInputMonitoringAccess() {
        _ = CGRequestListenEventAccess()
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func openMicrophoneSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    }

    func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    var microphoneAuthStatus: MicrophoneAuthStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized ? .granted : .denied
        case .undetermined:
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized ? .granted : .undetermined
        @unknown default:
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized ? .granted : .undetermined
        }
    }
}
