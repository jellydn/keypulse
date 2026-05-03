import XCTest
@testable import KeyPulse

/// Measures the overhead of keyCodeDisplayName() in the keystroke hot path.
///
/// The current implementation uses a 60-case switch statement, called on every
/// keystroke via updateDiagnosticsData(). Even with 20 Hz throttling, that's
/// ~20 calls/sec during fast typing. The key codes are sparse (0-126 with gaps),
/// so a dictionary lookup may be faster than a compiled switch jump table.
final class KeyCodeLookupPerformanceTest: XCTestCase {

    /// Baseline: measure the switch-based keyCodeDisplayName.
    /// Tests common key codes that would be hit during real typing.
    func testSwitchBaselineOverhead() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Common typing key codes (a-z, space, return, punctuation)
        let commonKeys: [UInt16] = [0,1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,
                                    20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,
                                    36,37,38,39,40,41,42,43,44,45,46,47,48,49]

        let iterations = 1000
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            for key in commonKeys {
                _ = controller.keyCodeDisplayName(key)
            }
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalCalls = iterations * commonKeys.count
        let avgNs = ((end - start) * 1_000_000_000) / Double(totalCalls)

        print("METRIC keycode_lookup_ns=\(String(format: "%.1f", avgNs))")
        print("INFO: Switch-based lookup: \(String(format: "%.1f", avgNs)) ns per call")
        print("INFO: Total for \(totalCalls) lookups: \(String(format: "%.2f", (end - start) * 1_000_000)) µs")
        print("INFO: At 60 keystrokes/sec with 20 Hz throttle: ~\(String(format: "%.2f", avgNs * 20 / 1000)) µs/sec")
    }

    /// Benchmark: dictionary-based lookup for comparison.
    func testDictionaryLookupOverhead() {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape", 55: "Command", 56: "Shift",
            57: "Caps Lock", 58: "Option", 59: "Control", 63: "Fn",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
            97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12", 123: "Left Arrow", 124: "Right Arrow",
            125: "Down Arrow", 126: "Up Arrow"
        ]

        let commonKeys: [UInt16] = [0,1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,
                                    20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,
                                    36,37,38,39,40,41,42,43,44,45,46,47,48,49]

        let iterations = 1000
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            for key in commonKeys {
                _ = keyMap[key] ?? "Key \(key)"
            }
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalCalls = iterations * commonKeys.count
        let avgNs = ((end - start) * 1_000_000_000) / Double(totalCalls)

        print("INFO: Dictionary lookup: \(String(format: "%.1f", avgNs)) ns per call")
        print("INFO: Total for \(totalCalls) lookups: \(String(format: "%.2f", (end - start) * 1_000_000)) µs")
    }

    /// Tests a miss case (key code not in map) — important because unknown keys
    /// return "Key \(keyCode)" via the default case, which requires string interpolation.
    func testDictionaryLookupWithMisses() {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 49: "Space", 36: "Return"
        ]

        // Mix of hits and misses
        let mixedKeys: [UInt16] = [0, 1, 49, 36, 100, 200, 255, 50, 51, 52]

        let iterations = 5000
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            for key in mixedKeys {
                _ = keyMap[key] ?? "Key \(key)"
            }
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalCalls = iterations * mixedKeys.count
        let avgNs = ((end - start) * 1_000_000_000) / Double(totalCalls)

        print("INFO: Dict lookup with misses: \(String(format: "%.1f", avgNs)) ns per call")
    }
}
