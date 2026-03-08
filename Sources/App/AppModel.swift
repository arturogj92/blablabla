import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum SessionState: Equatable {
        case idle
        case listeningPushToTalk
        case listeningLocked
        case finalizing
        case error(String)
    }

    @Published private(set) var sessionState: SessionState = .idle
    @Published private(set) var liveTranscript = ""
    @Published private(set) var committedTranscript = ""
    @Published private(set) var statusMessage = "Ready to dictate"
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var permissionStatus: PermissionStatus
    @Published private(set) var history: [TranscriptRecord]

    let settings: SettingsStore

    var showMainWindow: (() -> Void)?
    var showFloatingPanel: (() -> Void)?
    var hideFloatingPanel: (() -> Void)?

    var visibleTranscript: String {
        [committedTranscript, liveTranscript]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: committedTranscript.isEmpty || liveTranscript.isEmpty ? "" : " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let permissions: PermissionManager
    private let transcriptStore: TranscriptStore
    private let insertionService: TextInsertionService
    private let audioCapture: AudioCaptureEngine
    private let streamingClient: AssemblyAIStreamingClient

    private let soundPlayer = SoundEffectPlayer()
    private var pressStartedAt: Date?
    private var recordingStartedAt: Date?
    private var pendingStopWorkItem: DispatchWorkItem?
    private var pendingHideWorkItem: DispatchWorkItem?
    private var finalizationFallbackWorkItem: DispatchWorkItem?
    private var hasSubmittedTerminate = false

    init(
        settings: SettingsStore,
        permissions: PermissionManager,
        transcriptStore: TranscriptStore,
        insertionService: TextInsertionService,
        audioCapture: AudioCaptureEngine,
        streamingClient: AssemblyAIStreamingClient
    ) {
        self.settings = settings
        self.permissions = permissions
        self.transcriptStore = transcriptStore
        self.insertionService = insertionService
        self.audioCapture = audioCapture
        self.streamingClient = streamingClient
        self.permissionStatus = permissions.currentStatus()
        self.history = transcriptStore.load()

        audioCapture.onAudioData = { [weak streamingClient] data in
            streamingClient?.sendAudio(data)
        }

        audioCapture.onAudioLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        streamingClient.onEvent = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleAssemblyAIMessage(message)
            }
        }

        streamingClient.onFailure = { [weak self] errorMessage in
            Task { @MainActor [weak self] in
                self?.fail(with: errorMessage)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissions()
        }

        // Pre-prepare audio engine at launch so recording starts instantly
        if permissions.currentStatus().microphoneGranted {
            audioCapture.prepare(deviceUID: settings.selectedMicrophoneUID)
        }
    }

    func refreshPermissions() {
        permissionStatus = permissions.currentStatus()
    }

    func requestMicrophonePermission() {
        Task {
            let granted = await permissions.requestMicrophoneAccess()
            await MainActor.run {
                refreshPermissions()
                if granted || permissionStatus.microphoneGranted {
                    statusMessage = "Microphone access granted"
                } else {
                    statusMessage = "macOS did not grant microphone access. If no popup appeared, use System Settings."
                }
            }
        }
    }

    func requestAccessibilityPermission() {
        permissions.requestAccessibilityAccess()
        refreshPermissions()
    }

    func requestInputMonitoringPermission() {
        permissions.requestInputMonitoringAccess()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        permissions.openAccessibilitySettings()
    }

    func openMicrophoneSettings() {
        permissions.openMicrophoneSettings()
    }

    func openInputMonitoringSettings() {
        permissions.openInputMonitoringSettings()
    }

    func openHistoryWindow() {
        showMainWindow?()
    }

    func copyTranscript(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        statusMessage = "Transcript copied to clipboard"
    }

    func clearHistory() {
        history.removeAll()
        transcriptStore.save(history)
    }

    func toggleRecording() {
        cancelPendingHide()

        guard ensureReadyForRecording() else { return }

        switch sessionState {
        case .idle, .error:
            startRecording(mode: .listeningLocked)
        case .listeningPushToTalk, .listeningLocked:
            stopRecording()
        case .finalizing:
            break
        }
    }

    func handleShortcutPressed() {
        cancelPendingHide()

        guard ensureReadyForRecording() else { return }

        if pendingStopWorkItem != nil, sessionState == .listeningPushToTalk {
            pendingStopWorkItem?.cancel()
            pendingStopWorkItem = nil
            sessionState = .listeningLocked
            statusMessage = "Locked dictation"
            if settings.soundEffectsEnabled {
                soundPlayer.play(.recordingLocked, soundName: settings.lockedRecordingSound)
            }
            showFloatingPanel?()
            return
        }

        switch sessionState {
        case .idle, .error:
            pressStartedAt = Date()
            startRecording(mode: .listeningPushToTalk)
        case .listeningLocked:
            stopRecording()
        case .listeningPushToTalk, .finalizing:
            break
        }
    }

    func handleShortcutReleased() {
        switch sessionState {
        case .listeningPushToTalk:
            let heldTime = Date().timeIntervalSince(pressStartedAt ?? .now)
            if heldTime < 0.35 {
                let workItem = DispatchWorkItem { [weak self] in
                    self?.stopRecording()
                }
                pendingStopWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
            } else {
                stopRecording()
            }
        default:
            break
        }
    }

    private func ensureReadyForRecording() -> Bool {
        refreshPermissions()

        guard !settings.assemblyAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Add your AssemblyAI API key before dictating"
            showMainWindow?()
            return false
        }

        guard permissionStatus.microphoneGranted else {
            statusMessage = "Microphone access is required"
            requestMicrophonePermission()
            showMainWindow?()
            return false
        }

        guard permissionStatus.accessibilityGranted else {
            statusMessage = "Accessibility access is required to paste into other apps"
            permissions.requestAccessibilityAccess()
            showMainWindow?()
            return false
        }

        guard permissionStatus.inputMonitoringGranted else {
            statusMessage = "Input Monitoring is required for the global shortcut"
            permissions.requestInputMonitoringAccess()
            showMainWindow?()
            return false
        }

        return true
    }

    private func startRecording(mode: SessionState) {
        pendingStopWorkItem?.cancel()
        pendingStopWorkItem = nil
        finalizationFallbackWorkItem?.cancel()
        finalizationFallbackWorkItem = nil
        committedTranscript = ""
        liveTranscript = ""
        statusMessage = mode == .listeningLocked ? "Locked dictation" : "Listening"
        sessionState = mode
        hasSubmittedTerminate = false
        recordingStartedAt = Date()
        showFloatingPanel?()

        if settings.soundEffectsEnabled {
            soundPlayer.play(.recordingStarted, soundName: settings.startRecordingSound)
        }

        Task {
            do {
                try await streamingClient.start(apiKey: settings.assemblyAIKey)
                try audioCapture.start(deviceUID: settings.selectedMicrophoneUID)
            } catch {
                await MainActor.run {
                    self.fail(with: error.localizedDescription)
                }
            }
        }
    }

    private func stopRecording() {
        guard sessionState == .listeningPushToTalk || sessionState == .listeningLocked else {
            return
        }

        // Track usage
        if let start = recordingStartedAt {
            let seconds = Date().timeIntervalSince(start)
            UsageTracker.shared.addSession(seconds: seconds)
            recordingStartedAt = nil
        }

        pendingStopWorkItem?.cancel()
        pendingStopWorkItem = nil
        audioCapture.stop()
        audioLevel = 0

        if settings.soundEffectsEnabled {
            soundPlayer.play(.recordingStopped, soundName: settings.stopRecordingSound)
        }

        sessionState = .finalizing
        statusMessage = "Finalizing transcript"
        hasSubmittedTerminate = true
        streamingClient.stop()

        let fallback = DispatchWorkItem { [weak self] in
            self?.finalizeTranscript()
        }
        finalizationFallbackWorkItem = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: fallback)
    }

    private func handleAssemblyAIMessage(_ message: AssemblyAIMessage) {
        switch message.type {
        case "Begin":
            if sessionState == .listeningPushToTalk || sessionState == .listeningLocked {
                statusMessage = sessionState == .listeningLocked ? "Locked dictation" : "Listening"
            }
        case "Turn":
            let transcript = message.transcript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !transcript.isEmpty else { return }

            if message.endOfTurn == true {
                committedTranscript = [committedTranscript, transcript]
                    .filter { !$0.isEmpty }
                    .joined(separator: committedTranscript.isEmpty ? "" : " ")
                liveTranscript = ""
            } else {
                liveTranscript = transcript
            }
        case "Termination":
            if hasSubmittedTerminate {
                finalizeTranscript()
            }
        case "Error":
            fail(with: message.error ?? "AssemblyAI reported an unknown error")
        default:
            break
        }
    }

    private func finalizeTranscript() {
        finalizationFallbackWorkItem?.cancel()
        finalizationFallbackWorkItem = nil

        let finalText = visibleTranscript
        sessionState = .idle
        pressStartedAt = nil
        hasSubmittedTerminate = false

        guard !finalText.isEmpty else {
            statusMessage = "No speech detected"
            scheduleFloatingPanelHide(after: 1.0)
            return
        }

        let inserted = insertionService.insert(finalText)
        history.insert(TranscriptRecord(text: finalText, insertedIntoFocusedApp: inserted), at: 0)
        transcriptStore.save(history)

        if inserted {
            statusMessage = "Transcript pasted into the focused app"
            scheduleFloatingPanelHide(after: 0.8)
        } else {
            statusMessage = "No editable field was focused. Transcript saved to history"
            showMainWindow?()
        }
    }

    private func fail(with message: String) {
        audioCapture.stop()
        audioLevel = 0
        streamingClient.stop()
        sessionState = .error(message)
        statusMessage = message
        scheduleFloatingPanelHide(after: 1.5)
        showMainWindow?()
    }

    private func scheduleFloatingPanelHide(after delay: TimeInterval) {
        cancelPendingHide()

        let workItem = DispatchWorkItem { [weak self] in
            self?.hideFloatingPanel?()
        }
        pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelPendingHide() {
        pendingHideWorkItem?.cancel()
        pendingHideWorkItem = nil
    }
}
