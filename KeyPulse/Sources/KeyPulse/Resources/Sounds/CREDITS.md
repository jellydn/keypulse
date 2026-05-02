# Sound Assets Credits

## Overview

KeyPulse includes 12 procedurally generated mechanical keyboard sound samples
distributed across three distinct sound profiles: Linear, Tactile, and Clicky.

## Generation Method

All sounds were programmatically generated using Python with the following
technical specifications:

- **Format**: WAV (RIFF/WAVE), PCM 16-bit, mono, 44.1kHz sample rate
- **Duration**: 60-80ms per sample (under the 100ms requirement)
- **Generation Date**: 2026-05-02
- **Generator Script**: `scripts/ralph/generate_real_sounds.py`

## Profile Characteristics

### Linear Profile (`linear/`)

4 variations of smooth, quiet linear switch sounds:

- **Frequency range**: 160-220 Hz (low frequency dominated)
- **Envelope**: Fast attack (2%), exponential decay
- **Character**: Soft "thock" sound with minimal noise
- **Harmonics**: Fundamental + 2nd/3rd harmonics for body
- **Duration**: 60ms each

### Tactile Profile (`tactile/`)

4 variations of tactile bump switch sounds:

- **Frequency range**: 255-305 Hz (mid frequency)
- **Envelope**: Fast attack (1%), decay with tactile bump at 30%
- **Character**: Distinct bump feedback with soft bottom-out
- **Harmonics**: Fundamental + 1.5x and 2.5x harmonics for texture
- **Duration**: 70ms each

### Clicky Profile (`clicky/`)

4 variations of crisp clicky switch sounds:

- **Frequency range**: 420-480 Hz + 3300-3700 Hz click component
- **Envelope**: Very fast attack (0.5%), medium-long decay
- **Character**: Sharp click with high-frequency transient
- **Harmonics**: Fundamental + 1.7x harmonic + high-frequency click burst
- **Duration**: 80ms each

## File Listing

```
Resources/Sounds/
├── linear/
│   ├── linear_key_01.wav
│   ├── linear_key_02.wav
│   ├── linear_key_03.wav
│   └── linear_key_04.wav
├── tactile/
│   ├── tactile_key_01.wav
│   ├── tactile_key_02.wav
│   ├── tactile_key_03.wav
│   └── tactile_key_04.wav
└── clicky/
    ├── clicky_key_01.wav
    ├── clicky_key_02.wav
    ├── clicky_key_03.wav
    └── clicky_key_04.wav
```

## License

All sound assets in this directory are:

**Creative Commons Zero (CC0) 1.0 Universal**

Created by the KeyPulse development team and dedicated to the public domain.
You can copy, modify, distribute, and use these sounds, even for commercial
purposes, without asking permission or providing attribution.

See: https://creativecommons.org/publicdomain/zero/1.0/

## Technical Details

### Synthesis Method

Each sound is synthesized using additive synthesis with the following components:

1. **Fundamental tone**: Sine wave at base frequency
2. **Harmonics**: Additional sine waves at harmonic multiples
3. **Noise component**: White noise for mechanical texture
4. **Click transient** (clicky only): High-frequency burst at note onset
5. **Envelope shaping**: Exponential decay with optional bump (tactile)

### Variation System

Each profile includes 4 variations with subtle randomized differences:

- Base frequency offset: ±20-30 Hz
- Noise amount: ±5%
- Decay rate: Slight variation per sample
- This ensures repeated keystrokes sound natural and non-repetitive

### MD5 Checksums (for verification)

```
Linear:
  linear_key_01.wav: 10f48c0aff0cd265d2127fae7fdecc42
  linear_key_02.wav: c5f212d5c3eb0531260ad856a529f4f7
  linear_key_03.wav: 0e9bc20e687310421c6b57d83ddd5424
  linear_key_04.wav: 433759c15e3d6d2077d1f90723c8be94

Tactile:
  tactile_key_01.wav: 07d8a436cdf5b829302b67deeed6c8b7
  tactile_key_02.wav: 79178702936d20f693aadc5055249fe5
  tactile_key_03.wav: 899d8fcaba32c27a4d7083a8ba2faa84
  tactile_key_04.wav: d2a9a2b231069406df326181a50037a6

Clicky:
  clicky_key_01.wav: 6e078d2c6fa498990a4e1e6a85cd9033
  clicky_key_02.wav: ff306b4fa254deba0631f8ec7caadd96
  clicky_key_03.wav: bc6a071ad2f344481fb8eb085dabb38c
  clicky_key_04.wav: 10d4f7528205d0bd7406b1fb89fbbef9
```

## Design Notes

The sound profiles were designed to represent three common mechanical keyboard
switch types:

1. **Linear** simulates switches like Cherry MX Red or Black - smooth travel
   with no tactile bump, preferred by gamers for rapid keypresses.

2. **Tactile** simulates switches like Cherry MX Brown - noticeable bump at
   actuation point without the audible click, preferred for typing accuracy.

3. **Clicky** simulates switches like Cherry MX Blue or Green - both tactile
   bump and audible click, satisfying feedback for typing enthusiasts.

These are approximations created through synthesis, not recordings of actual
switches, but they capture the essential acoustic characteristics of each type.
