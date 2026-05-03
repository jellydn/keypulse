# KeyPulse

macOS menu bar app (LSUIElement) that plays mechanical keyboard sounds on keystroke. Swift 5.9+, macOS 13+, SwiftPM.

## Build & Test

All commands run from project root via `just`, or directly in `KeyPulse/`:

```
just build          # cd KeyPulse && swift build
just test           # cd KeyPulse && swift test
just run            # cd KeyPulse && swift run  (requires Accessibility permission)
just fmt            # swift-format format --in-place --recursive Sources/
```

Alternative: `xcodebuild -scheme KeyPulse` works from `KeyPulse/` too.

## Architecture

- **Entrypoint**: `KeyPulse/Sources/KeyPulse/KeyPulse.swift` (`@main` struct)
- **Wiring**: `KeyPulseAppDelegate` → `KeyPulseController` (owns `KeyboardMonitor` + `AudioEngine`)
- **Core types**: `AudioEngine` (8 round-robin `AVAudioPlayerNode`), `KeyboardMonitor` (CGEventTap), `MenuBarManager` (NSStatusItem), `SettingsStore` (singleton, UserDefaults), `SoundProfile` enum, `DiagnosticsData` (Equatable struct)
- **Sound assets**: `Resources/Sounds/` — files named `{profile}_key_{nn}.wav` (profiles: linear, tactile, clicky)

## Key Constraints (Hard-Earned)

- **SwiftPM flattens resource directories**. All 12 WAV filenames must be globally unique or SwiftPM errors on build (`linear_key_01.wav`, not `key_01.wav` in subdirs)
- **Resource access**: `Bundle.module.url(forResource:withExtension:)` — test resource bundle is `KeyPulse_KeyPulse.bundle`
- **Pitch randomization**: Uses `AVAudioPlayerNode.rate` (±5%), NOT `AVAudioUnitTimePitch`
- **Modifier keys**: `CGEventType.flagsChanged` events use sentinel key code `0xFF` — event mask must include both `.keyDown` and `.flagsChanged`
- **SettingsStore quirk**: `object(forKey:)` check needed for Bool/Int to distinguish "unset" from `0`/`false`; injectable `UserDefaults` for test isolation
- **Latency measurement**: `CACurrentMediaTime()` from QuartzCore; 100-sample history cap; `latencyReport()` for verification
- **Controller must be retained** as property on AppDelegate or it deallocates
- **SF Symbol icons**: Use `NSImage(systemSymbolName:accessibilityDescription:)` with `isTemplate = true` for menu bar icons; cache generated images per state
- **Muted icon compositing**: Composite `keyboard` + `nosign` (bottom-right overlay) using `NSImage(size:flipped:drawingHandler:)` — no SF Symbol `keyboard.slash` exists natively
- **Alternate menu pattern**: Right-click/option-click uses `statusItem?.button?.sendAction(on:)` with `[.leftMouseDown, .rightMouseDown]` and checks `NSApp.currentEvent?.modifierFlags.contains(.option)` in the handler to swap between main and compact alternate menus
- **Testable icon logic**: Use a static pure function (`iconSymbolName(enabled:muted:) -> String`) so unit tests can verify correct symbol without requiring NSApp context

## Debug Window

Shortcut: `Cmd+Opt+D`. Floating SwiftUI window (360x420, NSHostingController). Combine binding throttled to 10Hz.

## Preferences Window

Shortcut: `Cmd+,`. SwiftUI window (480x360, non-resizable, NSHostingController). TabView with General/Sounds/Advanced tabs. All controls bind to `SettingsStore` (ObservableObject) as single source of truth. Settings changes propagate to menu bar via `onSettingsChanged` → `menuBarManager.refresh()`.

## SettingsStore as ObservableObject

- `SettingsStore` conforms to `ObservableObject` for SwiftUI binding via `@ObservedObject`
- All setters call `objectWillChange.send()` before persisting to UserDefaults
- `@ObservedObject var settings: SettingsStore` used in PreferencesView, NOT `@StateObject` (singleton)
- Menu bar ↔ Preferences sync: menu bar changes call SettingsStore setters (which publish), Preferences window updates via `@ObservedObject`; Preferences changes call `onSettingsChanged` callback which invokes `menuBarManager.refresh()`

## Ralph Autonomous Development

`scripts/ralph/prd.json` defines user stories — **all 15 stories pass** (MVP complete). Active branch: `ralph/keypulse-mvp`. If adding new stories, update `passes: false` and follow commit format `feat: [Story ID] - [Title]`.

Pre-commit runs `swift build` + `swift test` via `prek` (prek.toml).

## Tests

19 test files in `KeyPulse/Tests/KeyPulseTests/`. Tests use `@testable import KeyPulse`. AudioEngine tests start an actual engine (works in CI on macOS). Some tests (accessibility, SMAppService) are conditional.
