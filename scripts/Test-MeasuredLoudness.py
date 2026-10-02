#!/usr/bin/env python3
"""Optional Windows evidence for Accurate two-pass and final-file loudness.

Uses existing FFmpeg/ffprobe and PowerShell 5.1/7, with Python's standard library
only. Generated harmonic-envelope audio is synthetic mechanics material, not
speech or listening evidence. Raw audio, reports and diagnostics remain ignored.
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


RATE = 48000
TARGET = "loudnorm=I=-12:TP=-1.5:LRA=7"
METRICS = {"integratedLufs": "input_i", "truePeakDbtp": "input_tp", "loudnessRangeLu": "input_lra"}
WRAPPER = r'''param(
    [string]$Application, [string]$Source, [string]$Destination,
    [string]$Ffmpeg, [string]$Ffprobe, [string]$Culture, [string]$Mode,
    [int]$Bits, [int]$StreamIndex, [switch]$Mono
)
$cultureInfo = [Globalization.CultureInfo]::GetCultureInfo($Culture)
[Threading.Thread]::CurrentThread.CurrentCulture = $cultureInfo
[Threading.Thread]::CurrentThread.CurrentUICulture = $cultureInfo
Write-Host ('WAC_HARNESS_CULTURE:' + [Threading.Thread]::CurrentThread.CurrentCulture.Name)
$arguments = @{
    inputPath = $Source; OutputDirectory = $Destination; FfmpegPath = $Ffmpeg
    FfprobePath = $Ffprobe; Mode = $Mode; BitDepth = $Bits
    AudioStreamIndex = $StreamIndex; LoudnessMode = 'Accurate'; NonInteractive = $true
}
if ($Mono) { $arguments.Mono = $true }
& $Application @arguments
exit $LASTEXITCODE
'''


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stop_owned_process_tree(process):
    """Bound cleanup to this harness child and its Windows descendants."""
    taskkill = Path(os.environ["SystemRoot"]) / "System32" / "taskkill.exe"
    try:
        return subprocess.run([str(taskkill), "/PID", str(process.pid), "/T", "/F"],
                              stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, timeout=10, check=True)
    finally:
        if process.poll() is None:
            process.kill()


def create_fixture(path: Path, channels: int, seconds: float, kind: str) -> dict:
    """Deterministic voiced-harmonic envelopes; no actual speech is generated."""
    samples = array.array("h")
    for frame in range(round(RATE * seconds)):
        time = frame / RATE
        for channel in range(channels):
            frequency = 120 + 31 * channel
            carrier = (0.62 * math.sin(2 * math.pi * frequency * time)
                       + 0.24 * math.sin(2 * math.pi * 2.013 * frequency * time)
                       + 0.12 * math.sin(2 * math.pi * 3.017 * frequency * time))
            syllable = 0.22 + 0.78 * math.sin(math.pi * 3.4 * time) ** 2
            envelope = (0.12 + 0.1 * math.sin(math.pi * 0.17 * time) ** 2) * syllable
            if kind == "high_lra":
                envelope = (0.004 if time % 18 < 9 else 0.3) * syllable
            elif kind == "peaks":
                envelope = 0.001
                phase = time % 2
                if phase < 0.012:
                    envelope += 0.95 * math.sin(math.pi * phase / 0.012) ** 2
            elif kind == "silence":
                envelope = 0.0
            samples.append(round(max(-1, min(1, carrier * envelope)) * 32767))
    if sys.byteorder != "little":
        samples.byteswap()
    with path.open("xb") as destination:
        with wave.open(destination, "wb") as wav:
            wav.setnchannels(channels)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(samples.tobytes())
    return {"id": path.stem, "channels": channels, "seconds": seconds, "kind": kind,
            "sample_rate": RATE, "frames": round(RATE * seconds), "sha256": sha256(path)}


def parse_stats(text: str) -> dict:
    """Independently parse exactly one FFmpeg loudnorm JSON measurement block."""
    candidates = [json.loads(block) for block in re.findall(r"\{[^{}]+\}", text)
                  if '"input_i"' in block and '"normalization_type"' in block]
    if len(candidates) != 1:
        raise ValueError("Expected exactly one loudnorm measurement block")
    return candidates[0]


def finite_value(value):
    number = float(value)
    return number if math.isfinite(number) else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--ffprobe", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--case", action="append", dest="selected_cases", help="Run only this matrix case ID; repeat to select several")
    parser.add_argument("--shell", choices=("ps51", "ps7"), help="Limit an investigative run to one shell")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    ffmpeg, ffprobe = args.ffmpeg.resolve(strict=True), args.ffprobe.resolve(strict=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = (args.output or repo / ".wac-local" / "WAC-M2-02" / stamp).resolve()
    if not output.is_relative_to((repo / ".wac-local").resolve()):
        parser.error("--output must be inside this repository's .wac-local folder")
    output.mkdir(parents=True, exist_ok=False)
    fixtures = output / "fixtures"
    fixtures.mkdir()
    wrapper = output / "Invoke-AccurateLocale.ps1"
    wrapper.write_text(WRAPPER, encoding="utf-8-sig")
    baseline_path = repo / "docs/codex/winaudioclean/BASELINE.json"
    sources = [repo / "WinAudioClean.ps1", repo / "WinAudioClean.IO.ps1", Path(__file__).resolve(), baseline_path]
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

    def source_hashes():
        return {path.relative_to(repo).as_posix(): sha256(path) for path in sources}

    clean_env = {key: value for key, value in os.environ.items() if key.upper() != "PSMODULEPATH"}
    summary = {
        "task": "WAC-M2-02", "created_utc": stamp,
        "notice": "Synthetic signal mechanics and encoded-file measurements only. No speech listening, default-sound approval or cross-build equivalence is claimed.",
        "environment": {"platform": platform.platform(), "python": platform.python_version(), "child_psmodulepath_removed": True},
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "source_sha256_before": source_hashes(), "harness_invocation": sys.orig_argv,
        "scope": {"selected_cases": args.selected_cases, "shell": args.shell, "full_matrix": not args.selected_cases and not args.shell},
        "locale_wrapper_sha256": sha256(wrapper),
        "tools": {name: {"path": str(path), "sha256": sha256(path)}
                  for name, path in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe))},
        "tolerances": {"target_integrated_lufs": -12, "integrated_tolerance_lu": 0.5,
                       "target_true_peak_dbtp": -1.5, "true_peak_tolerance_db": 0.2, "target_lra_lu": 7,
                       "duration_tolerance_seconds": 0.01},
        "fixtures": [], "cases": [], "commands": [],
    }

    def run(label, command, binary=False):
        command = [str(item) for item in command]
        started = dt.datetime.now(dt.timezone.utc)
        process = subprocess.Popen(command, cwd=repo, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=clean_env)
        timed_out = False
        try:
            stdout, stderr = process.communicate(timeout=180)
        except subprocess.TimeoutExpired:
            timed_out = True
            stop_owned_process_tree(process)
            stdout, stderr = process.communicate(timeout=10)
        result = {"id": label, "command": command, "exit_code": process.returncode, "timed_out": timed_out,
                  "elapsed_seconds": round((dt.datetime.now(dt.timezone.utc) - started).total_seconds(), 3)}
        for name, value in (("stdout", stdout), ("stderr", stderr)):
            raw_pcm = binary and name == "stdout"
            log = output / f"{label}-{name}.{'pcm' if raw_pcm else 'txt'}"
            if raw_pcm:
                log.write_bytes(value)
            else:
                log.write_text(sanitize(value.decode("utf-8", errors="replace")), encoding="utf-8")
            result[name + "_log"] = str(log.relative_to(repo))
            result[name + "_sha256"] = sha256(log)
        summary["commands"].append(result)
        return dict(result, stdout=stdout if binary else stdout.decode("utf-8", errors="replace"),
                    stderr=stderr.decode("utf-8", errors="replace"))

    def checked(label, command, binary=False):
        result = run(label, command, binary)
        if result["exit_code"] != 0 or result["timed_out"]:
            raise RuntimeError(f"{label} failed: {result['stderr']}")
        return result

    def file_record(path):
        return {"path": str(path.relative_to(repo)), "sha256": sha256(path)}

    def inspect_audio(label, path, channels, bits, seconds):
        probe_result = checked("probe-" + label, [ffprobe, "-v", "error", "-show_streams", "-of", "json", path])
        streams = json.loads(probe_result["stdout"]).get("streams", [])
        if len(streams) != 1:
            raise ValueError("Expected exactly one output stream")
        stream = streams[0]
        probe = {key: stream.get(key) for key in ("codec_name", "sample_rate", "channels", "bits_per_sample", "channel_layout", "duration")}
        probe["passed"] = (stream.get("codec_name") == f"pcm_s{bits}le" and int(stream.get("sample_rate", 0)) == RATE
                           and stream.get("channels") == channels and int(stream.get("bits_per_sample", 0)) == bits
                           and abs(float(stream.get("duration", 0)) - seconds) <= 0.01)
        decoded = checked("decode-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", path,
                                             "-map", "0:a:0", "-c:a", f"pcm_s{bits}le", "-f", f"s{bits}le", "-"], True)["stdout"]
        measured = checked("measure-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-i", path, "-map", "0:a:0",
                                               "-af", TARGET + ":print_format=json", "-f", "null", "NUL"])
        stats = parse_stats(measured["stderr"])
        values = {name: finite_value(stats[source]) for name, source in METRICS.items()}
        comparable = values["integratedLufs"] is not None and values["truePeakDbtp"] is not None and seconds >= 1
        compliant = (comparable and abs(values["integratedLufs"] + 12) <= 0.5 and values["truePeakDbtp"] <= -1.3)
        return {**file_record(path), "probe": probe, "decoded_pcm_sha256": hashlib.sha256(decoded).hexdigest(),
                "decoded_pcm_bytes": len(decoded), "independent_metrics": values,
                "independent_raw_stats": stats, "independent_comparable": comparable,
                "independent_compliant": compliant, "passed": probe["passed"] and len(decoded) > 0}

    # The final runtime report assertions are kept here so they can be reviewed
    # directly against the public schema and independent file observations.
    def inspect_report(path, config, audio, expected_prechain):
        def reject_constant(value):
            raise ValueError("Nonfinite JSON numeric constant: " + value)

        report = json.loads(path.read_text(encoding="utf-8-sig"), parse_constant=reject_constant)
        normalization = report["normalization"]
        text_path, summary_path = path.with_suffix(".txt"), path.parent / "WinAudioClean_Log.txt"
        text = text_path.read_text(encoding="utf-8-sig")
        combined = summary_path.read_text(encoding="utf-8-sig")
        facts = {**file_record(path), "text": file_record(text_path), "summary": file_record(summary_path),
                 "schema_version": report["schemaVersion"], "preset_id": report["presetId"], "preset_version": report["presetVersion"],
                 "settings": report["settings"], "selected_stream": report["input"]["stream"]["index"],
                 "requested_targets": report["requestedTargets"], "loudness_tolerances": report["loudnessTolerances"],
                 "normalization": {key: normalization[key] for key in ("requestedMode", "prechain", "analysisFilter", "renderFilter",
                                   "finalMeasurementFilter", "linearRequested", "fallbackReason", "actualType")},
                 "measurements": report["measurements"], "loudness_compliance": report["loudnessCompliance"],
                 "status": report["status"], "processing_status": report["processingStatus"],
                 "application_exit_code": report["applicationExitCode"], "native_exit_code": report["nativeExitCode"],
                 "reporting_complete": report["reporting"]["complete"], "warning_codes": report["warningCodes"],
                 "published": report["output"]["published"], "format": report["output"]["format"],
                 "text_contiguous_in_summary": text.strip() in combined, "stages": {}}
        expected_format = {"sampleRate": RATE, "bitDepth": config["bits"], "codec": f"pcm_s{config['bits']}le",
                           "channels": config["channels"], "channelLayout": "mono" if config["channels"] == 1 else "stereo", "container": "RIFF"}
        checks = {
            "identity": facts["schema_version"] == 1 and facts["preset_id"] == "original" and facts["preset_version"] == "1.0.0",
            "mode_stream": report["settings"]["loudnessMode"] == "Accurate" and report["settings"]["mode"] == config["mode"]
                           and facts["selected_stream"] == config["stream"] and normalization["requestedMode"] == "Accurate",
            "format": facts["format"] == expected_format,
            "targets": facts["requested_targets"] == {"integratedLufs": -12, "truePeakDbtp": -1.5, "loudnessRangeLu": 7},
            "tolerances": facts["loudness_tolerances"] == {"integratedLufs": 0.5, "truePeakDbtp": 0.2},
            "prechain": normalization["prechain"] == expected_prechain,
            "analysis_filter": normalization["analysisFilter"] == expected_prechain + "," + TARGET + ":print_format=json",
            "render_prechain": normalization["renderFilter"].startswith(expected_prechain + "," + TARGET + ":")
                               and normalization["renderFilter"].count("loudnorm=") == 1,
            "final_filter": normalization["finalMeasurementFilter"] == TARGET + ":print_format=json",
            "effective_filter": report["settings"]["exactFilters"] == normalization["renderFilter"],
            "same_dependency": Path(report["dependencies"]["ffmpeg"]["path"]).resolve() == ffmpeg
                               and report["dependencies"]["ffmpeg"]["version"] == summary["tools"]["ffmpeg"]["version"],
            "summary": facts["text_contiguous_in_summary"],
        }

        def argument(arguments, name):
            return arguments[arguments.index(name) + 1]

        for name in ("analysis", "render", "final"):
            stage = normalization[name]
            process = stage["process"]
            raw_stats = parse_stats(process["StandardError"])
            stages = {"status": stage["status"], "arguments": stage["arguments"], "input_source": stage["inputSource"],
                      "measurement": stage["measurement"], "raw_stats": raw_stats,
                      "process": {key: process[key] for key in ("Started", "ExitCode", "TimedOut", "Error", "CleanupError")}}
            arguments = stage["arguments"]
            stage_checks = {
                "success": stage["status"] == "PASSED" and process["Started"] and process["ExitCode"] == 0
                           and not process["TimedOut"] and not process["Error"] and not process["CleanupError"] and not stage["error"],
                "actual_type": stage["measurement"]["NormalizationType"] == raw_stats["normalization_type"],
                "quiet_statistics": "-nostats" in arguments and "-stats" not in arguments,
            }
            if name == "final":
                stage_checks["held_output_only"] = (stage["inputSource"] == "held_output_stream" and argument(arguments, "-i") == "pipe:0"
                                                      and argument(arguments, "-map") == "0:0" and argument(arguments, "-af") == normalization["finalMeasurementFilter"]
                                                      and "-ac" not in arguments and "-channel_layout" not in arguments)
            else:
                stage_checks["selected_source"] = (stage["inputSource"] == "file" and Path(argument(arguments, "-i")).resolve() == config["source"].resolve()
                                                    and argument(arguments, "-map") == "0:" + str(config["stream"]))
                stage_checks["channel_policy"] = (argument(arguments, "-ac") == str(config["channels"])
                                                   and argument(arguments, "-channel_layout") == expected_format["channelLayout"])
                stage_checks["effective_filter"] = argument(arguments, "-af") == normalization[name + "Filter"]
            stages["checks"] = stage_checks
            stages["passed"] = all(stage_checks.values())
            facts["stages"][name] = stages
        checks["stages"] = all(stage["passed"] for stage in facts["stages"].values())
        analysis = normalization["analysis"]["measurement"]
        render = normalization["render"]["measurement"]
        render_values = dict(item.split("=", 1) for item in normalization["renderFilter"].split("loudnorm=", 1)[1].split(":"))
        checks["observed_type"] = normalization["actualType"] == render["NormalizationType"]
        measured_keys = {"measured_I": "InputI", "measured_TP": "InputTP", "measured_LRA": "InputLRA",
                         "measured_thresh": "InputThreshold", "offset": "TargetOffset"}
        if analysis["Available"]:
            checks["measured_parameters"] = (normalization["linearRequested"] is True and render_values["linear"] == "true"
                                             and all(math.isfinite(float(render_values[key])) and float(render_values[key]) == analysis[value]
                                                     for key, value in measured_keys.items()))
            expected_fallback = "ffmpeg_dynamic_fallback" if render["NormalizationType"] == "dynamic" else None
        else:
            checks["measured_parameters"] = (normalization["linearRequested"] is False and render_values["linear"] == "false"
                                             and not any(key in render_values for key in measured_keys))
            expected_fallback = analysis["Reason"]
        checks["fallback"] = normalization["fallbackReason"] == expected_fallback
        checks["offset_name"] = "target_offset=" not in normalization["renderFilter"]
        metrics = audio["independent_metrics"]
        if metrics["truePeakDbtp"] is not None and metrics["truePeakDbtp"] > -1.3:
            expected_status, expected_reason = "OUT_OF_TOLERANCE", "true_peak_exceeded"
        elif config["kind"] in ("short", "silence"):
            expected_status = "UNMEASURABLE"
            expected_reason = "too_short" if config["kind"] == "short" else "silence"
        elif not audio["independent_comparable"]:
            expected_status, expected_reason = "UNMEASURABLE", "undefined_loudness"
        elif not audio["independent_compliant"]:
            expected_status, expected_reason = "OUT_OF_TOLERANCE", "loudness_out_of_tolerance"
        else:
            expected_status, expected_reason = "PASSED", None
        checks["compliance"] = facts["loudness_compliance"]["status"] == expected_status and facts["loudness_compliance"]["reason"] == expected_reason
        for name in METRICS:
            expected_value = metrics[name]
            expected_metric_reason = None
            if config["kind"] in ("short", "silence") and (name != "truePeakDbtp" or expected_value is None):
                expected_value = None
                expected_metric_reason = "too_short" if config["kind"] == "short" else "silence"
            metric = facts["measurements"][name]
            checks["final_" + name] = (metric["value"] == expected_value and metric["reason"] == expected_metric_reason)
        if config["kind"] == "high_lra":
            checks["high_lra_fallback"] = analysis["InputLRA"] > 7 and normalization["actualType"] == "dynamic"
        elif config["kind"] == "peaks":
            checks["peak_constrained_fallback"] = (not audio["independent_compliant"] and normalization["actualType"] == "dynamic"
                                                    and analysis["InputTP"] + (-12 - analysis["InputI"]) > -1.5)
        warning = expected_fallback is not None or expected_status != "PASSED"
        checks["outcome"] = (facts["status"] == ("WARNING" if warning else "SUCCESS") and facts["application_exit_code"] == (7 if warning else 0)
                             and facts["processing_status"] == "SUCCESS" and facts["native_exit_code"] == 0
                             and facts["published"] and facts["reporting_complete"] and bool(facts["warning_codes"]) == warning)
        facts["checks"] = checks
        facts["passed"] = all(checks.values())
        return facts

    try:
        for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe)):
            result = checked(name + "-version", [tool, "-version"])
            summary["tools"][name]["version"] = result["stdout"].splitlines()[0]
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        leveling = baseline["filters"]["level"].rsplit(",loudnorm=", 1)[0]
        prechains = {"Raw": baseline["filters"]["raw_clean"] + "," + leveling, "Zoom": leveling}
        definitions = [("stereo", 2, 36.0, "eligible"), ("mono", 1, 36.0, "eligible"),
                       ("high_lra", 1, 36.0, "high_lra"), ("peaks", 1, 36.0, "peaks"),
                       ("silence", 1, 3.0, "silence"), ("short", 1, 0.2, "eligible")]
        fixture_paths = {}
        for name, channels, seconds, kind in definitions:
            path = fixtures / (name + ".wav")
            record = create_fixture(path, channels, seconds, kind)
            summary["fixtures"].append({"path": str(path.relative_to(repo)), **record})
            fixture_paths[name] = path
        selected = fixtures / "selected-stream.mkv"
        checked("mux-selected-stream", [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", fixture_paths["mono"],
                "-i", fixture_paths["stereo"], "-map", "0:a:0", "-map", "1:a:0", "-c:a", "copy", selected])
        summary["fixtures"].append({"id": "selected-stream", **file_record(selected), "seconds": 36.0,
                                     "description": "Absolute stream 0 is mono; selected absolute stream 1 is stereo."})
        configs = [
            {"id": "selected-raw-16", "source": selected, "stream": 1, "mode": "Raw", "bits": 16, "channels": 2, "seconds": 36.0, "kind": "eligible"},
            {"id": "stereo-zoom-24", "source": fixture_paths["stereo"], "stream": 0, "mode": "Zoom", "bits": 24, "channels": 2, "seconds": 36.0, "kind": "eligible"},
            {"id": "mono-raw-24", "source": fixture_paths["mono"], "stream": 0, "mode": "Raw", "bits": 24, "channels": 1, "seconds": 36.0, "kind": "eligible"},
            {"id": "downmix-raw-16", "source": fixture_paths["stereo"], "stream": 0, "mode": "Raw", "bits": 16, "channels": 1, "seconds": 36.0, "kind": "downmix_constraint", "mono": True},
            {"id": "high-lra-zoom-16", "source": fixture_paths["high_lra"], "stream": 0, "mode": "Zoom", "bits": 16, "channels": 1, "seconds": 36.0, "kind": "high_lra"},
            {"id": "peaks-zoom-24", "source": fixture_paths["peaks"], "stream": 0, "mode": "Zoom", "bits": 24, "channels": 1, "seconds": 36.0, "kind": "peaks"},
            {"id": "silence-raw-16", "source": fixture_paths["silence"], "stream": 0, "mode": "Raw", "bits": 16, "channels": 1, "seconds": 3.0, "kind": "silence"},
            {"id": "short-zoom-16", "source": fixture_paths["short"], "stream": 0, "mode": "Zoom", "bits": 16, "channels": 1, "seconds": 0.2, "kind": "short"},
        ]
        if args.selected_cases:
            unknown = set(args.selected_cases) - {config["id"] for config in configs}
            if unknown:
                raise ValueError("Unknown matrix case IDs: " + ", ".join(sorted(unknown)))
            configs = [config for config in configs if config["id"] in args.selected_cases]
        expected_cases = len(configs) * (1 if args.shell else 2)
        previous_pcm = {}
        for shell_name, prefix, culture in (("powershell.exe", "ps51", "en-US"), ("pwsh.exe", "ps7", "de-DE")):
            if args.shell and prefix != args.shell:
                continue
            shell = shutil.which(shell_name)
            if shell is None:
                raise RuntimeError(f"Required shell not found: {shell_name}")
            result = checked(prefix + "-version", [shell, "-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"])
            summary["environment"][prefix] = result["stdout"].strip()
            for config in configs:
                case_id = prefix + "-" + config["id"]
                destination = output / case_id
                destination.mkdir()
                command = [shell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", wrapper,
                           "-Application", repo / "WinAudioClean.ps1", "-Source", config["source"], "-Destination", destination,
                           "-Ffmpeg", ffmpeg, "-Ffprobe", ffprobe, "-Culture", culture,
                           "-Mode", config["mode"], "-Bits", config["bits"], "-StreamIndex", config["stream"]]
                if config.get("mono"):
                    command += ["-Mono"]
                result = run(case_id, command)
                audio_paths = list(destination.glob("*_Cleaned_*.wav"))
                report_paths = list(destination.glob("WinAudioClean_*.json"))
                partials = list(destination.glob(".wac-*.partial"))
                case = {"id": case_id, "culture": culture, "config": {k: str(v) if isinstance(v, Path) else v for k, v in config.items()},
                        "exit_code": result["exit_code"], "final_count": len(audio_paths), "report_count": len(report_paths),
                        "partial_count": len(partials), "passed": not result["timed_out"] and len(audio_paths) == 1
                        and len(report_paths) == 1 and not partials and "WAC_HARNESS_CULTURE:" + culture in result["stdout"]}
                if len(audio_paths) == 1:
                    case["audio"] = inspect_audio(case_id, audio_paths[0], config["channels"], config["bits"], config["seconds"])
                    case["passed"] &= case["audio"]["passed"]
                    if config["kind"] == "eligible":
                        case["passed"] &= case["audio"]["independent_compliant"]
                    pcm_hash = case["audio"]["decoded_pcm_sha256"]
                    if config["id"] in previous_pcm:
                        case["same_pcm_across_shell_and_locale"] = pcm_hash == previous_pcm[config["id"]]
                        case["passed"] &= case["same_pcm_across_shell_and_locale"]
                    previous_pcm[config["id"]] = pcm_hash
                if len(report_paths) == 1 and "audio" in case:
                    prechain = ("pan=mono|c0=0.5*c0+0.5*c1," if config.get("mono") else "") + prechains[config["mode"]] + ",aresample=192000"
                    case["report"] = inspect_report(report_paths[0], config, case["audio"], prechain)
                    case["passed"] &= case["report"]["passed"] and case["exit_code"] == case["report"]["application_exit_code"]
                summary["cases"].append(case)
                print(f"{case_id}: {'PASS' if case['passed'] else 'FAIL'}", flush=True)
        summary["fixtures_unchanged"] = all(sha256(repo / fixture["path"]) == fixture["sha256"] for fixture in summary["fixtures"])
        summary["source_sha256_after"] = source_hashes()
        summary["sources_unchanged_during_run"] = summary["source_sha256_before"] == summary["source_sha256_after"]
        summary["status"] = "pass" if (len(summary["cases"]) == expected_cases and all(case["passed"] for case in summary["cases"])
                                            and summary["fixtures_unchanged"] and summary["sources_unchanged_during_run"]) else "fail"
        return 0 if summary["status"] == "pass" else 1
    except Exception as error:
        summary["status"] = "error"
        summary["error"] = str(error)
        print(sanitize(str(error)), file=sys.stderr)
        return 1
    finally:
        summary["source_sha256_after"] = source_hashes()
        summary["sources_unchanged_during_run"] = summary["source_sha256_before"] == summary["source_sha256_after"]
        evidence = output / "summary.json"
        evidence.write_text(json.dumps(sanitize(summary), indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
        print(f"Evidence: {sanitize(str(evidence))}", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
