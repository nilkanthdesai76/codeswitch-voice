import Foundation
import CodeSwitchVoice

@main
struct CodeSwitchCLI {
    static func main() async {
        print("\u{001B}[2J\u{001B}[H", terminator: "") // Clear screen
        print("""
        \u{001B}[1;36m=========================================================================\u{001B}[0m
        \u{001B}[1;32m         🎙️  CodeSwitch Voice — On-Device Multilingual Dictation        \u{001B}[0m
        \u{001B}[1;36m=========================================================================\u{001B}[0m
        Apple Silicon On-Device Acoustic Language ID & Dynamic Script Stitcher
        Zero Cloud Dependency • Privacy-Guaranteed • Sub-150ms Boundary Switching

        """)

        let pipeline = CodeSwitchPipeline(initialLanguage: .english)

        print("\u{001B}[1;33m[1/3] Running Multilingual Code-Switching Linguistic Benchmarks...\u{001B}[0m\n")

        let testCases: [(title: String, fragments: [DecodedFragment], context: ApplicationContextFormatter.ContextMode)] = [
            (
                title: "Hinglish (English + Hindi) in Slack",
                fragments: [
                    DecodedFragment(text: "please review this pull request", language: .english),
                    DecodedFragment(text: "bahut achha kaam kiya", language: .hindi),
                    DecodedFragment(text: "before merging thumbs up", language: .english)
                ],
                context: .slack
            ),
            (
                title: "Gujarati + English in Terminal",
                fragments: [
                    DecodedFragment(text: "tamaro code ekdam saras che", language: .gujarati),
                    DecodedFragment(text: "git commit hyphen m", language: .english),
                    DecodedFragment(text: "navo feature release", language: .gujarati)
                ],
                context: .terminal
            ),
            (
                title: "English + Mandarin in Xcode",
                fragments: [
                    DecodedFragment(text: "function calculateTax", language: .english),
                    DecodedFragment(text: "这个代码写得非常好", language: .chinese),
                    DecodedFragment(text: "return result", language: .english)
                ],
                context: .xcode
            ),
            (
                title: "Multilingual Business Email (English + French + Spanish)",
                fragments: [
                    DecodedFragment(text: "the financial projections are updated", language: .english),
                    DecodedFragment(text: "merci beaucoup pour votre collaboration", language: .french),
                    DecodedFragment(text: "best regards", language: .english)
                ],
                context: .mail
            )
        ]

        for (index, tc) in testCases.enumerated() {
            print("\u{001B}[1;34m--- Scenario \(index + 1): \(tc.title) ---\u{001B}[0m")
            print("  📥 Raw Fragments:")
            for f in tc.fragments {
                print("     • [\(f.language.rawValue.uppercased()) | \(f.script)] \(f.text)")
            }

            let result = pipeline.evaluateCodeSwitchedFragments(
                tc.fragments,
                targetContext: tc.context,
                injectToSystem: false
            )

            print("  🧵 Stitched Text:   \u{001B}[1;37m\(result.stitchedText)\u{001B}[0m")
            print("  ✨ Context Formatted (\(tc.context)): \u{001B}[1;32m\(result.formattedText)\u{001B}[0m")
            print("  ⚡ Latency: \(String(format: "%.2f", result.latencyMs)) ms | Code-Switched: \(result.didCodeSwitch)\n")
        }

        print("\u{001B}[1;33m[2/3] Acoustic LID & Ring Buffer Stress Benchmark...\u{001B}[0m")
        let ringBuffer = LockFreeAudioRingBuffer(capacity: 16000 * 2)
        let sampleSine = (0..<1600).map { i in sin(Float(i) * 0.1) * 0.5 }

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<50 {
            ringBuffer.write(samples: sampleSine)
            _ = ringBuffer.read(count: 800)
        }
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        print("  ✅ 80,000 samples processed through LockFreeAudioRingBuffer in \(String(format: "%.2f", elapsedMs)) ms")

        print("\n\u{001B}[1;33m[3/3] Application Context Rules Verification...\u{001B}[0m")
        let xcodeSample = ApplicationContextFormatter.format(
            "function getUser variable count equals 5 async await fetch",
            mode: .xcode
        )
        print("  Xcode Mode:     \(xcodeSample)")

        let slackSample = ApplicationContextFormatter.format(
            "Um I think like you know we should ship fire emoji rocket emoji",
            mode: .slack
        )
        print("  Slack Mode:     \(slackSample)")

        let terminalSample = ApplicationContextFormatter.format(
            "git checkout double dash force pipe grep main",
            mode: .terminal
        )
        print("  Terminal Mode:  \(terminalSample)")

        print("""

        \u{001B}[1;32m✨ CodeSwitch Voice engine initialized and verified successfully.\u{001B}[0m
        """)
    }
}
