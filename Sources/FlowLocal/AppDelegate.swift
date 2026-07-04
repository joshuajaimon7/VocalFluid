import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeys = HotkeyManager()
    private let transcriber = Transcriber()
    private let inserter = TextInserter()
    private let cleaner = Cleaner()
    private let hud = TranscriptHUD()
    private let settingsWindow = SettingsWindowController()
    private let onboarding = OnboardingWindowController()

    private var state: AppState = .loading {
        didSet { updateStatusItem() }
    }
    private var lastTranscript = ""
    private var dictating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        onboarding.showIfNeeded()

        // Permissions: Accessibility is required for the global hotkey tap.
        // If missing, poll until granted and (re)install the tap automatically.
        if HotkeyManager.ensurePermissions() {
            if !hotkeys.start() {
                state = .error("Hotkey tap failed — grant Accessibility permission and relaunch")
            }
        } else {
            flog("[FlowLocal] Accessibility permission missing — waiting for grant…")
            pollForAccessibilityGrant()
        }

        wireHotkeys()
        wireTranscriber()
        settingsWindow.onModelChanged = { [weak self] in self?.reloadModel() }

        loadModelAndCheckOllama()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.stop()
    }

    // MARK: - Startup / model lifecycle

    private func loadModelAndCheckOllama() {
        state = .loading
        Task {
            do {
                try await transcriber.loadModel()
                state = .idle
            } catch {
                state = .error("Model load failed: \(error.localizedDescription)")
                return
            }
            // Non-fatal: dictation works without cleanup (raw transcript is inserted).
            if AppSettings.shared.cleanupIntensity != .none {
                do {
                    try await cleaner.healthCheck()
                    flog("[FlowLocal] Ollama reachable, model '\(AppSettings.shared.ollamaModel)' available.")
                } catch {
                    flog("[FlowLocal] Cleanup unavailable: \(error.localizedDescription)")
                    state = .error(error.localizedDescription)
                }
            }
        }
    }

    private func reloadModel() {
        guard !dictating else { return }
        loadModelAndCheckOllama()
    }

    /// Waits for the user to grant Accessibility, then installs the hotkey tap
    /// — taps created before the grant never receive keyboard events.
    private func pollForAccessibilityGrant() {
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            Task { @MainActor in
                guard let self else { return }
                self.hotkeys.stop()
                if self.hotkeys.start() {
                    flog("[FlowLocal] Accessibility granted — hotkey tap installed.")
                } else {
                    self.state = .error("Hotkey tap failed after permission grant — relaunch FlowLocal")
                }
            }
        }
    }

    // MARK: - Wiring

    private func wireHotkeys() {
        hotkeys.onPushToTalkDown = { [weak self] in self?.startDictation() }
        hotkeys.onPushToTalkUp = { [weak self] in self?.stopDictation() }
        hotkeys.onToggle = { [weak self] in
            guard let self else { return }
            self.dictating ? self.stopDictation() : self.startDictation()
        }
    }

    private func wireTranscriber() {
        transcriber.onPartial = { [weak self] partial in
            Task { @MainActor in
                flog("[partial] \(partial)")
                self?.hud.update(text: partial)
            }
        }
        transcriber.onFinal = { [weak self] text in
            Task { @MainActor in
                guard let self else { return }
                self.hud.hide()
                guard !text.isEmpty else {
                    self.state = .idle
                    return
                }
                flog(">>> \(text)")
                await self.handleFinalTranscript(text)
            }
        }
    }

    // MARK: - Dictation pipeline: transcript → LLM cleanup → commands/vocab/app rules → insert

    private func handleFinalTranscript(_ text: String) async {
        // 1. LLM cleanup pass (bypassed when intensity is None or Ollama is down).
        let intensity = AppSettings.shared.cleanupIntensity
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName
        var cleaned = text
        var cleanupError: String?

        // Whole-utterance commands skip the LLM (never rewrite "scratch that").
        let isCommand = TranscriptProcessor.process(text, vocabulary: [], frontmostApp: nil) == .scratchLast

        if intensity != .none && !isCommand {
            state = .cleaning
            do {
                cleaned = try await cleaner.clean(text, intensity: intensity, appContext: frontmostApp)
                flog("[cleaned] \(cleaned)")
            } catch {
                // Insert the raw transcript rather than dropping the dictation.
                flog("[cleanup failed] \(error.localizedDescription)")
                cleanupError = error.localizedDescription
            }
        }

        // 2. Deterministic pass: voice commands, vocabulary rules, app formatting.
        let action = TranscriptProcessor.process(
            cleaned,
            vocabulary: AppSettings.shared.vocabulary,
            frontmostApp: frontmostApp
        )

        switch action {
        case .scratchLast:
            inserter.scratchLast()
            flog("[insert] scratched last dictation")
        case .insert(let finalText):
            lastTranscript = finalText
            appendHistory(finalText)
            let method = inserter.insert(finalText)
            flog("[insert] via \(method)")
        case .nothing:
            break
        }

        state = cleanupError.map { .error($0) } ?? .idle
        rebuildMenu()
    }

    /// Local transcript history (text only, never audio). Off by default.
    private func appendHistory(_ text: String) {
        guard AppSettings.shared.keepHistory else { return }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FlowLocal", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("history.txt")
        let line = "\(ISO8601DateFormatter().string(from: Date()))\t\(text)\n"
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            try? handle.close()
        } else {
            try? line.data(using: .utf8)!.write(to: file)
        }
    }

    // MARK: - Dictation control

    private func startDictation() {
        guard case .idle = state, !dictating else { return }
        dictating = true
        state = .listening
        flog("[dictation] start")
        hud.show()
        Task {
            do {
                try await transcriber.startDictation()
            } catch {
                await MainActor.run {
                    self.dictating = false
                    self.hud.hide()
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    private func stopDictation() {
        guard dictating else { return }
        dictating = false
        state = .transcribing
        flog("[dictation] stop — transcribing")
        Task { await transcriber.stopDictation() }
    }

    // MARK: - Menu bar UI

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusItem()
    }

    private func updateStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: state.menuBarSymbol,
                accessibilityDescription: "FlowLocal — \(state.label)"
            )
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let stateItem = NSMenuItem(title: state.label, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        if !lastTranscript.isEmpty {
            let preview = lastTranscript.count > 60
                ? String(lastTranscript.prefix(60)) + "…"
                : lastTranscript
            let lastItem = NSMenuItem(title: "Last: \(preview)", action: nil, keyEquivalent: "")
            lastItem.isEnabled = false
            menu.addItem(lastItem)
        }

        menu.addItem(.separator())

        let pttInfo = NSMenuItem(title: "Push-to-talk: hold Right ⌥", action: nil, keyEquivalent: "")
        pttInfo.isEnabled = false
        menu.addItem(pttInfo)

        let toggleItem = NSMenuItem(
            title: dictating ? "Stop Dictation (⌃⌥D)" : "Start Dictation (⌃⌥D)",
            action: #selector(toggleDictationFromMenu),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem(title: "Quit FlowLocal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleDictationFromMenu() {
        dictating ? stopDictation() : startDictation()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }
}
