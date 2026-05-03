# KeyPulse Codebase Structure

## Directory Layout

```
KeyPulse/                                    # SwiftPM package root
├── Package.swift                            # Swift 5.9, macOS 13+, no external deps
├── Info.plist                               # Bundle metadata, LSUIElement=true
├── KeyPulse.entitlements                    # Hardened runtime entitlements (minimal)
├── ExportOptions.plist                      # Notarization export options
│
├── Sources/
│   └── KeyPulse/                            # Main executable target
│       ├── KeyPulse.swift                   # @main entry point
│       ├── KeyPulseAppDelegate.swift        # NSApplicationDelegate lifecycle
│       ├── KeyPulseController.swift         # Central orchestrator (ObservableObject)
│       ├── KeyboardMonitor.swift            # CGEventTap keyboard listener
│       ├── AudioEngine.swift                # AVAudioEngine playback engine
│       ├── MenuBarManager.swift             # NSStatusItem menu bar UI
│       ├── SettingsStore.swift              # UserDefaults persistence + SMAppService
│       ├── DebugWindowController.swift      # Debug window (SwiftUI NSHostingController)
│       ├── PreferencesWindowController.swift# Preferences window (SwiftUI, 3 tabs)
│       ├── SoundAssets.swift                # SoundProfile enum + resource URL resolver
│       ├── DiagnosticsData.swift            # Diagnostics struct + Equatable
│       ├── Logging.swift                    # os.log Logger extensions (6 categories)
│       │
│       └── Resources/
│           └── Sounds/
│               ├── CREDITS.md               # Sound asset attribution
│               ├── linear/
│               │   ├── linear_key_01.wav
│               │   ├── linear_key_02.wav
│               │   ├── linear_key_03.wav
│               │   └── linear_key_04.wav
│               ├── tactile/
│               │   ├── tactile_key_01.wav
│               │   ├── tactile_key_02.wav
│               │   ├── tactile_key_03.wav
│               │   └── tactile_key_04.wav
│               └── clicky/
│                   ├── clicky_key_01.wav
│                   ├── clicky_key_02.wav
│                   ├── clicky_key_03.wav
│                   └── clicky_key_04.wav
│
└── Tests/
    └── KeyPulseTests/                       # XCTest target
        ├── KeyPulseTests.swift              # Main test class (~600 lines, all unit tests)
        ├── SettingsStoreIsolationTest.swift # Test isolation with injectable UserDefaults
        ├── AudioEngineConfigurationTest.swift
        ├── AudioLatencyPerformanceTest.swift
        ├── BufferConversionPerformanceTest.swift
        ├── DiagnosticsUpdatePerformanceTest.swift
        ├── EngineStartupPerformanceTest.swift
        ├── KeyboardDispatchPerformanceTest.swift
        ├── KeyboardMonitorResilienceTest.swift
        ├── KeyCodeLookupPerformanceTest.swift
        ├── KeystrokeDispatchLoadTest.swift
        ├── LockPerformanceTest.swift
        ├── MenuBarManagerTests.swift
        ├── PitchRandomizationPerformanceTest.swift
        ├── PrintOverheadPerformanceTest.swift
        ├── ProfileLoadPerformanceTest.swift
        ├── ProfileSwitchPerformanceTest.swift
        ├── SettingsStorePerformanceTest.swift
        └── SettingsStoreTestExecutionTest.swift
```

### Other Project Files

```
/Users/huynhdung/src/tries/2026-05-02-key-pulse/
├── README.md
├── AGENTS.md
├── CLAUDE.md
├── autoresearch.ideas.md
├── autoresearch.jsonl
├── progress.md
├── prek.toml
├── justfile                                  # Command runner recipes
├── LICENSE                                   # MIT
├── docs/                                     # Documentation artifacts
├── scripts/                                  # Build/CI scripts
├── tasks/                                    # Task definitions
└── .planning/
    └── codebase/
        ├── ARCHITECTURE.md                   # ← This document
        └── STRUCTURE.md                      # ← This document
```

---

## File Purposes

### Source Files (in execution order)

