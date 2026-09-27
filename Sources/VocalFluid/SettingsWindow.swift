import AppKit
import SwiftUI

/// Observable bridge between SwiftUI and the UserDefaults-backed Settings.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var modelName: String { didSet { AppSettings.shared.modelName = modelName } }
    @Published var language: String { didSet { AppSettings.shared.language = language } }
    @Published var highlightTransform: Bool { didSet { AppSettings.shared.highlightTransform = highlightTransform } }
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

    @Published var modelChangePending = false

    init() {
        let settings = AppSettings.shared
        modelName = settings.modelName
        language = settings.language
        highlightTransform = settings.highlightTransform
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
        "qwen2.5:0.5b",
        "qwen2.5:1.5b",
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
        .frame(width: 500, height: 400)
        .padding()
    }

    private var generalTab: some View {
        Form {
            Picker("Spoken Language", selection: $model.language) {
                ForEach(AppSettings.supportedLanguages) { lang in
                    Text("\(lang.flag) \(lang.name)").tag(lang.id)
                }
            }

            Picker("Speech Model", selection: $model.modelName) {
                ForEach(SettingsModel.sttModels, id: \.self) { Text($0) }
            }
            .onChange(of: model.modelName) { onModelChanged() }

            Divider()

            Toggle("Highlight & Voice Transform (Rewrite in-place)", isOn: $model.highlightTransform)
                .help("Select text anywhere on screen, hold Fn, and speak instructions to rewrite it.")

            Divider()

            Picker("AI Cleanup Model", selection: $model.ollamaModel) {
                ForEach(SettingsModel.ollamaModels, id: \.self) { Text($0) }
            }

            Picker("Cleanup Intensity", selection: $model.intensity) {
                ForEach(CleanupIntensity.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)

            TextField("Ollama Endpoint", text: $model.ollamaEndpoint)

            Divider()

            Toggle("Keep local transcript history (never audio)", isOn: $model.keepHistory)

            Text("Hold Fn (🌐) or Right ⌥ to speak · Double-tap Fn to toggle hands-free · Hold Shift on release for raw text")
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

            HStack {
                Button("+ Add Term") {
                    model.vocabulary.append(VocabularyEntry(term: "", replacement: ""))
                }
                Spacer()
            }
        }
        .padding()
    }

    private var appsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Casual Apps")
                .font(.headline)
            Text("Dictation into these apps drops the trailing period for a conversational feel:")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Messages, Slack, WhatsApp, Discord", text: $model.casualApps)
                .textFieldStyle(.roundedBorder)
            Spacer()
        }
        .padding()
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let model = SettingsModel()
    var onModelChanged: (() -> Void)?

    func show() {
        if window == nil {
            let view = SettingsView(model: model) { [weak self] in
                self?.onModelChanged?()
            }
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "VocalFluid Settings"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            self.window = win
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
