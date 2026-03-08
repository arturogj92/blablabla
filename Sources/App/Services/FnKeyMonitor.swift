import CoreGraphics
import Foundation

/// Monitors the Fn key alone (no other modifiers).
/// Fn only produces `flagsChanged` events — no keyDown/keyUp.
final class FnKeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isPressed = false

    func start() {
        stop()

        let mask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue
        let ref = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handle(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: ref
        ) else { return }

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

    private func handle(event: CGEvent) {
        let flags = event.flags

        // Only trigger when Fn is the ONLY modifier held
        let modifierMask: CGEventFlags = [.maskShift, .maskAlternate, .maskCommand, .maskControl]
        let hasOtherModifiers = !flags.intersection(modifierMask).isEmpty

        let fnDown = flags.contains(.maskSecondaryFn) && !hasOtherModifiers

        if fnDown && !isPressed {
            isPressed = true
            onPress?()
        } else if !fnDown && isPressed {
            isPressed = false
            onRelease?()
        }
    }
}
