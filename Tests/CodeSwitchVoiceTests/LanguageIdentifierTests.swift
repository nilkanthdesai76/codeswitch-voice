import XCTest
@testable import CodeSwitchVoice

final class LanguageIdentifierTests: XCTestCase {

    func testHysteresisFilterRequiresConsecutiveWindows() {
        let lid = LanguageIdentifier(
            initialLanguage: .english,
            hysteresisThreshold: 0.85,
            consecutiveRequired: 2
        )

        // Window 1: High Hindi probability (first occurrence) -> should NOT switch yet
        let res1 = lid.evaluateProbabilities([.english: 0.10, .hindi: 0.90])
        XCTAssertEqual(res1.dominantLanguage, .english)
        XCTAssertFalse(res1.didTransition)

        // Window 2: Second consecutive high Hindi window -> MUST transition
        let res2 = lid.evaluateProbabilities([.english: 0.10, .hindi: 0.90])
        XCTAssertEqual(res2.dominantLanguage, .hindi)
        XCTAssertTrue(res2.didTransition)

        // Window 3: Sustained Hindi
        let res3 = lid.evaluateProbabilities([.english: 0.05, .hindi: 0.95])
        XCTAssertEqual(res3.dominantLanguage, .hindi)
        XCTAssertFalse(res3.didTransition)
    }

    func testHysteresisIgnoresSingleFlicker() {
        let lid = LanguageIdentifier(
            initialLanguage: .english,
            hysteresisThreshold: 0.85,
            consecutiveRequired: 2
        )

        // Flicker window: high Spanish for 1 window only
        let res1 = lid.evaluateProbabilities([.english: 0.10, .spanish: 0.90])
        XCTAssertEqual(res1.dominantLanguage, .english)
        XCTAssertFalse(res1.didTransition)

        // Followed by English -> candidate should reset
        let res2 = lid.evaluateProbabilities([.english: 0.95, .spanish: 0.05])
        XCTAssertEqual(res2.dominantLanguage, .english)
        XCTAssertFalse(res2.didTransition)
    }

    func testZeroCrossingSnapping() {
        // Samples with a clean zero crossing at index 5
        let samples: [Float] = [1.0, 0.8, 0.6, 0.4, 0.2, -0.1, -0.3, -0.5]
        let snap = LanguageIdentifier.findNearestZeroCrossing(in: samples, around: 3, searchRadius: 4)
        // Sign changes between index 4 (0.2) and index 5 (-0.1)
        XCTAssertTrue(snap == 4 || snap == 5)
    }
}
