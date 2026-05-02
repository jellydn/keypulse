# Codebase Structure

**Analysis Date:** 2026-05-02

## Directory Layout

```
key-pulse/                               # Project root
├── KeyPulse/                            # SwiftPM package root
│   ├── Package.swift                    # SPM manifest (Swift 5.9+, macOS 13+)
│   ├── Info.plist                       # App metadata, LSUIElement, accessibility description
│   ├── KeyPulse.entitlements            # Hardened runtime entitlements
│   ├── ExportOptions.plist              # App Store export config
│   ├── .gitignore                       # SPM-specific gitignore
│   ├── Sources/KeyPulse/                # All app source code
│   │   ├── KeyPulse.swift               # @main entry point
│   │   ├── KeyPulseAppDelegate.swift    # App lifecycle & wiring
│   │   ├── KeyPulseController.swift     # Central mediator
│   │   ├── AudioEngine.swift            # Low-latency audio playback
│   │   ├── KeyboardMonitor.swift        # CGEventTap global hook
│   │   ├── MenuBarManager.swift         # NSStatusItem + NSMenu UI
│   │   ├── SettingsStore.swift          # UserDefaults persistence + SMAppService
│   │   ├── SoundAssets.swift            # SoundProfile enum & asset resolution
│   │   └── Resources/                  # Bundled assets
│   │       ├── Images/                  # (Empty - future use)
│   │       └── Sounds/                  # WAV sound files
│   │           ├── linear/              # Linear profile samples
│   │           │   ├── linear_key_01.wav
│   │           │   ├── linear_key_02.wav
│   │           │   ├── linear_key_03.wav
│   │           │   └── linear_key_04.wav
│   │           ├── tactile/             # Tactile profile samples
│   │           │   ├── tactile_key_01.wav
│   │           │   ├── tactile_key_02.wav
│   │           │   ├── tactile_key_03.wav
│   │           │   └── tactile_key_04.wav
│   │           ├── clicky/              # Clicky profile samples
│   │           │   ├── clicky_key_01.wav
│   │           │   ├── clicky_key_02.wav
│   │           │   ├── clicky_key_03.wav
│   │           │   └── clicky_key_04.wav
│   │           └── CREDITS.md           # Sound asset attribution
│   └── Tests/KeyPulseTests/            # Unit tests
│       └── KeyPulseTests.swift          # All test cases
├── scripts/                             # Build & automation
│   ├── build-release.sh                 # App Store release build script
│   └── ralph/                           # Autonomous dev agent
│       ├── prd.json                     # Product requirements
│       ├── ralph.sh                     # Loop runner
│       ├── progress.txt                 # Iteration log
│       ├── prompt-opencode.md           # Prompt template (OpenCode)
│       ├── prompt-pi.md                 # Prompt template (PI)
│       └── generate_sounds.py           # Sound generation scripts
├── .planning/codebase/                  # Codebase mapping docs
├── AGENTS.md                            # Agent guidelines
├── CLAUDE.md                            # Claude-specific instructions
├── README.md                            # Project documentation
├── justfile                             # Task runner recipes
├── LICENSE                              # MIT license
└── progress.md                          # Progress tracking
```

## Directory Purposes

**`KeyPulse/Sources/KeyPulse/`:**
- Purpose: All application source code (single target)
- Contains: 8 Swift files implementing the complete app
- Key files: `KeyPulseController.swift` (mediator), `AudioEngine.swift` (output), `KeyboardMonitor.swift` (input)

**`KeyPulse/Sources/KeyPulse/Resources/Sounds/`:**
- Purpose: WAV audio assets for 3 keyboard sound profiles
- Contains: 12 WAV files (4 per profile) + CREDITS.md attribution
- Key files: `{linear,tactile,clicky}_key_{01-04}.wav`

**`KeyPulse/Tests/KeyPulseTests/`:**
- Purpose: Unit tests for all components
- Contains: Single test file with ~50 test methods
- Key files: `KeyPulseTests.swift`

**`scripts/`:**
- Purpose: Build automation and autonomous development tooling
- Contains: `build-release.sh` for App Store distribution, `ralph/` agent loop
- Key files: `scripts/build-release.sh`

**`KeyPulse/`:**
- Purpose: Swift Package Manager package root
- Contains: `Package.swift`, `Info.plist`, entitlements, tests
- Key files: `Package.swift`, `Info.plist`, `KeyPulse.entitlements`

## Key File Locations

**Entry Points:**
- `KeyPulse/Sources/KeyPulse/KeyPulse.swift`: `@main` struct — app bootstrap
- `KeyPulse/Sources/KeyPulse/KeyPulseAppDelegate.swift`: `NSApplicationDelegate` — lifecycle & wiring

**Configuration:**
- `KeyPulse/Package.swift`: SPM manifest — targets, platforms, linked frameworks (Carbon, ServiceManagement)
- `KeyPulse/Info.plist`: App metadata — bundle ID (`com.keypulse.app`), `LSUIElement=true`, `NSAccessibilityUsageDescription`
- `KeyPulse/KeyPulse.entitlements`: Hardened runtime entitlements (minimal — no network, no mic, no file access)
- `KeyPulse/ExportOptions.plist`: App Store export configuration (team ID, signing)

