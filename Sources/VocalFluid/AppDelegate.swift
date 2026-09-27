import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeys = HotkeyManager()
    private let transcriber = Transcriber()
    private let inserter = TextInserter()
    private let cleaner = Cleaner()
    private let ollama = OllamaManager()
    private let settingsWindow = SettingsWindowController()
    private let onboarding = OnboardingWindowController()

    private var state: AppState = .loading {
        didSet { updateStatusItem() }
    }
    private var lastTranscript = ""
    private var dictating = false
    private var dictationStartTime: Date?
    private var activeHighlight: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        onboarding.showIfNeeded()

        // Show the Wispr Flow-style Dashboard Window
        DashboardWindowController.shared.show()

        // Show the Wispr Flow-style Floating Capsule Widget at screen bottom
        CapsuleWidgetController.shared.show()
        CapsuleWidgetController.shared.onToggleDictation = { [weak self] in
            self?.toggleDictationFromMenu()
        }
        CapsuleWidgetController.shared.onOpenDashboard = { [weak self] in
            self?.openDashboard()
        }

        wireHotkeys()
        wireTranscriber()

        // Permissions: Accessibility is required for the global hotkey tap and text insertion.
        if HotkeyManager.ensurePermissions() {
            hotkeys.start()
            flog("[VocalFluid] Accessibility permission active at launch.")
        } else {
            flog("[VocalFluid] Accessibility permission missing — waiting for grant…")
            hotkeys.start() // starts global monitor fallback
            pollForAccessibilityGrant()
        }
        settingsWindow.onModelChanged = { [weak self] in self?.reloadModel() }

        loadModelAndCheckOllama()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.stop()
        ollama.shutdownIfStarted()
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
                // Start Ollama automatically if it isn't already running.
                await ollama.ensureRunning(endpoint: AppSettings.shared.ollamaEndpoint)
                do {
                    try await cleaner.healthCheck()
                    flog("[VocalFluid] Ollama reachable, model '\(AppSettings.shared.ollamaModel)' available.")
                } catch {
                    flog("[VocalFluid] Cleanup unavailable: \(error.localizedDescription)")
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
    private var pollCount = 0
    private func pollForAccessibilityGrant() {
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.pollCount += 1
            let trusted = AXIsProcessTrusted()
            if trusted {
                timer.invalidate()
                Task { @MainActor in
                    self.hotkeys.stop()
                    if self.hotkeys.start() {
                        flog("[VocalFluid] Accessibility granted — hotkey tap installed successfully.")
                        self.rebuildMenu()
                    } else {
                        self.state = .error("Hotkey tap failed after permission grant — relaunch VocalFluid")
                    }
                }
            } else if self.pollCount % 6 == 0 {
                flog("[VocalFluid] Waiting for Accessibility in System Settings -> Privacy & Security -> Accessibility…")
            }
        }
    }

    // MARK: - Wiring

    private var bypassCleanupNext = false

    private func wireHotkeys() {
        hotkeys.onPushToTalkDown = { [weak self] in self?.startDictation() }
        hotkeys.onPushToTalkUp = { [weak self] bypass in self?.stopDictation(bypassCleanup: bypass) }
        hotkeys.onToggle = { [weak self] in
            guard let self else { return }
            self.dictating ? self.stopDictation(bypassCleanup: false) : self.startDictation()
        }
    }

    private func wireTranscriber() {
        transcriber.onPartial = { [weak self] partial in
            Task { @MainActor in
                flog("[partial] \(partial)")
                CapsuleWidgetController.shared.setDictating(true, partialText: partial)
            }
        }
        transcriber.onFinal = { [weak self] text in
            Task { @MainActor in
                guard let self else { return }
                guard !text.isEmpty else {
                    CapsuleWidgetController.shared.setDictating(false)
                    self.state = .idle
                    return
                }
                flog(">>> \(text)")
                await self.handleFinalTranscript(text)
                CapsuleWidgetController.shared.setDictating(false)
            }
        }
    }

    // MARK: - Dictation pipeline: transcript → LLM cleanup → commands/vocab/app rules → insert

    private func handleFinalTranscript(_ text: String) async {
        let bypass = bypassCleanupNext
        bypassCleanupNext = false

        // 1. LLM cleanup pass (bypassed when intensity is None, bypass is held, or Ollama is down).
        let intensity = bypass ? CleanupIntensity.none : AppSettings.shared.cleanupIntensity
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName
        var cleaned = text
        var cleanupError: String?

        // Whole-utterance commands skip the LLM (never rewrite "scratch that").
        let isCommand = TranscriptProcessor.process(text, vocabulary: [], frontmostApp: nil) == .scratchLast

        // Highlight & Transform takes precedence if the user had text selected
        if let highlight = activeHighlight, !highlight.isEmpty, !isCommand {
            state = .cleaning
            do {
                cleaned = try await cleaner.transform(originalText: highlight, instruction: text, appContext: frontmostApp)
                flog("[transformed] '\(highlight.prefix(30))…' -> '\(cleaned.prefix(30))…'")
            } catch {
                flog("[transform failed] \(error.localizedDescription) — using standard insertion")
            }
            activeHighlight = nil
        } else if intensity != .none && !isCommand {
            state = .cleaning
            do {
                cleaned = try await cleaner.clean(text, intensity: intensity, appContext: frontmostApp)
                flog("[cleaned] \(cleaned)")
            } catch {
                // Insert the raw transcript rather than dropping the dictation.
                flog("[cleanup failed] \(error.localizedDescription)")
                cleanupError = error.localizedDescription
            }
        } else if bypass {
            flog("[cleaner] bypassed via Shift release modifier (raw transcript used)")
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
            let duration = dictationStartTime.map { Date().timeIntervalSince($0) } ?? 2.0
            HistoryStore.shared.add(
                text: finalText,
                rawText: text,
                appName: frontmostApp ?? "Desktop",
                duration: duration
            )
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
            .appendingPathComponent("VocalFluid", isDirectory: true)
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
        dictationStartTime = Date()
        inserter.recordTargetApp()
        activeHighlight = inserter.captureSelectedText()
        if let highlight = activeHighlight {
            flog("[transform] active highlighted text: '\(highlight.prefix(30))…'")
            CapsuleWidgetController.shared.setDictating(true, partialText: "Transforming…")
        } else {
            CapsuleWidgetController.shared.setDictating(true, partialText: "Listening…")
        }
        state = .listening
        flog("[dictation] start")
        Task {
            do {
                try await transcriber.startDictation()
            } catch {
                await MainActor.run {
                    self.dictating = false
                    CapsuleWidgetController.shared.setDictating(false)
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    private func stopDictation(bypassCleanup: Bool = false) {
        guard dictating else { return }
        dictating = false
        hotkeys.isHandsFree = false
        bypassCleanupNext = bypassCleanup
        state = .transcribing
        flog("[dictation] stop — transcribing (bypass=\(bypassCleanup))")
        CapsuleWidgetController.shared.setDictating(true, partialText: "Pasting…")
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
                accessibilityDescription: "VocalFluid — \(state.label)"
            )
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let dashboardItem = NSMenuItem(
            title: "Open VocalFluid Dashboard…",
            action: #selector(openDashboard),
            keyEquivalent: "d"
        )
        dashboardItem.keyEquivalentModifierMask = [.command]
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        menu.addItem(.separator())

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

        let pttInfo = NSMenuItem(title: "Push-to-talk: Hold Fn (🌐) or Right ⌥", action: nil, keyEquivalent: "")
        pttInfo.isEnabled = false
        menu.addItem(pttInfo)

        let toggleInfo = NSMenuItem(title: "Toggle: Double-tap Fn or ⌃⌥Space", action: nil, keyEquivalent: "")
        toggleInfo.isEnabled = false
        menu.addItem(toggleInfo)

        let toggleItem = NSMenuItem(
            title: dictating ? "Stop Dictation" : "Start Dictation",
            action: #selector(toggleDictationFromMenu),
            keyEquivalent: " "
        )
        toggleItem.keyEquivalentModifierMask = [.control, .option]
        toggleItem.target = self
        menu.addItem(toggleItem)

        let accessItem = NSMenuItem(
            title: AXIsProcessTrusted() ? "Accessibility: Active ✓" : "Grant Accessibility Permission…",
            action: #selector(checkAccessibility),
            keyEquivalent: ""
        )
        accessItem.target = self
        menu.addItem(accessItem)

        menu.addItem(.separator())

        // Voice Tone Submenu
        let toneMenu = NSMenu()
        for tone in ToneMode.allCases {
            let item = NSMenuItem(title: tone.rawValue, action: #selector(selectTone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tone
            item.state = (StyleManager.shared.currentTone == tone) ? .on : .off
            toneMenu.addItem(item)
        }
        let toneSubmenuItem = NSMenuItem(title: "Voice Tone (\(StyleManager.shared.currentTone.rawValue))", action: nil, keyEquivalent: "")
        toneSubmenuItem.submenu = toneMenu
        menu.addItem(toneSubmenuItem)

        // Cleanup Intensity Submenu
        let intensityMenu = NSMenu()
        for intensity in CleanupIntensity.allCases {
            let item = NSMenuItem(title: intensity.rawValue, action: #selector(selectIntensity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = intensity
            item.state = (AppSettings.shared.cleanupIntensity == intensity) ? .on : .off
            intensityMenu.addItem(item)
        }
        let intensitySubmenuItem = NSMenuItem(title: "Cleanup (\(AppSettings.shared.cleanupIntensity.rawValue))", action: nil, keyEquivalent: "")
        intensitySubmenuItem.submenu = intensityMenu
        menu.addItem(intensitySubmenuItem)

        // Language Submenu
        let langMenu = NSMenu()
        let currentLang = AppSettings.shared.language
        for lang in AppSettings.supportedLanguages {
            let item = NSMenuItem(title: "\(lang.flag) \(lang.name)", action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.id
            item.state = (currentLang == lang.id) ? .on : .off
            langMenu.addItem(item)
        }
        let currentLangName = AppSettings.supportedLanguages.first { $0.id == currentLang }?.name ?? "English"
        let langSubmenuItem = NSMenuItem(title: "Language (\(currentLangName))", action: nil, keyEquivalent: "")
        langSubmenuItem.submenu = langMenu
        menu.addItem(langSubmenuItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let setupItem = NSMenuItem(title: "First-Run Setup Wizard…", action: #selector(openOnboarding), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)

        menu.addItem(NSMenuItem(title: "Quit VocalFluid", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func openOnboarding() {
        onboarding.show()
    }

    @objc private func openDashboard() {
        DashboardWindowController.shared.show()
    }

    @objc private func selectTone(_ sender: NSMenuItem) {
        if let tone = sender.representedObject as? ToneMode {
            StyleManager.shared.currentTone = tone
            rebuildMenu()
        }
    }

    @objc private func selectIntensity(_ sender: NSMenuItem) {
        if let intensity = sender.representedObject as? CleanupIntensity {
            AppSettings.shared.cleanupIntensity = intensity
            rebuildMenu()
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        if let langId = sender.representedObject as? String {
            AppSettings.shared.language = langId
            flog("[VocalFluid] Language switched to: \(langId)")
            rebuildMenu()
        }
    }

    @objc private func toggleDictationFromMenu() {
        dictating ? stopDictation() : startDictation()
    }

    @objc private func checkAccessibility() {
        if !HotkeyManager.ensurePermissions() {
            HotkeyManager.openAccessibilitySettings()
        } else {
            hotkeys.stop()
            if hotkeys.start() {
                flog("[VocalFluid] Hotkey tap verified and active.")
            }
            rebuildMenu()
        }
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }
}
