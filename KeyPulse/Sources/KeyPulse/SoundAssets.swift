import Foundation

/// Represents the three mechanical keyboard sound profiles.
enum SoundProfile: String, CaseIterable, Identifiable {
    case linear = "linear"
    case tactile = "tactile"
    case clicky = "clicky"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .linear:
            return "Linear"
        case .tactile:
            return "Tactile"
        case .clicky:
            return "Clicky"
        }
    }

    /// Returns the filename prefix for this profile.
    var filenamePrefix: String { rawValue }
}

/// Manages sound asset URLs for each sound profile.
enum SoundAssets {
    /// Number of samples per profile.
    static let samplesPerProfile = 4

    /// Returns the URLs for all samples in the specified profile.
    /// - Parameter profile: The sound profile to load samples for.
    /// - Returns: Array of URLs pointing to the sound files in the bundle.
    static func sampleURLs(for profile: SoundProfile) -> [URL] {
        let prefix = profile.filenamePrefix

        return (1...samplesPerProfile).compactMap { index in
            let filename = "\(prefix)_key_\(String(format: "%02d", index))"
            return Bundle.module.url(forResource: filename, withExtension: "wav")
        }
    }

    /// Returns a single sample URL by index for the specified profile.
    /// - Parameters:
    ///   - profile: The sound profile.
    ///   - index: Sample index (0 to samplesPerProfile-1).
    /// - Returns: URL to the sound file, or nil if index is out of bounds.
    static func sampleURL(for profile: SoundProfile, index: Int) -> URL? {
        guard index >= 0 && index < samplesPerProfile else { return nil }
        let prefix = profile.filenamePrefix
        let filename = "\(prefix)_key_\(String(format: "%02d", index + 1))"
        return Bundle.module.url(forResource: filename, withExtension: "wav")
    }

    /// Returns the count of available samples for the specified profile.
    /// - Parameter profile: The sound profile to check.
    /// - Returns: Number of successfully resolved sample URLs.
    static func availableSampleCount(for profile: SoundProfile) -> Int {
        return sampleURLs(for: profile).count
    }

    /// Returns true if all expected samples exist for the profile.
    /// - Parameter profile: The sound profile to verify.
    /// - Returns: True if all samples resolve to existing files.
    static func verifyAllSamplesExist(for profile: SoundProfile) -> Bool {
        let urls = sampleURLs(for: profile)
        guard urls.count == samplesPerProfile else { return false }

        return urls.allSatisfy { url in
            FileManager.default.fileExists(atPath: url.path)
        }
    }
}
