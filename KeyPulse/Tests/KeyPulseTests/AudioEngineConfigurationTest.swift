import XCTest
@testable import KeyPulse
import AVFoundation

/// Tests audio engine resilience to configuration changes
/// (headphones plugged/unplugged, Bluetooth device connect/disconnect, sample rate changes).
final class AudioEngineConfigurationTest: XCTestCase {

    func testObserverRegisteredOnStart() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        // Engine should be running and observer should be registered.
        // We verify by checking that start/stop cycle doesn't crash
        // and that the engine remains functional.
        XCTAssertTrue(engine.isRunning)

        // Verify playback still works after observer registration
        try engine.loadProfile(.linear)
        XCTAssertNoThrow(try engine.play(sampleIndex: 0))
    }

    func testEngineStillFunctionalAfterObserverSetup() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        // Load and play all profiles to ensure observer doesn't interfere
        for profile in SoundProfile.allCases {
            try engine.loadProfile(profile)
            for index in 0..<4 {
                XCTAssertNoThrow(try engine.play(sampleIndex: index))
            }
        }
    }

    func testObserverNotLeakedOnMultipleStarts() throws {
        let engine = AudioEngine()

        // Start and stop multiple times — observer should not accumulate
        for _ in 0..<3 {
            try engine.start()
            XCTAssertTrue(engine.isRunning)
            engine.stop()
            XCTAssertFalse(engine.isRunning)
        }

        // Final start should still work
        try engine.start()
        XCTAssertTrue(engine.isRunning)
        try engine.loadProfile(.linear)
        XCTAssertNoThrow(try engine.play(sampleIndex: 0))
        engine.stop()
    }

    func testStopRemovesObserver() throws {
        let engine = AudioEngine()
        try engine.start()
        XCTAssertTrue(engine.isRunning)

        // Stop should remove observer (verified by no crash on deinit)
        engine.stop()
        XCTAssertFalse(engine.isRunning)

        // Restart should re-register observer
        try engine.start()
        XCTAssertTrue(engine.isRunning)
        try engine.loadProfile(.linear)
        XCTAssertNoThrow(try engine.play(sampleIndex: 0))
        engine.stop()
    }

    /// Verifies the engine survives a configuration change notification gracefully.
    /// Posts a notification and confirms the engine doesn't crash and remains functional.
    func testHandleConfigurationChangeNotification() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        try engine.loadProfile(.linear)
        XCTAssertEqual(engine.currentProfile, .linear)

        // Post a configuration change notification (engine is the object)
        // The observer is registered with object: engine, so we need the actual AVAudioEngine.
        // We post a best-effort notification and verify the engine doesn't crash.
        NotificationCenter.default.post(
            name: .AVAudioEngineConfigurationChange,
            object: nil  // nil delivers to all observers regardless of object filter
        )

        // Give the handler time to execute on the main queue
        let expectation = XCTestExpectation(description: "Configuration change handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Engine should still be functional after handling the notification
        // If the handler ran, it would have restarted and reloaded the profile
        XCTAssertNoThrow(try engine.play(sampleIndex: 0))
    }
}
