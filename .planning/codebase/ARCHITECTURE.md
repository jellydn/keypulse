# KeyPulse Architecture

## Overview

KeyPulse is a macOS 13+ menu-bar application that plays mechanical keyboard sound effects in response to physical keystrokes. It uses `CGEventTap` for passive keyboard monitoring and `AVAudioEngine` for low-latency audio playback. The app follows a classic **AppDelegate + Controller** pattern (no SwiftUI `App` lifecycle), with **MVC-like separation** across five distinct layers.

---

## Architectural Pattern: AppDelegate + Controller (MVC-like)

The app deliberately avoids SwiftUI's `@main App` lifecycle in favor of `NSApplication` with a manual `NSApplicationDelegate`. This choice gives full control over:

- Menu bar lifecycle (`NSStatusItem`, no dock icon via `LSUIElement`)
- Accessibility permission prompts before monitoring starts
- Window controller management (debug, preferences)

| Layer | Role | Key Types |
|---|---|---|
| **Entry Point** | Bootstrap `@main` | `KeyPulse` (struct) |
| **App Delegate** | Lifecycle, window wiring, settings sync | `KeyPulseAppDelegate` |
| **Controller** | Orchestration, state, diagnostics | `KeyPulseController` |
| **Services** | Core capabilities | `KeyboardMonitor`, `AudioEngine`, `SettingsStore` |
| **UI** | Menu bar, windows | `MenuBarManager`, `DebugWindowController`, `PreferencesWindowController` |

```
┌─────────────────────────────────────────────┐
│  KeyPulse.swift (@main)                      │
│  └─ NSApplication.shared                     │
│     └─ delegate: KeyPulseAppDelegate         │
├─────────────────────────────────────────────┤
│  KeyPulseAppDelegate                         │
│  ├─ KeyPulseController (owns lifecycle)      │
│  ├─ MenuBarManager (menu bar + callbacks)    │
│  ├─ DebugWindowController (diagnostics)      │
│  ├─ PreferencesWindowController (settings)   │
│  └─ SettingsStore.shared (persistence)       │
├─────────────────────────────────────────────┤
│  KeyPulseController (ObservableObject)       │
│  ├─ KeyboardMonitor (CGEventTap)             │
│  └─ AudioEngine (AVAudioEngine)              │
├─────────────────────────────────────────────┤
│  Data / Model Layer                          │
│  ├─ SoundProfile (enum)                      │
│  ├─ SoundAssets (resource loader)            │
│  ├─ DiagnosticsData (struct)                 │
│  └─ Logger extensions (os_log)               │
└─────────────────────────────────────────────┘
```

---

## Data Flow: Key Event → Audio

The core data path is a **unidirectional pipeline** from hardware to speaker:

```
CGEventTap (kernel)
    │
    ▼
KeyboardMonitor.handleEvent()           ← CGEvent callback (any thread)
    │
    ▼  DispatchQueue.main.async { ... }
KeyboardMonitor.onKeyDown?(keyCode)     ← Main thread
    │
    ▼
KeyPulseController.setupKeyboardHandler()
    ├─ increment totalKeystrokes
    ├─ selectRandomSampleIndex()
    │
    ▼
AudioEngine.play(sampleIndex:)
    ├─ guard !isMuted
    ├─ guard isRunning
    ├─ select player node (round-robin)
    ├─ [optional] apply pitch randomization
    ├─ player.scheduleBuffer(at: nil, options: .interrupts)
    │    └─ No file I/O — pre-loaded PCM buffers
    └─ player.play()
```

### Latency Guarantee

The architecture guarantees **trigger-to-output latency < 20ms** through:

