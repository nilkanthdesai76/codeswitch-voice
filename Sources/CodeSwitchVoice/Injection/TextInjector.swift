import Foundation
#if canImport(ApplicationServices)
import ApplicationServices
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Injects transcribed text directly at the current active system cursor position
/// using macOS Accessibility APIs (`AXUIElement`) with simulated keystroke clipboard fallback.
public final class TextInjector: Sendable {

    public enum InjectionResult: Sendable {
        case accessibilitySuccess
        case pasteboardSimulated
        case failed
    }

    /// Injects text at current focused caret position.
    @discardableResult
    public static func inject(text: String) -> InjectionResult {
        guard !text.isEmpty else { return .failed }

        #if os(macOS)
        // 1. Attempt Accessibility API replacement on focused UI element
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let axResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        if axResult == .success, let element = focusedElement {
            let axElement = element as! AXUIElement
            let stringValue = text as CFTypeRef
            let setResult = AXUIElementSetAttributeValue(
                axElement,
                kAXSelectedTextAttribute as CFString,
                stringValue
            )
            if setResult == .success {
                return .accessibilitySuccess
            }
        }

        // 2. Fallback: Clipboard pasteboard simulation (Cmd+V)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let src = CGEventSource(stateID: .combinedSessionState)
        // Virtual key code 0x09 = 'V' on ANSI keyboards
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)

        return .pasteboardSimulated
        #else
        return .failed
        #endif
    }
}
