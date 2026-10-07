#!/usr/bin/env python3
"""Compare Original Raw/Zoom with frozen filters using existing Windows tools.

Development-only Python; no downloads, private audio or listening claims.
Both PowerShell hosts render deterministic synthetic input with the current
application. Direct FFmpeg references read their filter text from BASELINE.json
and use identical export settings. Decoded PCM bytes must match at zero lag.
Generated audio, native diagnostics and raw application reports stay ignored.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys


RATE = 48000
PRESET_ID = "original"
PRESET_VERSION = "1.0.0"


def source_application_version(main: Path) -> str:
    """Read the same literal version authority used by the package inspector."""
    spec = importlib.util.spec_from_file_location(
        "wac_original_release_version", Path(__file__).with_name("Test-ReleasePackage.py"))
    package = importlib.util.module_from_spec(spec)
    previous_bytecode_flag = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(package)
    finally:
        sys.dont_write_bytecode = previous_bytecode_flag
    try:
        return package.source_version(main.read_bytes())
    except package.CheckError as exc:
        raise ValueError(str(exc)) from exc


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        digest = hashlib.sha256()
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
        return digest.hexdigest()


def stop_owned_process_tree(process):
    """Stop only this harness child's Windows process tree, with bounded cleanup."""
    taskkill = Path(os.environ["SystemRoot"]) / "System32" / "taskkill.exe"
    try:
        return subprocess.run([str(taskkill), "/PID", str(process.pid), "/T", "/F"],
                              stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, timeout=10, check=True)
    finally:
        if process.poll() is None:
            process.kill()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--ffprobe", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    application_version = source_application_version(repo / "WinAudioClean.ps1")
    ffmpeg, ffprobe = args.ffmpeg.resolve(strict=True), args.ffprobe.resolve(strict=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = (args.output or repo / ".wac-local" / "WAC-M2-01" / stamp).resolve()
    if not output.is_relative_to((repo / ".wac-local").resolve()):
        parser.error("--output must be inside this repository's .wac-local folder")
    output.mkdir(parents=True, exist_ok=False)
    fixtures, references = output / "fixtures", output / "references"
    fixtures.mkdir()
    references.mkdir()
    baseline_path = repo / "docs/codex/winaudioclean/BASELINE.json"
    generator_path = repo / "docs/codex/winaudioclean/tools/generate_fixtures.py"
    runtime = [repo / "WinAudioClean.ps1", repo / "WinAudioClean.IO.ps1"]
    sources = runtime + [Path(__file__).resolve(), baseline_path, generator_path,
                         Path(__file__).with_name("Test-ReleasePackage.py")]
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
        "task": "WAC-M2-01", "created_utc": stamp,
        "notice": "Synthetic same-build, same-encoding filter compatibility only. No speech listening, independent loudness measurements, cross-build or legacy-container bit identity claimed.",
        "environment": {"platform": platform.platform(), "python": platform.python_version(), "child_psmodulepath_removed": True},
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "source_sha256_before": source_hashes(), "harness_invocation": sys.orig_argv,
        "tools": {name: {"path": str(path), "sha256": sha256(path)}
                  for name, path in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe))},
        "expected_application_version": application_version,
        "expected_preset": {"id": PRESET_ID, "version": PRESET_VERSION},
        "fixtures": [], "references": [], "cases": [], "commands": [],
    }

    def run(label, command, binary=False):
        command = [str(item) for item in command]
        started = dt.datetime.now(dt.timezone.utc)
        process = subprocess.Popen(command, cwd=repo, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=clean_env)
        timed_out = False
        try:
            stdout, stderr = process.communicate(timeout=120)
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

    def inspect_audio(label, path, channels, bits):
        result = checked("probe-" + label, [ffprobe, "-v", "error", "-show_streams", "-show_format", "-of", "json", path])
        streams = json.loads(result["stdout"]).get("streams", [])
        if len(streams) != 1:
            raise ValueError("Expected exactly one output stream")
        stream = streams[0]
        probe = {key: stream.get(key) for key in ("codec_name", "sample_rate", "channels", "bits_per_sample", "channel_layout", "duration")}
        probe["passed"] = (stream.get("codec_name") == f"pcm_s{bits}le" and int(stream.get("sample_rate", 0)) == RATE
                           and stream.get("channels") == channels and int(stream.get("bits_per_sample", 0)) == bits)
        decoded = checked("decode-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", path,
                                             "-map", "0:a:0", "-c:a", f"pcm_s{bits}le", "-f", f"s{bits}le", "-"], True)["stdout"]
        frame_bytes = channels * bits // 8
        facts = {**file_record(path), "probe": probe, "decoded_pcm_sha256": hashlib.sha256(decoded).hexdigest(),
                 "decoded_pcm_bytes": len(decoded), "frames": len(decoded) // frame_bytes,
                 "passed": probe["passed"] and len(decoded) > 0 and len(decoded) % frame_bytes == 0}
        return facts, decoded

    def inspect_report(path, mode, filters, bits, channels):
        # Export only selected facts and hashes. Raw paths, metadata and native
        # report diagnostics remain in the ignored local run directory.
        report = json.loads(path.read_text(encoding="utf-8-sig"))
        text_path, summary_path = path.with_suffix(".txt"), path.parent / "WinAudioClean_Log.txt"
        text = text_path.read_text(encoding="utf-8-sig")
        combined = summary_path.read_text(encoding="utf-8-sig")
        facts = {**file_record(path), "text": file_record(text_path), "summary": file_record(summary_path),
                 "schema_version": report.get("schemaVersion"), "tool_version": report.get("toolVersion"),
                 "preset_id": report.get("presetId"), "preset_name": report.get("presetName"),
                 "preset_version": report.get("presetVersion"), "preset_version_reason": report.get("presetVersionReason"),
                 "mode": report["settings"]["mode"], "exact_filters": report["settings"]["exactFilters"],
                 "loudness_mode": report["settings"]["loudnessMode"],
                 "fast_has_no_measurement_stages": all(report["normalization"][name] is None for name in ("analysis", "render", "final")),
                 "normalization_requested_mode": report["normalization"]["requestedMode"],
                 "normalization_actual_type": report["normalization"]["actualType"],
                 "format": report["output"]["format"], "requested_targets": report["requestedTargets"],
                 "measurements": report["measurements"], "loudness_compliance": report["loudnessCompliance"],
                 "status": report["status"], "published": report["output"]["published"],
                 "application_exit_code": report["applicationExitCode"], "native_exit_code": report["nativeExitCode"],
                 "text_contiguous_in_summary": text.strip() in combined,
                 "text_retains_preset_identity": f"PRESET         : Original (ID: {PRESET_ID}; version: {PRESET_VERSION})" in text,
                 "same_ffmpeg_path": Path(report["dependencies"]["ffmpeg"]["path"]).resolve() == ffmpeg,
                 "same_ffmpeg_version": report["dependencies"]["ffmpeg"]["version"] == summary["tools"]["ffmpeg"]["version"]}
        expected_format = {"sampleRate": RATE, "bitDepth": bits, "codec": f"pcm_s{bits}le", "channels": channels,
                           "channelLayout": "mono" if channels == 1 else "stereo", "container": "RIFF"}
        facts["passed"] = (facts["schema_version"] == 1 and facts["tool_version"] == application_version
                           and facts["preset_id"] == PRESET_ID and facts["preset_name"] == "Original" and facts["preset_version"] == PRESET_VERSION
                           and facts["preset_version_reason"] is None and facts["mode"] == mode
                           and facts["exact_filters"] == filters and facts["format"] == expected_format
                           and facts["requested_targets"] == {"integratedLufs": -12, "truePeakDbtp": -1.5, "loudnessRangeLu": 7}
                           and facts["loudness_mode"] == "Fast" and facts["fast_has_no_measurement_stages"]
                           and facts["normalization_requested_mode"] == "Fast" and facts["normalization_actual_type"] is None
                           and facts["status"] == "SUCCESS" and facts["published"]
                           and facts["application_exit_code"] == 0 and facts["native_exit_code"] == 0
                           and facts["text_contiguous_in_summary"] and facts["text_retains_preset_identity"]
                           and facts["same_ffmpeg_path"] and facts["same_ffmpeg_version"]
                           and facts["loudness_compliance"] == {"status": "NOT_MEASURED", "reason": "no_independent_measurement"}
                           and all(facts["measurements"].get(name) == {"value": None, "reason": "not_measured"}
                                   for name in ("integratedLufs", "truePeakDbtp", "loudnessRangeLu")))
        return facts

    try:
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        filters = {"Raw": baseline["filters"]["raw_clean"] + "," + baseline["filters"]["level"],
                   "Zoom": baseline["filters"]["level"]}
        summary["baseline"] = {"reviewed_commit": baseline["reviewed_commit"], "filters": filters,
                               "export_settings": "Explicit 48 kHz PCM16/24 RIFF, preserved mono/stereo; these are M1 encoding settings, not the historical implicit encoder defaults."}
        for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe)):
            result = checked(name + "-version", [tool, "-version"])
            summary["tools"][name]["version"] = result["stdout"].splitlines()[0]
        spec = importlib.util.spec_from_file_location("wac_synthetic_fixtures", generator_path)
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        definitions = [("stereo", 48000, 2, 8.0, "varying_tones"), ("mono", 44100, 1, 3.0, "varying_tones"),
                       ("short", 48000, 1, 0.2, "varying_tones"), ("silence", 48000, 1, 3.0, "silence")]
        fixture_paths = {}
        for name, rate, channels, seconds, kind in definitions:
            path = fixtures / (name + ".wav")
            record = generator.write_pcm(path, rate=rate, channels=channels, seconds=seconds, kind=kind)
            summary["fixtures"].append({"id": name, "path": str(path.relative_to(repo)), **record})
            fixture_paths[name] = path
        configs = [(name, channels, seconds, mode, 16) for name, _, channels, seconds, _ in definitions for mode in ("Raw", "Zoom")]
        configs += [("stereo", 2, 8.0, mode, 24) for mode in ("Raw", "Zoom")]
        reference_pcm = {}
        for name, channels, seconds, mode, bits in configs:
            label = f"{name}-{mode.lower()}-{bits}"
            path = references / (label + ".wav")
            checked("reference-" + label, [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", fixture_paths[name],
                    "-map", "0:0", "-vn", "-af", filters[mode], "-ar", RATE, "-c:a", f"pcm_s{bits}le", "-ac", channels,
                    "-channel_layout", "mono" if channels == 1 else "stereo", "-map_metadata", "-1", "-map_chapters", "-1",
                    "-f", "wav", "-rf64", "never", path])
            facts, decoded = inspect_audio("reference-" + label, path, channels, bits)
            facts["id"] = label
            facts["duration_matches_input"] = abs(facts["frames"] / RATE - seconds) <= 0.01
            facts["passed"] &= facts["duration_matches_input"]
            summary["references"].append(facts)
            reference_pcm[label] = decoded
        for shell_name, prefix in (("powershell.exe", "ps51"), ("pwsh.exe", "ps7")):
            shell = shutil.which(shell_name)
            if shell is None:
                raise RuntimeError(f"Required shell not found: {shell_name}")
            result = checked(prefix + "-version", [shell, "-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"])
            summary["environment"][prefix] = result["stdout"].strip()
            for name, channels, seconds, mode, bits in configs:
                label = f"{name}-{mode.lower()}-{bits}"
                case_id = prefix + "-" + label
                destination = output / case_id
                destination.mkdir()
                command = [shell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", runtime[0],
                           "-inputPath", fixture_paths[name], "-OutputDirectory", destination, "-Mode", mode,
                           "-FfmpegPath", ffmpeg, "-FfprobePath", ffprobe, "-NonInteractive"]
                if bits != 16:
                    command += ["-BitDepth", bits]
                result = run(case_id, command)
                audio = list(destination.glob("*_Cleaned_*.wav"))
                reports = list(destination.glob("WinAudioClean_*.json"))
                partials = list(destination.glob(".wac-*.partial"))
                case = {"id": case_id, "reference_id": label, "mode": mode, "bits": bits,
                        "exit_code": result["exit_code"], "final_count": len(audio), "report_count": len(reports),
                        "partial_count": len(partials), "passed": result["exit_code"] == 0 and not result["timed_out"]
                        and len(audio) == 1 and len(reports) == 1 and not partials}
                if len(audio) == 1:
                    case["audio"], decoded = inspect_audio(case_id, audio[0], channels, bits)
                    case["zero_lag_decoded_pcm_equal_to_baseline"] = decoded == reference_pcm[label]
                    case["duration_matches_input"] = abs(case["audio"]["frames"] / RATE - seconds) <= 0.01
                    case["passed"] &= (case["audio"]["passed"] and case["zero_lag_decoded_pcm_equal_to_baseline"]
                                       and case["duration_matches_input"])
                if len(reports) == 1:
                    case["report"] = inspect_report(reports[0], mode, filters[mode], bits, channels)
                    case["passed"] &= case["report"]["passed"]
                summary["cases"].append(case)
                print(f"{case_id}: {'PASS' if case['passed'] else 'FAIL'}", flush=True)
        summary["fixtures_unchanged"] = all(sha256(repo / fixture["path"]) == fixture["sha256"] for fixture in summary["fixtures"])
        summary["source_sha256_after"] = source_hashes()
        summary["sources_unchanged_during_run"] = summary["source_sha256_before"] == summary["source_sha256_after"]
        summary["status"] = "pass" if (len(summary["cases"]) == 20 and summary["fixtures_unchanged"]
                                            and summary["sources_unchanged_during_run"]
                                            and all(case["passed"] for case in summary["cases"] + summary["references"])) else "fail"
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
        evidence.write_text(json.dumps(sanitize(summary), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Evidence: {sanitize(str(evidence))}", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
