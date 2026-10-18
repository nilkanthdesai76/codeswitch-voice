import XCTest
@testable import CodeSwitchVoice

final class ContextFormatterTests: XCTestCase {

    func testXcodeFormatting() {
        let input = "function calculateSum variable total equals equals 10"
        let output = ApplicationContextFormatter.format(input, mode: .xcode)
        XCTAssertTrue(output.contains("func calculateSum"))
        XCTAssertTrue(output.contains("var total"))
        XCTAssertTrue(output.contains("=="))
    }

    func testVSCodeFormatting() {
        let input = "constant apiEndpoint interface User fat arrow"
        let output = ApplicationContextFormatter.format(input, mode: .vscode)
        XCTAssertTrue(output.contains("const apiEndpoint"))
        XCTAssertTrue(output.contains("interface User"))
        XCTAssertTrue(output.contains("=>"))
    }

    func testSlackFillerRemovalAndEmojis() {
        let input = "Um I think like you know we did a great job thumbs up fire emoji"
        let output = ApplicationContextFormatter.format(input, mode: .slack)
        XCTAssertFalse(output.contains("Um"))
        XCTAssertFalse(output.contains("like you know"))
        XCTAssertTrue(output.contains("👍"))
        XCTAssertTrue(output.contains("🔥"))
    }

    func testTerminalFlagFormatting() {
        let input = "git push hyphen hyphen force origin main pipe grep origin."
        let output = ApplicationContextFormatter.format(input, mode: .terminal)
        XCTAssertEqual(output, "git push --force origin main | grep origin")
    }

    func testMailSignoffFormatting() {
        let input = "The documents have been attached. Best regards"
        let output = ApplicationContextFormatter.format(input, mode: .mail)
        XCTAssertTrue(output.contains("Best regards,"))
    }
}
