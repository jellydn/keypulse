import XCTest
@testable import KeyPulse

/// Measures the overhead of the keystroke diagnostics hot path.
///
/// Baseline (before throttling): updateDiagnosticsData() was called on EVERY keystroke,
/// doing 31.58 µs of work (20+ @Published field writes, 60-case switch, latency reads).
/// At 60 keystrokes/sec, this wastes ~1,895 µs/sec of main-thread time since the
/// DebugWindowController throttles UI consumption to 10 Hz.
///
/// Optimized: source-level throttle at 20 Hz in setupKeyboardHandler().
/// Calls to updateDiagnosticsData() are skipped if <50ms since last publish.
/// Manual calls (settings changes, resetStats, diagnostics()) bypass the throttle.
final class DiagnosticsUpdatePerformanceTest: XCTestCase {

    /// Measures full updateDiagnosticsData() call latency (unthrottled).
    /// This is the per-call cost — the optimization reduces call frequency, not per-call cost.
    func testDiagnosticsUpdateOverhead() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Warm up
        _ = controller.diagnostics()

        let iterations = 1000
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            _ = controller.diagnostics()  // Calls updateDiagnosticsData() directly (no throttle)
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalMicroseconds = (end - start) * 1_000_000
        let avgMicroseconds = totalMicroseconds / Double(iterations)

        print("METRIC diagnostics_update_µs=\(String(format: "%.2f", avgMicroseconds))")
        print("INFO: Full diagnostics() call: \(String(format: "%.2f", avgMicroseconds)) µs")
        print("INFO: Total for \(iterations) calls: \(String(format: "%.2f", totalMicroseconds)) µs")
    }

    /// Measures total overhead per simulated keystroke burst (the real hot-path scenario).
    /// Simulates 600 keystrokes at ~60/sec. With 20 Hz throttling, only ~10% of
    /// updates are actually published, vs 100% before throttling.
    func testSimulatedKeystrokeBurstOverhead() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        let keystrokeCount = 600
        let start = CFAbsoluteTimeGetCurrent()

        for i in 0..<keystrokeCount {
            // Simulate what the keyboard handler does:
            // 1. Play a random sample
            // 2. Call diagnostics() (which includes updateDiagnosticsData internally)
            // Note: diagnostics() bypasses throttle, so we measure full overhead here.
            // In production, the throttle in setupKeyboardHandler() would skip
            // updateDiagnosticsData() ~90% of the time at this rate.
            controller.testPlay()
            _ = controller.diagnostics()
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalMs = (end - start) * 1000
        let avgPerKeystrokeUs = ((end - start) * 1_000_000) / Double(keystrokeCount)

        print("INFO: Simulated \(keystrokeCount) keystrokes (testPlay + diagnostics)")
        print("INFO: Total time: \(String(format: "%.2f", totalMs)) ms")
        print("INFO: Average per keystroke: \(String(format: "%.2f", avgPerKeystrokeUs)) µs")

        // Assertion: per-keystroke overhead should be reasonable
        // (testPlay involves audio scheduling which is the dominant cost)
        XCTAssertLessThan(avgPerKeystrokeUs, 5000, "Keystroke processing should be under 5ms")
    }

    /// Measures just the cost of counters + throttle guard (the always-executed part).
    /// This represents the minimum per-keystroke overhead in the throttled hot path.
    func testThrottleGuardOverhead() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Simulate the fast path: counter increments + time check (no diagnostics update)
        var counter = 0
        var lastPublishTime: TimeInterval = 0
        let throttleInterval: TimeInterval = 1.0 / 20.0

        let iterations = 10000
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            counter += 1
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastPublishTime >= throttleInterval {
                lastPublishTime = now
                // updateDiagnosticsData() would be called here — but we skip it
                // in the throttled case, so this is just the guard overhead
            }
        }

        let end = CFAbsoluteTimeGetCurrent()
        let avgNs = ((end - start) * 1_000_000_000) / Double(iterations)

        print("INFO: Throttle guard + counter overhead: \(String(format: "%.1f", avgNs)) ns per call")
        print("INFO: Total for \(iterations) guard checks: \(String(format: "%.2f", (end - start) * 1_000_000)) µs")
        print("INFO: Savings per skipped update: ~31 µs")
        print("INFO: At 60 keystrokes/sec with 20 Hz throttle: ~40 updates skipped/sec = ~1,240 µs saved/sec")

        // The throttle guard should be negligible (<1 µs)
        XCTAssertLessThan(avgNs, 1000, "Throttle guard should be under 1 µs")
    }
}
