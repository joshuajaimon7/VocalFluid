import AppKit
import Foundation

// Line-buffer stdout so console logging is visible when redirected to a file.
setvbuf(stdout, nil, _IOLBF, 0)

// MARK: - CLI arguments
// --selftest       : load the model, transcribe 2s of silence, print result, exit.
// --model <name>   : override the WhisperKit model (e.g. "tiny", "base", "small").
let arguments = CommandLine.arguments
if let modelFlagIndex = arguments.firstIndex(of: "--model"), modelFlagIndex + 1 < arguments.count {
    AppSettings.shared.modelNameOverride = arguments[modelFlagIndex + 1]
}

if let insertFlagIndex = arguments.firstIndex(of: "--insert-test"), insertFlagIndex + 1 < arguments.count {
    // Manual verification of text insertion: focus any text field within 3s,
    // and the given string is inserted at the cursor (AX first, paste fallback).
    let text = arguments[insertFlagIndex + 1]
    print("[FlowLocal] Inserting \"\(text)\" into the focused field in 3 seconds — click into a text field now…")
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        let method = TextInserter().insert(text)
        print("[FlowLocal] Inserted via \(method).")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
    }
    RunLoop.main.run()
} else if let cleanFlagIndex = arguments.firstIndex(of: "--clean-test"), cleanFlagIndex + 1 < arguments.count {
    // Verify the Ollama cleanup pass: health check, then clean the given text
    // at every intensity level.
    let raw = arguments[cleanFlagIndex + 1]
    Task {
        let cleaner = Cleaner()
        do {
            try await cleaner.healthCheck()
            print("[FlowLocal] Ollama OK (model: \(AppSettings.shared.ollamaModel))")
            for intensity in CleanupIntensity.allCases where intensity != .none {
                let cleaned = try await cleaner.clean(raw, intensity: intensity, appContext: "Notes")
                print("[\(intensity.rawValue)] \(cleaned)")
            }
            exit(0)
        } catch {
            FileHandle.standardError.write("CLEAN-TEST FAILED: \(error.localizedDescription)\n".data(using: .utf8)!)
            exit(1)
        }
    }
    RunLoop.main.run()
} else if arguments.contains("--process-test") {
    // Verify the deterministic post-processing layer (no model/network needed).
    let vocab = [VocabularyEntry(term: "whisper kit", replacement: "WhisperKit")]
    var failures = 0
    func expect(_ actual: TranscriptProcessor.Action, _ expected: TranscriptProcessor.Action, _ name: String) {
        if actual == expected {
            print("PASS \(name)")
        } else {
            print("FAIL \(name): got \(actual), expected \(expected)")
            failures += 1
        }
    }
    expect(TranscriptProcessor.process("Scratch that.", vocabulary: vocab, frontmostApp: nil),
           .scratchLast, "scratch-that command")
    expect(TranscriptProcessor.process("delete that", vocabulary: vocab, frontmostApp: nil),
           .scratchLast, "delete-that command")
    expect(TranscriptProcessor.process("Buy milk. New line. Buy eggs.", vocabulary: vocab, frontmostApp: nil),
           .insert("Buy milk.\nBuy eggs."), "inline new-line command")
    expect(TranscriptProcessor.process("I love whisper kit a lot.", vocabulary: vocab, frontmostApp: nil),
           .insert("I love WhisperKit a lot."), "vocabulary replacement")
    expect(TranscriptProcessor.process("Sounds good.", vocabulary: vocab, frontmostApp: "Messages"),
           .insert("Sounds good"), "casual app drops trailing period")
    expect(TranscriptProcessor.process("Sounds good.", vocabulary: vocab, frontmostApp: "Pages"),
           .insert("Sounds good."), "formal app keeps trailing period")
    expect(TranscriptProcessor.process("  ", vocabulary: vocab, frontmostApp: nil),
           .nothing, "empty input")
    print(failures == 0 ? "PROCESS-TEST OK" : "PROCESS-TEST FAILED (\(failures))")
    exit(failures == 0 ? 0 : 1)
} else if arguments.contains("--selftest") {
    // Headless verification: model loads and the transcription pipeline runs.
    Task {
        do {
            let transcriber = Transcriber()
            try await transcriber.loadModel()
            let silence = [Float](repeating: 0, count: 2 * 16000) // 2s @ 16kHz
            let text = try await transcriber.transcribe(samples: silence)
            print("SELFTEST OK — model '\(AppSettings.shared.modelName)' loaded; silence transcribed as: \"\(text)\"")
            exit(0)
        } catch {
            FileHandle.standardError.write("SELFTEST FAILED: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }
    RunLoop.main.run()
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu-bar only, no dock icon
        app.run()
    }
}
