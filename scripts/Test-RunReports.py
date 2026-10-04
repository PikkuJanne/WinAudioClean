#!/usr/bin/env python3
"""Optional real Windows FFmpeg checks for structured local run reports.

Uses synthetic audio and already installed tools. Faults affect isolated copies
of the application only. No recordings, raw reports or diagnostics are uploaded.
"""

from __future__ import annotations

import argparse
import array
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import wave


FAULT_OVERRIDE = r'''
$script:WacRunReportOriginalNative = ${function:Invoke-WacNativeProcess}
function Invoke-WacNativeProcess {
    param([string]$FilePath, [string[]]$ArgumentList = @(),
        [int]$TimeoutMilliseconds = 0, [int]$StreamCloseTimeoutMilliseconds = 5000)
    $result = & $script:WacRunReportOriginalNative -FilePath $FilePath -ArgumentList $ArgumentList -TimeoutMilliseconds $TimeoutMilliseconds -StreamCloseTimeoutMilliseconds $StreamCloseTimeoutMilliseconds
    if ($ArgumentList -contains '-af' -and $result.ExitCode -eq 0) {
        $result.StandardOutput += "`nPRIVATE_STDOUT_TOKEN C:\PRIVATE_USER_TOKEN\PRIVATE_FILENAME_TOKEN.wav"
        $result.StandardError += "`nPRIVATE_STDERR_TOKEN title PRIVATE_TITLE_TOKEN"
        if ($env:WAC_REPORT_TEST_PROCESS -eq 'encoder') { $result.ExitCode = 17 }
        if ($env:WAC_REPORT_TEST_PROCESS -eq 'validation') {
            $partial = @($ArgumentList | Where-Object { $_ -match '\.wac-[a-fA-F0-9]{32}\.partial$' })
            if ($partial.Count -ne 1) { throw 'Harness expected exactly one owned partial.' }
            $stream = [IO.File]::Open($partial[0], [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
            try { $stream.SetLength([long]($stream.Length / 3)) } finally { $stream.Dispose() }
        }
    }
    $result
}
$script:WacRunReportOriginalOpen = ${function:Open-WacReportWriter}
function Open-WacReportWriter {
    param([string]$Path, [switch]$CreateNew, [int]$TimeoutMilliseconds = 3000)
    $leaf = [IO.Path]::GetFileName($Path)
    if (($env:WAC_REPORT_TEST_WRITE -eq 'json' -and $leaf.EndsWith('.json')) -or
        ($env:WAC_REPORT_TEST_WRITE -eq 'summary' -and $leaf -eq 'WinAudioClean_Log.txt')) {
        throw [UnauthorizedAccessException]::new('Injected report permission failure')
    }
    & $script:WacRunReportOriginalOpen -Path $Path -CreateNew:$CreateNew -TimeoutMilliseconds $TimeoutMilliseconds
}
$script:WacRunReportOriginalSet = ${function:Set-WacOwnedReportContent}
function Set-WacOwnedReportContent {
    param($Writer, [string]$Content)
    if ($env:WAC_REPORT_TEST_WRITE -eq 'text-write' -and $Writer.Path.EndsWith('.txt')) {
        & $script:WacRunReportOriginalSet -Writer $Writer -Content $Content.Substring(0, [int]($Content.Length / 2))
        throw [IO.IOException]::new('Injected report write/flush failure after partial write')
    }
    & $script:WacRunReportOriginalSet -Writer $Writer -Content $Content
}
$script:WacRunReportOriginalAdd = ${function:Add-WacSummaryReportContent}
function Add-WacSummaryReportContent {
    param($Writer, [string]$Content)
    if ($env:WAC_REPORT_TEST_WRITE -eq 'summary-write') {
        $null = & $script:WacRunReportOriginalAdd -Writer $Writer -Content $Content.Substring(0, [int]($Content.Length / 2))
        throw [IO.IOException]::new('Injected report write/flush failure after partial append')
    }
    & $script:WacRunReportOriginalAdd -Writer $Writer -Content $Content
}
'''


