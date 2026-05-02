# KeyPulse

macOS menu bar app that plays mechanical keyboard sounds on every keystroke. Written in Swift, targets macOS 13+.

## Architecture

- **LSUIElement app** (no Dock icon, menu bar only) via `LSUIElement = YES` in Info.plist
- Core types: `AudioEngine` (AVAudioEngine + AVAudioPlayerNode), `KeyboardMonitor` (CGEventTap), `KeyPulseController` (wiring), `SettingsStore` (UserDefaults), `SoundProfile` enum
- Sound assets: `Resources/Sounds/{linear,tactile,clicky}/` — each profile has ≥4 WAV files (16-bit, 44.1kHz, <100ms)
- Bundle ID: `com.keypulse.app`

## Ralph Development Loop

This project uses [Ralph](scripts/ralph/) for autonomous agent-driven development.

- **PRD**: `scripts/ralph/prd.json` — defines user stories with priority order and `passes` flags
- **Progress**: `scripts/ralph/progress.txt` — append-only log; top has `## Codebase Patterns` section
- **Branch**: `ralph/keypulse-mvp` (from PRD `branchName`)
- **Commit format**: `feat: [Story ID] - [Story Title]` (e.g. `feat: US-001 - Scaffold Swift macOS menu bar app project`)
- **Completion signal**: `<promise>COMPLETE</promise>` in agent output stops the loop
- **One story per iteration**, highest-priority `passes: false` story first

Quality gates per story: typecheck → build → test pass before commit. Update PRD `passes: true` after commit.

## Build & Test

```
xcodebuild -scheme KeyPulse build
xcodebuild -scheme KeyPulse test
```

No npm/bun/pip — this is a pure Swift/Xcode project.

## Key Constraints

- Accessibility permission required at runtime (`AXIsProcessTrustedWithOptions`) for global keyboard hook
- `NSAccessibilityUsageDescription` must be in Info.plist
- Audio latency target: <20ms trigger-to-output (pre-load buffers into `AVAudioPCMBuffer`)
- Pitch randomization: ±5% via `AVAudioUnitTimePitch`
- Launch-at-login uses `SMAppService.mainApp` (macOS 13+ API, no LSSharedFileList)
