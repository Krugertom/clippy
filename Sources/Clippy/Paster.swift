import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Sends ⌘V to the frontmost app so a clicked clip lands right at the cursor.
/// Requires Accessibility permission; without it we silently stay copy-only
/// (the system prompt is shown on the first attempt).
@MainActor
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    private static var lastPasteAt = Date.distantPast

    /// Returns true if the paste keystroke was posted.
    @discardableResult
    static func pasteToFrontmostApp() -> Bool {
        // One ⌘V per interaction, no matter how many callers race here.
        guard Date().timeIntervalSince(lastPasteAt) > 0.4 else { return false }
        lastPasteAt = Date()
        guard trustedOrPrompt() else { return false }
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        return true
    }

    private static func trustedOrPrompt() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