def sha256(path: Path) -> str:
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ffmpeg', type=Path, required=True)
    parser.add_argument('--ffprobe', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    runtime = [repo / 'WinAudioClean.ps1', repo / 'WinAudioClean.IO.ps1']
    ffmpeg, ffprobe = args.ffmpeg.resolve(strict=True), args.ffprobe.resolve(strict=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output = (args.output or repo / '.wac-local' / 'WAC-M1-06' / stamp).resolve()
    if not output.is_relative_to((repo / '.wac-local').resolve()):
        parser.error('--output must be inside this repository\'s .wac-local folder')
    output.mkdir(parents=True, exist_ok=False)
    replacements = [(str(repo), '<repo>'), (str(Path.home()), '<user-profile>')]

    def sanitize(value):
        if isinstance(value, str):
            for original, replacement in replacements:
                for variant in (original, original.replace('\\', '/'), original.replace('\\', '\\\\')):
                    value = value.replace(variant, replacement)
            return value
        if isinstance(value, dict):
            return {key: sanitize(item) for key, item in value.items()}
        if isinstance(value, list):
            return [sanitize(item) for item in value]
        return value

    clean_env = {key: value for key, value in os.environ.items() if key.upper() != 'PSMODULEPATH'}
    summary = {
        'task': 'WAC-M1-06', 'created_utc': stamp,
        'notice': 'Synthetic local report mechanics. Injected permission/native/validation failures use isolated application copies; no ACL/security changes, uploads, speech listening or real volume exhaustion.',
        'environment': {'platform': platform.platform(), 'python': platform.python_version(), 'child_psmodulepath_removed': True},
        'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
        'runtime_sha256_before': {path.name: sha256(path) for path in runtime},
        'harness_sha256': sha256(Path(__file__)), 'harness_invocation': sys.orig_argv,
        'tools': {name: {'path': str(path), 'sha256': sha256(path)} for name, path in [('ffmpeg', ffmpeg), ('ffprobe', ffprobe)]},
        'cases': [], 'commands': [],
    }

    def start(label, command, env=None):
        command = [str(item) for item in command]
        process = subprocess.Popen(command, cwd=repo, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, encoding='utf-8', errors='replace', env=env or clean_env)
        return label, command, process, dt.datetime.now(dt.timezone.utc)

    def finish(pending):
        label, command, process, started = pending
        timed_out = False
        try:
            stdout, stderr = process.communicate(timeout=120)
        except subprocess.TimeoutExpired:
            timed_out = True
            process.kill()
            stdout, stderr = process.communicate(timeout=10)
        result = {'id': label, 'command': command, 'exit_code': process.returncode, 'timed_out': timed_out,
                  'elapsed_seconds': round((dt.datetime.now(dt.timezone.utc) - started).total_seconds(), 3)}
        for name, value in [('stdout', stdout), ('stderr', stderr)]:
            path = output / f'{label}-{name}.txt'
            path.write_text(sanitize(value), encoding='utf-8')
            result[name + '_log'] = str(path.relative_to(repo))
            result[name + '_sha256'] = sha256(path)
        summary['commands'].append(result)
        return dict(result, stdout=stdout, stderr=stderr)

    def run(label, command, env=None):
        return finish(start(label, command, env))

    def checked(label, command):
        result = run(label, command)
        if result['exit_code'] != 0 or result['timed_out']:
            raise RuntimeError(f"{label} failed: {result['stderr']}")
        return result

    def add_case(case):
        summary['cases'].append(case)
        print(f"{case['id']}: {'PASS' if case['passed'] else 'FAIL'}", flush=True)

    def file_record(path):
        return {'path': str(path.relative_to(repo)), 'sha256': sha256(path)}

    def inspect_report(path, text_path, summary_path, expected_exit, expected_status, published):
        # Raw report content remains local. The committed evidence carries only
        # hashes and allowlisted numerical/status observations of these reports.
        report = json.loads(path.read_text(encoding='utf-8-sig'))
        text = text_path.read_text(encoding='utf-8-sig') if text_path.is_file() else ''
        combined = summary_path.read_text(encoding='utf-8-sig') if summary_path.is_file() else ''
        metric_results = {name: report['measurements'][name] == {'value': None, 'reason': 'not_measured'}
                          for name in ('integratedLufs', 'truePeakDbtp', 'loudnessRangeLu')}
        facts = {'json': file_record(path), 'text': file_record(text_path) if text_path.is_file() else None, 'schema_version': report.get('schemaVersion'),
                 'job_id': report.get('jobId'), 'status': report.get('status'), 'processing_status': report.get('processingStatus'),
                 'application_exit_code': report.get('applicationExitCode'), 'native_exit_code': report.get('nativeExitCode'),
                 'input_duration_seconds': report['input']['durationSeconds'],
                 'processing_elapsed_seconds': report['timing']['processingElapsedSeconds'],
                 'published': report['output']['published'], 'output_format': report['output']['format'],
                 'metrics_null_with_reason': metric_results, 'text_contiguous_in_summary': text.strip() in combined,
                 'native_stdout_retained': 'PRIVATE_STDOUT_TOKEN' in report['diagnostics']['standardOutput'],
                 'native_stderr_retained': 'PRIVATE_STDERR_TOKEN' in report['diagnostics']['standardError']}
        facts['passed'] = facts['schema_version'] == 1 and facts['status'] == expected_status and facts['application_exit_code'] == expected_exit
        facts['passed'] &= facts['processing_status'] == ('SUCCESS' if published else 'FAILED') and facts['published'] == published
        facts['passed'] &= facts['input_duration_seconds'] == 3.0 and isinstance(facts['processing_elapsed_seconds'], (int, float))
        facts['passed'] &= math.isfinite(facts['processing_elapsed_seconds']) and facts['processing_elapsed_seconds'] > 0
        facts['passed'] &= facts['processing_elapsed_seconds'] != facts['input_duration_seconds'] and all(metric_results.values())
        if text:
            facts['passed'] &= expected_status in text and str(expected_exit) in text and report['jobId'] in text
        return facts, report

    try:
        for name, tool in [('ffmpeg', ffmpeg), ('ffprobe', ffprobe)]:
            result = checked(name + '-version', [tool, '-version'])
            summary['tools'][name]['version'] = result['stdout'].splitlines()[0]
        fixture = output / 'PRIVATE_FILENAME_TOKEN.wav'
        values = array.array('h')
        for frame in range(3 * 48000):
            values.extend(round(5000 * math.sin(2 * math.pi * frequency * frame / 48000)) for frequency in (440, 880))
        if sys.byteorder != 'little':
            values.byteswap()
        with wave.open(str(fixture), 'wb') as wav:
            wav.setnchannels(2)
            wav.setsampwidth(2)
            wav.setframerate(48000)
            wav.writeframes(values.tobytes())
        summary['fixture'] = file_record(fixture)
        sandbox = output / 'fault-application'
        sandbox.mkdir()
        source = runtime[0].read_text(encoding='utf-8-sig')
        marker = '# --- CONFIGURATION ---'
        if source.count(marker) != 1:
            raise RuntimeError('Expected one configuration marker for the isolated test override')
        (sandbox / runtime[0].name).write_text(source.replace(marker, FAULT_OVERRIDE + '\n' + marker), encoding='utf-8-sig')
        shutil.copy2(runtime[1], sandbox / runtime[1].name)
        summary['fault_application'] = {'override_sha256': hashlib.sha256(FAULT_OVERRIDE.encode('utf-8')).hexdigest(),
                                        'files': [file_record(path) for path in sandbox.iterdir()],
                                        'seam': 'Actual render first, then override native result or truncate owned partial; report creation throws a controlled permission error.'}
        for shell_name, prefix in [('powershell.exe', 'ps51'), ('pwsh.exe', 'ps7')]:
            shell = shutil.which(shell_name)
            if shell is None:
                raise RuntimeError(f'Required shell not found: {shell_name}')
            result = checked(prefix + '-version', [shell, '-NoLogo', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()'])
            summary['environment'][prefix] = result['stdout'].strip()

            def command(destination, fault=True):
                return [shell, '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', sandbox / runtime[0].name if fault else runtime[0],
                        '-inputPath', fixture, '-OutputDirectory', destination, '-Mode', 'Raw', '-BitDepth', 24,
                        '-FfmpegPath', ffmpeg, '-FfprobePath', ffprobe, '-NonInteractive']

            def new_destination(label):
                destination = output / label
                destination.mkdir()
                shutil.copy2(fixture, destination / 'prior-export.wav')
                return destination

            for name, native_fault, report_fault, expected_exit, expected_status, published in [
                ('success', '', '', 0, 'SUCCESS', True),
                ('encoder', 'encoder', '', 4, 'FAILED', False),
                ('validation', 'validation', '', 5, 'FAILED', False),
                ('json-permission', '', 'json', 7, 'WARNING', True),
                ('summary-permission', '', 'summary', 7, 'WARNING', True),
                ('encoder-summary-permission', 'encoder', 'summary', 4, 'FAILED', False),
                ('validation-summary-permission', 'validation', 'summary', 5, 'FAILED', False),
                ('text-partial-write', '', 'text-write', 7, 'WARNING', True),
                ('summary-partial-write', '', 'summary-write', 7, 'WARNING', True),
                ('encoder-summary-partial-write', 'encoder', 'summary-write', 4, 'FAILED', False),
            ]:
                label = prefix + '-' + name
                destination = new_destination(label)
                if report_fault == 'summary-write':
                    (destination / 'WinAudioClean_Log.txt').write_text('PREVIOUS_SUMMARY_BYTES_MUST_SURVIVE', encoding='utf-8')
                env = dict(clean_env, WAC_REPORT_TEST_PROCESS=native_fault, WAC_REPORT_TEST_WRITE=report_fault)
                result = run(label, command(destination, fault=name != 'success'), env)
                json_files = list(destination.glob('WinAudioClean_*.json'))
                audio_files = list(destination.glob('*_Cleaned_*.wav'))
                case = {'id': label, 'expected_exit': expected_exit, 'exit_code': result['exit_code'], 'expected_status': expected_status,
                        'audio_count': len(audio_files), 'report_count': len(json_files), 'reports': [],
                        'source_unchanged': sha256(fixture) == summary['fixture']['sha256'],
                        'prior_unchanged': sha256(destination / 'prior-export.wav') == summary['fixture']['sha256'],
                        'partial_count': len(list(destination.glob('.wac-*.partial')))}
                case['passed'] = result['exit_code'] == expected_exit and not result['timed_out'] and f'DONE: {expected_status}' in result['stdout']
                case['passed'] &= case['source_unchanged'] and case['prior_unchanged'] and not case['partial_count'] and len(audio_files) == int(published)
                if not report_fault:
                    case['passed'] &= len(json_files) == 1
                elif report_fault != 'json':
                    case['passed'] &= len(json_files) == 1
                for path in json_files:
                    text_path = path.with_suffix('.txt')
                    facts, report = inspect_report(path, text_path, destination / 'WinAudioClean_Log.txt', expected_exit, expected_status, published)
                    if not report_fault:
                        facts['passed'] &= facts['text_contiguous_in_summary']
                    if native_fault:
                        facts['passed'] &= facts['native_stdout_retained'] and facts['native_stderr_retained']
                        facts['passed'] &= facts['native_exit_code'] == (17 if native_fault == 'encoder' else 0)
                    case['reports'].append(facts)
                    case['passed'] &= facts['passed']
                if published:
                    probe = json.loads(checked('probe-' + label, [ffprobe, '-v', 'error', '-show_streams', '-of', 'json', audio_files[0]])['stdout'])['streams'][0]
                    case['verified_audio'] = {key: probe.get(key) for key in ('codec_name', 'sample_rate', 'channels', 'bits_per_sample', 'duration')}
                    case['passed'] &= probe['codec_name'] == 'pcm_s24le' and probe['sample_rate'] == '48000' and probe['channels'] == 2 and float(probe['duration']) == 3.0
                    if name == 'success':
                        success_report_path = json_files[0]
                if report_fault:
                    case['passed'] &= 'Injected report' in result['stdout'] + result['stderr']
                    if report_fault == 'summary-write':
                        case['prior_summary_unchanged'] = (destination / 'WinAudioClean_Log.txt').read_text(encoding='utf-8') == 'PREVIOUS_SUMMARY_BYTES_MUST_SURVIVE'
                        case['passed'] &= case['prior_summary_unchanged']
                    text_files = list(destination.glob('WinAudioClean_*.txt'))
                    case['surviving_text_reports'] = [file_record(path) for path in text_files]
                    case['passed'] &= all('STATUS         : SUCCESS' not in path.read_text(encoding='utf-8-sig') for path in text_files)
                add_case(case)

            destination = new_destination(prefix + '-concurrent')
            pending = [start(prefix + f'-concurrent-{index}', command(destination, fault=False)) for index in (1, 2)]
            results = [finish(item) for item in pending]
            json_files = list(destination.glob('WinAudioClean_*.json'))
            report_facts = [inspect_report(path, path.with_suffix('.txt'), destination / 'WinAudioClean_Log.txt', 0, 'SUCCESS', True)[0] for path in json_files]
            add_case({'id': prefix + '-concurrent', 'exit_codes': [item['exit_code'] for item in results], 'reports': report_facts,
                      'passed': all(item['exit_code'] == 0 and not item['timed_out'] for item in results) and len(json_files) == 2
                      and len({item['job_id'] for item in report_facts}) == 2
                      and all(item['passed'] and item['text_contiguous_in_summary'] for item in report_facts)
                      and len(list(destination.glob('*_Cleaned_*.wav'))) == 2 and not list(destination.glob('.wac-*.partial'))
                      and sha256(destination / 'prior-export.wav') == summary['fixture']['sha256']})

            # Seed synthetic secrets in a local report copy to challenge the
            # allowlist, including unknown nested metadata and raw diagnostics.
            sensitive = output / (prefix + '-sensitive-local-report.json')
            report = json.loads(success_report_path.read_text(encoding='utf-8-sig'))
            report['input']['containerTitle'] = 'PRIVATE_CONTAINER_TITLE_TOKEN'
            report['input']['stream']['title'] = 'PRIVATE_STREAM_TITLE_TOKEN'
            report['toolVersion'] = 'PRIVATE_TOOL_VERSION_TOKEN'
            report['dependencies']['ffmpeg']['version'] = 'PRIVATE_FFMPEG_VERSION_TOKEN'
            report['dependencies']['ffprobe']['version'] = 'PRIVATE_FFPROBE_VERSION_TOKEN'
            report['settings']['exactFilters'] = 'PRIVATE_FILTER_TOKEN C:\\PRIVATE_USER_TOKEN\\filter.txt'
            report['diagnostics']['standardOutput'] = 'PRIVATE_STDOUT_TOKEN C:\\PRIVATE_USER_TOKEN\\PRIVATE_FILENAME_TOKEN.wav'
            report['diagnostics']['standardError'] = 'PRIVATE_STDERR_TOKEN secret=PRIVATE_SECRET_TOKEN'
            report['unknownPrivateField'] = {'path': 'C:\\PRIVATE_EXTRA_TOKEN', 'title': 'PRIVATE_TITLE_TOKEN'}
            sensitive.write_text(json.dumps(report, indent=2), encoding='utf-8')
            before = sha256(sensitive)
            redacted = output / (prefix + '-redacted.json')
            export_command = [shell, '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', runtime[0],
                              '-ExportDiagnostic', sensitive, '-DiagnosticOutputPath', redacted]
            exported = run(prefix + '-redact', export_command)
            raw = redacted.read_text(encoding='utf-8-sig') if redacted.is_file() else ''
            redacted_before = sha256(redacted) if redacted.is_file() else None
            repeated = run(prefix + '-redact-no-overwrite', export_command)
            add_case({'id': prefix + '-redaction', 'exit_code': exported['exit_code'], 'repeat_exit_code': repeated['exit_code'],
                      'raw_report': file_record(sensitive), 'redacted_report': file_record(redacted) if redacted.is_file() else None,
                      'raw_unchanged': sha256(sensitive) == before, 'redacted_unchanged_after_repeat': redacted.is_file() and sha256(redacted) == redacted_before,
                      'sensitive_tokens_absent': 'PRIVATE_' not in raw and str(repo) not in raw,
                      'passed': exported['exit_code'] == 0 and repeated['exit_code'] != 0 and redacted.is_file()
                      and sha256(sensitive) == before and sha256(redacted) == redacted_before
                      and 'PRIVATE_' not in raw and str(repo) not in raw
                      and ('review' in exported['stdout'].lower() or 'inspect' in exported['stdout'].lower())})

        if summary['runtime_sha256_before'] != {path.name: sha256(path) for path in runtime}:
            raise RuntimeError('Runtime changed during validation; rerun against stable source')
        if summary['harness_sha256'] != sha256(Path(__file__)):
            raise RuntimeError('Harness changed during validation; rerun against stable source')
        summary['status'] = 'pass' if all(case['passed'] for case in summary['cases']) else 'fail'
        return 0 if summary['status'] == 'pass' else 1
    except Exception as error:
        summary['status'] = 'error'
        summary['error'] = str(error)
        print(sanitize(str(error)), file=sys.stderr)
        return 1
    finally:
        summary['runtime_sha256_after'] = {path.name: sha256(path) for path in runtime}
        summary['runtime_unchanged_during_run'] = summary['runtime_sha256_before'] == summary['runtime_sha256_after']
        summary['harness_sha256_after'] = sha256(Path(__file__))
        summary['harness_unchanged_during_run'] = summary['harness_sha256'] == summary['harness_sha256_after']
        evidence = output / 'summary.json'
        evidence.write_text(json.dumps(sanitize(summary), indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        print(f'Evidence: {sanitize(str(evidence))}', flush=True)


if __name__ == '__main__':
    raise SystemExit(main())
