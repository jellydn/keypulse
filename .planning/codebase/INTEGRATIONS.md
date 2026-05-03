# INTEGRATIONS.md — KeyPulse External Integrations

## Overview

KeyPulse is a **fully local** macOS application with no external service dependencies. It does not communicate with any remote servers, APIs, or cloud services. All operations — keystroke detection, audio playback, settings persistence — happen entirely on-device.

---

## External Services

| Service | Status | Details |
|---------|--------|---------|
| **Remote APIs** | None | No HTTP requests, REST APIs, or web socket connections |
| **Cloud Storage** | None | No iCloud, CloudKit, Dropbox, or other sync services |
| **Analytics** | None | No telemetry, crash reporting (Crashlytics, Sentry), or usage tracking |
| **Authentication** | None | No OAuth, Sign in with Apple, or identity providers |
| **Webhooks** | None | No outgoing or incoming webhooks |
| **Monitoring** | None | No APM, logging services, or remote observability |

---

## Data Storage

### UserDefaults (Primary Storage)

| Detail | Value |
|--------|-------|
| **Mechanism** | `Foundation.UserDefaults.standard` |
| **Purpose** | Persist user settings across app launches |
| **Keyspace Prefix** | `keypulse_*` (see `SettingsStore.swift` → `Keys` enum) |
| **Schema Version** | Current: `1` (stored under `keypulse_schemaVersion`) |
| **Migration** | `migrateIfNeeded()` in `SettingsStore.swift` — extensible for future schema changes |
| **Injection** | `init(defaults: UserDefaults = .standard)` allows test isolation via custom suites |

### Stored Settings Keys

| UserDefaults Key | Type | Default | Description |
|------------------|------|---------|-------------|
| `keypulse_schemaVersion` | Int | `1` | Settings schema version for migrations |
| `keypulse_profile` | String | `"linear"` | Active sound profile (linear/tactile/clicky) |
| `keypulse_volume` | Int | `100` | Volume percentage (0-100) |
| `keypulse_isMuted` | Bool | `false` | Mute state |
| `keypulse_isEnabled` | Bool | `true` | Whether keystroke processing is enabled |
| `keypulse_pitchRandomization` | Bool | `true` | Pitch variation per keystroke |
| `keypulse_launchAtLogin` | Bool | `false` | Launch-at-login preference (synced with SMAppService) |

### Bundle-Local Resources (Read-Only)

| Resource | Location | Format | Count |
|----------|----------|--------|-------|
| Sound samples | `Sources/KeyPulse/Resources/Sounds/*/` | WAV (PCM 16-bit mono 44.1kHz) | 12 files (4 per profile) |

---

## System Integrations

### macOS System Services

| Service | Framework | Integration Point | Details |
|---------|-----------|-------------------|---------|
| **CGEventTap** | CoreGraphics | `KeyboardMonitor.swift` | Global keyboard hook; listen-only mode (`kCGEventTapOptionListenOnly`); observes keyDown and flagsChanged events |
| **AVAudioEngine** | AVFoundation | `AudioEngine.swift` | Low-latency audio graph; 8 concurrent AVAudioPlayerNodes in round-robin; format conversion on load |
| **SMAppService** | ServiceManagement | `SettingsStore.swift` | Launch-at-login registration/unregistration; status caching with 5s TTL |
| **NSWorkspace** | AppKit | `KeyboardMonitor.swift` | System sleep/wake notifications (`NSWorkspace.didWakeNotification`) |
| **NSStatusBar** | AppKit | `MenuBarManager.swift` | Menu bar status item with programmatic template icon and contextual menu |
| **LSUIElement** | LaunchServices | `Info.plist` | App runs as menu bar agent with no Dock icon |
| **NSAccessibility** | ApplicationServices | `KeyboardMonitor.swift` | `AXIsProcessTrustedWithOptions()` — runtime permission check and request |
| **Unified Logging** | os.log | `Logging.swift` | Structured logging with subsystem `com.keypulse.app` and 6 categories |
| **NSWindow frame autosave** | AppKit | `DebugWindowController.swift`, `PreferencesWindowController.swift` | Window position/state persistence |
| **NotificationCenter** | Foundation | `KeyPulseAppDelegate.swift` | Cross-component communication (`keypulse_showDebugWindow` notification) |

### macOS Permission Requirements

| Permission | Type | Prompt | Required For |
|------------|------|--------|--------------|
| Accessibility | Runtime (AXIsProcessTrustedWithOptions) | System dialog on first launch | CGEventTap global keyboard monitoring |
| Microphone | Not required | — | Not used (playback only, no recording) |
| Network | Not required | — | Not used |
| Files | Not required | — | Only reads bundled resources |

---

## CI/CD

### Current Status: No CI/CD Pipeline

The project does **not** have any CI/CD configuration files (no `.github/workflows/`, no `.gitlab-ci.yml`, no `Jenkinsfile`, no `Dockerfile`).

### Available Build Automation

| Method | Trigger | Description |
|--------|---------|-------------|
| **just build** | Manual / pre-commit | `cd KeyPulse && swift build` |
| **just test** | Manual / pre-commit | `cd KeyPulse && swift test` |
| **just bundle** | Manual | Build release + copy into `.app` bundle structure |
| **Pre-commit hooks** | `git commit` | Runs `swift build` and `swift test` on each commit |

### Planned Distribution

| Channel | Method | Notes |
|---------|--------|-------|
| App Store | ExportOptions.plist (app-store method) | Requires Apple Developer Program, code signing, notarization |
| Direct DMG | `just bundle` + manual notarization | For direct download distribution |

---

## Environment Configuration

### No Runtime Environment Variables

The app does not read any environment variables at runtime. Configuration is entirely compile-time or stored in UserDefaults.

### Compile-Time Configuration

| Mechanism | Files | Purpose |
|-----------|-------|---------|
| Package.swift | Manifest | Target definitions, linked frameworks, resource paths |
| Info.plist | Bundle | Metadata, LSUIElement, accessibility description |
| ExportOptions.plist | Distribution | App Store signing configuration (manual, placeholder team ID) |
| KeyPulse.entitlements | Code signing | Hardened Runtime capabilities |

### No .xcconfig Files

The project does not use any `.xcconfig` configuration files.

---

## Summary

KeyPulse is a **self-contained, offline-capable** macOS application with zero external service integrations. Its only persistent storage is `UserDefaults` for user preferences. All audio assets are bundled with the app. The sole external integration required at runtime is the macOS Accessibility system permission for global keyboard monitoring, which is prompted on first launch via system UI.
