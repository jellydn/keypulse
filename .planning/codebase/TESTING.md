# KeyPulse Testing Guide

## 1. Test Framework & Setup

### Framework
- **XCTest** (Apple's native testing framework, Swift 5.9+)
- Run via: `cd KeyPulse && swift test` or `just test`

### Test Target Configuration
```swift
// Package.swift
.testTarget(
    name: "KeyPulseTests",
    dependencies: ["KeyPulse"]
)
```
- No external test dependencies (no Quick/Nimble, no mocking frameworks)
- Tests import the main target via `@testable import KeyPulse`

### Test File Organization
```
Tests/KeyPulseTests/
  KeyPulseTests.swift                              # Main test suite
  AudioEngineConfigurationTest.swift               # Audio engine lifecycle tests
  AudioLatencyPerformanceTest.swift                # Latency benchmark
  BufferConversionPerformanceTest.swift            # Buffer conversion benchmark
  DiagnosticsUpdatePerformanceTest.swift           # Diagnostics overhead benchmark
  EngineStartupPerformanceTest.swift               # Startup time benchmark
  KeyboardDispatchPerformanceTest.swift            # Dispatch latency benchmark
  KeyboardMonitorResilienceTest.swift              # Sleep/wake resilience tests
  KeyCodeLookupPerformanceTest.swift               # Key code lookup benchmark
  KeystrokeDispatchLoadTest.swift                  # Load test under typing simulation
  LockPerformanceTest.swift                        # Lock acquisition benchmark
  MenuBarManagerTests.swift                        # Menu bar UI tests
  PitchRandomizationPerformanceTest.swift           # Pitch randomization benchmark
  PrintOverheadPerformanceTest.swift               # Print overhead benchmark
  ProfileLoadPerformanceTest.swift                 # Profile loading benchmark
  ProfileSwitchPerformanceTest.swift               # Profile switching benchmark
  SettingsStoreIsolationTest.swift                 # UserDefaults injection tests
  SettingsStorePerformanceTest.swift               # Settings access benchmark
  SettingsStoreTestExecutionTest.swift             # Test overhead benchmark
```

## 2. Test Patterns

### Test Class Naming
- **Suffix**: `Test` (not `Tests` — note the singular)
  - ✅ `AudioEngineConfigurationTest`
  - ✅ `MenuBarManagerTests`
  - ✅ `KeyPulseTests`
- Pattern: `{ComponentName}{Scenario}Test` or `{ComponentName}Tests`
- All classes are `final` and extend `XCTestCase`:
  ```swift
  final class AudioEngineConfigurationTest: XCTestCase {
  ```

### Test Method Naming
- `func test{Scenario}()` — describes what's being verified
  - `testAudioEngineInitialization()`
  - `testAudioEnginePlayThrowsWhenNotRunning()`
  - `testSettingsStoreVolumeClamping()`
  - `testDiagnosticsDataEquatable_identity()`
- Underscores between logical groups for Equatable tests:
  - `testDiagnosticsDataEquatable_keystrokeFields()`
  - `testDiagnosticsDataEquatable_latencyFields()`

### Test Method Patterns
1. **Arrange-Act-Assert** (AAA) — the dominant pattern:
   ```swift
   func testAudioEngineStartStop() throws {
       let engine = AudioEngine()                    // Arrange
       try engine.start()                             // Act
       XCTAssertTrue(engine.isRunning)                // Assert
       engine.stop()                                  // Cleanup
       XCTAssertFalse(engine.isRunning)               // Assert post-cleanup
   }
   ```

2. **Given-When-Then** — used in more complex tests:
   ```swift
   func testSettingsStoreRoundTrip() throws {
       // Given: a configured controller
       let controller1 = try KeyPulseController(initialProfile: .clicky)
       controller1.setVolume(60)
       store.saveFromController(controller1)

       // When: creating a new controller and applying settings
       let controller2 = try KeyPulseController(...)
       store.applyToController(controller2)

       // Then: settings persisted correctly
       XCTAssertEqual(controller2.volume, 60)
   }
   ```

### Setup/Teardown
- `override func setUp()` — create test fixtures
- `override func tearDown()` — release resources
- Example from `MenuBarManagerTests`:
  ```swift
  override func setUp() {
      super.setUp()
      controller = try? KeyPulseController(initialProfile: .linear)
  }

  override func tearDown() {
      controller?.stop()
      controller = nil
      super.tearDown()
  }
  ```

### Defer Cleanup Pattern
- Preferred over setUp/tearDown for per-method cleanup:
  ```swift
  func testAudioEngineLoadProfile() throws {
      let engine = AudioEngine()
      try engine.start()
      defer { engine.stop() }
      // ... test body
  }
  ```

### Throwing Tests
- Test methods are marked `throws` when testing throwing APIs:
  ```swift
  func testAudioEngineStartStop() throws { ... }
  ```
- Non-throwing methods test non-throwing behaviors:
  ```swift
  func testSoundProfileDisplayNames() { ... }
  ```

## 3. Assertion Patterns

### Standard XCTest Assertions
- `XCTAssertTrue(expression, message?)`
- `XCTAssertFalse(expression, message?)`
- `XCTAssertEqual(a, b, message?)`
- `XCTAssertNotNil(expression, message?)`
- `XCTAssertNil(expression, message?)`
- `XCTAssertGreaterThan(a, b, message?)`
- `XCTAssertLessThan(a, b, message?)`

### Error Assertions
- `XCTAssertNoThrow(try expression, message?)`
  - Used for operations that should succeed
  - Does NOT catch or suppress — test will still fail on thrown errors
- `XCTAssertThrowsError(try expression, message?)` with error type checking:
  ```swift
  XCTAssertThrowsError(try engine.play(sampleIndex: -1)) { error in
      XCTAssertEqual(error as? AudioEngine.AudioEngineError, .invalidSampleIndex)
  }
  ```

### Optional Assertions
- Guard-let pattern with `XCTFail`:
  ```swift
  guard let url = SoundAssets.sampleURLs(for: .linear).first else {
      XCTFail("No sample files found")
      return
  }
  ```

## 4. Async Test Patterns (XCTestExpectation)

### Expectation-Based Async Testing
- Used for `DispatchQueue.main.async` patterns:
  ```swift
  let expectation = self.expectation(description: "Dispatch completed")
  expectation.expectedFulfillmentCount = iterations

  DispatchQueue.main.async {
      // ... test work ...
      expectation.fulfill()
  }

  wait(for: [expectation], timeout: 10.0)
  ```

### Notification Observation in Tests
- Posting notifications to verify observer behavior:
  ```swift
  NotificationCenter.default.post(
      name: .AVAudioEngineConfigurationChange,
      object: nil
  )
  // Then wait for async handler to execute
  let expectation = XCTestExpectation(description: "Config change handled")
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      expectation.fulfill()
  }
  wait(for: [expectation], timeout: 1.0)
  ```

## 5. Performance Test Patterns

### Manual Timing with CFAbsoluteTimeGetCurrent
- All performance tests use manual timing rather than `measure {}` blocks:
  ```swift
  let start = CFAbsoluteTimeGetCurrent()
  // ... code to measure ...
  let end = CFAbsoluteTimeGetCurrent()
  let durationMs = (end - start) * 1000
  ```

### METRIC Output Convention
- Every performance test prints a `METRIC_` machine-readable line for metric collection:
  ```swift
  print("METRIC audio_latency_ms=\(String(format: "%.3f", avgLatencyMs))")
  print("METRIC engine_startup_ms=\(String(format: "%.3f", avgTime))")
  print("METRIC profile_load_ms=\(String(format: "%.3f", avgMs))")
  print("METRIC dispatch_latency_µs=\(String(format: "%.2f", avgLatency))")
  print("METRIC lock_acquire_µs=\(String(format: "%.4f", avg))")
  print("METRIC keycode_lookup_ns=\(String(format: "%.1f", avgNs))")
  print("METRIC pitch_randomization_µs=\(String(format: "%.4f", avgMicroseconds))")
  print("METRIC print_overhead_µs=\(String(format: "%.4f", avgPerCall))")
  print("METRIC buffer_convert_µs=\(String(format: "%.2f", avgPerSample))")
  print("METRIC diagnostics_update_µs=\(String(format: "%.2f", avgMicroseconds))")
  print("METRIC status_read_µs=\(String(format: "%.2f", avgMicroseconds))")
  print("METRIC test_execution_ms=\(String(format: "%.3f", avgTime))")
  print("METRIC keystroke_dispatch_ms=\(String(format: "%.3f", avgLatency))")
  print("METRIC profile_switch_ms=\(String(format: "%.3f", avgTime))")
  ```
- Format: `METRIC {name}_{unit}={value}`

### INFO Output Convention
- Human-readable details alongside metrics:
  ```swift
  print("INFO: Average latency: \(String(format: "%.3f", avgLatencyMs)) ms")
  print("INFO: Total iterations: \(iterationCount)")
  ```

### Warmup Phase
- Performance tests include a warmup phase before measurement:
  ```swift
  // Warmup - play a few samples to stabilize
  for i in 0..<4 { try? engine.play(sampleIndex: i) }
  engine.resetLatencyMeasurements()
  ```

### Regression Guards
- Every performance test includes upper-bound assertions:
  ```swift
  XCTAssertLessThan(avgLatencyMs, 50.0, "Average latency must be under 50ms")
  XCTAssertLessThan(avgTime, 500.0, "Engine startup must be under 500ms")
  XCTAssertLessThan(avgPerSample, 1000.0, "Buffer load+convert must be under 1000µs")
  ```

### Performance Test Categories

| Test File | What It Measures | Baseline |
|---|---|---|
| `AudioLatencyPerformanceTest` | Trigger-to-output latency | ~? ms (<20 target) |
| `EngineStartupPerformanceTest` | AVAudioEngine creation | ~27ms |
| `ProfileLoadPerformanceTest` | Load profile with conversion | ~0.46ms |
| `ProfileSwitchPerformanceTest` | Switch pre-warmed profiles | ~0ms (instant) |
| `BufferConversionPerformanceTest` | WAV→engine format conversion | ~99µs/sample |
| `KeyCodeLookupPerformanceTest` | Switch-based key code lookup | ~73ns |
| `KeyboardDispatchPerformanceTest` | DispatchQueue.main async latency | ~732µs |
| `KeystrokeDispatchLoadTest` | 120 WPM burst simulation | ~0.04ms |
| `LockPerformanceTest` | os_unfair_lock acquisition | ~0.1µs |
| `PitchRandomizationPerformanceTest` | Float.random(in:) overhead | ~0.36µs |
| `PrintOverheadPerformanceTest` | print() vs noop | ~0.53µs |
| `DiagnosticsUpdatePerformanceTest` | Full diagnostics() call | ~31µs |
| `SettingsStorePerformanceTest` | launchAtLogin read (SMAppService) | ~0.33µs cached, ~7ms uncached |
| `SettingsStoreTestExecutionTest` | Test pattern overhead | ~0.43ms |

## 6. Mocking & Dependency Injection

### No External Mocking Framework
- No Quick/Nimble, Cuckoo, or other mocking libraries
- Mocking done via:
  1. **Protocols** (not yet used — future pattern)
  2. **Dependency injection** (UserDefaults injection)
  3. **Callback stubs** (onError, onKeyDown)
  4. **Test-specific instances** (isolated UserDefaults suites)

### UserDefaults Injection Pattern
- `SettingsStore` accepts injectable `UserDefaults`:
  ```swift
  // Production
  static let shared = SettingsStore()

  // Test
  let suite = UserDefaults(suiteName: "test.isolation.a")!
  let store = SettingsStore(defaults: suite)
  ```
- Key pattern: each test gets its own `UserDefaults(suiteName:)` domain
- Cleanup via `removePersistentDomain(forName:)` in test teardown:
  ```swift
  suiteA.removePersistentDomain(forName: "test.isolation.a")
  suiteB.removePersistentDomain(forName: "test.isolation.b")
  ```

### Isolation Test Pattern (`SettingsStoreIsolationTest`)
- Verifies that parallel tests don't interfere:
  ```swift
  let storeA = SettingsStore(defaults: suiteA)
  let storeB = SettingsStore(defaults: suiteB)

  storeA.profile = .tactile
  storeA.volume = 42

  // Store B should be unaffected
  XCTAssertEqual(storeB.profile, .linear)
  XCTAssertEqual(storeB.volume, 100)
  ```

### Callback Mocking
- For callback-based tests, set up a flag:
  ```swift
  var callbackFired = false
  manager.onEnabledChanged = { enabled in
      callbackFired = true
  }
  XCTAssertNotNil(manager.onEnabledChanged)
  ```
- Tests verify wiring exists; full integration requires UI interaction

### AudioEngine Mock Limitations
- `AudioEngine` cannot be easily mocked in isolation (uses AVAudioEngine)
- Tests start a real AVAudioEngine — works in CI on macOS
- Some tests verify structure rather than runtime behavior when permissions are unavailable

## 7. Test Categories

### Unit Tests (in `KeyPulseTests.swift`)
- **AudioEngine**: init, start/stop, profile loading, playback, mute, volume, pitch randomization, latency measurement, concurrent playback
- **SoundAssets**: profile enums, URL resolution, file existence verification
- **KeyPulseController**: init, profile switching, volume/state management, random sample selection, error handlers, diagnostics, stats reset
- **SettingsStore**: defaults, persistence, clamping, reset, save/apply round-trip, ObservableObject compliance, launch-at-login
- **DiagnosticsData**: initialization, formatted output, Equatable verification (all 22 fields tested individually)
- **Preferences**: controller init/show/hide, settings round-trip, reset all settings

### Configuration Tests (`AudioEngineConfigurationTest`)
- Observer registration on start
- Engine functionality after observer setup
- Observer leak prevention on multiple starts
- Observer removal on stop
- Handling `AVAudioEngineConfigurationChange` notification gracefully

### Resilience Tests (`KeyboardMonitorResilienceTest`)
- Observer registration on start (structural verification)
- Idempotent stop/teardown
- Start/stop cycle resilience
- Tear-down idempotency

### UI Tests (`MenuBarManagerTests`)
- Initialization creates status item
- State sync (enabled, mute, profile, pitch variation, volume)
- Launch at login state updates
- Callback wiring (all 8 callbacks tested individually)
- Multiple manager instances with same controller
- Rapid state change robustness

### Performance Tests (14 files)
- See §5 "Performance Test Categories" above for complete list

### Integration Tests
- Settings store round-trip (save→stop→load→verify)
- Controller state propagation to diagnostics
- Profile change → diagnostics update chain
- Mute state → play return value chain

## 8. Coverage & Best Practices

### Test Coverage Philosophy
- All 13 MVP user stories have acceptance criteria verified by tests
- Latency acceptance criteria (US-003): `<20ms average` — verified by `testAudioEngineLatencyUnder20msTarget()`
- Equatable completeness: all 22 `DiagnosticsData` fields individually tested for inequality
- Edge cases tested: double start, zero volume, invalid index, rapid concurrent calls

### What's NOT Tested
- **Hardware-dependent**: CGEventTap creation (requires accessibility permission)
- **System services**: SMAppService registration (requires app signing)
- **UI interaction**: Menu bar clicks, SwiftUI view rendering
- **Audio output**: Actual sound playback through hardware (tested on CI runners)

### Test Stability
- Tests are designed to pass in CI (macOS runner) without accessibility permission
- Conditional test paths for permission-gated features:
  ```swift
  let started = controller.start()
  if started {
      // Verify monitoring
  }
  // Test continues regardless of permission state
  ```

### Justfile Commands
```makefile
# Run all tests
test:
    cd KeyPulse && swift test

# Build + test (pre-commit hook via prek)
swift-test:
    cd KeyPulse && swift test
```

### Pre-commit Hook
- `prek.toml` runs `swift build` + `swift test` on every commit
- Both must pass before commit is accepted
