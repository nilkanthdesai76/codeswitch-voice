import Foundation
import Accelerate

/// Real-time Voice Activity Detector (VAD).
/// Uses short-time energy (RMS) and Zero Crossing Rate (ZCR) with hangover logic to detect speech onset and offset.
public final class VoiceActivityDetector: @unchecked Sendable {
    public struct VADFrameResult: Sendable {
        public let isSpeech: Bool
        public let energyRMS: Float
        public let zeroCrossingRate: Float
    }

    private let sampleRate: Float
    private let frameSize: Int
    private var energyThreshold: Float
    private var zcrThreshold: Float
    private let speechHangoverFrames: Int
    private var silenceCounter: Int = 0
    private var speechActive: Bool = false

    /// Initialize VAD.
    /// - Parameters:
    ///   - sampleRate: Audio sample rate in Hz (default: 16000).
    ///   - frameSize: Number of samples per frame (default: 320 samples = 20ms at 16kHz).
    ///   - energyThreshold: Minimum RMS energy to consider speech.
    ///   - zcrThreshold: Maximum zero-crossing rate (typical speech has ZCR within 0.05 - 0.40).
    ///   - speechHangoverFrames: Number of silent frames required to trigger speech offset (default: 15 frames = 300ms).
    public init(
        sampleRate: Float = 16000.0,
        frameSize: Int = 320,
        energyThreshold: Float = 0.015,
        zcrThreshold: Float = 0.50,
        speechHangoverFrames: Int = 15
    ) {
        self.sampleRate = sampleRate
        self.frameSize = frameSize
        self.energyThreshold = energyThreshold
        self.zcrThreshold = zcrThreshold
        self.speechHangoverFrames = speechHangoverFrames
    }

    /// Process a frame of audio samples and return speech detection result.
    public func processFrame(_ samples: [Float]) -> VADFrameResult {
        guard !samples.isEmpty else {
            return VADFrameResult(isSpeech: false, energyRMS: 0, zeroCrossingRate: 0)
        }

        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // Calculate Zero Crossing Rate
        var zeroCrossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i - 1] < 0) || (samples[i] < 0 && samples[i - 1] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcr = Float(zeroCrossings) / Float(samples.count)

        // Raw frame classification
        let isRawSpeech = rms >= energyThreshold && zcr <= zcrThreshold

        if isRawSpeech {
            speechActive = true
            silenceCounter = 0
        } else {
            if speechActive {
                silenceCounter += 1
                if silenceCounter >= speechHangoverFrames {
                    speechActive = false
                }
            }
        }

        return VADFrameResult(
            isSpeech: speechActive,
            energyRMS: rms,
            zeroCrossingRate: zcr
        )
    }

    /// Resets detector internal state.
    public func reset() {
        silenceCounter = 0
        speechActive = false
    }

    /// Update energy sensitivity threshold.
    public func setEnergyThreshold(_ threshold: Float) {
        self.energyThreshold = threshold
    }
}
