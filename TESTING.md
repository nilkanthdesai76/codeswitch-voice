# TESTING.md — CodeSwitch Voice Test Strategy

> Testing strategies, synthetic audio benchmarks, and linguistic stitching verification.

---

## 🧪 1. Test Strategy

1. **Text Stitching & Token Boundary Tests**:
   - Injects alternating Latin and Devanagari/Hindi string segments (e.g. `"Please review this PR "` + `"bahut achha kaam kiya"` + `" before merging"`) to verify smooth capitalization, spacing, and punctuation rules.
2. **Context Formatter Regex Tests**:
   - Verifies that developer voice shortcuts (`"const data equals await fetch users"`) map correctly to camelCase/snake_case code syntax when target app is an IDE.
3. **Ring Buffer Concurrency Tests**:
   - Stress-tests the lock-free circular audio ring buffer with high-frequency concurrent read and write operations across 8 worker threads to guarantee zero buffer overrun/underrun corruption.

---

## ⚡ 2. Execution Commands

```bash
# Run all unit tests
swift test

# Run text stitching tests specifically
swift test --filter TextStitcherTests
```
