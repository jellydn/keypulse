import Foundation
import ServiceManagement
import os.log

/// Persistent storage for user settings using UserDefaults.
/// Handles saving and loading of profile, volume, mute state, and enabled state.
/// Conforms to ObservableObject so SwiftUI views can bind to it via @ObservedObject.
final class SettingsStore: ObservableObject {
    /// Shared singleton instance for app-wide settings access (uses UserDefaults.standard).
    static let shared = SettingsStore()

    /// The UserDefaults instance backing this store.
    /// Injectable for test isolation; defaults to .standard for production use.
    private let defaults: UserDefaults

    /// Cache for SMAppService status to avoid expensive IPC on every read.
    /// Updated when setter is called or when explicitly refreshed.
    private var cachedLaunchAtLoginStatus: Bool?

    /// Timestamp of last status cache update.
    private var lastStatusCacheTime: Date?

    /// Cache validity duration (5 seconds) - balance between freshness and performance.
    private let statusCacheValidity: TimeInterval = 5.0

    /// UserDefaults keys for stored settings.
    private enum Keys {
        static let schemaVersion = "keypulse_schemaVersion"
        static let profile = "keypulse_profile"
        static let volume = "keypulse_volume"
        static let isMuted = "keypulse_isMuted"
        static let isEnabled = "keypulse_isEnabled"
        static let pitchRandomization = "keypulse_pitchRandomization"
        static let launchAtLogin = "keypulse_launchAtLogin"
    }

    /// Current settings schema version. Increment when adding/renaming/removing keys
    /// and add a migration in migrateIfNeeded().
    private static let currentSchemaVersion = 1

    /// Default values for settings.
    private enum Defaults {
        static let profile: SoundProfile = .linear
        static let volume: Int = 100
        static let isMuted: Bool = false
        static let isEnabled: Bool = true
        static let pitchRandomization: Bool = true
        static let launchAtLogin: Bool = false
    }

    /// The current sound profile.
    var profile: SoundProfile {
        get {
            if let rawValue = defaults.string(forKey: Keys.profile),
               let profile = SoundProfile(rawValue: rawValue) {
                return profile
            }
            return Defaults.profile
        }
        set {
            objectWillChange.send()
            defaults.set(newValue.rawValue, forKey: Keys.profile)
        }
    }

    /// The current volume level (0-100).
    var volume: Int {
        get {
            // Check if key exists to distinguish between 0 and not set
            if defaults.object(forKey: Keys.volume) == nil {
                return Defaults.volume
            }
            let storedValue = defaults.integer(forKey: Keys.volume)
            return clamp(storedValue, min: 0, max: 100)
        }
        set {
            objectWillChange.send()
            defaults.set(clamp(newValue, min: 0, max: 100), forKey: Keys.volume)
        }
    }

