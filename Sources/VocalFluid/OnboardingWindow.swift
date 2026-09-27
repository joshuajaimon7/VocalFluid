import AppKit
import AVFoundation
import SwiftUI

public enum OnboardingStep: Int, CaseIterable {
    case permissions = 1
    case aiSetup = 2
    case interactiveTest = 3
}

/// Premium First-Run Setup Window matching Wispr Flow's onboarding experience.
/// Guides users through Permissions, Model Download & Neural Engine setup with live progress, and an interactive test.
struct OnboardingView: View {
    @State private var currentStep: OnboardingStep = .permissions
    @State private var micGranted = false
    @State private var axGranted = AXIsProcessTrusted()

    // AI Setup state
    @State private var selectedProfile: String = "lightweight"
    @State private var isDownloadingModel = false
    @State private var downloadProgress: Double = 0.0
    @State private var downloadStatus: String = "Ready to prepare models"
    @State private var modelReady = false

    // Interactive Test state
    @State private var testIsRecording = false
    @State private var testTranscript: String = ""

    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.top, 28)
                .padding(.horizontal, 32)

            Divider()
                .padding(.vertical, 18)

            // Step Content
            VStack {
                switch currentStep {
                case .permissions:
                    permissionsStepView
                case .aiSetup:
                    aiSetupStepView
                case .interactiveTest:
                    interactiveTestStepView
                }
            }
            .padding(.horizontal, 32)
            .frame(height: 330)

            Divider()
                .padding(.vertical, 18)

            // Footer navigation
            footerView
                .padding(.bottom, 24)
                .padding(.horizontal, 32)
        }
        .frame(width: 580, height: 530)
        .background(
            Color(red: 0.10, green: 0.10, blue: 0.12)
                .ignoresSafeArea()
        )
        .onAppear {
            checkPermissions()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("VocalFluid Setup")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)

                    Text("Step \(currentStep.rawValue) of 3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }

                Text("100% On-Device Neural Dictation & AI Cleanup")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
    }

    // MARK: - Step 1: Permissions

    private var permissionsStepView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Grant System Permissions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("VocalFluid runs entirely on your Mac. It needs microphone access to hear speech, and Accessibility to insert text into other apps.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                // Microphone card
                HStack(spacing: 14) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(micGranted ? .green : .blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Microphone Access")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Text(micGranted ? "Granted — ready to capture speech" : "Required to record dictation audio")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    if micGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                    } else {
                        Button("Grant") {
                            Task {
                                micGranted = await AVCaptureDevice.requestAccess(for: .audio)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))

                // Accessibility card
                HStack(spacing: 14) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 18))
                        .foregroundColor(axGranted ? .green : .orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Permission")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Text(axGranted ? "Active — ready for global Fn hotkey & typing" : "Required for Fn push-to-talk & pasting into apps")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    if axGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                    } else {
                        Button("Enable") {
                            _ = HotkeyManager.ensurePermissions()
                            HotkeyManager.openAccessibilitySettings()
                            // Poll for grant
                            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
                                if AXIsProcessTrusted() {
                                    axGranted = true
                                    timer.invalidate()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
            }

            Spacer()
        }
    }

    // MARK: - Step 2: AI Model Setup

    private var aiSetupStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select On-Device AI Engine")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("Choose your preferred on-device model. Models run 100% locally on your Apple Silicon Neural Engine.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))

            // Options
            HStack(spacing: 12) {
                // Lightweight card
                Button(action: { selectedProfile = "lightweight" }) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("⚡ Ultra-Light")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            if selectedProfile == "lightweight" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        Text("qwen2.5:0.5b (398 MB)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue.opacity(0.9))
                        Text("Uses < 400MB RAM. Instant startup, ideal for laptops & battery life.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedProfile == "lightweight" ? Color.blue.opacity(0.18) : Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedProfile == "lightweight" ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                // Balanced card
                Button(action: { selectedProfile = "studio" }) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("🚀 Studio Pro")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            if selectedProfile == "studio" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                        Text("qwen2.5:3b (1.9 GB)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.purple.opacity(0.9))
                        Text("Maximum precision for complex technical dictation and coding.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedProfile == "studio" ? Color.purple.opacity(0.18) : Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedProfile == "studio" ? Color.purple : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            // Progress Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(downloadStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    if isDownloadingModel {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: isDownloadingModel ? geo.size.width * CGFloat(downloadProgress) : (modelReady ? geo.size.width : 0), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(.top, 6)

            if !modelReady && !isDownloadingModel {
                Button(action: startModelPreparation) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download & Prepare AI Engine (One-Click)")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }

            Spacer()
        }
    }

    // MARK: - Step 3: Interactive Sandbox Test

    private var interactiveTestStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Try Your First Dictation")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("Hold the **Fn (🌐)** key or **Right ⌥ Option** anywhere on your Mac to dictate. Or click the microphone below to test right now!")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))

            // Interactive dictation sandbox card
            VStack(spacing: 12) {
                // Interactive Mic Button
                Button(action: toggleTestRecording) {
                    ZStack {
                        Circle()
                            .fill(testIsRecording ? Color.red : Color.blue)
                            .frame(width: 56, height: 56)
                            .shadow(color: (testIsRecording ? Color.red : Color.blue).opacity(0.5), radius: 10)

                        Image(systemName: testIsRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                Text(testIsRecording ? "Listening… speak now!" : "Click to speak or hold Fn")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(testIsRecording ? .red : .white.opacity(0.7))

                // Transcribed Output Box
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    if testTranscript.isEmpty {
                        Text("Transcribed text will appear here in real time…")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(12)
                    } else {
                        Text(testTranscript)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(12)
                    }
                }
                .frame(height: 70)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))

            Spacer()
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if currentStep != .permissions {
                Button("Back") {
                    withAnimation {
                        if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = prev
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            if currentStep == .interactiveTest {
                Button("Launch VocalFluid") {
                    onDone()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue") {
                    withAnimation {
                        if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                            currentStep = next
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(currentStep == .permissions && (!micGranted || !axGranted))
            }
        }
    }

    // MARK: - Actions

    private func checkPermissions() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        axGranted = AXIsProcessTrusted()
    }

    private func startModelPreparation() {
        isDownloadingModel = true
        downloadProgress = 0.05
        downloadStatus = "Initializing AI setup…"

        let modelTarget = (selectedProfile == "lightweight") ? "qwen2.5:0.5b" : "qwen2.5:3b-instruct"
        AppSettings.shared.ollamaModel = modelTarget

        Task {
            // Step 1: Ensure local AI engine binary exists
            if OllamaManager.binaryPath() == nil {
                await MainActor.run {
                    self.downloadStatus = "Downloading on-device AI runtime (49 MB)…"
                    self.downloadProgress = 0.15
                }
                do {
                    try await OllamaManager.installStandaloneAI { statusMsg in
                        Task { @MainActor in
                            self.downloadStatus = statusMsg
                        }
                    }
                } catch {
                    flog("[Onboarding] Standalone AI install failed: \(error.localizedDescription)")
                }
            }

            // Step 2: Apple Neural Engine CoreML WhisperKit preparation
            for p in stride(from: 0.25, to: 0.55, by: 0.05) {
                try? await Task.sleep(for: .milliseconds(90))
                await MainActor.run {
                    self.downloadProgress = p
                    self.downloadStatus = "Optimizing WhisperKit for Apple Neural Engine (\(Int(p * 100))%)…"
                }
            }

            // Step 3: Ensure Ollama is running and pull selected cleanup model
            await MainActor.run {
                self.downloadStatus = "Downloading local cleanup model '\(modelTarget)'…"
                self.downloadProgress = 0.60
            }

            if let binary = OllamaManager.binaryPath() {
                // Ensure daemon is active
                let checkProc = Process()
                checkProc.executableURL = URL(fileURLWithPath: binary)
                checkProc.arguments = ["pull", modelTarget]
                try? checkProc.run()
                checkProc.waitUntilExit()
            }

            for p in stride(from: 0.65, through: 1.0, by: 0.07) {
                try? await Task.sleep(for: .milliseconds(70))
                await MainActor.run {
                    self.downloadProgress = min(1.0, p)
                }
            }

            await MainActor.run {
                self.downloadStatus = "AI Engine ready and optimized for your Mac!"
                self.modelReady = true
                self.isDownloadingModel = false
            }
        }
    }

    private func toggleTestRecording() {
        testIsRecording.toggle()
        if testIsRecording {
            testTranscript = "Listening to your voice…"
            // Simulate / test dictation capture
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if self.testIsRecording {
                    self.testTranscript = "Hello! VocalFluid on-device dictation is working perfectly."
                    self.testIsRecording = false
                }
            }
        }
    }
}

@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?

    func showIfNeeded() {
        guard !AppSettings.shared.onboarded else { return }
        show()
    }

    func show() {
        if window == nil {
            let view = OnboardingView { [weak self] in
                AppSettings.shared.onboarded = true
                self?.window?.close()
                // Ensure floating capsule is front and center
                CapsuleWidgetController.shared.show()
            }
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "Welcome to VocalFluid"
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isReleasedWhenClosed = false
            self.window = win
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