| File | Responsibility | Key Types | Lines (approx) |
|---|---|---|---|
| `KeyPulse.swift` | `@main` entry, bootstrap `NSApplication` + delegate | `struct KeyPulse` | ~10 |
| `KeyPulseAppDelegate.swift` | App lifecycle, window wiring, settings sync, notification observers | `class KeyPulseAppDelegate` | ~140 |
| `KeyPulseController.swift` | Central orchestrator: keyboard→audio pipeline, diagnostics, state | `class KeyPulseController` | ~270 |
| `KeyboardMonitor.swift` | CGEventTap lifecycle, permission handling, sleep/wake resilience | `class KeyboardMonitor` | ~260 |
| `AudioEngine.swift` | AVAudioEngine: start/stop, profile loading, playback, latency measurement | `class AudioEngine`, `enum AudioEngineError` | ~400 |
| `MenuBarManager.swift` | NSStatusItem, menu building, state sync, 11 callback closures | `class MenuBarManager` | ~280 |
| `SettingsStore.swift` | UserDefaults persistence, SMAppService, schema migration | `class SettingsStore` | ~280 |
| `DebugWindowController.swift` | Debug window (SwiftUI), live diagnostics display, test actions | `class DebugWindowController`, `struct DebugView`, `struct ModifierIndicator` | ~380 |
| `PreferencesWindowController.swift` | Preferences window (SwiftUI, 3 tabs), settings bindings | `class PreferencesWindowController`, `struct PreferencesView` | ~320 |
| `SoundAssets.swift` | SoundProfile enum, WAV URL resolution, sample validation | `enum SoundProfile`, `enum SoundAssets` | ~80 |
| `DiagnosticsData.swift` | Diagnostics struct, Equatable conformance, formatted report | `struct DiagnosticsData` | ~120 |
| `Logging.swift` | 6 os.log Logger extensions by subsystem category | `extension Logger` | ~40 |

### Test Files

| File | Focus | Key Techniques |
|---|---|---|
| `KeyPulseTests.swift` | All unit tests (~150 tests) | AudioEngine lifecycle, profile loading, mute/volume, diagnostics, SettingsStore round-trip, latency benchmarks |
| `SettingsStoreIsolationTest.swift` | Injectable UserDefaults for test isolation | Separate `UserDefaults(suiteName:)` per test, schema versioning, cross-contamination verification |
| Performance tests (16 files) | Latency, throughput, profiling benchmarks | `measure {}` blocks, XCTest metrics, repeat counts |

---

## Naming Conventions

### Swift Conventions

| Category | Convention | Examples |
|---|---|---|
| **Types** (classes, structs, enums) | `PascalCase` | `KeyPulseController`, `SoundProfile`, `AudioEngineError` |
| **Protocols** | `PascalCase` | `Identifiable`, `CaseIterable`, `ObservableObject` |
| **Methods / Functions** | `camelCase` | `start()`, `setProfile()`, `loadAndConvertBuffer(from:)` |
| **Properties** | `camelCase` | `isRunning`, `currentProfile`, `lastKeyCode` |
| **Private properties** | `camelCase`, no prefix | `private let engine`, `private var eventTap` |
| **Enum cases** | `lowerCamelCase` | `.linear`, `.tactile`, `.clicky` |
| **Static constants** | `camelCase` | `samplesPerProfile`, `currentSchemaVersion` |
| **Nested types** | `PascalCase` | `AudioEngineError`, `Keys`, `Defaults` |

### File Naming

| Pattern | Convention | Examples |
|---|---|---|
| **Main types** | One type per file, named after the type | `AudioEngine.swift`, `KeyboardMonitor.swift` |
| **UI controllers** | `{Name}Controller` or `{Name}Manager` | `DebugWindowController.swift`, `MenuBarManager.swift` |
| **App delegate** | `{AppName}AppDelegate` | `KeyPulseAppDelegate.swift` |
| **Entry point** | `{AppName}.swift` | `KeyPulse.swift` |
| **Data structs** | `{Name}Data` | `DiagnosticsData.swift` |
| **Resources** | `{Name}Assets` | `SoundAssets.swift` |
| **Logging** | `Logging.swift` (global extension) | `Logging.swift` |
| **Tests** | `{FileBeingTested}Tests` or `{Feature}Test` | `KeyPulseTests.swift`, `SettingsStoreIsolationTest.swift` |
| **Performance tests** | `{Feature}PerformanceTest` | `AudioLatencyPerformanceTest.swift` |
| **WAV samples** | `{profile}_key_{NN}.wav` | `linear_key_01.wav` |

### Bundle / UserDefaults Keys

| Pattern | Convention | Examples |
|---|---|---|
| **Bundle ID** | `com.{app}.app` | `com.keypulse.app` |
| **UserDefaults keys** | `keypulse_{keyName}` | `keypulse_volume`, `keypulse_launchAtLogin` |
| **Notification names** | `keypulse_{eventName}` | `keypulse_showDebugWindow` |
| **Logger subsystem** | Bundle ID | `com.keypulse.app` |
| **Logger categories** | PascalCase matching type | `AudioEngine`, `KeyboardMonitor`, `SettingsStore` |

