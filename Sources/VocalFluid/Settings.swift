import Foundation

public struct LanguageOption: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let flag: String

    public init(id: String, name: String, flag: String) {
        self.id = id
        self.name = name
        self.flag = flag
    }
}

/// User-configurable settings, persisted in UserDefaults.
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let modelName = "modelName"
        static let ollamaEndpoint = "ollamaEndpoint"
        static let ollamaModel = "ollamaModel"
        static let cleanupIntensity = "cleanupIntensity"
        static let language = "language"
        static let vocabulary = "vocabulary"
        static let casualApps = "casualApps"
        static let keepHistory = "keepHistory"
        static let onboarded = "onboarded"
        static let highlightTransform = "highlightTransform"
    }

    /// Supported dictation languages
    static let supportedLanguages: [LanguageOption] = [
        LanguageOption(id: "en", name: "English", flag: "🇺🇸"),
        LanguageOption(id: "auto", name: "Auto-Detect", flag: "🌐"),
        LanguageOption(id: "es", name: "Spanish", flag: "🇪🇸"),
        LanguageOption(id: "fr", name: "French", flag: "🇫🇷"),
        LanguageOption(id: "de", name: "German", flag: "🇩🇪"),
        LanguageOption(id: "it", name: "Italian", flag: "🇮🇹"),
        LanguageOption(id: "pt", name: "Portuguese", flag: "🇵🇹"),
        LanguageOption(id: "hi", name: "Hindi", flag: "🇮🇳"),
        LanguageOption(id: "ja", name: "Japanese", flag: "🇯🇵"),
        LanguageOption(id: "zh", name: "Chinese", flag: "🇨🇳"),
        LanguageOption(id: "ru", name: "Russian", flag: "🇷🇺"),
        LanguageOption(id: "ar", name: "Arabic", flag: "🇸🇦"),
        LanguageOption(id: "ko", name: "Korean", flag: "🇰🇷"),
    ]

    /// Target language for transcription (e.g. "en", "auto", "es"). Default: "en" for maximum accuracy.
    var language: String {
        get { defaults.string(forKey: Key.language) ?? "en" }
        set { defaults.set(newValue, forKey: Key.language) }
    }

    /// In-memory override from CLI flag; not persisted.
    var modelNameOverride: String?

    /// WhisperKit model variant. Default: large-v3 turbo (632MB), fast & accurate on Neural Engine.
    var modelName: String {
        get { modelNameOverride ?? defaults.string(forKey: Key.modelName) ?? "large-v3-v20240930_turbo_632MB" }
        set { defaults.set(newValue, forKey: Key.modelName) }
    }

    /// Local Ollama server.
    var ollamaEndpoint: String {
        get { defaults.string(forKey: Key.ollamaEndpoint) ?? "http://localhost:11434" }
        set { defaults.set(newValue, forKey: Key.ollamaEndpoint) }
    }

    /// Ollama model for the cleanup pass. Default is lightweight qwen2.5:0.5b (under 400MB RAM).
    var ollamaModel: String {
        get { defaults.string(forKey: Key.ollamaModel) ?? "qwen2.5:0.5b" }
        set { defaults.set(newValue, forKey: Key.ollamaModel) }
    }

    /// Cleanup intensity for the LLM pass.
    var cleanupIntensity: CleanupIntensity {
        get {
            defaults.string(forKey: Key.cleanupIntensity)
                .flatMap(CleanupIntensity.init(rawValue:)) ?? .light
        }
        set { defaults.set(newValue.rawValue, forKey: Key.cleanupIntensity) }
    }

    /// Enable Highlight & Voice Transform (rewriting selected text)
    var highlightTransform: Bool {
        get { defaults.object(forKey: Key.highlightTransform) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.highlightTransform) }
    }

    /// Custom vocabulary: terms bias WhisperKit recognition.
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

    /// Keep a local transcript history.
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
