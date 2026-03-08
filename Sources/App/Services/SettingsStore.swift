import Foundation
import Carbon.HIToolbox

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
}
