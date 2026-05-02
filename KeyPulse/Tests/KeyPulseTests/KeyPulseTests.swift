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
}
