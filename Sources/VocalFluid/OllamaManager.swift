import Foundation

/// Manages the lifecycle of the local Ollama server so the user never has to
/// start it by hand. VocalFluid supports:
/// 1. Pre-bundled internal binary (`VocalFluid.app/Contents/Resources/bin/ollama`)
/// 2. User-data binary (`~/Library/Application Support/VocalFluid/bin/ollama`)
/// 3. System-installed binaries (`/opt/homebrew/bin/ollama`, etc.)
final class OllamaManager {
    private var process: Process?
    private(set) var startedByUs = false

    /// Locations checked for the `ollama` CLI in order of preference.
    static var binaryCandidates: [String] {
        var candidates: [String] = []

        // 1. Embedded inside VocalFluid.app bundle
        if let embedded = Bundle.main.resourceURL?.appendingPathComponent("bin/ollama").path,
           FileManager.default.isExecutableFile(atPath: embedded) {
            candidates.append(embedded)
        }

        // 2. Downloaded into Application Support
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/VocalFluid/bin/ollama").path
        if FileManager.default.isExecutableFile(atPath: appSupport) {
            candidates.append(appSupport)
        }

        // 3. System / Homebrew installs
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/ollama",
            "/usr/local/bin/ollama",
            "/Applications/Ollama.app/Contents/Resources/ollama",
        ])

        return candidates
    }

    static func binaryPath() -> String? {
        binaryCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// True if an Ollama binary is available on this Mac
    static var isAvailable: Bool {
        binaryPath() != nil
    }

    /// Ensures a reachable Ollama server, starting one if needed.
    func ensureRunning(endpoint: String) async {
        if await isReachable(endpoint) {
            flog("[ollama] already running — leaving it as-is")
            return
        }
        guard let binary = Self.binaryPath() else {
            flog("[ollama] CLI not found — cleanups will use raw transcripts until AI engine is installed")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = ["serve"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        // Ensure Ollama stores models inside user's VocalFluid application support if embedded
        var env = ProcessInfo.processInfo.environment
        let modelsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/VocalFluid/models").path
        try? FileManager.default.createDirectory(atPath: modelsDir, withIntermediateDirectories: true)
        env["OLLAMA_MODELS"] = modelsDir
        proc.environment = env

        do {
            try proc.run()
            process = proc
            startedByUs = true
            flog("[ollama] started '\(binary) serve' (pid \(proc.processIdentifier))")
        } catch {
            flog("[ollama] failed to start: \(error.localizedDescription)")
            return
        }

        // Wait for the server to accept connections
        for _ in 0..<20 {
            if await isReachable(endpoint) {
                flog("[ollama] server is up")
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        flog("[ollama] server did not become reachable within timeout")
    }

    /// Stops the server, but only if VocalFluid started it.
    func shutdownIfStarted() {
        guard startedByUs, let process, process.isRunning else { return }
        process.terminate()
        self.process = nil
        startedByUs = false
        flog("[ollama] stopped (it was started by VocalFluid)")
    }

    private func isReachable(_ endpoint: String) async -> Bool {
        guard let url = URL(string: "\(endpoint)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: request)) != nil
    }

    // MARK: - 1-Click Background Downloader / Installer

    /// Downloads the official standalone arm64 Ollama binary into Application Support with zero terminal commands
    static func installStandaloneAI(onProgress: @escaping (String) -> Void) async throws {
        let destDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/VocalFluid/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let destBinary = destDir.appendingPathComponent("ollama")
        if FileManager.default.isExecutableFile(atPath: destBinary.path) {
            onProgress("AI Engine already installed.")
            return
        }

        onProgress("Downloading on-device AI Engine (49MB)…")
        let zipUrl = URL(string: "https://ollama.com/download/ollama-darwin.zip")!
        let (tempFile, _) = try await URLSession.shared.download(from: zipUrl)

        onProgress("Extracting AI Engine…")
        let unzipProc = Process()
        unzipProc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzipProc.arguments = ["-q", "-o", tempFile.path, "Ollama.app/Contents/Resources/ollama", "-d", "/tmp/vf_extract"]
        try unzipProc.run()
        unzipProc.waitUntilExit()

        let extracted = "/tmp/vf_extract/Ollama.app/Contents/Resources/ollama"
        if FileManager.default.fileExists(atPath: extracted) {
            try? FileManager.default.removeItem(at: destBinary)
            try FileManager.default.moveItem(atPath: extracted, toPath: destBinary.path)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destBinary.path)
            try? FileManager.default.removeItem(atPath: "/tmp/vf_extract")
            onProgress("AI Engine ready!")
        } else {
            throw NSError(domain: "VocalFluid", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unpack AI engine"])
        }
    }
}