1. **Pre-loaded PCM buffers** — `AudioEngine.loadProfile()` reads all WAV files into `AVAudioPCMBuffer` arrays at load time. Playback (`scheduleBuffer`) issues no file I/O.
2. **`at: nil` scheduling** — The buffer is scheduled for immediate playback with `nil` timestamp (lowest possible latency).
3. **Round-robin player nodes** — 8 concurrent `AVAudioPlayerNode` instances prevent queue contention during fast typing.
4. **`.interrupts` option** — If a player node is currently playing, the new buffer interrupts it rather than waiting.
5. **Pre-warming** — `preWarmAllProfiles()` caches all three profiles so profile switching is instant (buffer copy, no file I/O).

```
Measurement: CACurrentMediaTime() at play() entry → CACurrentMediaTime() after scheduleBuffer
Stored in: AudioEngine.latencyMeasurements (rolling window of 100)
Displayed: Debug Window via DiagnosticsData.latencyAverageMs
```

---

## Key Abstractions

### 1. `AudioEngine` (final class)

**File:** `Sources/KeyPulse/AudioEngine.swift`

The low-latency audio playback engine.

- **Owns:** One `AVAudioEngine`, 8 `AVAudioPlayerNode` instances
- **Profile caching:** `profileCache: [SoundProfile: [AVAudioPCMBuffer]]` — pre-warms all three profiles for instant switching
- **Lifecycle:** `start()` → `loadProfile()` → `play(sampleIndex:)` → `stop()`
- **Format conversion:** `loadAndConvertBuffer(from:)` converts WAV files to the engine's `commonFormat` (main mixer format)
- **Configuration resilience:** Registers for `.AVAudioEngineConfigurationChange` to reload buffers when audio route changes (headphones, Bluetooth)
- **Latency measurement:** `recordLatencyMeasurement(triggerTime:)` captures scheduling latency
- **Pitch randomization:** `isPitchRandomizationEnabled` applies `rate = Float.random(in: 0.95...1.05)` per keystroke

**Error types:**
```swift
enum AudioEngineError: Error {
    case engineNotRunning
    case invalidSampleIndex
    case bufferLoadFailed
    case engineStartFailed
}
```

### 2. `KeyboardMonitor` (final class)

**File:** `Sources/KeyPulse/KeyboardMonitor.swift`

Global keyboard event monitor using `CGEventTap` in **listen-only mode** (does not intercept events).

- **Event mask:** `keyDown | flagsChanged` — captures both regular keystrokes and modifier-only presses
- **Threading:** Dispatches callbacks to `DispatchQueue.main.async` for thread-safe controller access
- **Accessibility:** Requires `AXIsProcessTrusted` permission; provides `checkAccessibilityPermission()`, `requestAccessibilityPermission()`, and `openAccessibilitySettings()`
- **Wake resilience:** Registers for `NSWorkspace.didWakeNotification` to re-create the event tap after system sleep
- **Modifier debouncing:** Tracks `lastModifierFlags` to avoid duplicate `flagsChanged` events (one per press, one per release)
- **Sentinel value:** Modifier-only presses use key code `0xFF` (outside normal 0-127 range)

**Design rationale:** CGEventTap was chosen over `IOHIDManager` for simpler key code/flag extraction and better system integration, at the cost of requiring Accessibility permission.

### 3. `KeyPulseController` (final class, `ObservableObject`)

**File:** `Sources/KeyPulse/KeyPulseController.swift`

The central orchestrator that wires keyboard events to audio playback.

- **Owns:** `KeyboardMonitor` and `AudioEngine`
- **Published state:** `isEnabled`, `currentProfile`, `diagnosticsData`
- **Error handling:** `onError: ((Error) -> Void)?` callback for runtime errors
- **Diagnostics throttling:** Limits `@Published` updates to ~20 Hz on the keystroke hot path
- **Public API:** `start/stop()`, `setProfile/setVolume/setMuted/setPitchRandomization()`, `testPlay/testAllProfiles()`, `resetStats()`, `diagnostics()`
- **Key code display:** `keyCodeDisplayName(_:)` maps 40+ common key codes to human-readable names

