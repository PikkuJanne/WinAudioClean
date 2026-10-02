#!/usr/bin/env python3
"""Direct-FFmpeg synthetic characterization; NOT a test of the PowerShell tool.

Reads exact reviewed filters from BASELINE.json and reuses all five mechanics
fixtures. Compares legacy WAV encoding with explicit 48 kHz PCM16 encoding.
Writes only to a new directory; no uploads or application runtime dependency.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
from generate_fixtures import generate


SAMPLE_METRIC_FILTER = ('astats=metadata=0:reset=0:measure_perchannel=none:'
                        'measure_overall=Peak_level+RMS_level')
LOUDNESS_METRIC_FILTER = 'loudnorm=I=-12:TP=-1.5:print_format=json'


def executable(value: str) -> str:
    found = shutil.which(value)
    if not found:
        raise ValueError(f'Executable not found: {Path(value).name}')
    return str(Path(found).resolve())


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def sanitize(text: str, paths: dict[str, str]) -> str:
    # Replace longer paths first so a parent cannot hide a known child path.
    replacements = dict(paths)
    replacements[str(Path.home())] = '<home>'
    for original, replacement in sorted(replacements.items(), key=lambda item: -len(item[0])):
        text = text.replace(original, replacement)
        text = text.replace(original.replace('\\', '/'), replacement)
    # FFmpeg filter addresses differ between otherwise identical executions.
    return re.sub(r'(?<= @ )[0-9a-fA-F]+(?=\])', '<address>', text)


def run(args: list[str], timeout: int = 90) -> subprocess.CompletedProcess:
    result = subprocess.run(args, capture_output=True, text=True, encoding='utf-8',
                            errors='replace', timeout=timeout, check=False, shell=False)
    if result.returncode:
        paths = {a: Path(a).name for a in args if Path(a).is_absolute()}
        detail = sanitize(result.stderr[-1500:], paths)
        raise RuntimeError(f'{Path(args[0]).name} failed: exit {result.returncode}: {detail}')
    return result


def recorded_run(args: list[str], paths: dict[str, str]) -> tuple[subprocess.CompletedProcess, dict]:
    process = run(args)
    command = {'argv': [sanitize(a, paths) for a in args], 'exit_code': process.returncode}
    return process, command


def probe(ffprobe: str, path: Path, paths: dict[str, str] | None = None) -> dict:
    paths = paths or {ffprobe: Path(ffprobe).name, str(path): path.name}
    process, command = recorded_run(
        [ffprobe, '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)], paths)
    data = json.loads(process.stdout)
    streams = [s for s in data.get('streams', []) if s.get('codec_type') == 'audio']
    if len(streams) != 1:
        raise ValueError('Expected exactly one audio stream in characterization output.')
    stream = streams[0]
    duration = float(data['format']['duration'])
    if not math.isfinite(duration) or duration <= 0:
        raise ValueError('Expected a finite, positive audio duration.')
    return {'file': sanitize(str(path), paths), 'sha256': digest(path),
            'sample_rate': int(stream['sample_rate']), 'channels': stream['channels'],
            'codec': stream['codec_name'], 'sample_format': stream.get('sample_fmt'),
            'bits_per_sample': stream.get('bits_per_sample'),
            'container': data['format']['format_name'],
            'duration_seconds': duration, 'bytes': path.stat().st_size, 'command': command}


def metric(value: object, unit: str) -> dict:
    if isinstance(value, bool) or not isinstance(value, (str, int, float)):
        raise ValueError('Expected a numeric audio metric.')
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError('Expected a numeric audio metric.') from exc
    if not math.isfinite(number):
        return {'value': None, 'unit': unit, 'status': 'unavailable',
                'reason': f'FFmpeg reported {value}; this metric is undefined or unmeasurable.'}
    return {'value': number, 'unit': unit, 'status': 'measured', 'reason': None}


def parse_metrics(stderr: str) -> dict:
    """Read final-file input metrics, never the discarded analysis render's output."""
    decoder = json.JSONDecoder()
    blocks = []
    for match in re.finditer(r'\{', stderr):
        try:
            candidate, _ = decoder.raw_decode(stderr[match.start():])
        except ValueError:
            continue
        if isinstance(candidate, dict) and 'input_i' in candidate:
            blocks.append(candidate)
    if len(blocks) != 1:
        raise ValueError('Expected exactly one loudnorm measurement JSON block.')
    loudness = blocks[0]
    fields = {'integrated_loudness': ('input_i', 'LUFS'),
              'true_peak': ('input_tp', 'dBTP'),
              'loudness_range': ('input_lra', 'LU'),
              'relative_threshold': ('input_thresh', 'LUFS')}
    result = {}
    for name, (key, unit) in fields.items():
        if key not in loudness:
            raise ValueError(f'Missing loudnorm metric: {key}')
        result[name] = metric(loudness[key], unit)
    for name, label in [('sample_peak', 'Peak level dB'), ('rms', 'RMS level dB')]:
        values = re.findall(r'\b' + label + r':\s*([^\s]+)', stderr)
        if len(values) != 1:
            raise ValueError(f'Expected exactly one overall astats metric: {label}')
        result[name] = metric(values[0], 'dBFS')
    return result


