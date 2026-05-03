# STACK.md — KeyPulse Technology Stack

## Overview

KeyPulse is a native macOS menu bar application (LSUIElement) that plays low-latency mechanical keyboard sounds. It uses no external dependencies — only Apple system frameworks accessed via Swift Package Manager.

---

## Languages

| Language | Version | Notes |
|----------|---------|-------|
| Swift | 5.9+ | Declared via `// swift-tools-version:5.9` in Package.swift |
| Objective-C | Runtime-only | Indirect use via Cocoa/AppKit bridging |

---

## Runtime Requirements

| Requirement | Version | Source |
|-------------|---------|--------|
| macOS | 13+ (Ventura) | `platforms: [.macOS(.v13)]` in Package.swift |
| Architecture | arm64 (Apple Silicon) | Build artifacts in `.build/arm64-apple-macosx/` |
| Accessibility Permission | Runtime-granted | Required for CGEventTap; prompted via `AXIsProcessTrustedWithOptions()` |

---

## Build System

| Component | Detail | Source |
|-----------|--------|--------|
| Package Manager | Swift Package Manager (SwiftPM) | `Package.swift` (No SPM dep; no Package.resolved) |
| Tools Version | `swift-tools-version:5.9` | `Package.swift` line 1 |
| Command Runner | just | `justfile` at project root |
| Pre-commit | prek (pre-commit-kit) | `prek.toml` at project root |

### justfile Commands

| Command | Action |
|---------|--------|
| `just build` | `cd KeyPulse && swift build` |
| `just test` | `cd KeyPulse && swift test` |
| `just release` | `cd KeyPulse && swift build -c release` |
| `just run` | `cd KeyPulse && swift run` |
| `just clean` | Clean build artifacts |
| `just fmt` | Format Swift code with swift-format |
| `just lint` | Lint Swift code with swift-format |
| `just xcode` | Generate Xcode project |
| `just bundle` | Create app bundle in `dist/` |
| `just deps` | Show package dependency tree |
| `just debug-install` | Copy debug build to `~/.local/bin` |

### Pre-commit Hooks (prek.toml)

- `trailing-whitespace` — trim trailing whitespace
- `end-of-file-fixer` — ensure files end with newline
- `check-yaml` — validate YAML syntax
- `check-added-large-files` — prevent large file commits
- `swift-build` — run `swift build` on commit
- `swift-test` — run `swift test` on commit

---

## Frameworks & System Libraries

### Directly Imported Frameworks

| Framework | Usage | Imported In |
|-----------|-------|-------------|
| **AppKit** | Application lifecycle, menu bar, windows, NSApplication, NSStatusItem, NSMenu | `KeyPulse.swift`, `KeyPulseAppDelegate.swift`, `KeyboardMonitor.swift`, `MenuBarManager.swift`, `DebugWindowController.swift`, `PreferencesWindowController.swift` |
| **AVFoundation** | AVAudioEngine, AVAudioPlayerNode, AVAudioPCMBuffer, AVAudioFile, AVAudioConverter | `AudioEngine.swift` |
| **CoreGraphics** | CGEventTap, CGEvent, CGEventFlags, CGEventMask, CGEventTapProxy, CGEventType | `KeyboardMonitor.swift`, `KeyPulseController.swift` |
| **Combine** | @Published property wrappers, ObservableObject conformance | `KeyPulseController.swift`, `SettingsStore.swift` |
| **SwiftUI** | Debug Window views, Preferences Window views (NSHostingController, View, @ObservedObject) | `DebugWindowController.swift`, `PreferencesWindowController.swift` |
| **ServiceManagement** | SMAppService — launch-at-login registration | `SettingsStore.swift`, `Package.swift` linker settings |
| **Carbon** | Linked framework (minimal; used for HIToolbox key code constants) | `Package.swift` linker settings |
| **QuartzCore** | CACurrentMediaTime() for latency measurement | `AudioEngine.swift` |
| **os.log** | Unified logging (Logger subsystem: `com.keypulse.app`) | All source files |

### Indirect System Access

| Capability | Mechanism | Component |
|------------|-----------|-----------|
| Global keyboard hook | CGEventTap (listen-only mode) | `KeyboardMonitor.swift` |
| Low-latency audio playback | AVAudioEngine + pre-loaded PCM buffers | `AudioEngine.swift` |
| App visibility | LSUIElement = true (no Dock icon) | `Info.plist` |
| Accessibility permissions | AXIsProcessTrustedWithOptions() | `KeyboardMonitor.swift` |
| System sleep/wake | NSWorkspace.didWakeNotification | `KeyboardMonitor.swift` |

