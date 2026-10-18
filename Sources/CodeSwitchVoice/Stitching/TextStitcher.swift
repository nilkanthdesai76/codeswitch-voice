import Foundation

/// Merges decoded multilingual text fragments into a single coherent sentence.
/// Enforces Unicode script spacing, punctuation attachment, and capitalization rules.
public final class TextStitcher: Sendable {

    /// Stitches an array of decoded fragments into a natural formatted string.
    public static func stitch(fragments: [DecodedFragment]) -> String {
        guard !fragments.isEmpty else { return "" }

        var output = ""
        var prevScript: ScriptType? = nil

        for (index, fragment) in fragments.enumerated() {
            var text = fragment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let currScript = fragment.script

            if index == 0 || output.isEmpty {
                text = capitalizeFirstLetter(text)
                output += text
            } else {
                guard let lastScript = prevScript else {
                    output += text
                    prevScript = currScript
                    continue
                }

                // Check script boundary spacing
                if lastScript == .cjk && currScript == .cjk {
                    // CJK characters do not have whitespace delimiters
                    output += text
                } else {
                    // Standard inter-script space (Latin <-> Devanagari, Latin <-> CJK, Devanagari <-> CJK)
                    // Unless the current fragment begins with a punctuation symbol
                    if let firstChar = text.first, isPunctuation(firstChar) {
                        output += text
                    } else {
                        output += " " + text
                    }
                }
            }

            prevScript = currScript
        }

        return cleanPunctuationAndSpacing(output)
    }

    /// Capitalize first character of text.
    public static func capitalizeFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Clean up common punctuation spacing defects.
    public static func cleanPunctuationAndSpacing(_ raw: String) -> String {
        var text = raw

        // Remove space before punctuation marks: " ," -> ",", " ." -> "."
        let punctuationMarks = [".", ",", "!", "?", ":", ";", ")", "]", "}"]
        for p in punctuationMarks {
            text = text.replacingOccurrences(of: " " + p, with: p)
        }

        // Fix opening parenthesis spacing: "( " -> "("
        let openBrackets = ["(", "[", "{"]
        for b in openBrackets {
            text = text.replacingOccurrences(of: b + " ", with: b)
        }

        // Collapse multiple spaces
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }

        // Capitalize words following sentence-ending punctuation: ". word" -> ". Word"
        let sentenceEnders: [Character] = [".", "!", "?"]
        var chars = Array(text)
        var capitalizeNext = false

        for i in 0..<chars.count {
            let ch = chars[i]
            if sentenceEnders.contains(ch) {
                capitalizeNext = true
            } else if capitalizeNext && ch.isLetter {
                chars[i] = Character(ch.uppercased())
                capitalizeNext = false
            } else if capitalizeNext && ch.isWhitespace {
                // keep waiting for next letter
                continue
            } else if capitalizeNext {
                // Parentheses or other symbols cancel direct sentence capitalization
                capitalizeNext = false
            }
        }

        return String(chars).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isPunctuation(_ ch: Character) -> Bool {
        return ch.isPunctuation || [".", ",", "!", "?", ":", ";"].contains(ch)
    }
}
