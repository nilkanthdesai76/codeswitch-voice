import Foundation
import os

/// High-performance thread-safe circular audio ring buffer.
/// Decouples real-time audio recording callbacks from downstream neural LID and transcription queues.
public final class LockFreeAudioRingBuffer: @unchecked Sendable {
    private let capacity: Int
    private let buffer: UnsafeMutablePointer<Float>
    private var writeHead: Int = 0
    private var readHead: Int = 0
    private var countStored: Int = 0
    private var lock = os_unfair_lock_s()

    public init(capacity: Int = 16000 * 10) { // Default 10 seconds of 16kHz mono audio
        self.capacity = capacity
        self.buffer = .allocate(capacity: capacity)
        self.buffer.initialize(repeating: 0.0, count: capacity)
    }

    deinit {
        buffer.deinitialize(count: capacity)
        buffer.deallocate()
    }

    /// Number of available samples waiting to be read.
    public var availableCount: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return countStored
    }

    /// Write raw PCM Float32 audio samples into the ring buffer.
    /// Drops older samples if capacity is exceeded to avoid blocking audio thread.
    public func write(samples: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        for i in 0..<count {
            buffer[(writeHead + i) % capacity] = samples[i]
        }

        writeHead = (writeHead + count) % capacity
        countStored = min(capacity, countStored + count)
        if countStored == capacity {
            // Write caught up with read; advance read head
            readHead = writeHead
        }
    }

    /// Write from Swift Array.
    public func write(samples: [Float]) {
        samples.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                write(samples: base, count: ptr.count)
            }
        }
    }

    /// Read requested number of samples into output buffer.
    /// Returns true if count samples were successfully copied, or false if insufficient data.
    public func read(into output: UnsafeMutablePointer<Float>, count: Int) -> Bool {
        guard count > 0 else { return true }
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard countStored >= count else { return false }

        for i in 0..<count {
            output[i] = buffer[(readHead + i) % capacity]
        }

        readHead = (readHead + count) % capacity
        countStored -= count
        return true
    }

    /// Read requested number of samples into a Swift Array.
    public func read(count: Int) -> [Float]? {
        guard count > 0 else { return [] }
        var result = [Float](repeating: 0.0, count: count)
        let success = result.withUnsafeMutableBufferPointer { ptr -> Bool in
            guard let base = ptr.baseAddress else { return false }
            return read(into: base, count: count)
        }
        return success ? result : nil
    }

    /// Peek at available samples without advancing read head.
    public func peek(count: Int) -> [Float]? {
        guard count > 0 else { return [] }
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard countStored >= count else { return nil }

        var result = [Float](repeating: 0.0, count: count)
        for i in 0..<count {
            result[i] = buffer[(readHead + i) % capacity]
        }
        return result
    }

    /// Clears all stored audio.
    public func clear() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        writeHead = 0
        readHead = 0
        countStored = 0
    }
}
