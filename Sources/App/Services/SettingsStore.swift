import Foundation
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    @Published var assemblyAIKey: String {
        didSet { userDefaults.set(assemblyAIKey, forKey: Keys.assemblyAIKey) }
    }

    @Published var shortcutKeyCode: Int {
        didSet { userDefaults.set(shortcutKeyCode, forKey: Keys.shortcutKeyCode) }
    }

    @Published var shortcutModifierFlagsRawValue: UInt64 {
        didSet { userDefaults.set(shortcutModifierFlagsRawValue, forKey: Keys.shortcutModifierFlagsRawValue) }
    }

    @Published var shortcutDescription: String {
        didSet { userDefaults.set(shortcutDescription, forKey: Keys.shortcutDescription) }
    }

    @Published var selectedMicrophoneUID: String? {
        didSet { userDefaults.set(selectedMicrophoneUID, forKey: Keys.selectedMicrophoneUID) }
    }

    @Published var soundEffectsEnabled: Bool {
        didSet { userDefaults.set(soundEffectsEnabled, forKey: Keys.soundEffectsEnabled) }
    }

    @Published var startRecordingSound: String {
        didSet { userDefaults.set(startRecordingSound, forKey: Keys.startRecordingSound) }
    }

    @Published var lockedRecordingSound: String {
        didSet { userDefaults.set(lockedRecordingSound, forKey: Keys.lockedRecordingSound) }
    }

    @Published var stopRecordingSound: String {
        didSet { userDefaults.set(stopRecordingSound, forKey: Keys.stopRecordingSound) }
    }

    @Published var fnKeyEnabled: Bool {
        didSet { userDefaults.set(fnKeyEnabled, forKey: Keys.fnKeyEnabled) }
    }

    @Published var showIndicatorOnlyWhenRecording: Bool {
        didSet { userDefaults.set(showIndicatorOnlyWhenRecording, forKey: Keys.showIndicatorOnlyWhenRecording) }
    }

    @Published var floatingPanelFreePosition: Bool {
        didSet { userDefaults.set(floatingPanelFreePosition, forKey: Keys.floatingPanelFreePosition) }
    }

    @Published var floatingPanelX: Double? {
        didSet {
            if let v = floatingPanelX { userDefaults.set(v, forKey: Keys.floatingPanelX) }
            else { userDefaults.removeObject(forKey: Keys.floatingPanelX) }
        }
    }

    @Published var floatingPanelY: Double? {
        didSet {
            if let v = floatingPanelY { userDefaults.set(v, forKey: Keys.floatingPanelY) }
            else { userDefaults.removeObject(forKey: Keys.floatingPanelY) }
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    @Published var hideDockIcon: Bool {
        didSet { userDefaults.set(hideDockIcon, forKey: Keys.hideDockIcon) }
    }

    @Published var clipboardOnly: Bool {
        didSet { userDefaults.set(clipboardOnly, forKey: Keys.clipboardOnly) }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.assemblyAIKey = userDefaults.string(forKey: Keys.assemblyAIKey) ?? ""
        self.shortcutKeyCode = userDefaults.object(forKey: Keys.shortcutKeyCode) as? Int ?? Int(kVK_ISO_Section)
        self.shortcutModifierFlagsRawValue = userDefaults.object(forKey: Keys.shortcutModifierFlagsRawValue) as? UInt64 ?? SettingsStore.defaultModifierFlags.rawValue
        self.shortcutDescription = userDefaults.string(forKey: Keys.shortcutDescription) ?? ShortcutFormatter.description(
            keyCode: Int(kVK_ISO_Section),
            modifiers: SettingsStore.defaultModifierFlags
        )
        self.selectedMicrophoneUID = userDefaults.string(forKey: Keys.selectedMicrophoneUID)
        self.soundEffectsEnabled = userDefaults.object(forKey: Keys.soundEffectsEnabled) as? Bool ?? true
        self.startRecordingSound = userDefaults.string(forKey: Keys.startRecordingSound) ?? "Frog"
        self.lockedRecordingSound = userDefaults.string(forKey: Keys.lockedRecordingSound) ?? "Hero"
        self.stopRecordingSound = userDefaults.string(forKey: Keys.stopRecordingSound) ?? "Pop"
        self.fnKeyEnabled = userDefaults.object(forKey: Keys.fnKeyEnabled) as? Bool ?? false
        self.showIndicatorOnlyWhenRecording = userDefaults.object(forKey: Keys.showIndicatorOnlyWhenRecording) as? Bool ?? false
        self.floatingPanelFreePosition = userDefaults.object(forKey: Keys.floatingPanelFreePosition) as? Bool ?? false
        self.floatingPanelX = userDefaults.object(forKey: Keys.floatingPanelX) as? Double
        self.floatingPanelY = userDefaults.object(forKey: Keys.floatingPanelY) as? Double
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.hideDockIcon = userDefaults.object(forKey: Keys.hideDockIcon) as? Bool ?? false
        self.clipboardOnly = userDefaults.object(forKey: Keys.clipboardOnly) as? Bool ?? false
    }

    var shortcutModifierFlags: CGEventFlags {
        CGEventFlags(rawValue: shortcutModifierFlagsRawValue)
    }

    func updateShortcut(keyCode: Int, modifierFlags: CGEventFlags) {
        shortcutKeyCode = keyCode
        shortcutModifierFlagsRawValue = modifierFlags.rawValue
        shortcutDescription = ShortcutFormatter.description(keyCode: keyCode, modifiers: modifierFlags)
    }

    func resetShortcutToDefault() {
        updateShortcut(keyCode: Int(kVK_ISO_Section), modifierFlags: Self.defaultModifierFlags)
    }

    func resetFloatingPanelPosition() {
        floatingPanelX = nil
        floatingPanelY = nil
    }

    static let defaultModifierFlags: CGEventFlags = [.maskShift, .maskAlternate]
}

private enum Keys {
    static let assemblyAIKey = "settings.assemblyAIKey"
    static let shortcutKeyCode = "settings.shortcutKeyCode"
    static let shortcutModifierFlagsRawValue = "settings.shortcutModifierFlagsRawValue"
    static let shortcutDescription = "settings.shortcutDescription"
    static let selectedMicrophoneUID = "settings.selectedMicrophoneUID"
    static let soundEffectsEnabled = "settings.soundEffectsEnabled"
    static let startRecordingSound = "settings.startRecordingSound"
    static let lockedRecordingSound = "settings.lockedRecordingSound"
    static let stopRecordingSound = "settings.stopRecordingSound"
    static let fnKeyEnabled = "settings.fnKeyEnabled"
    static let showIndicatorOnlyWhenRecording = "settings.showIndicatorOnlyWhenRecording"
    static let floatingPanelFreePosition = "settings.floatingPanelFreePosition"
    static let floatingPanelX = "settings.floatingPanelX"
    static let floatingPanelY = "settings.floatingPanelY"
    static let hideDockIcon = "settings.hideDockIcon"
    static let clipboardOnly = "settings.clipboardOnly"
}
