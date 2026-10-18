import XCTest
@testable import CodeSwitchVoice

final class TextStitcherTests: XCTestCase {

    func testHinglishStitching() {
        let fragments = [
            DecodedFragment(text: "please review this PR", language: .english),
            DecodedFragment(text: "bahut achha kaam kiya", language: .hindi),
            DecodedFragment(text: "before merging.", language: .english)
        ]

        let result = TextStitcher.stitch(fragments: fragments)
        XCTAssertEqual(result, "Please review this PR bahut achha kaam kiya before merging.")
    }

    func testGujaratiEnglishStitching() {
        let fragments = [
            DecodedFragment(text: "tamaro code", language: .gujarati),
            DecodedFragment(text: "looks great", language: .english),
            DecodedFragment(text: "kaale malishu", language: .gujarati)
        ]

        let result = TextStitcher.stitch(fragments: fragments)
        XCTAssertEqual(result, "Tamaro code looks great kaale malishu")
    }

    func testCJKStitchingRules() {
        let fragments = [
            DecodedFragment(text: "welcome to", language: .english),
            DecodedFragment(text: "你好", language: .chinese, script: .cjk),
            DecodedFragment(text: "世界", language: .chinese, script: .cjk),
            DecodedFragment(text: "everyone", language: .english)
        ]

        let result = TextStitcher.stitch(fragments: fragments)
        // CJK to CJK should have no space, while Latin to CJK and CJK to Latin have spaces
        XCTAssertEqual(result, "Welcome to 你好世界 everyone")
    }

    func testPunctuationCleaning() {
        let raw = "hello , world ! this is a test . ( inside ) [ brackets ] and another . sentence ."
        let cleaned = TextStitcher.cleanPunctuationAndSpacing(raw)
        XCTAssertEqual(cleaned, "hello, world! This is a test. (inside) [brackets] and another. Sentence.")
    }

    func testCapitalization() {
        XCTAssertEqual(TextStitcher.capitalizeFirstLetter("hello world"), "Hello world")
        XCTAssertEqual(TextStitcher.capitalizeFirstLetter("already Capital"), "Already Capital")
        XCTAssertEqual(TextStitcher.capitalizeFirstLetter(""), "")
    }
}
