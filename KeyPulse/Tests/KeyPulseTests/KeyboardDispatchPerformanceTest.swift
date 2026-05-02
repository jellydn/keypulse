import XCTest
@testable import KeyPulse

/// Performance test for keyboard event dispatch latency
/// Measures the time from event callback to handler execution
final class KeyboardDispatchPerformanceTest: XCTestCase {

    func testMainQueueDispatchLatency() {
        let iterations = 1000
        var latencies: [Double] = []

        // Warmup
        for _ in 0..<10 {
            let start = CFAbsoluteTimeGetCurrent()
            DispatchQueue.main.async {
                _ = CFAbsoluteTimeGetCurrent()
            }
        }

        // Measure main queue dispatch latency
        let expectation = self.expectation(description: "Dispatch completed")
        expectation.expectedFulfillmentCount = iterations

        for _ in 0..<iterations {
            let dispatchTime = CFAbsoluteTimeGetCurrent()
            DispatchQueue.main.async {
                let executionTime = CFAbsoluteTimeGetCurrent()
                let latency = (executionTime - dispatchTime) * 1_000_000 // Convert to microseconds
                latencies.append(latency)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)

        let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
        let maxLatency = latencies.max() ?? 0
        let minLatency = latencies.min() ?? 0

        print("METRIC dispatch_latency_µs=\(String(format: "%.2f", avgLatency))")
        print("INFO: Average dispatch latency: \(String(format: "%.2f", avgLatency)) µs")
        print("INFO: Max dispatch latency: \(String(format: "%.2f", maxLatency)) µs")
        print("INFO: Min dispatch latency: \(String(format: "%.2f", minLatency)) µs")
        print("INFO: Samples: \(latencies.count)")
    }
}
