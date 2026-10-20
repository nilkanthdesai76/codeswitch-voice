# PRD.md — CodeSwitch Voice (On-Device Multilingual Dictation)

> Product Requirements Document for CodeSwitch Voice: The first local, privacy-guaranteed macOS dictation engine that seamlessly handles mid-sentence language switching (Code-Switching) on Apple Silicon.

---

## 🎯 1. Objective & Problem Statement

### The Problem
Traditional speech-to-text systems (including standard Whisper and Apple Dictation) fail drastically when multilingual speakers code-switch—that is, switching languages mid-sentence (e.g. speaking in English, inserting Hindi/Gujarati phrases, and continuing in English). Standard models lock onto a single language probability token at initialization. When the speaker changes languages, the transcriber either:
- Hallucinates phonetic gibberish in the wrong alphabet.
- Completely drops out and discards the sentence.
- Requires the user to stop, open a menu, and manually toggle input languages.

### The Solution
**CodeSwitch Voice** solves code-switching on-device:
- Runs a dual-stage streaming pipeline: a lightweight 500ms sliding acoustic **Language Identification (LID)** classifier running concurrently with quantized **Whisper v3 Turbo / Apple Speech** decoders.
- When an acoustic language boundary is detected, the audio stream is partitioned at the phoneme boundary, processed by the respective language vocabulary, and unified into a single natural sentence.
- 100% on-device on Apple Silicon Neural Engine (ANE) with zero audio transmission to cloud servers.

---

## 🔬 2. Acoustic Language Identification (LID) Specification

### 2.1 Feature Extraction & Windowing
- **Audio Format**: 16,000 Hz, 16-bit mono PCM.
- **Window Size**: 500 ms ($8,000\text{ samples}$).
- **Hop Size**: 250 ms ($4,000\text{ samples}$), providing $4\text{ classifications/second}$.
- **Feature Representation**: 80-channel log-mel filterbank energies ($0\text{ Hz} - 8000\text{ Hz}$) computed via `Accelerate.vDSP` FFT.

### 2.2 Supported Language Taxonomy
| ISO Code | Language Name | Primary Script | Sample Vocabulary Domain |
| :--- | :--- | :--- | :--- |
| `en` | English | Latin | Technical terminology, syntax, general prose |
| `hi` | Hindi | Devanagari | Colloquial expressions, conversational vernacular |
| `gu` | Gujarati | Gujarati | Regional dialect phrases, conversational speech |
| `es` | Spanish | Latin | Global conversational phrases |
| `fr` | French | Latin | European conversational speech |
| `de` | German | Latin | Compound nouns, technical phrases |
| `zh` | Mandarin | Hanzi (Simplified) | Standard Mandarin conversational |

### 2.3 Boundary Hysteresis Algorithm
To prevent erratic flickering between languages on ambiguous phonemes:
1. The neural classifier outputs a softmax distribution $\mathbf{P}_t = [p_1, p_2, \dots, p_K]$.
2. A language transition from $L_{\text{current}}$ to $L_{\text{candidate}}$ is triggered **only** if:
   $$P(L_{\text{candidate}}) \ge 0.85 \quad \text{for } \ge 2 \text{ consecutive windows (500ms)}$$
3. Once triggered, the phoneme boundary is snapped to the nearest zero-crossing / silence trough identified by the Voice Activity Detector (VAD).

---

## ✍️ 3. Token Stitching & Punctuation Boundary Rules

Merging Latin and non-Latin scripts requires strict Unicode spacing heuristics:

```swift
public final class TextStitcher {
    public static func stitch(fragments: [DecodedFragment]) -> String {
        var output = ""
        for (index, fragment) in fragments.enumerated() {
            let text = fragment.text.trimmingCharacters(in: .whitespaces)
            if index == 0 {
                output += text.capitalizedFirstLetter
                continue
            }
            
            let prevScript = fragments[index - 1].script
            let currScript = fragment.script
            
            // Script spacing rules:
            // Latin -> Devanagari/CJK: Insert single space
            // Devanagari -> Latin: Insert single space
            // CJK -> CJK: Zero space
            if prevScript == .cjk && currScript == .cjk {
                output += text
            } else {
                output += " " + text
            }
        }
        return output
    }
}
```

---

## 💻 4. Active Application Context Rules

When active application is detected via `NSWorkspace.shared.frontmostApplication`:

| Target App Bundle ID | Context Mode | Transformation Rules |
| :--- | :--- | :--- |
| `com.apple.dt.Xcode` | IDE / Swift | `"func", "var", "let", "async await", "guard let"` converted to keyword syntax; camelCase variables |
| `com.microsoft.VSCode` | IDE / Multi | `"const", "interface", "export default"` preserved with snake_case/camelCase options |
| `com.tinyspeck.slackmacgap` | Chat | Auto-capitalization, strips `"um", "uh", "you know"`, converts smiley words to emojis |
| `com.apple.mail` | Formal Email | Full sentence capitalization, converts `"regards", "best"` to structured sign-offs |
| `com.apple.Terminal` | Shell CLI | Lowercase strings, flags converted (`"hyphen hyphen force"` $\to$ `--force`) |

---

## 🚫 5. Non-Goals
- No sending audio to cloud Whisper APIs (100% on-device on Apple Silicon).
- No saving raw audio files to disk.
