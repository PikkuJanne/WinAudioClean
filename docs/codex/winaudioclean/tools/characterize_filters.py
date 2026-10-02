#!/usr/bin/env python3
"""Direct-FFmpeg synthetic characterization; NOT a test of the PowerShell tool.

Reads the exact reviewed filter strings from BASELINE.json. Runs four safe,
non-overwriting FFmpeg commands on newly generated synthetic audio. No uploads.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys
from generate_fixtures import write_pcm


def executable(value: str) -> str:
    found = shutil.which(value)
    if not found:
        raise ValueError(f'Executable not found: {value}')
    return found


def run(args: list[str], timeout: int = 90) -> subprocess.CompletedProcess:
    result = subprocess.run(args, capture_output=True, text=True, encoding='utf-8',
                            errors='replace', timeout=timeout, check=False, shell=False)
    if result.returncode:
        raise RuntimeError(f'{Path(args[0]).name} failed: exit {result.returncode}: {result.stderr[-1500:]}')
    return result


def probe(ffprobe: str, path: Path) -> dict:
    data = json.loads(run([ffprobe, '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)]).stdout)
    streams = [s for s in data.get('streams', []) if s.get('codec_type') == 'audio']
    if len(streams) != 1:
        raise ValueError('Expected exactly one audio stream in characterization output.')
    s = streams[0]
    return {'file': path.name, 'sample_rate': int(s['sample_rate']), 'channels': s['channels'],
            'codec': s['codec_name'], 'bits_per_sample': s.get('bits_per_sample'),
            'duration_seconds': float(data['format']['duration']), 'bytes': path.stat().st_size}


def characterize(output: Path, ffmpeg: str, ffprobe: str, baseline_path: Path) -> dict:
    ffmpeg, ffprobe = executable(ffmpeg), executable(ffprobe)
    baseline = json.loads(baseline_path.read_text(encoding='utf-8'))
    output.mkdir(parents=True, exist_ok=False)
    inp = output / 'synthetic_stereo_48k.wav'
    fixture = write_pcm(inp, rate=48000, channels=2, seconds=8.0, kind='varying_tones')
    filters = baseline['filters']
    chains = {'raw': filters['raw_clean'] + ',' + filters['level'], 'zoom': filters['level']}
    records = []
    for mode, chain in chains.items():
        for explicit in (False, True):
            label = f'{mode}_' + ('explicit_48k_pcm16' if explicit else 'legacy_unspecified_output')
            path = output / (label + '.wav')
            args = [ffmpeg, '-nostdin', '-n', '-hide_banner', '-v', 'error', '-i', str(inp), '-vn', '-af', chain]
            if explicit:
                args += ['-ar', '48000', '-c:a', 'pcm_s16le']
            args += [str(path)]
            process = run(args)
            record = {'label': label, 'mode': mode, 'exit_code': process.returncode,
                      'filter_chain': chain,
                      'argv': [Path(a).name if a in {ffmpeg, str(inp), str(path)} else a for a in args],
                      'stderr': process.stderr, 'output': probe(ffprobe, path)}
            records.append(record)
    result = {'schema_version': 1, 'reviewed_commit': baseline['reviewed_commit'],
              'environment': {'os': platform.system(), 'architecture': platform.machine(),
                              'python': platform.python_version(),
                              'ffmpeg': run([ffmpeg, '-version']).stdout.splitlines()[0],
                              'ffprobe': run([ffprobe, '-version']).stdout.splitlines()[0]},
              'scope': 'Direct FFmpeg filters on synthetic tones only. No PowerShell/.bat execution or speech listening test.',
              'fixture': fixture, 'input': probe(ffprobe, inp), 'runs': records}
    (output / 'characterization.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ffmpeg', default='ffmpeg')
    parser.add_argument('--ffprobe', default='ffprobe')
    parser.add_argument('--baseline', type=Path, default=Path(__file__).resolve().parents[1] / 'BASELINE.json')
    args = parser.parse_args(argv)
    try:
        result = characterize(args.output, args.ffmpeg, args.ffprobe, args.baseline)
        print(json.dumps({'environment': result['environment'], 'input': result['input'],
                          'outputs': [r['output'] for r in result['runs']]}, indent=2))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
