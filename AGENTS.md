# AGENTS.md — CodeSwitch Voice Operational Manual

> Ground-truth invariants, build/test commands, and rules for AI coding assistants working in `codeswitch-voice`.

---

## 🧭 1. Project Overview
- **Project Name**: `codeswitch-voice`
- **Core Purpose**: Local multilingual dictation engine with real-time acoustic code-switching for macOS.
- **Primary Tech Stack**: Swift 6, CoreML, Apple Neural Engine (ANE), `AVAudioEngine`, SwiftUI.
- **Deployment Targets**: macOS 14.0+ (Sonoma, Sequoia) on Apple Silicon.

---

## ⚡ 2. Verified Execution Commands

```bash
# Build Swift package
swift build

# Run unit tests
swift test

# Run single targeted test
swift test --filter TextStitcherTests

# Build with warnings as errors
swift build -Xswiftc -warnings-as-errors

# Build macOS app target
xcodebuild -scheme CodeSwitchVoice -configuration Debug build
```

---

## 🛡️ 3. Critical Invariants

1. **Strict Audio Ring Buffer Discipline**:
   - Audio callbacks must never block or wait on synchronous locks.
   - Use lock-free atomics and pre-allocated circular buffers for passing audio frames to the ML inference actor.
2. **Swift 6 Strict Concurrency**:
   - The ML inference loop must run inside an isolated actor (`actor CodeSwitchPipelineActor`).
   - All models passed across task boundaries must conform to `Sendable`.
3. **Microphone Privacy**:
   - The microphone icon in the macOS menu bar must cleanly extinguish when the user releases the dictation hotkey.
