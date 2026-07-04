import Foundation

/// User-configurable settings, persisted in UserDefaults.
/// (A SwiftUI Settings window arrives in milestone 4; for now these are
/// readable/writable via `defaults write com.flowlocal.app <key>`.)
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let modelName = "modelName"
        static let ollamaEndpoint = "ollamaEndpoint"
        static let ollamaModel = "ollamaModel"
        static let cleanupIntensity = "cleanupIntensity"
        static let vocabulary = "vocabulary"
        static let casualApps = "casualApps"
        static let keepHistory = "keepHistory"
        static let onboarded = "onboarded"
    }

    /// In-memory override from the --model CLI flag; not persisted.
    var modelNameOverride: String?

    /// WhisperKit model variant. Default: quantized large-v3 turbo (632MB),
    /// the best latency/accuracy tradeoff on Apple Silicon (runs on ANE/GPU).
    var modelName: String {
        get { modelNameOverride ?? defaults.string(forKey: Key.modelName) ?? "large-v3-v20240930_turbo_632MB" }
        set { defaults.set(newValue, forKey: Key.modelName) }
    }

    /// Local Ollama server. localhost only — the app makes no other network calls.
    var ollamaEndpoint: String {
        get { defaults.string(forKey: Key.ollamaEndpoint) ?? "http://localhost:11434" }
        set { defaults.set(newValue, forKey: Key.ollamaEndpoint) }
    }

    /// Ollama model for the cleanup pass (also good: llama3.1:8b, gemma2:2b, phi3).
    var ollamaModel: String {
        get { defaults.string(forKey: Key.ollamaModel) ?? "qwen2.5:3b-instruct" }
        set { defaults.set(newValue, forKey: Key.ollamaModel) }
    }

    /// Cleanup intensity for the LLM pass.
    var cleanupIntensity: CleanupIntensity {
        get {
            defaults.string(forKey: Key.cleanupIntensity)
                .flatMap(CleanupIntensity.init(rawValue:)) ?? .medium
        }
        set { defaults.set(newValue.rawValue, forKey: Key.cleanupIntensity) }
    }

    /// Custom vocabulary: terms bias WhisperKit recognition; entries with a
    /// replacement are also applied as find-replace after the LLM pass.
    var vocabulary: [VocabularyEntry] {
        get {
            guard let data = defaults.data(forKey: Key.vocabulary),
                  let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else {
                return []
            }
            return entries
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.vocabulary)
            }
        }
    }

    /// Apps where dictation drops the trailing period for a casual feel.
    var casualApps: [String] {
        get { defaults.stringArray(forKey: Key.casualApps) ?? ["Messages", "Slack", "WhatsApp", "Discord"] }
        set { defaults.set(newValue, forKey: Key.casualApps) }
    }

    /// Keep a local transcript history (never audio). Off by default.
    var keepHistory: Bool {
        get { defaults.bool(forKey: Key.keepHistory) }
        set { defaults.set(newValue, forKey: Key.keepHistory) }
    }

    /// First-run onboarding completed.
    var onboarded: Bool {
        get { defaults.bool(forKey: Key.onboarded) }
        set { defaults.set(newValue, forKey: Key.onboarded) }
    }
}
