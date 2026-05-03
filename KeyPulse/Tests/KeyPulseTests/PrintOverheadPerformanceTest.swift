import XCTest
@testable import KeyPulse

/// Performance test for print() overhead
/// Measures the cost of print statements in hot paths
final class PrintOverheadPerformanceTest: XCTestCase {

    func testPrintOverhead() {
        let iterations = 100_000

        // Measure print() overhead
        let startWithPrint = CFAbsoluteTimeGetCurrent()
        for i in 0..<iterations {
            print("KeyboardMonitor: Test message \(i)")
        }
        let endWithPrint = CFAbsoluteTimeGetCurrent()

        // Measure without print (empty loop)
        let startNoPrint = CFAbsoluteTimeGetCurrent()
        for i in 0..<iterations {
            _ = i  // Do something to prevent optimization
        }
        let endNoPrint = CFAbsoluteTimeGetCurrent()

        let withPrintMicroseconds = (endWithPrint - startWithPrint) * 1_000_000
        let noPrintMicroseconds = (endNoPrint - startNoPrint) * 1_000_000
        let printOverhead = withPrintMicroseconds - noPrintMicroseconds
        let avgPerCall = printOverhead / Double(iterations)

        print("METRIC print_overhead_µs=\(String(format: "%.4f", avgPerCall))")
        print("INFO: Average print() overhead: \(String(format: "%.4f", avgPerCall)) µs per call")
        print("INFO: Total with print: \(String(format: ".2f", withPrintMicroseconds)) µs")
        print("INFO: Total without print: \(String(format: ".2f", noPrintMicroseconds)) µs")
        print("INFO: Print overhead: \(String(format: ".2f", printOverhead)) µs total")

        // Regression guard: print overhead under 100µs (baseline ~0.53µs)
        XCTAssertLessThan(avgPerCall, 100.0, "Print overhead under 100µs per call")
    }
}
