import XCTest
@testable import KeyPulse

/// Performance test for audio profile loading
/// Measures time to load a profile (synchronous, on main thread)
final class ProfileLoadPerformanceTest: XCTestCase {

    func testProfileLoadPerformance() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        // Warmup - preload once to cache any file system operations
        _ = try? engine.loadProfile(.linear)

        // Measure loading each profile
        let profiles: [SoundProfile] = [.linear, .tactile, .clicky]
        var totalTime: Double = 0
        var iterationCount = 0

        for profile in profiles {
            // Measure multiple iterations per profile
            for _ in 0..<5 {
                let start = CFAbsoluteTimeGetCurrent()
                try engine.loadProfile(profile)
                let end = CFAbsoluteTimeGetCurrent()

                let durationMs = (end - start) * 1000
                totalTime += durationMs
                iterationCount += 1
            }
        }

        let avgMs = totalTime / Double(iterationCount)
        print("METRIC profile_load_ms=\(String(format: "%.3f", avgMs))")
        print("INFO: Average profile load time: \(String(format: "%.3f", avgMs)) ms")
        print("INFO: Total iterations: \(iterationCount)")
    }
}
