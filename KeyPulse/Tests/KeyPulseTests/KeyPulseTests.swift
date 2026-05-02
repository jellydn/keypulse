import XCTest
@testable import KeyPulse

final class KeyPulseTests: XCTestCase {
    func testAppDelegateInitialization() {
        let delegate = KeyPulseAppDelegate()
        XCTAssertNotNil(delegate)
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
}
