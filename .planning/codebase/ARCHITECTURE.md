# Architecture

**Analysis Date:** 2026-05-02

## Pattern Overview

**Overall:** Mediator/Controller-centric layered architecture

**Key Characteristics:**
- **Mediator pattern** via `KeyPulseController` — single coordinator that wires input (keyboard) to output (audio)
- **Observer/callback pattern** for keyboard events — `KeyboardMonitor.onKeyDown` closure, `MenuBarManager` callback closures
- **Singleton** for `SettingsStore.shared` — centralized UserDefaults persistence
- **No external dependencies** — pure Apple frameworks (AVFoundation, CoreGraphics, Carbon, AppKit, ServiceManagement)

## Layers

**App Lifecycle Layer:**
- Purpose: Bootstrap the app as an LSUIElement (menu bar only, no Dock icon) and manage lifecycle
- Location: `KeyPulse/Sources/KeyPulse/KeyPulse.swift`, `KeyPulse/Sources/KeyPulse/KeyPulseAppDelegate.swift`
- Contains: `@main` entry point, `NSApplicationDelegate` conformance
- Depends on: `KeyPulseController`, `MenuBarManager`, `SettingsStore`
- Used by: macOS runtime (app launch)

**Controller/Coordination Layer:**
- Purpose: Central mediator wiring keyboard input to audio output; owns all domain objects
- Location: `KeyPulse/Sources/KeyPulse/KeyPulseController.swift`
- Contains: `KeyPulseController` — orchestrates `KeyboardMonitor` + `AudioEngine`
- Depends on: `KeyboardMonitor`, `AudioEngine`, `SoundAssets`, `SoundProfile`
- Used by: `KeyPulseAppDelegate`, `MenuBarManager`

**Input Layer:**
- Purpose: Monitor global keyboard events via CGEventTap
- Location: `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`
- Contains: `KeyboardMonitor` — wraps CGEventTap with callback interface
- Depends on: CoreGraphics, Carbon, AppKit (for accessibility permission UX)
- Used by: `KeyPulseController`

**Output/Audio Layer:**
- Purpose: Low-latency audio playback with pre-loaded buffers and concurrent player nodes
- Location: `KeyPulse/Sources/KeyPulse/AudioEngine.swift`
- Contains: `AudioEngine` — AVAudioEngine with 8 concurrent AVAudioPlayerNodes
- Depends on: AVFoundation, `SoundAssets`, `SoundProfile`
- Used by: `KeyPulseController`

**UI Layer:**
- Purpose: Menu bar status item with profile picker, volume slider, toggles
- Location: `KeyPulse/Sources/KeyPulse/MenuBarManager.swift`
- Contains: `MenuBarManager` — builds NSMenu, handles user interactions
- Depends on: `KeyPulseController` (for state reads/writes), AppKit
- Used by: `KeyPulseAppDelegate`

**Persistence Layer:**
- Purpose: Load/save user preferences to UserDefaults; sync launch-at-login with SMAppService
- Location: `KeyPulse/Sources/KeyPulse/SettingsStore.swift`
- Contains: `SettingsStore` — singleton with typed accessors for all settings
- Depends on: `SoundProfile`, ServiceManagement
- Used by: `KeyPulseAppDelegate`

**Domain/Asset Layer:**
- Purpose: Define sound profiles and resolve WAV asset URLs from the bundle
- Location: `KeyPulse/Sources/KeyPulse/SoundAssets.swift`
- Contains: `SoundProfile` enum, `SoundAssets` utility
- Depends on: Foundation (Bundle.module)
- Used by: `AudioEngine`, `KeyPulseController`, `MenuBarManager`, `SettingsStore`

## Data Flow

**Keystroke → Sound (primary flow):**
1. User presses a key → macOS CGEvent fires
2. `CGEventTap` callback fires → `KeyboardMonitor.handleEvent()` extracts keyCode
3. `KeyboardMonitor` dispatches `onKeyDown?(keyCode)` on main thread via `DispatchQueue.main.async`
4. `KeyPulseController.setupKeyboardHandler()` closure receives keyCode, checks `isEnabled`
5. `KeyPulseController.playRandomSample()` selects a random index (0..<4)
6. `KeyPulseController` calls `AudioEngine.play(sampleIndex:)`
7. `AudioEngine` selects next player node via round-robin (thread-safe with `NSLock`)
8. If pitch randomization enabled → `player.rate = Float.random(in: 0.95...1.05)`
9. Buffer is scheduled on the player node → `player.scheduleBuffer()` + `player.play()`
10. Sound outputs through `AVAudioEngine`'s main mixer → hardware

**Settings Persistence (bidirectional):**
- **Save:** `MenuBarManager` callbacks → `SettingsStore` setters → UserDefaults + SMAppService
- **Load:** `KeyPulseAppDelegate.applicationDidFinishLaunching` → `SettingsStore.applyToController()` → `KeyPulseController`

**Profile Switching:**
1. User selects profile in menu → `MenuBarManager.profileSelected(_:)`
2. `controller.setProfile(profile)` → `AudioEngine.loadProfile(profile)`
3. `AudioEngine` loads 4 WAV files via `SoundAssets.sampleURLs(for:)` → converts to `AVAudioPCMBuffer`
4. Buffers atomically replace previous set

