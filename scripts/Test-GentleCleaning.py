#!/usr/bin/env python3
"""Windows synthetic evidence for optional Gentle and typed cleaning settings.

Development-only standard-library Python, existing FFmpeg/ffprobe, and both
PowerShell hosts. Ignored disposable app copies capture native arguments and
delegate unchanged to the original native helper. No speech listening occurs.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys


RATE = 48000
TARGET = "loudnorm=I=-12:TP=-1.5:LRA=7"
LEVEL = "dynaudnorm=f=200:g=11:p=0.85:m=20:s=12"
FAST_TARGET = "loudnorm=I=-12:TP=-1.5"
METRICS = {"integratedLufs": "input_i", "truePeakDbtp": "input_tp", "loudnessRangeLu": "input_lra"}
CAPTURE = r'''# Development evidence only: capture argv, delegate unchanged.
$script:WacEvidenceOriginalNative = ${function:Invoke-WacNativeProcess}
function Invoke-WacNativeProcess {
    param([string]$FilePath, [AllowEmptyCollection()][string[]]$ArgumentList = @(),
        [int]$TimeoutMilliseconds = 0, [int]$StreamCloseTimeoutMilliseconds = 5000,
        [System.IO.Stream]$StandardInputStream)
    $record = [ordered]@{ executable = $FilePath; arguments = @($ArgumentList)
        inputStream = ($null -ne $StandardInputStream)
        timeoutMilliseconds = $TimeoutMilliseconds }
    $capturePath = Join-Path $env:WAC_EVIDENCE_CAPTURE ([guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($capturePath, ($record | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    & $script:WacEvidenceOriginalNative @PSBoundParameters
}

'''
DEFAULTS = {
    "Original": {"schemaVersion": 1, "Declip": True, "Declick": True, "Denoise": True, "Gate": True,
                 "HighpassHz": 80, "NoiseFloorDb": -25, "NoiseReductionDb": 12,
                 "GateThresholdDb": -45, "GateRangeDb": -25},
    "Gentle": {"schemaVersion": 1, "Declip": False, "Declick": False, "Denoise": True, "Gate": False,
               "HighpassHz": 60, "NoiseFloorDb": -35, "NoiseReductionDb": 6,
               "GateThresholdDb": -45, "GateRangeDb": -25},
}


def ps_quote(value) -> str:
    """Quote path data for a PowerShell single-quoted literal."""
    return "'" + str(value).replace("'", "''") + "'"


def ps_options(options: dict) -> str:
    values = []
    for key, value in options.items():
        literal = ("$true" if value else "$false") if isinstance(value, bool) else "[double]" + str(value)
        values.append(key + "=" + literal)
    return "@{" + ";".join(values) + "}"


def argument(arguments, name):
    return arguments[arguments.index(name) + 1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--ffprobe", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--case", action="append", dest="selected_cases")
    parser.add_argument("--shell", choices=("ps51", "ps7"))
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    helper_path = repo / "scripts/Test-MeasuredLoudness.py"
    spec = importlib.util.spec_from_file_location("wac_measured_helpers", helper_path)
    helpers = importlib.util.module_from_spec(spec)
    previous_bytecode_policy = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(helpers)
    finally:
        sys.dont_write_bytecode = previous_bytecode_policy
    sha256 = helpers.sha256
    ffmpeg, ffprobe = args.ffmpeg.resolve(strict=True), args.ffprobe.resolve(strict=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = (args.output or repo / ".wac-local/WAC-M2-03" / stamp).resolve()
    if not output.is_relative_to((repo / ".wac-local").resolve()):
        parser.error("--output must be inside this repository's .wac-local folder")
    output.mkdir(parents=True, exist_ok=False)
    fixtures, references, application = output / "fixtures", output / "references", output / "app"
    for folder in (fixtures, references, application):
        folder.mkdir()
    baseline = repo / "docs/codex/winaudioclean/BASELINE.json"
    sources = [repo / "WinAudioClean.ps1", repo / "WinAudioClean.IO.ps1", Path(__file__).resolve(), helper_path, baseline]

    def sanitize(value):
        if isinstance(value, str):
            for original, replacement in ((str(repo), "<repo>"), (str(Path.home()), "<user-profile>")):
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
        "task": "WAC-M2-03", "created_utc": stamp,
        "notice": "Synthetic filter/stream/encoding mechanics only; no listening, speech-quality approval, independent meter calibration or default-sound promotion.",
        "environment": {"platform": platform.platform(), "python": platform.python_version(), "child_psmodulepath_removed": True},
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "source_sha256_before": source_hashes(), "harness_invocation": sys.orig_argv,
        "scope": {"selected_cases": args.selected_cases, "shell": args.shell, "full_matrix": not args.selected_cases and not args.shell},
        "tools": {name: {"path": str(path), "sha256": sha256(path)} for name, path in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe))},
        "fixtures": [], "references": [], "cases": [], "commands": [],
    }

    def run(label, command, binary=False, env=None):
        command = [str(item) for item in command]
        started = dt.datetime.now(dt.timezone.utc)
        process = subprocess.Popen(command, cwd=repo, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=env or clean_env)
        timed_out = False
        try:
            stdout, stderr = process.communicate(timeout=180)
        except subprocess.TimeoutExpired:
            timed_out = True
            helpers.stop_owned_process_tree(process)
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

    def inspect_audio(label, path, config):
        streams = json.loads(checked("probe-" + label, [ffprobe, "-v", "error", "-show_streams", "-of", "json", path])["stdout"])["streams"]
        if len(streams) != 1:
            raise ValueError("Expected exactly one output stream")
        stream = streams[0]
        bits, channels, seconds = config["bits"], config["channels"], config["seconds"]
        decoded = checked("decode-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", path,
                                             "-map", "0:a:0", "-c:a", f"pcm_s{bits}le", "-f", f"s{bits}le", "-"], True)["stdout"]
        measured = checked("measure-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-i", path, "-map", "0:a:0",
                                               "-af", TARGET + ":print_format=json", "-f", "null", "NUL"])
        stats = helpers.parse_stats(measured["stderr"])
        values = {name: helpers.finite_value(stats[source]) for name, source in METRICS.items()}
        expected_bytes = round(seconds * RATE) * channels * bits // 8
        checks = {
            "codec": stream["codec_name"] == f"pcm_s{bits}le", "sample_rate": int(stream["sample_rate"]) == RATE,
            "channels": stream["channels"] == channels, "bit_depth": int(stream["bits_per_sample"]) == bits,
            "duration": abs(float(stream["duration"]) - seconds) <= 0.01,
            "pcm_duration": abs(len(decoded) - expected_bytes) <= round(0.01 * RATE) * channels * bits // 8,
            "complete_frames": len(decoded) > 0 and len(decoded) % (channels * bits // 8) == 0,
            "finite_meter": all(value is not None for value in values.values()),
        }
        return {**file_record(path), "probe": {key: stream.get(key) for key in ("codec_name", "sample_rate", "channels", "bits_per_sample", "channel_layout", "duration")},
                "decoded_pcm_sha256": hashlib.sha256(decoded).hexdigest(), "decoded_pcm_bytes": len(decoded),
                "independent_metrics": values, "independent_raw_stats": stats, "checks": checks, "passed": all(checks.values())}

    def inspect_report(path, config, audio, captured):
        def reject_constant(value):
            raise ValueError("Nonfinite JSON numeric constant: " + value)

        report = json.loads(path.read_text(encoding="utf-8-sig"), parse_constant=reject_constant)
        settings, normalization = report["settings"], report["normalization"]
        expected_settings = dict(DEFAULTS[config["preset"]], **config["options"])
        expected_filter = config["chain"] + "," + FAST_TARGET
        if config.get("mono"):
            expected_filter = "pan=mono|c0=0.5*c0+0.5*c1," + expected_filter
        expected_format = {"sampleRate": RATE, "bitDepth": config["bits"], "codec": f"pcm_s{config['bits']}le",
                           "channels": config["channels"], "channelLayout": "mono" if config["channels"] == 1 else "stereo", "container": "RIFF"}
        text_path, summary_path = path.with_suffix(".txt"), path.parent / "WinAudioClean_Log.txt"
        text = text_path.read_text(encoding="utf-8-sig")
        checks = {
            "identity": report["schemaVersion"] == 1 and report["presetId"] == config["preset"].lower()
                        and report["presetVersion"] == ("0.1.0" if config["preset"] == "Gentle" else "1.0.0"),
            "experimental": report["presetExperimental"] is (config["preset"] == "Gentle"),
            "customized": report["presetCustomized"] is bool(config["options"]),
            "effective_cleaning": settings["cleaning"] == expected_settings,
            "cleaning_types": all(type(settings["cleaning"][key]) is bool for key in ("Declip", "Declick", "Denoise", "Gate"))
                              and all(type(settings["cleaning"][key]) in (int, float) and math.isfinite(settings["cleaning"][key])
                                      for key in ("HighpassHz", "NoiseFloorDb", "NoiseReductionDb", "GateThresholdDb", "GateRangeDb")),
            "mode_stream": settings["mode"] == "Raw" and settings["loudnessMode"] == config["loudness"]
                           and report["input"]["stream"]["index"] == config["stream"],
            "format": report["output"]["format"] == expected_format,
            "targets": report["requestedTargets"] == {"integratedLufs": -12, "truePeakDbtp": -1.5, "loudnessRangeLu": 7},
            "dependency": Path(report["dependencies"]["ffmpeg"]["path"]).resolve() == ffmpeg,
            "summary": text.strip() in summary_path.read_text(encoding="utf-8-sig"),
            "native_success": report["nativeExitCode"] == 0 and report["processingStatus"] == "SUCCESS"
                              and report["output"]["published"] and report["reporting"]["complete"],
        }
        render_commands = [record for record in captured if "-af" in record["arguments"] and "-c:a" in record["arguments"]]
        checks["one_actual_render"] = len(render_commands) == 1
        render_args = render_commands[0]["arguments"] if len(render_commands) == 1 else []
        if render_args:
            checks["actual_render_map"] = argument(render_args, "-map") == "0:" + str(config["stream"])
            checks["actual_render_channels"] = argument(render_args, "-ac") == str(config["channels"])
            checks["actual_render_filter"] = argument(render_args, "-af") == settings["exactFilters"]
        stages = {}
        if config["loudness"] == "Fast":
            checks["fast_filters"] = settings["exactFilters"] == expected_filter
            checks["fast_no_analysis"] = len([r for r in captured if "-af" in r["arguments"]]) == 1
            checks["fast_no_measurement_stages"] = all(normalization[name] is None for name in ("analysis", "render", "final"))
            checks["fast_not_measured"] = report["loudnessCompliance"] == {"status": "NOT_MEASURED", "reason": "no_independent_measurement"}
            checks["fast_metrics"] = all(report["measurements"][name] == {"value": None, "reason": "not_measured"} for name in METRICS)
            checks["fast_outcome"] = report["status"] == "SUCCESS" and report["applicationExitCode"] == 0
        else:
            prechain = expected_filter.rsplit(",loudnorm=", 1)[0] + ",aresample=192000"
            checks["prechain"] = normalization["prechain"] == prechain
            checks["analysis_filter"] = normalization["analysisFilter"] == prechain + "," + TARGET + ":print_format=json"
            checks["render_prechain"] = normalization["renderFilter"].startswith(prechain + "," + TARGET + ":") and normalization["renderFilter"].count("loudnorm=") == 1
            checks["effective_filter"] = settings["exactFilters"] == normalization["renderFilter"]
            checks["final_filter"] = normalization["finalMeasurementFilter"] == TARGET + ":print_format=json"
            for name in ("analysis", "render", "final"):
                stage = normalization[name]
                process = stage["process"]
                stats = helpers.parse_stats(process["StandardError"])
                argv = stage["arguments"]
                recorded = [record for record in captured if record["arguments"] == argv]
                stage_checks = {
                    "success": stage["status"] == "PASSED" and process["Started"] and process["ExitCode"] == 0
                               and not process["TimedOut"] and not process["Error"] and not process["CleanupError"] and not stage["error"],
                    "actual_arguments": len(recorded) == 1,
                    "actual_type": stage["measurement"]["NormalizationType"] == stats["normalization_type"],
                    "effective_filter": argument(argv, "-af") == normalization[name + "Filter"] if name != "final" else argument(argv, "-af") == normalization["finalMeasurementFilter"],
                }
                if name == "final":
                    stage_checks["held_output_only"] = stage["inputSource"] == "held_output_stream" and argument(argv, "-i") == "pipe:0" and argument(argv, "-map") == "0:0" and len(recorded) == 1 and recorded[0]["inputStream"]
                else:
                    stage_checks["selected_source"] = argument(argv, "-map") == "0:" + str(config["stream"]) and Path(argument(argv, "-i")).resolve() == config["source"].resolve()
                    stage_checks["channel_policy"] = argument(argv, "-ac") == str(config["channels"]) and argument(argv, "-channel_layout") == expected_format["channelLayout"]
                stages[name] = {"arguments": argv, "measurement": stage["measurement"], "raw_stats": stats, "checks": stage_checks, "passed": all(stage_checks.values())}
            checks["stages"] = all(stage["passed"] for stage in stages.values())
            analysis, render = normalization["analysis"]["measurement"], normalization["render"]["measurement"]
            render_values = dict(item.split("=", 1) for item in normalization["renderFilter"].split("loudnorm=", 1)[1].split(":"))
            measured_keys = {"measured_I": "InputI", "measured_TP": "InputTP", "measured_LRA": "InputLRA", "measured_thresh": "InputThreshold", "offset": "TargetOffset"}
            checks["measured_parameters"] = analysis["Available"] and normalization["linearRequested"] and render_values["linear"] == "true" and all(float(render_values[key]) == analysis[value] for key, value in measured_keys.items())
            checks["observed_type"] = normalization["actualType"] == render["NormalizationType"]
            expected_fallback = "ffmpeg_dynamic_fallback" if render["NormalizationType"] == "dynamic" else None
            checks["fallback"] = normalization["fallbackReason"] == expected_fallback
            metrics = audio["independent_metrics"]
            if metrics["truePeakDbtp"] > -1.3:
                compliance, reason = "OUT_OF_TOLERANCE", "true_peak_exceeded"
            elif abs(metrics["integratedLufs"] + 12) > 0.5:
                compliance, reason = "OUT_OF_TOLERANCE", "loudness_out_of_tolerance"
            else:
                compliance, reason = "PASSED", None
            checks["compliance"] = report["loudnessCompliance"] == {"status": compliance, "reason": reason}
            checks["final_metrics"] = all(report["measurements"][name] == {"value": value, "reason": None} for name, value in metrics.items())
            warning = expected_fallback is not None or compliance != "PASSED"
            checks["accurate_outcome"] = report["status"] == ("WARNING" if warning else "SUCCESS") and report["applicationExitCode"] == (7 if warning else 0) and bool(report["warningCodes"]) == warning
        return {**file_record(path), "text": file_record(text_path), "summary": file_record(summary_path),
                "preset_id": report["presetId"], "preset_version": report["presetVersion"], "settings": settings,
                "preset_experimental": report["presetExperimental"], "preset_customized": report["presetCustomized"],
                "format": report["output"]["format"], "measurements": report["measurements"], "loudness_compliance": report["loudnessCompliance"],
                "application_exit_code": report["applicationExitCode"], "status": report["status"], "stages": stages,
                "checks": checks, "passed": all(checks.values())}

    try:
        source = (repo / "WinAudioClean.ps1").read_text(encoding="utf-8-sig")
        marker = "# --- CONFIGURATION ---"
        if source.count(marker) != 1:
            raise ValueError("Expected exactly one disposable capture insertion marker")
        copied_app = application / "WinAudioClean.ps1"
        copied_app.write_text(source.replace(marker, CAPTURE + marker), encoding="utf-8-sig")
        copied_io = application / "WinAudioClean.IO.ps1"
        shutil.copyfile(repo / "WinAudioClean.IO.ps1", copied_io)
        summary["instrumentation"] = {"seam": "Disposable app capture before CONFIGURATION; Invoke-WacNativeProcess delegates unchanged with PSBoundParameters.",
                                      "insertion_source": CAPTURE, "insertion_sha256": hashlib.sha256(CAPTURE.encode()).hexdigest(),
                                      "app_copy": file_record(copied_app), "io_copy": file_record(copied_io)}
        for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe)):
            summary["tools"][name]["version"] = checked(name + "-version", [tool, "-version"])["stdout"].splitlines()[0]
        fixture_paths = {}
        for name, channels in (("stereo", 2), ("mono", 1)):
            path = fixtures / (name + ".wav")
            summary["fixtures"].append({"path": str(path.relative_to(repo)), **helpers.create_fixture(path, channels, 12.0, "eligible")})
            fixture_paths[name] = path
        selected = fixtures / "selected-stream.mkv"
        checked("mux-selected-stream", [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", fixture_paths["mono"], "-i", fixture_paths["stereo"],
                                       "-map", "0:a:0", "-map", "1:a:0", "-c:a", "copy", selected])
        summary["fixtures"].append({"id": "selected-stream", **file_record(selected), "seconds": 12.0,
                                    "description": "Unselected absolute stream 0 mono; selected absolute stream 1 stereo."})
        configs = [
            {"id": "gentle-fast-stereo16", "preset": "Gentle", "loudness": "Fast", "source": fixture_paths["stereo"], "stream": 0, "channels": 2, "bits": 16, "options": {}, "chain": "highpass=f=60,afftdn=nf=-35:nr=6," + LEVEL},
            {"id": "gentle-accurate-stereo24", "preset": "Gentle", "loudness": "Accurate", "source": fixture_paths["stereo"], "stream": 0, "channels": 2, "bits": 24, "options": {}, "chain": "highpass=f=60,afftdn=nf=-35:nr=6," + LEVEL},
            {"id": "gentle-fast-mono24", "preset": "Gentle", "loudness": "Fast", "source": fixture_paths["mono"], "stream": 0, "channels": 1, "bits": 24, "options": {}, "chain": "highpass=f=60,afftdn=nf=-35:nr=6," + LEVEL},
            {"id": "gentle-accurate-downmix16", "preset": "Gentle", "loudness": "Accurate", "source": fixture_paths["stereo"], "stream": 0, "channels": 1, "bits": 16, "mono": True, "options": {}, "chain": "highpass=f=60,afftdn=nf=-35:nr=6," + LEVEL},
            {"id": "original-disabled-fast-selected16", "preset": "Original", "loudness": "Fast", "source": selected, "stream": 1, "channels": 2, "bits": 16, "options": {"Declip": False, "Declick": False, "Denoise": False, "Gate": False}, "chain": "highpass=f=80," + LEVEL},
            {"id": "gentle-lower-accurate-mono16", "preset": "Gentle", "loudness": "Accurate", "source": fixture_paths["mono"], "stream": 0, "channels": 1, "bits": 16, "options": {"Declip": True, "Declick": True, "Gate": True, "HighpassHz": 20, "NoiseFloorDb": -80, "NoiseReductionDb": 0.01, "GateThresholdDb": -80, "GateRangeDb": -60}, "chain": "adeclip,highpass=f=20,adeclick,afftdn=nf=-80:nr=0.01,agate=range=0.001:threshold=0.0001," + LEVEL},
            {"id": "gentle-upper-fast-selected24", "preset": "Gentle", "loudness": "Fast", "source": selected, "stream": 1, "channels": 2, "bits": 24, "options": {"Declip": True, "Declick": True, "Gate": True, "HighpassHz": 200, "NoiseFloorDb": -20, "NoiseReductionDb": 20, "GateThresholdDb": -20, "GateRangeDb": 0}, "chain": "adeclip,highpass=f=200,adeclick,afftdn=nf=-20:nr=20,agate=range=1:threshold=0.1," + LEVEL},
            {"id": "gentle-fractional-accurate-selected24", "preset": "Gentle", "loudness": "Accurate", "source": selected, "stream": 1, "channels": 2, "bits": 24, "options": {"Gate": True, "HighpassHz": 61.5, "NoiseFloorDb": -35.25, "NoiseReductionDb": 6.125, "GateThresholdDb": -40, "GateRangeDb": -20}, "chain": "highpass=f=61.5,afftdn=nf=-35.25:nr=6.125,agate=range=0.1:threshold=0.01," + LEVEL},
        ]
        for config in configs:
            config["seconds"] = 12.0
        if args.selected_cases:
            unknown = set(args.selected_cases) - {config["id"] for config in configs}
            if unknown:
                raise ValueError("Unknown matrix case IDs: " + ", ".join(sorted(unknown)))
            configs = [config for config in configs if config["id"] in args.selected_cases]
        reference_pcm = {}
        for config in configs:
            if config["loudness"] != "Fast":
                continue
            path = references / (config["id"] + ".wav")
            filters = config["chain"] + "," + FAST_TARGET
            checked("reference-" + config["id"], [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", config["source"],
                    "-map", "0:" + str(config["stream"]), "-vn", "-af", filters, "-ar", RATE, "-c:a", f"pcm_s{config['bits']}le", "-ac", config["channels"],
                    "-channel_layout", "mono" if config["channels"] == 1 else "stereo", "-map_metadata", "-1", "-map_chapters", "-1", "-f", "wav", "-rf64", "never", path])
            record = inspect_audio("reference-" + config["id"], path, config)
            summary["references"].append(record)
            reference_pcm[config["id"]] = record["decoded_pcm_sha256"]
        previous_pcm = {}
        expected_cases = len(configs) * (1 if args.shell else 2)
        for shell_name, prefix, culture in (("powershell.exe", "ps51", "en-US"), ("pwsh.exe", "ps7", "de-DE")):
            if args.shell and args.shell != prefix:
                continue
            shell = shutil.which(shell_name)
            if shell is None:
                raise RuntimeError("Required shell not found: " + shell_name)
            summary["environment"][prefix] = checked(prefix + "-version", [shell, "-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"])["stdout"].strip()
            for config in configs:
                case_id = prefix + "-" + config["id"]
                destination, capture = output / case_id, output / (case_id + "-argv")
                destination.mkdir()
                capture.mkdir()
                invocation = "& " + ps_quote(copied_app) + " -inputPath " + ps_quote(config["source"]) + " -OutputDirectory " + ps_quote(destination)
                invocation += " -FfmpegPath " + ps_quote(ffmpeg) + " -FfprobePath " + ps_quote(ffprobe)
                invocation += f" -Mode Raw -Preset {config['preset']} -LoudnessMode {config['loudness']} -BitDepth {config['bits']} -AudioStreamIndex {config['stream']} -NonInteractive"
                if config["options"]:
                    invocation += " -CleaningOptions " + ps_options(config["options"])
                if config.get("mono"):
                    invocation += " -Mono"
                ps_command = "$cultureInfo=[Globalization.CultureInfo]::GetCultureInfo(" + ps_quote(culture) + "); [Threading.Thread]::CurrentThread.CurrentCulture=$cultureInfo; [Threading.Thread]::CurrentThread.CurrentUICulture=$cultureInfo; Write-Host ('WAC_HARNESS_CULTURE:' + [Threading.Thread]::CurrentThread.CurrentCulture.Name); " + invocation + "; exit $LASTEXITCODE"
                result = run(case_id, [shell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_command], env=dict(clean_env, WAC_EVIDENCE_CAPTURE=str(capture)))
                audio_paths, report_paths, partials = list(destination.glob("*_Cleaned_*.wav")), list(destination.glob("WinAudioClean_*.json")), list(destination.glob(".wac-*.partial"))
                captured = [json.loads(path.read_text(encoding="utf-8-sig")) for path in sorted(capture.glob("*.json"))]
                case = {"id": case_id, "culture": culture, "config": {key: str(value) if isinstance(value, Path) else value for key, value in config.items()},
                        "exit_code": result["exit_code"], "final_count": len(audio_paths), "report_count": len(report_paths), "partial_count": len(partials),
                        "captured_commands": captured, "capture_files": [file_record(path) for path in sorted(capture.glob("*.json"))],
                        "passed": not result["timed_out"] and len(audio_paths) == 1 and len(report_paths) == 1 and not partials and "WAC_HARNESS_CULTURE:" + culture in result["stdout"]}
                if len(audio_paths) == 1:
                    case["audio"] = inspect_audio(case_id, audio_paths[0], config)
                    case["passed"] &= case["audio"]["passed"]
                    pcm_hash = case["audio"]["decoded_pcm_sha256"]
                    if config["id"] in previous_pcm:
                        case["same_pcm_across_shell_and_locale"] = pcm_hash == previous_pcm[config["id"]]
                        case["passed"] &= case["same_pcm_across_shell_and_locale"]
                    previous_pcm[config["id"]] = pcm_hash
                    if config["loudness"] == "Fast":
                        case["zero_lag_pcm_equal_to_direct_reference"] = pcm_hash == reference_pcm[config["id"]]
                        case["passed"] &= case["zero_lag_pcm_equal_to_direct_reference"]
                if len(report_paths) == 1 and "audio" in case:
                    case["report"] = inspect_report(report_paths[0], config, case["audio"], captured)
                    case["passed"] &= case["report"]["passed"] and result["exit_code"] == case["report"]["application_exit_code"]
                summary["cases"].append(case)
                print(case_id + (": PASS" if case["passed"] else ": FAIL"), flush=True)
        summary["fixtures_unchanged"] = all(sha256(repo / fixture["path"]) == fixture["sha256"] for fixture in summary["fixtures"])
        summary["source_sha256_after"] = source_hashes()
        summary["sources_unchanged_during_run"] = summary["source_sha256_before"] == summary["source_sha256_after"]
        summary["instrumented_copies_unchanged"] = sha256(copied_app) == summary["instrumentation"]["app_copy"]["sha256"] and sha256(copied_io) == summary["instrumentation"]["io_copy"]["sha256"]
        summary["status"] = "pass" if len(summary["cases"]) == expected_cases and all(case["passed"] for case in summary["cases"]) and all(record["passed"] for record in summary["references"]) and summary["fixtures_unchanged"] and summary["sources_unchanged_during_run"] and summary["instrumented_copies_unchanged"] else "fail"
        return 0 if summary["status"] == "pass" else 1
    except Exception as error:
        summary["status"], summary["error"] = "error", str(error)
        print(sanitize(str(error)), file=sys.stderr)
        return 1
    finally:
        summary["source_sha256_after"] = source_hashes()
        summary["sources_unchanged_during_run"] = summary["source_sha256_before"] == summary["source_sha256_after"]
        evidence = output / "summary.json"
        evidence.write_text(json.dumps(sanitize(summary), indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
        print("Evidence: " + sanitize(str(evidence)), flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
