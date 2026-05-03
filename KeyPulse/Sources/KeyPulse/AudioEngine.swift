import Foundation
import AVFoundation
import QuartzCore
import os
import os.log

/// Low-latency audio playback engine for mechanical keyboard sounds.
/// Uses AVAudioEngine with multiple AVAudioPlayerNodes for concurrent playback.
/// All samples are pre-loaded into memory to eliminate file I/O during playback.
final class AudioEngine {
    /// Lock protecting mutable state accessed from both audio dispatch and main queues.
    /// Used for: isMuted, isRunning, volume, isPitchRandomizationEnabled, buffers, latencyMeasurements, nextPlayerIndex.
    private let stateLock = OSAllocatedUnfairLock()
    /// The underlying audio engine.
    private let engine = AVAudioEngine()

    /// Player nodes used for concurrent playback. Multiple nodes allow overlapping sounds.
    private var playerNodes: [AVAudioPlayerNode] = []

    /// Pre-loaded PCM buffers for the current profile.
    /// Index corresponds to sample index (0 to samplesPerProfile-1).
    /// Thread-safe backing — use stateLock for writes, play() reads under stateLock.
    private var _buffers: [AVAudioPCMBuffer] = []

    /// Cached buffers for all profiles (pre-warmed for instant switching).
    /// Key: SoundProfile, Value: Array of 4 PCM buffers.
    private var profileCache: [SoundProfile: [AVAudioPCMBuffer]] = [:]

    /// Whether all profiles have been pre-warmed.
    private(set) var isPreWarmed = false

    /// Current sound profile.
    private(set) var currentProfile: SoundProfile?

    /// Number of concurrent player nodes (allows this many simultaneous sounds).
    /// Set high enough to handle fast typing without cutting off sounds.
    private let concurrentPlayerCount = 8

    /// Index for round-robin player node selection.
    private var _nextPlayerIndex = 0

    /// Whether the engine is currently running.
    private var _isRunning = false

    /// Volume level (0.0 to 1.0).
    private var _volume: Float = 1.0

    /// Mute state. When true, playback is short-circuited.
    private var _isMuted = false

    /// Pitch randomization state. When true, playback rate varies by ±5% per keystroke.
    private var _isPitchRandomizationEnabled = false

    /// Re-entrancy guard for configuration change handler.
    private var _isRestarting = false

    /// Latency measurements for performance monitoring.
    private var _latencyMeasurements: [TimeInterval] = []

    /// Observer token for audio engine configuration changes (route changes, sample rate).
    private var configChangeObserver: NSObjectProtocol?

    // MARK: - Thread-Safe Accessors

    /// Volume level (0.0 to 1.0). Thread-safe via stateLock.
    var volume: Float {
        get { stateLock.withLock { _volume } }
        set { stateLock.withLock { _volume = max(0.0, min(1.0, newValue)) }; updateVolume() }
    }

    /// Mute state. Thread-safe via stateLock.
    var isMuted: Bool {
        get { stateLock.withLock { _isMuted } }
        set { stateLock.withLock { _isMuted = newValue } }
    }

    /// Pitch randomization state. Thread-safe via stateLock.
    var isPitchRandomizationEnabled: Bool {
        get { stateLock.withLock { _isPitchRandomizationEnabled } }
        set { stateLock.withLock { _isPitchRandomizationEnabled = newValue } }
    }

    /// Whether the engine is currently running. Thread-safe via stateLock.
    private(set) var isRunning: Bool {
        get { stateLock.withLock { _isRunning } }
        set { stateLock.withLock { _isRunning = newValue } }
    }

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

