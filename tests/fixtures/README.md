# Synthetic audio baseline fixtures

The standard-library generator at
`docs/codex/winaudioclean/tools/generate_fixtures.py` creates deterministic
16-bit little-endian PCM WAV files in a **new** directory. It refuses an existing
directory or filename. No recordings or generated audio are committed.

| File | Rate | Channels | Duration | Signal |
| --- | --- | --- | --- | --- |
| `synthetic_stereo_48k.wav` | 48,000 Hz | 2 | 8 s | Changing amplitude; 220/330 Hz channel tones, 60 Hz hum and seeded noise |
| `input [mix] äö Å.wav` | 44,100 Hz | 1 | 3 s | Changing amplitude, hum and seeded noise; Unicode/spaces/brackets path |
| `silence.wav` | 48,000 Hz | 1 | 3 s | Digital silence |
| `very_short.wav` | 48,000 Hz | 1 | 0.2 s | Short changing-amplitude tone with hum/noise |
| `synthetic_stress.wav` | 48,000 Hz | 2 | 3 s | Saturated 180/320 Hz channel tones, seeded noise and half-second impulse assignments |

The random seed is 24680. Each generated `fixtures.json` records frame counts,
bytes and SHA256 hashes. The WAC-M0-03 run reports retain the measured fixture
and output identities for repeatability on the recorded tool build. Stereo
tones differ by channel; this suite does not establish channel isolation,
impulse alignment or speech quality.

Use `.wac-local/` for generated material. See [development commands](../README.md)
for the complete characterization, and the
[pending listening checklist](../../docs/codex/winaudioclean/evidence/WAC-M0-03-listening.md)
for owner-supplied speech. The PowerShell scripts beside this file are controlled
test doubles and process helpers; they are not audio samples.
