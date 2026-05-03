<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/logo.svg">
    <img src="docs/logo.svg" width="160" alt="KeyPulse Logo" style="max-width: 100%;">
  </picture>
</p>

# 🎹 KeyPulse

> Make any keyboard feel satisfying.

[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?logo=swift)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13+-000000?logo=macos)](https://developer.apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A lightweight macOS menu bar app that plays low-latency mechanical keyboard sounds for every keystroke — no extra hardware, no noise in shared offices.

## ✨ Features

- ⚡ Real-time keystroke sounds with < 20ms latency
- 🔊 3 sound profiles: Linear, Tactile, Clicky
- 🎚️ Volume slider with mute toggle
- 🎲 Pitch randomization for natural feel
- 📱 System-wide global hook (works in any app)
- 🍎 Native menu bar UI (no Dock icon)
- 💾 Persisted settings across sessions
- 🚀 Launch at login

## 📦 Installation

### Download (Coming Soon)

KeyPulse will be available on the [App Store](https://apps.apple.com) and as a notarized DMG.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/jellydn/keypulse.git
cd keypulse

# Build release binary
just release

# Or build app bundle
just bundle
```

## 🚀 Usage

1. **Install** the app
2. **Launch** — you'll see the 🎹 icon in the menu bar
3. **Pick a profile** — Linear, Tactile, or Clicky
4. **Just type** — hear satisfying mechanical sounds with every keystroke

> ⚠️ **Accessibility Permission Required**: KeyPulse needs permission to monitor keyboard events. You'll be prompted on first launch — grant access in System Settings → Privacy & Security → Accessibility.

### Keyboard Shortcuts

| Shortcut    | Action                           |
| ----------- | -------------------------------- |
| `Cmd+Opt+D` | Toggle Debug Window              |
| —           | Click menu bar icon for settings |

### Debug Window

The Debug Window provides real-time diagnostics for testing and verification:

- **Keystroke Stats**: Total count, last key code, modifier detection
- **Profile & Sample**: Active profile, last sample played
- **Latency Metrics**: Average/min/max with PASS/FAIL indicator (<20ms target)
- **Modifier Flags**: Live state of Shift, Command, Option, Control
- **Settings**: Volume, mute state, pitch variation
- **Actions**: Test Sound, Test All Profiles, Reset Stats, Copy Diagnostics

![Debug Window](docs/debug-window-screenshot.png)

## 🛠️ Development

```bash
# Install dependencies and build
just build

# Run tests
just test

# Run locally (requires accessibility permission)
just run

# Format code
just fmt

# Show all available commands
just
```

### Requirements

- macOS 13+
- Xcode 15+ / Swift 5.9+
- [just](https://github.com/casey/just) command runner

### Project Structure

```
KeyPulse/
├── Sources/KeyPulse/
│   ├── KeyPulse.swift           # App entry point
│   ├── KeyPulseAppDelegate.swift# App lifecycle
│   ├── KeyPulseController.swift # Main controller
│   ├── AudioEngine.swift        # Low-latency audio
│   ├── KeyboardMonitor.swift    # CGEventTap hook
│   ├── MenuBarManager.swift      # Menu bar UI
│   ├── SettingsStore.swift       # UserDefaults persistence
│   └── SoundAssets.swift        # Sound profile definitions
├── Resources/Sounds/            # WAV assets (linear/tactile/clicky)
└── Tests/KeyPulseTests/         # Unit tests
```

### Tech Stack

- **Platform**: macOS 13+, Swift 5.9+, SwiftPM
- **Audio**: `AVAudioEngine` + pre-loaded `AVAudioPCMBuffer`
- **Input**: `CGEventTap` (global keyboard hook)
- **Persistence**: `UserDefaults`
- **Build**: `just` command runner

## 🤖 Building with Ralph

This repo uses [Ralph](https://github.com/jellydn/ralph) — an autonomous agent loop that implements user stories from `scripts/ralph/prd.json`.

```bash
# Run one iteration
./scripts/ralph/ralph.sh --once

# Run loop until complete
./scripts/ralph/ralph.sh
```

## 🧪 TestFlight Distribution

See [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md) for detailed instructions on:

- Code signing setup
- Building release archives
- Uploading to App Store Connect
- Adding internal testers

Quick build:

```bash
./scripts/build-release.sh 0.1.0 1
```

## 📋 Roadmap

| Feature                   | Status     |
| ------------------------- | ---------- |
| MVP with 3 sound profiles | ✅ Done    |
| Launch at login           | ✅ Done    |
| Pitch randomization       | ✅ Done    |
| Per-app profiles          | 🚧 Planned |
| Custom sound packs        | 🚧 Planned |
| Windows port              | 🔮 Future  |

## ⚠️ Known Issues

- Accessibility permission must be granted manually in System Settings
- Some apps with secure input fields may block keystroke detection

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

Sound assets are bundled under compatible licenses (CC0 or owner-licensed).

## 🙏 Acknowledgments

- Inspired by the tactile joy of mechanical keyboards
- Built with [Ralph](https://github.com/jellydn/ralph) autonomous development
- Thanks to all beta testers and contributors

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/jellydn">@jellydn</a>
</p>
