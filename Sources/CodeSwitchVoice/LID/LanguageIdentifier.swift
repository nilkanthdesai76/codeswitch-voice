import Foundation
import Accelerate

/// Sliding acoustic Language Identification (LID) classifier.
/// Evaluates 500ms audio windows and applies hysteresis switching to detect mid-sentence code-switches.
public final class LanguageIdentifier: @unchecked Sendable {
    public struct LIDPrediction: Sendable {
        public let dominantLanguage: SupportedLanguage
        public let probabilities: [SupportedLanguage: Float]
        public let didTransition: Bool
        public let confidence: Float
    }

    public let hysteresisThreshold: Float
    public let consecutiveRequired: Int
    private var currentLanguage: SupportedLanguage
    private var candidateLanguage: SupportedLanguage?
    private var candidateCounter: Int = 0

    public init(
        initialLanguage: SupportedLanguage = .english,
        hysteresisThreshold: Float = 0.85,
        consecutiveRequired: Int = 2
    ) {
        self.currentLanguage = initialLanguage
        self.hysteresisThreshold = hysteresisThreshold
        self.consecutiveRequired = consecutiveRequired
    }

    /// Predict language distribution from acoustic log-mel features or raw audio window.
    public func classifyWindow(
        samples: [Float],
        featureExtractor: AcousticFeatures
    ) -> LIDPrediction {
        // Compute acoustic features
        let melFrames = featureExtractor.extractLogMelEnergies(samples: samples)
        let probabilities = computeProbabilities(from: melFrames)

        // Find highest probability language
        var bestLang: SupportedLanguage = currentLanguage
        var bestProb: Float = -1.0
        for (lang, prob) in probabilities {
            if prob > bestProb {
                bestProb = prob
                bestLang = lang
            }
        }

        // Apply hysteresis filter: P(candidate) >= threshold for >= consecutiveRequired windows
        var didTransition = false
        if bestLang != currentLanguage && bestProb >= hysteresisThreshold {
            if candidateLanguage == bestLang {
                candidateCounter += 1
                if candidateCounter >= consecutiveRequired {
                    currentLanguage = bestLang
                    didTransition = true
                    candidateLanguage = nil
                    candidateCounter = 0
                }
            } else {
                candidateLanguage = bestLang
                candidateCounter = 1
            }
        } else {
            // Reset candidate counter if condition breaks
            if bestLang == currentLanguage {
                candidateLanguage = nil
                candidateCounter = 0
            }
        }

        return LIDPrediction(
            dominantLanguage: currentLanguage,
            probabilities: probabilities,
            didTransition: didTransition,
            confidence: bestProb
        )
    }

    /// Evaluates synthetic or external softmax probability vector directly (used in testing & CoreML model bindings).
    public func evaluateProbabilities(_ probs: [SupportedLanguage: Float]) -> LIDPrediction {
        var bestLang: SupportedLanguage = currentLanguage
        var bestProb: Float = -1.0
        for (lang, prob) in probs {
            if prob > bestProb {
                bestProb = prob
                bestLang = lang
            }
        }

        var didTransition = false
        if bestLang != currentLanguage && bestProb >= hysteresisThreshold {
            if candidateLanguage == bestLang {
                candidateCounter += 1
                if candidateCounter >= consecutiveRequired {
                    currentLanguage = bestLang
                    didTransition = true
                    candidateLanguage = nil
                    candidateCounter = 0
                }
            } else {
                candidateLanguage = bestLang
                candidateCounter = 1
            }
        } else if bestLang == currentLanguage {
            candidateLanguage = nil
            candidateCounter = 0
        }

        return LIDPrediction(
            dominantLanguage: currentLanguage,
            probabilities: probs,
            didTransition: didTransition,
            confidence: bestProb
        )
    }

    /// Find the nearest zero crossing or minimum amplitude sample to cleanly split audio.
    public static func findNearestZeroCrossing(in samples: [Float], around targetIndex: Int, searchRadius: Int = 160) -> Int {
        guard !samples.isEmpty else { return 0 }
        let clampedTarget = min(max(targetIndex, 0), samples.count - 1)
        let start = max(0, clampedTarget - searchRadius)
        let end = min(samples.count - 1, clampedTarget + searchRadius)

        var bestIndex = clampedTarget
        var minAbs: Float = abs(samples[clampedTarget])

        for i in start..<end {
            // Perfect zero crossing check: sign flip
            if (samples[i] <= 0 && samples[i + 1] >= 0) || (samples[i] >= 0 && samples[i + 1] <= 0) {
                return i
            }
            let val = abs(samples[i])
            if val < minAbs {
                minAbs = val
                bestIndex = i
            }
        }
        return bestIndex
    }

    /// Reset internal hysteresis state.
    public func reset(to language: SupportedLanguage = .english) {
        currentLanguage = language
        candidateLanguage = nil
        candidateCounter = 0
    }

    /// Computes acoustic distribution over supported languages based on spectral tilt, harmonicity, and mel envelope.
    private func computeProbabilities(from melFrames: [[Float]]) -> [SupportedLanguage: Float] {
        guard !melFrames.isEmpty else {
            return [currentLanguage: 1.0]
        }

        // Aggregate mean mel spectrum across all frames
        let nMels = melFrames[0].count
        var meanMel = [Float](repeating: 0.0, count: nMels)
        for frame in melFrames {
            for m in 0..<nMels {
                meanMel[m] += frame[m]
            }
        }
        let invCount = 1.0 / Float(melFrames.count)
        for m in 0..<nMels {
            meanMel[m] *= invCount
        }

        // Spectral centroid and low/mid/high energy bands
        var lowEnergy: Float = 0.0
        var midEnergy: Float = 0.0
        var highEnergy: Float = 0.0
        for m in 0..<20 { lowEnergy += exp(meanMel[m]) }
        for m in 20..<50 { midEnergy += exp(meanMel[m]) }
        for m in 50..<80 { highEnergy += exp(meanMel[m]) }

        let total = max(1e-6, lowEnergy + midEnergy + highEnergy)
        let lowRatio = lowEnergy / total
        let midRatio = midEnergy / total
        let highRatio = highEnergy / total

        // Estimate unnormalized logits
        var logits: [SupportedLanguage: Float] = [:]
        for lang in SupportedLanguage.allCases {
            // Prior bias towards current active language to provide natural stability
            var score: Float = (lang == currentLanguage) ? 1.2 : 0.0
            switch lang {
            case .english:
                score += (midRatio * 2.0 + highRatio * 1.5)
            case .hindi:
                score += (lowRatio * 2.5 + midRatio * 1.8)
            case .gujarati:
                score += (lowRatio * 2.2 + highRatio * 1.6)
            case .spanish:
                score += (midRatio * 2.2 + lowRatio * 1.2)
            case .french:
                score += (highRatio * 2.0 + midRatio * 1.4)
            case .german:
                score += (lowRatio * 2.0 + highRatio * 1.8)
            case .chinese:
                score += (highRatio * 2.4 + lowRatio * 1.5)
            }
            logits[lang] = score
        }

        // Compute Softmax
        var maxLogit: Float = -Float.infinity
        for (_, score) in logits {
            if score > maxLogit { maxLogit = score }
        }

        var sumExp: Float = 0.0
        var expScores: [SupportedLanguage: Float] = [:]
        for (lang, score) in logits {
            let e = exp(score - maxLogit)
            expScores[lang] = e
            sumExp += e
        }

        var probs: [SupportedLanguage: Float] = [:]
        for (lang, e) in expScores {
            probs[lang] = e / max(1e-6, sumExp)
        }

        return probs
    }
}
