#!/usr/bin/env python3
"""Optional real Windows FFmpeg checks for transactional output publication.

Uses Python's standard library and already installed FFmpeg/ffprobe. Synthetic
media, isolated fault-injection application copies and diagnostics remain in
.wac-local. No production test hook, download or machine setting is required.
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
import re
import shutil
import subprocess
import sys
import wave


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def measure_audio(path: Path, frequency: int, channels: int, tolerance: float = 0.01) -> dict:
    with wave.open(str(path), "rb") as wav:
        actual_channels, rate, width = wav.getnchannels(), wav.getframerate(), wav.getsampwidth()
        frames = wav.getnframes()
        wav.setpos(min(rate, frames // 3))
        values = array.array("h", wav.readframes(min(rate // 2, frames // 3)))
    if width != 2:
        raise ValueError(f"Expected unchanged PCM16 encoding, found sample width {width}")
    if sys.byteorder != "little":
        values.byteswap()
    measurements = []
    for channel in range(actual_channels):
        powers = {}
        for candidate in (440, 880):
            coefficient = 2 * math.cos(2 * math.pi * candidate / rate)
            previous = before_previous = 0.0
            for value in values[channel::actual_channels]:
                current = value + coefficient * previous - before_previous
                before_previous, previous = previous, current
            powers[candidate] = max(0.0, previous**2 + before_previous**2 - coefficient * previous * before_previous)
        other = 880 if frequency == 440 else 440
        measurements.append({"channel": channel, "dominant_hz": max(powers, key=powers.get),
                             "expected_to_other_power_ratio": round(powers[frequency] / max(powers[other], 1), 3)})
    duration = frames / rate
    return {"channels": actual_channels, "sample_rate": rate, "sample_width_bytes": width,
            "duration_seconds": duration, "duration_tolerance_seconds": tolerance, "frequencies": measurements,
            "passed": actual_channels == channels and abs(duration - 3.0) <= tolerance
                      and all(item["dominant_hz"] == frequency and item["expected_to_other_power_ratio"] > 100
                              for item in measurements)}


FAULT_OVERRIDE = r'''
# Development harness injection in an isolated application copy only. The real
# encoder runs first; this seam changes only its result or its owned output.
$script:WacHarnessOriginalNative = ${function:Invoke-WacNativeProcess}
function Invoke-WacNativeProcess {
    param([string]$FilePath, [string[]]$ArgumentList = @(),
        [int]$TimeoutMilliseconds = 0, [int]$StreamCloseTimeoutMilliseconds = 5000)
    $result = & $script:WacHarnessOriginalNative -FilePath $FilePath -ArgumentList $ArgumentList -TimeoutMilliseconds $TimeoutMilliseconds -StreamCloseTimeoutMilliseconds $StreamCloseTimeoutMilliseconds
    if ($ArgumentList -contains '-af' -and $result.ExitCode -eq 0) {
        $partial = @($ArgumentList | Where-Object { $_ -match '\.wac-[a-fA-F0-9]{32}\.partial$' })
        if ($partial.Count -ne 1) { throw 'Harness expected exactly one owned partial in render arguments.' }
        if ($env:WAC_TRANSACTION_FAULT -in @('empty', 'invalid', 'truncated')) {
            $stream = [IO.File]::Open($partial[0], [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
            try {
                if ($env:WAC_TRANSACTION_FAULT -eq 'empty') { $stream.SetLength(0) }
                elseif ($env:WAC_TRANSACTION_FAULT -eq 'truncated') { $stream.SetLength([long]($stream.Length / 3)) }
                else {
                    $bytes = [Text.Encoding]::ASCII.GetBytes('Not a WAV file: controlled validation failure.')
                    $stream.SetLength(0)
                    $stream.Write($bytes, 0, $bytes.Length)
                }
            } finally { $stream.Dispose() }
        } elseif ($env:WAC_TRANSACTION_FAULT -eq 'encoder') {
            $result.ExitCode = 17
            $result.StandardError += "`nControlled encoder failure after partial output."
        } elseif ($env:WAC_TRANSACTION_FAULT -eq 'disk-full') {
            $result.ExitCode = 28
            $result.StandardError += "`nControlled disk-full simulation: No space left on device."
        }
    }
    $result
}
$script:WacHarnessOriginalPublish = ${function:Publish-WacOutputTransaction}
function Publish-WacOutputTransaction {
    param($Transaction)
    if ($env:WAC_TRANSACTION_FAULT -eq 'crash') {
        # Exit terminates the owned application immediately, before rename and
        # without running its finally block; no error-reporting UI is opened.
        [Environment]::Exit(99)
    }
    if ($env:WAC_TRANSACTION_FAULT -eq 'rename-race') {
        $bytes = [Text.Encoding]::ASCII.GetBytes('Foreign file created after output name selection; preserve these bytes.')
        $stream = [IO.File]::Open($Transaction.FinalPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    }
    & $script:WacHarnessOriginalPublish -Transaction $Transaction
}
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--ffprobe", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    runtime = [repo / "WinAudioClean.ps1", repo / "WinAudioClean.IO.ps1"]
    ffmpeg, ffprobe = args.ffmpeg.resolve(strict=True), args.ffprobe.resolve(strict=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = (args.output or repo / ".wac-local" / "WAC-M1-04" / stamp).resolve()
    if not output.is_relative_to((repo / ".wac-local").resolve()):
        parser.error("--output must be inside this repository's .wac-local folder")
    output.mkdir(parents=True, exist_ok=False)
    fixtures = output / "fixtures"
    fixtures.mkdir()
    replacements = [(str(repo), "<repo>"), (str(Path.home()), "<user-profile>")]

    def sanitize(value):
        if isinstance(value, str):
            for original, replacement in replacements:
                for variant in (original, original.replace("\\", "/"), original.replace("\\", "\\\\")):
                    value = value.replace(variant, replacement)
            return value
        if isinstance(value, dict):
            return {key: sanitize(item) for key, item in value.items()}
        if isinstance(value, list):
            return [sanitize(item) for item in value]
        return value

    # PS5.1 must initialize its own module search path when this development
    # harness inherits a PS7 environment. This modifies child processes only.
    clean_env = {key: value for key, value in os.environ.items() if key.upper() != "PSMODULEPATH"}
    summary = {
        "task": "WAC-M1-04", "created_utc": stamp,
        "notice": "Synthetic publication/ownership checks. Fault cases use documented isolated application-copy overrides. Disk-full is simulated; no actual volume exhaustion, speech listening or large-file claim.",
        "environment": {"platform": platform.platform(), "python": platform.python_version(), "child_psmodulepath_removed": True},
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "runtime_sha256_before": {path.name: sha256(path) for path in runtime},
        "harness_sha256": sha256(Path(__file__)),
        "tools": {"ffmpeg": {"path": str(ffmpeg), "sha256": sha256(ffmpeg)},
                  "ffprobe": {"path": str(ffprobe), "sha256": sha256(ffprobe)}},
        "fixtures": [], "cases": [], "commands": [],
    }

    def start(label, command, env=None):
        command = [str(item) for item in command]
        process = subprocess.Popen(command, cwd=repo, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, encoding="utf-8", errors="replace", env=env or clean_env)
        return label, command, process, dt.datetime.now(dt.timezone.utc)

    def finish(pending, timeout=120):
        label, command, process, started = pending
        timed_out = False
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            process.kill()
            stdout, stderr = process.communicate(timeout=10)
        result = {"id": label, "command": command, "exit_code": process.returncode,
                  "timed_out": timed_out, "elapsed_seconds": round((dt.datetime.now(dt.timezone.utc) - started).total_seconds(), 3)}
        for name, value in (("stdout", stdout), ("stderr", stderr)):
            log = output / f"{label}-{name}.txt"
            log.write_text(sanitize(value), encoding="utf-8")
            result[name + "_log"] = str(log.relative_to(repo))
            result[name + "_sha256"] = sha256(log)
        summary["commands"].append(result)
        return dict(result, stdout=stdout, stderr=stderr)

    def run(label, command, env=None):
        return finish(start(label, command, env))

    def require_success(result):
        if result["exit_code"] != 0 or result["timed_out"]:
            raise RuntimeError(f"{result['id']} failed: {result['stderr']}")
        return result

    def snapshot(paths):
        return {str(path.relative_to(repo)): sha256(path) for path in paths}

    def unchanged(manifest):
        return all((repo / name).is_file() and sha256(repo / name) == digest for name, digest in manifest.items())

    def add_case(case):
        summary["cases"].append(case)
        print(f"{case['id']}: {'PASS' if case['passed'] else 'FAIL'}", flush=True)

    try:
        for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe)):
            result = require_success(run(name + "-version", [tool, "-version"]))
            summary["tools"][name]["version"] = result["stdout"].splitlines()[0]
        multi = fixtures / "video + two tracks.mkv"
        mono = fixtures / "first" / "same-stem.wav"
        stereo = fixtures / "second" / "same-stem.wav"
        mp3 = fixtures / "compressed.mp3"
        aac = fixtures / "compressed.m4a"
        mono.parent.mkdir()
        stereo.parent.mkdir()
        require_success(run("generate-multi", [
            ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error",
            "-f", "lavfi", "-i", "color=c=black:s=16x16:r=10",
            "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
            "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000",
            "-map", "0:v:0", "-map", "1:a:0", "-map", "2:a:0",
            "-c:v", "ffv1", "-c:a", "pcm_s16le", "-ac:a:1", "2", "-t", "3", multi,
        ]))
        for name, index, path in (("mono", 1, mono), ("stereo", 2, stereo)):
            require_success(run("generate-" + name, [
                ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-i", multi,
                "-map", f"0:{index}", "-c:a", "copy", path,
            ]))
        for name, codec, path in (("mp3", "libmp3lame", mp3), ("aac", "aac", aac)):
            require_success(run("generate-" + name, [
                ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-i", mono,
                "-c:a", codec, "-b:a", "128k", path,
            ]))
        input_manifest = snapshot([multi, mono, stereo, mp3, aac])
        summary["fixtures"] = [{"path": path, "sha256": digest} for path, digest in input_manifest.items()]
        if args.prepare_only:
            summary["status"] = "fixtures-prepared; application checks not run"
            return 0

        sandbox = output / "fault-application"
        sandbox.mkdir()
        source_text = runtime[0].read_text(encoding="utf-8-sig")
        marker = "# --- CONFIGURATION ---"
        if source_text.count(marker) != 1:
            raise RuntimeError("Expected exactly one configuration marker for the isolated fault seam")
        (sandbox / runtime[0].name).write_text(source_text.replace(marker, FAULT_OVERRIDE + "\n" + marker), encoding="utf-8-sig")
        shutil.copy2(runtime[1], sandbox / runtime[1].name)
        summary["fault_application"] = {"seam": "Override native result/owned output after actual encoding, or publication immediately before rename; all other code and actual validation retained.",
                                        "files": snapshot(list(sandbox.iterdir())),
                                        "override_sha256": hashlib.sha256(FAULT_OVERRIDE.encode("utf-8")).hexdigest()}
        collision_bytes = b"Foreign file created after output name selection; preserve these bytes."
        collision_hash = hashlib.sha256(collision_bytes).hexdigest()

        for shell_name, prefix in (("powershell.exe", "ps51"), ("pwsh.exe", "ps7")):
            shell = shutil.which(shell_name)
            if shell is None:
                raise RuntimeError(f"Required shell not found: {shell_name}")
            result = require_success(run(prefix + "-version", [shell, "-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"] ))
            summary["environment"][prefix] = result["stdout"].strip()

            def command(input_path, destination, index, mode="Zoom", fault=False):
                return [shell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        sandbox / runtime[0].name if fault else runtime[0], "-inputPath", input_path,
                        "-OutputDirectory", destination, "-Mode", mode, "-AudioStreamIndex", index,
                        "-FfmpegPath", ffmpeg, "-FfprobePath", ffprobe, "-NonInteractive"]

            def new_destination(name):
                destination = output / (prefix + "-" + name)
                destination.mkdir()
                shutil.copy2(mono, destination / "prior-export.wav")
                return destination

            def success_case(label, result, destination, before, frequency, channels, tolerance=0.01):
                files = sorted(destination.glob("*_Cleaned_*.wav"))
                created = [path for path in files if str(path.relative_to(repo)) not in before]
                partials = list(destination.glob(".wac-*.partial"))
                case = {"id": label, "exit_code": result["exit_code"], "new_final_count": len(created),
                        "partial_count": len(partials), "sources_unchanged": unchanged(input_manifest),
                        "prior_files_unchanged": unchanged(before), "passed": result["exit_code"] == 0
                        and not result["timed_out"] and len(created) == 1 and not partials
                        and unchanged(input_manifest) and unchanged(before)}
                if len(created) == 1:
                    case["output"] = str(created[0].relative_to(repo))
                    case["output_sha256"] = sha256(created[0])
                    case["audio"] = measure_audio(created[0], frequency, channels, tolerance)
                    case["passed"] &= case["audio"]["passed"]
                add_case(case)

            rapid = new_destination("rapid-repeat")
            for repetition, mode in ((1, "Raw"), (2, "Zoom")):
                before = snapshot(rapid.glob("*.wav"))
                label = f"{prefix}-rapid-{repetition}"
                result = run(label, command(multi, rapid, 1, mode))
                success_case(label, result, rapid, before, 440, 1)
            same_stem = new_destination("same-stem")
            for name, input_path, frequency, channels in (("mono", mono, 440, 1), ("stereo", stereo, 880, 2)):
                before = snapshot(same_stem.glob("*.wav"))
                label = prefix + "-same-stem-" + name
                result = run(label, command(input_path, same_stem, 0))
                success_case(label, result, same_stem, before, frequency, channels)

            for name, path in (("mp3", mp3), ("aac", aac)):
                destination = new_destination("compressed-" + name)
                before = snapshot(destination.glob("*.wav"))
                label = prefix + "-compressed-" + name
                result = run(label, command(path, destination, 0))
                success_case(label, result, destination, before, 440, 1, 0.1)

            concurrent = new_destination("concurrent")
            before = snapshot(concurrent.glob("*.wav"))
            pending = [start(prefix + f"-concurrent-{index}", command(multi, concurrent, index, mode))
                       for index, mode in ((1, "Raw"), (2, "Zoom"))]
            results = [finish(item) for item in pending]
            final_files = sorted(concurrent.glob("*_Cleaned_*.wav"))
            analyses = []
            for path in final_files:
                with wave.open(str(path), "rb") as wav:
                    channels = wav.getnchannels()
                analyses.append({"output": str(path.relative_to(repo)), "sha256": sha256(path),
                                 "audio": measure_audio(path, 440 if channels == 1 else 880, channels)})
            add_case({"id": prefix + "-concurrent", "exit_codes": [item["exit_code"] for item in results],
                      "new_final_count": len(final_files), "outputs": analyses,
                      "partial_count": len(list(concurrent.glob(".wac-*.partial"))),
                      "sources_unchanged": unchanged(input_manifest), "prior_files_unchanged": unchanged(before),
                      "passed": all(item["exit_code"] == 0 and not item["timed_out"] for item in results)
                      and len(final_files) == 2 and len({path.name for path in final_files}) == 2
                      and sorted(item["audio"]["channels"] for item in analyses) == [1, 2]
                      and all(item["audio"]["passed"] for item in analyses)
                      and not list(concurrent.glob(".wac-*.partial")) and unchanged(before) and unchanged(input_manifest)})

            for fault, expected_exit in (("empty", 5), ("invalid", 5), ("truncated", 5),
                                         ("encoder", 4), ("disk-full", 4), ("rename-race", 5), ("crash", 99)):
                destination = new_destination(fault)
                before = snapshot(destination.glob("*.wav"))
                label = prefix + "-" + fault
                env = dict(clean_env, WAC_TRANSACTION_FAULT=fault)
                result = run(label, command(multi, destination, 2, fault=True), env)
                final_files = list(destination.glob("*_Cleaned_*.wav"))
                partials = list(destination.glob(".wac-*.partial"))
                case = {"id": label, "fault": fault, "expected_exit": expected_exit, "exit_code": result["exit_code"],
                        "new_final_count": len(final_files), "partials": snapshot(partials),
                        "sources_unchanged": unchanged(input_manifest), "prior_files_unchanged": unchanged(before),
                        "passed": result["exit_code"] == expected_exit and not result["timed_out"]
                        and unchanged(before) and unchanged(input_manifest)}
                if fault == "rename-race":
                    case["foreign_final_unchanged"] = len(final_files) == 1 and sha256(final_files[0]) == collision_hash
                    case["passed"] &= case["foreign_final_unchanged"] and not partials
                elif fault == "crash":
                    case["passed"] &= len(final_files) == 0 and len(partials) == 1 and bool(
                        re.fullmatch(r"\.wac-[0-9a-f]{32}\.partial", partials[0].name))
                    if len(partials) == 1:
                        case["retained_audio"] = measure_audio(partials[0], 880, 2)
                        case["passed"] &= case["retained_audio"]["passed"]
                else:
                    case["passed"] &= len(final_files) == 0 and not partials
                add_case(case)
                if fault == "crash":
                    leftover_manifest = snapshot(partials)
                    recovery = run(prefix + "-after-crash", command(multi, destination, 1))
                    finals_after = list(destination.glob("*_Cleaned_*.wav"))
                    add_case({"id": prefix + "-after-crash", "exit_code": recovery["exit_code"],
                              "leftovers_unchanged": unchanged(leftover_manifest), "new_final_count": len(finals_after),
                              "passed": recovery["exit_code"] == 0 and len(finals_after) == 1
                              and len(list(destination.glob(".wac-*.partial"))) == len(partials)
                              and unchanged(leftover_manifest) and unchanged(before) and unchanged(input_manifest)
                              and measure_audio(finals_after[0], 440, 1)["passed"]})

        if {path.name: sha256(path) for path in runtime} != summary["runtime_sha256_before"]:
            raise RuntimeError("Runtime changed during validation; rerun against stable source")
        summary["status"] = "pass" if all(case["passed"] for case in summary["cases"]) else "fail"
        return 0 if summary["status"] == "pass" else 1
    except Exception as error:
        summary["status"] = "error"
        summary["error"] = str(error)
        print(sanitize(str(error)), file=sys.stderr)
        return 1
    finally:
        summary["runtime_sha256_after"] = {path.name: sha256(path) for path in runtime}
        summary["runtime_unchanged_during_run"] = summary["runtime_sha256_before"] == summary["runtime_sha256_after"]
        evidence = output / "summary.json"
        evidence.write_text(json.dumps(sanitize(summary), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Evidence: {sanitize(str(evidence))}", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
