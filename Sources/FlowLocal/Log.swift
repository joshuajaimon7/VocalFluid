import Foundation

/// Logs to both stdout and ~/Library/Logs/FlowLocal.log so diagnostics survive
/// launches via Finder/LaunchServices where stdout goes nowhere.
func flog(_ message: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)"
    print(line)
    let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/FlowLocal.log")
    guard let data = (line + "\n").data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: url)
    }
}
