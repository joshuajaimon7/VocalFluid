import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Inserts text at the current cursor position in whatever app has focus.
///
/// Strategy:
/// 1. Accessibility API — find the system-wide focused UI element and set its
///    selected text. Clean and precise, but fails silently in some apps
///    (Google Docs, VSCode, Electron apps).
/// 2. Pasteboard fallback — save the clipboard, copy the text, synthesize
///    Cmd+V via CGEvent, then restore the clipboard. Works nearly everywhere.
///
/// Requires Accessibility permission (shared with the hotkey tap).
@MainActor
final class TextInserter {
    /// Length of the most recent insertion, for "scratch that".
    private var lastInsertedLength = 0

    /// Inserts `text` into the focused field. Returns the method used.
    @discardableResult
    func insert(_ text: String) -> InsertionMethod {
        guard !text.isEmpty else { return .none }
        let target = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        flog("[insert] target app: \(target)")
        lastInsertedLength = text.count
        if insertViaAccessibility(text) {
            return .accessibility
        }
        insertViaPasteboard(text)
        return .pasteboard
    }

    /// "Scratch that": deletes the last inserted chunk by synthesizing
    /// backspaces (works regardless of which insertion method was used).
    func scratchLast() {
        guard lastInsertedLength > 0 else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        let deleteKey = CGKeyCode(kVK_Delete)
        for _ in 0..<lastInsertedLength {
            CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: true)?.post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: false)?.post(tap: .cghidEventTap)
        }
        lastInsertedLength = 0
    }

    // MARK: - Method 1: Accessibility API

    private func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef
        ) == .success, let focusedRef else {
            return false
        }
        let focused = focusedRef as! AXUIElement

        // Only attempt on elements that expose a settable selected-text attribute;
        // otherwise the set can "succeed" while doing nothing (Google Docs, VSCode).
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            focused, kAXSelectedTextAttribute as CFString, &settable
        ) == .success, settable.boolValue else {
            return false
        }

        // Read back the current value to detect silent failures.
        let setResult = AXUIElementSetAttributeValue(
            focused, kAXSelectedTextAttribute as CFString, text as CFTypeRef
        )
        guard setResult == .success else { return false }

        // Verify the element actually contains our text now (best-effort).
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &valueRef) == .success,
           let value = valueRef as? String, !value.contains(text) {
            return false
        }
        return true
    }

    // MARK: - Method 2: Pasteboard + synthesized Cmd+V

    private func insertViaPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Preserve the user's clipboard (all types we can round-trip).
        let savedItems: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    contents[type] = data
                }
            }
            return contents
        } ?? []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        synthesizeCmdV()

        // Restore after the paste lands (Cmd+V is async in the target app).
        // Generous delay: restoring too early clobbers the paste in slow apps.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            pasteboard.clearContents()
            let items = savedItems.map { contents -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (type, data) in contents {
                    item.setData(data, forType: type)
                }
                return item
            }
            if !items.isEmpty {
                pasteboard.writeObjects(items)
            }
        }
    }

    private func synthesizeCmdV() {
        // kVK_ANSI_V maps to the physical V position; on non-QWERTY layouts this
        // can differ, but Cmd+V by position is the conventional tradeoff.
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

enum InsertionMethod {
    case accessibility
    case pasteboard
    case none
}
