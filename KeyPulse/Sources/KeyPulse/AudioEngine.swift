import Foundation
import AVFoundation
import QuartzCore
import os.lock

/// Low-latency audio playback engine for mechanical keyboard sounds.
/// Uses AVAudioEngine with multiple AVAudioPlayerNodes for concurrent playback.
/// All samples are pre-loaded into memory to eliminate file I/O during playback.
final class AudioEngine {
    /// The underlying audio engine.
    private let engine = AVAudioEngine()

    /// Player nodes used for concurrent playback. Multiple nodes allow overlapping sounds.
    private var playerNodes: [AVAudioPlayerNode] = []

    /// Pre-loaded PCM buffers for the current profile.
    /// Index corresponds to sample index (0 to samplesPerProfile-1).
    private var buffers: [AVAudioPCMBuffer] = []

    /// Current sound profile.
    private(set) var currentProfile: SoundProfile?

    /// Number of concurrent player nodes (allows this many simultaneous sounds).
    /// Set high enough to handle fast typing without cutting off sounds.
    private let concurrentPlayerCount = 8

    /// Index for round-robin player node selection.
    private var nextPlayerIndex = 0

    /// Lock for thread-safe player node selection.
    /// Uses os_unfair_lock for lower latency compared to NSLock.
    private var playerLock = os_unfair_lock()

    /// Whether the engine is currently running.
    private(set) var isRunning = false

    /// Volume level (0.0 to 1.0).
    var volume: Float = 1.0 {
        didSet {
            // Clamp to valid range
            volume = max(0.0, min(1.0, volume))
            updateVolume()
        }
    }

    /// Mute state. When true, playback is short-circuited.
    var isMuted = false

    /// Pitch randomization state. When true, playback rate varies by ±5% per keystroke.
    var isPitchRandomizationEnabled = false

    /// Randomization range for pitch variation (±5% = 0.95 to 1.05).
    private let pitchRandomizationRange: ClosedRange<Float> = 0.95...1.05

    /// The common format used for all audio processing.
    /// Uses the main mixer's input format which is typically stereo @ 44.1kHz or 48kHz.
    private var commonFormat: AVAudioFormat {
        return engine.mainMixerNode.inputFormat(forBus: 0)
    }

    /// Error types for AudioEngine operations.
    enum AudioEngineError: Error {
        case engineNotRunning
        case invalidSampleIndex
        case bufferLoadFailed
        case engineStartFailed
    }

    // MARK: - Lifecycle

    /// Creates a new AudioEngine instance.
    /// Note: Call `start()` and `loadProfile(_:)` before playing.
    init() {
        // Engine is created but not started until explicitly requested
    }

    deinit {
        stop()
    }

    /// Starts the audio engine and initializes player nodes.
    /// - Throws: AudioEngineError if the engine fails to start.
    func start() throws {
        guard !isRunning else { return }

        // Get the common format for all audio processing
        let format = commonFormat

        // Create player nodes
        playerNodes.reserveCapacity(concurrentPlayerCount)
        for _ in 0..<concurrentPlayerCount {
            let playerNode = AVAudioPlayerNode()
            playerNodes.append(playerNode)
            engine.attach(playerNode)

            // Connect to main mixer with the common format
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        }

        // Start the engine
        do {
            try engine.start()
            isRunning = true
            updateVolume()
        } catch {
            throw AudioEngineError.engineStartFailed
        }
    }

    /// Stops the audio engine and releases player nodes.
    func stop() {
        guard isRunning else { return }

        // Stop all player nodes
        for player in playerNodes {
            player.stop()
        }

        // Stop and reset engine
        engine.stop()

        // Detach player nodes
        for player in playerNodes {
            engine.detach(player)
        }

        playerNodes.removeAll()
        isRunning = false
    }

    // MARK: - Profile Loading

    /// Loads all samples for the specified profile into memory.
    /// - Parameter profile: The sound profile to load.
    /// - Throws: AudioEngineError if samples fail to load.
    func loadProfile(_ profile: SoundProfile) throws {
        // Get sample URLs for the profile
        let urls = SoundAssets.sampleURLs(for: profile)
        guard urls.count == SoundAssets.samplesPerProfile else {
            throw AudioEngineError.bufferLoadFailed
        }

        // Load each sample into a PCM buffer, converting to common format
        var newBuffers: [AVAudioPCMBuffer] = []
        newBuffers.reserveCapacity(urls.count)

        for url in urls {
            guard let buffer = loadAndConvertBuffer(from: url) else {
                throw AudioEngineError.bufferLoadFailed
            }
            newBuffers.append(buffer)
        }

        // Atomically swap buffers
        buffers = newBuffers
        currentProfile = profile
    }

    /// Loads a WAV file and converts it to the common format if needed.
    /// - Parameter url: URL to the WAV file.
    /// - Returns: The loaded buffer in common format, or nil if loading fails.
    private func loadAndConvertBuffer(from url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else {
            return nil
        }

        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            return nil
        }

        do {
            try file.read(into: sourceBuffer)
        } catch {
            return nil
        }

        // Get the target format (common format used by the engine)
        let targetFormat = commonFormat

        // Check if conversion is needed
        if sourceBuffer.format == targetFormat {
            return sourceBuffer
        }

