import Foundation

/// The app's high-level state, reflected in the menu-bar icon.
enum AppState: Equatable {
    case loading        // model downloading / loading
    case idle           // ready, waiting for hotkey
    case listening      // mic open, streaming partials
    case transcribing   // hotkey released, final STT pass
    case cleaning       // Ollama cleanup pass running
    case error(String)  // something went wrong (message shown in menu)

    var menuBarSymbol: String {
        switch self {
        case .loading:      return "hourglass"
        case .idle:         return "mic"
        case .listening:    return "mic.fill"
        case .transcribing: return "waveform"
        case .cleaning:     return "wand.and.stars"
        case .error:        return "exclamationmark.triangle.fill"
        }
    }

    var label: String {
        switch self {
        case .loading:            return "Loading model…"
        case .idle:               return "Idle — hold Right ⌥ to dictate"
        case .listening:          return "Listening…"
        case .transcribing:       return "Transcribing…"
        case .cleaning:           return "Cleaning up…"
        case .error(let message): return "Error: \(message)"
        }
    }
}
