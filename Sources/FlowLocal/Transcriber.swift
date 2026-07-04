import AVFoundation
import Foundation
import WhisperKit

/// On-device streaming transcription via WhisperKit (CoreML on ANE/GPU — never CPU-only).
///
/// Streaming model: while the mic is open we re-transcribe the growing audio
/// buffer roughly once per second and emit the result as a live partial
/// ("hypothesis") transcript. When the hotkey is released we run a final pass
/// over the complete buffer and emit the confirmed transcript.
final class Transcriber {
    /// Live partial transcript while dictating.
    var onPartial: ((String) -> Void)?
    /// Final confirmed transcript after the mic closes.
    var onFinal: ((String) -> Void)?

    private var whisperKit: WhisperKit?
    private var streamTask: Task<Void, Never>?
    private var isRecording = false

    private var decodingOptions: DecodingOptions {
        var options = DecodingOptions(
            task: .transcribe,
            temperature: 0,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        // Bias recognition toward the user's custom vocabulary by feeding the
        // terms as a prompt (Whisper conditions on it like preceding context).
        let terms = AppSettings.shared.vocabulary.map(\.term).filter { !$0.isEmpty }
        if !terms.isEmpty, let tokenizer = whisperKit?.tokenizer {
            let vocabularyHint = " " + terms.joined(separator: ", ")
            let tokens = tokenizer.encode(text: vocabularyHint)
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            if !tokens.isEmpty {
                options.promptTokens = tokens
                options.usePrefillPrompt = true
            }
        }
        return options
    }

    // MARK: - Model lifecycle

    func loadModel() async throws {
        let modelName = AppSettings.shared.modelName
        flog("[FlowLocal] Loading WhisperKit model '\(modelName)' (first run downloads it)…")
        let config = WhisperKitConfig(
            model: modelName,
            verbose: false,
            prewarm: true,
            load: true
        )
        whisperKit = try await WhisperKit(config)
        flog("[FlowLocal] Model ready.")
    }

    // MARK: - One-shot transcription (used by --selftest and the final pass)

    func transcribe(samples: [Float]) async throws -> String {
        guard let whisperKit else { throw TranscriberError.modelNotLoaded }
        let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: decodingOptions)
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Streaming dictation

    /// In-flight startup, so a fast stop can await it instead of racing it.
    /// (Releasing the hotkey quickly used to hit stop while start was still
    /// awaiting mic permission — stop no-opped and the mic stayed open forever.)
    private var startupTask: Task<Void, Error>?

    func startDictation() async throws {
        guard let whisperKit else { throw TranscriberError.modelNotLoaded }
        guard !isRecording, startupTask == nil else { return }

        let task = Task<Void, Error> {
            guard await AudioProcessor.requestRecordPermission() else {
                throw TranscriberError.microphoneDenied
            }
            try whisperKit.audioProcessor.startRecordingLive { _ in }
            isRecording = true
            startStreamLoop(whisperKit: whisperKit)
        }
        startupTask = task
        do {
            try await task.value
            startupTask = nil
        } catch {
            startupTask = nil
            throw error
        }
    }

    /// Partial-transcript loop: re-transcribe the growing buffer ~1x/sec.
    private func startStreamLoop(whisperKit: WhisperKit) {
        streamTask = Task { [weak self] in
            var lastSampleCount = 0
            while let self, self.isRecording, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard self.isRecording else { break }
                let samples = Array(whisperKit.audioProcessor.audioSamples)
                // Skip until there's at least a second of new audio.
                guard samples.count - lastSampleCount >= 16000 else { continue }
                lastSampleCount = samples.count
                if let partial = try? await self.transcribe(samples: samples), !partial.isEmpty {
                    self.onPartial?(partial)
                }
            }
        }
    }

    func stopDictation() async {
        // Wait out any in-flight start so stop can never race past it.
        if let startupTask {
            _ = try? await startupTask.value
        }
        guard let whisperKit, isRecording else {
            // Nothing was recording — still emit a final so the UI resets.
            onFinal?("")
            return
        }
        isRecording = false
        // Cancel the partial loop and wait for any in-flight partial
        // transcription — concurrent WhisperKit transcribe calls are unsafe.
        if let streamTask {
            streamTask.cancel()
            await streamTask.value
        }
        streamTask = nil

        whisperKit.audioProcessor.stopRecording()
        let samples = Array(whisperKit.audioProcessor.audioSamples)
        defer { whisperKit.audioProcessor.purgeAudioSamples(keepingLast: 0) }

        // Ignore accidental taps shorter than ~0.3s.
        guard samples.count >= 4800 else {
            onFinal?("")
            return
        }

        // Energy gate: don't transcribe near-silence at all — Whisper
        // hallucinates on it ("you", "Thank you.", "."), and the LLM then
        // "answers" the hallucination.
        let rms = sqrt(samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count))
        guard rms > 0.005 else {
            flog("[stt] dropped near-silent audio (rms=\(rms))")
            onFinal?("")
            return
        }

        var text = (try? await transcribe(samples: samples)) ?? ""
        // Content-free or known silence-hallucination outputs → drop.
        let normalized = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        let hallucinations: Set<String> = ["you", "thank you", "thanks for watching", "thank you for watching", "bye", "hmm", "mm-hmm"]
        if !text.contains(where: { $0.isLetter || $0.isNumber }) || hallucinations.contains(normalized) {
            flog("[stt] dropped likely hallucination: \"\(text)\"")
            text = ""
        }
        onFinal?(text)
    }
}

enum TranscriberError: LocalizedError {
    case modelNotLoaded
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "WhisperKit model is not loaded yet"
        case .microphoneDenied: return "Microphone access denied — grant it in System Settings → Privacy & Security → Microphone"
        }
    }
}