            // Register for audio configuration changes (headphones, Bluetooth, sample rate)
            registerConfigurationObserver()
        } catch {
            throw AudioEngineError.engineStartFailed
        }
    }

    /// Registers for AVAudioEngineConfigurationChange notifications.
    /// When the audio route changes (headphones plugged/unplugged, Bluetooth device),
    /// the engine's format may change, making pre-converted buffers incompatible.
    /// We restart the engine and clear caches to re-convert buffers to the new format.
    private func registerConfigurationObserver() {
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isRunning else { return }

            // Re-entrancy guard: prevent recursive calls if engine.stop() triggers
            // another configuration change notification while the engine is unstable.
            let alreadyRestarting = self.stateLock.withLock {
                if self._isRestarting { return true }
                self._isRestarting = true
                return false
            }
            guard !alreadyRestarting else {
                Logger.audioEngine.info("Config change handler already running — suppressing nested invocation")
                return
            }

            Logger.audioEngine.info("Audio configuration changed — restarting engine")

            // Remember current profile to reload after restart
            let savedProfile = self.currentProfile

            // Stop and restart the engine with the new format
            self.engine.stop()

            // Clear caches — buffers were converted to the old format
            self.stateLock.withLock {
                self._buffers.removeAll()
                self._isRestarting = false
            }
            self.profileCache.removeAll()
            self.isPreWarmed = false

            do {
                try self.engine.start()
                Logger.audioEngine.info("Engine restarted after configuration change")

                // Re-load the current profile (re-converts buffers to new format)
                if let profile = savedProfile {
                    try self.loadProfile(profile)
                    Logger.audioEngine.info("Profile '\(profile.rawValue)' reloaded with new format")

                    // Re-pre-warm all profiles so instant switching is restored
                    do {
                        try self.preWarmAllProfiles()
                    } catch {
                        Logger.audioEngine.error("Failed to re-pre-warm after config change: \(error.localizedDescription)")
                    }
                }
            } catch {
                Logger.audioEngine.error("Failed to restart engine after configuration change: \(error.localizedDescription)")
                self.isRunning = false
            }
        }
    }

    /// Stops the audio engine and releases player nodes.
    func stop() {
        guard isRunning else { return }

        // Remove configuration observer
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }

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
        // Check if profile is already cached (pre-warmed)
        if let cachedBuffers = profileCache[profile] {
            // Instant switch using cached buffers
            stateLock.withLock {
                _buffers = cachedBuffers
            }
            currentProfile = profile
            return
        }

        // Fallback: Load on-demand (first time or cache miss)
        let urls = SoundAssets.sampleURLs(for: profile)
        guard urls.count == SoundAssets.samplesPerProfile else {
            throw AudioEngineError.bufferLoadFailed
        }

        var newBuffers: [AVAudioPCMBuffer] = []
        newBuffers.reserveCapacity(urls.count)

        for url in urls {
            guard let buffer = loadAndConvertBuffer(from: url) else {
                throw AudioEngineError.bufferLoadFailed
            }
            newBuffers.append(buffer)
        }

        let buffersToStore = newBuffers
        stateLock.withLock {
            _buffers = buffersToStore
        }
        currentProfile = profile
    }

    /// Pre-warms all profiles by loading and caching their buffers.
    /// Call this after engine start for instant profile switching.
    /// - Throws: AudioEngineError if any profile fails to load.
    func preWarmAllProfiles() throws {
        guard isRunning else {
            throw AudioEngineError.engineNotRunning
        }

        let profiles: [SoundProfile] = [.linear, .tactile, .clicky]

        for profile in profiles {
            // Skip if already cached
            guard profileCache[profile] == nil else { continue }

            let urls = SoundAssets.sampleURLs(for: profile)
            guard urls.count == SoundAssets.samplesPerProfile else {
                throw AudioEngineError.bufferLoadFailed
            }

            var profileBuffers: [AVAudioPCMBuffer] = []
            profileBuffers.reserveCapacity(urls.count)

            for url in urls {
                guard let buffer = loadAndConvertBuffer(from: url) else {
                    throw AudioEngineError.bufferLoadFailed
                }
                profileBuffers.append(buffer)
            }

            profileCache[profile] = profileBuffers
        }

        isPreWarmed = true
    }

    /// Loads a WAV file and converts it to the common format if needed.
    /// - Parameter url: URL to the WAV file.
    /// - Returns: The loaded buffer in common format, or nil if loading fails.
    private func loadAndConvertBuffer(from url: URL) -> AVAudioPCMBuffer? {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            Logger.audioEngine.error("Failed to open audio file \(url.lastPathComponent): \(error.localizedDescription)")
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
            Logger.audioEngine.error("Audio conversion error: \(error.localizedDescription)")
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

        // Atomically snapshot engine state under the lock
        let playbackState = stateLock.withLock { () -> (buffer: AVAudioPCMBuffer, playerIndex: Int, volume: Float, shouldRandomizePitch: Bool)? in
            guard !_isMuted, _isRunning else { return nil }
            guard sampleIndex >= 0, sampleIndex < _buffers.count else { return nil }
            let idx = _nextPlayerIndex
            _nextPlayerIndex = (_nextPlayerIndex + 1) % concurrentPlayerCount
            return (_buffers[sampleIndex], idx, _volume, _isPitchRandomizationEnabled)
        }

        guard let state = playbackState else {
            // Check which condition caused the nil return by re-reading under the lock.
            // We must be careful: isMuted → silent return, notRunning → throw, bad index → throw.
            let (muted, running, hasValidIndex) = stateLock.withLock {
                (_isMuted, _isRunning, sampleIndex >= 0 && sampleIndex < _buffers.count)
            }
            if muted {
                // Short-circuit: silent return, no error
                return
            }
            if !running {
                throw AudioEngineError.engineNotRunning
            }
            if !hasValidIndex {
                throw AudioEngineError.invalidSampleIndex
            }
            // Shouldn't reach here, but handle gracefully
            return
        }

        let player = playerNodes[state.playerIndex]

        // Apply pitch randomization if enabled
        if state.shouldRandomizePitch {
            player.rate = Float.random(in: pitchRandomizationRange)
        } else {
            player.rate = 1.0
        }

        // Schedule and play the buffer
        player.scheduleBuffer(state.buffer, at: nil, options: .interrupts, completionHandler: nil)

        // Set volume and start playback
        player.volume = state.volume
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
        stateLock.withLock { _buffers.count }
    }

    /// Returns true if the specified profile is currently loaded.
    /// - Parameter profile: The profile to check.
    /// - Returns: True if this profile is loaded and ready to play.
    func isProfileLoaded(_ profile: SoundProfile) -> Bool {
        stateLock.withLock {
            currentProfile == profile && _buffers.count == SoundAssets.samplesPerProfile
        }
    }

    // MARK: - Latency Measurement

    /// Maximum number of latency measurements to keep in history.
    private let maxLatencyHistorySize = 100

    /// Measures and records the latency for a play() call.
    /// Thread-safe via stateLock.
    /// - Parameter triggerTime: The timestamp when the keystroke was detected.
    func recordLatencyMeasurement(triggerTime: TimeInterval) {
        let outputTime = CACurrentMediaTime()
        let latency = outputTime - triggerTime

        stateLock.withLock {
            _latencyMeasurements.append(latency)
            if _latencyMeasurements.count > maxLatencyHistorySize {
                _latencyMeasurements.removeFirst(_latencyMeasurements.count - maxLatencyHistorySize)
            }
        }
    }

    /// Returns the average latency from recent measurements.
    /// - Returns: Average latency in seconds, or 0 if no measurements available.
    var averageLatency: TimeInterval {
        stateLock.withLock {
            guard !_latencyMeasurements.isEmpty else { return 0 }
            let total = _latencyMeasurements.reduce(0, +)
            return total / Double(_latencyMeasurements.count)
        }
    }

    /// Returns the maximum latency from recent measurements.
    /// - Returns: Maximum latency in seconds, or 0 if no measurements available.
    var maxLatency: TimeInterval {
        stateLock.withLock { _latencyMeasurements.max() ?? 0 }
    }

    /// Returns the minimum latency from recent measurements.
    /// - Returns: Minimum latency in seconds, or 0 if no measurements available.
    var minLatency: TimeInterval {
        stateLock.withLock { _latencyMeasurements.min() ?? 0 }
    }

    /// Returns the number of latency measurements collected.
    var latencyMeasurementCount: Int {
        stateLock.withLock { _latencyMeasurements.count }
    }

    /// Clears all latency measurements.
    func resetLatencyMeasurements() {
        stateLock.withLock { _latencyMeasurements.removeAll() }
    }

    /// Returns a formatted latency report for debugging/verification.
    /// - Returns: A string with latency statistics.
    func latencyReport() -> String {
        let count = stateLock.withLock { _latencyMeasurements.count }
        guard count > 0 else {
            return "No latency measurements available"
        }

        let avgMs = averageLatency * 1000
        let maxMs = maxLatency * 1000
        let minMs = minLatency * 1000

        return """
        Latency Statistics (\(count) samples):
        - Average: \(String(format: "%.3f", avgMs)) ms
        - Maximum: \(String(format: "%.3f", maxMs)) ms
        - Minimum: \(String(format: "%.3f", minMs)) ms
        - Target: < 20ms
        - Status: \(avgMs < 20 ? "✅ PASS" : "❌ FAIL")
        """
    }
}
