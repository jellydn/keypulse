# Deferred Optimizations from Autoresearch Session

## Performance Optimizations Completed ✅

| Optimization | Metric | Baseline | Result | Commit |
|--------------|--------|----------|--------|--------|
| NSLock → os_unfair_lock | lock_acquire_µs | 0.104 | 0.099 (~5%) | - |
| SMAppService status cache | status_read_µs | 7,242 | 0.33 (~22,000x) | 39c12ce |
| Pre-warmed audio profiles | profile_switch_ms | 0.63 | 0 (~100%) | 0374fe0 |
| Keystroke dispatch baseline | keystroke_dispatch_ms | 0.04 | - | Baseline only |

**Audio latency**: 0.43 ms avg (well under 20ms target) - micro-optimizations showed no improvement.

## Attempted but Discarded ❌

| Optimization | Metric | Baseline | Result | Reason |
|--------------|--------|----------|--------|--------|
| Player nodes 8→6 | engine_startup_ms | 27.36 | 27.16 (~0.7%) | Negligible improvement |
| Remove redundant rate set | audio_latency_ms | 0.428 | 0.428 (0%) | No improvement |
| Remove isPlaying check | audio_latency_ms | 0.428 | 0.429 (0%) | No improvement |

## Baselines Established (No Action Needed) 📊

| Metric | Value | Assessment |
|--------|-------|------------|
| Keystroke dispatch | 40 µs | Negligible - not a bottleneck |
| Pitch randomization | 0.36 µs | Negligible - highly optimized |
| SettingsStore test | 0.43 ms | Fast - UserDefaults is lightweight |
| Audio latency | 0.43 ms avg | Target met (well under 20ms) |
| Profile load | 0.46 ms | Fast enough for current use |
| Engine startup | 27 ms | Dominated by AVAudioEngine init |

**Finding**: Engine startup time is dominated by AVAudioEngine initialization, not player node creation. The 10ms audio latency spikes are from AVAudioEngine thread scheduling, not Swift code. Test state pollution is a correctness concern, not a performance issue.

## Deferred Quality/Stability Improvements

### High Priority
1. **CGEventTap restart on failure** - Add `eventTapFailed` callback and `NSWorkspaceDidWakeNotification` observer
2. **Force unwrap fixes** - `KeyboardMonitor.swift:66` (URL), `MenuBarManager.swift` (menu items)
3. **print() → os.Logger** - Replace 20+ print statements with structured logging

### Medium Priority
4. **Error propagation to UI** - Show alerts for profile load failures
5. **SoundAssets validation** - Explicit error messages for missing resources
6. **MenuBarManager tests** - Zero test coverage currently

### Low Priority
7. **Carbon framework deprecation** - Replace with hardcoded key codes
8. **Settings schema versioning** - Add migration path for future settings changes

## Key Learnings

- DispatchQueue.main.async overhead is negligible (40 µs) - not a bottleneck
- The 10ms audio latency spikes are from AVAudioEngine thread scheduling, not Swift code
- Caching expensive IPC calls (SMAppService.status) yields massive improvements
- Pre-loading resources eliminates user-perceived latency
