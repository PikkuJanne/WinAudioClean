#!/usr/bin/env python3
"""Windows synthetic excerpt/alignment/level-matching evidence for previews.

Uses existing FFmpeg/ffprobe and both PowerShell hosts. Generated recordings,
reports, raw logs and disposable native-argument capture copies stay ignored.
No speech listening, automatic playback or full-program quality claim occurs.
"""

from __future__ import annotations

import argparse
import array
import datetime as dt
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import platform
import random
import shutil
import subprocess
import sys
import wave


RATE = 48000
TARGET = "loudnorm=I=-12:TP=-1.5:LRA=7"
METRICS = {"integratedLufs": "input_i", "truePeakDbtp": "input_tp", "loudnessRangeLu": "input_lra"}
ROLES = ("Original", "Processed", "CompareOriginal", "CompareProcessed")


def load_helpers(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    previous_policy = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = previous_policy
    return module


def create_fixture(path: Path, channels: int, seconds: float, kind: str) -> dict:
    """Timed synthetic impulses/broadband markers over harmonic envelopes."""
    samples = array.array("h")
    rng = random.Random(24680)
    marker = [rng.random() * 2 - 1 for _ in range(RATE // 4)]
    for frame in range(round(seconds * RATE)):
        time = frame / RATE
        for channel in range(channels):
            if kind == "silence":
                value = 0.0
            elif kind == "hot":
                # Legal sample peaks with intersample overshoot; no source clip.
                value = 0.8 * (1 if math.sin(2 * math.pi * (997 + channel * 23) * time) >= 0 else -1)
                value *= 0.1 + 0.9 * math.sin(math.pi * 0.35 * time) ** 2
            else:
                frequency = 120 + channel * 31
                envelope = (0.03 + 0.08 * math.sin(math.pi * 0.17 * time) ** 2) * (0.22 + 0.78 * math.sin(math.pi * 3.4 * time) ** 2)
                value = envelope * (0.62 * math.sin(2 * math.pi * frequency * time) + 0.24 * math.sin(2 * math.pi * 2.013 * frequency * time))
                phase = frame % (4 * RATE)
                if 2 * RATE <= phase < 2 * RATE + len(marker):
                    marker_frame = phase - 2 * RATE
                    value += 0.35 * marker[marker_frame] * math.sin(math.pi * marker_frame / len(marker)) ** 2
                if phase == 3 * RATE:
                    value = 0.8
            samples.append(round(max(-1, min(1, value)) * 32767))
    if sys.byteorder != "little":
        samples.byteswap()
    with path.open("xb") as target:
        with wave.open(target, "wb") as wav:
            wav.setnchannels(channels)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(samples.tobytes())
    return {"id": path.stem, "channels": channels, "seconds": seconds, "kind": kind,
            "sample_rate": RATE, "frames": round(RATE * seconds), "marker_every_seconds": 4 if kind == "timed" else None}


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
    common_path, measured_path = repo / "scripts/Test-GentleCleaning.py", repo / "scripts/Test-MeasuredLoudness.py"
    common = load_helpers(common_path, "wac_preview_common")
    measured = load_helpers(measured_path, "wac_preview_measurements")
    sha256 = measured.sha256
    ffmpeg, ffprobe = args.ffmpeg.resolve(strict=True), args.ffprobe.resolve(strict=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = (args.output or repo / ".wac-local/WAC-M2-04" / stamp).resolve()
    if not output.is_relative_to((repo / ".wac-local").resolve()):
        parser.error("--output must be inside this repository's .wac-local folder")
    output.mkdir(parents=True, exist_ok=False)
    fixtures, references, application = output / "fixtures", output / "references", output / "app"
    for folder in (fixtures, references, application):
        folder.mkdir()
    baseline_path = repo / "docs/codex/winaudioclean/BASELINE.json"
    sources = [repo / "WinAudioClean.ps1", repo / "WinAudioClean.IO.ps1", repo / "WinAudioClean.Preview.ps1",
               Path(__file__).resolve(), common_path, measured_path, baseline_path]

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
        "task": "WAC-M2-04", "created_utc": stamp,
        "notice": "Synthetic bounded-excerpt/filter/gain mechanics; no speech listening, automatic playback, full-program loudness or independent meter calibration.",
        "environment": {"platform": platform.platform(), "python": platform.python_version(), "child_psmodulepath_removed": True},
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "source_sha256_before": source_hashes(), "harness_invocation": sys.orig_argv,
        "scope": {"selected_cases": args.selected_cases, "shell": args.shell, "full_matrix": not args.selected_cases and not args.shell},
        "tools": {name: {"path": str(path), "sha256": sha256(path)} for name, path in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe))},
        "fixtures": [], "cases": [], "commands": [],
    }

    def run(label, command, binary=False, env=None):
        command = [str(item) for item in command]
        started = dt.datetime.now(dt.timezone.utc)
        process = subprocess.Popen(command, cwd=repo, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=env or clean_env)
        timed_out = False
        try:
            stdout, stderr = process.communicate(timeout=240)
        except subprocess.TimeoutExpired:
            timed_out = True
            measured.stop_owned_process_tree(process)
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

    def inspect_audio(label, path, config, duration_samples):
        streams = json.loads(checked("probe-" + label, [ffprobe, "-v", "error", "-show_streams", "-of", "json", path])["stdout"])["streams"]
        if len(streams) != 1:
            raise ValueError("Expected exactly one output stream")
        stream = streams[0]
        bits, channels = config["bits"], config["channels"]
        decoded = checked("decode-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", path,
                                             "-map", "0:a:0", "-c:a", f"pcm_s{bits}le", "-f", f"s{bits}le", "-"], True)["stdout"]
        observed = checked("measure-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-i", path, "-map", "0:a:0",
                                               "-af", TARGET + ":print_format=json", "-f", "null", "NUL"])
        stats = measured.parse_stats(observed["stderr"])
        values = {name: measured.finite_value(stats[source]) for name, source in METRICS.items()}
        checks = {
            "codec": stream["codec_name"] == f"pcm_s{bits}le", "sample_rate": int(stream["sample_rate"]) == RATE,
            "channels": stream["channels"] == channels, "bit_depth": int(stream["bits_per_sample"]) == bits,
            "duration": abs(float(stream["duration"]) - duration_samples / RATE) <= 1 / RATE,
            "exact_frame_count": len(decoded) == duration_samples * channels * bits // 8,
            "container": path.read_bytes()[:4] == (b"RF64" if config.get("rf64") else b"RIFF"),
        }
        return {**file_record(path), "probe": {key: stream.get(key) for key in ("codec_name", "sample_rate", "channels", "bits_per_sample", "channel_layout", "duration")},
                "decoded_pcm_sha256": hashlib.sha256(decoded).hexdigest(), "decoded_pcm_bytes": len(decoded),
                "independent_metrics": values, "independent_raw_stats": stats, "checks": checks, "passed": all(checks.values())}, decoded

    def direct_reference(label, config, source, filters, output_path, window_start=None, window_duration=None):
        argv = [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-n"]
        if window_start is not None:
            argv += ["-seek_timestamp", "1", "-ss", window_start + config.get("stream_start", 0), "-t", window_duration]
        argv += ["-i", source, "-map", "0:" + str(config["stream"] if source == config["source"] else 0), "-vn", "-af", filters,
                 "-ar", RATE, "-c:a", f"pcm_s{config['bits']}le", "-ac", config["channels"],
                 "-channel_layout", "mono" if config["channels"] == 1 else "stereo", "-map_metadata", "-1", "-map_chapters", "-1",
                 "-f", "wav", "-rf64", "always" if config.get("rf64") else "never", output_path]
        checked(label, argv)

    full_source_pcm = {}

    def source_frame_slice(label, config, plan, offset=0):
        # Intentional full decoding in the evidence harness, not the application.
        # This independent slice catches seeking from a wrong PTS origin.
        key = (str(config["source"]), config["stream"], config["bits"], config["channels"], bool(config.get("mono")))
        if key not in full_source_pcm:
            filters = ("pan=mono|c0=0.5*c0+0.5*c1," if config.get("mono") else "") + "aresample=48000"
            decoded = checked("full-source-reference-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", config["source"],
                        "-map", "0:" + str(config["stream"]), "-af", filters, "-ac", config["channels"],
                        "-c:a", f"pcm_s{config['bits']}le", "-f", f"s{config['bits']}le", "-"], True)["stdout"]
            full_source_pcm[key] = decoded
        block = config["channels"] * config["bits"] // 8
        before = (plan["startSamples"] + offset) * block
        if before < 0:
            return b""
        return full_source_pcm[key][before:before + plan["durationSamples"] * block]

    def expected_range(config):
        start_samples = round(config.get("start", 0) * RATE)
        duration_samples = min(round(config.get("duration", 45) * RATE), round(config["seconds"] * RATE) - start_samples)
        before = min(5 * RATE, start_samples)
        after = min(5 * RATE, round(config["seconds"] * RATE) - start_samples - duration_samples)
        return {"startSamples": start_samples, "durationSamples": duration_samples,
                "startSeconds": start_samples / RATE, "durationSeconds": duration_samples / RATE,
                "windowStartSeconds": (start_samples - before) / RATE,
                "windowDurationSeconds": (duration_samples + before + after) / RATE,
                "trimStartSamples": before, "trimEndSamples": before + duration_samples,
                "preRollSeconds": before / RATE, "postRollSeconds": after / RATE}

    def inspect_report(path, config, captured, reference_filters, label):
        def reject_constant(value):
            raise ValueError("Nonfinite JSON numeric constant: " + value)

        report = json.loads(path.read_text(encoding="utf-8-sig"), parse_constant=reject_constant)
        plan = expected_range(config)
        checks = {"schema": report["schemaVersion"] == 1 and report["reportType"] == "preview",
                  "range": all(report["range"][key] == value for key, value in plan.items()),
                  "four_assets": set(report["assets"]) == set(ROLES),
                  "no_compensation": report["alignment"]["compensationSamples"] == 0 and report["alignment"]["filterDelayPolicy"] == "preserved"}
        checks["delay_reference"] = report["alignment"]["referenceDelaySeconds"] == (0 if config["profile"] in ("Zoom", "DisabledRaw") else 0.025)
        checks["full_profile_unchanged"] = report["settings"]["fullProfileFilters"] == reference_filters[config["profile"]]
        checks["selected_stream"] = report["input"]["streamIndex"] == config["stream"]
        checks["excerpt_metric_scope"] = report["normalization"]["scope"] == "bounded_context_window" and bool(report["boundaryNotice"])
        checks["selected_timeline"] = report["timeline"]["streamIndex"] == config["stream"] and report["timeline"]["streamStartSeconds"] == config.get("stream_start", 0) and report["timeline"]["absoluteSeekSeconds"] == config.get("stream_start", 0) + plan["windowStartSeconds"] and report["timeline"]["seekTimestamp"] is True
        seek_bound = report["timeline"]["seekToleranceSamples"]
        resolution = report["timeline"]["timestampResolutionSeconds"]
        checks["declared_seek_precision"] = type(seek_bound) is int and 0 < seek_bound <= 480 and resolution > 0 and seek_bound == math.ceil(RATE * resolution) + 1
        bounded = [record for record in captured if "-ss" in record["arguments"]]
        checks["bounded_input_count"] = len(bounded) == (3 if config["loudness"] == "Accurate" else 2)
        checks["all_source_calls_bounded"] = all("-ss" in record["arguments"] for record in captured
            if "-i" in record["arguments"] and Path(argument(record["arguments"], "-i")).name == config["source"].name and "-af" in record["arguments"])
        for i, record in enumerate(bounded):
            argv = record["arguments"]
            checks["range_argv_" + str(i)] = argv.index("-ss") < argv.index("-i") and argv.index("-t") < argv.index("-i") and float(argument(argv, "-ss")) == plan["windowStartSeconds"] + config.get("stream_start", 0) and float(argument(argv, "-t")) == plan["windowDurationSeconds"] and argument(argv, "-map") == "0:" + str(config["stream"])
            checks["absolute_seek_" + str(i)] = "-seek_timestamp" in argv and argument(argv, "-seek_timestamp") == "1"
        assets, pcm, refs = {}, {}, {}
        for role in ROLES:
            asset = report["assets"][role]
            audio_path = Path(asset["path"])
            facts, decoded = inspect_audio(label + "-" + role, audio_path, config, plan["durationSamples"])
            expected_format = {"sampleRate": RATE, "bitDepth": config["bits"], "codec": f"pcm_s{config['bits']}le", "channels": config["channels"],
                               "channelLayout": "mono" if config["channels"] == 1 else "stereo", "container": "RF64" if config.get("rf64") else "RIFF"}
            facts["checks"]["reported_format"] = asset["format"] == expected_format
            metrics = facts["independent_metrics"]
            stage = asset["measurementStage"]
            stage_checks = {"held_stream": stage["inputSource"] == "held_output_stream" and argument(stage["arguments"], "-i") == "pipe:0",
                            "success": stage["status"] == "PASSED" and stage["process"]["ExitCode"] == 0,
                            "captured": len([record for record in captured if record["arguments"] == stage["arguments"] and record["inputStream"]]) >= 1}
            for name, value in metrics.items():
                reported = asset["measurements"][name]
                if plan["durationSeconds"] < 1 and (name != "truePeakDbtp" or value is None):
                    stage_checks["metric_" + name] = reported == {"value": None, "reason": "too_short"}
                elif metrics["integratedLufs"] is None and (name != "truePeakDbtp" or value is None):
                    reason = "silence" if metrics["truePeakDbtp"] is None else "undefined_loudness"
                    stage_checks["metric_" + name] = reported == {"value": None, "reason": reason}
                elif value is None:
                    stage_checks["metric_" + name] = reported["value"] is None and reported["reason"] in ("silence", "undefined_loudness")
                else:
                    stage_checks["metric_" + name] = reported == {"value": value, "reason": None}
            facts["stage_checks"] = stage_checks
            facts["passed"] &= all(stage_checks.values()) and facts["checks"]["reported_format"]
            assets[role], pcm[role] = facts, decoded
        prefix = "pan=mono|c0=0.5*c0+0.5*c1," if config.get("mono") else ""
        trim = f"aresample=48000,atrim=start_sample={plan['trimStartSamples']}:end_sample={plan['trimEndSamples']},asetpts=PTS-STARTPTS"
        original_filters = prefix + trim
        processed = report["assets"]["Processed"]["exactFilters"]
        if config["loudness"] == "Fast":
            checks["frozen_processed_filters"] = processed == prefix + reference_filters[config["profile"]] + "," + trim
        else:
            prechain = prefix + reference_filters[config["profile"]].rsplit(",loudnorm=", 1)[0] + ",aresample=192000"
            checks["accurate_prechain"] = processed.startswith(prechain + "," + TARGET + ":") and processed.endswith("," + trim) and processed.count("loudnorm=") == 1
            analysis = report["stages"]["Analysis"]
            checks["accurate_analysis"] = argument(analysis["arguments"], "-af") == prechain + "," + TARGET + ":print_format=json" and analysis["status"] == "PASSED"
            checks["accurate_repeated_prechain"] = report["normalization"]["prechain"] == prechain and report["normalization"]["renderFilter"] + "," + trim == processed
        checks["original_filter"] = report["assets"]["Original"]["exactFilters"] == original_filters
        source_offsets = [0] + [offset for delta in range(1, seek_bound + 1) for offset in (delta, -delta)]
        source_offset = None
        signature = pcm["Original"][:64 * config["channels"] * config["bits"] // 8]
        for offset in source_offsets:
            candidate = source_frame_slice(label, config, plan, offset)
            if candidate[:len(signature)] == signature and candidate == pcm["Original"]:
                source_offset = offset
                break
        source_slice_facts = {"nominal_start_sample": plan["startSamples"], "measured_offset_samples": source_offset,
                              "exact_at_nominal_start": source_offset == 0, "declared_seek_tolerance_samples": seek_bound,
                              "timestamp_resolution_seconds": resolution,
                              "actual_start_sample": None if source_offset is None else plan["startSamples"] + source_offset,
                              "notice": "Exact PCM match against independent full selected-stream decode; container seek quantization is separate from preserved graph delay."}
        checks["original_selected_source_within_declared_precision"] = source_offset is not None and abs(source_offset) <= seek_bound
        if config["source"].suffix.lower() == ".wav":
            checks["wave_exact_selected_source_frame_slice"] = source_offset == 0
        for role, filters in (("Original", original_filters), ("Processed", processed)):
            ref_path = references / (label + "-" + role + ".wav")
            direct_reference("reference-" + label + "-" + role, config, config["source"], filters, ref_path, plan["windowStartSeconds"], plan["windowDurationSeconds"])
            facts, decoded = inspect_audio("reference-" + label + "-" + role, ref_path, config, plan["durationSamples"])
            facts["zero_added_shift_exact_pcm"] = decoded == pcm[role]
            facts["passed"] &= facts["zero_added_shift_exact_pcm"]
            refs[role] = facts
        matching = report["matching"]
        comparison_checks = {"attenuation_only": matching["originalGainDb"] <= 0 and matching["processedGainDb"] <= 0,
                             "documented_peak_guard": matching["peakCeilingDbtp"] == -1.5 and matching["headroomTargetDbtp"] == -1.7}
        original_metrics, processed_metrics = assets["Original"]["independent_metrics"], assets["Processed"]["independent_metrics"]
        available = plan["durationSeconds"] >= 1 and all(metrics[name] is not None for metrics in (original_metrics, processed_metrics) for name in ("integratedLufs", "truePeakDbtp"))
        comparison_checks["availability"] = matching["available"] is available
        if available:
            target = min(original_metrics["integratedLufs"], processed_metrics["integratedLufs"],
                         original_metrics["integratedLufs"] - original_metrics["truePeakDbtp"] - 1.7,
                         processed_metrics["integratedLufs"] - processed_metrics["truePeakDbtp"] - 1.7)
            comparison_checks["common_target"] = abs(matching["commonTargetLufs"] - target) <= 0.000001
            comparison_checks["original_planned_gain"] = abs(matching["originalGainDb"] - min(0, target - original_metrics["integratedLufs"])) <= 0.000001
            comparison_checks["processed_planned_gain"] = abs(matching["processedGainDb"] - min(0, target - processed_metrics["integratedLufs"])) <= 0.000001
        for original_role, comparison_role, gain_key in (("Original", "CompareOriginal", "originalGainDb"), ("Processed", "CompareProcessed", "processedGainDb")):
            asset = report["assets"][comparison_role]
            comparison_checks[comparison_role + "_gain"] = asset["gainDb"] == matching[gain_key]
            comparison_checks[comparison_role + "_filter"] = asset["exactFilters"].startswith("volume=") and asset["exactFilters"].endswith("dB,aresample=48000") and ",loudnorm=" not in asset["exactFilters"]
            ref_path = references / (label + "-" + comparison_role + ".wav")
            direct_reference("reference-" + label + "-" + comparison_role, config, Path(report["assets"][original_role]["path"]), asset["exactFilters"], ref_path)
            facts, decoded = inspect_audio("reference-" + label + "-" + comparison_role, ref_path, config, plan["durationSamples"])
            facts["gain_only_exact_pcm"] = decoded == pcm[comparison_role]
            facts["passed"] &= facts["gain_only_exact_pcm"]
            refs[comparison_role] = facts
            peak = assets[comparison_role]["independent_metrics"]["truePeakDbtp"]
            comparison_checks[comparison_role + "_safe_peak"] = peak is None or peak <= -1.5
        if matching["available"]:
            a, b = assets["CompareOriginal"]["independent_metrics"]["integratedLufs"], assets["CompareProcessed"]["independent_metrics"]["integratedLufs"]
            comparison_checks["matched_loudness"] = a is not None and b is not None and abs(a - b) <= 0.2 + 1e-9
            comparison_checks["pair_difference"] = matching["pairDifferenceLu"] is not None and abs(matching["pairDifferenceLu"] - abs(a - b)) <= 0.000001
        else:
            comparison_checks["unmeasurable_label"] = matching["reason"] in ("too_short", "silence", "undefined_loudness") and matching["commonTargetLufs"] is None
        if config["id"] == "hot-original-guard":
            comparison_checks["actual_peak_guard_needed"] = original_metrics["truePeakDbtp"] > -1.5 and matching["originalGainDb"] < 0
        checks["assets"] = all(asset["passed"] for asset in assets.values())
        checks["references"] = all(ref["passed"] for ref in refs.values())
        checks["comparison"] = all(comparison_checks.values())
        return {**file_record(path), "range": report["range"], "timeline": report["timeline"], "source_frame_slice_verification": source_slice_facts,
                "alignment": report["alignment"], "matching": matching,
                "assets": assets, "references": refs, "comparison_checks": comparison_checks,
                "status": report["status"], "application_exit_code": report["applicationExitCode"],
                "checks": checks, "passed": all(checks.values())}

    try:
        source = (repo / "WinAudioClean.ps1").read_text(encoding="utf-8-sig")
        marker = "# --- CONFIGURATION ---"
        if source.count(marker) != 1:
            raise ValueError("Expected exactly one disposable capture insertion marker")
        copied_app = application / "WinAudioClean.ps1"
        copied_app.write_text(source.replace(marker, common.CAPTURE + marker), encoding="utf-8-sig")
        for name in ("WinAudioClean.IO.ps1", "WinAudioClean.Preview.ps1"):
            shutil.copyfile(repo / name, application / name)
        copy_hashes = {path.name: sha256(path) for path in application.iterdir()}
        summary["instrumentation"] = {"seam": "Disposable main capture before CONFIGURATION, unchanged native delegation; copy both IO and Preview siblings.",
                                      "insertion_source": common.CAPTURE, "insertion_sha256": hashlib.sha256(common.CAPTURE.encode()).hexdigest(),
                                      "copy_sha256_before": copy_hashes}
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        level = baseline["filters"]["level"]
        reference_filters = {"OriginalRaw": baseline["filters"]["raw_clean"] + "," + level,
                             "GentleRaw": "highpass=f=60,afftdn=nf=-35:nr=6," + level,
                             "Zoom": level, "DisabledRaw": "highpass=f=80," + level}
        for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe)):
            summary["tools"][name]["version"] = checked(name + "-version", [tool, "-version"])["stdout"].splitlines()[0]
        fixture_paths = {}
        for name, channels, seconds, kind in (("stereo", 2, 95.0, "timed"), ("mono", 1, 95.0, "timed"),
                                               ("short", 1, 0.2, "timed"), ("silence", 1, 3.0, "silence"), ("hot", 2, 12.0, "hot")):
            path = fixtures / (name + ".wav")
            record = create_fixture(path, channels, seconds, kind)
            summary["fixtures"].append({**record, **file_record(path)})
            fixture_paths[name] = path
        selected = fixtures / "selected-stream.mkv"
        checked("mux-selected-stream", [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", fixture_paths["mono"], "-i", fixture_paths["stereo"],
                                       "-map", "0:a:0", "-map", "1:a:0", "-c:a", "copy", selected])
        summary["fixtures"].append({"id": "selected-stream", **file_record(selected), "seconds": 95.0,
                                    "description": "Stream0 mono; selected absolute stream1 stereo."})
        shifted = fixtures / "shifted-selected.mkv"
        checked("mux-shifted-selected-stream", [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", fixture_paths["mono"],
                "-itsoffset", "3", "-i", fixture_paths["stereo"], "-map", "0:a:0", "-map", "1:a:0", "-c:a", "copy", shifted])
        summary["fixtures"].append({"id": "shifted-selected-stream", **file_record(shifted), "seconds": 95.0,
                                    "description": "Stream0 origin0; selected stereo stream1 origin3s, duration95s, end98s."})
        configs = [
            {"id": "start-original-fast", "profile": "OriginalRaw", "source": fixture_paths["stereo"], "seconds": 95, "channels": 2, "start": 0, "duration": 12},
            {"id": "middle-gentle-fast", "profile": "GentleRaw", "source": fixture_paths["stereo"], "seconds": 95, "channels": 2, "start": 30, "duration": 12, "bits": 24},
            {"id": "end-zoom-fast", "profile": "Zoom", "source": fixture_paths["mono"], "seconds": 95, "channels": 1, "start": 88},
            {"id": "default-selected-gentle", "profile": "GentleRaw", "source": selected, "seconds": 95, "channels": 2, "stream": 1},
            {"id": "short-zoom", "profile": "Zoom", "source": fixture_paths["short"], "seconds": 0.2, "channels": 1},
            {"id": "silent-gentle", "profile": "GentleRaw", "source": fixture_paths["silence"], "seconds": 3, "channels": 1},
            {"id": "hot-original-guard", "profile": "OriginalRaw", "source": fixture_paths["hot"], "seconds": 12, "channels": 2, "start": 3, "duration": 6, "bits": 24},
            {"id": "middle-original-accurate-downmix", "profile": "OriginalRaw", "source": fixture_paths["stereo"], "seconds": 95, "channels": 1, "start": 30, "duration": 10, "mono": True, "loudness": "Accurate"},
            {"id": "middle-disabled-fast", "profile": "DisabledRaw", "source": fixture_paths["mono"], "seconds": 95, "channels": 1, "start": 30, "duration": 12,
             "options": {"Declip": False, "Declick": False, "Denoise": False, "Gate": False}},
            {"id": "fractional-selected-gentle", "profile": "GentleRaw", "source": selected, "seconds": 95, "channels": 2, "stream": 1, "start": 30.125, "duration": 11.75, "rf64": True},
            {"id": "shifted-selected-middle", "profile": "Zoom", "source": shifted, "seconds": 95, "channels": 2, "stream": 1, "stream_start": 3, "start": 30, "duration": 12},
            {"id": "shifted-selected-start", "profile": "Zoom", "source": shifted, "seconds": 95, "channels": 2, "stream": 1, "stream_start": 3, "start": 1, "duration": 12},
        ]
        for config in configs:
            config.setdefault("bits", 16)
            config.setdefault("stream", 0)
            config.setdefault("loudness", "Fast")
            config.setdefault("options", {})
        if args.selected_cases:
            unknown = set(args.selected_cases) - {config["id"] for config in configs}
            if unknown:
                raise ValueError("Unknown matrix case IDs: " + ", ".join(sorted(unknown)))
            configs = [config for config in configs if config["id"] in args.selected_cases]
        previous_pcm, expected_cases = {}, len(configs) * (1 if args.shell else 2)
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
                sentinel = destination / "prior-export.wav"
                sentinel.write_bytes(b"Prior user-owned export must remain unchanged.\r\n")
                sentinel_hash = sha256(sentinel)
                invocation = "& " + common.ps_quote(copied_app) + " -inputPath " + common.ps_quote(config["source"]) + " -OutputDirectory " + common.ps_quote(destination)
                invocation += " -FfmpegPath " + common.ps_quote(ffmpeg) + " -FfprobePath " + common.ps_quote(ffprobe)
                preset, mode = ("Gentle" if config["profile"] == "GentleRaw" else "Original"), ("Zoom" if config["profile"] == "Zoom" else "Raw")
                invocation += f" -Mode {mode} -Preset {preset} -LoudnessMode {config['loudness']} -BitDepth {config['bits']} -AudioStreamIndex {config['stream']} -Preview -NonInteractive"
                if "start" in config:
                    invocation += " -PreviewStartSeconds " + common.ps_quote(config["start"])
                if "duration" in config:
                    invocation += " -PreviewDurationSeconds " + common.ps_quote(config["duration"])
                if config["options"]:
                    invocation += " -CleaningOptions " + common.ps_options(config["options"])
                if config.get("mono"):
                    invocation += " -Mono"
                if config.get("rf64"):
                    invocation += " -Rf64"
                ps_command = "$cultureInfo=[Globalization.CultureInfo]::GetCultureInfo(" + common.ps_quote(culture) + "); [Threading.Thread]::CurrentThread.CurrentCulture=$cultureInfo; [Threading.Thread]::CurrentThread.CurrentUICulture=$cultureInfo; Write-Host ('WAC_HARNESS_CULTURE:' + [Threading.Thread]::CurrentThread.CurrentCulture.Name); " + invocation + "; exit $LASTEXITCODE"
                result = run(case_id, [shell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_command], env=dict(clean_env, WAC_EVIDENCE_CAPTURE=str(capture)))
                reports = list(destination.glob("*.json"))
                audio_paths, partials = [path for path in destination.glob("*.wav") if path != sentinel], list(destination.glob(".wac-*.partial"))
                captured = [json.loads(path.read_text(encoding="utf-8-sig")) for path in sorted(capture.glob("*.json"))]
                case = {"id": case_id, "culture": culture, "config": {key: str(value) if isinstance(value, Path) else value for key, value in config.items()},
                        "exit_code": result["exit_code"], "audio_count": len(audio_paths), "report_count": len(reports), "partial_count": len(partials),
                        "prior_export_unchanged": sha256(sentinel) == sentinel_hash,
                        "captured_commands": captured, "capture_files": [file_record(path) for path in sorted(capture.glob("*.json"))],
                        "passed": not result["timed_out"] and len(audio_paths) == 4 and len(reports) == 1 and not partials and not list(destination.glob("*_Cleaned_*.wav")) and "WAC_HARNESS_CULTURE:" + culture in result["stdout"] and sha256(sentinel) == sentinel_hash}
                if len(reports) == 1:
                    case["report"] = inspect_report(reports[0], config, captured, reference_filters, case_id)
                    case["passed"] &= case["report"]["passed"] and result["exit_code"] == case["report"]["application_exit_code"]
                    for role in ROLES:
                        pcm_hash = case["report"]["assets"][role]["decoded_pcm_sha256"]
                        key = config["id"] + "/" + role
                        if key in previous_pcm:
                            case.setdefault("same_pcm_across_shell_and_locale", {})[role] = pcm_hash == previous_pcm[key]
                            case["passed"] &= case["same_pcm_across_shell_and_locale"][role]
                        previous_pcm[key] = pcm_hash
                summary["cases"].append(case)
                print(case_id + (": PASS" if case["passed"] else ": FAIL"), flush=True)
        summary["fixtures_unchanged"] = all(sha256(repo / fixture["path"]) == fixture["sha256"] for fixture in summary["fixtures"])
        summary["source_sha256_after"] = source_hashes()
        summary["sources_unchanged_during_run"] = summary["source_sha256_before"] == summary["source_sha256_after"]
        summary["instrumentation"]["copy_sha256_after"] = {path.name: sha256(path) for path in application.iterdir()}
        summary["copies_unchanged"] = copy_hashes == summary["instrumentation"]["copy_sha256_after"]
        summary["status"] = "pass" if len(summary["cases"]) == expected_cases and all(case["passed"] for case in summary["cases"]) and summary["fixtures_unchanged"] and summary["sources_unchanged_during_run"] and summary["copies_unchanged"] else "fail"
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