**Core Logic:**
- `KeyPulse/Sources/KeyPulse/KeyPulseController.swift`: Central mediator — wires keyboard → audio, manages state
- `KeyPulse/Sources/KeyPulse/AudioEngine.swift`: Audio output — AVAudioEngine, 8 player nodes, buffer pool, pitch randomization
- `KeyPulse/Sources/KeyPulse/KeyboardMonitor.swift`: Input capture — CGEventTap listen-only, accessibility permission handling

**UI:**
- `KeyPulse/Sources/KeyPulse/MenuBarManager.swift`: Menu bar — NSStatusItem, NSMenu, programmatic icon, callback-driven actions

**Persistence:**
- `KeyPulse/Sources/KeyPulse/SettingsStore.swift`: UserDefaults singleton — `keypulse_` prefixed keys, launch-at-login via SMAppService

**Domain:**
- `KeyPulse/Sources/KeyPulse/SoundAssets.swift`: Sound profiles enum — `SoundProfile` (3 cases), `SoundAssets` (URL resolution via `Bundle.module`)

**Testing:**
- `KeyPulse/Tests/KeyPulseTests/KeyPulseTests.swift`: All unit tests — AudioEngine, KeyPulseController, SettingsStore, SoundAssets, SoundProfile

**Build:**
- `scripts/build-release.sh`: App Store release pipeline — archive, sign, export
- `justfile`: Task runner — build, test, release, clean, bundle, fmt, lint, deps

## Naming Conventions

**Source Files:**
- Pattern: `PascalCase.swift` — one primary type per file, filename matches the type
- Examples: `AudioEngine.swift` → `class AudioEngine`, `KeyboardMonitor.swift` → `class KeyboardMonitor`, `SoundAssets.swift` → `enum SoundAssets`

**Sound Assets:**
- Pattern: `{profile}_key_{NN}.wav` — profile name + sequential two-digit number
- Examples: `linear_key_01.wav`, `tactile_key_03.wav`, `clicky_key_04.wav`
- Rule: Filenames must be unique across all resource directories because SwiftPM flattens the resource bundle (no subdirectory hierarchy preserved)

**Test Files:**
- Pattern: `{ModuleName}Tests.swift` — single test file per module
- Examples: `KeyPulseTests.swift`

**Directories:**
- Pattern: `PascalCase/` for source directories matching module names
- Examples: `KeyPulse/`, `KeyPulseTests/`

**UserDefault Keys:**
- Pattern: `keypulse_{propertyName}` — all lowercase, prefixed with bundle ID
- Examples: `keypulse_profile`, `keypulse_volume`, `keypulse_isMuted`

**Bundle Identifier:**
- `com.keypulse.app` — reverse-DNS style

## Where to Add New Code

**New Sound Profile:**
- Add case to `SoundProfile` enum in `KeyPulse/Sources/KeyPulse/SoundAssets.swift`
- Create new directory `KeyPulse/Sources/KeyPulse/Resources/Sounds/{profile}/` with 4+ WAV files named `{profile}_key_{NN}.wav`
- Update `SoundProfile.allCases` is automatic (enum conformance)
- Add menu item in `MenuBarManager.buildMenu()` (or the profile loop handles it if using `SoundProfile.allCases`)
- Test: Add profile loading test in `KeyPulseTests.swift`

**New User Setting:**
- Add key to `SettingsStore.Keys` private enum in `KeyPulse/Sources/KeyPulse/SettingsStore.swift`
- Add default to `SettingsStore.Defaults` private enum
- Add computed property with getter/setter using `UserDefaults.standard`
- Add `saveFromController` / `applyToController` logic
- Add menu item in `MenuBarManager.swift` + callback
- Add callback wiring in `KeyPulseAppDelegate.setupMenuBar()`

**New Feature Module:**
- Implementation: Add new Swift file in `KeyPulse/Sources/KeyPulse/`
- Wire into `KeyPulseController` or `KeyPulseAppDelegate` as appropriate
- Tests: Add test methods in `KeyPulse/Tests/KeyPulseTests/KeyPulseTests.swift`

**Utility/Helper:**
- Shared helpers go directly in `KeyPulse/Sources/KeyPulse/` (flat structure, no submodules)

## Special Directories

**`KeyPulse/Sources/KeyPulse/Resources/Sounds/`:**
- Purpose: Bundled WAV audio assets loaded at runtime via `Bundle.module`
- Generated: No (manually created and committed)
- Committed: Yes
- Note: SwiftPM flattens this directory — all filenames must be globally unique

**`KeyPulse/Sources/KeyPulse/Resources/Images/`:**
- Purpose: Placeholder for future image assets (currently empty)
- Generated: No
- Committed: Yes (empty directory)

**`KeyPulse/.build/`:**
- Purpose: SPM build artifacts
- Generated: Yes
- Committed: No (in `.gitignore`)

**`scripts/ralph/`:**
- Purpose: Autonomous development agent (Ralph) for iterative story implementation
- Generated: No
- Committed: Yes
- Note: Contains PRD, progress log, and prompt templates

**`.planning/codebase/`:**
- Purpose: Codebase mapping documentation (7 structured MD files)
- Generated: Yes (by codemap skill)
- Committed: TBD

---

*Structure analysis: 2026-05-02*
