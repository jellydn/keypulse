import Foundation

/// Central controller that wires keyboard events to audio playback.
/// Owns both KeyboardMonitor and AudioEngine, coordinating keystroke
/// detection with sound sample playback.
final class KeyPulseController {
    /// The keyboard monitor for detecting global keystrokes.
    private let keyboardMonitor: KeyboardMonitor

    /// The audio engine for playing sound samples.
    private let audioEngine: AudioEngine

    /// The current sound profile.
    private(set) var currentProfile: SoundProfile = .linear

    /// Whether the controller is enabled (processing keystrokes).
    var isEnabled: Bool = true

    /// Error handler for runtime issues.
    var onError: ((Error) -> Void)?

    /// Creates a new controller with the specified profile.
    /// - Parameter initialProfile: The initial sound profile to load (defaults to .linear).
    /// - Throws: AudioEngine.AudioEngineError if the audio engine fails to start or load profile.
    init(initialProfile: SoundProfile = .linear) throws {
        self.keyboardMonitor = KeyboardMonitor()
        self.audioEngine = AudioEngine()
        self.currentProfile = initialProfile

        // Start the audio engine
        try audioEngine.start()

        // Load the initial profile
        try audioEngine.loadProfile(initialProfile)

        // Set up the keyboard event handler
        setupKeyboardHandler()
    }

    deinit {
        keyboardMonitor.stop()
        audioEngine.stop()
    }

    /// Starts monitoring keyboard events.
    /// - Returns: True if monitoring started successfully, false if accessibility permission is missing.
    @discardableResult
    func start() -> Bool {
        return keyboardMonitor.start()
    }

    /// Stops monitoring keyboard events.
    func stop() {
        keyboardMonitor.stop()
    }

    /// Changes the current sound profile.
    /// - Parameter profile: The new profile to load.
    /// - Throws: AudioEngine.AudioEngineError if profile loading fails.
    func setProfile(_ profile: SoundProfile) throws {
        try audioEngine.loadProfile(profile)
        currentProfile = profile
    }

    /// Sets the volume level.
    /// - Parameter percent: Volume percentage (0-100).
    func setVolume(_ percent: Int) {
        audioEngine.volume = Float(percent) / 100.0
    }

    /// Gets the current volume as a percentage (0-100).
    var volume: Int {
        return Int(audioEngine.volume * 100.0)
    }

    /// Sets the mute state.
    /// - Parameter muted: Whether audio should be muted.
    func setMuted(_ muted: Bool) {
        audioEngine.isMuted = muted
    }

    /// Gets the current mute state.
    var isMuted: Bool {
        return audioEngine.isMuted
    }

    /// Returns the number of samples in the current profile.
    var sampleCount: Int {
        return SoundAssets.samplesPerProfile
    }

    // MARK: - Private Methods

    /// Sets up the keyboard event handler to play sounds.
    private func setupKeyboardHandler() {
        keyboardMonitor.onKeyDown = { [weak self] keyCode in
            guard let self = self, self.isEnabled else { return }

            // Play a random sample from the current profile
            self.playRandomSample()
        }
    }

    /// Selects and plays a random sample from the current profile.
    private func playRandomSample() {
        // Select a random sample index
        let sampleIndex = selectRandomSampleIndex()

        do {
            try audioEngine.play(sampleIndex: sampleIndex)
        } catch {
            // Report error through error handler
            onError?(error)
        }
    }

    /// Selects a random sample index.
    /// Currently uses uniform random selection. Future iterations could implement
    /// rotation logic to avoid playing the same sample twice in a row.
    /// - Returns: A random sample index between 0 and samplesPerProfile-1.
    func selectRandomSampleIndex() -> Int {
        return Int.random(in: 0..<SoundAssets.samplesPerProfile)
    }
}
