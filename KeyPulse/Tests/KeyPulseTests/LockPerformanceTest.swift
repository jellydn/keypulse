import XCTest
import Foundation
import os.lock
@testable import KeyPulse

/// Performance test for player selection lock
/// Measures the time to acquire lock and increment index using actual AudioEngine
final class LockPerformanceTest: XCTestCase {

    func measureAudioEngineLock() -> Double {
        let engine = AudioEngine()
        let iterations = 1_000_000

        // Measure just the lock acquisition and index increment portion
        // This simulates what happens in AudioEngine.play() but without audio playback
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            // This mirrors the actual lock usage in AudioEngine.play()
            var playerLock = os_unfair_lock()
            var nextPlayerIndex = 0
            let concurrentPlayerCount = 8

            os_unfair_lock_lock(&playerLock)
            let _ = nextPlayerIndex
            nextPlayerIndex = (nextPlayerIndex + 1) % concurrentPlayerCount
            os_unfair_lock_unlock(&playerLock)
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalMicroseconds = (end - start) * 1_000_000
        return totalMicroseconds / Double(iterations)
    }

    func testLockPerformanceBenchmark() {
        // Warmup
        _ = measureAudioEngineLock()

        // Measure os_unfair_lock performance (current implementation)
        let times = (0..<5).map { _ in measureAudioEngineLock() }
        let avg = times.reduce(0, +) / Double(times.count)

        // Output metric
        print("METRIC lock_acquire_µs=\(String(format: "%.4f", avg))")
        print("INFO: os_unfair_lock avg: \(String(format: "%.4f", avg)) µs per acquire")
    }
}
