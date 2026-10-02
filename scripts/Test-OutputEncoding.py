#!/usr/bin/env python3
"""Optional Windows/FFmpeg evidence for explicit PCM, timing and channel policy.

Requires only Python's standard library plus existing FFmpeg/ffprobe and both
PowerShell hosts. Synthetic audio and raw diagnostics stay under .wac-local.
This is a short-file mechanics check, not listening or full >4 GiB validation.
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
import struct
import subprocess
import sys
import wave


RATE = 48000
DURATION = 6.0
ACTIVE_START, ACTIVE_END = 0.75, 5.25
FREQUENCIES = (440, 880)
MARKERS = (1.25, 4.75)
MARKER_FREQUENCIES = (1600, 2400)
IMPULSES = (2.0, 3.75)
CLEAN = "adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056"
LEVEL = "dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5"


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def create_fixture(path: Path, rate: int, channels: int) -> None:
    """Distinct channel tones, shaped markers and precisely located impulses."""
    values = array.array("h")
    impulse_frames = {round(time * rate) for time in IMPULSES}
    for frame in range(round(DURATION * rate)):
        time = frame / rate
        envelope = max(0.0, min(1.0, (time - ACTIVE_START) / 0.01, (ACTIVE_END - time) / 0.01))
        for channel in range(channels):
            value = 0.08 * envelope * math.sin(2 * math.pi * FREQUENCIES[channel] * time)
            for center in MARKERS:
                distance = abs(time - center)
                if distance < 0.04:
                    marker_envelope = 0.5 * (1 + math.cos(math.pi * distance / 0.04))
                    value += 0.4 * marker_envelope * math.sin(2 * math.pi * MARKER_FREQUENCIES[channel] * time)
            if frame in impulse_frames:
                value += 0.7 if channel == 0 else -0.7
            values.append(round(max(-1.0, min(1.0, value)) * 32767))
    if sys.byteorder != "little":
        values.byteswap()
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(values.tobytes())


def read_pcm(path: Path) -> dict:
    """Read actual PCM independently of ffprobe, including a small RF64 header."""
    payload = path.read_bytes()
    if payload[:4] not in (b"RIFF", b"RF64") or payload[8:12] != b"WAVE":
        raise ValueError("Expected RIFF/RF64 WAVE")
    offset = 12
    fmt = data = ds64 = None
    while offset + 8 <= len(payload):
        chunk, length = struct.unpack_from("<4sI", payload, offset)
        start = offset + 8
        if chunk == b"ds64":
            ds64 = struct.unpack_from("<QQQI", payload, start)
        if chunk == b"data" and length == 0xFFFFFFFF and ds64 is not None:
            length = ds64[1]
        if start + length > len(payload):
            raise ValueError("Truncated WAVE chunk")
        if chunk == b"fmt ":
            fmt = struct.unpack_from("<HHIIHH", payload, start)
        elif chunk == b"data":
            data = payload[start:start + length]
        offset = start + length + (length % 2)
    if fmt is None or data is None:
        raise ValueError("Missing WAVE format or data")
    tag, channels, rate, _, block_align, bits = fmt
    if tag not in (1, 0xFFFE) or bits not in (16, 24):
        raise ValueError(f"Unexpected PCM format tag={tag}, bits={bits}")
    if len(data) % block_align:
        raise ValueError("Partial PCM frame")
    values = array.array("d")
    if bits == 16:
        integers = array.array("h", data)
        if sys.byteorder != "little":
            integers.byteswap()
        values.extend(value / 32768 for value in integers)
    else:
        for position in range(0, len(data), 3):
            value = int.from_bytes(data[position:position + 3], "little", signed=True)
            values.append(value / 8388608)
    return {"container": payload[:4].decode("ascii"), "channels": channels, "rate": rate,
            "bits": bits, "frames": len(data) // block_align, "values": values,
            "data_sha256": hashlib.sha256(data).hexdigest(),
            "ds64": None if ds64 is None else {"riff_size": ds64[0], "data_size": ds64[1],
                                               "sample_count": ds64[2], "table_length": ds64[3]}}


def power(values, frequency: int, rate: int) -> float:
    coefficient = 2 * math.cos(2 * math.pi * frequency / rate)
    previous = before_previous = 0.0
    for value in values:
        current = value + coefficient * previous - before_previous
        before_previous, previous = previous, current
    return max(0.0, previous**2 + before_previous**2 - coefficient * previous * before_previous)


def rms(values) -> float:
    return math.sqrt(sum(value * value for value in values) / max(1, len(values)))


def measure(pcm: dict, mono_conversion: bool = False) -> dict:
    """Check channels and absolute timing independently of the reference encode.

    adeclick can intentionally remove single-sample impulses. Their measured
    peaks are therefore reported, not required to survive. Shaped tone markers
    supply an independently measurable alignment check through both chains.
    """
    rate = pcm["rate"]
    output = {"duration_seconds": pcm["frames"] / rate, "frames": pcm["frames"], "channels": []}
    for channel in range(pcm["channels"]):
        values = pcm["values"][channel::pcm["channels"]]
        tone = values[round(2.5 * rate):round(3.0 * rate)]
        powers = {str(frequency): power(tone, frequency, rate) for frequency in FREQUENCIES}
        expected = FREQUENCIES[channel]
        other = FREQUENCIES[1 - channel]
        ratio = powers[str(expected)] / max(powers[str(other)], 1e-20)
        # A downmix must retain both different input tones; separate output
        # channels must each overwhelmingly favor their own tone.
        tone_ok = (0.05 < ratio < 20) if mono_conversion else ratio > 100
        marker_results = []
        for center in MARKERS:
            # A 10 ms sliding window at 1 ms steps, within +/-100 ms. Weighted
            # band-power centroid is robust to the preserved dynamic filters.
            weighted = total = 0.0
            for step in range(-100, 101):
                start = round((center + step / 1000 - 0.005) * rate)
                segment = values[start:start + round(0.01 * rate)]
                strength = power(segment, MARKER_FREQUENCIES[channel], rate)
                weighted += (center + step / 1000) * strength
                total += strength
            measured_center = weighted / total if total else None
            marker_results.append({"known_center_seconds": center, "measured_center_seconds": measured_center,
                                   "offset_ms": None if measured_center is None else 1000 * (measured_center - center)})
        window = round(0.001 * rate)
        active_windows = [position for position in range(0, len(values) - window + 1, window)
                          if rms(values[position:position + window]) > 0.005]
        onset = None if not active_windows else active_windows[0] / rate
        end = None if not active_windows else (active_windows[-1] + window) / rate
        edges = {"first_half_second_max": max(abs(value) for value in values[:round(0.5 * rate)]),
                 "last_half_second_max": max(abs(value) for value in values[-round(0.5 * rate):]),
                 "activity_threshold_rms": 0.005, "first_active_seconds": onset, "last_active_seconds": end}
        impulses = []
        for time in IMPULSES:
            position = round(time * rate)
            start, end_position = position - round(0.005 * rate), position + round(0.005 * rate) + 1
            local = values[start:end_position]
            peak = max(range(len(local)), key=lambda index: abs(local[index]))
            impulses.append({"known_time_seconds": time, "sample_at_known_time": values[position],
                             "local_peak_abs": abs(local[peak]), "local_peak_offset_ms": 1000 * (start + peak - position) / rate})
        # Absolute marker/activity offsets remain visible: the unchanged Raw
        # chain itself has measurable latency. The app's additional delay is
        # checked separately against the independently rendered frozen chain.
        passed = tone_ok and edges["first_half_second_max"] < 0.001 and edges["last_half_second_max"] < 0.001
        passed &= onset is not None and end is not None and all(item["offset_ms"] is not None for item in marker_results)
        output["channels"].append({"index": channel, "tone_power": powers,
                                   "expected_to_other_power_ratio": ratio, "markers": marker_results,
                                   "silence_and_activity": edges, "impulses": impulses,
                                   "nominal_marker_alignment_within_10ms": all(item["offset_ms"] is not None and abs(item["offset_ms"]) <= 10 for item in marker_results),
                                   "nominal_activity_alignment_within_20ms": onset is not None and end is not None and abs(onset - ACTIVE_START) <= 0.02 and abs(end - ACTIVE_END) <= 0.02,
                                   "passed": passed})
    output["passed"] = abs(output["duration_seconds"] - DURATION) <= 0.01 and all(item["passed"] for item in output["channels"])
    return output


def alignment_delta(actual: dict, reference: dict) -> dict:
    """Report residual timing error, without erasing the absolute measurements."""
    channels = []
    for measured, baseline in zip(actual["channels"], reference["channels"], strict=True):
        marker_deltas = [value["offset_ms"] - original["offset_ms"]
                         for value, original in zip(measured["markers"], baseline["markers"], strict=True)]
        activity_deltas = {name + "_delta_ms": 1000 * (measured["silence_and_activity"][name] - baseline["silence_and_activity"][name])
                           for name in ("first_active_seconds", "last_active_seconds")}
        channels.append({"index": measured["index"], "marker_delta_ms": marker_deltas, **activity_deltas})
    maximum = max(abs(value) for channel in channels
                  for value in channel["marker_delta_ms"] + [channel["first_active_seconds_delta_ms"], channel["last_active_seconds_delta_ms"]])
    return {"channels": channels, "max_abs_delta_ms": maximum, "tolerance_ms": 1000 / RATE,
            "passed": maximum <= 1000 / RATE and actual["frames"] == reference["frames"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--ffprobe", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--prepare-only", action="store_true", help="Generate fixtures and reference renders; do not run the app")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    runtime = [repo / "WinAudioClean.ps1", repo / "WinAudioClean.IO.ps1"]
    ffmpeg, ffprobe = args.ffmpeg.resolve(strict=True), args.ffprobe.resolve(strict=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = (args.output or repo / ".wac-local" / "WAC-M1-05" / stamp).resolve()
    if not output.is_relative_to((repo / ".wac-local").resolve()):
        parser.error("--output must be inside this repository's .wac-local folder")
    output.mkdir(parents=True, exist_ok=False)
    fixtures, references = output / "fixtures", output / "references"
    fixtures.mkdir()
    references.mkdir()
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

    clean_env = {key: value for key, value in os.environ.items() if key.upper() != "PSMODULEPATH"}
    summary = {
        "task": "WAC-M1-05", "created_utc": stamp,
        "notice": "Synthetic short-file checks; no speech listening, loudness certification, actual volume exhaustion or full >4 GiB stress claim.",
        "environment": {"platform": platform.platform(), "python": platform.python_version(), "child_psmodulepath_removed": True},
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "runtime_sha256_before": {path.name: sha256(path) for path in runtime},
        "harness_sha256": sha256(Path(__file__)),
        "harness_invocation": [sys.executable, *sys.argv],
        "frozen_filter_baseline_sha256": sha256(repo / "docs/codex/winaudioclean/BASELINE.json"),
        "tools": {"ffmpeg": {"path": str(ffmpeg), "sha256": sha256(ffmpeg)},
                  "ffprobe": {"path": str(ffprobe), "sha256": sha256(ffprobe)}},
        "signal_contract": {"duration_seconds": DURATION, "active_start_seconds": ACTIVE_START,
                            "active_end_seconds": ACTIVE_END, "left_right_tones_hz": FREQUENCIES,
                            "marker_centers_seconds": MARKERS, "left_right_marker_hz": MARKER_FREQUENCIES,
                            "known_impulses_seconds": IMPULSES, "marker_reference_tolerance_ms": 1000 / RATE,
                            "activity_reference_tolerance_ms": 1000 / RATE, "duration_tolerance_ms": 10,
                            "note": "Impulse survival is not required because Raw adeclick removes isolated transients. Absolute marker/activity offsets are reported, including preserved Raw-filter latency. Acceptance requires no additional offset against independently rendered frozen filters, plus zero-lag PCM equality, retained boundary silence, duration and independent channel-frequency checks."},
        "filters": {"Raw": CLEAN + "," + LEVEL, "Zoom": LEVEL},
        "fixtures": [], "references": [], "cases": [], "commands": [],
    }

    def run(label, command):
        command = [str(item) for item in command]
        started = dt.datetime.now(dt.timezone.utc)
        process = subprocess.Popen(command, cwd=repo, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, encoding="utf-8", errors="replace", env=clean_env)
        timed_out = False
        try:
            stdout, stderr = process.communicate(timeout=120)
        except subprocess.TimeoutExpired:
            timed_out = True
            process.kill()
            stdout, stderr = process.communicate(timeout=10)
        result = {"id": label, "command": command, "exit_code": process.returncode, "timed_out": timed_out,
                  "elapsed_seconds": round((dt.datetime.now(dt.timezone.utc) - started).total_seconds(), 3)}
        for name, value in (("stdout", stdout), ("stderr", stderr)):
            log = output / f"{label}-{name}.txt"
            log.write_text(sanitize(value), encoding="utf-8")
            result[name + "_log"] = str(log.relative_to(repo))
            result[name + "_sha256"] = sha256(log)
        summary["commands"].append(result)
        return dict(result, stdout=stdout, stderr=stderr)

    def checked(label, command):
        result = run(label, command)
        if result["exit_code"] != 0 or result["timed_out"]:
            raise RuntimeError(f"{label} failed: {result['stderr']}")
        return result

    def probe(label, path, channels, bits):
        result = checked(label, [ffprobe, "-v", "error", "-show_streams", "-show_format", "-of", "json", path])
        data = json.loads(result["stdout"])
        streams = data.get("streams", [])
        if len(streams) != 1:
            raise ValueError("Expected exactly one output stream")
        stream = streams[0]
        expected_layout = "mono" if channels == 1 else "stereo"
        # Canonical PCM16 mono/stereo RIFF can omit a channel mask; retain the
        # reported absence and use channel-count convention only in that case.
        reported_layout = stream.get("channel_layout")
        resolved_layout = reported_layout or (expected_layout if stream.get("channels") == channels else None)
        detail = {name: stream.get(name) for name in ("codec_name", "codec_type", "sample_fmt", "sample_rate", "channels", "channel_layout", "bits_per_sample", "bits_per_raw_sample", "duration")}
        detail.update({"resolved_layout": resolved_layout, "layout_basis": "ffprobe" if reported_layout else "canonical mono/stereo PCM channel-count convention",
                       "passed": stream.get("codec_name") == f"pcm_s{bits}le" and stream.get("codec_type") == "audio"
                       and int(stream.get("sample_rate", 0)) == RATE and stream.get("channels") == channels
                       and int(stream.get("bits_per_sample", 0)) == bits and resolved_layout == expected_layout})
        return detail

    try:
        baseline = json.loads((repo / "docs/codex/winaudioclean/BASELINE.json").read_text(encoding="utf-8"))
        if baseline["filters"] != {"raw_clean": CLEAN, "level": LEVEL}:
            raise ValueError("Frozen reference filter strings differ from BASELINE.json")
        for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe)):
            result = checked(name + "-version", [tool, "-version"])
            summary["tools"][name]["version"] = result["stdout"].splitlines()[0]
        sources = {}
        for rate in (44100, 48000):
            for channels in (1, 2):
                path = fixtures / f"{rate}-{channels}ch.wav"
                create_fixture(path, rate, channels)
                sources[(rate, channels)] = path
                summary["fixtures"].append({"path": str(path.relative_to(repo)), "sha256": sha256(path),
                                             "sample_rate": rate, "channels": channels, "measurements": measure(read_pcm(path))})
        reference_pcm, reference_measurements = {}, {}
        configs = [(rate, channels, mode, bits, False, False)
                   for rate in (44100, 48000) for channels in (1, 2) for mode in ("Raw", "Zoom") for bits in (16, 24)]
        configs += [(48000, 2, "Raw", 16, True, False), (44100, 2, "Zoom", 24, True, False),
                    (48000, 2, "Raw", 24, False, True), (44100, 1, "Zoom", 16, False, True)]
        for rate, channels, mode, bits, mono, rf64 in configs:
            label = f"{rate}-{channels}ch-{mode.lower()}-{bits}" + ("-mono" if mono else "") + ("-rf64" if rf64 else "")
            target_channels = 1 if mono else channels
            filters = ("pan=mono|c0=0.5*c0+0.5*c1," if mono else "") + summary["filters"][mode]
            path = references / (label + ".wav")
            checked("reference-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-i", sources[(rate, channels)],
                    "-map", "0:0", "-vn", "-af", filters, "-ar", RATE, "-c:a", f"pcm_s{bits}le", "-ac", target_channels,
                    "-channel_layout", "mono" if target_channels == 1 else "stereo", "-map_metadata", "-1", "-map_chapters", "-1",
                    "-f", "wav", "-rf64", "always" if rf64 else "never", path])
            pcm = read_pcm(path)
            reference_pcm[label] = pcm
            reference_measurements[label] = measure(pcm, mono)
            summary["references"].append({"id": label, "path": str(path.relative_to(repo)), "sha256": sha256(path),
                                            "pcm_sha256": pcm["data_sha256"], "measurements": reference_measurements[label],
                                            "probe": probe("probe-reference-" + label, path, target_channels, bits)})
            print(f"reference-{label}: prepared", flush=True)
        if args.prepare_only:
            summary["status"] = "fixtures-and-references-prepared; application checks not run"
            return 0
        for shell_name, prefix in (("powershell.exe", "ps51"), ("pwsh.exe", "ps7")):
            shell = shutil.which(shell_name)
            if shell is None:
                raise RuntimeError(f"Required shell not found: {shell_name}")
            result = checked(prefix + "-version", [shell, "-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"])
            summary["environment"][prefix] = result["stdout"].strip()
            for rate, channels, mode, bits, mono, rf64 in configs:
                label = f"{rate}-{channels}ch-{mode.lower()}-{bits}" + ("-mono" if mono else "") + ("-rf64" if rf64 else "")
                case_id = prefix + "-" + label
                destination = output / case_id
                destination.mkdir()
                target_channels = 1 if mono else channels
                command = [shell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", runtime[0],
                           "-inputPath", sources[(rate, channels)], "-OutputDirectory", destination, "-Mode", mode,
                           "-FfmpegPath", ffmpeg, "-FfprobePath", ffprobe, "-NonInteractive"]
                # The matrix also verifies the actual default: PCM16 without
                # -BitDepth. Extra RF64/mono cases exercise an explicit 16.
                if bits != 16 or mono or rf64:
                    command += ["-BitDepth", bits]
                if mono:
                    command += ["-Mono"]
                if rf64:
                    command += ["-Rf64"]
                result = run(case_id, command)
                files = list(destination.glob("*_Cleaned_*.wav"))
                partials = list(destination.glob(".wac-*.partial"))
                case = {"id": case_id, "matrix_case": not mono and not rf64, "input_rate": rate, "input_channels": channels,
                        "mode": mode, "bits": bits, "mono_requested": mono, "rf64_requested": rf64,
                        "exit_code": result["exit_code"], "final_count": len(files), "partial_count": len(partials),
                        "passed": result["exit_code"] == 0 and not result["timed_out"] and len(files) == 1 and not partials}
                if len(files) == 1:
                    pcm = read_pcm(files[0])
                    case["output"] = str(files[0].relative_to(repo))
                    case["output_sha256"] = sha256(files[0])
                    case["pcm_sha256"] = pcm["data_sha256"]
                    case["probe"] = probe("probe-" + case_id, files[0], target_channels, bits)
                    case["measurements"] = measure(pcm, mono)
                    case["container"] = pcm["container"]
                    case["ds64"] = pcm["ds64"]
                    case["reference_id"] = label
                    case["alignment_to_frozen_filter_reference"] = alignment_delta(case["measurements"], reference_measurements[label])
                    case["zero_lag_pcm_equal_to_reference"] = pcm["data_sha256"] == reference_pcm[label]["data_sha256"]
                    case["passed"] &= case["probe"]["passed"] and case["measurements"]["passed"] and case["zero_lag_pcm_equal_to_reference"] and case["alignment_to_frozen_filter_reference"]["passed"]
                    case["passed"] &= pcm["container"] == ("RF64" if rf64 else "RIFF")
                    if rf64:
                        case["passed"] &= pcm["ds64"] is not None and pcm["ds64"]["sample_count"] == pcm["frames"]
                        case["passed"] &= pcm["ds64"]["riff_size"] == files[0].stat().st_size - 8 and pcm["ds64"]["data_size"] == pcm["frames"] * target_channels * bits // 8
                summary["cases"].append(case)
                print(f"{case_id}: {'PASS' if case['passed'] else 'FAIL'}", flush=True)
        summary["fixtures_unchanged"] = all(sha256(repo / fixture["path"]) == fixture["sha256"] for fixture in summary["fixtures"])
        if {path.name: sha256(path) for path in runtime} != summary["runtime_sha256_before"]:
            raise RuntimeError("Runtime changed during validation; rerun against stable source")
        if sha256(Path(__file__)) != summary["harness_sha256"]:
            raise RuntimeError("Harness changed during validation; rerun against stable source")
        summary["status"] = "pass" if summary["fixtures_unchanged"] and all(case["passed"] for case in summary["cases"]) else "fail"
        return 0 if summary["status"] == "pass" else 1
    except Exception as error:
        summary["status"] = "error"
        summary["error"] = str(error)
        print(sanitize(str(error)), file=sys.stderr)
        return 1
    finally:
        summary["runtime_sha256_after"] = {path.name: sha256(path) for path in runtime}
        summary["runtime_unchanged_during_run"] = summary["runtime_sha256_before"] == summary["runtime_sha256_after"]
        summary["harness_sha256_after"] = sha256(Path(__file__))
        summary["harness_unchanged_during_run"] = summary["harness_sha256"] == summary["harness_sha256_after"]
        evidence = output / "summary.json"
        evidence.write_text(json.dumps(sanitize(summary), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Evidence: {sanitize(str(evidence))}", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
