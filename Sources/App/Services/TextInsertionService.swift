import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

final class TextInsertionService {
    private let logFile: URL = {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("blablabla-debug.log")
        // Clear on launch
        try? "".write(to: url, atomically: true, encoding: .utf8)
        return url
    }()

    private func log(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(ts)] \(message)\n"
        if let data = line.data(using: .utf8), let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    }

    func insert(_ text: String) -> Bool {
        log("insert() called, text length=\(text.count)")

        let element = focusedElement()
        if let element {
            let role = stringValue(attribute: kAXRoleAttribute as String, of: element) ?? "unknown"
            let editable = isProbablyEditable(element)
            log("Focused element: role=\(role), editable=\(editable)")

            if editable {
                if insertViaAccessibility(text, into: element) {
                    log("SUCCESS via Accessibility API")
                    return true
                }
                log("Accessibility insert FAILED, falling back to pasteboard")
            }
        } else {
            log("No focused element found")
        }

        let result = insertViaPasteboard(text)
        log("insertViaPasteboard returned \(result)")
        return result
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard result == .success, let focusedElement = focused else {
            return nil
        }

        return (focusedElement as! AXUIElement)
    }

    private func isProbablyEditable(_ element: AXUIElement) -> Bool {
        if let editable = booleanValue(attribute: "AXEditable", of: element), editable {
            return true
        }

        if let role = stringValue(attribute: kAXRoleAttribute as String, of: element),
           [kAXTextFieldRole as String, kAXTextAreaRole as String, kAXComboBoxRole as String, "AXSearchField"].contains(role) {
            return true
        }

        var settable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable) == .success, settable.boolValue {
            return true
        }

        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue {
            return true
        }

        return false
    }

    private func insertViaAccessibility(_ text: String, into element: AXUIElement) -> Bool {
        guard let currentValue = stringValue(attribute: kAXValueAttribute as String, of: element) else {
            return false
        }

        if let selectedRange = selectedRange(of: element) {
            let nsRange = NSRange(location: selectedRange.location, length: selectedRange.length)
            if let swiftRange = Range(nsRange, in: currentValue) {
                let updatedValue = currentValue.replacingCharacters(in: swiftRange, with: text)
                let cursorLocation = nsRange.location + (text as NSString).length
                guard setString(updatedValue, for: kAXValueAttribute as String, on: element),
                      setSelectedRange(NSRange(location: cursorLocation, length: 0), on: element) else {
                    return false
                }
                return true
            }
        }

        return false
    }

    private func insertViaPasteboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Use .privateState so physical keyboard state (e.g. shortcut modifiers
        // still held) doesn't contaminate the synthetic Cmd+V.
        let source = CGEventSource(stateID: .privateState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            log("FAILED to create CGEvent for Cmd+V")
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Send Cmd+V directly to the frontmost app's PID for reliable delivery
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let pid = frontApp.processIdentifier
            log("Posting Cmd+V to PID \(pid) (\(frontApp.localizedName ?? "unknown"))")
            keyDown.postToPid(pid)
            usleep(30_000) // 30 ms gap so the app processes keyDown
            keyUp.postToPid(pid)
        } else {
            log("No frontmost app, posting to HID tap")
            keyDown.post(tap: .cghidEventTap)
            usleep(30_000)
            keyUp.post(tap: .cghidEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            pasteboard.clearContents()
            if let previousString {
                pasteboard.setString(previousString, forType: .string)
            }
        }

        return true
    }

    private func stringValue(attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func booleanValue(attribute: String, of element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? Bool
    }

    private func selectedRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var range = CFRange()
        let axRangeValue = unsafeBitCast(axValue, to: AXValue.self)
        guard AXValueGetValue(axRangeValue, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private func setString(_ value: String, for attribute: String, on element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef) == .success
    }

    private func setSelectedRange(_ range: NSRange, on element: AXUIElement) -> Bool {
        var mutableRange = CFRange(location: range.location, length: range.length)
        guard let axValue = AXValueCreate(.cfRange, &mutableRange) else {
            return false
        }

        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axValue) == .success
    }
}
