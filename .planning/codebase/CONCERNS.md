# Codebase Concerns

**Analysis Date:** 2026-05-02

## Tech Debt

**Logging uses `print()` everywhere instead of `os_log`:**
- Issue: All diagnostic output uses `print()` statements — 20+ calls across 4 files. No log levels, no subsystem tagging, no log persistence, no ability to disable in release builds.
- Files: `KeyPulse/Sources/KeyPulse/KeyPulseAppDelegate.swift` (lines 26, 37, 42, 47, 52, 57, 62, 67, 82, 90, 95, 98, 107, 113), `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (lines 81, 103, 118, 144), `KeyPulse/Sources/KeyPulse/AudioEngine.swift` (line 207), `KeyPulse/Sources/KeyPulse/SettingsStore.swift` (lines 130, 141), `KeyPulse/Sources/KeyPulse/MenuBarManager.swift` (line 239)
- Impact: Debug noise in production; no structured way to diagnose issues from user reports; Console.app filtering impossible.
- Fix approach: Replace with `os.Logger` (macOS 12+) using subsystem `com.keypulse.app` and category-based logging. Use `.debug` for diags, `.info` for state changes, `.error` for failures.

**Force-unwrap on URL string in `KeyboardMonitor`:**
- Issue: `URL(string: "x-apple.systempreferences:...")!` will crash if the URL scheme is ever invalid.
- Files: `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (line 66)
- Impact: Runtime crash in accessibility-settings-opening code path. Low probability but catastrophic if hit.
- Fix approach: Use `guard let url = URL(string: "...")` with a fallback or `URL(string: "...") ?? URL(string: "x-apple.systempreferences:")!` which is guaranteed valid.

**Force-unwrap on NSMenuItem in `MenuBarManager`:**
- Issue: `menu.addItem(enabledMenuItem!)`, `menu.addItem(muteMenuItem!)`, `menu.addItem(pitchVariationMenuItem!)`, `menu.addItem(launchAtLoginMenuItem!)` all force-unwrap implicitly unwrapped optionals that are set in the same `buildMenu()` method.
- Files: `KeyPulse/Sources/KeyPulse/MenuBarManager.swift` (lines 98, 151, 160, 171)
- Impact: If menu construction order changes or a menu item assignment is removed, the app will crash. Implicitly unwrapped optionals are fragile.
- Fix approach: Use safe unwrap with `guard let` or restructure to avoid optionals — e.g., construct items inline rather than storing as properties and adding later.

**No error propagation from `AudioEngine.loadProfile` to UI:**
- Issue: `KeyPulseController.setProfile()` throws, which is caught in `MenuBarManager.profileSelected()` with only a `print()`. The user gets no feedback if profile switching fails.
- Files: `KeyPulse/Sources/KeyPulse/MenuBarManager.swift` (line 239)
- Impact: Failed profile switches are invisible to the user; menu state may be inconsistent.
- Fix approach: Add an `onError` callback or use a proper alert via `NSAlert` to inform the user. Sync menu state back to actual `controller.currentProfile` after failure.

**`SoundAssets.sampleURLs` uses `compactMap` — silently drops missing files:**
- Issue: If a WAV file is missing from the bundle, `compactMap` returns nil and the URL is silently dropped. `AudioEngine.loadProfile` then checks `urls.count == SoundAssets.samplesPerProfile` and throws, but the root cause (missing file) is obscure.
- Files: `KeyPulse/Sources/KeyPulse/SoundAssets.swift` (lines 22-26)
- Impact: Debugging missing resources is harder — you get `bufferLoadFailed` rather than "file X not found".
- Fix approach: Change to `map` + explicit error with filename, or add a `validateResources()` method that logs which files are missing before attempting load.

## Known Bugs

**CGEventTap dies after system sleep / input monitoring toggle — no restart:**
- Symptoms: After macOS sleep/wake or toggling Accessibility permissions, the event tap stops receiving events. `KeyboardMonitor` has no restart-on-failure logic.
- Files: `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`
- Trigger: Put Mac to sleep and wake, or toggle Accessibility off/on in System Settings.
- Workaround: Quit and relaunch KeyPulse. No in-app recovery exists.
- Fix approach: Override `eventTapFailed` callback on the `CGEventTap` to detect `.tapDisabledByTimeout` and `.tapDisabledByUserInput` events, and re-enable or recreate the tap. Also add `NSWorkspaceDidWakeNotification` observer to re-establish the tap.

