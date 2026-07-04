import AppKit
import SwiftUI

/// Observable bridge between SwiftUI and the UserDefaults-backed Settings.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var modelName: String { didSet { AppSettings.shared.modelName = modelName } }
    @Published var ollamaEndpoint: String { didSet { AppSettings.shared.ollamaEndpoint = ollamaEndpoint } }
    @Published var ollamaModel: String { didSet { AppSettings.shared.ollamaModel = ollamaModel } }
    @Published var intensity: CleanupIntensity { didSet { AppSettings.shared.cleanupIntensity = intensity } }
    @Published var vocabulary: [VocabularyEntry] { didSet { AppSettings.shared.vocabulary = vocabulary } }
    @Published var casualApps: String {
        didSet {
            AppSettings.shared.casualApps = casualApps
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
    }
    @Published var keepHistory: Bool { didSet { AppSettings.shared.keepHistory = keepHistory } }

    /// Restart-required marker: STT model changes need a model reload.
    @Published var modelChangePending = false

    init() {
        let settings = AppSettings.shared
        modelName = settings.modelName
        ollamaEndpoint = settings.ollamaEndpoint
        ollamaModel = settings.ollamaModel
        intensity = settings.cleanupIntensity
        vocabulary = settings.vocabulary
        casualApps = settings.casualApps.joined(separator: ", ")
        keepHistory = settings.keepHistory
    }

    static let sttModels = [
        "large-v3-v20240930_turbo_632MB",
        "large-v3-v20240930_626MB",
        "distil-whisper_distil-large-v3_turbo_600MB",
        "small.en",
        "small",
        "base.en",
        "base",
        "tiny.en",
        "tiny",
    ]

    static let ollamaModels = [
        "qwen2.5:3b-instruct",
        "llama3.1:8b",
        "gemma2:2b",
        "phi3",
    ]
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    var onModelChanged: () -> Void

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            vocabularyTab.tabItem { Label("Vocabulary", systemImage: "character.book.closed") }
            appsTab.tabItem { Label("Apps", systemImage: "macwindow") }
        }
        .frame(width: 480, height: 360)
        .padding()
    }

    private var generalTab: some View {
        Form {
            Picker("Speech model", selection: $model.modelName) {
                ForEach(SettingsModel.sttModels, id: \.self) { Text($0) }
            }
            .onChange(of: model.modelName) { onModelChanged() }

            Divider()

            TextField("Ollama endpoint", text: $model.ollamaEndpoint)
            Picker("Cleanup model", selection: $model.ollamaModel) {
                ForEach(SettingsModel.ollamaModels, id: \.self) { Text($0) }
            }
            Picker("Cleanup intensity", selection: $model.intensity) {
                ForEach(CleanupIntensity.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)

            Divider()

            Toggle("Keep local transcript history (text only, never audio)", isOn: $model.keepHistory)

            Text("Hotkeys: hold Right ⌥ to dictate (push-to-talk) · ⌃⌥D toggles")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var vocabularyTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terms bias speech recognition. Add a replacement to auto-correct spelling (one rule per term).")
                .font(.footnote)
                .foregroundStyle(.secondary)

            List {
                ForEach($model.vocabulary) { $entry in
                    HStack {
                        TextField("Term (e.g. WhisperKit)", text: $entry.term)
                        Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                        TextField("Replacement (optional)", text: $entry.replacement)
                        Button(role: .destructive) {
                            model.vocabulary.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Button {
                model.vocabulary.append(VocabularyEntry(term: ""))
            } label: {
                Label("Add term", systemImage: "plus")
            }
        }
        .padding()
    }

    private var appsTab: some View {
        Form {
            Text("Casual apps — the trailing period is dropped when dictating into these:")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Comma-separated app names", text: $model.casualApps)
            Text("Match by app name as shown in the menu bar (e.g. Messages, Slack).")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

/// Hosts the SwiftUI settings view in a regular window.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let model = SettingsModel()
    var onModelChanged: (() -> Void)?

    func show() {
        if window == nil {
            let view = SettingsView(model: model) { [weak self] in self?.onModelChanged?() }
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "FlowLocal Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
