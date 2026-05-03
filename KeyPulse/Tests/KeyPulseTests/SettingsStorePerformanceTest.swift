import XCTest
@testable import KeyPulse

/// Performance test for SettingsStore.launchAtLogin getter
/// Measures the time to read the launchAtLogin property (involves SMAppService.status IPC)
final class SettingsStorePerformanceTest: XCTestCase {

    func testLaunchAtLoginReadPerformance() {
        let store = SettingsStore.shared

        // Warmup
        _ = store.launchAtLogin

        // Measure multiple reads
        let iterations = 100
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            _ = store.launchAtLogin
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalMicroseconds = (end - start) * 1_000_000
        let avgMicroseconds = totalMicroseconds / Double(iterations)

        print("METRIC status_read_µs=\(String(format: "%.2f", avgMicroseconds))")
        print("INFO: Average launchAtLogin read time: \(String(format: "%.2f", avgMicroseconds)) µs")
        print("INFO: Total time for \(iterations) reads: \(String(format: "%.2f", totalMicroseconds)) µs")

        // Regression guard: read under 50ms (covers both cached ~0.33µs and uncached ~7ms)
        XCTAssertLessThan(avgMicroseconds, 50000.0, "LaunchAtLogin read under 50ms")
    }
}