**Launch-at-login state desync between `SMAppService` and UserDefaults:**
- Symptoms: `SettingsStore.launchAtLogin` getter uses `SMAppService.mainApp.status` as source of truth, which can differ from what's stored in UserDefaults. If `SMAppService.register()` throws (common in unsigned debug builds), UserDefaults still gets the `false` value but the UI toggle may show `on`.
- Files: `KeyPulse/Sources/KeyPulse/SettingsStore.swift` (lines 111-148)
- Trigger: Running unsigned/locally-built app; macOS revoking login items after updates.
- Workaround: Toggle again to re-sync.
- Fix approach: Make `launchAtLogin` setter return a `Result` or throw so the UI can reflect failures. On read, always query `SMAppService` — current behavior is correct but the toggle in `MenuBarManager.toggleLaunchAtLogin()` reads from local state rather than checking `SMAppService`.

**`SettingsStore` is a singleton with no isolation — test state pollution:**
- Symptoms: Tests using `SettingsStore.shared` can pollute each other's state. `resetToDefaults()` modifies actual UserDefaults.
- Files: `KeyPulse/Tests/KeyPulseTests/KeyPulseTests.swift` (multiple test methods call `SettingsStore.shared.resetToDefaults()`)
- Trigger: Running tests in different order or with parallel execution.
- Workaround: Tests currently call `resetToDefaults()` at the start of each test.
- Fix approach: Use a separate `UserDefaults` suite for testing (`UserDefaults(suiteName: "TestDefaults")`), inject it into `SettingsStore`, and call `removeSuite` in teardown. Or add an `init(userDefaults:)` designated initializer.

## Security Considerations

**Accessibility permission prompt and system settings URL:**
- Risk: App requires full Accessibility permission to monitor all keyboard input globally. The `NSAccessibilityUsageDescription` in `Info.plist` explains why, but this is a highly privileged permission that could concern privacy-focused users.
- Files: `KeyPulse/Info.plist` (`NSAccessibilityUsageDescription`), `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`
- Current mitigation: Uses `kCGEventTapOptionListenOnly` — the tap does not modify or intercept events. Entitlements explicitly disable network access.
- Recommendations: Document on the project README that the app never logs, transmits, or stores keystroke data. Consider adding a privacy policy. Add a periodic check for `AXIsProcessTrusted()` and show status in the menu bar icon.

**Hardened runtime entitlements are minimal — good, but JIT is explicitly set to `false`:**
- Risk: `com.apple.security.cs.allow-jit` is `false`, `network.client` and `network.server` are `false`. This is correctly restrictive but the `allow-jit` key being present (even with `false`) may cause confusion during review. It could be removed entirely since the default is `false`.
- Files: `KeyPulse/KeyPulse.entitlements`
- Current mitigation: All entitlements explicitly disabled. No network, no file access beyond bundle.
- Recommendations: Remove `com.apple.security.cs.allow-jit` since it's the default. Consider adding `com.apple.security.device.audio` if needed for `AVAudioEngine` on hardened runtime (though currently not required).

**No obfuscation or rate-limiting on keystroke timing data:**
- Risk: While the app only uses key-down events (not key content), the timing between sounds could theoretically leak typing speed patterns to an observer. This is very low risk since the app only plays audio.
- Files: `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`
- Current mitigation: `listenOnly` mode; no logged keystroke data.
- Recommendations: No action needed — this is informational only.

## Performance Bottlenecks

**Audio buffer format conversion during `loadProfile` runs on main thread:**
- Problem: `AudioEngine.loadProfile()` calls `loadAndConvertBuffer()` which creates `AVAudioFile`, reads PCM data, and potentially converts format via `AVAudioConverter`. This happens synchronously and could block the main thread if WAV files are large.
- Files: `KeyPulse/Sources/KeyPulse/AudioEngine.swift` (lines 148-206)
- Cause: WAV files are small (<100ms per AGENTS.md), so the practical impact is minimal, but the design is not future-proof for larger sample packs.
- Improvement path: Move profile loading to a background queue with a completion handler. Pre-warm all three profiles on app launch in anticipation of quick switches.

**`SettingsStore.launchAtLogin` getter calls `SMAppService.mainApp.status` on every read:**
- Problem: `SMAppService.status` may involve inter-process communication with `logind`. Called on every `syncMenuState()` invocation and when reading the property.
- Files: `KeyPulse/Sources/KeyPulse/SettingsStore.swift` (lines 112-127)
- Cause: System API call rather than cached value.
- Improvement path: Cache the status and refresh on explicit demand or via `SMAppService` state change notification (if available). This is minor — the call is fast.

