import XCTest
@testable import CodeSwitchVoice

final class VADTests: XCTestCase {

    func testSilenceDetection() {
        let vad = VoiceActivityDetector(energyThreshold: 0.02)
        let silence = [Float](repeating: 0.001, count: 320)
        let result = vad.processFrame(silence)
        XCTAssertFalse(result.isSpeech)
        XCTAssertLessThan(result.energyRMS, 0.02)
    }

    func testSpeechDetection() {
        let vad = VoiceActivityDetector(energyThreshold: 0.02)
        // High amplitude voice-like periodic signal
        let speech = (0..<320).map { i in sin(Float(i) * 0.05) * 0.5 }
        let result = vad.processFrame(speech)
        XCTAssertTrue(result.isSpeech)
        XCTAssertGreaterThan(result.energyRMS, 0.02)
    }
}
