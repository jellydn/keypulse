import XCTest
@testable import KeyPulse

/// Performance test for AudioEngine startup time
/// Tests if we can optimize the player node pool size for faster startup
final class EngineStartupPerformanceTest: XCTestCase {

    func testEngineStartupTime() throws {
        // Measure engine startup time (creating player nodes)
        let iterations = 10
        var startupTimes: [Double] = []

        for _ in 0..<iterations {
            let engine = AudioEngine()

            let start = CFAbsoluteTimeGetCurrent()
            try engine.start()
            let end = CFAbsoluteTimeGetCurrent()

            let durationMs = (end - start) * 1000
            startupTimes.append(durationMs)

            engine.stop()
        }

        let avgTime = startupTimes.reduce(0, +) / Double(startupTimes.count)
        let maxTime = startupTimes.max() ?? 0
        let minTime = startupTimes.min() ?? 0

        print("METRIC engine_startup_ms=\(String(format: "%.3f", avgTime))")
        print("INFO: Average engine startup time: \(String(format: "%.3f", avgTime)) ms")
        print("INFO: Max startup time: \(String(format: "%.3f", maxTime)) ms")
        print("INFO: Min startup time: \(String(format: "%.3f", minTime)) ms")
        print("INFO: Player node count: 8 (current)")
    }
}
