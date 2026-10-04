#!/usr/bin/env python3
"""Generate synthetic PCM mechanics fixtures, never real speech; developer-only.

Writes only into a newly created output directory. Python is not an application
dependency. No network requests, downloads, private audio or third-party packages.
"""
from __future__ import annotations
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave


def write_pcm(path: Path, *, rate: int, channels: int, seconds: float, kind: str) -> dict:
    if path.exists():
        raise FileExistsError(f'Refusing to overwrite {path.name}')
    rng = random.Random(24680)
    samples = array('h')
    frame_count = round(rate * seconds)
    for i in range(frame_count):
        t = i / rate
        envelope = 0.10 + 0.35 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.45 * t))
        for channel in range(channels):
            if kind == 'silence':
                value = 0.0
            elif kind == 'stress':
                value = 1.25 * math.sin(2 * math.pi * (180 + 140 * channel) * t)
                value += (rng.random() - 0.5) * 0.03
                if i % (rate // 2) == 0:
                    value = 1.0
            else:
                value = envelope * math.sin(2 * math.pi * (220 + 110 * channel) * t)
                value += 0.025 * math.sin(2 * math.pi * 60 * t)
                value += (rng.random() - 0.5) * 0.006
            samples.append(max(-32768, min(32767, round(value * 32767))))
    if sys.byteorder != 'little':
        samples.byteswap()
    # Exclusive reservation ensures a same-name fixture cannot be overwritten.
    with path.open('xb') as target:
        with wave.open(target, 'wb') as w:
            w.setnchannels(channels)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(samples.tobytes())
    return {'file': path.name, 'sample_rate': rate, 'channels': channels,
            'frames': frame_count, 'seconds': seconds, 'kind': kind,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bytes': path.stat().st_size}


def generate(output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=False)
    definitions = [
        ('synthetic_stereo_48k.wav', 48000, 2, 8.0, 'varying_tones'),
        ('input [mix] äö Å.wav', 44100, 1, 3.0, 'varying_tones'),
        ('silence.wav', 48000, 1, 3.0, 'silence'),
        ('very_short.wav', 48000, 1, 0.2, 'varying_tones'),
        ('synthetic_stress.wav', 48000, 2, 3.0, 'stress')]
    records = [write_pcm(output / name, rate=rate, channels=channels, seconds=seconds, kind=kind)
               for name, rate, channels, seconds, kind in definitions]
    result = {'schema_version': 1,
              'notice': 'Synthetic tones/noise for mechanics only; no speech/listening acceptance.',
              'fixtures': records}
    (output / 'fixtures.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New directory; existing paths are refused.')
    args = parser.parse_args(argv)
    try:
        print(json.dumps(generate(args.output), indent=2, ensure_ascii=False))
        return 0
    except (OSError, ValueError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