### 4. `MenuBarManager` (final class)

**File:** `Sources/KeyPulse/MenuBarManager.swift`

Manages the `NSStatusItem` menu bar icon and dropdown menu.

- **Icon:** Programmatic 18×18 template `NSImage` (key outline)
- **Menu items:** Enabled toggle, Profile submenu (3 profiles), Volume slider, Mute toggle, Pitch Variation toggle, Launch at Login toggle, Preferences, Debug Window, Quit
- **Callback pattern:** 11 `on*` closure properties for stateless communication with the app delegate
- **State sync:** `syncMenuState()` reads controller state and updates menu checkmarks/sliders

### 5. `SettingsStore` (final class, `ObservableObject`)

**File:** `Sources/KeyPulse/SettingsStore.swift`

Persistent settings storage via `UserDefaults` with `SMAppService` integration for launch-at-login.

- **Singleton:** `SettingsStore.shared` for production; injectable `UserDefaults` suite for test isolation
- **Schema migration:** `migrateIfNeeded()` with `currentSchemaVersion` for future-proofing
- **Keys:** 7 `UserDefaults` keys prefixed with `keypulse_`
- **SMAppService caching:** Launch-at-login status cached for 5 seconds to avoid expensive IPC on every read
- **Two-way sync:** `saveFromController(_:)` / `applyToController(_:)` for controller↔store round-trips

### 6. `SoundProfile` (enum) & `SoundAssets` (enum)

**File:** `Sources/KeyPulse/SoundAssets.swift`

- **`SoundProfile`:** 3 cases (`.linear`, `.tactile`, `.clicky`), conforms to `CaseIterable`, `Identifiable`
- **`SoundAssets`:** Static methods to resolve bundle URLs for `{profile}_key_{01-04}.wav` files
- **Validation:** `verifyAllSamplesExist(for:)` and `availableSampleCount(for:)` for integrity checks

### 7. `DiagnosticsData` (struct, `Equatable`)

**File:** `Sources/KeyPulse/DiagnosticsData.swift`

Value type for real-time diagnostics published by the controller.

- **22 fields** across 6 categories: keystroke stats, profile/sample, latency, modifier flags, settings, app info
- **Full Equatable conformance** — all 22 fields compared to ensure `@Published` detects every change
- **Formatting:** `formattedDiagnostics()` returns a multi-line report for clipboard copying

### 8. `Logger` Extensions

**File:** `Sources/KeyPulse/Logging.swift`

6 category-specific `os.log` loggers under subsystem `com.keypulse.app`:

| Logger | Category | Usage |
|---|---|---|
| `Logger.audioEngine` | `AudioEngine` | Start/stop, profile load, config changes |
| `Logger.keyboardMonitor` | `KeyboardMonitor` | Tap creation, permission, sleep/wake |
| `Logger.appDelegate` | `AppDelegate` | Lifecycle, settings sync, menu callbacks |
| `Logger.settingsStore` | `SettingsStore` | Persistence, migration, SMAppService |
| `Logger.menuBarManager` | `MenuBarManager` | Menu actions, profile errors |
| `Logger.soundAssets` | `SoundAssets` | Missing sample warnings |

---

## Entry Points

### Application Entry

```swift
// KeyPulse.swift
@main
struct KeyPulse {
    static func main() {
        let app = NSApplication.shared
        let delegate = KeyPulseAppDelegate()
        app.delegate = delegate
        app.run()
    }
}
```

The `@main` entry point creates an `NSApplication`, assigns the delegate, and calls `run()`. The `Info.plist` sets `LSUIElement=true` to suppress the dock icon.

### App Delegate Lifecycle

