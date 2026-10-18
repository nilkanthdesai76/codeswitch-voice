import XCTest
@testable import CodeSwitchVoice

final class RingBufferTests: XCTestCase {

    func testBasicReadWrite() {
        let buffer = LockFreeAudioRingBuffer(capacity: 100)
        let input: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]

        buffer.write(samples: input)
        XCTAssertEqual(buffer.availableCount, 5)

        let read = buffer.read(count: 5)
        XCTAssertNotNil(read)
        XCTAssertEqual(read!, input)
        XCTAssertEqual(buffer.availableCount, 0)
    }

    func testInsufficientDataReturnsNil() {
        let buffer = LockFreeAudioRingBuffer(capacity: 50)
        buffer.write(samples: [0.1, 0.2])
        XCTAssertNil(buffer.read(count: 10))
    }

    func testConcurrentReadAndWrite() {
        let buffer = LockFreeAudioRingBuffer(capacity: 20000)
        let sampleBatch = [Float](repeating: 0.42, count: 100)
        let iterations = 100

        let group = DispatchGroup()

        // Writer queue
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<iterations {
                buffer.write(samples: sampleBatch)
                usleep(100)
            }
            group.leave()
        }

        // Reader queue
        group.enter()
        var totalRead = 0
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<iterations {
                if let read = buffer.read(count: 50) {
                    totalRead += read.count
                }
                usleep(100)
            }
            group.leave()
        }

        group.wait()
        XCTAssertGreaterThan(totalRead, 0)
    }
}
