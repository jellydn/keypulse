# KeyPulse Coding Conventions

## 1. Naming Conventions

### Types (PascalCase)
- **Classes, structs, enums, protocols**: PascalCase
  - `KeyPulseController`, `KeyboardMonitor`, `AudioEngine`
  - `DiagnosticsData`, `DebugWindowController`, `PreferencesWindowController`
  - `SoundProfile`, `SoundAssets`
- **Type aliases**: PascalCase (`KeyDownHandler`, `AudioEngineError`)

### Functions, Methods, Properties (camelCase)
- All methods and properties: camelCase
  - `loadProfile()`, `setupKeyboardHandler()`, `playRandomSample()`
  - `isRunning`, `currentProfile`, `samplesPerProfile`
- Boolean properties use `is`/`has` prefix:
  - `isRunning`, `isMuted`, `isEnabled`, `isPreWarmed`, `isMonitoring`
  - `isLastKeyModifier`, `isWindowVisible`, `isPitchVariationEnabled`
- Private stored properties use camelCase with underscore prefix for backing stores:
  - `cachedLaunchAtLoginStatus`, `lastStatusCacheTime`

### Enums
- Enum cases: camelCase (`linear`, `tactile`, `clicky`)
- Computed properties on enums for display: `displayName -> "Linear"`, `filenamePrefix -> "linear"`
- Conform to `CaseIterable`, `Identifiable` where needed

### Constants
- Static constants in nested `enum Keys` / `enum Defaults` / `enum Constants` pattern:
  - `Keys.profile`, `Defaults.volume`, `samplesPerProfile`
- Cases are camelCase within Keys/Defaults enums
- Module-level constants: `static let subsystem = "com.keypulse.app"`

### File/Directory Organization
```
Sources/KeyPulse/
  KeyPulse.swift               # @main entry point
  KeyPulseAppDelegate.swift     # App lifecycle wiring
  KeyPulseController.swift      # Central controller
  AudioEngine.swift             # Audio playback engine
  KeyboardMonitor.swift         # CGEventTap global hook
  MenuBarManager.swift          # NSStatusItem menu bar
  SettingsStore.swift           # UserDefaults persistence
  SoundAssets.swift             # Sound profile enum + asset manager
  DiagnosticsData.swift         # Diagnostics struct
  DebugWindowController.swift   # SwiftUI debug window
  PreferencesWindowController.swift # SwiftUI preferences
  Logging.swift                 # os.log Logger extensions
  Resources/                    # Sound WAV files
```

## 2. Swift Language Conventions

### Final Classes
- All classes are marked `final` unless subclassing is explicitly intended:
  - `final class SettingsStore`, `final class KeyPulseController`, `final class AudioEngine`
  - `final class KeyboardMonitor`, `final class MenuBarManager`

### Structs for Value Types
- `struct DiagnosticsData` — value semantics for Combine @Published
- Conforms to `Equatable` (all fields compared explicitly, see `DiagnosticsData+Equatable`)

### Enums for Namespacing
- `enum Keys` inside `SettingsStore` — UserDefaults key constants
- `enum Defaults` inside `SettingsStore` — default values
- `enum SoundAssets` — static namespace for asset management functions
- Nested error enums within class: `enum AudioEngineError: Error`

### ObservableObject Conformance
- Classes that publish observable state conform to `ObservableObject`:
  - `SettingsStore` (singleton via `@ObservedObject` in SwiftUI views)
  - `KeyPulseController` (via `@ObservedObject` in DebugView)
- Key properties use `@Published` for SwiftUI/Combine binding
  - `@Published private(set) var currentProfile`
  - `@Published var isEnabled`
  - `@Published var diagnosticsData`

### Access Control
- Explicit `private` for implementation details
- `internal` (default) for API surface
- `private(set)` for read-only public properties:
  - `private(set) var isRunning`, `private(set) var currentProfile`
  - `private(set) var isPreWarmed`, `private(set) var isMonitoring`
- `fileprivate` used sparingly (e.g., nested view sections)

### MARK Comments
- `// MARK: - Section Name` for organizing class internals:
  - `// MARK: - Lifecycle`, `// MARK: - Private Methods`
  - `// MARK: - Playback`, `// MARK: - Latency Measurement`
  - `// MARK: - Window Management`, `// MARK: - Setup`
  - `// MARK: - Permission Handling`, `// MARK: - Monitoring Control`
  - `// MARK: - View Sections`, `// MARK: - Actions`

