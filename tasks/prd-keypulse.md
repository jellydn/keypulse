# PRD: KeyPulse

## 1. Introduction / Overview

KeyPulse is a lightweight macOS menu-bar app that plays low-latency mechanical
keyboard sounds for every keystroke, system-wide. It replicates the tactile-audio
satisfaction of a mechanical keyboard on laptops and membrane keyboards without
extra hardware or noise pollution.

**Core value proposition:** *"Make any keyboard feel satisfying."*

## 2. Goals

- Deliver perceptually-instant audio feedback (< 20 ms) on every keystroke.
- Ship 3 distinct sound profiles (Linear, Tactile, Clicky) bundled as WAV samples.
- Provide a zero-friction menu-bar UX (no Dock icon, no onboarding).
- Persist user preferences across launches.
- Mitigate audio fatigue with subtle pitch randomization (selected nice-to-have).
- Keep the app idle CPU usage under 5% and memory footprint minimal.
- Produce a TestFlight-installable beta build.

## 3. User Stories

### US-001: Scaffold Swift macOS menu-bar app project
**Description:** As a developer, I need a working Xcode project for a macOS menu-bar (LSUIElement) app so subsequent stories have a build target.

**Acceptance Criteria:**
- [ ] Create `KeyPulse.xcodeproj` with macOS app target, Swift 5.9+, deployment target macOS 13
- [ ] Set `LSUIElement = YES` in Info.plist (no Dock icon, menu bar only)
- [ ] App launches and shows a placeholder `NSStatusItem` with title "KP"
- [ ] `xcodebuild -scheme KeyPulse build` succeeds with no new warnings
- [ ] Typecheck passes

### US-002: Bundle WAV sound assets for 3 profiles
**Description:** As a developer, I need pre-recorded keystroke samples bundled in the app so the audio engine has assets to play.

**Acceptance Criteria:**
- [ ] Add `Resources/Sounds/` folders: `linear/`, `tactile/`, `clicky/`
- [ ] Each profile folder has ≥ 4 WAV samples (16-bit, 44.1 kHz, < 100 ms)
- [ ] Samples sourced from **free / CC0 packs**, choosing the highest available audio quality
- [ ] Add `Resources/Sounds/CREDITS.md` listing source, license, and any attribution requirements
- [ ] Samples are added to the app target's Copy Bundle Resources phase
- [ ] Add a `SoundAssets` enum that resolves bundle URLs for each profile
- [ ] Unit test verifies all sample URLs resolve and files exist
- [ ] Typecheck passes
- [ ] Tests pass

### US-003: Implement low-latency Core Audio playback engine
**Description:** As a developer, I need an `AudioEngine` that pre-loads samples and triggers playback in under 20 ms so keystrokes feel instant.

**Acceptance Criteria:**
- [ ] Create `AudioEngine` using `AVAudioEngine` + `AVAudioPlayerNode`
- [ ] Pre-load all samples for the active profile into `AVAudioPCMBuffer` instances at startup
- [ ] `play(sampleIndex:)` schedules a buffer with no file I/O on the call
- [ ] Concurrent playback supported (overlapping keystrokes do not cut off)
- [ ] Measured trigger-to-output latency under 20 ms on a developer Mac
- [ ] Unit test confirms engine starts, loads buffers, and `play(...)` does not throw
- [ ] Typecheck passes
- [ ] Tests pass

### US-004: Implement global keyboard hook (event capture)
**Description:** As a developer, I need a system-wide keystroke listener so the app reacts to typing in any application.

**Acceptance Criteria:**
- [ ] Create `KeyboardMonitor` class that captures key-down events system-wide via `CGEventTap`
- [ ] On first run, prompt user via `AXIsProcessTrustedWithOptions`
- [ ] Add `NSAccessibilityUsageDescription` to Info.plist
- [ ] Monitor exposes a callback `onKeyDown: (keyCode: UInt16) -> Void`
- [ ] Manual verification doc in PR: typing in TextEdit triggers the callback (logged to Console)
- [ ] Typecheck passes

### US-005: Wire keystroke events to audio playback
**Description:** As a user, I want to hear a sound the moment I press any key so typing feels mechanical.

