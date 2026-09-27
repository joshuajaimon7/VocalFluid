import AppKit
import CoreGraphics

/// System-wide hotkey capture via CGEvent tap + NSEvent global monitor.
///
/// - Push-to-talk: Hold Function / Globe (Fn, keycode 63 or maskSecondaryFn) — Wispr Flow style.
///   (Right Option, keycode 61, is also supported as an alternate push-to-talk key).
///   Hold Shift while releasing to bypass LLM cleanup and insert raw output.
/// - Double-tap Fn: Toggles hands-free dictation on/off.
/// - Hands-free toggle: Control+Option+Space or Control+Option+D.
///
/// Requires Accessibility permission.
final class HotkeyManager {
    var onPushToTalkDown: (() -> Void)?
    var onPushToTalkUp: ((_ bypassCleanup: Bool) -> Void)?
    var onToggle: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let fnKeycode: Int64 = 63
    private static let rightOptionKeycode: Int64 = 61
    private static let spaceKeycode: Int64 = 49
    private static let dKeycode: Int64 = 2

    private var globalMonitor: Any?
    private var fnHeld = false
    private var rightOptionHeld = false
    private var lastFnPressTime: Date = .distantPast

    /// Returns true if the event tap was installed (permissions granted).
    @discardableResult
    func start() -> Bool {
        setupGlobalMonitor()
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            manager.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            flog("[hotkey] CGEvent.tapCreate FAILED — using global monitor fallback (grant Accessibility in System Settings)")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        flog("[hotkey] event tap installed (AXTrusted=\(AXIsProcessTrusted()), listenAccess=\(CGPreflightListenEventAccess()))")
        return true
    }

    private func setupGlobalMonitor() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self, self.eventTap == nil else { return }
            if event.type == .flagsChanged {
                let fnActive = event.modifierFlags.contains(.function)
                if fnActive != self.fnHeld {
                    self.fnHeld = fnActive
                    if fnActive {
                        flog("[globalMonitor] Fn key down")
                        DispatchQueue.main.async { self.onPushToTalkDown?() }
                    } else {
                        flog("[globalMonitor] Fn key up")
                        let bypass = event.modifierFlags.contains(.shift)
                        DispatchQueue.main.async { self.onPushToTalkUp?(bypass) }
                    }
                }
            } else if event.type == .keyDown {
                if (event.keyCode == UInt16(Self.spaceKeycode) || event.keyCode == UInt16(Self.dKeycode)),
                   event.modifierFlags.contains(.control), event.modifierFlags.contains(.option) {
                    flog("[globalMonitor] Hotkey toggle triggered")
                    DispatchQueue.main.async { self.onToggle?() }
                }
            }
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        eventTap = nil
        runLoopSource = nil
        fnHeld = false
        rightOptionHeld = false
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .flagsChanged:
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // 1. Function / Globe key detection (Wispr Flow default)
            let isFnFlag = flags.contains(.maskSecondaryFn)
            let isFnKeycode = (keycode == Self.fnKeycode)

            if isFnFlag || isFnKeycode {
                let isNowDown = isFnFlag
                if isNowDown != fnHeld {
                    fnHeld = isNowDown
                    if fnHeld {
                        let now = Date()
                        // Double-tap Fn detection within 350ms toggles continuous dictation
                        if now.timeIntervalSince(lastFnPressTime) < 0.35 {
                            flog("[hotkey] Double-tap Fn detected -> toggling hands-free dictation")
                            DispatchQueue.main.async { self.onToggle?() }
                        } else {
                            flog("[hotkey] Fn down (push-to-talk)")
                            DispatchQueue.main.async { self.onPushToTalkDown?() }
                        }
                        lastFnPressTime = now
                    } else {
                        flog("[hotkey] Fn up (stop dictation)")
                        let bypass = flags.contains(.maskShift)
                        DispatchQueue.main.async { self.onPushToTalkUp?(bypass) }
                    }
                }
            }

            // 2. Right Option key (alternate single-finger push-to-talk)
            if keycode == Self.rightOptionKeycode {
                let optionDown = flags.contains(.maskAlternate)
                if optionDown != rightOptionHeld {
                    rightOptionHeld = optionDown
                    if rightOptionHeld {
                        flog("[hotkey] Right Option down (push-to-talk)")
                        DispatchQueue.main.async { self.onPushToTalkDown?() }
                    } else {
                        flog("[hotkey] Right Option up (stop dictation)")
                        let bypass = flags.contains(.maskShift)
                        DispatchQueue.main.async { self.onPushToTalkUp?(bypass) }
                    }
                }
            }

        case .keyDown:
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Control + Option + Space or Control + Option + D (Hands-free toggle)
            if (keycode == Self.spaceKeycode || keycode == Self.dKeycode),
               flags.contains(.maskControl), flags.contains(.maskAlternate),
               !flags.contains(.maskCommand), !flags.contains(.maskShift) {
                flog("[hotkey] Hands-free toggle pressed (⌃⌥Space/D)")
                DispatchQueue.main.async { self.onToggle?() }
            }

        case .tapDisabledByTimeout, .tapDisabledByUserInput:
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
