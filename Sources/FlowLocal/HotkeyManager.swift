import AppKit
import CoreGraphics

/// System-wide hotkey capture via a CGEvent tap.
///
/// - Push-to-talk: hold Right Option (keycode 61) — dictation runs while held.
/// - Toggle: Control+Option+D — starts/stops dictation hands-free.
///
/// Requires Accessibility permission (and Input Monitoring on newer macOS).
/// The tap is listen-only for now; milestone 4 may consume the toggle chord.
final class HotkeyManager {
    var onPushToTalkDown: (() -> Void)?
    var onPushToTalkUp: (() -> Void)?
    var onToggle: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var rightOptionHeld = false

    private static let rightOptionKeycode: Int64 = 61
    private static let dKeycode: Int64 = 2

    /// Returns true if the event tap was installed (permissions granted).
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            manager.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        // .defaultTap (active) rather than .listenOnly: listen-only keyboard
        // taps additionally require the Input Monitoring permission, while an
        // active tap works with Accessibility alone. We pass events through
        // unmodified, so behavior is identical for the user.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            flog("[hotkey] CGEvent.tapCreate FAILED — Accessibility/Input Monitoring not granted for this process")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        flog("[hotkey] event tap installed (AXTrusted=\(AXIsProcessTrusted()), listenAccess=\(CGPreflightListenEventAccess()))")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .flagsChanged:
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            if UserDefaults.standard.bool(forKey: "debugKeys") {
                flog("[keylog] flagsChanged keycode=\(keycode) flags=\(event.flags.rawValue)")
            }
            guard keycode == Self.rightOptionKeycode else { return }
            let optionDown = event.flags.contains(.maskAlternate)
            if optionDown && !rightOptionHeld {
                rightOptionHeld = true
                DispatchQueue.main.async { self.onPushToTalkDown?() }
            } else if !optionDown && rightOptionHeld {
                rightOptionHeld = false
                DispatchQueue.main.async { self.onPushToTalkUp?() }
            }

        case .keyDown:
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            if UserDefaults.standard.bool(forKey: "debugKeys") {
                flog("[keylog] keyDown keycode=\(keycode) flags=\(flags.rawValue)")
            }
            if keycode == Self.dKeycode,
               flags.contains(.maskControl), flags.contains(.maskAlternate),
               !flags.contains(.maskCommand), !flags.contains(.maskShift) {
                DispatchQueue.main.async { self.onToggle?() }
            }

        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disables taps that stall; re-enable.
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }

        default:
            break
        }
    }

    // MARK: - Permissions

    /// Prompts for Accessibility permission if not yet granted.
    static func ensurePermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        // Event taps additionally need Input Monitoring on modern macOS.
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }
        return trusted
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
