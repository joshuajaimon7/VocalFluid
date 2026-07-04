import Foundation

/// Deterministic post-processing that runs AFTER the LLM cleanup pass:
/// voice commands, custom-vocabulary replacement rules, and per-app formatting.
enum TranscriptProcessor {

    /// The action the app should take for a dictation result.
    enum Action: Equatable {
        case insert(String)     // insert this text at the cursor
        case scratchLast        // delete the last inserted chunk
        case nothing            // empty dictation
    }

    /// Interprets voice commands and applies replacements/formatting.
    /// - Parameters:
    ///   - text: cleaned transcript
    ///   - vocabulary: user's replacement rules (applied after the LLM pass)
    ///   - frontmostApp: localized app name, for per-app formatting rules
    static func process(_ text: String, vocabulary: [VocabularyEntry], frontmostApp: String?) -> Action {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return .nothing }

        // 1. Whole-utterance commands: "scratch that" / "delete that".
        let bare = result.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        if bare == "scratch that" || bare == "delete that" {
            return .scratchLast
        }

        // 2. Inline commands: "new line" / "new paragraph" become literal breaks.
        result = replaceInlineCommand(in: result, command: "new paragraph", with: "\n\n")
        result = replaceInlineCommand(in: result, command: "new line", with: "\n")

        // 3. Custom vocabulary replacement rules (one rule per term).
        for entry in vocabulary where !entry.replacement.isEmpty {
            result = result.replacingOccurrences(
                of: entry.term,
                with: entry.replacement,
                options: [.caseInsensitive]
            )
        }

        // 4. Per-app formatting: drop the trailing period in messaging apps.
        if let app = frontmostApp, AppSettings.shared.casualApps.contains(where: { $0.caseInsensitiveCompare(app) == .orderedSame }) {
            result = strippingTrailingPeriod(result)
        }

        return result.isEmpty ? .nothing : .insert(result)
    }

    /// Replaces a spoken command with literal text, tolerating surrounding
    /// punctuation/capitalization the STT or LLM may have added
    /// (e.g. "… stock. New line. Buy milk" → "… stock.\nBuy milk").
    private static func replaceInlineCommand(in text: String, command: String, with replacement: String) -> String {
        // Consume a preceding comma (", new line,") but keep sentence-ending
        // punctuation ("milk. New line" → "milk.\n"), plus trailing punctuation.
        let pattern = ",?\\s*\\b\(command)\\b[,.!?]*\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private static func strippingTrailingPeriod(_ text: String) -> String {
        // Only a single sentence-final period — don't touch "..." or "?!".
        guard text.hasSuffix("."), !text.hasSuffix("..") else { return text }
        return String(text.dropLast())
    }
}

/// One custom-vocabulary entry: the term biases transcription, and the
/// optional replacement rule corrects spelling after the LLM pass.
struct VocabularyEntry: Codable, Equatable, Identifiable {
    var id = UUID()
    var term: String
    var replacement: String = "" // empty → bias-only, no replacement
}
