import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

final class TextInsertionService {
    func insert(_ text: String) -> Bool {
        if let element = focusedElement(), isProbablyEditable(element) {
            if insertViaAccessibility(text, into: element) {
                return true
            }
        }

        // Always fall back to pasteboard (Cmd+V) even if no editable element was found
        return insertViaPasteboard(text)
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

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
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