**Acceptance Criteria:**
- [ ] Create `KeyPulseController` that owns `KeyboardMonitor` + `AudioEngine`
- [ ] On each key-down, controller picks a random sample from the current profile and plays it
- [ ] **All key-down events trigger sound, including modifier-only keys (shift/cmd/option/ctrl)** — no suppression
- [ ] Manual verification: launch app, type in any app, hear a sound per keystroke with no audible lag
- [ ] Unit test for sample-selection rotation logic
- [ ] Typecheck passes
- [ ] Tests pass

### US-006: Add sound profile model and runtime switching
**Description:** As a user, I want to switch between Linear, Tactile, and Clicky profiles so I can pick the feel I prefer.

**Acceptance Criteria:**
- [ ] Define `SoundProfile` enum: `.linear`, `.tactile`, `.clicky` with display names
- [ ] `KeyPulseController.setProfile(_:)` swaps loaded buffers without restarting the engine
- [ ] Switching profile while typing does not crash and applies on the next keystroke
- [ ] Unit test confirms `setProfile` reloads the correct buffer set
- [ ] Typecheck passes
- [ ] Tests pass

### US-007: Add volume control and mute toggle
**Description:** As a user, I want a 0–100 volume slider and a mute toggle so I can control loudness.

**Acceptance Criteria:**
- [ ] `AudioEngine` exposes `volume: Float` (0.0–1.0) bound to the player node's volume
- [ ] `AudioEngine.isMuted: Bool` short-circuits playback when true (no buffer scheduling)
- [ ] Controller provides `setVolume(_ percent: Int)` (0–100) and `setMuted(_:)`
- [ ] Unit tests verify volume clamping and mute behavior
- [ ] Typecheck passes
- [ ] Tests pass

### US-008: Build menu bar UI (toggle, profile picker, volume slider)
**Description:** As a user, I want a simple menu bar interface so I can control KeyPulse without opening a window.

**Acceptance Criteria:**
- [ ] `NSStatusItem` shows a custom monochrome template icon
- [ ] Clicking opens an `NSMenu` with: "Enabled" toggle, profile submenu (Linear / Tactile / Clicky with checkmarks), volume slider, "Mute", "Quit KeyPulse"
- [ ] All controls reflect and update controller state in real time
- [ ] Manual verification: each control changes behavior immediately while typing
- [ ] Typecheck passes

### US-009: Persist user settings in UserDefaults
**Description:** As a user, I want my profile, volume, mute state, and enabled state to survive app restarts.

**Acceptance Criteria:**
- [ ] Create `SettingsStore` with keyed accessors: `profile`, `volume`, `isMuted`, `isEnabled`
- [ ] Load values on launch and apply to controller before showing the menu
- [ ] Save on every change via property observers
- [ ] Unit test round-trips each setting through `UserDefaults`
- [ ] Manual verification: change settings, quit, relaunch — settings restored
- [ ] Typecheck passes
- [ ] Tests pass

### US-010: Add pitch randomization (selected nice-to-have)
**Description:** As a user, I want subtle pitch variation per keystroke so repeated typing does not become fatiguing.

**Acceptance Criteria:**
- [ ] Add `pitchRandomization: Bool` to `SettingsStore` (default `true`)
- [ ] `AudioEngine.play(...)` randomly varies playback rate by ±5% per buffer
- [ ] Add menu item "Pitch Variation" toggle reflecting the setting
- [ ] Unit test confirms rate stays within ±5% bounds
- [ ] Manual verification: repeated identical keys sound subtly different
- [ ] Typecheck passes
- [ ] Tests pass

### US-011: Add launch-at-login and background runtime polish
**Description:** As a user, I want KeyPulse to start when I log in and run unobtrusively so it is set-and-forget.

**Acceptance Criteria:**
- [ ] Add "Launch at Login" menu item using `SMAppService.mainApp` (macOS 13+)
- [ ] State persists in `SettingsStore` and reflects current login-item registration
- [ ] App keeps `LSUIElement = YES` (no Dock icon, no main window)
- [ ] Idle CPU usage measured under 5% on developer Mac (recorded in PR notes)
- [ ] Typecheck passes

### US-012: Configure signing, notarization, and TestFlight build
**Description:** As a developer, I need a distributable beta build so testers can install KeyPulse via TestFlight.

