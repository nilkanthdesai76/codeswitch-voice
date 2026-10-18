import Foundation

/// Primary Unicode script families for punctuation and spacing rules.
public enum ScriptType: String, Sendable, Codable {
    case latin
    case devanagari
    case gujarati
    case cjk
    case other

    public static func detect(from text: String) -> ScriptType {
        for scalar in text.unicodeScalars {
            let val = scalar.value
            // Devanagari range: 0x0900 - 0x097F
            if val >= 0x0900 && val <= 0x097F {
                return .devanagari
            }
            // Gujarati range: 0x0A80 - 0x0AFF
            if val >= 0x0A80 && val <= 0x0AFF {
                return .gujarati
            }
            // CJK Unified Ideographs: 0x4E00 - 0x9FFF
            if (val >= 0x4E00 && val <= 0x9FFF) || (val >= 0x3400 && val <= 0x4DBF) {
                return .cjk
            }
        }
        return .latin
    }
}

/// Supported languages with taxonomy.
public enum SupportedLanguage: String, CaseIterable, Sendable, Codable {
    case english = "en"
    case hindi = "hi"
    case gujarati = "gu"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chinese = "zh"

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .hindi: return "Hindi"
        case .gujarati: return "Gujarati"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .chinese: return "Mandarin"
        }
    }

    public var script: ScriptType {
        switch self {
        case .english, .spanish, .french, .german: return .latin
        case .hindi: return .devanagari
        case .gujarati: return .gujarati
        case .chinese: return .cjk
        }
    }
}

/// A transcribed fragment resulting from an acoustic segment.
public struct DecodedFragment: Sendable, Codable, Equatable {
    public let text: String
    public let language: SupportedLanguage
    public let script: ScriptType
    public let confidence: Float
    public let startTimeSec: Double
    public let durationSec: Double

    public init(
        text: String,
        language: SupportedLanguage,
        script: ScriptType? = nil,
        confidence: Float = 0.95,
        startTimeSec: Double = 0.0,
        durationSec: Double = 0.0
    ) {
        self.text = text
        self.language = language
        self.script = script ?? language.script
        self.confidence = confidence
        self.startTimeSec = startTimeSec
        self.durationSec = durationSec
    }
}

/// Aggregated result of a code-switched utterance.
public struct TranscriptionResult: Sendable, Codable, Equatable {
    public let originalFragments: [DecodedFragment]
    public let stitchedText: String
    public let formattedText: String
    public let detectedLanguages: [SupportedLanguage]
    public let didCodeSwitch: Bool
    public let latencyMs: Double

    public init(
        originalFragments: [DecodedFragment],
        stitchedText: String,
        formattedText: String,
        detectedLanguages: [SupportedLanguage],
        didCodeSwitch: Bool,
        latencyMs: Double
    ) {
        self.originalFragments = originalFragments
        self.stitchedText = stitchedText
        self.formattedText = formattedText
        self.detectedLanguages = detectedLanguages
        self.didCodeSwitch = didCodeSwitch
        self.latencyMs = latencyMs
    }
}
