# SECURITY.md — CodeSwitch Voice Privacy & Audio Isolation

> Microphone privacy and zero-cloud audio architecture for CodeSwitch Voice.

---

## 🔒 1. Zero Cloud Egress

- **Local Inference Guarantee**: All speech recognition, language identification, and formatting models run 100% locally on the Apple Neural Engine.
- **Ephemeral RAM Audio**: PCM audio frames are streamed into volatile circular memory buffers. Once transcribed into text, the raw audio samples are immediately overwritten and zeroed.
- **No Disk Logging**: Raw audio recordings are never persisted to disk, caches, or temporary directories.
