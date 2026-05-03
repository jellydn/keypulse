import XCTest
@testable import KeyPulse

/// Performance test for audio latency
/// Measures the trigger-to-output latency in AudioEngine.play()
final class AudioLatencyPerformanceTest: XCTestCase {

    func testAudioLatency() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        // Load a profile
        try engine.loadProfile(.linear)

        // Warmup - play a few samples to stabilize
        for i in 0..<4 {
            try? engine.play(sampleIndex: i)
        }

        // Clear measurements after warmup
        engine.resetLatencyMeasurements()

        // Collect latency measurements
        let playCount = 100
        for i in 0..<playCount {
            let index = i % 4  // Cycle through 4 samples
            try? engine.play(sampleIndex: index)
        }

        // Calculate average latency in milliseconds
        let avgLatencySeconds = engine.averageLatency
        let avgLatencyMs = avgLatencySeconds * 1000
        let maxLatencyMs = engine.maxLatency * 1000
        let minLatencyMs = engine.minLatency * 1000

        print("METRIC audio_latency_ms=\(String(format: "%.3f", avgLatencyMs))")
        print("INFO: Average latency: \(String(format: "%.3f", avgLatencyMs)) ms")
        print("INFO: Max latency: \(String(format: "%.3f", maxLatencyMs)) ms")
        print("INFO: Min latency: \(String(format: "%.3f", minLatencyMs)) ms")
        print("INFO: Samples collected: \(engine.latencyMeasurementCount)")

        // Regression guard: latency must stay under generous threshold (target <20ms)
        XCTAssertLessThan(avgLatencyMs, 50.0, "Average latency must be under 50ms")
        XCTAssertLessThan(maxLatencyMs, 200.0, "Max latency must be under 200ms")
        XCTAssertEqual(engine.latencyMeasurementCount, playCount)
    }
}