### Defer for Cleanup
- `defer { }` pattern for cleanup in tests and methods
- `deinit` for releasing resources (engine stop, notification removal)

### Weak References
- `[weak self]` in closures to avoid retain cycles
- `weak var controller: KeyPulseController?` for delegates and observers
- Notification observers use `[weak self]` in the handler block

### Guard Statements
- `guard let` for optional unwrapping in early-return pattern
- `guard !isRunning else { return }` for idempotent start/stop guards

### Error Handling: throws + do/catch
- Methods that can fail `throw` concrete error types:
  - `func start() throws`
  - `func loadProfile(_ profile: SoundProfile) throws`
  - `func play(sampleIndex: Int) throws`
- `do { try ... } catch { ... }` pattern at call sites
- Error propagation through `onError` callback when UI is involved:
  ```swift
  controller.onError = { error in
      Logger.appDelegate.error("Error: \(error.localizedDescription)")
  }
  ```
- `XCTAssertNoThrow` / `XCTAssertThrowsError` in tests for error path verification

### Enum Error Types
- Concrete error enum nested in owning class:
  ```swift
  enum AudioEngineError: Error {
      case engineNotRunning
      case invalidSampleIndex
      case bufferLoadFailed
      case engineStartFailed
  }
  ```

## 3. Logging Patterns (os.log)

### Logger Extensions
- All logging via `os.log` `Logger` extensions defined in `Logging.swift`
- Single subsystem: `com.keypulse.app`
- Category-specific loggers per component:
  - `Logger.audioEngine` — `"AudioEngine"`
  - `Logger.keyboardMonitor` — `"KeyboardMonitor"`
  - `Logger.appDelegate` — `"AppDelegate"`
  - `Logger.settingsStore` — `"SettingsStore"`
  - `Logger.menuBarManager` — `"MenuBarManager"`
  - `Logger.soundAssets` — `"SoundAssets"`

### Log Levels
- `.debug` — verbose state changes, useful during development (e.g., "Enabled state changed to true")
- `.info` — lifecycle events (e.g., "Started monitoring keyboard events")
- `.error` — failures needing attention (e.g., "Failed to create event tap")
- `.warning` — resource issues (e.g., "Missing sample: ...")

### Log Message Format
- Descriptive strings without verbose parameter syntax
- Interpolate key values directly: `Logger.audioEngine.info("Engine restarted after configuration change")`
- Include error descriptions: `Logger.settingsStore.error("Failed to register: \(error.localizedDescription)")`

## 4. Concurrency Patterns

### No async/await
- The codebase uses **no Swift Concurrency** (`async/await`, `Task`, `actor`)
- All async work is via `DispatchQueue.main.async`
- Event tap callbacks dispatch to main queue: `DispatchQueue.main.async { [weak self] in ... }`

### Main Thread Assumption
- `CFRunLoopAddSource(CFRunLoopGetMain(), ...)` — event tap runs on main run loop
- `NotificationCenter.default.addObserver(... queue: .main ...)` — all observers fire on main queue
- UI updates (SwiftUI @ObservedObject) are implicitly on main thread
- `CGEvent.tapCreate` callback runs on the main run loop

### Thread Safety Notes
- `AudioEngine.nextPlayerIndex` uses round-robin without lock — comment documents this is safe because "All callers of play() arrive via DispatchQueue.main.async"
- `KeyboardMonitor.lastModifierFlags` accessed only from event tap callback (main run loop)
- `SettingsStore` backing `UserDefaults` is thread-safe by macOS framework contract

### No Locks Used
- **No `os_unfair_lock`, `NSLock`, or `DispatchSemaphore` in production code**
- The old implementation had a lock for player selection; current version uses round-robin on main queue
- Lock performance test (`LockPerformanceTest`) benchmarks `os_unfair_lock` but the production code no longer uses it

### Notification-Based Communication
- `NotificationCenter.default.addObserver(forName:object:queue:using:)` for cross-component events
  - `AVAudioEngineConfigurationChange` — audio route changes
  - `NSWorkspace.didWakeNotification` — system wake from sleep
  - `"keypulse_showDebugWindow"` — custom notification for cross-tab communication
