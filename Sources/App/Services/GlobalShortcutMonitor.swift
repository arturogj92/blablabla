import Carbon.HIToolbox
import CoreGraphics
import Foundation

final class GlobalShortcutMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private let keyCode: CGKeyCode
    private let requiredFlags: CGEventFlags
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isPressed = false

    init(keyCode: Int, requiredFlags: CGEventFlags) {
        self.keyCode = CGKeyCode(keyCode)
        self.requiredFlags = requiredFlags
    }

    func start() {
        stop()

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let ref = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(refcon).takeUnretainedValue()

                // Re-enable tap if macOS disabled it (timeout or user input)
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                let consumed = monitor.handle(event: event, type: type)
                return consumed ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: ref
        ) else {
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }

        isPressed = false
    }

    @discardableResult
    private func handle(event: CGEvent, type: CGEventType) -> Bool {
        guard type == .keyDown || type == .keyUp else { return false }

        let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == keyCode else { return false }

        let flags = event.flags.intersection([.maskShift, .maskAlternate, .maskCommand, .maskControl, .maskSecondaryFn])
        guard flags.contains(requiredFlags), flags == requiredFlags else {
            if type == .keyUp, isPressed {
                isPressed = false
                onRelease?()
                return true
            }
            return false
        }

        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        switch type {
        case .keyDown where !isRepeat && !isPressed:
            isPressed = true
            onPress?()
            return true
        case .keyDown where isRepeat:
            // Suppress key repeat sound
            return true
        case .keyUp where isPressed:
            isPressed = false
            onRelease?()
            return true
        default:
            return true
        }
    }
}
