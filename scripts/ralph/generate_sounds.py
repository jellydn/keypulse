#!/usr/bin/env python3
"""Generate minimal placeholder WAV files for KeyPulse sound profiles."""

import struct
import os


def create_wav_file(filepath, duration_ms=50, sample_rate=44100):
    """Create a minimal valid WAV file with silence."""
    num_samples = int(sample_rate * duration_ms / 1000)

    # WAV header
    # RIFF chunk
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

    # data chunk (silence - all zeros)
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

        # Write data chunk (silence)
        f.write(data)
        f.write(struct.pack("<I", subchunk2_size))
        f.write(b"\x00" * subchunk2_size)

    print(f"Created: {filepath} ({duration_ms}ms, {sample_rate}Hz, 16-bit)")


# Create sound files for each profile
base_path = "/Users/huynhdung/src/tries/2026-05-02-key-pulse/KeyPulse/Sources/KeyPulse/Resources/Sounds"

profiles = {
    "linear": ["key_01.wav", "key_02.wav", "key_03.wav", "key_04.wav"],
    "tactile": ["key_01.wav", "key_02.wav", "key_03.wav", "key_04.wav"],
    "clicky": ["key_01.wav", "key_02.wav", "key_03.wav", "key_04.wav"],
}

for profile, files in profiles.items():
    for filename in files:
        filepath = os.path.join(base_path, profile, filename)
        create_wav_file(filepath)

print("\nAll sound assets generated successfully!")
