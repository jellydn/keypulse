import XCTest
@testable import KeyPulse

/// Performance test for profile switching
/// Measures the time to switch between profiles with pre-warmed cache
final class ProfileSwitchPerformanceTest: XCTestCase {

    func testProfileSwitchPerformance() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        // Pre-warm all profiles for instant switching
        try engine.preWarmAllProfiles()

        // Load initial profile
        try engine.loadProfile(.linear)

        let profiles: [SoundProfile] = [.tactile, .clicky, .linear, .tactile, .clicky]
        var switchTimes: [Double] = []

        // Measure profile switching (should be instant with cache)
        for profile in profiles {
            let start = CFAbsoluteTimeGetCurrent()
            try engine.loadProfile(profile)
            let end = CFAbsoluteTimeGetCurrent()

            let durationMs = (end - start) * 1000
            switchTimes.append(durationMs)
        }

        let avgTime = switchTimes.reduce(0, +) / Double(switchTimes.count)
        let maxTime = switchTimes.max() ?? 0
        let minTime = switchTimes.min() ?? 0

        print("METRIC profile_switch_ms=\(String(format: "%.3f", avgTime))")
        print("INFO: Average profile switch time: \(String(format: "%.3f", avgTime)) ms")
        print("INFO: Max profile switch time: \(String(format: "%.3f", maxTime)) ms")
        print("INFO: Min profile switch time: \(String(format: "%.3f", minTime)) ms")
        print("INFO: Pre-warmed: \(engine.isPreWarmed)")
    }
}
