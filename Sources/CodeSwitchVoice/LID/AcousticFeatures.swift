import Foundation
import Accelerate

/// Computes 80-channel log-mel filterbank energies from 16kHz mono audio.
/// Used by the Acoustic Language Identification (LID) classifier.
public final class AcousticFeatures: @unchecked Sendable {
    public let sampleRate: Float
    public let nFft: Int
    public let hopLength: Int
    public let nMels: Int
    public let minFreq: Float
    public let maxFreq: Float

    private let window: [Float]
    private let melFilters: [[Float]] // [nMels x (nFft/2 + 1)]
    private let fftSetup: vDSP_DFT_Setup?

    public init(
        sampleRate: Float = 16000.0,
        nFft: Int = 400,
        hopLength: Int = 160,
        nMels: Int = 80,
        minFreq: Float = 0.0,
        maxFreq: Float = 8000.0
    ) {
        self.sampleRate = sampleRate
        self.nFft = nFft
        self.hopLength = hopLength
        self.nMels = nMels
        self.minFreq = minFreq
        self.maxFreq = maxFreq

        // Create Hann window
        var win = [Float](repeating: 0.0, count: nFft)
        vDSP_hann_window(&win, vDSP_Length(nFft), Int32(vDSP_HANN_NORM))
        self.window = win

        // Precompute Mel filterbank matrix
        self.melFilters = Self.createMelFilterbank(
            nMels: nMels,
            nFft: nFft,
            sampleRate: sampleRate,
            minFreq: minFreq,
            maxFreq: maxFreq
        )

        // Setup 1D Discrete Fourier Transform
        self.fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(nFft),
            .FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    /// Extract 80-channel log-mel spectrogram frames from raw audio samples.
    /// Returns 2D array: [framesCount x nMels].
    public func extractLogMelEnergies(samples: [Float]) -> [[Float]] {
        guard samples.count >= nFft, let fftSetup = fftSetup else {
            return []
        }

        let numFrames = (samples.count - nFft) / hopLength + 1
        var result = [[Float]]()
        result.reserveCapacity(numFrames)

        let halfFft = nFft / 2 + 1
        var windowed = [Float](repeating: 0.0, count: nFft)
        var realIn = [Float](repeating: 0.0, count: nFft)
        var imagIn = [Float](repeating: 0.0, count: nFft)
        var realOut = [Float](repeating: 0.0, count: nFft)
        var imagOut = [Float](repeating: 0.0, count: nFft)
        var powerSpectrum = [Float](repeating: 0.0, count: halfFft)

        for frameIdx in 0..<numFrames {
            let start = frameIdx * hopLength
            let frameSamples = Array(samples[start..<start + nFft])

            // Window frame
            vDSP_vmul(frameSamples, 1, window, 1, &windowed, 1, vDSP_Length(nFft))

            realIn = windowed
            imagIn.withUnsafeMutableBufferPointer { ptr in
                ptr.initialize(repeating: 0.0)
            }

            // Execute FFT
            vDSP_DFT_Execute(
                fftSetup,
                &realIn,
                &imagIn,
                &realOut,
                &imagOut
            )

            // Compute power spectrum: |X|^2 = real^2 + imag^2
            for i in 0..<halfFft {
                powerSpectrum[i] = realOut[i] * realOut[i] + imagOut[i] * imagOut[i]
            }

            // Apply Mel filterbanks & log compression
            var melEnergies = [Float](repeating: 0.0, count: nMels)
            for m in 0..<nMels {
                var dot: Float = 0.0
                vDSP_dotpr(powerSpectrum, 1, melFilters[m], 1, &dot, vDSP_Length(halfFft))
                // Log compression with small epsilon floor
                melEnergies[m] = log(max(dot, 1e-6))
            }

            result.append(melEnergies)
        }

        return result
    }

    /// Computes triangular Mel filterbank weights.
    private static func createMelFilterbank(
        nMels: Int,
        nFft: Int,
        sampleRate: Float,
        minFreq: Float,
        maxFreq: Float
    ) -> [[Float]] {
        let halfFft = nFft / 2 + 1

        func hzToMel(_ hz: Float) -> Float {
            return 2595.0 * log10(1.0 + hz / 700.0)
        }

        func melToHz(_ mel: Float) -> Float {
            return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)
        }

        let minMel = hzToMel(minFreq)
        let maxMel = hzToMel(maxFreq)
        let melPoints = (0...(nMels + 1)).map { i -> Float in
            minMel + Float(i) * (maxMel - minMel) / Float(nMels + 1)
        }
        let hzPoints = melPoints.map { melToHz($0) }
        let binPoints = hzPoints.map { hz -> Int in
            let bin = Int(floor((Float(nFft) + 1.0) * hz / sampleRate))
            return min(max(bin, 0), halfFft - 1)
        }

        var filters = [[Float]](repeating: [Float](repeating: 0.0, count: halfFft), count: nMels)

        for m in 0..<nMels {
            let left = binPoints[m]
            let center = binPoints[m + 1]
            let right = binPoints[m + 2]

            if center > left {
                for k in left..<center {
                    filters[m][k] = Float(k - left) / Float(center - left)
                }
            }

            if right > center {
                for k in center..<right {
                    filters[m][k] = Float(right - k) / Float(right - center)
                }
            }
        }

        return filters
    }
}
