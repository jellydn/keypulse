import XCTest
@testable import KeyPulse

/// Verifies that SettingsStore supports injectable UserDefaults for test isolation.
/// Without injection, tests sharing UserDefaults.standard would race during
/// parallel execution. With injection, each test gets its own suite.
final class SettingsStoreIsolationTest: XCTestCase {

    func testIsolatedStoresDoNotInterfere() {
        let suiteA = UserDefaults(suiteName: "test.isolation.a")!
        let suiteB = UserDefaults(suiteName: "test.isolation.b")!

        // Clean up any previous state
        suiteA.removePersistentDomain(forName: "test.isolation.a")
        suiteB.removePersistentDomain(forName: "test.isolation.b")

        let storeA = SettingsStore(defaults: suiteA)
        let storeB = SettingsStore(defaults: suiteB)

        // Both start with default profile
        storeA.resetToDefaults()
        storeB.resetToDefaults()
        XCTAssertEqual(storeA.profile, .linear)
        XCTAssertEqual(storeB.profile, .linear)

        // Change store A only
        storeA.profile = .tactile
        storeA.volume = 42

        // Store B should be unaffected
        XCTAssertEqual(storeA.profile, .tactile)
        XCTAssertEqual(storeA.volume, 42)
        XCTAssertEqual(storeB.profile, .linear)
        XCTAssertEqual(storeB.volume, 100)

        // Change store B only
        storeB.profile = .clicky
        storeB.isMuted = true

        // Store A should be unaffected
        XCTAssertEqual(storeA.profile, .tactile)
        XCTAssertFalse(storeA.isMuted)
        XCTAssertEqual(storeB.profile, .clicky)
        XCTAssertTrue(storeB.isMuted)

        // Clean up
        suiteA.removePersistentDomain(forName: "test.isolation.a")
        suiteB.removePersistentDomain(forName: "test.isolation.b")
    }

    func testIsolatedStoreRoundTrip() {
        let suite = UserDefaults(suiteName: "test.roundtrip")!
        suite.removePersistentDomain(forName: "test.roundtrip")

        let store = SettingsStore(defaults: suite)
        store.resetToDefaults()

        // Write settings
        store.profile = .clicky
        store.volume = 75
        store.isMuted = true
        store.isEnabled = false
        store.pitchRandomization = false

        // Create a new store backed by the same suite — should read persisted values
        let store2 = SettingsStore(defaults: suite)
        XCTAssertEqual(store2.profile, .clicky)
        XCTAssertEqual(store2.volume, 75)
        XCTAssertTrue(store2.isMuted)
        XCTAssertFalse(store2.isEnabled)
        XCTAssertFalse(store2.pitchRandomization)

        // Reset and verify
        store2.resetToDefaults()
        XCTAssertEqual(store2.profile, .linear)
        XCTAssertEqual(store2.volume, 100)

        suite.removePersistentDomain(forName: "test.roundtrip")
    }

    // MARK: - Schema Versioning

    func testSchemaVersionStampedOnFirstInit() {
        let suite = UserDefaults(suiteName: "test.schema.init")!
        suite.removePersistentDomain(forName: "test.schema.init")

        // Fresh UserDefaults should have no schema version
        XCTAssertEqual(suite.integer(forKey: "keypulse_schemaVersion"), 0)

        // Creating a SettingsStore should stamp the current version
        let store = SettingsStore(defaults: suite)
        _ = store.profile
        XCTAssertEqual(suite.integer(forKey: "keypulse_schemaVersion"), 1)

        suite.removePersistentDomain(forName: "test.schema.init")
    }

    func testSchemaVersionNotDowngraded() {
        let suite = UserDefaults(suiteName: "test.schema.nodowngrade")!
        suite.removePersistentDomain(forName: "test.schema.nodowngrade")

        // Simulate a future version (e.g., app downgraded after beta)
        suite.set(99, forKey: "keypulse_schemaVersion")

        // Creating a store should NOT downgrade the version
        let store = SettingsStore(defaults: suite)
        _ = store.profile
        XCTAssertEqual(suite.integer(forKey: "keypulse_schemaVersion"), 99,
                       "Schema version should not be downgraded by older app")

        suite.removePersistentDomain(forName: "test.schema.nodowngrade")
    }

    func testIsolatedStoreResetClearsOnlyOwnSuite() {
        let suiteA = UserDefaults(suiteName: "test.reset.a")!
        let suiteB = UserDefaults(suiteName: "test.reset.b")!
        suiteA.removePersistentDomain(forName: "test.reset.a")
        suiteB.removePersistentDomain(forName: "test.reset.b")

        let storeA = SettingsStore(defaults: suiteA)
        let storeB = SettingsStore(defaults: suiteB)

        storeA.profile = .tactile
        storeB.profile = .clicky

        // Reset only A
        storeA.resetToDefaults()
        XCTAssertEqual(storeA.profile, .linear)
        XCTAssertEqual(storeB.profile, .clicky, "Store B should be unaffected by A's reset")

        suiteA.removePersistentDomain(forName: "test.reset.a")
        suiteB.removePersistentDomain(forName: "test.reset.b")
    }
}