`applicationDidFinishLaunching(_:)` orchestrates setup in this order:
1. `setupController()` — initializes `KeyPulseController` with saved profile, starts keyboard monitoring
2. `applySettingsToController()` — restores volume, mute, enabled, pitch randomization from store
3. `setupMenuBar()` — creates `MenuBarManager` and wires all 11 callback closures for settings persistence
4. `setupDebugWindow()` — creates `DebugWindowController` (Cmd+Opt+D)
5. `setupPreferencesWindow()` — creates `PreferencesWindowController` (Cmd+,)
6. `registerNotificationObservers()` — listens for `keypulse_showDebugWindow` notification (Advanced tab button)

---

## Error Handling Strategy

| Layer | Strategy | Examples |
|---|---|---|
| **AudioEngine** | Throws `AudioEngineError` on failures | Engine start fails, buffer load fails, invalid sample index |
| **KeyPulseController** | Propagates errors via `onError` closure; caller-side handling | `AudioEngineError` forwarded; controller startup logs failure |
| **MenuBarManager** | Catches profile switch errors, reverts checkmarks, calls `controller.onError` | Failed `setProfile()` reverts UI state |
| **KeyboardMonitor** | Returns `Bool` from `start()`; logs failures with `Logger.keyboardMonitor` | Accessibility not granted, tap creation fails |
| **SettingsStore** | Logs `SMAppService` registration errors; invalidates cache on failure | Launch-at-login registration fails |
| **DebugWindowController** | `controller.onError` is the error sink; `testPlay()` returns `Bool` | Muted test play returns `false` |
| **AppDelegate** | Logs all errors via `Logger.appDelegate`; shows no user-facing alerts (menu bar app) | Controller init failure |

---

## Concurrency Model

- **CGEventTap callback** fires on an arbitrary system thread → `handleEvent()` runs on that thread
- **DispatchQueue.main.async** is used to bridge to the main thread for `onKeyDown` and `onFlagsChanged` callbacks
- **`AudioEngine.play()`** is called from `DispatchQueue.main.async` in `setupKeyboardHandler()`, so all audio scheduling runs on the main thread
- **No locks** — the round-robin `nextPlayerIndex` is only accessed from the main thread
- **`@Published` throttling** — `keyboardMonitor.onKeyDown` throttles `diagnosticsData` updates to 20 Hz max to avoid Combine pipeline overload

---

## Window Controllers

### DebugWindowController
- **File:** `Sources/KeyPulse/DebugWindowController.swift`
- **Type:** `NSWindowController` (manual, not NIB/storyboard)
- **Content:** SwiftUI `DebugView` (hosted in `NSHostingController`)
- **Binding:** `@ObservedObject var controller: KeyPulseController` — reactive diagnostics display
- **Key features:** Keystroke stats, latency metrics, modifier indicators, profile switcher, Test Sound/Test All actions, Copy Diagnostics, Reset Stats
- **Hotkey:** Cmd+Opt+D

### PreferencesWindowController
- **File:** `Sources/KeyPulse/PreferencesWindowController.swift`
- **Type:** `NSWindowController` (manual)
- **Content:** SwiftUI `PreferencesView` (3 tabs: General, Sounds, Advanced)
- **Binding:** `@ObservedObject var settings: SettingsStore` — settings are the single source of truth
- **Notifications:** Posts `"keypulse_showDebugWindow"` on Advanced tab button
- **Hotkey:** Cmd+,

---

## Package / Dependencies

**File:** `KeyPulse/Package.swift`

- Swift 5.9, macOS 13+
- **No external dependencies** — pure Apple frameworks:
  - `AVFoundation` (AVAudioEngine, AVAudioPlayerNode)
  - `CoreGraphics` (CGEventTap, CGEvent)
  - `AppKit` (NSStatusItem, NSMenu, NSWindow)
  - `Combine` (@Published, ObservableObject)
  - `ServiceManagement` (SMAppService for launch-at-login)
  - `Carbon` (linker flag for CGEventTap APIs)
- **Resources:** WAV files in `Resources/Sounds/{linear,tactile,clicky}/` (4 per profile = 12 total)
- Test target uses `@testable import KeyPulse`
