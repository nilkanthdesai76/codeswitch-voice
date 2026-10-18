# CodeSwitch Voice 🎙️🌐

> On-device, privacy-guaranteed multilingual dictation engine that seamlessly handles mid-sentence language switching (Code-Switching) on Apple Silicon.

[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue.svg)](https://developer.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Neural Engine](https://img.shields.io/badge/Hardware-Apple%20Neural%20Engine-purple.svg)](https://apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## ✨ Features

- 🌐 **Real-Time Code-Switching** — Speak in English, switch to Hindi, Spanish, or French mid-sentence, and continue without transcription drop-outs or manual language toggles.
- ⚡ **Acoustic Sliding-Window LID** — 500ms real-time acoustic Language Identification running on the Apple Neural Engine to detect language transitions before decoding.
- 💻 **Context-Aware Formatting** — Dictate directly into Xcode or VS Code to auto-format syntax (`func getUsers() async`), or dictate into Slack/Mail with smart punctuation and filler-word removal.
- 🔒 **100% On-Device Privacy** — Zero audio bytes ever leave your Mac. All inference runs offline with zero cloud subscriptions.
- 🚀 **Floating Notch Indicator** — Minimal HUD behind the MacBook notch displaying live language flags (`🇺🇸 EN` $\leftrightarrow$ `🇮🇳 HI`) and audio energy.

---

## ⚡ Quick Start

```bash
# Clone repository
git clone https://github.com/nilkanthdesai76/codeswitch-voice.git
cd codeswitch-voice

# Build and run tests
swift test

# Build application
swift build -c release
```

---

## 📚 Documentation Pillars
- [PRD.md](PRD.md) — Product specifications and linguistic requirements
- [ARCHITECTURE.md](ARCHITECTURE.md) — Streaming audio pipeline and multi-stream decoding
- [AGENTS.md](AGENTS.md) — Operational instructions for AI coding assistants
- [TESTING.md](TESTING.md) — Multilingual stitching and ring buffer verification
- [SECURITY.md](SECURITY.md) — Ephemeral RAM audio and zero-cloud policies
