import Foundation
import os.log

/// Structured logging categories for KeyPulse.
/// Each extension provides a category-specific Logger for subsystem "com.keypulse.app".
///
/// Usage:
///   Logger.audioEngine.info("Started audio engine")
///   Logger.keyboardMonitor.error("Failed to create event tap")
///   Logger.appDelegate.debug("Profile changed to \(profile.displayName)")
///
/// Log levels:
///   .debug  — verbose state changes useful during development
///   .info   — lifecycle events (start, stop, wake, init)
///   .error  — failures that need attention
///
/// All logs are visible in Console.app filtered by subsystem "com.keypulse.app".
extension Logger {
    /// Subsystem identifier matching the app's bundle ID.
    private static let subsystem = "com.keypulse.app"

    /// Audio engine lifecycle and playback events.
    static let audioEngine = Logger(subsystem: subsystem, category: "AudioEngine")

    /// Keyboard event monitoring and CGEventTap lifecycle.
    static let keyboardMonitor = Logger(subsystem: subsystem, category: "KeyboardMonitor")

    /// App delegate: initialization, settings sync, callbacks.
    static let appDelegate = Logger(subsystem: subsystem, category: "AppDelegate")

    /// Settings persistence and SMAppService integration.
    static let settingsStore = Logger(subsystem: subsystem, category: "SettingsStore")

    /// Menu bar UI actions (profile change, volume, mute).
    static let menuBarManager = Logger(subsystem: subsystem, category: "MenuBarManager")

    /// Sound asset loading and validation.
    static let soundAssets = Logger(subsystem: subsystem, category: "SoundAssets")
}