    /// Whether the audio is muted.
    var isMuted: Bool {
        get {
            // Check if key exists to distinguish between false and not set
            if defaults.object(forKey: Keys.isMuted) == nil {
                return Defaults.isMuted
            }
            return defaults.bool(forKey: Keys.isMuted)
        }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Keys.isMuted)
        }
    }

    /// Whether KeyPulse is enabled (processing keystrokes).
    var isEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isEnabled) == nil {
                return Defaults.isEnabled
            }
            return defaults.bool(forKey: Keys.isEnabled)
        }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Keys.isEnabled)
        }
    }

    /// Whether pitch randomization is enabled (subtle variation per keystroke).
    var pitchRandomization: Bool {
        get {
            if defaults.object(forKey: Keys.pitchRandomization) == nil {
                return Defaults.pitchRandomization
            }
            return defaults.bool(forKey: Keys.pitchRandomization)
        }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Keys.pitchRandomization)
        }
    }

    /// Whether the app should launch at login.
    /// This property syncs with SMAppService to reflect the actual system registration state.
    /// Uses cached status to avoid expensive IPC calls on every read.
    var launchAtLogin: Bool {
        get {
            // Check if we have a valid cached status
            if let cached = cachedLaunchAtLoginStatus,
               let lastUpdate = lastStatusCacheTime,
               Date().timeIntervalSince(lastUpdate) < statusCacheValidity {
                return cached
            }

            // Cache miss or expired - query the actual system state via SMAppService
            let serviceStatus = SMAppService.mainApp.status
            let isRegistered = (serviceStatus == .enabled)

            // Update cache
            cachedLaunchAtLoginStatus = isRegistered
            lastStatusCacheTime = Date()

            // Check if key exists in UserDefaults (first-time sync)
            if defaults.object(forKey: Keys.launchAtLogin) == nil {
                // If system says it's registered, update our stored value
                if isRegistered {
                    defaults.set(true, forKey: Keys.launchAtLogin)
                }
            }

            return isRegistered
        }
        set {
            objectWillChange.send()

            // Sync with SMAppService
            let service = SMAppService.mainApp

            // Update cache optimistically
            cachedLaunchAtLoginStatus = newValue
            lastStatusCacheTime = Date()

            if newValue {
                // Register for launch at login
                if service.status != .enabled {
                    do {
                        try service.register()
                        defaults.set(true, forKey: Keys.launchAtLogin)
                    } catch {
                        Logger.settingsStore.error("Failed to register for launch at login: \(error.localizedDescription)")
                        // Invalidate cache on failure so next read queries fresh state
                        cachedLaunchAtLoginStatus = nil
                    }
                }
            } else {
                // Unregister from launch at login
                if service.status == .enabled {
                    do {
                        try service.unregister()
                        defaults.set(false, forKey: Keys.launchAtLogin)
                    } catch {
                        Logger.settingsStore.error("Failed to unregister from launch at login: \(error.localizedDescription)")
                        // Invalidate cache on failure so next read queries fresh state
                        cachedLaunchAtLoginStatus = nil
                    }
                }
            }
        }
    }

    /// Forces a refresh of the launch at login status from SMAppService.
    /// Call this when the app becomes active or when you need guaranteed fresh state.
    func refreshLaunchAtLoginStatus() {
        cachedLaunchAtLoginStatus = nil
        lastStatusCacheTime = nil
        _ = launchAtLogin  // Trigger a fresh read
    }

    /// Loads all settings and returns them as a tuple.
    /// - Returns: Tuple containing (profile, volume, isMuted, isEnabled).
    func loadAllSettings() -> (profile: SoundProfile, volume: Int, isMuted: Bool, isEnabled: Bool) {
        return (profile, volume, isMuted, isEnabled)
    }

    /// Saves all settings from a controller's current state.
    /// - Parameter controller: The KeyPulseController to read state from.
    func saveFromController(_ controller: KeyPulseController) {
        profile = controller.currentProfile
        volume = controller.volume
        isMuted = controller.isMuted
        isEnabled = controller.isEnabled
        pitchRandomization = controller.pitchRandomization
    }

    /// Applies stored settings to a controller.
    /// - Parameter controller: The KeyPulseController to configure.
    func applyToController(_ controller: KeyPulseController) {
        controller.setVolume(volume)
        controller.setMuted(isMuted)
        controller.isEnabled = isEnabled
        controller.setPitchRandomization(pitchRandomization)
        // Note: Profile is set during controller initialization and changed via setProfile()
    }

    /// Resets all settings to their default values.
    func resetToDefaults() {
        profile = Defaults.profile
        volume = Defaults.volume
        isMuted = Defaults.isMuted
        isEnabled = Defaults.isEnabled
        pitchRandomization = Defaults.pitchRandomization
    }

    // MARK: - Initialization

    /// Creates a SettingsStore backed by the given UserDefaults.
    /// - Parameter defaults: UserDefaults instance (defaults to .standard for production).
    ///   Use a unique suite name for isolated test execution.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateIfNeeded()
    }

    /// Runs schema migrations when the stored version is older than current.
    /// Add migration blocks here when incrementing currentSchemaVersion.
    private func migrateIfNeeded() {
        let storedVersion = defaults.integer(forKey: Keys.schemaVersion)

        // Fresh install: stamp current version, no migration needed
        if storedVersion == 0 {
            defaults.set(Self.currentSchemaVersion, forKey: Keys.schemaVersion)
            return
        }

        // Future migrations go here:
        // if storedVersion < 2 { migrateV1toV2() }
        // if storedVersion < 3 { migrateV2toV3() }

        // Stamp current version after all migrations complete
        if storedVersion < Self.currentSchemaVersion {
            defaults.set(Self.currentSchemaVersion, forKey: Keys.schemaVersion)
        }
    }

    // MARK: - Private Methods

    /// Clamps a value to a specified range.
    /// - Parameters:
    ///   - value: The value to clamp.
    ///   - min: The minimum allowed value.
    ///   - max: The maximum allowed value.
    /// - Returns: The clamped value.
    private func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}
