import AppKit
import AVFoundation
import SwiftUI

/// First-run onboarding: explains and requests Microphone + Accessibility,
/// and verifies Ollama is reachable with the configured model pulled.
struct OnboardingView: View {
    @State private var micGranted = false
    @State private var axGranted = AXIsProcessTrusted()
    @State private var ollamaStatus = "Not checked"
    @State private var ollamaOK = false
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to FlowLocal")
                .font(.title2).bold()
            Text("Hold **Right ⌥** and speak — cleaned-up text lands wherever your cursor is. Everything runs on this Mac: speech-to-text on the Neural Engine, cleanup via your local Ollama. Audio never leaves the device and is never written to disk.")
                .fixedSize(horizontal: false, vertical: true)

            step(
                done: micGranted,
                title: "Microphone",
                detail: "Needed to hear you dictate.",
                button: "Grant"
            ) {
                Task {
                    micGranted = await AVCaptureDevice.requestAccess(for: .audio)
                }
            }

            step(
                done: axGranted,
                title: "Accessibility",
                detail: "Needed for the global hotkey and to type into other apps.",
                button: "Open System Settings"
            ) {
                _ = HotkeyManager.ensurePermissions()
                HotkeyManager.openAccessibilitySettings()
            }

            step(
                done: ollamaOK,
                title: "Ollama (\(ollamaStatus))",
                detail: "Local LLM for transcript cleanup. Optional — dictation works without it.",
                button: "Check"
            ) {
                Task {
                    do {
                        try await Cleaner().healthCheck()
                        ollamaOK = true
                        ollamaStatus = "ready"
                    } catch {
                        ollamaOK = false
                        ollamaStatus = error.localizedDescription
                    }
                }
            }

            HStack {
                Spacer()
                Button("Start Dictating") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            axGranted = AXIsProcessTrusted()
        }
    }

    private func step(done: Bool, title: String, detail: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold()
                Text(detail).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !done {
                Button(button, action: action)
            }
        }
    }
}

@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?

    func showIfNeeded() {
        guard !AppSettings.shared.onboarded else { return }
        let view = OnboardingView { [weak self] in
            AppSettings.shared.onboarded = true
            self?.window?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "FlowLocal Setup"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