**State Management:**
- **Runtime state** held in `KeyPulseController` (profile, volume, mute, enabled, pitchRandomization)
- **Persistent state** stored in `SettingsStore` (UserDefaults) with `keypulse_` prefix
- **Launch-at-login** state uses `SMAppService.mainApp` as source of truth, with UserDefaults as cache
- **Menu state** synchronized via `MenuBarManager.syncMenuState()` called after changes

## Key Abstractions

**SoundProfile (enum):**
- Purpose: Represents the three keyboard sound profiles (`linear`, `tactile`, `clicky`)
- Examples: `KeyPulse/Sources/KeyPulse/SoundAssets.swift`
- Pattern: `String`-backed `CaseIterable` + `Identifiable` enum with `displayName` and `filenamePrefix` computed properties

**AudioEngine (class):**
- Purpose: Manages AVAudioEngine lifecycle, concurrent playback, buffer pre-loading, and audio settings
- Examples: `KeyPulse/Sources/KeyPulse/AudioEngine.swift`
- Pattern: Object pool of 8 `AVAudioPlayerNode` instances with round-robin selection and `NSLock` thread safety; pre-loaded `AVAudioPCMBuffer` array for zero-I/O playback

**KeyboardMonitor (class):**
- Purpose: Global keystroke detection via CGEventTap
- Examples: `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`
- Pattern: Observer with `onKeyDown` callback closure; `Unmanaged<Self>` passed as `refcon` to C-style CGEventTap callback; `kCGEventTapOptionListenOnly` to pass events through without modification

**SettingsStore (singleton):**
- Purpose: Typed UserDefaults access with defaults, clamping, and SMAppService sync
- Examples: `KeyPulse/Sources/KeyPulse/SettingsStore.swift`
- Pattern: Singleton (`static let shared`); private `Keys` and `Defaults` enums; nil-check on `UserDefaults.object(forKey:)` to distinguish "not set" from "set to false/0"

**MenuBarManager (class):**
- Purpose: NSStatusItem with NSMenu, programmatic template icon, and callback-driven actions
- Examples: `KeyPulse/Sources/KeyPulse/MenuBarManager.swift`
- Pattern: Callback closures (`onEnabledChanged`, `onProfileChanged`, etc.) set by `KeyPulseAppDelegate`; `weak` reference to controller to avoid retain cycles

## Entry Points

**App launch (`KeyPulse.main`):**
- Location: `KeyPulse/Sources/KeyPulse/KeyPulse.swift`
- Triggers: macOS launches the app (menu bar agent, login item, or user double-click)
- Responsibilities: Creates `NSApplication.shared`, sets `KeyPulseAppDelegate` as delegate, calls `app.run()`

**App lifecycle (`applicationDidFinishLaunching`):**
- Location: `KeyPulse/Sources/KeyPulse/KeyPulseAppDelegate.swift`
- Triggers: macOS `NSApplicationDelegate` callback
- Responsibilities: Calls `setupController()` (creates `KeyPulseController`, starts keyboard monitoring, handles accessibility permission), `applySettingsToController()` (loads saved settings), `setupMenuBar()` (creates `MenuBarManager`, wires all callbacks)

**App termination (`applicationWillTerminate`):**
- Location: `KeyPulse/Sources/KeyPulse/KeyPulseAppDelegate.swift`
- Responsibilities: Calls `saveSettings()` to persist controller state

**Build/Release pipeline:**
- Location: `scripts/build-release.sh`
- Triggers: Developer runs `./scripts/build-release.sh [version] [build_number]`
- Responsibilities: Validates prerequisites, builds via Xcode or SwiftPM, creates xcarchive, exports for App Store

## Error Handling

**Strategy:** Throw-and-propagate with optional error handler callback

**Patterns:**
- `AudioEngine.AudioEngineError` enum — `.engineNotRunning`, `.invalidSampleIndex`, `.bufferLoadFailed`, `.engineStartFailed`
- `KeyPulseController` init throws — propagates `AudioEngine` errors on start or profile load
- `KeyPulseController.onError` optional closure — set by app delegate to log runtime errors
- Playback errors caught in `playRandomSample()` and forwarded to `onError`
- `KeyboardMonitor.start()` returns `Bool` — returns `false` if accessibility permission missing (not a throw)
- `SettingsStore` silently falls back to defaults — no error surface; `SMAppService.register()`/`.unregister()` errors printed to console

## Cross-Cutting Concerns

**Logging:** Bare `print()` statements throughout — no structured logging framework. All messages prefixed with `"KeyPulse:"` or `"KeyboardMonitor:"`.

**Validation:**
- Volume clamped to 0–100 in `SettingsStore` and 0.0–1.0 in `AudioEngine`
- Sample indices validated before playback (`0..<buffers.count`)
- Sound asset URLs validated by `SoundAssets.verifyAllSamplesExist(for:)`

**Authentication/Permissions:**
- Accessibility permission required at runtime (`AXIsProcessTrustedWithOptions`)
- `NSAccessibilityUsageDescription` in `Info.plist` explains purpose to user
- `KeyboardMonitor.openAccessibilitySettings()` opens System Settings
- No login, no accounts, no network — completely offline app

**Thread Safety:**
- `AudioEngine.play()` uses `NSLock` (`playerLock`) for round-robin player node selection
- `KeyboardMonitor` dispatches `onKeyDown` callback to main thread via `DispatchQueue.main.async`
- `AVAudioEngine` operations assumed on main thread (no explicit concurrency protection on `loadProfile`/`start`/`stop`)

---

*Architecture analysis: 2026-05-02*
