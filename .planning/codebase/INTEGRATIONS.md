# Integrations

**Analysis Date:** 2026-05-02

## Overview

KeyPulse is a **fully offline macOS application** with **zero external service integrations**. It has no network dependencies, no cloud APIs, no databases, and no authentication providers. All core functionality is provided by Apple system frameworks.

## External Services

**None.** The application makes no outbound network requests, uses no cloud services, and operates entirely offline.

- ❌ No REST APIs
- ❌ No GraphQL endpoints
- ❌ No cloud services (AWS, GCP, Azure)
- ❌ No analytics platforms
- ❌ No crash reporting services
- ❌ No telemetry

## Databases

**None.** Persistent storage uses `UserDefaults` only — no Core Data, no SQLite, no Realm.

- **Storage:** `UserDefaults.standard` via `KeyPulse/Sources/KeyPulse/SettingsStore.swift`
- **Keys:** Prefixed with `keypulse_` (e.g., `keypulse_profile`, `keypulse_volume`, `keypulse_isMuted`, `keypulse_isEnabled`, `keypulse_pitchRandomization`, `keypulse_launchAtLogin`)
- **No schema migrations needed** — simple key-value pairs only

## Authentication

**No user authentication.** The app requires no login or identity management.

## Apple System Framework Integrations

These are the platform APIs that KeyPulse integrates with:

### AVFoundation — Audio Playback
- **File:** `KeyPulse/Sources/KeyPulse/AudioEngine.swift`
- **Components:** `AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioPCMBuffer`, `AVAudioConverter`, `AVAudioFile`
- **Purpose:** Low-latency playback of pre-loaded WAV samples with pitch randomization
- **Pattern:** 8 concurrent player nodes with round-robin selection for overlapping sounds
- **Latency target:** < 20ms trigger-to-output

### CoreGraphics — Keyboard Event Monitoring
- **File:** `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`
- **Components:** `CGEvent`, `CGEventTap`, `CGEventMask`, `CGEventType`
- **Purpose:** Global keyboard event monitoring (listen-only, non-intercepting)
- **Permission:** Requires Accessibility access (`AXIsProcessTrustedWithOptions`)
- **Event tap type:** `kCGEventTapOptionListenOnly` — does not modify or consume events

### Carbon — Key Code Constants
- **File:** `KeyPulse/Package.swift` (linked framework), `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`
- **Purpose:** Virtual key code constants used alongside CGEvent key codes
- **Note:** Carbon is used only for key code definitions, not for UI (Carbon UI APIs are deprecated)

### ServiceManagement — Launch at Login
- **File:** `KeyPulse/Sources/KeyPulse/SettingsStore.swift`
- **Components:** `SMAppService.mainApp`
- **Purpose:** Register/unregister the app for launch-at-login via macOS 13+ API
- **Pattern:** Register on enable, unregister on disable; `SMAppService.status` is source of truth

### AppKit — Menu Bar UI
- **File:** `KeyPulse/Sources/KeyPulse/MenuBarManager.swift`, `KeyPulse/Sources/KeyPulse/KeyPulseAppDelegate.swift`
- **Components:** `NSStatusItem`, `NSMenu`, `NSMenuItem`, `NSApplication`, `NSSlider`, `NSWorkspace`
- **Purpose:** Menu bar icon, dropdown menu with profile/volume/mute/pitch variation/launch controls
- **App type:** `LSUIElement = YES` — no Dock icon, menu bar only

### Foundation — Core Types & Persistence
- **File:** All source files
- **Components:** `UserDefaults`, `FileManager`, `DispatchQueue`, `Bundle`
- **Purpose:** Settings persistence, file existence checks, thread dispatching, resource bundle access

## Accessibility Integration

**Soft dependency — requires user grant:**

| Aspect | Detail |
|--------|--------|
| Permission | Accessibility (System Settings → Privacy & Security → Accessibility) |
| API | `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt` |
| Description | Declared in `KeyPulse/Info.plist` under `NSAccessibilityUsageDescription` |
| Prompt text | "KeyPulse needs to listen to keyboard events system-wide to play mechanical keyboard sounds." |
| Fallback | `KeyboardMonitor.openAccessibilitySettings()` opens System Settings to the right pane |
| Runtime check | `KeyboardMonitor.checkAccessibilityPermission()` returns `Bool` |

## Code Signing & Distribution

| Aspect | Detail |
|--------|--------|
| Bundle ID | `com.keypulse.app` |
| Signing | Hardened runtime (entitlements in `KeyPulse/KeyPulse.entitlements`) |
| Distribution target | App Store / TestFlight via `ExportOptions.plist` |
| Notarization | Required for distribution outside App Store |
| JIT | Explicitly disabled (`com.apple.security.cs.allow-jit = false`) |
| Network | Explicitly no network entitlements |
| File access | No special file system entitlements |

## Build/CI Integrations

**None currently.** No CI/CD pipeline, no GitHub Actions, no automated builds.

- Build is manual via `just` recipes or `swift build`
- Sign/archive is manual via `scripts/build-release.sh`
- Ralph (`scripts/ralph/`) provides agent-driven development loop, not CI

---

*Integrations analysis: 2026-05-02*
