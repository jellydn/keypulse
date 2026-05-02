#!/usr/bin/env python3
"""
Generate realistic mechanical keyboard sounds for KeyPulse.

Creates distinct sound profiles:
- Linear: Soft, smooth thock (low frequency, short decay)
- Tactile: Medium bump with soft click (mid frequency, moderate decay)
- Clicky: Sharp, crisp click (high frequency with audible click)

All sounds: 44.1kHz, 16-bit, mono, <100ms
"""

import struct
import os
import math
import random


def save_wav(filepath, samples, sample_rate=44100):
    """Save samples as a 16-bit mono WAV file."""
    num_samples = len(samples)

    # Convert float samples (-1.0 to 1.0) to 16-bit integers
    int_samples = [int(max(-1.0, min(1.0, s)) * 32767) for s in samples]

    # WAV header
    riff = b"RIFF"
    file_size = 36 + num_samples * 2  # header + data
    wave = b"WAVE"

    # fmt chunk
    fmt = b"fmt "
    subchunk1_size = 16
    audio_format = 1  # PCM
    num_channels = 1
    byte_rate = sample_rate * num_channels * 2  # 16-bit
    block_align = num_channels * 2
    bits_per_sample = 16

    # data chunk
    data = b"data"
    subchunk2_size = num_samples * 2

    with open(filepath, "wb") as f:
        # Write RIFF header
        f.write(riff)
        f.write(struct.pack("<I", file_size))
        f.write(wave)

        # Write fmt chunk
        f.write(fmt)
        f.write(struct.pack("<I", subchunk1_size))
        f.write(struct.pack("<H", audio_format))
        f.write(struct.pack("<H", num_channels))
        f.write(struct.pack("<I", sample_rate))
        f.write(struct.pack("<I", byte_rate))
        f.write(struct.pack("<H", block_align))
        f.write(struct.pack("<H", bits_per_sample))

        # Write data chunk
        f.write(data)
        f.write(struct.pack("<I", subchunk2_size))

        # Write samples
        for sample in int_samples:
            f.write(struct.pack("<h", sample))

    duration_ms = (num_samples / sample_rate) * 1000
    print(f"Created: {filepath} ({duration_ms:.1f}ms, {sample_rate}Hz, 16-bit)")


def generate_linear_key(sample_rate=44100, duration_ms=60, variation=0):
    """
    Generate a linear switch sound - soft, smooth thock.
    Low frequency dominated, quick decay, no click.
    """
    num_samples = int(sample_rate * duration_ms / 1000)
    samples = []

    # Randomize slightly for variation
    base_freq = 180 + random.uniform(-20, 20) + (variation * 5)
    noise_amount = 0.15 + random.uniform(-0.05, 0.05)

    for i in range(num_samples):
        t = i / sample_rate
        progress = i / num_samples

        # Main thock - low frequency sine with harmonics
        thock = math.sin(2 * math.pi * base_freq * t)
        thock += 0.3 * math.sin(2 * math.pi * base_freq * 2 * t)  # 2nd harmonic
        thock += 0.15 * math.sin(2 * math.pi * base_freq * 3 * t)  # 3rd harmonic

        # Add some filtered noise for texture (lowpass character)
        noise = random.uniform(-1, 1) * noise_amount

        # Exponential decay envelope (fast attack, medium decay)
        attack_samples = int(0.02 * num_samples)  # 2% attack
        if i < attack_samples:
            envelope = i / attack_samples
        else:
            decay_progress = (i - attack_samples) / (num_samples - attack_samples)
            envelope = math.exp(-decay_progress * 4)

        sample = (thock * 0.7 + noise * 0.3) * envelope
        samples.append(sample)

    # Normalize
    max_val = max(abs(s) for s in samples) if samples else 1
    if max_val > 0:
        samples = [s / max_val * 0.9 for s in samples]

    return samples


