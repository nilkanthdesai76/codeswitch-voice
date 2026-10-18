import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Formats transcribed text according to the currently active application context.
public final class ApplicationContextFormatter: Sendable {
    public enum ContextMode: String, Sendable, CaseIterable {
        case general
        case xcode = "com.apple.dt.Xcode"
        case vscode = "com.microsoft.VSCode"
        case slack = "com.tinyspeck.slackmacgap"
        case mail = "com.apple.mail"
        case terminal = "com.apple.Terminal"

        public static func fromBundleIdentifier(_ bundleID: String?) -> ContextMode {
            guard let bundleID = bundleID else { return .general }
            if bundleID.contains("Xcode") { return .xcode }
            if bundleID.contains("VSCode") || bundleID.contains("Code") { return .vscode }
            if bundleID.contains("slack") { return .slack }
            if bundleID.contains("mail") { return .mail }
            if bundleID.contains("Terminal") || bundleID.contains("iTerm") { return .terminal }
            return .general
        }
    }

    /// Automatically formats text based on the frontmost application.
    public static func formatForFrontmostApp(_ text: String) -> String {
        #if canImport(AppKit)
        let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let mode = ContextMode.fromBundleIdentifier(frontmostID)
        return format(text, mode: mode)
        #else
        return format(text, mode: .general)
        #endif
    }

    /// Formats text according to explicit context mode.
    public static func format(_ rawText: String, mode: ContextMode) -> String {
        switch mode {
        case .xcode:
            return formatXcode(rawText)
        case .vscode:
            return formatVSCode(rawText)
        case .slack:
            return formatSlack(rawText)
        case .mail:
            return formatMail(rawText)
        case .terminal:
            return formatTerminal(rawText)
        case .general:
            return rawText
        }
    }

    // MARK: - App Specific Formatters

    private static func formatXcode(_ text: String) -> String {
        var result = text

        // Convert spoken keywords to Swift syntax
        let swiftReplacements: [(String, String)] = [
            ("function ", "func "),
            ("variable ", "var "),
            ("constant ", "let "),
            ("guard let ", "guard let "),
            ("async await", "async await"),
            ("return ", "return "),
            ("equals equals", "=="),
            ("not equals", "!="),
            ("arrow ", "-> "),
            ("open bracket", "["),
            ("close bracket", "]"),
            ("open brace", "{"),
            ("close brace", "}")
        ]

        for (spoken, syntax) in swiftReplacements {
            result = result.replacingOccurrences(of: spoken, with: syntax, options: .caseInsensitive)
        }

        return result
    }

    private static func formatVSCode(_ text: String) -> String {
        var result = text

        let jsReplacements: [(String, String)] = [
            ("constant ", "const "),
            ("export default ", "export default "),
            ("interface ", "interface "),
            ("fat arrow", "=>"),
            ("arrow function", "() =>"),
            ("triple equals", "==="),
            ("not triple equals", "!==")
        ]

        for (spoken, syntax) in jsReplacements {
            result = result.replacingOccurrences(of: spoken, with: syntax, options: .caseInsensitive)
        }

        return result
    }

    private static func formatSlack(_ text: String) -> String {
        var result = text

        // Strip verbal fillers
        let fillers = [
            "\\bum\\b", "\\buh\\b", "\\bah\\b", "\\byou know\\b", "\\blike you know\\b"
        ]
        for filler in fillers {
            if let regex = try? NSRegularExpression(pattern: filler, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(location: 0, length: result.utf16.count),
                    withTemplate: ""
                )
            }
        }

        // Convert emoji keywords
        let emojiMap: [(String, String)] = [
            ("thumbs up", "👍"),
            ("thumbs down", "👎"),
            ("smiley face", "😊"),
            ("laughing face", "😂"),
            ("fire emoji", "🔥"),
            ("rocket emoji", "🚀"),
            ("heart emoji", "❤️"),
            ("party popper", "🎉")
        ]

        for (spoken, emoji) in emojiMap {
            result = result.replacingOccurrences(of: spoken, with: emoji, options: .caseInsensitive)
        }

        // Clean double spaces created by filler removal
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatMail(_ text: String) -> String {
        var result = text

        // Format common formal email signoffs
        let signoffs: [(String, String)] = [
            ("best regards", "\n\nBest regards,\n"),
            ("kind regards", "\n\nKind regards,\n"),
            ("warm regards", "\n\nWarm regards,\n"),
            ("sincerely", "\n\nSincerely,\n"),
            ("thanks and regards", "\n\nThanks & regards,\n")
        ]

        for (spoken, formatted) in signoffs {
            if let range = result.range(of: spoken, options: .caseInsensitive) {
                result.replaceSubrange(range, with: formatted)
            }
        }

        return TextStitcher.cleanPunctuationAndSpacing(result)
    }

    private static func formatTerminal(_ text: String) -> String {
        var result = text.lowercased()

        // Spoken CLI flag conversions
        let cliFlags: [(String, String)] = [
            ("hyphen hyphen ", "--"),
            ("double dash ", "--"),
            ("dash ", "-"),
            ("hyphen ", "-"),
            ("pipe ", " | "),
            ("greater than ", " > "),
            ("double greater than ", " >> "),
            ("ampersand ampersand ", " && "),
            ("pseudo ", "sudo ")
        ]

        for (spoken, sym) in cliFlags {
            result = result.replacingOccurrences(of: spoken, with: sym)
        }

        // Remove trailing punctuation in commands
        if result.hasSuffix(".") {
            result.removeLast()
        }

        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
