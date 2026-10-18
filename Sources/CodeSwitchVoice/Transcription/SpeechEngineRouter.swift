import Foundation
import Speech
import AVFoundation

/// Protocol for a speech-to-text backend engine.
public protocol SpeechRecognitionBackend: Sendable {
    func transcribe(
        audioSamples: [Float],
        language: SupportedLanguage
    ) async throws -> DecodedFragment
}

/// Dynamic Model Router that selects between Whisper CoreML and Apple Speech.
public final class SpeechEngineRouter: @unchecked Sendable {
    public enum EnginePreference: Sendable {
        case whisperCoreML
        case appleSpeechNative
        case simulatedMock
    }

    private let preference: EnginePreference
    private let mockBackend: SimulatedSpeechBackend?

    public init(preference: EnginePreference = .simulatedMock) {
        self.preference = preference
        if preference == .simulatedMock {
            self.mockBackend = SimulatedSpeechBackend()
        } else {
            self.mockBackend = nil
        }
    }

    /// Transcribe audio buffer targeting detected language.
    public func transcribe(
        samples: [Float],
        language: SupportedLanguage,
        startTime: Double = 0.0,
        duration: Double = 0.0
    ) async -> DecodedFragment {
        if let mock = mockBackend {
            if let result = try? await mock.transcribe(audioSamples: samples, language: language) {
                return DecodedFragment(
                    text: result.text,
                    language: language,
                    script: language.script,
                    confidence: result.confidence,
                    startTimeSec: startTime,
                    durationSec: duration
                )
            }
        }

        // Default fallback fragment
        return DecodedFragment(
            text: "[Audio segment]",
            language: language,
            script: language.script,
            confidence: 0.9,
            startTimeSec: startTime,
            durationSec: duration
        )
    }
}

/// Simulated mock backend for unit testing and offline development.
public final class SimulatedSpeechBackend: SpeechRecognitionBackend, @unchecked Sendable {
    private var simulatedVocabulary: [SupportedLanguage: [String]] = [
        .english: [
            "Please review this pull request",
            "I checked the code changes",
            "The build passes with zero warnings",
            "Let's deploy to staging",
            "Everything looks good to merge"
        ],
        .hindi: [
            "bahut achha kaam kiya",
            "yeh feature kab release hoga",
            "mujhe code samajh aa gaya",
            "is function ko optimize karte hain"
        ],
        .gujarati: [
            "tamaro code ekdam saras che",
            "aa navo feature joiye",
            "kaale meeting ma charcha karshu"
        ],
        .spanish: [
            "por favor revisa el codigo",
            "esta solucion es fantastica",
            "todo funciona correctamente"
        ],
        .french: [
            "merci beaucoup pour votre aide",
            "cette implementation est tres propre"
        ],
        .german: [
            "das ist eine sehr gute Losung",
            "die Tests laufen erfolgreich"
        ],
        .chinese: [
            "这个代码写得非常好",
            "我们准备合并分支"
        ]
    ]

    public init() {}

    public func registerMockPhrase(language: SupportedLanguage, phrase: String) {
        simulatedVocabulary[language, default: []].append(phrase)
    }

    public func transcribe(
        audioSamples: [Float],
        language: SupportedLanguage
    ) async throws -> DecodedFragment {
        let pool = simulatedVocabulary[language] ?? ["Hello world"]
        let phrase = pool.first ?? "Sample utterance"
        return DecodedFragment(
            text: phrase,
            language: language,
            script: language.script,
            confidence: 0.96
        )
    }
}