**Acceptance Criteria:**
- [ ] Set bundle identifier `com.keypulse.app` and version `0.1.0`
- [ ] Configure code signing with Developer ID + automatic signing
- [ ] Add hardened runtime entitlements (document any required entitlements)
- [ ] Add `scripts/build-release.sh` that runs `xcodebuild archive` and `xcodebuild -exportArchive`
- [ ] Document TestFlight upload steps in `README.md`
- [ ] Typecheck passes

## 4. Functional Requirements

- FR-1: The app must run as an `LSUIElement` (menu bar only, no Dock icon).
- FR-2: The app must capture key-down events system-wide via `CGEventTap`.
- FR-3: The app must request Accessibility permission on first launch.
- FR-4: Each key-down must trigger playback of a randomly chosen sample from the active profile, including modifier-only keys.
- FR-5: Playback latency from keystroke to audible output must be under 20 ms.
- FR-6: The app must ship 3 sound profiles (Linear, Tactile, Clicky), each with ≥ 4 WAV samples.
- FR-7: The user must be able to switch profiles at runtime via the menu without restarting the engine.
- FR-8: The user must be able to set volume (0–100%) and mute via the menu.
- FR-9: All preferences (profile, volume, mute, enabled, launch-at-login, pitch variation) must persist in `UserDefaults`.
- FR-10: Each playback must apply random pitch variation of ±5% when the pitch-variation setting is enabled.
- FR-11: The app must offer a "Launch at Login" toggle backed by `SMAppService.mainApp`.
- FR-12: The build pipeline must produce a signed, notarized archive suitable for TestFlight.

## 5. Non-Goals (Out of Scope for MVP)

- Key-release sounds (down only).
- Per-key or keyboard-specific sound mapping.
- Per-app sound profiles.
- Custom user-imported sound packs.
- Cloud sync of settings.
- Windows or Linux support.
- Analytics, telemetry, or accounts.
- Login/subscription flows.

## 6. Design Considerations

- Menu-bar icon: monochrome template image, ~18×18 pt.
- Status menu order: Enabled → Profile submenu → Volume slider → Mute → Pitch Variation → Launch at Login → Quit.
- Sound assets are short (< 100 ms) and pre-loaded into PCM buffers at startup to avoid file I/O on the keystroke path.
- First-run Accessibility prompt should be non-blocking and re-enterable from the menu.

## 7. Technical Considerations

- **Audio:** `AVAudioEngine` + `AVAudioPlayerNode` with pre-loaded `AVAudioPCMBuffer` instances; pitch via `AVAudioUnitTimePitch` or per-node `rate`.
- **Input:** `CGEventTap` at session level; requires Accessibility permission. `IOHIDManager` retained as a fallback if event-tap latency is insufficient.
- **Persistence:** `UserDefaults` only — no Keychain, no iCloud.
- **Concurrency:** Audio scheduling on a dedicated serial queue to avoid main-thread jitter.
- **Distribution:** TestFlight first; channel decision (MAS vs. notarized DMG) deferred until after beta.

## 8. Success Metrics

- Time-to-first-sound after install: under 30 seconds.
- Trigger-to-output latency: < 20 ms (measured on dev hardware).
- Idle CPU usage: < 5%.
- Crash-free sessions: 99%+ across browser, IDE, editor.
- 7-day retention and % of users with sound enabled after day 1 (post-beta).

## 9. Resolved Decisions

- **Sample source:** Use **free / CC0 packs**, prioritizing the best audio quality available. No paid licensing for MVP.
- **Modifier-only keystrokes:** **Trigger sound** for them too (no suppression). All key-down events produce audio.
- **Pricing:** **Free for now.** Optional flat-price "support the dev" tier may be added later — exact amount TBD.
- **Distribution channel:** **TBD** — revisit after TestFlight beta feedback (MAS vs. notarized DMG).
- **Panic-mute global hotkey:** **Out of scope (KISS).** Users can mute via the menu bar.

---

**Ralph mirror:** This PRD is encoded as machine-readable user stories in
[`scripts/ralph/prd.json`](../scripts/ralph/prd.json) for autonomous execution.
