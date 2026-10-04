#!/usr/bin/env python3
"""Development-only, report-driven synthetic audio reproduction on Windows.

The app creates local reports in both PowerShell hosts. Direct pinned FFmpeg
then rebuilds outputs from the report's typed settings and measured parameters,
not the seed case's profile. Audio, full reports and raw logs stay ignored.
Only scalar proof, hashes and commands with opaque file aliases are shareable.
"""

from __future__ import annotations

import argparse
import datetime as dt
from decimal import Decimal
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
LEVEL = "dynaudnorm=f=200:g=11:p=0.85:m=20:s=12"
TOGGLES = ("Declip", "Declick", "Denoise", "Gate")
BOUNDS = {"HighpassHz": (20, 200), "NoiseFloorDb": (-80, -20), "NoiseReductionDb": (0.01, 20),
          "GateThresholdDb": (-80, -20), "GateRangeDb": (-60, 0)}
MEASURED = {"InputI": ("measured_I", -99, 0), "InputTP": ("measured_TP", -99, 99),
            "InputLRA": ("measured_LRA", 0, 99), "InputThreshold": ("measured_thresh", -99, 0),
            "TargetOffset": ("offset", -99, 99)}
METRICS = {"integratedLufs": "InputI", "truePeakDbtp": "InputTP", "loudnessRangeLu": "InputLRA"}
ROLES = ("Original", "Processed", "CompareOriginal", "CompareProcessed")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def number(value):
    require(type(value) in (int, float) and math.isfinite(value), "Expected a finite JSON number")
    return value


def literal(value):
    # Report JSON may preserve binary subtraction noise (e.g. -11.899999999999999)
    # beyond the application's invariant filter formatter's meaningful digits.
    text = format(Decimal(format(number(value), ".15g")), "f")
    return text.rstrip("0").rstrip(".") if "." in text else text


def parameters(token):
    parts = token.split(":")
    pairs = [item.split("=", 1) for item in parts]
    require(all(len(pair) == 2 for pair in pairs), "Invalid filter parameter record")
    require(len({pair[0] for pair in pairs}) == len(pairs), "Duplicate filter parameter")
    return dict(pairs)


def profile_from_report(report):
    """Versioned application recipe plus typed effective report values only."""
    settings = report["settings"]
    require(report["schemaVersion"] == 1 and report["toolVersion"] == "2.3", "Unsupported report/application version")
    identity = report["presetId"]
    require(identity in ("original", "gentle"), "Unsupported base preset")
    require(report["presetVersion"] == ("1.0.0" if identity == "original" else "0.1.0"), "Unsupported preset version")
    require(report["presetName"] == ("Original" if identity == "original" else "Gentle (experimental)"), "Inconsistent preset name")
    require(report["presetExperimental"] is (identity == "gentle") and type(report["presetCustomized"]) is bool,
            "Inconsistent candidate/customization flags")
    require(settings["mode"] in ("Raw", "Zoom"), "Unsupported mode")
    require(settings["loudnessMode"] in ("Fast", "Accurate"), "Unsupported loudness mode")
    require(type(settings["mono"]) is bool and type(settings["rf64"]) is bool, "Invalid output policy booleans")
    stages = []
    cleaning = settings["cleaning"]
    if settings["mode"] == "Raw":
        require(type(cleaning) is dict and set(cleaning) == {"schemaVersion", *TOGGLES, *BOUNDS}, "Invalid cleaning schema")
        require(type(cleaning["schemaVersion"]) is int and cleaning["schemaVersion"] == 1, "Invalid cleaning version")
        for key in TOGGLES:
            require(type(cleaning[key]) is bool, "Invalid stage toggle")
        for key, bounds in BOUNDS.items():
            require(bounds[0] <= number(cleaning[key]) <= bounds[1], "Cleaning setting outside contract")
        if not report["presetCustomized"]:
            gentle = identity == "gentle"
            base = {"schemaVersion": 1, "Declip": not gentle, "Declick": not gentle, "Denoise": True, "Gate": not gentle,
                    "HighpassHz": 60 if gentle else 80, "NoiseFloorDb": -35 if gentle else -25,
                    "NoiseReductionDb": 6 if gentle else 12, "GateThresholdDb": -45, "GateRangeDb": -25}
            require(cleaning == base, "Unmarked customized effective settings")
        if cleaning["Declip"]:
            stages.append("adeclip")
        stages.append("highpass=f=" + literal(cleaning["HighpassHz"]))
        if cleaning["Declick"]:
            stages.append("adeclick")
        if cleaning["Denoise"]:
            denoise = "afftdn=nf=" + literal(cleaning["NoiseFloorDb"])
            if identity == "gentle" or cleaning["NoiseFloorDb"] != -25 or cleaning["NoiseReductionDb"] != 12:
                denoise += ":nr=" + literal(cleaning["NoiseReductionDb"])
            stages.append(denoise)
        if cleaning["Gate"]:
            def gate(db, default_db, rounded):
                return rounded if db == default_db else format(10 ** (db / 20), ".15f").rstrip("0").rstrip(".")
            stages.append("agate=range=" + gate(cleaning["GateRangeDb"], -25, "0.056")
                          + ":threshold=" + gate(cleaning["GateThresholdDb"], -45, "0.0056"))
    else:
        require(cleaning is None and identity == "original" and not report["presetCustomized"], "Invalid Zoom choices")
    # Schema 1 has no leveling knobs: the application-2.3 recipe is fixed.
    stages.append(LEVEL)
    stages.append("loudnorm=I=-12:TP=-1.5")
    return ",".join(stages)