def generate_tactile_key(sample_rate=44100, duration_ms=70, variation=0):
    """
    Generate a tactile switch sound - bump feedback with soft click.
    Mid frequency with a distinct "bump" in the envelope.
    """
    num_samples = int(sample_rate * duration_ms / 1000)
    samples = []

    base_freq = 280 + random.uniform(-25, 25) + (variation * 8)
    noise_amount = 0.2 + random.uniform(-0.05, 0.05)

    # Tactile bump position (around 30% into the sound)
    bump_position = 0.3 + random.uniform(-0.05, 0.05)
    bump_samples = int(num_samples * bump_position)

    for i in range(num_samples):
        t = i / sample_rate
        progress = i / num_samples

        # Main tone - mid frequency
        tone = math.sin(2 * math.pi * base_freq * t)
        tone += 0.4 * math.sin(2 * math.pi * base_freq * 1.5 * t)
        tone += 0.2 * math.sin(2 * math.pi * base_freq * 2.5 * t)

        # Add some mid-high frequency content for the "bump"
        bump = 0.3 * math.sin(2 * math.pi * base_freq * 3 * t)

        # More pronounced noise for tactile feel
        noise = random.uniform(-1, 1) * noise_amount

        # Envelope with tactile bump
        attack_samples = int(0.01 * num_samples)
        if i < attack_samples:
            envelope = i / attack_samples
        else:
            decay_progress = (i - attack_samples) / (num_samples - attack_samples)
            # Add a bump in the envelope
            bump_envelope = (
                math.exp(-(((i - bump_samples) / (num_samples * 0.15)) ** 2)) * 0.3
            )
            envelope = math.exp(-decay_progress * 3.5) + bump_envelope
            envelope = min(1.0, envelope)

        sample = (tone * 0.6 + bump * 0.2 + noise * 0.4) * envelope
        samples.append(sample)

    max_val = max(abs(s) for s in samples) if samples else 1
    if max_val > 0:
        samples = [s / max_val * 0.9 for s in samples]

    return samples


def generate_clicky_key(sample_rate=44100, duration_ms=80, variation=0):
    """
    Generate a clicky switch sound - sharp, crisp click.
    High frequency content with distinct click and longer decay.
    """
    num_samples = int(sample_rate * duration_ms / 1000)
    samples = []

    base_freq = 450 + random.uniform(-30, 30) + (variation * 10)
    click_freq = 3500 + random.uniform(-200, 200)
    noise_amount = 0.25 + random.uniform(-0.05, 0.05)

    for i in range(num_samples):
        t = i / sample_rate
        progress = i / num_samples

        # Main click tone - higher frequency
        tone = math.sin(2 * math.pi * base_freq * t)
        tone += 0.5 * math.sin(2 * math.pi * base_freq * 1.7 * t)

        # Sharp click component (very high frequency burst at start)
        click_decay = math.exp(-progress * 15)
        click = math.sin(2 * math.pi * click_freq * t) * click_decay

        # More high-frequency noise for clickiness
        noise = random.uniform(-1, 1) * noise_amount

        # Sharp attack, medium-long decay
        attack_samples = int(0.005 * num_samples)  # Very fast attack
        if i < attack_samples:
            envelope = i / attack_samples
        else:
            decay_progress = (i - attack_samples) / (num_samples - attack_samples)
            envelope = math.exp(-decay_progress * 2.5)

        # Mix: more click and noise for clicky feel
        sample = (tone * 0.4 + click * 0.35 + noise * 0.4) * envelope
        samples.append(sample)

    max_val = max(abs(s) for s in samples) if samples else 1
    if max_val > 0:
        samples = [s / max_val * 0.95 for s in samples]

    return samples


def main():
    """Generate all sound assets for the 3 profiles."""
    random.seed(42)  # For reproducibility

    base_path = "/Users/huynhdung/src/tries/2026-05-02-key-pulse/KeyPulse/Sources/KeyPulse/Resources/Sounds"

    # Ensure directories exist
    for profile in ["linear", "tactile", "clicky"]:
        os.makedirs(os.path.join(base_path, profile), exist_ok=True)

    # Generate 4 variations for each profile
    for profile in ["linear", "tactile", "clicky"]:
        for i in range(1, 5):
            filepath = os.path.join(base_path, profile, f"{profile}_key_{i:02d}.wav")

            if profile == "linear":
                samples = generate_linear_key(variation=i - 1)
            elif profile == "tactile":
                samples = generate_tactile_key(variation=i - 1)
            else:  # clicky
                samples = generate_clicky_key(variation=i - 1)

            save_wav(filepath, samples)

    print("\nAll sound assets generated successfully!")
    print("\nProfiles:")
    print("  - Linear: Soft thock, low frequency (180-200Hz)")
    print("  - Tactile: Medium bump, mid frequency (255-305Hz)")
    print("  - Clicky: Sharp click, high frequency (420-480Hz + 3300-3700Hz click)")


if __name__ == "__main__":
    main()
