import XCTest
@testable import KeyPulse

/// Performance test for pitch randomization
/// Measures the overhead of Float.random(in:) for pitch variation
final class PitchRandomizationPerformanceTest: XCTestCase {

    func testPitchRandomizationPerformance() {
        let range: ClosedRange<Float> = 0.95...1.05
        let iterations = 100_000

        var rates: [Float] = []
        rates.reserveCapacity(iterations)

        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            let rate = Float.random(in: range)
            rates.append(rate)
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalMicroseconds = (end - start) * 1_000_000
        let avgMicroseconds = totalMicroseconds / Double(iterations)

        print("METRIC pitch_randomization_µs=\(String(format: "%.4f", avgMicroseconds))")
        print("INFO: Average pitch randomization time: \(String(format: "%.4f", avgMicroseconds)) µs")
        print("INFO: Total time for \(iterations) iterations: \(String(format: "%.2f", totalMicroseconds)) µs")

        // Verify randomness quality (basic check)
        let avgRate = rates.reduce(0, +) / Float(rates.count)
        print("INFO: Average rate value: \(avgRate) (expected ~1.0)")

        // Regression guard: randomization under 100µs (baseline ~0.36µs)
        XCTAssertLessThan(avgMicroseconds, 100.0, "Pitch randomization under 100µs")
        XCTAssertGreaterThan(avgRate, 0.94)
        XCTAssertLessThan(avgRate, 1.06)
    }
}
