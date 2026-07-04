import Foundation

/// Manages the lifecycle of the local Ollama server so the user never has to
/// start it by hand. FlowLocal launches `ollama serve` on startup if it isn't
/// already running, and shuts it down on quit — but ONLY if FlowLocal was the
/// one that started it. If Ollama was already running (the user's own server
/// or the Ollama menu-bar app), FlowLocal leaves it completely alone.
final class OllamaManager {
    private var process: Process?
    private(set) var startedByUs = false

    /// Common install locations for the `ollama` CLI.
    private static let binaryCandidates = [
        "/usr/local/bin/ollama",
        "/opt/homebrew/bin/ollama",
        "/Applications/Ollama.app/Contents/Resources/ollama",
    ]

    static func binaryPath() -> String? {
        binaryCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Ensures a reachable Ollama server, starting one if needed.
    /// Returns once the server responds (or after a ~10s timeout).
    func ensureRunning(endpoint: String) async {
        if await isReachable(endpoint) {
            flog("[ollama] already running — leaving it as-is")
            return
        }
        guard let binary = Self.binaryPath() else {
            flog("[ollama] CLI not found in known locations — cleanup will be unavailable")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = ["serve"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            process = proc
            startedByUs = true
            flog("[ollama] started '\(binary) serve' (pid \(proc.processIdentifier))")
        } catch {
            flog("[ollama] failed to start: \(error.localizedDescription)")
            return
        }

        // Wait for the server to accept connections.
        for _ in 0..<20 {
            if await isReachable(endpoint) {
                flog("[ollama] server is up")
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        flog("[ollama] server did not become reachable within timeout")
    }

    /// Stops the server, but only if FlowLocal started it. Called on quit.
    func shutdownIfStarted() {
        guard startedByUs, let process, process.isRunning else { return }
        process.terminate() // SIGTERM to `ollama serve`, which stops its runners too
        self.process = nil
        startedByUs = false
        flog("[ollama] stopped (it was started by FlowLocal)")
    }

    private func isReachable(_ endpoint: String) async -> Bool {
        guard let url = URL(string: "\(endpoint)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: request)) != nil
    }
}
