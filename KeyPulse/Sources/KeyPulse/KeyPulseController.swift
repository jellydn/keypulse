import Foundation
import Combine
import CoreGraphics

/// Central controller that wires keyboard events to audio playback.
/// Owns both KeyboardMonitor and AudioEngine, coordinating keystroke
/// detection with sound sample playback.
final class KeyPulseController: ObservableObject {
    /// The keyboard monitor for detecting global keystrokes.
    private let keyboardMonitor: KeyboardMonitor

    /// The audio engine for playing sound samples.
    private let audioEngine: AudioEngine

    /// The current sound profile.
    @Published private(set) var currentProfile: SoundProfile = .linear

    /// Whether the controller is enabled (processing keystrokes).
    @Published var isEnabled: Bool = true

    /// Error handler for runtime issues.
    var onError: ((Error) -> Void)?

    // MARK: - Diagnostics Tracking

    /// Published diagnostics data for real-time UI binding.
    @Published var diagnosticsData = DiagnosticsData()

    /// Total keystroke counter for debug window.
    private var totalKeystrokes: Int = 0

    /// Last key code received.
    private var lastKeyCode: UInt16 = 0

    /// Whether the last key was a modifier.
    private var isLastKeyModifier: Bool = false

    /// Last sample index played.
    private var lastSampleIndex: Int = 0

    /// Cancellable for throttling diagnostic updates.
    private var diagnosticsUpdateCancellable: AnyCancellable?

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

