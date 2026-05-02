# 🎹 KeyPulse

> **Make any keyboard feel satisfying.**

A lightweight macOS menu bar app that plays low-latency mechanical keyboard
sounds for every keystroke — no extra hardware, no noise in shared offices.

This repo is the autonomous-build workspace driven by **Ralph** (`scripts/ralph/`).

---

## 🧩 Problem

Laptop and membrane keyboards lack tactile and auditory feedback, making typing
feel flat. Mechanical keyboards solve this physically, but are:

- 💸 Expensive
- 🔊 Noisy in shared environments
- 🎒 Not portable (especially for MacBook users)

## 💡 Solution

KeyPulse simulates the *feel* of mechanical typing through high-quality,
low-latency audio playback — system-wide, in any app.

---

## 🎯 Target Users

- Developers using MacBooks
- Writers and content creators
- Mechanical keyboard enthusiasts away from their boards
- Remote workers in quiet shared environments

## ✨ MVP Features

| Feature                     | Status   |
| --------------------------- | -------- |
| Real-time keystroke sound   | MVP      |
| 3 sound profiles (linear / tactile / clicky) | MVP |
| Volume slider + mute        | MVP      |
| System-wide global hook     | MVP      |
| Menu bar UI (no Dock icon)  | MVP      |
| Persisted settings          | MVP      |
| **Pitch randomization**     | MVP (selected nice-to-have) |
| Launch at login             | MVP      |
| Per-app profiles            | v2       |
| Custom sound packs          | v2       |
| Windows port                | v3       |

## ⚙️ User Flow

```diagram
╭─────────╮   ╭────────╮   ╭────────────────╮   ╭──────────╮
│ Install │──▶│ Launch │──▶│ Pick a profile │──▶│ Just type│
╰─────────╯   ╰────────╯   ╰────────────────╯   ╰────┬─────╯
                                                     │
                                                     ▼
                                              ╭─────────────╮
                                              │ Hear it 🎵  │
                                              ╰─────────────╯
```

## 🧱 Tech Stack

- **Platform:** macOS 13+ (native, Swift 5.9+)
- **Audio:** `AVAudioEngine` + pre-loaded `AVAudioPCMBuffer` (target latency < 20ms)
- **Input capture:** `CGEventTap` (Accessibility permission required)
- **Persistence:** `UserDefaults`
- **Distribution:** TestFlight beta → decide MAS vs. notarized DMG

## 📊 Success Metrics

- Time-to-first-sound after install: **< 30s**
- Daily active usage
- 7-day retention
- % of users with sound enabled after day 1

## 💰 Monetization

- **Free for now** — no login, no subscription
- Optional flat-price "support the dev" tier may be added later (TBD)

---

## 🤖 Building with Ralph

This repo uses [Ralph](https://github.com/jellydn/ralph) — an autonomous agent
loop that picks the next unfinished story from `scripts/ralph/prd.json`,
implements it, verifies it, and marks it done.

### Layout

```
scripts/ralph/
├── prd.json            # 12 user stories (US-001 … US-012)
├── progress.txt        # Iteration log written by ralph.sh
├── prompt-opencode.md  # Prompt template (OpenCode driver)
├── prompt-pi.md        # Prompt template (PI driver)
└── ralph.sh            # Loop runner
```

### Run a single iteration

```bash
cd scripts/ralph
./ralph.sh --once
```

### Run the loop until all stories pass

```bash
./ralph.sh
```

### Story plan (high-level)

| ID     | Title                                                    | Phase   |
| ------ | -------------------------------------------------------- | ------- |
| US-001 | Scaffold Swift macOS menu bar app                        | Setup   |
| US-002 | Bundle WAV sound assets for 3 profiles                   | Assets  |
| US-003 | Low-latency Core Audio playback engine                   | Engine  |
| US-004 | Global keyboard hook (CGEventTap + Accessibility prompt) | Engine  |
| US-005 | Wire keystrokes → audio playback                         | Engine  |
| US-006 | Sound-profile model + runtime switching                  | Engine  |
| US-007 | Volume control + mute                                    | Engine  |
| US-008 | Menu bar UI                                              | UI      |
| US-009 | Persist settings via `UserDefaults`                      | UI      |
| US-010 | Pitch randomization (selected nice-to-have)              | Polish  |
| US-011 | Launch at login + background polish                      | Polish  |
| US-012 | Signing, notarization, TestFlight build                  | Release |

Each story is sized to fit a single Ralph iteration (one fresh context window).

---

## ⚠️ Risks

- Perceived as a novelty rather than a daily tool
- Audio fatigue over long sessions → mitigated by pitch randomization
- Latency spikes degrade the core delight → strict < 20ms budget
- Accessibility-permission friction → handled with first-run prompt

## ✅ Definition of Done (MVP)

- [ ] User installs and hears sound within 30 seconds
- [ ] No noticeable lag during typing
- [ ] Stable across major apps (browser, IDE, editor)
- [ ] Runs unobtrusively in the background

---

## 📜 License

TBD — likely MIT for the source, with bundled samples under CC0 or owner-licensed.
