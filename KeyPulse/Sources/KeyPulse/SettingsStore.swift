import Foundation
import ServiceManagement
import os.log

/// Persistent storage for user settings using UserDefaults.
/// Handles saving and loading of profile, volume, mute state, and enabled state.
final class SettingsStore {
    /// Shared singleton instance for app-wide settings access.
    static let shared = SettingsStore()

    /// Cache for SMAppService status to avoid expensive IPC on every read.
    /// Updated when setter is called or when explicitly refreshed.
    private var cachedLaunchAtLoginStatus: Bool?

    /// Timestamp of last status cache update.
    private var lastStatusCacheTime: Date?

    /// Cache validity duration (5 seconds) - balance between freshness and performance.
    private let statusCacheValidity: TimeInterval = 5.0

    /// UserDefaults keys for stored settings.
    private enum Keys {
        static let profile = "keypulse_profile"
        static let volume = "keypulse_volume"
        static let isMuted = "keypulse_isMuted"
        static let isEnabled = "keypulse_isEnabled"
        static let pitchRandomization = "keypulse_pitchRandomization"
        static let launchAtLogin = "keypulse_launchAtLogin"
    }

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
            if let rawValue = UserDefaults.standard.string(forKey: Keys.profile),
               let profile = SoundProfile(rawValue: rawValue) {
                return profile
            }
            return Defaults.profile
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.profile)
        }
    }

    /// The current volume level (0-100).
    var volume: Int {
        get {
            // Check if key exists to distinguish between 0 and not set
            if UserDefaults.standard.object(forKey: Keys.volume) == nil {
                return Defaults.volume
            }
            let storedValue = UserDefaults.standard.integer(forKey: Keys.volume)
            return clamp(storedValue, min: 0, max: 100)
        }
        set {
            UserDefaults.standard.set(clamp(newValue, min: 0, max: 100), forKey: Keys.volume)
        }
    }

    /// Whether the audio is muted.
    var isMuted: Bool {
        get {
            // Check if key exists to distinguish between false and not set
            if UserDefaults.standard.object(forKey: Keys.isMuted) == nil {
                return Defaults.isMuted
            }
            return UserDefaults.standard.bool(forKey: Keys.isMuted)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.isMuted)
        }
    }

    /// Whether KeyPulse is enabled (processing keystrokes).
    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.isEnabled) == nil {
                return Defaults.isEnabled
            }
            return UserDefaults.standard.bool(forKey: Keys.isEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.isEnabled)
        }
    }

    /// Whether pitch randomization is enabled (subtle variation per keystroke).
    var pitchRandomization: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.pitchRandomization) == nil {
                return Defaults.pitchRandomization
            }
            return UserDefaults.standard.bool(forKey: Keys.pitchRandomization)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.pitchRandomization)
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
            if UserDefaults.standard.object(forKey: Keys.launchAtLogin) == nil {
                // If system says it's registered, update our stored value
                if isRegistered {
                    UserDefaults.standard.set(true, forKey: Keys.launchAtLogin)
                }
            }

            return isRegistered
        }
        set {
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
                        UserDefaults.standard.set(true, forKey: Keys.launchAtLogin)
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
                        UserDefaults.standard.set(false, forKey: Keys.launchAtLogin)
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

    // MARK: - Private Methods

    private init() {}

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