def measure(ffmpeg: str, path: Path, paths: dict[str, str]) -> dict:
    commands, measurements = {}, []
    # Separate graphs keep loudnorm's resampling out of sample peak/RMS analysis.
    for name, chain in [('sample_metrics', SAMPLE_METRIC_FILTER),
                        ('loudness_metrics', LOUDNESS_METRIC_FILTER)]:
        args = [ffmpeg, '-nostdin', '-hide_banner', '-nostats', '-v', 'info',
                '-i', str(path), '-vn', '-af', chain, '-f', 'null', '-']
        process, commands[name] = recorded_run(args, paths)
        measurements.append(process.stderr)
    return {'method': 'Independent astats overall sample peak/RMS and loudnorm input_* '
                      'analyses of final PCM file; analysis renders are discarded. '
                      'No target-compliance or listening claim.',
            'commands': commands, 'values': parse_metrics('\n'.join(measurements))}


def tool_record(tool: str, paths: dict[str, str]) -> dict:
    process, command = recorded_run([tool, '-version'], paths)
    version = process.stdout.strip()
    if not version:
        raise ValueError(f'{Path(tool).name} returned no version/build information.')
    return {'binary': Path(tool).name, 'sha256': digest(Path(tool)),
            'version_output': sanitize(version, paths),
            'version_output_sha256': hashlib.sha256(version.encode('utf-8')).hexdigest(),
            'command': command}


def characterize(output: Path, ffmpeg: str, ffprobe: str, baseline_path: Path) -> dict:
    ffmpeg, ffprobe = executable(ffmpeg), executable(ffprobe)
    baseline = json.loads(baseline_path.read_text(encoding='utf-8'))
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    paths = {ffmpeg: Path(ffmpeg).name, ffprobe: Path(ffprobe).name, str(output): '<output>'}
    tools = {'ffmpeg': tool_record(ffmpeg, paths), 'ffprobe': tool_record(ffprobe, paths)}
    generated = generate(output / 'fixtures')
    filters = baseline['filters']
    chains = {'raw': filters['raw_clean'] + ',' + filters['level'], 'zoom': filters['level']}
    fixtures, records = [], []
    for fixture in generated['fixtures']:
        inp = output / 'fixtures' / fixture['file']
        paths[str(inp)] = 'fixtures/' + inp.name
        fixtures.append({'generator': fixture, 'input': probe(ffprobe, inp, paths)})
        for mode, chain in chains.items():
            for explicit in (False, True):
                label = f'{mode}_' + ('explicit_48k_pcm16' if explicit else 'legacy_unspecified_output')
                path = output / (inp.stem + '__' + label + '.wav')
                paths[str(path)] = path.name
                args = [ffmpeg, '-nostdin', '-n', '-hide_banner', '-v', 'error',
                        '-i', str(inp), '-vn', '-af', chain]
                if explicit:
                    args += ['-ar', '48000', '-c:a', 'pcm_s16le']
                args += [str(path)]
                process, command = recorded_run(args, paths)
                records.append({'fixture': inp.name, 'label': label, 'mode': mode,
                                'filter_chain': chain, 'render': command,
                                'stderr': sanitize(process.stderr, paths),
                                'output': probe(ffprobe, path, paths),
                                'metrics': measure(ffmpeg, path, paths)})
    result = {'schema_version': 2, 'reviewed_commit': baseline['reviewed_commit'],
              'environment': {'os': platform.system(), 'os_version': platform.version(),
                              'architecture': platform.machine(), 'python': platform.python_version(),
                              **tools},
              'scope': 'Direct FFmpeg filters on five synthetic mechanics fixtures only. '
                       'No PowerShell/.bat execution, speech listening, or target-compliance test. '
                       'Legacy and explicit output encoding are separate comparisons.',
              'reproducibility': 'No timestamps or local paths. Compare the complete JSON reports '
                                 'from two new directories using the same tool binaries; investigate '
                                 'any difference, including hashes and metrics.',
              'fixtures': fixtures, 'runs': records}
    with (output / 'characterization.json').open('x', encoding='utf-8', newline='\n') as report:
        report.write(json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + '\n')
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
        print(json.dumps({'environment': result['environment'],
                          'inputs': [f['input'] for f in result['fixtures']],
                          'outputs': [r['output'] for r in result['runs']]}, indent=2))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
