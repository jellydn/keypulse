# Testing Patterns

**Analysis Date:** 2026-05-02

## Test Framework

**Runner:**
- XCTest (Apple's built-in Swift testing framework)
- Config: `KeyPulse/Package.swift` — `.testTarget(name: "KeyPulseTests", dependencies: ["KeyPulse"])`

**Assertion Library:**
- XCTest assertions: `XCTAssertEqual`, ` XCTAssertTrue`, ` XCTAssertFalse`, ` XCTAssertNil`, ` XCTAssertNotNil`, ` XCTAssertNoThrow`, ` XCTAssertThrowsError`, ` XCTAssertGreaterThanOrEqual`, ` XCTAssertLessThan`
- No third-party assertion libraries

**Run Commands:**
```bash
cd KeyPulse && swift test              # Run all tests
cd KeyPulse && swift test --parallel   # Run tests in parallel
cd KeyPulse && swift build             # Build before testing
just test                              # Via justfile (project root)
```

**Coverage:**
```bash
cd KeyPulse && swift test --enable-code-coverage
```

## Test File Organization

**Location:**
- Separate test target: `KeyPulse/Tests/KeyPulseTests/`
- Single test file: `KeyPulseTests.swift`
- Tests are in a separate SPM target with `@testable import KeyPulse`

**Naming:**
- File: `KeyPulseTests.swift` (matches module name + "Tests")
- Test class: `KeyPulseTests: XCTestCase`
- Test methods: `test[Component][Scenario]` pattern

**Structure:**
```
KeyPulse/
└── Tests/
    └── KeyPulseTests/
        └── KeyPulseTests.swift    # All tests in one file
```

## Test Structure

**Suite Organization:**
```swift
final class KeyPulseTests: XCTestCase {

    // MARK: - AudioEngine Tests

    func testAudioEngineInitialization() { ... }
    func testAudioEngineStartStop() throws { ... }
    func testAudioEngineLoadProfile() throws { ... }

    // MARK: - SoundAssets Tests

    func testSoundProfileDisplayNames() { ... }
    func testSoundAssetsSampleURLsForLinear() { ... }

    // MARK: - KeyPulseController Tests

    func testKeyPulseControllerInitialization() throws { ... }

    // MARK: - SettingsStore Tests

    func testSettingsStoreDefaultProfile() { ... }

    // MARK: - Pitch Randomization Tests

    func testAudioEnginePitchRandomizationEnabled() throws { ... }

    // MARK: - Launch at Login Tests

    func testSettingsStoreDefaultLaunchAtLogin() { ... }
}
```

**Patterns:**
- **Arrange/Act/Assert** — standard 3-phase pattern throughout
- **Setup**: Create fresh instances inline per test (no `setUp()` method)
- **Teardown**: `defer { engine.stop() }` or `defer { controller.stop() }` for cleanup
- **MARK sections**: Grouped by component — `// MARK: - AudioEngine Tests`, `// MARK: - SoundAssets Tests`, `// MARK: - KeyPulseController Tests`, `// MARK: - SettingsStore Tests`, `// MARK: - Pitch Randomization Tests`, `// MARK: - Launch at Login Tests`

## Mocking

**Framework:** None — no mock framework used

**Patterns:**
- Tests use **actual production components** (real `AudioEngine`, real `KeyPulseController`, real `SettingsStore`)
- `AudioEngine` is tested with real audio playback via AVAudioEngine
- `KeyPulseController` is tested with real `AudioEngine` and `KeyboardMonitor`
- `SettingsStore.shared` singleton is used directly (with `resetToDefaults()` before each test)
- No protocol-based dependency injection for testing
- `KeyboardMonitor` cannot fully test start() without accessibility permission (tests avoid this path)

**What to Mock:**
- Currently nothing — all tests use real instances

**What NOT to Mock:**
- `AudioEngine` — tested directly
- `KeyPulseController` — tested as integration with real `AudioEngine`
- `SoundAssets` — tested with real bundle resources (`Bundle.module`)

## Fixtures and Factories

**Test Data:**
- Sound profile enum values: `SoundProfile.allCases` iterated in tests
- Settings defaults verified against `SettingsStore.Defaults` values
- Volume bounds tested: 0, 50, 100, -50 (underflow), 150 (overflow)
- Sample indices tested: valid (0-3), invalid (-1, 4, 100)

**Location:**
- No separate fixture files or test data directories
- Test data is inline values within test methods
- Sound resources accessed via `Bundle.module` (SPM resource bundle)

**Singleton pattern for SettingsStore:**
```swift
func testSettingsStoreDefaultProfile() {
    let store = SettingsStore.shared
    store.resetToDefaults()  // Reset to known state before testing
    XCTAssertEqual(store.profile, .linear)
}
```

**Controller lifecycle pattern:**
```swift
func testKeyPulseControllerSetProfile() throws {
    let controller = try KeyPulseController(initialProfile: .linear)
    defer { controller.stop() }  // Cleanup after test

    try controller.setProfile(.tactile)
    XCTAssertEqual(controller.currentProfile, .tactile)
}
```

## Coverage

**Requirements:** None enforced (no minimum coverage target)

**View Coverage:**
```bash
cd KeyPulse && swift test --enable-code-coverage
# Reports to: .build/debug/codecov/
```

**Current Coverage Areas:**
- `AudioEngine` — initialization, start/stop, profile loading, playback, mute, volume, pitch randomization
- `SoundProfile` — display names, raw values, allCases, id
- `SoundAssets` — sample URLs, per-profile count, verification
- `KeyPulseController` — initialization, profile switching, volume, mute, enabled state, random sample selection
- `SettingsStore` — defaults, persistence, clamping, round-trip, controller sync
- `KeyPulseAppDelegate` — basic initialization only

**Not Covered:**
- `MenuBarManager` — no tests (UI-dependent, requires NSStatusBar)
- `KeyboardMonitor.start()` — requires accessibility permission
- `KeyboardMonitor` event tap callback — requires real keyboard events
- CGEvent tap creation — requires system accessibility entitlement
- `SMAppService` registration — requires signed app bundle

## Test Types

**Unit Tests:**
- `SoundProfile` enum values and properties
- `SoundAssets` URL resolution and file existence
- `SettingsStore` get/set and clamping logic
- `AudioEngine` state management (start/stop/loadProfile)
- `KeyPulseController` state queries and mutations

**Integration Tests:**
- `KeyPulseController` + `AudioEngine` — verified by testing controller methods that exercise audio engine (profile switching, volume, mute)
- `SettingsStore` ↔ `KeyPulseController` — verified by `testSettingsStoreRoundTrip()` and `testSettingsStoreSaveFromController()`/`testSettingsStoreApplyToController()`
- `AudioEngine` + `Bundle.module` — verified by loading and playing all profiles

**E2E Tests:**
- Not used — no UI automation testing framework

## Common Patterns

**Error Testing:**
```swift
func testAudioEnginePlayThrowsWhenNotRunning() throws {
    let engine = AudioEngine()
    XCTAssertThrowsError(try engine.play(sampleIndex: 0)) { error in
        XCTAssertEqual(error as? AudioEngine.AudioEngineError, .engineNotRunning)
    }
}

func testAudioEnginePlayThrowsForInvalidIndex() throws {
    let engine = AudioEngine()
    try engine.start()
    defer { engine.stop() }
    try engine.loadProfile(.linear)

    XCTAssertThrowsError(try engine.play(sampleIndex: -1)) { error in
        XCTAssertEqual(error as? AudioEngine.AudioEngineError, .invalidSampleIndex)
    }
}
```

**Defer Cleanup Pattern:**
```swift
func testAudioEngineLoadProfile() throws {
    let engine = AudioEngine()
    try engine.start()
    defer { engine.stop() }  // Cleanup guaranteed even on error

    try engine.loadProfile(.linear)
    XCTAssertEqual(engine.currentProfile, .linear)
}
```

**Reset Before Test Pattern:**
```swift
func testSettingsStoreDefaultProfile() {
    let store = SettingsStore.shared
    store.resetToDefaults()  // Ensure clean state
    XCTAssertEqual(store.profile, .linear)
}
```

**Iteration Over Enum Cases:**
```swift
func testAudioEngineAllProfiles() throws {
    let engine = AudioEngine()
    try engine.start()
    defer { engine.stop() }

    for profile in SoundProfile.allCases {
        try engine.loadProfile(profile)
        XCTAssertTrue(engine.isProfileLoaded(profile))
        for index in 0..<4 {
            XCTAssertNoThrow(try engine.play(sampleIndex: index))
        }
    }
}
```

**Boundary Value Testing:**
```swift
func testSettingsStoreVolumeClamping() {
    store.volume = 150
    XCTAssertEqual(store.volume, 100)  // Over max

    store.volume = -50
    XCTAssertEqual(store.volume, 0)   // Under min
}
```

---

*Testing analysis: 2026-05-02*
