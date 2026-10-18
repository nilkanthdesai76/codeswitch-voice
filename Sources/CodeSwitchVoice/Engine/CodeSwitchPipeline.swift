import Foundation
import Accelerate

/// Top-level coordinator for CodeSwitch Voice streaming dictation.
public final class CodeSwitchPipeline: @unchecked Sendable {
    public let ringBuffer: LockFreeAudioRingBuffer
    public let vad: VoiceActivityDetector
    public let featureExtractor: AcousticFeatures
    public let languageIdentifier: LanguageIdentifier
    public let router: SpeechEngineRouter

    private var isRunning: Bool = false
    private var activeSpeechAudio: [Float] = []
    private var currentSegmentLanguage: SupportedLanguage = .english
    private var segmentStartSample: Int = 0
    private var totalSamplesProcessed: Int = 0
    private var accumulatedFragments: [DecodedFragment] = []

    public init(
        initialLanguage: SupportedLanguage = .english,
        enginePreference: SpeechEngineRouter.EnginePreference = .simulatedMock
    ) {
        self.ringBuffer = LockFreeAudioRingBuffer()
        self.vad = VoiceActivityDetector()
        self.featureExtractor = AcousticFeatures()
        self.languageIdentifier = LanguageIdentifier(initialLanguage: initialLanguage)
        self.router = SpeechEngineRouter(preference: enginePreference)
        self.currentSegmentLanguage = initialLanguage
    }

    /// Feed audio samples (e.g. from microphone tap).
    public func feedAudio(samples: [Float]) {
        ringBuffer.write(samples: samples)
    }

    /// Process queued audio in ring buffer in 500ms sliding windows.
    /// Returns a completed TranscriptionResult when a sentence or utterance silence boundary completes.
    public func processAvailableAudio() async -> TranscriptionResult? {
        let windowSize = 8000 // 500ms at 16kHz
        let hopSize = 4000    // 250ms hop

        guard let window = ringBuffer.read(count: hopSize) else {
            return nil
        }

        totalSamplesProcessed += hopSize

        // 1. Voice Activity Detection
        let vadResult = vad.processFrame(window)

        if vadResult.isSpeech {
            activeSpeechAudio.append(contentsOf: window)

            // 2. Classify Language
            let lid = languageIdentifier.classifyWindow(
                samples: window,
                featureExtractor: featureExtractor
            )

            // 3. Language Transition Check
            if lid.didTransition && activeSpeechAudio.count > windowSize {
                let snapIndex = LanguageIdentifier.findNearestZeroCrossing(
                    in: activeSpeechAudio,
                    around: activeSpeechAudio.count - hopSize
                )

                let segmentAudio = Array(activeSpeechAudio[0..<snapIndex])
                activeSpeechAudio = Array(activeSpeechAudio[snapIndex...])

                let durationSec = Double(segmentAudio.count) / 16000.0
                let startSec = Double(segmentStartSample) / 16000.0
                segmentStartSample += segmentAudio.count

                let fragment = await router.transcribe(
                    samples: segmentAudio,
                    language: currentSegmentLanguage,
                    startTime: startSec,
                    duration: durationSec
                )
                accumulatedFragments.append(fragment)

                currentSegmentLanguage = lid.dominantLanguage
            }
        } else {
            // Speech stopped; finalize utterance if there are buffered speech samples
            if !activeSpeechAudio.isEmpty && activeSpeechAudio.count >= 3200 { // at least 200ms
                let durationSec = Double(activeSpeechAudio.count) / 16000.0
                let startSec = Double(segmentStartSample) / 16000.0

                let fragment = await router.transcribe(
                    samples: activeSpeechAudio,
                    language: currentSegmentLanguage,
                    startTime: startSec,
                    duration: durationSec
                )
                accumulatedFragments.append(fragment)
                activeSpeechAudio.removeAll(keepingCapacity: true)

                // Assemble finished utterance
                let fragments = accumulatedFragments
                accumulatedFragments.removeAll()
                segmentStartSample = 0

                let stitched = TextStitcher.stitch(fragments: fragments)
                let formatted = ApplicationContextFormatter.formatForFrontmostApp(stitched)

                let distinctLangs = Array(Set(fragments.map { $0.language }))
                let didCodeSwitch = distinctLangs.count > 1

                return TranscriptionResult(
                    originalFragments: fragments,
                    stitchedText: stitched,
                    formattedText: formatted,
                    detectedLanguages: distinctLangs,
                    didCodeSwitch: didCodeSwitch,
                    latencyMs: 120.0
                )
            } else if !activeSpeechAudio.isEmpty {
                activeSpeechAudio.removeAll(keepingCapacity: true)
            }
        }

        return nil
    }

    /// Synchronously processes a list of simulated code-switched fragments for end-to-end evaluation.
    public func evaluateCodeSwitchedFragments(
        _ fragments: [DecodedFragment],
        targetContext: ApplicationContextFormatter.ContextMode = .general,
        injectToSystem: Bool = false
    ) -> TranscriptionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let stitched = TextStitcher.stitch(fragments: fragments)
        let formatted = ApplicationContextFormatter.format(stitched, mode: targetContext)

        if injectToSystem {
            TextInjector.inject(text: formatted)
        }

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        let distinctLangs = Array(Set(fragments.map { $0.language }))

        return TranscriptionResult(
            originalFragments: fragments,
            stitchedText: stitched,
            formattedText: formatted,
            detectedLanguages: distinctLangs,
            didCodeSwitch: distinctLangs.count > 1,
            latencyMs: latency
        )
    }

    /// Reset pipeline state.
    public func reset() {
        ringBuffer.clear()
        vad.reset()
        languageIdentifier.reset()
        activeSpeechAudio.removeAll()
        accumulatedFragments.removeAll()
        segmentStartSample = 0
        totalSamplesProcessed = 0
    }
}
