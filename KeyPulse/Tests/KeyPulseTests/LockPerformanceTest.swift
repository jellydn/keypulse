import XCTest
import Foundation
import os.lock
@testable import KeyPulse

/// Performance test for player selection lock
/// Measures the time to acquire lock and increment index
final class LockPerformanceTest: XCTestCase {

    func measureNSLock() -> Double {
        let lock = NSLock()
        var index = 0
        let iterations = 1_000_000
        let concurrentCount = 8

        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            lock.lock()
            index = (index + 1) % concurrentCount
            lock.unlock()
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalMicroseconds = (end - start) * 1_000_000
        return totalMicroseconds / Double(iterations)
    }

    func measureOSUnfairLock() -> Double {
        var lock = os_unfair_lock()
        var index = 0
        let iterations = 1_000_000
        let concurrentCount = 8

        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            os_unfair_lock_lock(&lock)
            index = (index + 1) % concurrentCount
            os_unfair_lock_unlock(&lock)
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalMicroseconds = (end - start) * 1_000_000
        return totalMicroseconds / Double(iterations)
    }

    func testLockPerformanceBenchmark() {
        // Warmup
        _ = measureNSLock()
        _ = measureOSUnfairLock()

        // Measure NSLock
        let nsLockTimes = (0..<5).map { _ in measureNSLock() }
        let nsLockAvg = nsLockTimes.reduce(0, +) / Double(nsLockTimes.count)

        // Measure os_unfair_lock
        let unfairTimes = (0..<5).map { _ in measureOSUnfairLock() }
        let unfairAvg = unfairTimes.reduce(0, +) / Double(unfairTimes.count)

        // Output metric
        print("METRIC lock_acquire_µs=\(String(format: "%.4f", nsLockAvg))")
        print("INFO: NSLock avg: \(String(format: "%.4f", nsLockAvg)) µs")
        print("INFO: os_unfair_lock avg: \(String(format: "%.4f", unfairAvg)) µs")
        print("INFO: Improvement: \(String(format: "%.1f", (nsLockAvg / unfairAvg)))x faster")
    }
}