---

## External Dependencies

**None.** The project uses zero third-party packages or libraries. All dependencies are Apple system frameworks.

---

## Project Structure

```
KeyPulse/
├── Package.swift                            # SPM manifest (swift-tools-version:5.9)
├── Info.plist                               # Bundle metadata, LSUIElement, accessibility prompt
├── KeyPulse.entitlements                    # Hardened Runtime entitlements (minimal)
├── ExportOptions.plist                       # App Store Connect export configuration
├── Sources/KeyPulse/
│   ├── KeyPulse.swift                       # @main entry point, NSApplication delegate setup
│   ├── KeyPulseAppDelegate.swift            # NSApplicationDelegate, lifecycle, wiring
│   ├── KeyPulseController.swift             # Central orchestrator (ObservableObject)
│   ├── AudioEngine.swift                    # AVAudioEngine wrapper, buffer management, pitch
│   ├── KeyboardMonitor.swift                # CGEventTap wrapper, permission handling, wake
│   ├── MenuBarManager.swift                 # NSStatusItem, NSMenu, all menu actions
│   ├── SettingsStore.swift                  # UserDefaults wrapper, SMAppService, schema migration
│   ├── SoundAssets.swift                    # SoundProfile enum, WAV asset URL resolution
│   ├── Logging.swift                        # Logger extensions per subsystem category
│   ├── DiagnosticsData.swift                # Diagnostic struct (Equatable) for debug UI
│   ├── DebugWindowController.swift          # NSWindow + NSHostingController<DebugView>
│   ├── PreferencesWindowController.swift    # NSWindow + NSHostingController<PreferencesView>
│   └── Resources/
│       └── Sounds/
│           ├── CREDITS.md                   # Sound asset documentation
│           ├── linear/                      # 4 WAV files (60ms, PCM 16-bit mono 44.1kHz)
│           ├── tactile/                     # 4 WAV files (70ms, PCM 16-bit mono 44.1kHz)
│           └── clicky/                      # 4 WAV files (80ms, PCM 16-bit mono 44.1kHz)
└── Tests/
    └── KeyPulseTests/
        ├── KeyPulseTests.swift              # Main test suite
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
        ├── SettingsStoreIsolationTest.swift
        ├── SettingsStorePerformanceTest.swift
        └── SettingsStoreTestExecutionTest.swift
```

---

## Configuration Files

| File | Purpose |
|------|---------|
| `KeyPulse/Package.swift` | SPM manifest; defines executable target, resources, linked frameworks |
| `KeyPulse/Info.plist` | Bundle ID (`com.keypulse.app`), version (`0.1.0` / build `1`), LSUIElement, accessibility usage description |
| `KeyPulse/KeyPulse.entitlements` | Hardened Runtime entitlements; minimal — JIT enabled, no networking, no file-system special access |
| `KeyPulse/ExportOptions.plist` | App Store Connect export config (manual signing, Apple Distribution cert, team ID placeholder) |
| `justfile` | Build/test/run/bundle command recipes |
| `prek.toml` | Pre-commit hook definitions |
| `KeyPulse/.gitignore` | Excludes `.build`, Xcode user data, DerivedData |

---

## Entitlements Summary

| Entitlement | Value | Notes |
|-------------|-------|-------|
| `com.apple.security.cs.allow-jit` | `false` | Required for hardened runtime; not using JIT |
| `com.apple.security.network.client` | `false` | No network access needed |
| `com.apple.security.network.server` | `false` | No network server |
| `com.apple.security.files.user-selected.read-only` | `false` | Only reads bundled resources |

Accessibility permission is NOT an entitlement — it is handled at runtime via `AXIsProcessTrustedWithOptions()` and `NSAccessibilityUsageDescription` in Info.plist.

---

## Version Information

| Component | Version |
|-----------|---------|
| Swift Tools | 5.9 |
| macOS Target | 13.0 |
| App Version | 0.1.0 |
| Build Number | 1 |
| Bundle Identifier | com.keypulse.app |

---

## Testing Framework

- **Framework**: XCTest (bundled with Swift toolchain)
- **Test Target**: `KeyPulseTests` depends on `KeyPulse`
- **Test count**: 20 test files covering:
  - Audio engine configuration and performance
  - Keyboard monitor resilience
  - Settings store isolation and performance
  - Latency, buffer conversion, dispatch, pitch randomization
  - Menu bar manager unit tests
  - Profile loading/switch performance
