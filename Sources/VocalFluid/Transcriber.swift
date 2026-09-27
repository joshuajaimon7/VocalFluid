import AVFoundation
import Foundation
import WhisperKit

/// On-device streaming transcription via WhisperKit (CoreML on ANE/GPU — never CPU-only).
final class Transcriber {
    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?

    private var whisperKit: WhisperKit?
    private var streamTask: Task<Void, Never>?
    private var isRecording = false

    private var latestPartialText: String = ""
    private var lastTranscribedSampleCount: Int = 0

    private var decodingOptions: DecodingOptions {
        var options = DecodingOptions(
            task: .transcribe,
            temperature: 0,
            temperatureFallbackCount: 0,
            sampleLength: 224,
            usePrefillPrompt: false,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            clipTimestamps: [],
            suppressBlank: true
        )

        // Multi-language: Explicit language code dramatically improves recognition accuracy
        let lang = AppSettings.shared.language
        if lang != "auto" {
            options.language = lang
        }

        return options
    }

    // MARK: - Model lifecycle

    func loadModel() async throws {
        let modelName = AppSettings.shared.modelName
        flog("[VocalFluid] Loading WhisperKit model '\(modelName)' (language=\(AppSettings.shared.language))…")
        let config = WhisperKitConfig(
            model: modelName,
            verbose: false,
            prewarm: true,
            load: true
        )
        whisperKit = try await WhisperKit(config)
        flog("[VocalFluid] Model ready.")
    }

    // MARK: - One-shot transcription

    func transcribe(samples: [Float]) async throws -> String {
        guard let whisperKit else { throw TranscriberError.modelNotLoaded }
        let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: decodingOptions)
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Streaming dictation

    private var startupTask: Task<Void, Error>?

    func startDictation() async throws {
        guard let whisperKit else { throw TranscriberError.modelNotLoaded }
        guard !isRecording, startupTask == nil else { return }

        latestPartialText = ""
        lastTranscribedSampleCount = 0

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

    private func startStreamLoop(whisperKit: WhisperKit) {
        streamTask = Task { [weak self] in
            while let self, self.isRecording, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(450))
                guard self.isRecording, !Task.isCancelled else { break }
                let samples = Array(whisperKit.audioProcessor.audioSamples)
                guard samples.count - self.lastTranscribedSampleCount >= 8000 else { continue }
                self.lastTranscribedSampleCount = samples.count
                if let partial = try? await self.transcribe(samples: samples), !partial.isEmpty {
                    guard self.isRecording, !Task.isCancelled else { break }
                    self.latestPartialText = partial
                    self.onPartial?(partial)
                }
            }
        }
    }

    func stopDictation() async {
        if let startupTask {
            _ = try? await startupTask.value
        }
        guard let whisperKit, isRecording else {
            onFinal?("")
            return
        }
        isRecording = false
        // Cancel the background streaming loop immediately without blocking
        streamTask?.cancel()
        streamTask = nil

        whisperKit.audioProcessor.stopRecording()
        let samples = Array(whisperKit.audioProcessor.audioSamples)
        defer { whisperKit.audioProcessor.purgeAudioSamples(keepingLast: 0) }

        // Ignore accidental taps shorter than ~0.25s
        guard samples.count >= 4000 else {
            onFinal?("")
            return
        }

        // Energy gate: lowered to 0.002 to capture soft & quiet voices accurately
        let rms = sqrt(samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count))
        guard rms > 0.002 else {
            flog("[stt] dropped near-silent audio (rms=\(rms))")
            onFinal?("")
            return
        }

        // If background streaming already transcribed within 0.25s of key release, use it instantly!
        var text: String
        let unTranscribedSamples = samples.count - lastTranscribedSampleCount
        if unTranscribedSamples < 4000 && !latestPartialText.isEmpty {
            flog("[stt] instant final from streaming partial (\(unTranscribedSamples) trailing samples)")
            text = latestPartialText
        } else {
            text = (try? await transcribe(samples: samples)) ?? ""
        }

        let normalized = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        let hallucinations: Set<String> = ["thanks for watching", "thank you for watching", "subtitles by", "amara.org"]
        if hallucinations.contains(normalized) {
            flog("[stt] dropped hallucination: \"\(text)\"")
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
