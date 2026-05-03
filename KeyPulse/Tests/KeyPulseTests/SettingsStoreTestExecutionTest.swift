import XCTest
@testable import KeyPulse

/// Performance test for SettingsStore test execution
/// Measures the overhead of singleton-based test isolation
final class SettingsStoreTestExecutionTest: XCTestCase {

    func testSettingsStoreExecutionTime() {
        let iterations = 50
        var executionTimes: [Double] = []

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()

            // Simulate a typical SettingsStore test pattern
            let store = SettingsStore.shared
            let originalProfile = store.profile
            let originalVolume = store.volume
            let originalEnabled = store.isEnabled

            // Modify settings
            store.profile = .tactile
            store.volume = 75
            store.isEnabled = false

            // Reset to defaults (common pattern in tests)
            store.resetToDefaults()

            // Verify reset
            _ = store.profile == .linear
            _ = store.volume == 100
            _ = store.isEnabled == true

            let end = CFAbsoluteTimeGetCurrent()
            let durationMs = (end - start) * 1000
            executionTimes.append(durationMs)

            // Restore original values
            store.profile = originalProfile
            store.volume = originalVolume
            store.isEnabled = originalEnabled
        }

        let avgTime = executionTimes.reduce(0, +) / Double(executionTimes.count)
        let maxTime = executionTimes.max() ?? 0
        let minTime = executionTimes.min() ?? 0

        print("METRIC test_execution_ms=\(String(format: "%.3f", avgTime))")
        print("INFO: Average test execution time: \(String(format: "%.3f", avgTime)) ms")
        print("INFO: Max execution time: \(String(format: "%.3f", maxTime)) ms")
        print("INFO: Min execution time: \(String(format: "%.3f", minTime)) ms")
        print("INFO: Iterations: \(executionTimes.count)")

        // Regression guard: test execution under 10ms (baseline ~0.43ms)
        XCTAssertLessThan(avgTime, 10.0, "SettingsStore test execution under 10ms")
        XCTAssertLessThan(maxTime, 50.0, "Max test execution under 50ms")
    }
}
