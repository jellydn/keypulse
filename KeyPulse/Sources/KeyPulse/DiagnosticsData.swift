import Foundation

/// Data structure containing real-time diagnostics for the Debug Window.
/// Published by KeyPulseController for Combine-based UI binding.
struct DiagnosticsData {
    /// Reads a value from the main bundle's Info.plist.
    private static func bundleString(_ key: String, fallback: String) -> String {
        Bundle.main.infoDictionary?[key] as? String ?? fallback
    }


    /// Total number of keystrokes detected
    var totalKeystrokes: Int = 0

    /// Last key code received (0 for modifier events — check isLastKeyModifier instead)
    var lastKeyCode: UInt16 = 0

    /// Whether the last keystroke was a modifier key (flagsChanged)
    var isLastKeyModifier: Bool = false

    /// Display name for the last key (e.g., "Space", "Shift (Modifier)")
    var lastKeyDisplayName: String = "-"

    /// Currently active profile
    var activeProfile: SoundProfile = .linear

    /// Index of the last sample played
    var lastSampleIndex: Int = 0

    /// Filename of the last sample played
    var lastSampleFilename: String = "-"

    /// Latency statistics (in milliseconds)
    var latencyAverageMs: Double = 0
    var latencyMinMs: Double = 0
    var latencyMaxMs: Double = 0
    var latencySampleCount: Int = 0

    /// Current modifier flags state
    var isShiftPressed: Bool = false
    var isCommandPressed: Bool = false
    var isOptionPressed: Bool = false
    var isControlPressed: Bool = false

    /// Current settings state
    var volumePercent: Int = 100
    var isMuted: Bool = false
    var isPitchVariationEnabled: Bool = true

    /// App and system info (read dynamically from Bundle.main)
    var bundleIdentifier: String = DiagnosticsData.bundleString(kCFBundleIdentifierKey as String, fallback: "com.keypulse.app")
    var appVersion: String = DiagnosticsData.bundleString("CFBundleShortVersionString", fallback: "0.1.0")
    var buildNumber: String = DiagnosticsData.bundleString(kCFBundleVersionKey as String, fallback: "1")
    var macOSVersion: String = ProcessInfo.processInfo.operatingSystemVersionString

    /// Whether the controller is currently enabled
    var isEnabled: Bool = true

    /// Formatted diagnostics text for clipboard copying
    func formattedDiagnostics() -> String {
        """
        KeyPulse Diagnostics Report
        ===========================

        App Information:
        - Bundle ID: \(bundleIdentifier)
        - Version: \(appVersion) (Build \(buildNumber))
        - macOS: \(macOSVersion)

        Runtime Statistics:
        - Total Keystrokes: \(totalKeystrokes)
        - Last Key: \(lastKeyDisplayName) (Code: \(lastKeyCode), Hex: 0x\(String(format: "%02X", lastKeyCode)))
        - Last Sample: \(lastSampleFilename) (Index: \(lastSampleIndex))

        Performance:
        - Average Latency: \(String(format: "%.3f", latencyAverageMs)) ms
        - Min Latency: \(String(format: "%.3f", latencyMinMs)) ms
        - Max Latency: \(String(format: "%.3f", latencyMaxMs)) ms
        - Samples: \(latencySampleCount)
        - Target: < 20ms
        - Status: \(latencyAverageMs < 20 ? "PASS" : "FAIL")

        Current Settings:
        - Profile: \(activeProfile.displayName)
        - Volume: \(volumePercent)%
        - Muted: \(isMuted ? "Yes" : "No")
        - Pitch Variation: \(isPitchVariationEnabled ? "On" : "Off")
        - Enabled: \(isEnabled ? "Yes" : "No")

        Modifier Flags:
        - Shift: \(isShiftPressed ? "Pressed" : "Released")
        - Command: \(isCommandPressed ? "Pressed" : "Released")
        - Option: \(isOptionPressed ? "Pressed" : "Released")
        - Control: \(isControlPressed ? "Pressed" : "Released")

        Generated: \(Date())
        """
    }
}

/// Extension to make DiagnosticsData equatable for @Published change detection.
/// All fields are compared so that @Published correctly detects every change.
/// A partial comparison would silently suppress UI updates for omitted fields.
extension DiagnosticsData: Equatable {
    static func == (lhs: DiagnosticsData, rhs: DiagnosticsData) -> Bool {
        lhs.totalKeystrokes == rhs.totalKeystrokes &&
        lhs.lastKeyCode == rhs.lastKeyCode &&
        lhs.isLastKeyModifier == rhs.isLastKeyModifier &&
        lhs.lastKeyDisplayName == rhs.lastKeyDisplayName &&
        lhs.activeProfile == rhs.activeProfile &&
        lhs.lastSampleIndex == rhs.lastSampleIndex &&
        lhs.lastSampleFilename == rhs.lastSampleFilename &&
        lhs.latencyAverageMs == rhs.latencyAverageMs &&
        lhs.latencyMinMs == rhs.latencyMinMs &&
        lhs.latencyMaxMs == rhs.latencyMaxMs &&
        lhs.latencySampleCount == rhs.latencySampleCount &&
        lhs.isShiftPressed == rhs.isShiftPressed &&
        lhs.isCommandPressed == rhs.isCommandPressed &&
        lhs.isOptionPressed == rhs.isOptionPressed &&
        lhs.isControlPressed == rhs.isControlPressed &&
        lhs.volumePercent == rhs.volumePercent &&
        lhs.isMuted == rhs.isMuted &&
        lhs.isPitchVariationEnabled == rhs.isPitchVariationEnabled &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.appVersion == rhs.appVersion &&
        lhs.buildNumber == rhs.buildNumber &&
        lhs.macOSVersion == rhs.macOSVersion &&
        lhs.isEnabled == rhs.isEnabled
    }
}
