import XCTest
@testable import KeyPulse
import AVFoundation

/// Measures the overhead of AVAudioConverter during buffer loading.
///
/// The `loadAndConvertBuffer` method in AudioEngine:
/// 1. Loads WAV file via AVAudioFile
/// 2. Reads into source AVAudioPCMBuffer (WAV's native format)
/// 3. Checks if conversion is needed (source format vs engine format)
/// 4. If needed: creates AVAudioConverter + output buffer + converts
///
/// If WAV files were pre-encoded in the engine's native format, the converter
/// step (steps 3-4) could be eliminated, reducing load time and memory churn.
final class BufferConversionPerformanceTest: XCTestCase {

    /// Measures real profile load through the AudioEngine API (includes conversion).
    func testFullProfileLoadThroughEngine() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        let iterations = 50
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            try engine.loadProfile(.linear)
            try engine.loadProfile(.tactile)
            try engine.loadProfile(.clicky)
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalProfiles = iterations * 3
        let avgMicroseconds = ((end - start) * 1_000_000) / Double(totalProfiles)
        let avgPerSample = avgMicroseconds / 4.0

        print("METRIC buffer_convert_µs=\(String(format: "%.2f", avgPerSample))")

        // Regression guard: buffer load+convert under 1ms (baseline ~99µs)
        XCTAssertLessThan(avgPerSample, 1000.0, "Buffer load+convert must be under 1000µs")
        print("INFO: Average per-sample load (includes conversion): \(String(format: "%.2f", avgPerSample)) µs")
        print("INFO: Average per-profile load (4 samples): \(String(format: "%.2f", avgMicroseconds)) µs")
        print("INFO: Total for \(totalProfiles) profile loads: \(String(format: "%.2f", (end - start) * 1_000_000)) µs")
    }

    /// Measures pre-warm (loads all profiles once, includes conversion).
    func testPreWarmThroughEngine() throws {
        let engine = AudioEngine()
        try engine.start()
        defer { engine.stop() }

        let iterations = 30
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<iterations {
            try engine.preWarmAllProfiles()
        }

        let end = CFAbsoluteTimeGetCurrent()
        let avgMicroseconds = ((end - start) * 1_000_000) / Double(iterations)
        // preWarmAllProfiles loads 12 samples (3 profiles × 4)
        let avgPerSample = avgMicroseconds / 12.0

        print("INFO: Average pre-warm (12 samples): \(String(format: "%.2f", avgMicroseconds)) µs")
        print("INFO: Average per-sample in pre-warm: \(String(format: "%.2f", avgPerSample)) µs")
        print("INFO: Total for \(iterations) pre-warms: \(String(format: "%.2f", (end - start) * 1_000_000)) µs")
    }

    /// Measures the conversion step in isolation: load WAV → convert to engine format.
    /// This isolates the AVAudioConverter overhead from the AVAudioFile read overhead.
    func testConversionStepIsolation() throws {
        let tempEngine = AVAudioEngine()
        let engineFormat = tempEngine.mainMixerNode.inputFormat(forBus: 0)

        // Use one sample file
        guard let url = SoundAssets.sampleURLs(for: .linear).first else {
            XCTFail("No sample files found")
            return
        }

        guard let file = try? AVAudioFile(forReading: url) else {
            XCTFail("Could not open audio file")
            return
        }

        let sourceFormat = file.processingFormat
        let formatsMatch = sourceFormat == engineFormat
        print("INFO: Source format: \(sourceFormat)")
        print("INFO: Engine format: \(engineFormat)")
        print("INFO: Formats match: \(formatsMatch)")

        let iterations = 200
        var totalLoadUs: Double = 0
        var totalConvertUs: Double = 0

        for _ in 0..<iterations {
            // Re-open file each iteration to reset read position
            guard let f = try? AVAudioFile(forReading: url) else { continue }

            // Measure: AVAudioFile read only
            let t1 = CFAbsoluteTimeGetCurrent()
            guard let sourceBuffer = AVAudioPCMBuffer(
                pcmFormat: sourceFormat,
                frameCapacity: AVAudioFrameCount(f.length)
            ) else { continue }
            try f.read(into: sourceBuffer)
            let t2 = CFAbsoluteTimeGetCurrent()

            // Measure: conversion only
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: engineFormat,
                frameCapacity: sourceBuffer.frameCapacity
            ) else { continue }
            guard let converter = AVAudioConverter(from: sourceFormat, to: engineFormat) else { continue }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return sourceBuffer
            }
            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            let t3 = CFAbsoluteTimeGetCurrent()

            totalLoadUs += (t2 - t1) * 1_000_000
            totalConvertUs += (t3 - t2) * 1_000_000
        }

        let avgLoadUs = totalLoadUs / Double(iterations)
        let avgConvertUs = totalConvertUs / Double(iterations)
        let convertPercent = (avgConvertUs / (avgLoadUs + avgConvertUs)) * 100

        print("INFO: Average WAV load (read only): \(String(format: "%.2f", avgLoadUs)) µs")
        print("INFO: Average format conversion: \(String(format: "%.2f", avgConvertUs)) µs")
        print("INFO: Conversion is \(String(format: "%.1f", convertPercent))% of total")
        print("INFO: Total per sample: \(String(format: "%.2f", avgLoadUs + avgConvertUs)) µs")

        // If conversion is a significant portion, pre-encoding WAVs to engine format
        // would be worthwhile. If <10%, not worth the build complexity.
        if formatsMatch {
            print("INFO: Formats already match — no conversion needed!")
        }
    }
}
