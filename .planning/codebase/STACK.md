# Technology Stack

**Analysis Date:** 2026-05-02

## Languages

**Primary:**
- Swift 5.9+ — All source code, app logic, tests

**Secondary:**
- XML — Property lists (`Info.plist`, `KeyPulse.entitlements`, `ExportOptions.plist`)
- Shell — Build script (`scripts/build-release.sh`), Ralph runner (`scripts/ralph/ralph.sh`)

## Runtime

**Environment:**
- macOS 13+ (Ventura and above) — Required by `Package.swift` platform declaration and `SMAppService.mainApp` API

**Package Manager:**
- Swift Package Manager (SwiftPM) — Defined in `KeyPulse/Package.swift`
- No `Package.resolved` or external dependencies — zero third-party packages

**Build Tool:**
- `just` — Task runner defined in `justfile` at project root
- `xcodebuild` — Used by `scripts/build-release.sh` for archive/export

## Frameworks

**Core (Apple System Frameworks):**
- `AppKit` — Menu bar UI (`NSStatusItem`, `NSMenu`, `NSMenuItem`), app lifecycle (`NSApplication`, `NSApplicationDelegate`)
- `AVFoundation` — Audio playback (`AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioPCMBuffer`, `AVAudioConverter`)
- `CoreGraphics` — Keyboard event monitoring (`CGEvent`, `CGEventTap`, `CGEventMask`)
- `Carbon` — Linked explicitly in `Package.swift`; provides `kVK_*` key code constants used alongside CGEventTap
- `ServiceManagement` — Launch-at-login (`SMAppService.mainApp.register()/unregister()`)
- `Foundation` — Core types (`UserDefaults`, `URL`, `FileManager`, `URLSession`)

**Testing:**
- `XCTest` — Unit testing framework (`KeyPulse/Tests/KeyPulseTests/KeyPulseTests.swift`)

**Build/Dev:**
- SwiftPM (`swift build`, `swift test`, `swift package`)
- `just` command runner (`justfile`)
- `swift-format` — Code formatting/linting (optional, not enforced in CI)

## Key Dependencies

**Critical:**
- No third-party dependencies — the project is self-contained with zero external packages

**Infrastructure:**
- None — the app is fully offline, no network calls

## Configuration

**Environment:**
- No `.env` files or environment variables required
- App runs as `LSUIElement` (no Dock icon), configured in `KeyPulse/Info.plist`
- Accessibility permission required at runtime (prompted via `AXIsProcessTrustedWithOptions`)

**Build:**
- `KeyPulse/Package.swift` — SwiftPM manifest (swift-tools-version:5.9)
- `KeyPulse/Info.plist` — App bundle configuration (bundle ID: `com.keypulse.app`, version `0.1.0`)
- `KeyPulse/KeyPulse.entitlements` — Hardened runtime entitlements (minimal: JIT disabled, no network, no file access)
- `KeyPulse/ExportOptions.plist` — App Store export configuration (manual signing, Upload destination)
- `KeyPulse/Sources/KeyPulse/Resources/Sounds/CREDITS.md` — Sound asset attribution

**Key Config Files:**
| File | Purpose |
|------|---------|
| `KeyPulse/Package.swift` | SwiftPM manifest, target definitions, linked frameworks |
| `KeyPulse/Info.plist` | Bundle ID, version, LSUIElement, accessibility description |
| `KeyPulse/KeyPulse.entitlements` | Hardened runtime entitlements |
| `KeyPulse/ExportOptions.plist` | App Store distribution signing config |
| `justfile` | Build/run/test task runner |
| `scripts/ralph/prd.json` | Product requirements / user stories |
| `scripts/ralph/ralph.sh` | Autonomous build loop runner |

## Platform Requirements

**Development:**
- macOS 13+ (Ventura+)
- Xcode 15+ with Swift 5.9+
- `just` command runner (optional, for task recipes)
- Accessibility permission required to test global keyboard monitoring

**Production:**
- macOS 13+ target deployment
- Notarized Apple Developer distribution
- Accessibility permission at runtime

## Audio Assets

**Sound Profiles (bundled WAV files):**
- `KeyPulse/Sources/KeyPulse/Resources/Sounds/linear/` — 4 samples (`linear_key_01.wav` – `linear_key_04.wav`)
- `KeyPulse/Sources/KeyPulse/Resources/Sounds/tactile/` — 4 samples (`tactile_key_01.wav` – `tactile_key_04.wav`)
- `KeyPulse/Sources/KeyPulse/Resources/Sounds/clicky/` — 4 samples (`clicky_key_01.wav` – `clicky_key_04.wav`)
- Total: 12 WAV files, 16-bit 44.1kHz, <100ms each

---

*Stack analysis: 2026-05-02*