**`DispatchQueue.main.async` for every keystroke callback:**
- Problem: `KeyboardMonitor.handleEvent()` dispatches every key-down event to the main thread via `DispatchQueue.main.async`. At high typing speeds (100+ WPM), this creates many small dispatches.
- Files: `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (line 152)
- Cause: Required by AppKit — audio playback from AVAudioEngine needs main run loop. However, the `play()` path itself does minimal work (schedule pre-loaded buffer).
- Improvement path: Profile actual latency; if problematic, consider using `DispatchQueue.global(qos: .userInteractive)` for the audio scheduling and only dispatch UI updates to main.

**Round-robin player node selection uses `NSLock`:**
- Problem: `NSLock` in `AudioEngine.play()` for `nextPlayerIndex` is acquired/released per keystroke. `os_unfair_lock` would be faster for this contention-free critical section.
- Files: `KeyPulse/Sources/KeyPulse/AudioEngine.swift` (lines 73, 229-232)
- Cause: `NSLock` is a recursive-safe lock with higher overhead than necessary for this simple counter.
- Improvement path: Replace with `os_unfair_lock_s` (available since macOS 10.14) for lower overhead on the hot path. Alternatively use `NSLock` with `name` for debugging during development.

## Fragile Areas

**Sound asset loading depends on SwiftPM resource bundle flattening:**
- Files: `KeyPulse/Sources/KeyPulse/SoundAssets.swift`, `KeyPulse/Package.swift`
- Why fragile: SwiftPM's `.process("Resources")` flattens directory structure. Sound files are currently at `Resources/Sounds/{linear,tactile,clicky}/` with unique prefixes (`linear_key_01.wav`). If someone adds a file like `key_01.wav` without the profile prefix, it could collide. The `SoundAssets.sampleURLs` function constructs filenames from `profile.filenamePrefix` — any renaming breaks the lookup silently.
- Safe modification: Always use the `{profile}_key_{NN}` naming convention. Never rely on subdirectory structure.
- Test coverage: `testSoundAssetsSampleURLsForLinear/Tactile/Clicky` verify URLs resolve, but don't guard against future naming regressions.

**`MenuBarManager` implicitly unwrapped optionals for menu items:**
- Files: `KeyPulse/Sources/KeyPulse/MenuBarManager.swift` (lines 29-34)
- Why fragile: `enabledMenuItem`, `muteMenuItem`, `pitchVariationMenuItem`, `launchAtLoginMenuItem` are declared as implicitly unwrapped optionals (`NSMenuItem?`) but force-unwrapped in `buildMenu()`. If `buildMenu()` is called out of order, or items are restructured, crashes follow.
- Safe modification: Convert to non-optional properties or use safe unwrapping.
- Test coverage: No unit tests exist for `MenuBarManager`.

**`KeyPulseController` owns `KeyboardMonitor` and `AudioEngine` without dependency injection:**
- Files: `KeyPulse/Sources/KeyPulse/KeyPulseController.swift` (lines 16-19)
- Why fragile: `KeyboardMonitor` and `AudioEngine` are created directly in `init`. Makes testing `KeyPulseController` in isolation difficult — test must create real `AudioEngine` (which requires hardware audio).
- Safe modification: Accept protocols or factory closures in `init` for testability. Create `AudioEngineProtocol` and `KeyboardMonitorProtocol`.
- Test coverage: Tests create real `AudioEngine` instances; works on CI with audio hardware but fragile.

**CGEventTap callback uses `Unmanaged.passUnretained(self)` — lifetime risk:**
- Files: `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift` (lines 98-106)
- Why fragile: The `userInfo` parameter passes an unretained reference to `self`. If `KeyboardMonitor` is deallocated while the tap is still active, the callback will reference freed memory → crash.
- Safe modification: Ensure `stop()` is always called in `deinit` (it is), and verify the tap is invalidated before the object is freed. Consider using `Unmanaged.passRetained`/`Unmanaged.passUnretained` with explicit lifecycle management.
- Test coverage: No unit tests exercise the callback's lifetime semantics.

## Scaling Limits

**Player node pool size is fixed at 8:**
- Current capacity: 8 concurrent `AVAudioPlayerNode` instances.
- Limit: At extreme typing speeds (>100 WPM burst), 8 simultaneous sounds may not be enough, causing overlapping notes to cut each other off due to `.interrupts` schedule option.
- Scaling path: Make `concurrentPlayerCount` configurable or dynamically increase based on typing burst detection. Alternatively, use `.interrupts` more carefully — currently every `scheduleBuffer` call uses `.interrupts`, meaning the same player node will stop its current playback.

**Only 3 profiles × 4 samples each = 12 WAV files bundled:**
- Current capacity: 3 profiles, 4 variants each.
- Limit: Adding custom sound packs or more profiles requires code changes to the `SoundProfile` enum.
- Scaling path: Make `SoundProfile` dynamic (loaded from disk/plist) rather than a compile-time enum. Support arbitrary profile names and sample counts from the resource bundle.

**`SettingsStore` uses a flat UserDefaults namespace — no migration path:**
- Current capacity: 6 keys in `UserDefaults.standard` with `keypulse_` prefix.
- Limit: No versioning or migration strategy if settings schema changes.
- Scaling path: Add a `keypulse_settingsVersion` key and a migration function that upgrades from older schemas.

## Dependencies at Risk

**SwiftPM resource flattening:**
- Risk: Swift Package Manager flattens the `Resources/Sounds/{linear,tactile,clicky}/` directory structure. The current naming convention (`{profile}_key_{NN}.wav`) works around this, but it's a convention, not enforced.
- Impact: Adding sound files without the profile prefix would cause collision or lookup failure.
- Migration plan: No alternative available in SwiftPM currently. Document the convention clearly in code comments and enforce via CI check.

**Carbon framework for virtual key codes:**
- Risk: `Carbon` is technically deprecated but still ships with macOS. `KeyboardMonitor` imports `Carbon` to access virtual key code constants.
- Impact: If Apple removes `Carbon.framework`, key code constants would need to be defined manually.
- Migration plan: Replace `Carbon` import with hardcoded `UInt16` constants for the key codes used (or `CGKeyCode` from CoreGraphics). Only the `keyCode` field is used — no actual Carbon API calls.

**ServiceManagement framework for launch at login:**
- Risk: `SMAppService` (macOS 13+) is the current recommended API but requires code signing. In unsigned debug builds, `register()` may throw.
- Impact: Launch-at-login feature is non-functional in local debug builds.
- Migration plan: No migration path needed — this is the correct modern API. Accept that it requires proper signing for full functionality.

## Missing Critical Features

**No CGEventTap restart on failure:**
- Problem: When the event tap is disabled by the system (timeout, user toggle), there is no recovery mechanism. The app silently stops receiving keyboard events.
- Blocks: Reliable unattended operation — user must relaunch after tap failure.

**No accessibility permission re-check after initial denial:**
- Problem: If the user denies Accessibility permission on first launch, the app opens System Settings once but doesn't monitor for when permission is granted. The user must relaunch the app after granting.
- Blocks: Smooth first-run experience.

**No unit tests for `KeyboardMonitor` or `MenuBarManager`:**
- Problem: `KeyboardMonitor` requires Accessibility permission and real CGEventTap, making it untestable in CI. `MenuBarManager` has no unit tests at all.
- Blocks: Regression testing of menu state synchronization and event tap lifecycle.

**No crash reporting or analytics:**
- Problem: No mechanism to capture crashes or usage data. Force unwraps and error paths could crash silently.
- Blocks: Understanding real-world failure rates.

**Test coverage does not exercise launch-at-login with `SMAppService`:**
- Problem: The tests for `launchAtLogin` have comments acknowledging they can't fully test `SMAppService` behavior. The getter/setter round-trip is only partially testable.
- Blocks: Confidence that launch-at-login works across app updates and macOS upgrades.

## Test Coverage Gaps

**`KeyboardMonitor` has zero isolated unit tests:**
- What's not tested: `start()`, `stop()`, `checkAccessibilityPermission()`, `requestAccessibilityPermission()`, `handleEvent()` callback, event tap creation failure, tap restart after failure.
- Files: `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`
- Risk: Any change to event tap lifecycle or accessibility permission flow could break silently.
- Priority: High — but requires protocol-based abstraction to mock `CGEvent` and `AXIsProcessTrustedWithOptions`.

**`MenuBarManager` has zero unit tests:**
- What's not tested: Menu construction, state synchronization, callback wiring, volume slider behavior, profile selection, enabled/mute/pitch toggles.
- Files: `KeyPulse/Sources/KeyPulse/MenuBarManager.swift`
- Risk: Menu state can drift from controller state without detection.
- Priority: High — test menu construction by verifying `NSMenu` item count and titles.

**`KeyPulseAppDelegate` has a minimal initialization test only:**
- What's not tested: `applicationDidFinishLaunching` full flow, settings application, accessibility permission flow, error handling on controller init failure.
- Files: `KeyPulse/Sources/KeyPulse/KeyPulseAppDelegate.swift`
- Risk: Integration bugs between controller, menu bar, and settings are invisible.
- Priority: Medium — requires app lifecycle mocking.

**`AudioEngine.loadAndConvertBuffer` error paths are not tested:**
- What's not tested: Corrupt WAV files, missing resources, format conversion failures, buffer allocation failures.
- Files: `KeyPulse/Sources/KeyPulse/AudioEngine.swift` (lines 173-206)
- Risk: Error handling code is untested — format conversion failure path returns `nil` which causes `loadProfile` to throw.
- Priority: Medium — test with invalid/corrupt data in test bundle.

**No performance/latency tests:**
- What's not tested: Audio playback latency, buffer scheduling overhead, memory usage with concurrent playback at speed.
- Files: All source files.
- Risk: The core value proposition (< 20ms latency) is not verified by tests.
- Priority: Low — requires specialized audio measurement tooling.

---

*Concerns audit: 2026-05-02*