def measurement(stats, seconds):
    def finite(key):
        value = float(stats[key])
        return value if math.isfinite(value) else None
    values = {"InputI": finite("input_i"), "InputTP": finite("input_tp"), "InputLRA": finite("input_lra"),
              "InputThreshold": finite("input_thresh"), "TargetOffset": finite("target_offset")}
    require(values["InputI"] is None or values["InputI"] <= 0, "Unsupported positive-integrated-loudness parser domain")
    reason = None
    if seconds < 1:
        reason = "too_short"
    elif values["InputI"] is None:
        reason = "silence" if values["InputTP"] is None else "undefined_loudness"
    if reason:
        values["InputI"] = values["InputLRA"] = None
    return dict(Available=reason is None, Reason=reason, **values, NormalizationType=stats["normalization_type"])


def metrics(measured):
    return {name: {"value": measured[key], "reason": measured["Reason"] if measured[key] is None else None}
            for name, key in METRICS.items()}


def accurate_from_report(report, profile, prefix):
    preview = report.get("reportType") == "preview"
    recorded = report["normalization"]
    analysis = report["stages"]["Analysis"] if preview else recorded["analysis"]
    require(analysis["status"] == "PASSED", "Recorded analysis did not pass")
    prechain = prefix + profile.rsplit(",loudnorm=", 1)[0] + ",aresample=192000"
    if preview:
        target_values = parameters(recorded["analysisFilter"].rsplit("loudnorm=", 1)[1])
        require(set(target_values) == {"I", "TP", "LRA", "print_format"} and target_values["print_format"] == "json",
                "Invalid Preview target record")
        targets = {key: float(target_values[key]) for key in ("I", "TP", "LRA")}
    else:
        targets = {"I": report["requestedTargets"]["integratedLufs"], "TP": report["requestedTargets"]["truePeakDbtp"],
                   "LRA": report["requestedTargets"]["loudnessRangeLu"]}
    normalizer = "loudnorm=" + ":".join(key + "=" + literal(targets[key]) for key in ("I", "TP", "LRA"))
    analysis_filter = prechain + "," + normalizer + ":print_format=json"
    measured = analysis["measurement"]
    require(type(measured["Available"]) is bool, "Invalid analysis availability")
    tail = normalizer + ":linear=false:print_format=json"
    linear = False
    planned_fallback = measured["Reason"]
    if measured["Available"]:
        require(measured["Reason"] is None, "Contradictory available analysis")
        outside = any(not low <= number(measured[key]) <= high for key, (_, low, high) in MEASURED.items())
        if outside:
            planned_fallback = "measurement_out_of_range"
        else:
            tail = normalizer + "".join(":" + item[0] + "=" + literal(measured[key]) for key, item in MEASURED.items())
            tail += ":linear=true:print_format=json"
            linear, planned_fallback = True, None
    else:
        require(measured["Reason"] in ("too_short", "silence", "undefined_loudness"), "Unclassified unavailable analysis")
    rebuilt = prechain + "," + tail
    require(recorded["prechain"] == prechain and recorded["analysisFilter"] == analysis_filter
            and recorded["renderFilter"] == rebuilt and recorded["linearRequested"] is linear,
            "Accurate graphs do not match effective settings/recorded measured values")
    render_stage = report["stages"]["Processed"]["normalization"] if preview else recorded["render"]
    observed = render_stage["measurement"]["NormalizationType"]
    fallback = "ffmpeg_dynamic_fallback" if linear and observed == "dynamic" else planned_fallback
    require(recorded["actualType"] == observed and recorded["fallbackReason"] == fallback, "Inconsistent actual normalization choice")
    return rebuilt, analysis_filter, measured, targets


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", required=True, type=Path)
    parser.add_argument("--ffprobe", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--case", action="append", dest="selected_cases")
    parser.add_argument("--shell", choices=("ps51", "ps7"))
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    helper_paths = [repo / "scripts/Test-MeasuredLoudness.py", repo / "scripts/Test-GentleCleaning.py"]
    loaded = []
    for index, path in enumerate(helper_paths):
        spec = importlib.util.spec_from_file_location("wac_reproduction_helper_" + str(index), path)
        module = importlib.util.module_from_spec(spec)
        previous = sys.dont_write_bytecode
        try:
            sys.dont_write_bytecode = True
            spec.loader.exec_module(module)
        finally:
            sys.dont_write_bytecode = previous
        loaded.append(module)
    helpers, common = loaded
    sha256 = helpers.sha256
    ffmpeg, ffprobe = args.ffmpeg.resolve(strict=True), args.ffprobe.resolve(strict=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = (args.output or repo / ".wac-local/WAC-M2-05" / stamp).resolve()
    require(output.is_relative_to((repo / ".wac-local").resolve()), "Scratch output must be inside .wac-local")
    output.mkdir(parents=True, exist_ok=False)
    for name in ("fixtures", "recreated", "logs"):
        (output / name).mkdir()
    sources = [repo / name for name in ("WinAudioClean.ps1", "WinAudioClean.IO.ps1", "WinAudioClean.Preview.ps1")]
    sources += [Path(__file__).resolve(), *helper_paths]
    clean_env = {key: value for key, value in os.environ.items() if key.upper() != "PSMODULEPATH"}
    aliases = {str(ffmpeg): "<ffmpeg>", str(ffprobe): "<ffprobe>", str(output): "<scratch>",
               str(repo): "<repo>", str(Path.home()): "<user-profile>"}

    def alias(path, name):
        aliases[str(path)] = "<" + name + ">"

    def sanitize(value):
        if isinstance(value, str):
            for original in sorted(aliases, key=len, reverse=True):
                for variant in (original, original.replace("\\", "/"), original.replace("\\", "\\\\")):
                    value = value.replace(variant, aliases[original])
            return value
        if isinstance(value, list):
            return [sanitize(item) for item in value]
        if isinstance(value, dict):
            return {key: sanitize(item) for key, item in value.items()}
        return value

    def source_hashes():
        return {path.relative_to(repo).as_posix(): sha256(path) for path in sources}

    summary = {"task": "WAC-M2-05", "acceptance": "AC-048", "created_utc": stamp,
               "notice": "Report-driven direct FFmpeg reproduction on synthetic inputs; no speech listening, independent meter calibration or cross-build guarantee.",
               "method": "The unchanged app produces local reports in two hosts. Replay ignores seed CLI choices and rebuilds graphs from each report. Leveling has the fixed application-2.3 recipe; exact reported graphs must agree before execution. Comparison WAVs use the recreated excerpts as binary stdin.",
               "path_policy": "Commands retain actual argument order/content with audio/report/log paths replaced by opaque aliases. The ignored scratch directory holds the full local artifacts. Aliases are linked by file hashes, not shareable media paths.",
               "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
               "source_sha256_before": source_hashes(), "harness_invocation": sys.orig_argv,
               "scope": {"selected_cases": args.selected_cases, "shell": args.shell, "full_matrix": not args.selected_cases and not args.shell},
               "environment": {"platform": platform.platform(), "python": platform.python_version(), "child_psmodulepath_removed": True},
               "tools": {name: {"id": name, "sha256": sha256(tool)} for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe))},
               "fixtures": [], "cases": [], "commands": [], "limitations": ["No audio/listening approval or default promotion.", "Positive integrated/threshold LUFS remains an unsupported fail-closed parser domain.", "Same-build exact PCM does not establish cross-build reproducibility or full-program Preview equivalence."]}
    immutable = {}

    def remember(path, name):
        alias(path, name)
        immutable[path] = sha256(path)
        return {"id": name, "sha256": immutable[path], "bytes": path.stat().st_size}

    def run(label, command, binary=False, stdin=None, stdin_id=None):
        started = dt.datetime.now(dt.timezone.utc)
        command = [str(item) for item in command]
        process = subprocess.Popen(command, cwd=repo, env=clean_env,
                                   stdin=subprocess.PIPE if stdin is not None else subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        timed_out = False
        try:
            stdout, stderr = process.communicate(input=stdin, timeout=240)
        except subprocess.TimeoutExpired:
            timed_out = True
            helpers.stop_owned_process_tree(process)
            stdout, stderr = process.communicate(timeout=10)
        record = {"id": label, "command": command, "exit_code": process.returncode, "timed_out": timed_out,
                  "elapsed_seconds": round((dt.datetime.now(dt.timezone.utc) - started).total_seconds(), 3)}
        if stdin is not None:
            record["binary_stdin"] = {"id": stdin_id, "bytes": len(stdin), "sha256": hashlib.sha256(stdin).hexdigest()}
        for name, data in (("stdout", stdout), ("stderr", stderr)):
            log = output / "logs" / (label + "-" + name + (".pcm" if binary and name == "stdout" else ".txt"))
            log.write_bytes(data)
            alias(log, "log:" + label + ":" + name)
            record[name + "_sha256"] = sha256(log)
            record[name + "_bytes"] = len(data)
        summary["commands"].append(record)
        return record, stdout if binary else stdout.decode("utf-8", errors="replace"), stderr.decode("utf-8", errors="replace")

    def checked(label, command, binary=False, stdin=None, stdin_id=None):
        result, stdout, stderr = run(label, command, binary, stdin, stdin_id)
        require(result["exit_code"] == 0 and not result["timed_out"], label + " failed")
        return stdout, stderr

    def inspect_audio(label, path, fmt):
        stdout, _ = checked("probe-" + label, [ffprobe, "-v", "error", "-show_streams", "-of", "json", path])
        streams = json.loads(stdout)["streams"]
        require(len(streams) == 1, "Expected one recreated/published audio stream")
        stream = streams[0]
        pcm, _ = checked("decode-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", path,
                           "-map", "0:a:0", "-c:a", fmt["codec"], "-f", "s" + str(fmt["bitDepth"]) + "le", "-"], True)
        block = fmt["channels"] * fmt["bitDepth"] // 8
        require(len(pcm) > 0 and len(pcm) % block == 0, "Incomplete decoded PCM frames")
        frames = len(pcm) // block
        _, stderr = checked("meter-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-i", path, "-map", "0:a:0",
                            "-af", "loudnorm=I=-12:TP=-1.5:LRA=7:print_format=json", "-f", "null", "NUL"])
        measured = measurement(helpers.parse_stats(stderr), frames / RATE)
        with path.open("rb") as source:
            container = source.read(4).decode("ascii")
        checks = {"codec": stream["codec_name"] == fmt["codec"], "rate": int(stream["sample_rate"]) == fmt["sampleRate"],
                  "bits": int(stream["bits_per_sample"]) == fmt["bitDepth"], "channels": stream["channels"] == fmt["channels"],
                  "layout": stream.get("channel_layout", "mono" if stream["channels"] == 1 else "stereo") == fmt["channelLayout"],
                  "container": container == fmt["container"]}
        return {"file_sha256": sha256(path), "decoded_pcm_sha256": hashlib.sha256(pcm).hexdigest(), "frames": frames,
                "decoded_bytes": len(pcm), "format": fmt, "measurements": metrics(measured), "checks": checks,
                "layout_basis": "probe" if stream.get("channel_layout") else "inferred_from_supported_channel_count",
                "passed": all(checks.values())}, pcm

    def render(label, source, filters, fmt, destination, stream=0, window=None, from_pipe=False):
        if from_pipe:
            argv = ["-nostdin", "-protocol_whitelist", "pipe", "-format_whitelist", "wav", "-f", "wav", "-i", "pipe:0", "-map", "0:0"]
        else:
            argv = ["-nostdin"]
            if window:
                argv += ["-seek_timestamp", "1", "-ss", literal(window[0]), "-t", literal(window[1])]
            argv += ["-i", source, "-map", "0:" + str(stream)]
        argv += ["-vn", "-af", filters, "-ar", fmt["sampleRate"], "-c:a", fmt["codec"], "-ac", fmt["channels"],
                 "-channel_layout", fmt["channelLayout"], "-map_metadata", "-1", "-map_chapters", "-1", "-f", "wav",
                 "-rf64", "always" if fmt["container"] == "RF64" else "never", destination, "-n", "-hide_banner", "-loglevel", "info", "-nostats"]
        return checked(label, [ffmpeg, *argv], stdin=source.read_bytes() if from_pipe else None,
                       stdin_id=aliases.get(str(source)) if from_pipe else None)[1]

    def replay(case_id, report_path):
        report_record = remember(report_path, "local-report:" + case_id)
        report_bytes = report_path.read_bytes()
        require(hashlib.sha256(report_bytes).hexdigest() == report_record["sha256"], "Report changed before parsing")
        report = json.loads(report_bytes.decode("utf-8-sig"), parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
        preview = report.get("reportType") == "preview"
        source = Path(report["input"]["path"])
        require(source in immutable, "Report does not reference a pinned synthetic source")
        source_id = aliases[str(source)]
        stream_index = report["input"]["streamIndex"] if preview else report["input"]["stream"]["index"]
        stdout, _ = checked("source-probe-" + case_id, [ffprobe, "-v", "error", "-show_streams", "-of", "json", source])
        selected = [stream for stream in json.loads(stdout)["streams"] if stream["index"] == stream_index]
        require(len(selected) == 1, "Recorded selected stream not found")
        selected = selected[0]
        settings = report["settings"]
        profile = profile_from_report(report)
        prefix = "pan=mono|c0=0.5*c0+0.5*c1," if settings["mono"] and selected["channels"] == 2 else ""
        fmt = report["assets"]["Processed"]["format"] if preview else report["output"]["format"]
        require(fmt["sampleRate"] == RATE and fmt["bitDepth"] in (16, 24) and fmt["bitDepth"] == settings["bitDepth"] and fmt["codec"] == "pcm_s" + str(settings["bitDepth"]) + "le",
                "Inconsistent encoding choices")
        require(fmt["channels"] in (1, 2) and fmt["channels"] == (1 if settings["mono"] else selected["channels"])
                and fmt["channelLayout"] == ("mono" if fmt["channels"] == 1 else "stereo")
                and fmt["container"] == ("RF64" if settings["rf64"] else "RIFF"), "Inconsistent channel/container choices")
        for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe)):
            require(Path(report["dependencies"][name]["path"]).resolve() == tool
                    and report["dependencies"][name]["version"] == summary["tools"][name]["version"], "Recorded tool differs from pinned build")
        filter_chain = prefix + profile
        window = None
        context_seconds = report["input"]["durationSeconds"]
        if preview:
            require(settings["fullProfileFilters"] == profile and report["alignment"]["compensationSamples"] == 0,
                    "Preview full profile/alignment differs")
            timeline, interval = report["timeline"], report["range"]
            require(timeline["seekTimestamp"] is True and timeline["streamIndex"] == stream_index
                    and timeline["absoluteSeekSeconds"] == timeline["streamStartSeconds"] + interval["windowStartSeconds"], "Inconsistent Preview seek timeline")
            window = (timeline["absoluteSeekSeconds"], interval["windowDurationSeconds"])
            context_seconds = interval["windowDurationSeconds"]
        targets, recorded_analysis = None, None
        if settings["loudnessMode"] == "Accurate":
            filter_chain, analysis_filter, recorded_analysis, targets = accurate_from_report(report, profile, prefix)
            argv = ["-nostdin"]
            if window:
                argv += ["-seek_timestamp", "1", "-ss", literal(window[0]), "-t", literal(window[1])]
            argv += ["-i", source, "-map", "0:" + str(stream_index), "-vn", "-af", analysis_filter,
                     "-ar", RATE, "-ac", fmt["channels"], "-channel_layout", fmt["channelLayout"], "-f", "null", "NUL", "-hide_banner", "-loglevel", "info", "-nostats"]
            _, stderr = checked("reanalysis-" + case_id, [ffmpeg, *argv])
            require(measurement(helpers.parse_stats(stderr), context_seconds) == recorded_analysis, "Recorded first-pass measurements not reproduced")
        else:
            require(report["normalization"]["renderFilter"] == filter_chain and report["normalization"]["actualType"] is None,
                    "Inconsistent Fast normalization record")
        if preview:
            trim = "aresample=48000,atrim=start_sample=" + str(interval["trimStartSamples"]) + ":end_sample=" + str(interval["trimEndSamples"]) + ",asetpts=PTS-STARTPTS"
            require(interval["trimEndSamples"] - interval["trimStartSamples"] == interval["durationSamples"], "Invalid Preview sample range")
            graphs = {"Original": prefix + trim, "Processed": filter_chain + "," + trim}
            for role, gain_key in (("CompareOriginal", "originalGainDb"), ("CompareProcessed", "processedGainDb")):
                gain = number(report["matching"][gain_key])
                require(gain <= 0 and report["assets"][role]["gainDb"] == gain, "Invalid comparison attenuation choice")
                graphs[role] = "volume=" + literal(gain) + "dB,aresample=48000"
        else:
            require(settings["exactFilters"] == filter_chain, "Ordinary exact graph does not match report reconstruction")
            graphs = {"Export": filter_chain}
        record = {"id": case_id, "report": report_record,
                  "input": {"id": source_id, "sha256": immutable[source], "stream_index": stream_index,
                            "codec": selected["codec_name"], "channels": selected["channels"], "sample_rate": int(selected["sample_rate"])},
                  "report_choices": {"toolVersion": report["toolVersion"], "presetId": report["presetId"], "presetVersion": report["presetVersion"],
                                     "presetExperimental": report["presetExperimental"], "presetCustomized": report["presetCustomized"],
                                     "settings": {key: settings[key] for key in ("mode", "loudnessMode", "cleaning", "bitDepth", "mono", "rf64")},
                                     "normalization": {key: report["normalization"][key] for key in ("linearRequested", "actualType", "fallbackReason")},
                                     "warningCodes": report["warningCodes"],
                                     "applicationExitCode": report["applicationExitCode"], "status": report["status"]},
                  "recipe": {"profile": profile, "prefix": prefix, "graphs": graphs, "recorded_analysis": recorded_analysis, "targets": targets},
                  "assets": {}, "passed": True}
        if preview:
            record["report_choices"].update(range=interval, timeline=timeline, matching=report["matching"])
        else:
            record["report_choices"]["loudnessCompliance"] = report["loudnessCompliance"]
        recreated_paths = {}
        for role, filters in graphs.items():
            asset = report["assets"][role] if preview else report["output"]
            if preview:
                require(asset["exactFilters"] == filters and asset["format"] == fmt, "Preview asset graph/format inconsistent")
            published = Path(asset["path"])
            destination = output / "recreated" / (case_id + "-" + role + ".wav")
            published_record = remember(published, "published:" + case_id + ":" + role)
            alias(destination, "recreated:" + case_id + ":" + role)
            from_pipe = role in ("CompareOriginal", "CompareProcessed")
            source_role = "Original" if role == "CompareOriginal" else "Processed"
            replay_source = recreated_paths[source_role] if from_pipe else source
            stderr = render("recreate-" + case_id + "-" + role, replay_source, filters, fmt, destination,
                            stream_index, window, from_pipe)
            recreated_paths[role] = destination
            original, original_pcm = inspect_audio(case_id + "-published-" + role, published, fmt)
            recreated, recreated_pcm = inspect_audio(case_id + "-recreated-" + role, destination, fmt)
            expected_frames = interval["durationSamples"] if preview else round(report["input"]["durationSeconds"] * RATE)
            checks = {"exact_decoded_pcm": original_pcm == recreated_pcm, "exact_frames": original["frames"] == recreated["frames"] == expected_frames,
                      "format": original["passed"] and recreated["passed"], "classified_meter_same": original["measurements"] == recreated["measurements"]}
            if preview or settings["loudnessMode"] == "Accurate":
                reported_metrics = asset["measurements"] if preview else report["measurements"]
                checks["report_encoded_metrics"] = reported_metrics == recreated["measurements"]
            else:
                reported_metrics = report["measurements"]
                checks["fast_explicitly_unmeasured"] = all(value == {"value": None, "reason": "not_measured"} for value in report["measurements"].values()) and report["loudnessCompliance"] == {"status": "NOT_MEASURED", "reason": "no_independent_measurement"}
            if settings["loudnessMode"] == "Accurate" and role in ("Export", "Processed"):
                checks["actual_normalization_type"] = helpers.parse_stats(stderr)["normalization_type"] == report["normalization"]["actualType"]
            recreated_record = remember(destination, "recreated:" + case_id + ":" + role)
            record["assets"][role] = {"original_file": published_record, "recreated_file": recreated_record,
                                      "original": original, "recreated": recreated, "reported_measurements": reported_metrics,
                                      "checks": checks, "passed": all(checks.values())}
            record["passed"] &= all(checks.values())
        if preview:
            matching = report["matching"]
            a, b = record["assets"]["Original"]["recreated"]["measurements"], record["assets"]["Processed"]["recreated"]["measurements"]
            require(matching["available"] is True, "This Preview replay fixture expects available matching")
            target = min(a["integratedLufs"]["value"], b["integratedLufs"]["value"],
                         a["integratedLufs"]["value"] - a["truePeakDbtp"]["value"] + matching["headroomTargetDbtp"],
                         b["integratedLufs"]["value"] - b["truePeakDbtp"]["value"] + matching["headroomTargetDbtp"])
            require(abs(target - matching["commonTargetLufs"]) <= 1e-9
                    and abs(min(0, target - a["integratedLufs"]["value"]) - matching["originalGainDb"]) <= 1e-9
                    and abs(min(0, target - b["integratedLufs"]["value"]) - matching["processedGainDb"]) <= 1e-9, "Comparison gains not reproducible from encoded excerpt metrics")
        return record

    try:
        for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe)):
            stdout, _ = checked(name + "-version", [tool, "-version"])
            summary["tools"][name]["version"] = stdout.splitlines()[0]
        fixtures = {}
        for name, channels, seconds, kind in (("stereo", 2, 12, "eligible"), ("mono", 1, 12, "eligible"), ("silence", 1, 3, "silence")):
            path = output / "fixtures" / (name + ".wav")
            metadata = helpers.create_fixture(path, channels, seconds, kind)
            summary["fixtures"].append(dict(metadata, **remember(path, "fixture:" + name)))
            fixtures[name] = path
        selected = output / "fixtures" / "selected.mkv"
        alias(selected, "fixture:selected")
        checked("mux-selected", [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", fixtures["mono"], "-i", fixtures["stereo"],
                                 "-map", "0:a:0", "-map", "1:a:0", "-c:a", "copy", selected])
        summary["fixtures"].append(dict(remember(selected, "fixture:selected"), description="Stream0 mono, stream1 stereo; selected stream1."))
        configs = [
            {"id": "original-fast-stereo16", "source": fixtures["stereo"], "preset": "Original", "loudness": "Fast", "bits": 16},
            {"id": "original-accurate-downmix24", "source": fixtures["stereo"], "preset": "Original", "loudness": "Accurate", "bits": 24, "mono": True},
            {"id": "gentle-fast-mono24", "source": fixtures["mono"], "preset": "Gentle", "loudness": "Fast", "bits": 24},
            {"id": "gentle-accurate-stereo16", "source": fixtures["stereo"], "preset": "Gentle", "loudness": "Accurate", "bits": 16},
            {"id": "custom-accurate-selected24-rf64", "source": selected, "preset": "Gentle", "loudness": "Accurate", "bits": 24, "stream": 1, "rf64": True,
             "options": {"Declip": True, "Gate": True, "HighpassHz": 61.5, "NoiseFloorDb": -35.25, "NoiseReductionDb": 6.125, "GateThresholdDb": -40, "GateRangeDb": -20}},
            {"id": "silence-original-accurate16", "source": fixtures["silence"], "preset": "Original", "loudness": "Accurate", "bits": 16},
            {"id": "zoom-fast-mono16", "source": fixtures["mono"], "preset": "Original", "loudness": "Fast", "bits": 16, "mode": "Zoom"},
            {"id": "preview-gentle-accurate-selected24", "source": selected, "preset": "Gentle", "loudness": "Accurate", "bits": 24, "stream": 1, "preview": True},
        ]
        if args.selected_cases:
            require(set(args.selected_cases) <= {config["id"] for config in configs}, "Unknown case ID")
            configs = [config for config in configs if config["id"] in args.selected_cases]
        previous_pcm = {}
        expected_cases = len(configs) * (1 if args.shell else 2)
        for shell_name, prefix, culture in (("powershell.exe", "ps51", "en-US"), ("pwsh.exe", "ps7", "de-DE")):
            if args.shell and args.shell != prefix:
                continue
            shell = shutil.which(shell_name)
            require(shell is not None, "Required shell not found: " + shell_name)
            stdout, _ = checked(prefix + "-version", [shell, "-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"])
            summary["environment"][prefix] = stdout.strip()
            for config in configs:
                case_id = prefix + "-" + config["id"]
                destination = output / case_id
                destination.mkdir()
                alias(destination, "case-output:" + case_id)
                invocation = "& " + common.ps_quote(repo / "WinAudioClean.ps1") + " -inputPath " + common.ps_quote(config["source"])
                invocation += " -OutputDirectory " + common.ps_quote(destination) + " -FfmpegPath " + common.ps_quote(ffmpeg) + " -FfprobePath " + common.ps_quote(ffprobe)
                invocation += f" -Mode {config.get('mode', 'Raw')} -Preset {config['preset']} -LoudnessMode {config['loudness']} -BitDepth {config['bits']} -AudioStreamIndex {config.get('stream', 0)} -NonInteractive"
                if config.get("mono"):
                    invocation += " -Mono"
                if config.get("rf64"):
                    invocation += " -Rf64"
                if config.get("options"):
                    invocation += " -CleaningOptions " + common.ps_options(config["options"])
                if config.get("preview"):
                    invocation += " -Preview -PreviewStartSeconds 2.125 -PreviewDurationSeconds 6.75"
                ps_command = "$cultureInfo=[Globalization.CultureInfo]::GetCultureInfo(" + common.ps_quote(culture) + "); [Threading.Thread]::CurrentThread.CurrentCulture=$cultureInfo; [Threading.Thread]::CurrentThread.CurrentUICulture=$cultureInfo; Write-Host ('WAC_HARNESS_CULTURE:' + [Threading.Thread]::CurrentThread.CurrentCulture.Name); " + invocation + "; exit $LASTEXITCODE"
                process, stdout, _ = run("app-" + case_id, [shell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_command])
                require(process["exit_code"] in (0, 7) and not process["timed_out"] and "WAC_HARNESS_CULTURE:" + culture in stdout, "App seed render failed")
                reports = list(destination.glob("WinAudioClean_*.json"))
                require(len(reports) == 1 and not list(destination.glob(".wac-*.partial")), "Unexpected report/partial count")
                case = replay(case_id, reports[0])
                require(case["report_choices"]["applicationExitCode"] == process["exit_code"], "Report/application exit disagreement")
                case["culture"], case["application_exit_code"] = culture, process["exit_code"]
                case["same_pcm_across_shell_and_locale"] = {}
                for role, asset in case["assets"].items():
                    key = (config["id"], role)
                    pcm_hash = asset["recreated"]["decoded_pcm_sha256"]
                    if key in previous_pcm:
                        same = previous_pcm[key] == pcm_hash
                        case["same_pcm_across_shell_and_locale"][role] = same
                        case["passed"] &= same
                    previous_pcm[key] = pcm_hash
                summary["cases"].append(case)
                print(case_id + (": PASS" if case["passed"] else ": FAIL"), flush=True)
        summary["files_unchanged"] = all(sha256(path) == digest for path, digest in immutable.items())
        summary["tools_sha256_after"] = {name: sha256(tool) for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe))}
        summary["tools_unchanged"] = all(summary["tools_sha256_after"][name] == proof["sha256"] for name, proof in summary["tools"].items())
        summary["source_sha256_after"] = source_hashes()
        summary["sources_unchanged_during_run"] = summary["source_sha256_before"] == summary["source_sha256_after"]
        summary["status"] = "pass" if len(summary["cases"]) == expected_cases and all(case["passed"] for case in summary["cases"]) and summary["files_unchanged"] and summary["tools_unchanged"] and summary["sources_unchanged_during_run"] else "fail"
        return 0 if summary["status"] == "pass" else 1
    except Exception as error:
        summary["status"], summary["error"] = "error", str(error)
        print(sanitize(str(error)), file=sys.stderr)
        return 1
    finally:
        summary["source_sha256_after"] = source_hashes()
        summary["sources_unchanged_during_run"] = summary["source_sha256_before"] == summary["source_sha256_after"]
        proof = output / "summary.json"
        proof.write_text(json.dumps(sanitize(summary), indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
        print("Evidence: " + sanitize(str(proof)), flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
