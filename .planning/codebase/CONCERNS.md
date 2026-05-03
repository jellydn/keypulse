# KeyPulse Codebase Concerns

> Analyzed: 2026-05-03
> Scope: All 12 Swift source files, 19 test files, Package.swift, entitlements, plist, docs
> Source lines: 2,925 Swift (sources) + 2,752 Swift (tests)

---

## Table of Contents

1. [Technical Debt](#1-technical-debt)
2. [Known Bugs & Code Quality](#2-known-bugs--code-quality)
3. [Security Considerations](#3-security-considerations)
4. [Performance Bottlenecks](#4-performance-bottlenecks)
5. [Fragile Areas](#5-fragile-areas)
6. [Dependencies at Risk](#6-dependencies-at-risk)
7. [Missing Critical Features](#7-missing-critical-features)
8. [Test Coverage Gaps](#8-test-coverage-gaps)
9. [Documentation Gaps](#9-documentation-gaps)
10. [Architecture Risks](#10-architecture-risks)

---

## 1. Technical Debt

### 1.1 Unused Carbon Framework Linkage
**File:** `KeyPulse/Package.swift` (line 15)
**Risk:** Low
**Detail:** `Carbon` is still listed in `linkerSettings.linkedFramework` even though all `import Carbon` statements were removed from source files. This adds an unnecessary link-time dependency and could cause confusion about framework usage.
**Action:** Remove `.linkedFramework("Carbon")` from Package.swift.

### 1.2 SettingsStore.resetToDefaults() Doesn't Clear Launch-at-Login Cache
**File:** `KeyPulse/Sources/KeyPulse/SettingsStore.swift` (lines 228-235)
**Risk:** Low
**Detail:** `resetToDefaults()` resets `profile`, `volume`, `isMuted`, `isEnabled`, and `pitchRandomization` but does NOT invalidate `cachedLaunchAtLoginStatus` or `lastStatusCacheTime`. After reset, the stale cached SMAppService status persists for up to 5 seconds, so `launchAtLogin` may return the old cached value instead of re-querying the system.
**Action:** Add `cachedLaunchAtLoginStatus = nil; lastStatusCacheTime = nil` to `resetToDefaults()`.

### 1.3 Hardcoded App Metadata in DiagnosticsData
**File:** `KeyPulse/Sources/KeyPulse/DiagnosticsData.swift` (lines 39-41)
**Risk:** Low
**Detail:** `bundleIdentifier`, `appVersion`, and `buildNumber` are hardcoded strings (`"com.keypulse.app"`, `"0.1.0"`, `"1"`) instead of being read dynamically from `Bundle.main.infoDictionary`. These will go out of sync when the version is bumped.
**Action:** Read from `Bundle.main` via `CFBundleIdentifier`, `CFBundleShortVersionString`, and `CFBundleVersion`.

### 1.4 PreferencesWindowController Recreates SwiftUI View on Every Show
**File:** `KeyPulse/Sources/KeyPulse/PreferencesWindowController.swift` (lines 92-101)
**Risk:** Medium
**Detail:** `showWindow()` creates a brand new `PreferencesView` and replaces `hostingController.rootView` every time the window is shown. This discards any ephemeral SwiftUI state (e.g., open disclosure groups, scroll position, alert dismissal state). A better approach is to create the view once in `setupWindow()` and update bindings via `@ObservedObject`.
**Action:** Move view creation to `setupWindow()` and let the `@ObservedObject` property on `SettingsStore` handle reactivity.

### 1.5 No Type-Safe Notification Names
**File:** `KeyPulse/Sources/KeyPulse/PreferencesWindowController.swift` (lines 299-303), `KeyPulse/Sources/KeyPulse/KeyPulseAppDelegate.swift` (lines 117)
**Risk:** Low
**Detail:** The notification name `"keypulse_showDebugWindow"` is a string literal used in two files. Any typo creates a silent breakage. No compile-time checking exists.
**Action:** Define as a static extension on `NSNotification.Name` (e.g., `extension NSNotification.Name { static let showDebugWindow = NSNotification.Name("keypulse_showDebugWindow") }`).

### 1.6 No Keyboard Layout Awareness
**File:** `KeyPulse/Sources/KeyPulse/KeyPulseController.swift` (lines 206-258)
**Risk:** Medium
**Detail:** `keyCodeDisplayName()` uses a hardcoded US ANSI keycode mapping. Users with ISO keyboards, AZERTY, QWERTZ, Dvorak, or other non-US layouts will see incorrect key names in the debug window. The key codes themselves (interpreted by CGEvent) are correct, but the display names mislead.
**Action:** Use `NSEvent.keyBindingDictionary` or `TISCopyCurrentKeyboardLayoutInputSource` for dynamic layout-aware key naming.

### 1.7 No Performance Baseline Persistence
**Risk:** Medium
**Detail:** Performance tests (`AudioLatencyPerformanceTest`, `BufferConversionPerformanceTest`, etc.) have regression guards with arbitrary thresholds (e.g., `< 50ms`). There is no stored baseline file that records "normal" values for the current hardware. Thresholds degrade silently as the codebase evolves.
**Action:** Add a baseline file (e.g., `.baselines.json`) that stores expected metric values and is checked during CI.

### 1.8 SettingsStore Schema Migration Stub
**File:** `KeyPulse/Sources/KeyPulse/SettingsStore.swift` (lines 241-258)
**Risk:** Low
**Detail:** The `migrateIfNeeded()` method exists and correctly handles versioning, but there's no actual migration test. Only `currentSchemaVersion = 1` exists. The infrastructure is untested beyond basic stamp-and-read scenarios.
**Action:** Add a test that simulates upgrading from version 0 to version 1 with known data.

---

## 2. Known Bugs & Code Quality

### 2.1 Missing Debug Window Screenshot in README
**File:** `README.md` (line ~80)
**Risk:** Low
**Detail:** README references `docs/debug-window-screenshot.png` via `![Debug Window](docs/debug-window-screenshot.png)`, but this file does not exist in `docs/`. Renders as a broken image on GitHub.
**Action:** Add the screenshot or remove the reference.

### 2.2 MenuBarManager.toggleLaunchAtLogin Optimistic State Flicker
**File:** `KeyPulse/Sources/KeyPulse/MenuBarManager.swift` (lines 300-306)
**Risk:** Medium
**Detail:** `toggleLaunchAtLogin()` toggles the menu item check state optimistically BEFORE the SMAppService registration attempt completes. If the SMAppService call fails (e.g., due to signing, entitlements, or macOS restrictions), the check state briefly toggles on then reverts when the callback fires, creating a visual flicker.
**Action:** Pass the pending state to the callback and let the callback confirm success before updating the menu item state. Alternatively, set state optimistically but handle the error path.

### 2.3 AudioEngine Config Change Test Possibly Ineffective
**File:** `KeyPulse/Tests/KeyPulseTests/AudioEngineConfigurationTest.swift` (lines 81-102)
**Risk:** Medium
**Detail:** The test posts `AVAudioEngineConfigurationChange` with `object: nil`, but the real observer in `AudioEngine.swift` (line 131) is registered with `object: engine`. NotificationCenter's `object` filter means `nil`-object notifications are delivered to ALL observers, so this test DOES work, but it also means the notification would fire for ANY engine's config change, not just this one. The test relies on implicit behavior and doesn't verify `object` filtering.
**Action:** Add explicit assertion that the observer is registered with `object: engine` to confirm test accuracy.

### 2.4 Audio Engine Stop During Config Change May Cause Double-Free
**File:** `KeyPulse/Sources/KeyPulse/AudioEngine.swift` (lines 115-146)
**Risk:** High
**Detail:** The `AVAudioEngineConfigurationChange` handler calls `self.engine.stop()` on the main queue while the engine is in an unstable state (configuration just changed). If the engine is already in the process of stopping from another call site, this could cause undefined behavior. The `isRunning` flag is only set to `false` after `do-catch` completes, creating a race window.
**Action:** Add a re-entrancy guard (e.g., `guard !isRestarting else { return }`) and set a `isRestarting` flag before `engine.stop()`.

### 2.5 No Error Recovery for CGEventTap Creation Failure After Wake
**File:** `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (lines 155-173)
**Risk:** High
**Detail:** The `NSWorkspace.didWakeNotification` handler attempts to re-create the tap once. If `createEventTap()` returns `false`, it sets `isMonitoring = false` permanently until the user manually toggles monitoring off and back on. There is no retry mechanism.
**Action:** Add exponential backoff retry (e.g., 3 attempts with 1s, 2s, 4s delays) before marking `isMonitoring = false`.

### 2.6 Window Level Conflict for Debug Window
**File:** `KeyPulse/Sources/KeyPulse/DebugWindowController.swift` (line 63)
**Risk:** Low
**Detail:** Debug window is set to `.floating` level, which may interfere with other floating windows (e.g., Preferences window). Both windows floating concurrently could cause z-order confusion.
**Action:** Consider `.normal` level for the debug window, or manage window ordering explicitly.

### 2.7 `selectRandomSampleIndex()` Pure Random (No Rotation)
**File:** `KeyPulse/Sources/KeyPulse/KeyPulseController.swift` (lines 362-365)
**Risk:** Low
**Detail:** The comment says "Future iterations could implement rotation logic to avoid playing the same sample twice in a row," but this remains unimplemented. Pure random selection means ~25% chance of repeating the same sample on consecutive keystrokes.
**Action:** Implement basic "avoid last index" logic or shuffle-based rotation for more natural sound variety.

---

## 3. Security Considerations

### 3.1 Full Keystroke Capture — No Privacy Filter
**File:** `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (lines 214-269)
**Risk:** HIGH
**Detail:** The CGEventTap captures ALL key-down events system-wide, including passwords, credit card numbers, private messages, and other sensitive input. The current implementation processes every keystroke with no ability to:
- Exclude specific apps (e.g., password managers, banking apps)
- Pause during secure text entry (Secure Text Input fields)
- Respect the currently focused app's privacy requirements

While the app is legitimate and data is only used for audio playback, any future compromise could expose all keyboard input. The `NSAccessibilityUsageDescription` in Info.plist explains the need, but the privacy boundary is coarse.

**Recommendations:**
- Add an "Allowlist" or "Blocklist" of apps per-keystroke
- Detect `kCGSessionSecureInputFlag` or `CGEventSourceFlagsState` indicating secure input
- Document the privacy boundary in the UI (show which apps are being monitored)
- Consider on-device processing guarantees (no network I/O)

### 3.2 No Data Sanitization in Diagnostics
**File:** `KeyPulse/Sources/KeyPulse/DiagnosticsData.swift` (line 10), `KeyPulse/Sources/KeyPulse/KeyPulseController.swift` (line 206)
**Risk:** Medium
**Detail:** `lastKeyCode` and `lastKeyDisplayName` are logged and displayed in the debug window. While key codes don't directly leak the character typed, the display name for printable keys (e.g., "A") does. The "Copy Diags" feature copies this data to the pasteboard.
**Action:** Sanitize or mask last key data when the debug window is not visible. Add a privacy notice for the copy-diagnostics feature.

### 3.3 Debug Window Shows Live Keystroke Data Without Authentication
**File:** `KeyPulse/Sources/KeyPulse/DebugWindowController.swift`
**Risk:** Medium
**Detail:** The debug window (accessible via Cmd+Opt+D) shows live keystroke data (last key pressed, total count, latency, etc.). Any person with physical access to the machine can open the debug window and see keystroke information without authentication.
**Action:** Add a simple dismissal timer for the debug window (auto-hide after N minutes). Not a high priority for a developer tool, but worth noting.

### 3.4 SMAppService Status IPC Is EXPENSIVE
**File:** `KeyPulse/Sources/KeyPulse/SettingsStore.swift` (lines 122-143)
**Risk:** Low (Performance)
**Detail:** The 5-second cache for `launchAtLogin` status exists because every call to `SMAppService.mainApp.status` triggers an expensive XPC call to `launchd`. The cache is already implemented, but the initial `migrateIfNeeded()` call reads `launchAtLogin` during init (via `defaults.integer(forKey:)`), which doesn't trigger the IPC path since the cache is only for the `launchAtLogin` getter.
**Action:** None needed — already well-handled. Documented for awareness.

---

## 4. Performance Bottlenecks

### 4.1 AVAudioConverter Recreated Per Buffer Load
**File:** `KeyPulse/Sources/KeyPulse/AudioEngine.swift` (lines 248-289)
**Risk:** Low
**Detail:** `loadAndBufferConvert()` creates a new `AVAudioConverter` instance for every buffer, even when the source format matches the target format (the function has an early return for matching formats, but the converter is only created inside the conversion branch). This is fine for the current 12-buffer load, but if the sample library grows to hundreds of sounds, converter creation overhead becomes significant.
**Action:** Cache converters per source format, or pre-convert all assets at build time.

### 4.2 10ms Audio Latency Spikes (AVAudioEngine Scheduling)
**File:** `KeyPulse/Sources/KeyPulse/AudioEngine.swift`
**Risk:** Low (acknowledged)
**Detail:** As noted in autoresearch findings, occasional 10ms latency spikes come from AVAudioEngine thread scheduling, not Swift code. The average is 0.43ms (well under 20ms target). Micro-optimizations showed no improvement. This is a platform limitation, not code debt.
**Action:** No action possible — this is an AVAudioEngine characteristic. Document in deployment notes.

### 4.3 Main Thread Bottleneck for ALL Playback
**File:** `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (lines 234-238)
**Risk:** Medium
**Detail:** All keystroke→audio dispatch goes through `DispatchQueue.main.async`. If the main thread is blocked (e.g., during heavy animation, sheet presentation, or run loop processing), keystrokes are queued and delayed, increasing effective latency. The autoresearch baseline shows 40µs overhead for this dispatch, but the queue depth can grow under main thread contention.
**Action:** Consider a dedicated serial queue for the audio dispatch path, or use `perform(_:with:afterDelay:0, modes: [.common])` for higher priority schedule.

### 4.4 PreferencesWindow Full View Reconstruction
**File:** `KeyPulse/Sources/KeyPulse/PreferencesWindowController.swift` (lines 92-101)
**Risk:** Medium
**Detail:** As noted in tech debt (1.4), `showWindow()` recreates the entire SwiftUI view hierarchy. For a preferences window shown once per session, this is acceptable. But if the window is shown/hidden frequently, view reconstruction adds ~5-10ms of work and discards state.
**Action:** Implement view caching as described in 1.4.

---

## 5. Fragile Areas

### 5.1 AudioEngine Lifecycle — Config Change Handler Does Heavy Work on Main Queue
**File:** `KeyPulse/Sources/KeyPulse/AudioEngine.swift` (lines 115-146)
**Risk:** HIGH
**Detail:** The `AVAudioEngineConfigurationChange` notification handler runs on `.main` and performs: engine stop, cache clearing, engine restart, profile reloading, and full pre-warming of all profiles. During this ~30-50ms window, the app's main thread is blocked and no keystrokes are processed. If the configuration changes rapidly (e.g., Bluetooth headphone pairing/unpairing events), this could stack.
**Action:** Offload cache clearing and pre-warming to a background queue. Only the engine stop/start needs the main thread.

### 5.2 CGEventTap Assumes Main Run Loop
**File:** `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (lines 80-82)
**Risk:** Medium
**Detail:** The event tap run loop source is added to `CFRunLoopGetMain()` with `.commonModes`. If the app enters a tracking mode (e.g., menu tracking, window resize) that doesn't use `.commonModes`, events may not be delivered. `.commonModes` normally includes both default and event tracking modes, but custom run loop modes would exclude it.
**Action:** Document this assumption. Consider adding a background thread with its own run loop for event delivery if modal tracking becomes an issue.

### 5.3 0xFF Sentinel Key Code Overlaps Possible Real Key
**File:** `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (line 259-261)
**Risk:** Medium
**Detail:** The modifier key sentinel value `0xFF (255)` is outside the standard key code range (0-127 for most keyboards, though extended keyboards can use up to 0x7F). However, macOS HID key codes can theoretically go up to 255 (0xFF). If a future keyboard or HID device produces key code 255, it would be misidentified as a modifier event.
**Action:** Use a separate boolean flag (`isModifierEvent`) instead of a sentinel key code, or use a higher unreachable value like `0xFFFF`.

### 5.4 AudioEngine.play() Relies on buffers Array Being Populated
**File:** `KeyPulse/Sources/KeyPulse/AudioEngine.swift` (lines 325-360)
**Risk:** Medium
**Detail:** `play(sampleIndex:)` checks `sampleIndex < buffers.count` but doesn't validate that `buffers` is non-empty. If `loadProfile` was never called (buffers is empty), the guard `sampleIndex < buffers.count` correctly rejects all indices since `0 < 0` is false. However, if `loadProfile` partially fails and `buffers` is in an inconsistent state, the guard may pass but `buffers[sampleIndex]` could access stale data.
**Action:** Add an explicit `guard !buffers.isEmpty else { throw AudioEngineError.bufferLoadFailed }` check.

### 5.5 Weak Controller Reference in DebugWindowController.setupWindow()
**File:** `KeyPulse/Sources/KeyPulse/DebugWindowController.swift` (lines 11, 42)
**Risk:** LOW
**Detail:** `setupWindow()` is called from `init()`, which uses `guard let controller = controller else { return }`. The `controller` property is `weak`. If the controller is deallocated between init and setupWindow (unlikely since init takes controller as parameter), the window never appears. Currently safe because callers hold a strong reference, but fragile to refactoring.
**Action:** Make init take a strong reference and store as strong. Keep weak only if needed to break cycles.

### 5.6 KeyboardMonitor Callback Refcon Raw Pointer Safety
**File:** `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (lines 71-80)
**Risk:** Medium
**Detail:** The `CGEventTap` callback takes a raw `Unmanaged` refcon pointer. While the current code correctly uses `Unmanaged.passUnretained(self).toOpaque()` and `fromOpaque(...).takeUnretainedValue()`, any future refactoring that changes the memory layout or adds another level of indirection could cause a use-after-free. The callback fires on the event tap thread, not the main thread, so there's a threading concern if `self` is deallocated concurrently.
**Action:** Consider using a trampoline object that's strongly retained while the tap is active. The current code with `takeUnretainedValue()` assumes `self` outlives the tap, which is guaranteed by `deinit { stop() }`, but fragile.

---

## 6. Dependencies at Risk

### 6.1 External Dependencies
**Risk:** None
**Detail:** KeyPulse has zero external dependencies. All dependencies are Apple system frameworks:
- `AVFoundation` (AVAudioEngine, AVAudioPlayerNode, AVAudioFile, AVAudioPCMBuffer, AVAudioConverter)
- `CoreGraphics` (CGEventTap, CGEvent, CGEventFlags)
- `AppKit` (NSStatusItem, NSMenu, NSMenuItem, NSApplication, NSWindow)
- `SwiftUI` (Views, @Published, @ObservedObject, ObservableObject)
- `Combine` (objectWillChange, @Published)
- `ServiceManagement` (SMAppService for launch at login)
- `QuartzCore` (CACurrentMediaTime for latency measurement)

### 6.2 Carbon Framework (Unused)
**File:** `KeyPulse/Package.swift` (line 15)
**Risk:** Low
**Detail:** Carbon is linked but no code imports it. Already documented in tech debt (1.1). Removing it has no functional impact.

### 6.3 SMAppService API Availability
**Risk:** Medium
**Detail:** `SMAppService` (introduced in macOS 13) is used for launch-at-login. The deployment target is macOS 13+, so this is safe. However, `SMAppService` behavior differs between sandboxed and non-sandboxed builds (TestFlight vs. App Store). The TestFlight build guide (TESTFLIGHT.md) explicitly notes this limitation.
**Action:** Verify launch-at-login works correctly in App Store builds vs. development builds.

---

## 7. Missing Critical Features

### 7.1 Per-App Profile Configuration
**Status:** Planned
**Detail:** Users cannot configure different sound profiles for different applications. A developer might want Clicky for Xcode but Linear for Safari.
**Risk:** Medium for user experience.

### 7.2 Custom Sound Pack Support
**Status:** Planned
**Detail:** Users cannot import their own WAV files. All 12 samples are bundled at build time.
**Risk:** Medium for user experience.

### 7.3 App Exclusion (Privacy)
**Status:** Not implemented
**Detail:** No way to exclude specific apps from keystroke monitoring (password managers, banking apps, etc.).
**Risk:** High for privacy/security (see 3.1).

### 7.4 Pause During Secure Input
**Status:** Not implemented
**Detail:** When a secure text input field is active (e.g., password field), the system sets a flag that CGEventTap-delivered events can include. Currently, KeyPulse plays sounds even during password entry.
**Risk:** Medium for privacy.

### 7.5 Keyboard Layout Detection
**Status:** Not implemented
**Detail:** Debug window shows incorrect key names for non-US keyboard layouts.
**Risk:** Low (cosmetic, US MBP keyboard is most common).

### 7.6 Analytics/Telemetry Opt-Out
**Status:** Not implemented (no analytics present)
**Detail:** No analytics are collected, which is good. But there's no documented privacy policy or telemetry disclosure.
**Risk:** Low.

### 7.7 Auto-Update Mechanism
**Status:** Not implemented
**Detail:** No Sparkle integration or other auto-update mechanism. Users must manually rebuild or download from TestFlight.
**Risk:** Medium for distribution.

---

## 8. Test Coverage Gaps

### 8.1 KeyboardMonitor — Near-Zero Coverage
**Risk:** HIGH
**Detail:** `KeyboardMonitor` (275 lines) has only two minimal test files:
- `KeyboardMonitorResilienceTest.swift` (80 lines) — verifies structural correctness but cannot start the CGEventTap without accessibility permission
- `KeyboardDispatchPerformanceTest.swift` (50 lines) — benchmarks dispatch overhead, not the monitor itself

Untested paths:
- `createEventTap()` error handling when CGEventTap.tapCreate returns nil
- `tearDownEventTap()` idempotency
- `handleEvent()` dispatch for different event types
- `handleFlagsChangedEvent()` debouncing logic
- `registerWakeObserver()` and observer cleanup
- `.keyUp` events are explicitly not monitored (could be a feature requirement)

### 8.2 DebugWindowController — No Dedicated Test File
**Risk:** Medium
**Detail:** `DebugWindowController` (413 lines) has no dedicated test file. Tests in `KeyPulseTests.swift` verify basic init/show/hide behavior, but don't test:
- Window setup with nil controller
- `toggleWindow()` when window is nil
- `windowShouldClose()` behavior
- SwiftUI `DebugView` rendering (requires View inspection)
- Modifier indicator rendering

### 8.3 PreferencesWindowController — Minimal Coverage
**Risk:** Medium
**Detail:** Tests exist in `KeyPulseTests.swift` for init/show/hide, but don't test:
- Settings change through the SwiftUI bindings (requires UI testing)
- Notification posting for "Show Debug Window"
- Reset-to-defaults flow
- `onSettingsChanged` callback propagation
- Tab switching behavior

### 8.4 AudioEngine Configuration Change — Object Filter Mismatch
**File:** `KeyPulse/Tests/KeyPulseTests/AudioEngineConfigurationTest.swift` (lines 81-102)
**Risk:** Medium
**Detail:** As noted in bugs (2.3), the test posts `nil` object, but the real observer filters on `object: engine`. The test works because NotificationCenter delivers nil-object posts to all observers regardless of object filter, but the test is misleading. It doesn't verify the object filter is correctly scoped.

### 8.5 No Integration Tests for Full Keystroke→Audio Pipeline
**Risk:** Medium
**Detail:** No test exercises the complete path: CGEvent (simulated) → KeyboardMonitor.onKeyDown → KeyPulseController.playRandomSample → AudioEngine.play(). Tests are either AudioEngine-only or structural. The integration between components is untested.

### 8.6 No Performance Regression Baseline Storage
**Risk:** Medium
**Detail:** Performance tests have inline thresholds that could drift. No stored baseline is checked against CI runs.

### 8.7 MenuBarManager Callbacks Never Triggered Through Actions
**Risk:** Medium
**Detail:** `MenuBarManagerTests` verify callbacks are wired (`XCTAssertNotNil(manager.onEnabledChanged)`) but never trigger them through actual menu actions (`toggleEnabled()`, `profileSelected()`, etc.). The `@objc` action methods are untested.

---

## 9. Documentation Gaps

### 9.1 Missing CHANGELOG.md
**Risk:** Low
**Detail:** No changelog exists. Changes are tracked only through git history and the PRD.

### 9.2 Missing CONTRIBUTING.md
**Risk:** Low
**Detail:** No contributing guidelines for external contributors.

### 9.3 Missing Architecture Decision Records (ADRs)
**Risk:** Low
**Detail:** Key decisions (CGEventTap vs IOHIDManager, 8 player nodes, pre-warming, 0xFF sentinel, 20Hz throttling) are documented in code comments but not in a centralized ADR document.

### 9.4 Missing Privacy Policy
**Risk:** Medium
**Detail:** No privacy policy document exists. For App Store submission and user trust, a privacy policy explaining what data is collected (keystroke events, for local audio only) and what is NOT collected (no network transmission, no storage, no tracking) should be added.

### 9.5 Debug Window Screenshot Missing
**File:** `README.md`
**Risk:** Low
**Detail:** Broken image reference as noted in bugs (2.1).

### 9.6 CLAUDE.md Points to AGENTS.md (Which is Minimal)
**Risk:** Low
**Detail:** `CLAUDE.md` contains only `@./AGENTS.md`, and `AGENTS.md` is focused on build/test/dev workflow. No AI/agent-specific guidance exists.

---

## 10. Architecture Risks

### 10.1 Singleton-Pattern Coupling in SettingsStore
**File:** `KeyPulse/Sources/KeyPulse/SettingsStore.swift` (line 10)
**Risk:** Medium
**Detail:** `SettingsStore.shared` is a singleton used everywhere. While injectable `UserDefaults` solves test isolation for individual tests, production code always uses `.standard`. This makes it impossible to run the app with different settings configurations (e.g., for UI previews or widget extensions).
**Action:** Consider using a dependency injection container or environment values for SwiftUI previews.

### 10.2 No Graceful Degradation on Audio Engine Failure
**File:** `KeyPulse/Sources/KeyPulse/KeyPulseAppDelegate.swift` (lines 112-128)
**Risk:** Medium
**Detail:** If `KeyPulseController.init()` throws (audio engine fails to start), the controller is nil and the app runs without any keyboard feedback. There's no retry mechanism or user-friendly error UI — the menu bar appears but does nothing.
**Action:** Show a specific menu bar state with error details and a "Retry" option.

### 10.3 No Crash Recovery for Event Tap
**File:** `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`
**Risk:** HIGH
**Detail:** Beyond the wake-notification handler (which gives one retry), there's no safety net. If the CGEventTap dies unexpectedly (e.g., due to a system policy change, SIP update, or permissions revocation), the user gets no feedback. The menu bar still shows "Enabled" but no sounds play.
**Action:** Add a periodic health check (e.g., every 30 seconds check `CGEvent.tapIsValid(tap:)` and restart if invalid). Show a menu bar warning icon when the tap is down.

### 10.4 Main Thread Dependency for Audio Playback
**File:** `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (lines 237-238)
**Risk:** Medium
**Detail:** As noted in performance (4.3), all playback dispatches through main queue. Under main thread contention, keystrokes are delayed and eventually dropped if the queue grows too large. A dedicated audio queue would isolate playback from UI jank.
**Action:** Create a dedicated serial `DispatchQueue` for audio dispatch, separate from `DispatchQueue.main`.

### 10.5 No Backpressure Mechanism in Keystroke Handling
**File:** `KeyPulse/Sources/KeyPulse/KeyPulseController.swift` (lines 141-166)
**Risk:** Low
**Detail:** The `onKeyDown` closure processes every keystroke synchronously: increments counter, plays sound, throttles diagnostics. If a user types faster than the audio engine can play (unlikely with 8 concurrent player nodes), events are silently dropped (player.scheduleBuffer with `.interrupts` replaces the previous buffer). There's no feedback to the user that sounds are being skipped.
**Action:** Document the 8-concurrent-sound limit in the UI. Optionally add a counter for "dropped sounds" in diagnostics.

---

## Summary of Risk Levels

| Risk Level | Count | Key Items |
|---|---|---|
| **HIGH** | 4 | Full keystroke capture (3.1), AudioEngine config change threading (5.1), KeyboardMonitor zero coverage (8.1), No event tap crash recovery (10.3) |
| **Medium** | 16 | Config change test (2.3), AudioEngine stop race (2.4), Wake retry (2.5), Main thread bottleneck (4.3), 0xFF sentinel overlap (5.3), Per-app profiles missing (7.1), Secure input pause missing (7.4), PreferencesView coverage (8.3), Pipeline integration tests (8.5), etc. |
| **Low** | 15 | Carbon linkage (1.1), Reset cache (1.2), Hardcoded metadata (1.3), Notification names (1.5), ISO keyboard (1.6), Rotation logic (2.7), Debug window screenshot (2.1), etc. |

**Total concerns documented: 35**