---

## Where to Add New Code

### Adding a New Sound Profile

1. Create a new case in `SoundProfile` enum (`SoundAssets.swift`)
2. Add 4 WAV files named `{newProfile}_key_01.wav` through `_04.wav` to `Resources/Sounds/{newProfile}/`
3. Add the new profile to the profile-switching code in:
   - `MenuBarManager.buildMenu()` — profile submenu
   - `DebugWindowController` `DebugView` — `Picker` options
   - `PreferencesWindowController` `PreferencesView` — `Picker` options
   - `AudioEngine.preWarmAllProfiles()` — profiles array

### Adding a New Settings Property

1. Add a `UserDefaults` key constant in `SettingsStore.Keys`
2. Add a computed property with getter/setter following the existing pattern (with `objectWillChange.send()`)
3. Add default value in `SettingsStore.Defaults`
4. Wire to controller in `SettingsStore.saveFromController()` and `applyToController()`
5. Add corresponding property + logic in `KeyPulseController` (e.g., `setPitchRandomization()`)
6. Add menu item in `MenuBarManager` and wire callback
7. Add UI control in `PreferencesWindowController` (choose tab based on category)

### Adding a New Diagnostics Field

1. Add a property to `DiagnosticsData` struct
2. Add equality comparison in the `==` function
3. Update `KeyPulseController.updateDiagnosticsData()` to populate the new field
4. Add display section in `DebugView` (SwiftUI body)

### Adding a New Window Controller

1. Create a new `{Name}WindowController` class extending `NSObject, NSWindowDelegate`
2. Follow the pattern from `DebugWindowController` or `PreferencesWindowController`:
   - Weak reference to `KeyPulseController`
   - `setupWindow()` method creating `NSWindow` with `NSHostingController`
   - `showWindow()` / `hideWindow()` / `toggleWindow()` methods
   - `NSWindowDelegate.windowShouldClose()` to hide instead of close
3. Instantiate in `KeyPulseAppDelegate.setup*()` method
4. Wire menu bar callback in `setupMenuBar()` if needed

### Adding a New Test

- **Unit tests:** Add methods to `KeyPulseTests.swift` (single class, ~600 lines) or create a new file if the feature is substantial
- **Isolation tests:** Follow `SettingsStoreIsolationTest.swift` pattern with injectable dependencies
- **Performance tests:** Create a new `{Feature}PerformanceTest.swift` file using `XCTestCase.measure {}`

---

## Key Patterns

### Callback Wiring (Delegate-light)

The app uses **closure properties** instead of delegation or Combine publishers for menu events:

```swift
// MenuBarManager exposes callbacks:
var onEnabledChanged: ((Bool) -> Void)?
var onProfileChanged: ((SoundProfile) -> Void)?
// ...

// AppDelegate wires them:
menuBarManager?.onEnabledChanged = { [weak self] enabled in
    self?.settingsStore.isEnabled = enabled
}
```

### ObservableObject for UI Binding

`KeyPulseController` and `SettingsStore` both conform to `ObservableObject` and use `@Published` properties. SwiftUI views bind via `@ObservedObject`:

```swift
// DebugView receives controller:
struct DebugView: View {
    @ObservedObject var controller: KeyPulseController
    // Access: controller.diagnosticsData.totalKeystrokes
}

// PreferencesView receives settings:
struct PreferencesView: View {
    @ObservedObject var settings: SettingsStore
    // Access: settings.volume, settings.isMuted
}
```

### Singleton + Injection

`SettingsStore.shared` is the production singleton. Tests inject isolated `UserDefaults` suites:

```swift
let store = SettingsStore(defaults: UserDefaults(suiteName: "test.isolation.a")!)
```

### Resource Loading

Sound assets are loaded via `Bundle.module.url(forResource:withExtension:)` — the SwiftPM resource accessor generated by `Resources/` directory in `Package.swift`.

---

## Compilation / Build

```bash
# Build
cd KeyPulse && swift build

# Run
cd KeyPulse && swift run

# Test
cd KeyPulse && swift test

# Test with performance metrics
cd KeyPulse && swift test -c release
```

The app requires macOS 13+ and Accessibility permission (prompted on first launch). Build is configured for arm64 (Apple Silicon).