- Observers stored as `NSObjectProtocol?` and removed in `deinit` or `stop()`

### System Sleep/Wake Resilience
- `KeyboardMonitor` registers `NSWorkspace.didWakeNotification` observer
- On wake: tears down and re-creates CGEventTap (taps are invalidated during sleep)
- `AudioEngine` registers `.AVAudioEngineConfigurationChange` observer
- On config change: restarts engine, clears format-specific caches, reloads profiles

## 5. Resource Management

### Bundle Resources
- Sound assets accessed via `Bundle.module.url(forResource:withExtension:)`
- Files in `Sources/KeyPulse/Resources/` directory with `.process` resource rule in `Package.swift`
- All WAV filenames must be globally unique across profiles (SwiftPM flattens resource dirs)
- Format: `{profile}_key_{nn}.wav` (e.g., `linear_key_01.wav`)

### Audio Lifecycle
- `AVAudioEngine` created in `init()`, started via `start()`
- `AVAudioPlayerNode` instances created during `start()`, detached in `stop()`
- Pre-loaded `AVAudioPCMBuffer` arrays per profile, cached for instant switching
- `profileCache: [SoundProfile: [AVAudioPCMBuffer]]` for pre-warmed profiles
- Format conversion via `AVAudioConverter` on first load, cached thereafter

### Deinit Cleanup
- Every class with resources implements `deinit`:
  - AudioEngine: `stop()` stops engine, detaches nodes
  - KeyboardMonitor: `stop()` removes event tap and wake observer
  - KeyPulseController: `stop()` on keyboardMonitor and audioEngine
  - DebugWindowController: `window?.delegate = nil`
  - PreferencesWindowController: `window?.delegate = nil`

### SettingsStore Quirks
- `UserDefaults.standard` for production, injectable for tests
- `object(forKey:)` check needed for Bool/Int to distinguish "unset" vs `0`/`false`
  ```swift
  if defaults.object(forKey: Keys.volume) == nil { return Defaults.volume }
  ```
- Schema versioning via `migrateIfNeeded()` for future migrations
- `SMAppService` as source of truth for launch-at-login status with TTL cache (5 seconds)
- Property setters call `objectWillChange.send()` explicitly for ObservableObject compliance

## 6. Architecture Patterns

### Controller Pattern
- `KeyPulseController` is the central coordinator owning `KeyboardMonitor` and `AudioEngine`
- App delegate creates controller, passes to views/managers
- Controller exposes methods as the API boundary

### Callback/Delegate Pattern
- Menu bar actions use callback properties:
  ```swift
  var onEnabledChanged: ((Bool) -> Void)?
  var onProfileChanged: ((SoundProfile) -> Void)?
  ```
- Error propagation via callback: `var onError: ((Error) -> Void)?`
- App delegate wires callbacks to settings persistence

### Singleton Pattern
- `SettingsStore.shared` — single source of truth for settings
- Also supports dependency injection via `init(defaults:)` for test isolation
- SwiftUI views bind to shared instance via `@ObservedObject`

### SwiftUI Bridging
- `NSHostingController` wraps SwiftUI views in AppKit windows
- `@ObservedObject` for reactive binding to `KeyPulseController` and `SettingsStore`
- Views pass `onSettingsChanged` callbacks to bridge back to AppKit controllers

### Throttling
- Diagnostics updates throttled at 20 Hz (50ms interval) to reduce main-thread overhead
- Throttle in `setupKeyboardHandler()` — only updates diagnostics if >=50ms since last publish
- Manual calls (settings changes, `diagnostics()`, `resetStats()`) bypass throttle

## 7. Testing Conventions (for reference)

See `TESTING.md` for full test conventions. Summary:
- `@testable import KeyPulse`
- `final class XxxTest: XCTestCase`
- Test methods: `func testXxx()`
- `defer { }` for cleanup in tests
- Performance tests: `CFAbsoluteTimeGetCurrent()` with `METRIC_` and `INFO:` print output
- `XCTAssertNoThrow`, `XCTAssertThrowsError` with specific error enum comparison
- `XCTestExpectation` for async patterns
