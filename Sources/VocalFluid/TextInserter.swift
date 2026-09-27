import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Inserts text at the current cursor position in whatever app has focus.
///
/// Uses standard macOS pasteboard + synthesized Cmd+V (like Raycast and Wispr Flow),
/// guaranteeing universal compatibility with zero duplicate paste events.
@MainActor
final class TextInserter {
    private var lastInsertedLength = 0
    private var targetApp: NSRunningApplication?

    /// Records the currently focused application prior to dictation.
    func recordTargetApp() {
        let current = NSWorkspace.shared.frontmostApplication
        if current?.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApp = current
            flog("[insert] recorded target app: \(current?.localizedName ?? "?") (PID \(current?.processIdentifier ?? 0))")
        }
    }

    /// Captures any text currently selected in the target app for Highlight & Transform.
    func captureSelectedText() -> String? {
        guard AppSettings.shared.highlightTransform else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
           let focused = focusedRef {
            var selectedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
               let selected = selectedRef as? String, !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flog("[transform] captured selected text: '\(selected.prefix(40))…'")
                return selected
            }
        }
        return nil
    }

    /// Restores focus to the target app so text lands in the right field.
    func restoreFocusToTargetApp() {
        if let app = targetApp, app.bundleIdentifier != Bundle.main.bundleIdentifier {
            app.activate()
            usleep(50000) // 50ms for window server focus switch
        }
    }

    /// Inserts `text` into the focused field exactly once.
    @discardableResult
    func insert(_ text: String) -> InsertionMethod {
        guard !text.isEmpty else { return .none }

        restoreFocusToTargetApp()

        let target = targetApp?.localizedName ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        flog("[insert] inserting \(text.count) chars into: \(target)")
        lastInsertedLength = text.count

        insertViaPasteboard(text)
        return .pasteboard
    }

    /// "Scratch that": deletes the last inserted chunk by synthesizing backspaces.
    func scratchLast() {
        guard lastInsertedLength > 0 else { return }
        restoreFocusToTargetApp()
        let source = CGEventSource(stateID: .combinedSessionState)
        let deleteKey = CGKeyCode(kVK_Delete)
        for _ in 0..<lastInsertedLength {
            CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: true)?.post(tap: .cghidEventTap)
            usleep(3000)
            CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: false)?.post(tap: .cghidEventTap)
            usleep(3000)
        }
        lastInsertedLength = 0
    }

    // MARK: - Single clean Pasteboard + synthesized Cmd+V

    private func insertViaPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Preserve current clipboard items
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

        // Single clean Cmd+V keystroke
        synthesizeCmdV()

        // Restore clipboard after paste has processed in target app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
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
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        usleep(25000) // 25ms hold duration
        keyUp.post(tap: .cghidEventTap)
    }
}

enum InsertionMethod {
    case accessibility
    case pasteboard
    case none
}