        // Create output buffer in target format
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: sourceBuffer.frameCapacity
        ) else {
            return nil
        }

        // Convert the buffer format
        guard let converter = AVAudioConverter(from: sourceBuffer.format, to: targetFormat) else {
            return nil
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("Audio conversion error: \(error)")
            return nil
        }

        return outputBuffer
    }

    // MARK: - Playback

    /// Plays a sample from the currently loaded profile.
    /// This method is designed for low-latency triggering with no file I/O.
    /// - Parameter sampleIndex: Index of the sample to play (0 to samplesPerProfile-1).
    /// - Throws: AudioEngineError if playback fails.
    func play(sampleIndex: Int) throws {
        // Capture trigger time for latency measurement
        let triggerTime = CACurrentMediaTime()

        // Short-circuit if muted
        guard !isMuted else { return }

        // Validate engine state
        guard isRunning else {
            throw AudioEngineError.engineNotRunning
        }

        // Validate sample index
        guard sampleIndex >= 0 && sampleIndex < buffers.count else {
            throw AudioEngineError.invalidSampleIndex
        }

        // Get the pre-loaded buffer
        let buffer = buffers[sampleIndex]

        // Select player node using round-robin (thread-safe)
        let playerIndex: Int
        os_unfair_lock_lock(&playerLock)
        playerIndex = nextPlayerIndex
        nextPlayerIndex = (nextPlayerIndex + 1) % concurrentPlayerCount
        os_unfair_lock_unlock(&playerLock)

        let player = playerNodes[playerIndex]

        // Apply pitch randomization if enabled
        if isPitchRandomizationEnabled {
            let rate = Float.random(in: pitchRandomizationRange)
            player.rate = rate
        } else {
            player.rate = 1.0
        }

        // Schedule and play the buffer
        // Using nil for when makes it play immediately (lowest latency)
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)

        // Set volume on the player node before playing
        player.volume = volume

        // Start playback if not already playing
        if !player.isPlaying {
            player.play()
        }

        // Record latency measurement after scheduling
        recordLatencyMeasurement(triggerTime: triggerTime)
    }

    // MARK: - Volume Control

    /// Updates the volume on all player nodes.
    private func updateVolume() {
        for player in playerNodes {
            player.volume = volume
        }
    }

    /// Returns the number of currently loaded buffers.
    var loadedBufferCount: Int {
        return buffers.count
    }

    /// Returns true if the specified profile is currently loaded.
    /// - Parameter profile: The profile to check.
    /// - Returns: True if this profile is loaded and ready to play.
    func isProfileLoaded(_ profile: SoundProfile) -> Bool {
        return currentProfile == profile && buffers.count == SoundAssets.samplesPerProfile
    }

    // MARK: - Latency Measurement

    /// Stores recent latency measurements for performance monitoring.
    /// Values are in seconds (trigger-to-output time).
    private var latencyMeasurements: [TimeInterval] = []

    /// Maximum number of latency measurements to keep in history.
    private let maxLatencyHistorySize = 100

    /// Measures and records the latency for a play() call.
    /// Call this at the start of play() with the timestamp when play() was invoked.
    /// - Parameter triggerTime: The timestamp when the keystroke was detected.
    func recordLatencyMeasurement(triggerTime: TimeInterval) {
        let outputTime = CACurrentMediaTime()
        let latency = outputTime - triggerTime

        latencyMeasurements.append(latency)

        // Keep only recent measurements
        if latencyMeasurements.count > maxLatencyHistorySize {
            latencyMeasurements.removeFirst(latencyMeasurements.count - maxLatencyHistorySize)
        }
    }

    /// Returns the average latency from recent measurements.
    /// - Returns: Average latency in seconds, or 0 if no measurements available.
    var averageLatency: TimeInterval {
        guard !latencyMeasurements.isEmpty else { return 0 }
        let total = latencyMeasurements.reduce(0, +)
        return total / Double(latencyMeasurements.count)
    }

    /// Returns the maximum latency from recent measurements.
    /// - Returns: Maximum latency in seconds, or 0 if no measurements available.
    var maxLatency: TimeInterval {
        return latencyMeasurements.max() ?? 0
    }

    /// Returns the minimum latency from recent measurements.
    /// - Returns: Minimum latency in seconds, or 0 if no measurements available.
    var minLatency: TimeInterval {
        return latencyMeasurements.min() ?? 0
    }

    /// Returns the number of latency measurements collected.
    var latencyMeasurementCount: Int {
        return latencyMeasurements.count
    }

    /// Clears all latency measurements.
    func resetLatencyMeasurements() {
        latencyMeasurements.removeAll()
    }

    /// Returns a formatted latency report for debugging/verification.
    /// - Returns: A string with latency statistics.
    func latencyReport() -> String {
        guard !latencyMeasurements.isEmpty else {
            return "No latency measurements available"
        }

        let avgMs = averageLatency * 1000
        let maxMs = maxLatency * 1000
        let minMs = minLatency * 1000

        return """
        Latency Statistics (\(latencyMeasurements.count) samples):
        - Average: \(String(format: "%.3f", avgMs)) ms
        - Maximum: \(String(format: "%.3f", maxMs)) ms
        - Minimum: \(String(format: "%.3f", minMs)) ms
        - Target: < 20ms
        - Status: \(avgMs < 20 ? "✅ PASS" : "❌ FAIL")
        """
    }
}
