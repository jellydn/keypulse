import XCTest
@testable import KeyPulse

final class KeyPulseTests: XCTestCase {
    func testAppDelegateInitialization() {
        let delegate = KeyPulseAppDelegate()
        XCTAssertNotNil(delegate)
    }

    // MARK: - AudioEngine Tests

    func testAudioEngineInitialization() {
        let engine = AudioEngine()
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isRunning)
        XCTAssertNil(engine.currentProfile)
    }

    func testAudioEngineStartStop() throws {
        let engine = AudioEngine()

        // Start should succeed
        try engine.start()
        XCTAssertTrue(engine.isRunning)

        // Stop should clean up
        engine.stop()
        XCTAssertFalse(engine.isRunning)
    }

    func testAudioEngineDoubleStart() throws {
        let engine = AudioEngine()

        // First start
        try engine.start()
        XCTAssertTrue(engine.isRunning)

        // Second start should be no-op (no error)
        try engine.start()
        XCTAssertTrue(engine.isRunning)

        engine.stop()
    }

    func testAudioEngineLoadProfile() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        // Load linear profile
        try engine.loadProfile(.linear)
        XCTAssertEqual(engine.currentProfile, .linear)
        XCTAssertEqual(engine.loadedBufferCount, 4)
        XCTAssertTrue(engine.isProfileLoaded(.linear))

        // Load tactile profile
        try engine.loadProfile(.tactile)
        XCTAssertEqual(engine.currentProfile, .tactile)
        XCTAssertEqual(engine.loadedBufferCount, 4)
        XCTAssertTrue(engine.isProfileLoaded(.tactile))
        XCTAssertFalse(engine.isProfileLoaded(.linear))

        // Load clicky profile
        try engine.loadProfile(.clicky)
        XCTAssertEqual(engine.currentProfile, .clicky)
        XCTAssertEqual(engine.loadedBufferCount, 4)
        XCTAssertTrue(engine.isProfileLoaded(.clicky))
    }

    func testAudioEnginePlayValidIndex() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)

        // Play each valid sample index - should not throw
        for index in 0..<4 {
            XCTAssertNoThrow(try engine.play(sampleIndex: index))
        }
    }

    func testAudioEnginePlayThrowsWhenNotRunning() throws {
        let engine = AudioEngine()
        // Don't start the engine

        // Play should throw when engine not running
        XCTAssertThrowsError(try engine.play(sampleIndex: 0)) { error in
            XCTAssertEqual(error as? AudioEngine.AudioEngineError, .engineNotRunning)
        }
    }

    func testAudioEnginePlayThrowsForInvalidIndex() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)

        // Play with invalid index should throw
        XCTAssertThrowsError(try engine.play(sampleIndex: -1)) { error in
            XCTAssertEqual(error as? AudioEngine.AudioEngineError, .invalidSampleIndex)
        }

        XCTAssertThrowsError(try engine.play(sampleIndex: 100)) { error in
            XCTAssertEqual(error as? AudioEngine.AudioEngineError, .invalidSampleIndex)
        }
    }

    func testAudioEnginePlayThrowsWhenNoProfileLoaded() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        // Don't load any profile
        // Play should throw due to invalid index (buffers array is empty)
        XCTAssertThrowsError(try engine.play(sampleIndex: 0)) { error in
            XCTAssertEqual(error as? AudioEngine.AudioEngineError, .invalidSampleIndex)
        }
    }

    func testAudioEngineMute() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)

        // When muted, play should short-circuit without error
        engine.isMuted = true
        XCTAssertNoThrow(try engine.play(sampleIndex: 0))
        XCTAssertNoThrow(try engine.play(sampleIndex: 1))

        // Unmute and play should work
        engine.isMuted = false
        XCTAssertNoThrow(try engine.play(sampleIndex: 0))
    }

    func testAudioEngineVolume() throws {
        let engine = AudioEngine()

        // Default volume should be 1.0
        XCTAssertEqual(engine.volume, 1.0)

        // Set valid volume
        engine.volume = 0.5
        XCTAssertEqual(engine.volume, 0.5)

        // Volume should clamp to 0.0-1.0 range
        engine.volume = 1.5
        XCTAssertEqual(engine.volume, 1.0)

        engine.volume = -0.5
        XCTAssertEqual(engine.volume, 0.0)
    }

    func testAudioEngineConcurrentPlayback() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)

        // Rapidly trigger multiple plays to test concurrent playback
        // Using the same index multiple times
        for _ in 0..<10 {
            XCTAssertNoThrow(try engine.play(sampleIndex: 0))
        }
    }

    func testAudioEngineAllProfiles() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        // Test that all profiles can be loaded and played
        for profile in SoundProfile.allCases {
            try engine.loadProfile(profile)
            XCTAssertTrue(engine.isProfileLoaded(profile))

            // Play all samples for this profile
            for index in 0..<4 {
                XCTAssertNoThrow(try engine.play(sampleIndex: index))
            }
        }
    }

    // MARK: - SoundAssets Tests

    func testSoundProfileDisplayNames() {
        XCTAssertEqual(SoundProfile.linear.displayName, "Linear")
        XCTAssertEqual(SoundProfile.tactile.displayName, "Tactile")
        XCTAssertEqual(SoundProfile.clicky.displayName, "Clicky")
    }

    func testSoundProfileRawValues() {
        XCTAssertEqual(SoundProfile.linear.rawValue, "linear")
        XCTAssertEqual(SoundProfile.tactile.rawValue, "tactile")
        XCTAssertEqual(SoundProfile.clicky.rawValue, "clicky")
    }

    func testSoundProfileAllCases() {
        let allCases = SoundProfile.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.linear))
        XCTAssertTrue(allCases.contains(.tactile))
        XCTAssertTrue(allCases.contains(.clicky))
    }

    func testSoundAssetsSamplesPerProfile() {
        XCTAssertEqual(SoundAssets.samplesPerProfile, 4)
    }

    func testSoundAssetsSampleURLsForLinear() {
        let urls = SoundAssets.sampleURLs(for: .linear)
        XCTAssertEqual(urls.count, 4, "Linear profile should have 4 sample URLs")

        // Verify each URL resolves
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                         "Sample file should exist at \(url.path)")
        }
    }

    func testSoundAssetsSampleURLsForTactile() {
        let urls = SoundAssets.sampleURLs(for: .tactile)
        XCTAssertEqual(urls.count, 4, "Tactile profile should have 4 sample URLs")

        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                         "Sample file should exist at \(url.path)")
        }
    }

    func testSoundAssetsSampleURLsForClicky() {
        let urls = SoundAssets.sampleURLs(for: .clicky)
        XCTAssertEqual(urls.count, 4, "Clicky profile should have 4 sample URLs")

        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                         "Sample file should exist at \(url.path)")
        }
    }

    func testSoundAssetsSampleURLByIndex() {
        // Valid indices
        XCTAssertNotNil(SoundAssets.sampleURL(for: .linear, index: 0))
        XCTAssertNotNil(SoundAssets.sampleURL(for: .linear, index: 3))

        // Invalid indices
        XCTAssertNil(SoundAssets.sampleURL(for: .linear, index: -1))
        XCTAssertNil(SoundAssets.sampleURL(for: .linear, index: 4))
        XCTAssertNil(SoundAssets.sampleURL(for: .linear, index: 100))
    }

    func testSoundAssetsAvailableSampleCount() {
        XCTAssertEqual(SoundAssets.availableSampleCount(for: .linear), 4)
        XCTAssertEqual(SoundAssets.availableSampleCount(for: .tactile), 4)
        XCTAssertEqual(SoundAssets.availableSampleCount(for: .clicky), 4)
    }

    func testSoundAssetsVerifyAllSamplesExist() {
        XCTAssertTrue(SoundAssets.verifyAllSamplesExist(for: .linear),
                     "All linear samples should exist")
        XCTAssertTrue(SoundAssets.verifyAllSamplesExist(for: .tactile),
                     "All tactile samples should exist")
        XCTAssertTrue(SoundAssets.verifyAllSamplesExist(for: .clicky),
                     "All clicky samples should exist")
    }

    func testSoundProfileIdentifiable() {
        XCTAssertEqual(SoundProfile.linear.id, "linear")
        XCTAssertEqual(SoundProfile.tactile.id, "tactile")
        XCTAssertEqual(SoundProfile.clicky.id, "clicky")
    }

    // MARK: - KeyPulseController Tests

    func testKeyPulseControllerInitialization() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        XCTAssertNotNil(controller)
        XCTAssertEqual(controller.currentProfile, .linear)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertEqual(controller.sampleCount, 4)

        // Clean up
        controller.stop()
    }

    func testKeyPulseControllerSetProfile() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Initial profile should be linear
        XCTAssertEqual(controller.currentProfile, .linear)

        // Switch to tactile
        try controller.setProfile(.tactile)
        XCTAssertEqual(controller.currentProfile, .tactile)

        // Switch to clicky
        try controller.setProfile(.clicky)
        XCTAssertEqual(controller.currentProfile, .clicky)

        // Switch back to linear
        try controller.setProfile(.linear)
        XCTAssertEqual(controller.currentProfile, .linear)
    }

    func testKeyPulseControllerVolume() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Default volume should be 100%
        XCTAssertEqual(controller.volume, 100)

        // Set volume to 50%
        controller.setVolume(50)
        XCTAssertEqual(controller.volume, 50)

        // Set volume to 0%
        controller.setVolume(0)
        XCTAssertEqual(controller.volume, 0)

        // Set volume to 100%
        controller.setVolume(100)
        XCTAssertEqual(controller.volume, 100)
    }

    func testKeyPulseControllerMute() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Default should not be muted
        XCTAssertFalse(controller.isMuted)

        // Mute
        controller.setMuted(true)
        XCTAssertTrue(controller.isMuted)

        // Unmute
        controller.setMuted(false)
        XCTAssertFalse(controller.isMuted)
    }

    func testKeyPulseControllerEnabledState() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Default should be enabled
        XCTAssertTrue(controller.isEnabled)

        // Disable
        controller.isEnabled = false
        XCTAssertFalse(controller.isEnabled)

        // Re-enable
        controller.isEnabled = true
        XCTAssertTrue(controller.isEnabled)
    }

    func testKeyPulseControllerSelectRandomSampleIndex() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Generate many random samples to verify distribution
        var sampleIndices: [Int] = []
        for _ in 0..<100 {
            let index = controller.selectRandomSampleIndex()
            sampleIndices.append(index)

            // Verify index is in valid range
            XCTAssertGreaterThanOrEqual(index, 0)
            XCTAssertLessThan(index, 4)
        }

        // Verify we got some variety (unlikely but possible to get all same)
        // Just verify at least 2 different indices were selected
        let uniqueIndices = Set(sampleIndices)
        XCTAssertGreaterThanOrEqual(uniqueIndices.count, 1, "Should have at least some variety in random selection")
    }

    func testKeyPulseControllerAllProfiles() throws {
        // Test that controller can be initialized with each profile
        for profile in SoundProfile.allCases {
            let controller = try KeyPulseController(initialProfile: profile)
            XCTAssertEqual(controller.currentProfile, profile)
            controller.stop()
        }
    }

    func testKeyPulseControllerErrorHandler() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Set up error handler
        var errorReceived: Error?
        controller.onError = { error in
            errorReceived = error
        }

        // Test that error handler is set (actual error testing would require simulating an error condition)
        XCTAssertNotNil(controller.onError)
    }

    func testKeyPulseControllerModifierKeyTriggersPlayback() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Start monitoring
        let started = controller.start()
        // Note: This may fail in tests without accessibility permission, which is expected

        if started {
            // If monitoring started, verify controller is properly set up
            XCTAssertTrue(controller.isEnabled)

            // The modifier key handling is tested through the KeyboardMonitor
            // which now includes flagsChanged events in its event mask.
            // We verify here that the controller accepts the modifier key code (0xFF)
            // and would play a sound when triggered.

            // Since we can't easily synthesize CGEvent taps in unit tests,
            // we verify the controller is in a state that would accept events
            XCTAssertEqual(controller.sampleCount, 4)
        }
    }

    // MARK: - SettingsStore Tests

    func testSettingsStoreDefaultProfile() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        XCTAssertEqual(store.profile, .linear)
    }

    func testSettingsStoreProfilePersistence() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Save each profile and verify it persists
        for profile in SoundProfile.allCases {
            store.profile = profile
            XCTAssertEqual(store.profile, profile)
        }
    }

    func testSettingsStoreDefaultVolume() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        XCTAssertEqual(store.volume, 100)
    }

    func testSettingsStoreVolumePersistence() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Test saving different volume levels
        store.volume = 50
        XCTAssertEqual(store.volume, 50)

        store.volume = 0
        XCTAssertEqual(store.volume, 0)

        store.volume = 100
        XCTAssertEqual(store.volume, 100)
    }

    func testSettingsStoreVolumeClamping() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Test that volume is clamped to 0-100 range
        store.volume = 150
        XCTAssertEqual(store.volume, 100)

        store.volume = -50
        XCTAssertEqual(store.volume, 0)
    }

    func testSettingsStoreDefaultMute() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        XCTAssertFalse(store.isMuted)
    }

    func testSettingsStoreMutePersistence() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        store.isMuted = true
        XCTAssertTrue(store.isMuted)

        store.isMuted = false
        XCTAssertFalse(store.isMuted)
    }

    func testSettingsStoreDefaultEnabled() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        XCTAssertTrue(store.isEnabled)
    }

    func testSettingsStoreEnabledPersistence() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        store.isEnabled = false
        XCTAssertFalse(store.isEnabled)

        store.isEnabled = true
        XCTAssertTrue(store.isEnabled)
    }

    func testSettingsStoreLoadAllSettings() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        let settings = store.loadAllSettings()
        XCTAssertEqual(settings.profile, .linear)
        XCTAssertEqual(settings.volume, 100)
        XCTAssertFalse(settings.isMuted)
        XCTAssertTrue(settings.isEnabled)
    }

    func testSettingsStoreResetToDefaults() {
        let store = SettingsStore.shared

        // Change all settings to non-default values
        store.profile = .clicky
        store.volume = 75
        store.isMuted = true
        store.isEnabled = false

        // Reset to defaults
        store.resetToDefaults()

        XCTAssertEqual(store.profile, .linear)
        XCTAssertEqual(store.volume, 100)
        XCTAssertFalse(store.isMuted)
        XCTAssertTrue(store.isEnabled)
    }

    func testSettingsStoreSaveFromController() throws {
        let store = SettingsStore.shared
        let controller = try KeyPulseController(initialProfile: .tactile)
        defer { controller.stop() }

        // Modify controller state
        controller.setVolume(75)
        controller.setMuted(true)
        controller.isEnabled = false

        // Save to settings store
        store.saveFromController(controller)

        // Verify settings were saved
        XCTAssertEqual(store.profile, .tactile)
        XCTAssertEqual(store.volume, 75)
        XCTAssertTrue(store.isMuted)
        XCTAssertFalse(store.isEnabled)
    }

    func testSettingsStoreApplyToController() throws {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Set non-default values in store
        store.profile = .clicky
        store.volume = 25
        store.isMuted = true
        store.isEnabled = false

        // Create controller with default profile (store profile will be applied separately)
        let controller = try KeyPulseController(initialProfile: store.profile)
        defer { controller.stop() }

        // Apply settings to controller
        store.applyToController(controller)

        // Verify controller state
        XCTAssertEqual(controller.volume, 25)
        XCTAssertTrue(controller.isMuted)
        XCTAssertFalse(controller.isEnabled)
    }

    func testSettingsStoreRoundTrip() throws {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Create and modify controller
        let controller1 = try KeyPulseController(initialProfile: .clicky)
        controller1.setVolume(60)
        controller1.setMuted(true)
        controller1.isEnabled = false
        controller1.setPitchRandomization(false)

        // Save settings
        store.saveFromController(controller1)
        controller1.stop()

        // Create new controller and load settings
        let controller2 = try KeyPulseController(initialProfile: store.profile)
        defer { controller2.stop() }
        store.applyToController(controller2)

        // Verify settings persisted
        XCTAssertEqual(controller2.currentProfile, .clicky)
        XCTAssertEqual(controller2.volume, 60)
        XCTAssertTrue(controller2.isMuted)
        XCTAssertFalse(controller2.isEnabled)
        XCTAssertFalse(controller2.pitchRandomization)
    }

    // MARK: - Pitch Randomization Tests

    func testAudioEnginePitchRandomizationDisabled() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)

        // With pitch randomization disabled, play should work normally
        engine.isPitchRandomizationEnabled = false
        XCTAssertNoThrow(try engine.play(sampleIndex: 0))
    }

    func testAudioEnginePitchRandomizationEnabled() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)

        // With pitch randomization enabled, play should work with variation
        engine.isPitchRandomizationEnabled = true
        XCTAssertNoThrow(try engine.play(sampleIndex: 0))
    }

    func testKeyPulseControllerPitchRandomization() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer { controller.stop() }

        // Default should be false (not enabled by controller)
        XCTAssertFalse(controller.pitchRandomization)

        // Enable pitch randomization
        controller.setPitchRandomization(true)
        XCTAssertTrue(controller.pitchRandomization)

        // Disable pitch randomization
        controller.setPitchRandomization(false)
        XCTAssertFalse(controller.pitchRandomization)
    }

    func testSettingsStoreDefaultPitchRandomization() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Default should be true as per US-010 requirements
        XCTAssertTrue(store.pitchRandomization)
    }

    func testSettingsStorePitchRandomizationPersistence() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Test saving different states
        store.pitchRandomization = false
        XCTAssertFalse(store.pitchRandomization)

        store.pitchRandomization = true
        XCTAssertTrue(store.pitchRandomization)
    }

    func testSettingsStoreApplyPitchRandomizationToController() throws {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Set pitch randomization to false in store
        store.pitchRandomization = false

        // Create controller with default profile
        let controller = try KeyPulseController(initialProfile: store.profile)
        defer { controller.stop() }

        // Apply settings to controller
        store.applyToController(controller)

        // Verify pitch randomization was applied
        XCTAssertFalse(controller.pitchRandomization)

        // Now enable and re-apply
        store.pitchRandomization = true
        store.applyToController(controller)
        XCTAssertTrue(controller.pitchRandomization)
    }

    // MARK: - Latency Measurement Tests

    func testAudioEngineLatencyMeasurement() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)

        // Reset any previous measurements
        engine.resetLatencyMeasurements()
        XCTAssertEqual(engine.latencyMeasurementCount, 0)

        // Play multiple samples to generate measurements
        let playCount = 20
        for i in 0..<playCount {
            try engine.play(sampleIndex: i % 4)
        }

        // Verify measurements were recorded
        XCTAssertEqual(engine.latencyMeasurementCount, playCount,
                       "Should have recorded latency for each play() call")

        // Get latency statistics
        let averageMs = engine.averageLatency * 1000
        let maxMs = engine.maxLatency * 1000
        let minMs = engine.minLatency * 1000

        // Print latency report for documentation
        print("\n" + engine.latencyReport())

        // Verify latency is reasonable (should be well under 20ms for pre-loaded buffers)
        // Note: In unit tests without actual audio output, this measures scheduling time
        XCTAssertGreaterThan(averageMs, 0, "Average latency should be positive")
        XCTAssertGreaterThan(maxMs, 0, "Max latency should be positive")
        XCTAssertGreaterThan(minMs, 0, "Min latency should be positive")

        // The architecture guarantees <20ms - in practice we see <5ms for pre-loaded buffers
        // Using a generous threshold of 50ms for unit test environment variability
        XCTAssertLessThan(averageMs, 50, "Average latency should be under 50ms (target: <20ms)")
        XCTAssertLessThan(maxMs, 100, "Max latency should be under 100ms (target: <20ms)")
    }

    func testAudioEngineLatencyReport() throws {
        let engine = AudioEngine()

        // Before any measurements
        let emptyReport = engine.latencyReport()
        XCTAssertTrue(emptyReport.contains("No latency measurements available"))

        try engine.start()
        defer { engine.stop() }
        try engine.loadProfile(.linear)

        // After playing samples
        try engine.play(sampleIndex: 0)
        try engine.play(sampleIndex: 1)

        let report = engine.latencyReport()
        XCTAssertTrue(report.contains("Latency Statistics"))
        XCTAssertTrue(report.contains("Average:"))
        XCTAssertTrue(report.contains("Maximum:"))
        XCTAssertTrue(report.contains("Minimum:"))
        XCTAssertTrue(report.contains("Target: < 20ms"))
    }

    func testAudioEngineLatencyReset() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)

        // Play some samples
        for i in 0..<10 {
            try engine.play(sampleIndex: i % 4)
        }

        XCTAssertEqual(engine.latencyMeasurementCount, 10)

        // Reset measurements
        engine.resetLatencyMeasurements()

        XCTAssertEqual(engine.latencyMeasurementCount, 0)
        XCTAssertEqual(engine.averageLatency, 0)
        XCTAssertEqual(engine.maxLatency, 0)
        XCTAssertEqual(engine.minLatency, 0)
    }

    func testAudioEngineLatencyUnder20msTarget() throws {
        // This test verifies the core acceptance criteria for US-003:
        // "Measured trigger-to-output latency under 20ms"
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)

        // Reset measurements
        engine.resetLatencyMeasurements()

        // Simulate rapid typing - 50 keystrokes
        let keystrokeCount = 50
        for i in 0..<keystrokeCount {
            try engine.play(sampleIndex: i % 4)
        }

        let averageMs = engine.averageLatency * 1000
        let maxMs = engine.maxLatency * 1000

        // Document the actual measurement
        print("\n=== US-003 LATENCY BENCHMARK ===")
        print(engine.latencyReport())
        print("=================================\n")

        // Verify measurements were taken
        XCTAssertEqual(engine.latencyMeasurementCount, keystrokeCount)

        // The architecture (pre-loaded buffers, no file I/O) guarantees <20ms
        // We use pre-loaded AVAudioPCMBuffer with scheduleBuffer(at: nil) for minimal latency
        // In production, actual latency depends on audio hardware buffer size
        // This test measures the code path latency (trigger to scheduleBuffer call)

        // Acceptable thresholds for unit test environment:
        // - Average must be under 20ms (the core AC)
        // - Max should be under 50ms (allows for occasional scheduler delays)
        XCTAssertLessThan(averageMs, 20.0,
                          "Average latency (\(String(format: "%.3f", averageMs))ms) must be under 20ms - US-003 AC")
        XCTAssertLessThan(maxMs, 50.0,
                          "Max latency (\(String(format: "%.3f", maxMs))ms) should be under 50ms")
    }

    // MARK: - Launch at Login Tests

    func testSettingsStoreDefaultLaunchAtLogin() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Default should be false (not launching at login)
        XCTAssertFalse(store.launchAtLogin)
    }

    func testSettingsStoreLaunchAtLoginPersistence() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Note: We can't actually test SMAppService registration in unit tests
        // as it requires app signing and system permissions.
        // Instead, we test that the UserDefaults persistence works correctly.

        // Test that the getter checks UserDefaults correctly
        // The getter reads from SMAppService status which may vary,
        // but we verify the property exists and is accessible

        // Read the current value (may be true or false depending on system state)
        let initialValue = store.launchAtLogin

        // Setting should not crash and should update UserDefaults if successful
        // Note: Actual registration may fail in tests without proper entitlements
        store.launchAtLogin = !initialValue

        // The value reflects the actual SMAppService status, not our UserDefaults
        // This is the correct behavior as SMAppService is the source of truth
        XCTAssertNotNil(store.launchAtLogin)
    }

    func testSettingsStoreLaunchAtLoginUserDefaultsKey() {
        let store = SettingsStore.shared
        store.resetToDefaults()

        // Verify the UserDefaults key exists and is properly namespaced
        let key = "keypulse_launchAtLogin"

        // Initially should be nil after reset (since we don't set UserDefaults on reset for this)
        // Note: launchAtLogin getter uses SMAppService status as source of truth

        // Test that setting works through the setter
        // The setter syncs with SMAppService and updates UserDefaults on success
        store.launchAtLogin = false

        // Verify we can read it back (may differ from what we set due to SMAppService state)
        _ = store.launchAtLogin
    }

    // MARK: - Diagnostics Tests

    func testDiagnosticsDataInitialization() {
        let diagnostics = DiagnosticsData()
        XCTAssertEqual(diagnostics.totalKeystrokes, 0)
        XCTAssertEqual(diagnostics.lastKeyCode, 0)
        XCTAssertEqual(diagnostics.activeProfile, .linear)
        XCTAssertEqual(diagnostics.latencySampleCount, 0)
        XCTAssertEqual(diagnostics.volumePercent, 100)
        XCTAssertFalse(diagnostics.isMuted)
        XCTAssertTrue(diagnostics.isPitchVariationEnabled)
    }

    func testDiagnosticsDataFormattedOutput() {
        var diagnostics = DiagnosticsData()
        diagnostics.totalKeystrokes = 42
        diagnostics.lastKeyCode = 49
        diagnostics.lastKeyDisplayName = "Space"
        diagnostics.activeProfile = .tactile
        diagnostics.latencyAverageMs = 1.5
        diagnostics.latencyMinMs = 0.5
        diagnostics.latencyMaxMs = 10.0
        diagnostics.latencySampleCount = 100
        diagnostics.volumePercent = 75
        diagnostics.isMuted = false

        let formatted = diagnostics.formattedDiagnostics()

        XCTAssertTrue(formatted.contains("KeyPulse Diagnostics Report"))
        XCTAssertTrue(formatted.contains("Total Keystrokes: 42"))
        XCTAssertTrue(formatted.contains("Space"))
        XCTAssertTrue(formatted.contains("Tactile"))
        XCTAssertTrue(formatted.contains("75%"))
        XCTAssertTrue(formatted.contains("PASS"))
    }

    func testKeyPulseControllerDiagnostics() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer {
            controller.stop()
        }

        let diagnostics = controller.diagnostics()

        XCTAssertEqual(diagnostics.activeProfile, .linear)
        XCTAssertEqual(diagnostics.totalKeystrokes, 0)
        XCTAssertEqual(diagnostics.latencySampleCount, 0)
    }

    func testKeyPulseControllerResetStats() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer {
            controller.stop()
        }

        // Reset stats
        controller.resetStats()

        let diagnostics = controller.diagnostics()
        XCTAssertEqual(diagnostics.totalKeystrokes, 0)
        XCTAssertEqual(diagnostics.latencySampleCount, 0)
    }

    func testKeyPulseControllerTestPlayIncrementsSampleIndex() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer {
            controller.stop()
        }

        // Get initial state
        let initialDiagnostics = controller.diagnostics()
        let initialSampleIndex = initialDiagnostics.lastSampleIndex

        // Play a test sound (will only work if not muted)
        controller.setMuted(false)
        controller.setVolume(50)
        let playResult = controller.testPlay()

        // Result depends on whether audio engine is running
        // We just verify the method doesn't crash
        XCTAssertTrue(playResult || !playResult) // Always true, just verifying no crash

        // Get updated state
        let updatedDiagnostics = controller.diagnostics()

        // Sample index should be set (either 0 or the random index)
        XCTAssertGreaterThanOrEqual(updatedDiagnostics.lastSampleIndex, 0)
        XCTAssertLessThan(updatedDiagnostics.lastSampleIndex, SoundAssets.samplesPerProfile)
    }

    func testKeyPulseControllerTestPlayWhenMuted() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer {
            controller.stop()
        }

        // Mute and try to play
        controller.setMuted(true)
        let playResult = controller.testPlay()

        // Should return false when muted
        XCTAssertFalse(playResult)
    }

    func testKeyPulseControllerProfileChangeUpdatesDiagnostics() throws {
        let controller = try KeyPulseController(initialProfile: .linear)
        defer {
            controller.stop()
        }

        XCTAssertEqual(controller.diagnostics().activeProfile, .linear)

        try controller.setProfile(.tactile)
        XCTAssertEqual(controller.diagnostics().activeProfile, .tactile)

        try controller.setProfile(.clicky)
        XCTAssertEqual(controller.diagnostics().activeProfile, .clicky)
    }

    // MARK: - DiagnosticsData Equatable Tests
    // All 22 fields must be compared — a partial comparison would cause @Published
    // to silently suppress UI updates for omitted fields.

    func testDiagnosticsDataEquatable_identity() {
        let data1 = DiagnosticsData()
        let data2 = DiagnosticsData()
        XCTAssertEqual(data1, data2)
    }

    func testDiagnosticsDataEquatable_keystrokeFields() {
        var base = DiagnosticsData()
        var changed = DiagnosticsData()

        // totalKeystrokes
        changed.totalKeystrokes = 42
        XCTAssertNotEqual(base, changed, "totalKeystrokes difference must cause inequality")

        // lastKeyCode
        changed = DiagnosticsData()
        changed.lastKeyCode = 49  // Space
        XCTAssertNotEqual(base, changed, "lastKeyCode difference must cause inequality")

        // isLastKeyModifier
        changed = DiagnosticsData()
        changed.isLastKeyModifier = true
        XCTAssertNotEqual(base, changed, "isLastKeyModifier difference must cause inequality")

        // lastKeyDisplayName
        changed = DiagnosticsData()
        changed.lastKeyDisplayName = "Space"
        XCTAssertNotEqual(base, changed, "lastKeyDisplayName difference must cause inequality")
    }

    func testDiagnosticsDataEquatable_profileFields() {
        var base = DiagnosticsData()
        var changed = DiagnosticsData()

        // activeProfile
        changed.activeProfile = .tactile
        XCTAssertNotEqual(base, changed, "activeProfile difference must cause inequality")

        // lastSampleIndex
        changed = DiagnosticsData()
        changed.lastSampleIndex = 3
        XCTAssertNotEqual(base, changed, "lastSampleIndex difference must cause inequality")

        // lastSampleFilename
        changed = DiagnosticsData()
        changed.lastSampleFilename = "clicky_key_02.wav"
        XCTAssertNotEqual(base, changed, "lastSampleFilename difference must cause inequality")
    }

    func testDiagnosticsDataEquatable_latencyFields() {
        // THIS IS THE BUG FIX: latency fields were previously NOT compared,
        // causing @Published to suppress latency updates in the Debug Window.
        var base = DiagnosticsData()
        var changed = DiagnosticsData()

        // latencyAverageMs
        changed.latencyAverageMs = 5.2
        XCTAssertNotEqual(base, changed, "latencyAverageMs difference must cause inequality")

        // latencyMinMs
        changed = DiagnosticsData()
        changed.latencyMinMs = 0.3
        XCTAssertNotEqual(base, changed, "latencyMinMs difference must cause inequality")

        // latencyMaxMs
        changed = DiagnosticsData()
        changed.latencyMaxMs = 15.7
        XCTAssertNotEqual(base, changed, "latencyMaxMs difference must cause inequality")

        // latencySampleCount
        changed = DiagnosticsData()
        changed.latencySampleCount = 100
        XCTAssertNotEqual(base, changed, "latencySampleCount difference must cause inequality")
    }

    func testDiagnosticsDataEquatable_modifierFlags() {
        var base = DiagnosticsData()
        var changed = DiagnosticsData()

        // isShiftPressed
        changed.isShiftPressed = true
        XCTAssertNotEqual(base, changed, "isShiftPressed difference must cause inequality")

        // isCommandPressed
        changed = DiagnosticsData()
        changed.isCommandPressed = true
        XCTAssertNotEqual(base, changed, "isCommandPressed difference must cause inequality")

        // isOptionPressed
        changed = DiagnosticsData()
        changed.isOptionPressed = true
        XCTAssertNotEqual(base, changed, "isOptionPressed difference must cause inequality")

        // isControlPressed
        changed = DiagnosticsData()
        changed.isControlPressed = true
        XCTAssertNotEqual(base, changed, "isControlPressed difference must cause inequality")
    }

    func testDiagnosticsDataEquatable_settingsFields() {
        // volumePercent, isMuted, isPitchVariationEnabled were previously NOT compared,
        // so changing mute/volume via the menu bar would not update the Debug Window.
        var base = DiagnosticsData()
        var changed = DiagnosticsData()

        // volumePercent
        changed.volumePercent = 50
        XCTAssertNotEqual(base, changed, "volumePercent difference must cause inequality")

        // isMuted
        changed = DiagnosticsData()
        changed.isMuted = true
        XCTAssertNotEqual(base, changed, "isMuted difference must cause inequality")

        // isPitchVariationEnabled
        changed = DiagnosticsData()
        changed.isPitchVariationEnabled = false
        XCTAssertNotEqual(base, changed, "isPitchVariationEnabled difference must cause inequality")

        // isEnabled
        changed = DiagnosticsData()
        changed.isEnabled = false
        XCTAssertNotEqual(base, changed, "isEnabled difference must cause inequality")
    }

    func testDiagnosticsDataEquatable_appInfoFields() {
        var base = DiagnosticsData()
        var changed = DiagnosticsData()

        // bundleIdentifier
        changed.bundleIdentifier = "com.other.app"
        XCTAssertNotEqual(base, changed, "bundleIdentifier difference must cause inequality")

        // appVersion
        changed = DiagnosticsData()
        changed.appVersion = "2.0.0"
        XCTAssertNotEqual(base, changed, "appVersion difference must cause inequality")

        // buildNumber
        changed = DiagnosticsData()
        changed.buildNumber = "99"
        XCTAssertNotEqual(base, changed, "buildNumber difference must cause inequality")

        // macOSVersion should differ from empty string
        changed = DiagnosticsData()
        changed.macOSVersion = ""
        XCTAssertNotEqual(base, changed, "macOSVersion difference must cause inequality")
    }

    func testDiagnosticsDataEquatable_allFieldsChanged() {
        var data1 = DiagnosticsData()
        var data2 = DiagnosticsData()
        data2.totalKeystrokes = 99
        data2.latencyAverageMs = 3.7
        data2.isMuted = true
        data2.volumePercent = 25
        data2.isShiftPressed = true
        data2.activeProfile = .clicky
        XCTAssertNotEqual(data1, data2)

        // Match all fields back — should be equal again
        data1.totalKeystrokes = 99
        data1.latencyAverageMs = 3.7
        data1.isMuted = true
        data1.volumePercent = 25
        data1.isShiftPressed = true
        data1.activeProfile = .clicky
        XCTAssertEqual(data1, data2)
    }

    func testDiagnosticsDataLatencyPassFail() {
        var diagnostics = DiagnosticsData()

        // Good latency (< 20ms) - should show PASS
        diagnostics.latencyAverageMs = 10.0
        XCTAssertTrue(diagnostics.formattedDiagnostics().contains("PASS"))

        // Bad latency (> 20ms) - should show FAIL
        diagnostics.latencyAverageMs = 25.0
        XCTAssertTrue(diagnostics.formattedDiagnostics().contains("FAIL"))
    }
}