        // Initialize diagnostics data with app info
        updateDiagnosticsData()
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
        updateDiagnosticsData()
    }

    /// Sets the volume level.
    /// - Parameter percent: Volume percentage (0-100).
    func setVolume(_ percent: Int) {
        audioEngine.volume = Float(percent) / 100.0
        updateDiagnosticsData()
    }

    /// Gets the current volume as a percentage (0-100).
    var volume: Int {
        return Int(audioEngine.volume * 100.0)
    }

    /// Sets the mute state.
    /// - Parameter muted: Whether audio should be muted.
    func setMuted(_ muted: Bool) {
        audioEngine.isMuted = muted
        updateDiagnosticsData()
    }

    /// Gets the current mute state.
    var isMuted: Bool {
        return audioEngine.isMuted
    }

    /// Sets the pitch randomization state.
    /// - Parameter enabled: Whether to enable ±5% pitch variation per keystroke.
    func setPitchRandomization(_ enabled: Bool) {
        audioEngine.isPitchRandomizationEnabled = enabled
        updateDiagnosticsData()
    }

    /// Gets the current pitch randomization state.
    var pitchRandomization: Bool {
        return audioEngine.isPitchRandomizationEnabled
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

            // Track keystroke diagnostics
            self.totalKeystrokes += 1
            self.lastKeyCode = keyCode
            self.isLastKeyModifier = (keyCode == 0xFF)

            // Play a random sample from the current profile
            self.playRandomSample()

            // Update diagnostics after handling keystroke
            self.updateDiagnosticsData()
        }

        // Set up modifier flags tracking
        keyboardMonitor.onFlagsChanged = { [weak self] flags in
            guard let self = self else { return }
            self.updateModifierFlags(flags)
        }
    }

    /// Updates the modifier flags in diagnostics data.
    private func updateModifierFlags(_ flags: CGEventFlags) {
        diagnosticsData.isShiftPressed = flags.contains(.maskShift)
        diagnosticsData.isCommandPressed = flags.contains(.maskCommand)
        diagnosticsData.isOptionPressed = flags.contains(.maskAlternate)
        diagnosticsData.isControlPressed = flags.contains(.maskControl)
    }

    /// Updates the published diagnostics data.
    /// Called on every keystroke and when settings change.
    private func updateDiagnosticsData() {
        diagnosticsData.totalKeystrokes = totalKeystrokes
        diagnosticsData.lastKeyCode = lastKeyCode
        diagnosticsData.isLastKeyModifier = isLastKeyModifier
        diagnosticsData.lastKeyDisplayName = keyCodeDisplayName(lastKeyCode)
        diagnosticsData.activeProfile = currentProfile
        diagnosticsData.lastSampleIndex = lastSampleIndex
        diagnosticsData.lastSampleFilename = SoundAssets.sampleURL(for: currentProfile, index: lastSampleIndex)?.lastPathComponent ?? "-"

        // Latency stats from audio engine
        diagnosticsData.latencyAverageMs = audioEngine.averageLatency * 1000
        diagnosticsData.latencyMinMs = audioEngine.minLatency * 1000
        diagnosticsData.latencyMaxMs = audioEngine.maxLatency * 1000
        diagnosticsData.latencySampleCount = audioEngine.latencyMeasurementCount

        // Settings state
        diagnosticsData.volumePercent = volume
        diagnosticsData.isMuted = isMuted
        diagnosticsData.isPitchVariationEnabled = pitchRandomization
        diagnosticsData.isEnabled = isEnabled

        // Modifier flags (get current state)
        let flags = keyboardMonitor.currentModifierFlags
        updateModifierFlags(flags)
    }

    /// Returns a human-readable name for a key code.
    private func keyCodeDisplayName(_ keyCode: UInt16) -> String {
        if keyCode == 0xFF {
            return "Modifier (flagsChanged)"
        }
        // Common key code mappings
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 55: return "Command"
        case 56: return "Shift"
        case 57: return "Caps Lock"
        case 58: return "Option"
        case 59: return "Control"
        case 63: return "Fn"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 123: return "Left Arrow"
        case 124: return "Right Arrow"
        case 125: return "Down Arrow"
        case 126: return "Up Arrow"
        default: return "Key \(keyCode)"
        }
    }

    /// Selects and plays a random sample from the current profile.
    private func playRandomSample() {
        // Select a random sample index
        let sampleIndex = selectRandomSampleIndex()
        lastSampleIndex = sampleIndex

        do {
            try audioEngine.play(sampleIndex: sampleIndex)
        } catch {
            // Report error through error handler
            onError?(error)
        }
    }

    /// Plays a specific sample from the current profile.
    /// Used by the Debug Window's "Test Sound" button.
    /// - Parameter sampleIndex: The index of the sample to play (defaults to random).
    /// - Returns: True if playback was successful, false otherwise.
    @discardableResult
    func testPlay(sampleIndex: Int? = nil) -> Bool {
        // Don't play if muted
        guard !isMuted else { return false }

        let index = sampleIndex ?? selectRandomSampleIndex()
        lastSampleIndex = index

        do {
            try audioEngine.play(sampleIndex: index)
            // Update diagnostics after test play
            updateDiagnosticsData()
            return true
        } catch {
            onError?(error)
            return false
        }
    }

    /// Plays one sample from each profile in sequence with a delay.
    /// Used by the Debug Window's "Test All Profiles" button.
    /// - Parameter delayMs: Delay between samples in milliseconds (default 250ms).
    func testAllProfiles(delayMs: Int = 250) {
        let profiles: [SoundProfile] = [.linear, .tactile, .clicky]
        let delay = Double(delayMs) / 1000.0

        for (index, profile) in profiles.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * delay)) { [weak self] in
                guard let self = self else { return }
                do {
                    try self.setProfile(profile)
                    self.testPlay(sampleIndex: 0)
                } catch {
                    self.onError?(error)
                }
            }
        }
    }

    /// Returns current diagnostics data.
    /// - Returns: A DiagnosticsData struct with all current values.
    func diagnostics() -> DiagnosticsData {
        updateDiagnosticsData()
        return diagnosticsData
    }

    /// Resets the keystroke counter and latency statistics.
    /// Used by the Debug Window's "Reset Stats" button.
    func resetStats() {
        totalKeystrokes = 0
        lastKeyCode = 0
        isLastKeyModifier = false
        lastSampleIndex = 0
        audioEngine.resetLatencyMeasurements()
        updateDiagnosticsData()
    }

    /// Selects a random sample index.
    /// Currently uses uniform random selection. Future iterations could implement
    /// rotation logic to avoid playing the same sample twice in a row.
    /// - Returns: A random sample index between 0 and samplesPerProfile-1.
    func selectRandomSampleIndex() -> Int {
        return Int.random(in: 0..<SoundAssets.samplesPerProfile)
    }
}
