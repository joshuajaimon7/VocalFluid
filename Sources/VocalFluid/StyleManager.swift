import Foundation

public enum ToneMode: String, CaseIterable, Codable, Identifiable {
    case neutral = "Neutral"
    case formal = "Formal"
    case casual = "Casual"
    case excited = "Excited"
    case developer = "Developer"

    public var id: String { rawValue }

    public var promptDirective: String {
        switch self {
        case .neutral:
            return "- Preserve natural tone, contractions, and direct phrasing."
        case .formal:
            return "- Use formal vocabulary and de-contract abbreviations (e.g. use 'do not' instead of 'don't', 'cannot' instead of 'can't')."
        case .casual:
            return "- Keep colloquial, relaxed, conversational phrasing. Contractions are encouraged."
        case .excited:
            return "- Convey high energy, upbeat cadence, and dynamic punctuation without inventing unnecessary fluff."
        case .developer:
            return "- Preserve technical jargon, code identifiers (camelCase, snake_case), CLI commands, and function names exactly. Minimize extraneous punctuation."
        }
    }
}

public struct AppToneRule: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var appName: String
    public var tone: ToneMode

    public init(id: UUID = UUID(), appName: String, tone: ToneMode) {
        self.id = id
        self.appName = appName
        self.tone = tone
    }
}

@MainActor
public final class StyleManager: ObservableObject {
    public static let shared = StyleManager()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let currentTone = "vocalfluid_toneMode"
        static let myStyleReference = "vocalfluid_myStyleReference"
        static let appToneRules = "vocalfluid_appToneRules"
    }

    @Published public var currentTone: ToneMode {
        didSet { defaults.set(currentTone.rawValue, forKey: Key.currentTone) }
    }

    @Published public var myStyleReference: String {
        didSet { defaults.set(myStyleReference, forKey: Key.myStyleReference) }
    }

    @Published public var appToneRules: [AppToneRule] {
        didSet {
            if let data = try? JSONEncoder().encode(appToneRules) {
                defaults.set(data, forKey: Key.appToneRules)
            }
        }
    }

    private init() {
        let savedTone = defaults.string(forKey: Key.currentTone)
            .flatMap(ToneMode.init(rawValue:)) ?? .neutral
        self.currentTone = savedTone

        self.myStyleReference = defaults.string(forKey: Key.myStyleReference) ?? ""

        if let data = defaults.data(forKey: Key.appToneRules),
           let rules = try? JSONDecoder().decode([AppToneRule].self, from: data) {
            self.appToneRules = rules
        } else {
            self.appToneRules = [
                AppToneRule(appName: "Xcode", tone: .developer),
                AppToneRule(appName: "Visual Studio Code", tone: .developer),
                AppToneRule(appName: "Terminal", tone: .developer),
                AppToneRule(appName: "Slack", tone: .casual),
                AppToneRule(appName: "Messages", tone: .casual),
                AppToneRule(appName: "Discord", tone: .casual),
                AppToneRule(appName: "Mail", tone: .formal)
            ]
        }
    }

    public func effectiveTone(for appName: String?) -> ToneMode {
        guard let appName, !appName.isEmpty else { return currentTone }
        if let match = appToneRules.first(where: { $0.appName.caseInsensitiveCompare(appName) == .orderedSame }) {
            return match.tone
        }
        return currentTone
    }

    public func promptSnippet(for appName: String?) -> String {
        let tone = effectiveTone(for: appName)
        var snippet = "\nTone requirement: \(tone.rawValue).\n\(tone.promptDirective)"

        let trimmedRef = myStyleReference.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRef.isEmpty {
            snippet += "\nAdopt the user's personal voice, vocabulary cadence, and writing style based on these samples of their writing:\n\"\"\"\n\(trimmedRef)\n\"\"\""
        }
        return snippet
    }
}
