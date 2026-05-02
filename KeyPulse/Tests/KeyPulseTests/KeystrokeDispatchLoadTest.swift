import XCTest
@testable import KeyPulse

/// Performance test for keystroke dispatch under load
/// Simulates rapid typing (120 WPM = ~10 keystrokes/second)
final class KeystrokeDispatchLoadTest: XCTestCase {

    func testKeystrokeDispatchLatency() {
        // Simulate 120 WPM typing: ~10 chars/sec, sustained for 1 second
        let keystrokesPerSecond = 10
        let durationSeconds = 1
        let totalKeystrokes = keystrokesPerSecond * durationSeconds

        var latencies: [Double] = []
        let expectation = self.expectation(description: "All keystrokes processed")
        expectation.expectedFulfillmentCount = totalKeystrokes

        // Use background queue to generate keystrokes (like real CGEventTap callback)
        // while main queue processes them
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<totalKeystrokes {
                let dispatchTime = CFAbsoluteTimeGetCurrent()
                DispatchQueue.main.async {
                    let executionTime = CFAbsoluteTimeGetCurrent()
                    let latencyMs = (executionTime - dispatchTime) * 1000
                    latencies.append(latencyMs)
                    expectation.fulfill()
                }

                // Simulate typing interval (100ms between keystrokes for 120 WPM)
                if i < totalKeystrokes - 1 {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)

        let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
        let maxLatency = latencies.max() ?? 0

        print("METRIC keystroke_dispatch_ms=\(String(format: "%.3f", avgLatency))")
        print("INFO: Average dispatch latency: \(String(format: "%.3f", avgLatency)) ms")
        print("INFO: Max dispatch latency: \(String(format: "%.3f", maxLatency)) ms")
        print("INFO: Total keystrokes: \(latencies.count)")
    }
}
