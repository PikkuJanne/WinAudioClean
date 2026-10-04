#!/usr/bin/env python3
"""Development-only execution of packaged README and Get-Help examples on Windows.

The controller needs Python/Git; the application does not. It validates the
clean committed ZIP first, copies the approved FFmpeg pair beside each freshly
extracted application, and supplies a disclosed eight-second synthetic WAV.
README fence contents are retained byte-for-byte and evaluated unchanged. Raw
logs, reports and media remain in a new ignored local directory. Only fixed
codes, example IDs, versions, hashes and validation facts reach summary.json.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import sys
import uuid
import zipfile

# Import the existing read-only archive/controller helpers without creating a
# Python cache in the source tree whose clean state is being checked.
sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location("wac_release_checks", Path(__file__).with_name("Test-ReleasePackage.py"))
release = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(release)
CheckError = release.CheckError
require = release.require
REPO = release.REPO

FENCE = re.compile(rb"(?m)^```powershell[ \t]*\r?\n(.*?)^```[ \t]*\r?$", re.DOTALL)
LABEL = re.compile(rb"(?m)^<!-- example: ([a-z][a-z0-9-]{0,63}) -->\r?\n\Z")
WARNING_CODES = {
    "normalization_fallback", "normalization_result_unavailable",
    "final_loudness_out_of_tolerance", "final_loudness_unmeasurable",
    "final_loudness_failed", "comparison_unmeasurable", "comparison_out_of_tolerance",
}
README_REPORT_COUNTS = {"first-run": 1, "raw-24": 1, "accurate": 1, "gentle": 1,
                        "track-mono-rf64": 1, "preview": 1, "list": 2, "manifest": 1,
                        "folder": 1, "settings-save": 0, "settings-show": 0, "settings-reset": 0,
                        "bat": 1, "help": 0, "diagnostic": 0}
RAW_CLEANING = {"schemaVersion": 1, "Declip": True, "Declick": True, "Denoise": True,
                "Gate": True, "HighpassHz": 80, "NoiseFloorDb": -25, "NoiseReductionDb": 12,
                "GateThresholdDb": -45, "GateRangeDb": -25}
GENTLE_CLEANING = dict(RAW_CLEANING, Declip=False, Declick=False, Gate=False,
                       HighpassHz=60, NoiseFloorDb=-35, NoiseReductionDb=4)


def expected_case(identifier):
    """Independent documented requests, not values read back from a report."""
    expected = {"mode": "Zoom", "bitDepth": 16, "mono": False, "rf64": False,
                "loudnessMode": "Fast", "presetId": "original", "presetVersion": "1.0.0",
                "presetCustomized": False, "cleaning": None, "preview": False,
                "job_folder": False, "action": None}
    if identifier in {"raw-24", "help-example-2"}:
        expected.update(mode="Raw", bitDepth=24, cleaning=RAW_CLEANING)
    if identifier in {"accurate", "help-example-3"}:
        expected["loudnessMode"] = "Accurate"
    if identifier in {"gentle", "help-example-4"}:
        expected.update(mode="Raw", presetId="gentle", presetVersion="0.1.0",
                        presetCustomized=True, cleaning=GENTLE_CLEANING)
    if identifier == "track-mono-rf64":
        expected.update(bitDepth=24, mono=True, rf64=True)
    if identifier in {"preview", "help-example-5", "diagnostic-preview-source"}:
        expected["preview"] = True
    if identifier == "list":
        expected["job_folder"] = True
    if identifier in {"settings-save", "settings-show", "settings-reset"}:
        expected["action"] = identifier
    if identifier == "help-example-6":
        expected["action"] = "settings-save"
    return expected

HELP_AUDIT = r"""
$ErrorActionPreference='Stop'
$app=Join-Path (Get-Location) 'WinAudioClean.ps1'
$help=Get-Help -Name $app -Full
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($app,[ref]$tokens,[ref]$parseErrors)
if (@($parseErrors).Count) { throw 'Source parser failed.' }
$parameters=@(foreach ($parameter in $ast.ParamBlock.Parameters) {
    $hidden=$false
    foreach ($attribute in $parameter.Attributes) {
        foreach ($argument in $attribute.NamedArguments) {
            if ($argument.ArgumentName -eq 'DontShow' -and $argument.Argument.Extent.Text -eq '$true') { $hidden=$true }
        }
    }
    if (-not $hidden) {
        $name=$parameter.Name.VariablePath.UserPath
        $documented=@($help.parameters.parameter | Where-Object { $_.name -eq $name })
        $description=(@($documented | ForEach-Object { $_.description } | ForEach-Object { $_.Text }) -join "`n")
        $default=$null
        if ($null -ne $parameter.DefaultValue) { $default=$parameter.DefaultValue.Extent.Text }
        [ordered]@{ name=$name; description=$description; default_expression=$default;
            help_default=$(if ($documented.Count -eq 1) { [string]$documented[0].defaultValue } else { $null });
            help_entry_count=$documented.Count }
    }
})
$examples=@($help.examples.example | ForEach-Object { [ordered]@{ code=[string]$_.code } })
[ordered]@{ shell_version=$PSVersionTable.PSVersion.ToString();
    application_data=[Environment]::GetFolderPath('ApplicationData');
    music_directory=[Environment]::GetFolderPath('MyMusic');
    elevated_administrator=([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
    parameters=$parameters; examples=$examples } |
    ConvertTo-Json -Depth 8 -Compress
"""


def source_state():
    return (release.git("rev-parse", "HEAD").strip(),
            release.git("status", "--porcelain=v1", "--untracked-files=all", "-z"))


def readme_examples(data):
    """Extract original bytes; require a stable ID for every PowerShell fence."""
    blocks = []
    for match in FENCE.finditer(data):
        prefix = data[:match.start()]
        preceding = prefix.splitlines(keepends=True)[-1:] or [b""]
        label = LABEL.fullmatch(preceding[0])
        require(label is not None, "readme_unlabelled_powershell_fence")
        identifier = label[1].decode("ascii")
        code = match[1]
        require(code.strip() and identifier not in {item["id"] for item in blocks}, "readme_empty_or_duplicate_example")
        require(not re.search(rb"(?i)-(?:PickFile|OpenOutputFolder)\b", code), "interactive_documentation_example")
        blocks.append({"id": identifier, "code": code})
    require(blocks and len(blocks) == len(re.findall(rb"(?m)^```powershell\b", data)), "readme_fence_inventory")
    return blocks


def payload_unchanged(package, contents, tools):
    try:
        release.ordinary_path(package)
        for name, data in contents.items():
            path = package.joinpath(*name.split("/"))
            release.ordinary_path(path, file=True)
            if path.read_bytes() != data:
                return False
        for name, expected_hash in tools.items():
            path = package / (name + ".exe")
            release.ordinary_path(path, file=True)
            if release.file_digest(path) != expected_hash:
                return False
        return True
    except (OSError, CheckError):
        return False


def extract_package(output, label, contents, tools, *, include_tools=True):
    package = output / (label[:20] + " äö " + uuid.uuid4().hex)
    package.mkdir()
    for name, data in contents.items():
        target = package.joinpath(*name.split("/"))
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write(data)
    if include_tools:
        for name, path in tools.items():
            shutil.copyfile(path, package / (name + ".exe"))
    fixture = package / "recording.wav"
    release.generate_tone(fixture)
    release.ordinary_path(package)
    return package, fixture, release.file_digest(fixture)


def file_inventory(package):
    inventory = {}
    for path in package.rglob("*"):
        if path.is_file():
            release.ordinary_path(path, file=True)
            inventory[path.relative_to(package).as_posix()] = release.file_digest(path)
    return inventory


def local_file(value, package):
    require(isinstance(value, str), "report_path_type")
    require(Path(value).is_absolute(), "report_path_not_absolute")
    path = Path(os.path.normpath(value))
    package = Path(os.path.normpath(str(package)))
    try:
        path.relative_to(package)
    except ValueError as exc:
        raise CheckError("report_outside_local_fixture") from exc
    release.ordinary_path(path, file=True)
    return path


def local_directory(value, package):
    require(isinstance(value, str) and Path(value).is_absolute(), "report_directory_type")
    path = Path(os.path.normpath(value))
    try:
        path.relative_to(Path(os.path.normpath(str(package))))
    except ValueError as exc:
        raise CheckError("report_outside_local_fixture") from exc
    release.ordinary_path(path)
    return path


def finite_number(value):
    return type(value) in {int, float} and math.isfinite(value)


def requested_report_policy(report, expected, package, path):
    settings = report["settings"]
    for name in ("mode", "bitDepth", "mono", "rf64", "loudnessMode"):
        require(settings.get(name) == expected[name] and
                (name not in {"mono", "rf64"} or type(settings[name]) is bool), "requested_setting_ignored")
    for name in ("presetId", "presetVersion", "presetCustomized"):
        require(report.get(name) == expected[name], "requested_preset_ignored")
    require(type(report["presetCustomized"]) is bool and type(report["presetExperimental"]) is bool,
            "preset_flag_type")
    require(settings.get("cleaning") == expected["cleaning"], "requested_cleaning_ignored")
    if expected["cleaning"] is not None:
        require(all(type(settings["cleaning"][name]) is bool for name in ("Declip", "Declick", "Denoise", "Gate")) and
                all(finite_number(settings["cleaning"][name]) for name in
                    ("HighpassHz", "NoiseFloorDb", "NoiseReductionDb", "GateThresholdDb", "GateRangeDb")),
                "cleaning_field_type")
    require((report.get("reportType") == "preview") is expected["preview"], "requested_route_ignored")
    require(report["input"].get("streamIndex", report["input"].get("stream", {}).get("index")) == 0,
            "requested_audio_stream_ignored")
    organization = report.get("outputOrganization") if expected["preview"] else report["output"].get("organization")
    if expected["job_folder"]:
        require(isinstance(organization, dict), "requested_job_folder_ignored")
        root = local_directory(organization["rootDirectory"], package)
        media = local_directory(organization["mediaDirectory"], package)
        reports = local_directory(organization["reportDirectory"], package)
        require(root.parent == package / "Exports" and re.fullmatch(r"WinAudioClean_Job_[a-f0-9]{32}", root.name) and
                media == root / "media" and reports == root / "reports" and path.parent == reports and
                local_file(report["output"]["path"], package).parent == media, "requested_output_layout_ignored")
    else:
        require(organization is None and path.parent == package / "Exports", "requested_flat_layout_ignored")


def metric_projection(metrics, measurement):
    require(set(metrics) == {"integratedLufs", "truePeakDbtp", "loudnessRangeLu"}, "measurement_key_inventory")
    for public, internal in (("integratedLufs", "InputI"), ("truePeakDbtp", "InputTP"), ("loudnessRangeLu", "InputLRA")):
        value = measurement[internal]
        require(value is None or finite_number(value), "nonfinite_measurement")
        reason = None if value is not None else measurement["Reason"]
        require(metrics[public] == {"value": value, "reason": reason}, "measurement_projection_mismatch")


def measured_stage(stage, source, *, allow_native_failure=False):
    require(stage.get("status") in {"PASSED", "FAILED"} and stage.get("inputSource") == source and
            isinstance(stage.get("arguments"), list) and stage["arguments"] and
            isinstance(stage.get("process"), dict), "loudness_stage_structure")
    process = stage["process"]
    require({"Started", "TimedOut", "Cancelled", "ExitCode", "Error", "CleanupError"} <= set(process) and
            all(type(process[key]) is bool for key in ("Started", "TimedOut", "Cancelled")) and
            (process["ExitCode"] is None or type(process["ExitCode"]) is int) and
            all(process[key] is None or isinstance(process[key], str) for key in ("Error", "CleanupError")),
            "loudness_native_result_schema")
    if stage["status"] == "FAILED" and allow_native_failure:
        require(stage.get("measurement") is None and process["Cancelled"] is False and
                isinstance(stage.get("error"), str) and bool(stage["error"].strip()),
                "failed_final_stage_missing_reason")
        return None
    require(process.get("Started") is True and process.get("TimedOut") is False and
            process.get("Cancelled") is False and process.get("ExitCode") == 0 and
            not process.get("Error") and not process.get("CleanupError"),
            "loudness_stage_native_failure")
    if stage["status"] == "PASSED":
        measurement = stage["measurement"]
        require(type(measurement.get("Available")) is bool, "measurement_availability")
        for key in ("InputI", "InputTP", "InputLRA", "InputThreshold", "TargetOffset"):
            require(measurement.get(key) is None or finite_number(measurement[key]), "nonfinite_measurement")
        require(not measurement["Available"] or all(finite_number(measurement[key]) for key in
                ("InputI", "InputTP", "InputLRA", "InputThreshold", "TargetOffset")), "available_measurement_incomplete")
        require(measurement["Reason"] is None if measurement["Available"] else
                measurement["Reason"] in {"too_short", "silence", "undefined_loudness"}, "measurement_reason")
        return measurement
    require(stage.get("measurement") is None, "failed_stage_has_measurement")
    return None


def accurate_claims(report):
    normalization = report["normalization"]
    warnings = set(report["warningCodes"])
    require(normalization["requestedMode"] == "Accurate" and type(normalization["linearRequested"]) is bool,
            "accurate_requested_mode_ignored")
    analysis = measured_stage(normalization["analysis"], "file")
    require(analysis is not None, "accurate_analysis_not_passed")
    render = measured_stage(normalization["render"], "file")
    final = measured_stage(normalization["final"], "held_output_stream", allow_native_failure=True)
    require(normalization.get("prechain", "").endswith(",aresample=192000") and
            "loudnorm=I=-12:TP=-1.5:LRA=7" in normalization.get("renderFilter", ""), "accurate_filter_scope")
    for stage_name, filter_name in (("analysis", "analysisFilter"), ("render", "renderFilter"), ("final", "finalMeasurementFilter")):
        arguments = normalization[stage_name]["arguments"]
        require(all(isinstance(value, str) for value in arguments) and arguments.count("-af") == 1 and
                arguments.index("-af") + 1 < len(arguments) and
                arguments[arguments.index("-af") + 1] == normalization[filter_name], "accurate_stage_filter_mismatch")
    final_arguments = normalization["final"]["arguments"]
    require(final_arguments.count("-i") == 1 and final_arguments.index("-i") + 1 < len(final_arguments) and
            final_arguments[final_arguments.index("-i") + 1] == "pipe:0",
            "accurate_final_input_scope")
    requested_linear = ":linear=true:" if normalization["linearRequested"] else ":linear=false:"
    require(requested_linear in normalization["renderFilter"], "accurate_linear_request_mismatch")
    if render is None:
        require("normalization_result_unavailable" in warnings, "accurate_render_warning_missing")
    else:
        require(normalization["actualType"] == render["NormalizationType"] in {"linear", "dynamic"}, "accurate_render_type")
    fallback = normalization["fallbackReason"]
    require(fallback in {None, "measurement_out_of_range", "too_short", "silence", "undefined_loudness", "ffmpeg_dynamic_fallback"},
            "accurate_fallback_reason")
    require((fallback is not None) == ("normalization_fallback" in warnings), "accurate_fallback_warning")
    if final is None:
        require(set(report["measurements"]) == {"integratedLufs", "truePeakDbtp", "loudnessRangeLu"} and
                all(metric == {"value": None, "reason": "measurement_failed"}
                    for metric in report["measurements"].values()), "failed_final_measurement_claim")
        compliance = {"status": "FAILED", "reason": "measurement_failed"}
    else:
        metric_projection(report["measurements"], final)
        if final["InputTP"] is not None and final["InputTP"] > -1.3:
            compliance = {"status": "OUT_OF_TOLERANCE", "reason": "true_peak_exceeded"}
        elif not final["Available"]:
            compliance = {"status": "UNMEASURABLE", "reason": final["Reason"]}
        elif abs(final["InputI"] + 12) > 0.5:
            compliance = {"status": "OUT_OF_TOLERANCE", "reason": "loudness_out_of_tolerance"}
        else:
            compliance = {"status": "PASSED", "reason": None}
    require(report["loudnessCompliance"] == compliance, "accurate_compliance_claim")
    needed = None if compliance["status"] == "PASSED" else "final_loudness_" + compliance["status"].lower()
    require((needed is None or needed in warnings) and
            not any(code.startswith("final_loudness_") and code != needed for code in warnings), "accurate_compliance_warning")


def preview_claims(report):
    expected_range = {"startSeconds": 1, "durationSeconds": 3, "startSamples": 48000, "durationSamples": 144000,
                      "requestedStartSeconds": 1, "requestedDurationSeconds": 3, "durationExplicit": True,
                      "defaultDurationClipped": False, "windowStartSeconds": 0, "windowDurationSeconds": 8,
                      "trimStartSamples": 48000, "trimEndSamples": 192000, "preRollSeconds": 1, "postRollSeconds": 4}
    require(all(report["range"].get(key) == value for key, value in expected_range.items()), "requested_preview_range_ignored")
    assets = report["assets"]
    for asset in assets.values():
        require(asset["frames"] == 144000 and asset["durationSeconds"] == 3, "preview_asset_interval")
        measurement = measured_stage(asset["measurementStage"], "held_output_stream")
        require(measurement is not None, "preview_asset_measurement_failed")
        metric_projection(asset["measurements"], measurement)
        require(asset["format"] == {"sampleRate": 48000, "bitDepth": 16, "codec": "pcm_s16le", "channels": 2,
                                    "channelLayout": "stereo", "container": "RIFF"}, "preview_asset_format_claim")
    matching = report["matching"]
    require(type(matching["available"]) is bool and matching["peakCeilingDbtp"] == -1.5 and
            matching["headroomTargetDbtp"] == -1.7 and matching["toleranceLu"] == 0.2 and
            all(finite_number(matching[key]) and matching[key] <= 0 for key in ("originalGainDb", "processedGainDb")),
            "preview_matching_policy")
    for role, key in (("CompareOriginal", "originalGainDb"), ("CompareProcessed", "processedGainDb")):
        require(assets[role]["gainDb"] == matching[key], "preview_comparison_gain")
        peak = assets[role]["measurementStage"]["measurement"]["InputTP"]
        require(peak is None or peak <= -1.5, "preview_comparison_peak_claim")
    require(assets["Original"]["gainDb"] == assets["Processed"]["gainDb"] == 0, "preview_source_gain")
    base_available = all(assets[role]["measurementStage"]["measurement"]["Available"] for role in ("Original", "Processed"))
    require(matching["available"] is base_available, "preview_matching_availability")
    original = assets["Original"]["measurementStage"]["measurement"]
    processed = assets["Processed"]["measurementStage"]["measurement"]
    if base_available:
        target = min(original["InputI"], processed["InputI"], original["InputI"] - original["InputTP"] - 1.7,
                     processed["InputI"] - processed["InputTP"] - 1.7)
        require(finite_number(matching["commonTargetLufs"]) and abs(matching["commonTargetLufs"] - target) <= 1e-9,
                "preview_matching_target")
        gains = {"originalGainDb": min(0, target - original["InputI"]),
                 "processedGainDb": min(0, target - processed["InputI"])}
    else:
        require(matching["commonTargetLufs"] is None, "unavailable_preview_target_claim")
        gains = {"originalGainDb": 0 if original["InputTP"] is None else min(0, -1.7 - original["InputTP"]),
                 "processedGainDb": 0 if processed["InputTP"] is None else min(0, -1.7 - processed["InputTP"])}
    require(all(abs(matching[key] - value) <= 1e-9 for key, value in gains.items()), "preview_derived_gain_mismatch")
    warnings = set(report["warningCodes"])
    if base_available and all(assets[role]["measurementStage"]["measurement"]["Available"] for role in ("CompareOriginal", "CompareProcessed")):
        difference = abs(assets["CompareOriginal"]["measurementStage"]["measurement"]["InputI"] -
                         assets["CompareProcessed"]["measurementStage"]["measurement"]["InputI"])
        require(finite_number(matching["pairDifferenceLu"]) and abs(matching["pairDifferenceLu"] - difference) <= 1e-9,
                "preview_matching_difference")
        passed = difference <= 0.2 + 1e-9
        require(matching["status"] == ("PASSED" if passed else "OUT_OF_TOLERANCE") and
                matching["reason"] == (None if passed else "comparison_loudness_difference") and
                ("comparison_out_of_tolerance" in warnings) is (not passed), "preview_matching_status")
    else:
        require(matching["status"] == "UNMEASURABLE" and matching["pairDifferenceLu"] is None and
                "comparison_unmeasurable" in warnings, "preview_unmeasurable_claim")


def inspect_pcm(path, *, bits, channels, frames, container):
    """Verify actual RIFF/RF64 PCM chunks rather than trusting report metadata."""
    data = path.read_bytes()
    signature = b"RF64" if container == "RF64" else b"RIFF"
    require(len(data) >= 44 and data[:4] == signature and data[8:12] == b"WAVE", "wave_container")
    require(container == "RF64" or struct.unpack_from("<I", data, 4)[0] + 8 == len(data), "wave_size")
    chunks = {}
    position = 12
    rf64_sizes = None
    while position + 8 <= len(data):
        name, size = struct.unpack_from("<4sI", data, position)
        if name == b"ds64":
            require(size >= 28 and position + 8 + size <= len(data), "wave_rf64_header")
            rf64_sizes = struct.unpack_from("<3Q", data, position + 8)
        if name == b"data" and size == 0xffffffff:
            require(rf64_sizes is not None, "wave_rf64_data_size")
            size = rf64_sizes[1]
        end = position + 8 + size
        require(end <= len(data) and (name not in chunks or name not in {b"fmt ", b"data"}), "wave_chunks")
        chunks[name] = data[position + 8:end]
        position = end + (size & 1)
    require(position == len(data) and b"fmt " in chunks and b"data" in chunks, "wave_chunks")
    fmt = chunks[b"fmt "]
    require(len(fmt) >= 16, "wave_format")
    kind, actual_channels, rate, byte_rate, alignment, actual_bits = struct.unpack_from("<HHIIHH", fmt)
    pcm = kind == 1
    if kind == 65534:
        pcm = len(fmt) >= 40 and fmt[24:40] == bytes.fromhex("0100000000001000800000aa00389b71")
        pcm = pcm and struct.unpack_from("<H", fmt, 18)[0] == bits
    expected_alignment = channels * (bits // 8)
    require(pcm and (actual_channels, rate, byte_rate, alignment, actual_bits) ==
            (channels, 48000, 48000 * expected_alignment, expected_alignment, bits), "wave_pcm_policy")
    require(len(chunks[b"data"]) == frames * alignment, "wave_frame_count")
    if container == "RF64":
        require(rf64_sizes and rf64_sizes == (len(data) - 8, frames * alignment, frames), "wave_rf64_sizes")
    return {"sha256": release.digest(data), "container": container, "codec": "pcm_s%dle" % bits,
            "sample_rate": 48000, "bit_depth": bits, "channels": channels, "frames": frames}


def inspect_report(path, package, fixture, version, tool_hashes, allow_warning, expected=None):
    raw = path.read_bytes()
    report = release.read_json(raw)
    expected = expected or expected_case("first-run")
    require(report.get("schemaVersion") == 1 and report.get("toolVersion") == version, "report_schema_or_version")
    preview = report.get("reportType") == "preview"
    requested_report_policy(report, expected, package, path)
    code = report.get("applicationExitCode")
    require(code in ({0, 7} if allow_warning else {0}) and report.get("status") ==
            ("WARNING" if code == 7 else "SUCCESS"), "report_outcome")
    warnings = report.get("warningCodes")
    require(isinstance(warnings, list) and set(warnings) <= WARNING_CODES and
            bool(warnings) == (code == 7), "unclassified_report_warning")
    require(report.get("reporting", {}).get("complete") is True and
            report["reporting"].get("errors") == [], "reporting_incomplete")
    reported_input = local_file(report["input"]["path"], package)
    require(release.file_digest(reported_input) == release.file_digest(fixture) and
            report["input"]["durationSeconds"] == 8.0, "report_input")
    require(report["settings"]["mode"] in {"Raw", "Zoom"} and
            report["settings"]["loudnessMode"] in {"Fast", "Accurate"}, "report_settings")
    preset = report.get("presetId")
    require((preset, report.get("presetVersion"), report.get("presetExperimental")) in
            {("original", "1.0.0", False), ("gentle", "0.1.0", True)}, "report_preset")
    require(preset != "gentle" or report["settings"]["mode"] == "Raw", "report_gentle_mode")
    for name, expected_hash in tool_hashes.items():
        observed = report["dependencies"][name]
        tool = local_file(observed["path"], package)
        require(tool == package / (name + ".exe") and release.file_digest(tool) == expected_hash and
                re.match(name + r" version 9\.0\.2(?:[-\s]|$)", observed["version"]), "report_tool_identity")
    bits = report["settings"]["bitDepth"]
    channels = 1 if report["settings"]["mono"] else 2
    container = "RF64" if report["settings"]["rf64"] else "RIFF"
    require(bits in {16, 24}, "report_bit_depth")
    text = path.with_suffix(".txt")
    require(text.is_file() and text.read_bytes().strip(), "text_report_missing")
    outputs = []
    if preview:
        preview_claims(report)
        require(set(report["assets"]) == {"Original", "Processed", "CompareOriginal", "CompareProcessed"}, "preview_asset_inventory")
        require(report["normalization"]["scope"] == "bounded_context_window" and
                report["range"]["durationSamples"] > 0 and report["range"]["durationSeconds"] <= 8,
                "preview_scope")
        for asset in report["assets"].values():
            media = local_file(asset["path"], package)
            outputs.append(inspect_pcm(media, bits=bits, channels=channels,
                                       frames=report["range"]["durationSamples"], container=container))
    else:
        require(report.get("sourceRevision") is None and report.get("sourceRevisionReason") == "not_embedded", "report_revision")
        require(report["processingStatus"] == "SUCCESS" and report["processingExitCode"] == 0 and
                report["nativeExitCode"] == 0 and report["reasonCodes"] == [], "report_processing")
        require(report["requestedTargets"] == {"integratedLufs": -12, "truePeakDbtp": -1.5, "loudnessRangeLu": 7} and
                report["loudnessTolerances"] == {"integratedLufs": 0.5, "truePeakDbtp": 0.2}, "report_target_policy")
        require(report["output"]["published"] is True and report["output"]["validity"] == "PASSED", "report_publication")
        format_policy = report["output"]["format"]
        require(format_policy == {"sampleRate": 48000, "bitDepth": bits, "codec": "pcm_s%dle" % bits,
                                  "channels": channels, "channelLayout": "mono" if channels == 1 else "stereo",
                                  "container": container}, "report_format")
        outputs.append(inspect_pcm(local_file(report["output"]["path"], package), bits=bits,
                                   channels=channels, frames=release.FRAMES, container=container))
        summary = path.parent / "WinAudioClean_Log.txt"
        require(summary.is_file() and text.read_bytes().strip() in summary.read_bytes(), "summary_report_missing")
        if report["settings"]["loudnessMode"] == "Fast":
            require(report["loudnessCompliance"] == {"status": "NOT_MEASURED", "reason": "no_independent_measurement"}, "fast_measurement_claim")
        else:
            accurate_claims(report)
    return {"sha256": release.digest(raw), "text_sha256": release.file_digest(text),
            "schema_version": 1, "type": "preview" if preview else "full", "tool_version": version,
            "preset_id": preset, "preset_version": report["presetVersion"], "status": report["status"],
            "application_exit_code": code, "warning_codes": warnings, "local_scope_verified": True,
            "outputs": outputs}


def run_code(host, env, package, code, prefix):
    with prefix.with_suffix(".ps1").open("xb") as stream:
        stream.write(code)
    # The bytes retained above are the exact published example. The wrapper
    # changes no command/argument and only returns the application's exit code.
    wrapper = "$ErrorActionPreference='Stop';[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false);$global:LASTEXITCODE=0;" \
              "& ([ScriptBlock]::Create([Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($env:WAC_CHECK_EXAMPLE))));" \
              "exit $LASTEXITCODE"
    child_env = dict(env, WAC_CHECK_EXAMPLE=str(prefix.with_suffix(".ps1")))
    return release.run_child([str(host), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
                              "-EncodedCommand", release.encoded(wrapper)], package, child_env, prefix)


def inspect_new_reports(package, before, fixture, version, tool_hashes, allow_warning, expected):
    after = file_inventory(package)
    reports = []
    for name in sorted(after.keys() - before.keys()):
        if name.endswith(".json") and Path(name).name.startswith("WinAudioClean_"):
            reports.append(inspect_report(package / name, package, fixture, version, tool_hashes, allow_warning, expected))
    # The documented folder example copies the disclosed fixture before
    # selection. Such byte-identical inputs are distinct from published media.
    input_hash = release.file_digest(fixture)
    new_media = {name for name in after.keys() - before.keys()
                 if name.endswith(".wav") and after[name] != input_hash}
    published = {str(Path(media).relative_to(package).as_posix())
                 for name in after.keys() - before.keys() if name.endswith(".json") and Path(name).name.startswith("WinAudioClean_")
                 for media in report_media_paths(release.read_json((package / name).read_bytes()))}
    require(new_media == published, "unreported_new_media")
    require(not any(name.endswith(".partial") or ".partial." in name for name in after), "partial_output_retained")
    return reports, after


def report_media_paths(report):
    if report.get("reportType") == "preview":
        return [item["path"] for item in report["assets"].values()]
    return [report["output"]["path"]] if report["output"]["published"] else []


def inspect_auxiliary(package, before, after, fixture, code, exit_code, report_count, expected, prefix):
    diagnostics = []
    journals = []
    for name in sorted(after.keys() - before.keys()):
        path = package / name
        if name.endswith(".json") and not Path(name).name.startswith("WinAudioClean_"):
            data = release.read_json(path.read_bytes())
            if data.get("diagnosticExport") == "redacted":
                require(data.get("schemaVersion") == 1 and
                        data.get("diagnostics") == {"omitted": True, "reason": "may_contain_paths_or_metadata"}, "diagnostic_schema")
                require(not re.search(rb"(?:[A-Za-z]:[\\/]|recording\.wav|ffmpeg\.exe|ffprobe\.exe)", path.read_bytes()),
                        "diagnostic_path_leak")
                diagnostics.append({"sha256": after[name], "schema_version": 1, "paths_omitted": True})
        if name.endswith(".jsonl"):
            records = [release.read_json(line) for line in path.read_bytes().splitlines() if line.strip()]
            require(len(records) >= 3 and records[0].get("type") == "batch" and
                    records[0].get("schemaVersion") in {1, 2} and records[-1].get("type") == "summary" and
                    records[-1].get("reportingComplete") is True and records[-1].get("exitCode") == 0 and
                    records[-1].get("status") == "SUCCESS", "journal_completion")
            items = records[1:-1]
            require(records[0]["inputCount"] == len(items) == report_count and
                    records[-1]["counts"]["success"] == len(items), "journal_item_count")
            frozen = records[0]["settings"]
            require(all(frozen.get(key) == expected[key] for key in
                        ("mode", "bitDepth", "mono", "rf64", "loudnessMode")) and
                    frozen.get("preset") == ("Gentle" if expected["presetId"] == "gentle" else "Original") and
                    frozen.get("cleaningOptions") == {}, "journal_requested_settings_ignored")
            destination = local_directory(frozen["outputDirectory"], package)
            if expected["job_folder"]:
                organization = records[0].get("outputOrganization")
                require(isinstance(organization, dict) and destination.name == "media" and
                        destination.parent.parent == package / "Exports" and
                        destination == local_directory(organization["mediaDirectory"], package) and
                        path.parent == local_directory(organization["reportDirectory"], package), "journal_output_layout_ignored")
            else:
                require(destination == package / "Exports" and path.parent == destination, "journal_destination_ignored")
            if records[0]["schemaVersion"] == 2:
                require(records[0]["selection"]["kind"] == "folders" and records[0]["selection"]["recurse"] is False and
                        [local_directory(value, package) for value in records[0]["selection"]["directories"]] == [package / "Inputs"],
                        "journal_folder_selection_ignored")
            for index, item in enumerate(items, 1):
                require(item.get("type") == "item" and item.get("index") == index and
                        item.get("exitCode") == 0 and item.get("status") == "SUCCESS" and
                        item.get("diagnostics") == [], "journal_item_outcome")
                requested = Path(item["inputPath"])
                if not requested.is_absolute():
                    requested = package / requested
                require(release.file_digest(local_file(str(requested), package)) == release.file_digest(fixture), "journal_input")
            journals.append({"sha256": after[name], "schema_version": records[0]["schemaVersion"],
                             "item_count": len(items), "reporting_complete": True})
    if re.search(rb"(?i)-ExportDiagnostic\b", code) and exit_code == 0:
        require(len(diagnostics) == 1, "diagnostic_example_missing_export")
    if re.search(rb"(?i)-(?:InputPaths|InputListPath|InputDirectories)\b", code) and exit_code == 0:
        require(len(journals) == 1, "batch_example_missing_journal")
    if re.search(rb"(?i)-InputListPath\b", code) and exit_code == 0:
        require(release.read_json((package / "inputs.json").read_bytes()) == {"schemaVersion": 1, "inputs": ["recording.wav"]},
                "documented_manifest_not_created")
    if expected["action"] in {"settings-save", "settings-show", "settings-reset"} and exit_code == 0:
        inspect_settings_action(package, prefix, expected)
    if re.search(rb"(?i)-(?:SaveSettings|ResetSettings)\b", code) and exit_code == 0:
        settings = release.read_json((package / "example-settings.json").read_bytes())
        require(settings.get("schemaVersion") == 1 and isinstance(settings.get("settings"), dict), "example_settings_schema")
        if re.search(rb"(?i)-ResetSettings\b", code):
            require(settings["settings"] == {}, "example_reset_not_builtin")
        else:
            require(settings["settings"]["mode"] == "Zoom" and
                    settings["settings"]["bitDepth"] == 16 and
                    settings["settings"]["mono"] is False and settings["settings"]["rf64"] is False and
                    settings["settings"]["loudnessMode"] == "Fast" and
                    settings["settings"]["preset"] == "Original", "example_saved_settings")
    return diagnostics, journals


def inspect_settings_action(package, prefix, expected):
    action = expected["action"]
    saved = release.read_json((package / "example-settings.json").read_bytes())
    lines = [line for line in prefix.with_suffix(".stdout.log").read_bytes().splitlines() if line.startswith(b"{")]
    require(len(lines) == 1, "settings_display_count")
    shown = release.read_json(lines[0])
    require(shown.get("schemaVersion") == 1 and isinstance(shown.get("origins"), dict), "settings_display_schema")
    require(set(shown["origins"]) == {"Mode", "Preset", "LoudnessMode", "BitDepth", "Mono", "Rf64",
                                      "OutputDirectory", "CleaningOptions", "AudioStreamIndex"}, "settings_origin_inventory")
    if action == "settings-reset":
        builtins = {"preset": "Original", "loudnessMode": "Fast", "bitDepth": 16, "mono": False,
                    "rf64": False, "outputDirectory": expected["music_directory"], "cleaningOptions": {}}
        require(saved == {"schemaVersion": 1, "settings": {}} and
                shown["settings"] == builtins and
                shown["effectiveCleaning"] is None and shown["effectiveFilterChain"] is None and
                shown["effectiveProfileReason"] == "mode_not_selected" and
                set(shown["origins"].values()) == {"BuiltIn"} and
                shown["settings"]["outputDirectory"] == expected["music_directory"], "settings_reset_display")
    else:
        expected_saved = {"mode": "Zoom", "preset": "Original", "loudnessMode": "Fast", "bitDepth": 16,
                          "mono": False, "rf64": False, "outputDirectory": str(package / "Exports"), "cleaningOptions": {}}
        require(saved == {"schemaVersion": 1, "settings": expected_saved} and shown["settings"] == expected_saved and
                shown["effectiveCleaning"] is None and shown["effectiveProfileReason"] is None and
                shown["effectiveFilterChain"] == "dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5",
                "saved_settings_requested_choices")
        if action == "settings-show":
            require(all(shown["origins"][name] == "Saved" for name in
                        ("Mode", "Preset", "LoudnessMode", "BitDepth", "Mono", "Rf64", "OutputDirectory", "CleaningOptions")) and
                    shown["origins"]["AudioStreamIndex"] == "BuiltIn", "settings_saved_origins")
        else:
            require(shown["origins"]["Mode"] == shown["origins"]["OutputDirectory"] == "CLI" and
                    all(shown["origins"][name] == "BuiltIn" for name in
                        ("Preset", "LoudnessMode", "BitDepth", "Mono", "Rf64", "CleaningOptions", "AudioStreamIndex")),
                    "settings_save_origins")
    for name, value in (("preset", "Original"), ("loudnessMode", "Fast"), ("bitDepth", 16),
                        ("mono", False), ("rf64", False), ("cleaningOptions", {})):
        require(shown["settings"].get(name) == value, "settings_display_builtin_defaults")


def check_case(host, env, package, code, prefix, fixture, input_hash, contents, tool_hashes, version,
               *, expected_exits=(0,), allow_warning=False, expect_reports=None, preserve_existing=False, expected=None):
    before = file_inventory(package)
    expected = expected or expected_case("first-run")
    old_summaries = {name: (package / name).read_bytes() for name in before if Path(name).name == "WinAudioClean_Log.txt"}
    result = {"passed": False, "error_code": None, "command_sha256": release.digest(code)}
    try:
        result.update(run_code(host, env, package, code, prefix))
        require(result["exit_code"] in expected_exits and not result["timed_out"], "example_exit_or_timeout")
        reports, after = inspect_new_reports(package, before, fixture, version, tool_hashes, allow_warning, expected)
        if expect_reports is not None:
            require(len(reports) == expect_reports, "example_report_count")
        if result["exit_code"] == 7:
            require(allow_warning and any(item["application_exit_code"] == 7 for item in reports), "warning_without_valid_published_report")
        if preserve_existing:
            # The cumulative summary log is intentionally append-only.
            changes = {"example-settings.json"} if expected["action"] == "settings-reset" else set()
            require(all(after.get(name) == value for name, value in before.items()
                        if Path(name).name != "WinAudioClean_Log.txt" and name not in changes), "previous_file_changed")
            require(all((package / name).read_bytes().startswith(data) for name, data in old_summaries.items()),
                    "previous_summary_bytes_changed")
        result["diagnostics"], result["journals"] = inspect_auxiliary(package, before, after, fixture, code,
                                                                     result["exit_code"], len(reports), expected, prefix)
        result["reports"] = reports
        result["new_report_count"] = len(reports)
        result["new_output_count"] = sum(len(item["outputs"]) for item in reports)
        result["passed"] = True
    except CheckError as exc:
        result["error_code"] = str(exc)
        if str(exc) == "owned_child_cleanup_incomplete":
            raise
    except (OSError, ValueError, KeyError, TypeError) as exc:
        prefix.with_suffix(".private-error.txt").write_text(repr(exc), encoding="utf-8")
        result["error_code"] = "case_inspection_failed"
    result["input_unchanged"] = release.file_digest(fixture) == input_hash
    result["payload_and_copied_tools_unchanged"] = payload_unchanged(package, contents, tool_hashes)
    require(result["input_unchanged"] and result["payload_and_copied_tools_unchanged"], "fixture_or_package_changed")
    result["requested_settings_and_route_verified"] = result["passed"]
    return result


def audit_help(host, env, package, output, shell, application_data):
    prefix = output / (shell + "-help-audit")
    result = release.run_child([str(host), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
                                "-EncodedCommand", release.encoded(HELP_AUDIT)], package, env, prefix)
    require(result["exit_code"] == 0 and not result["timed_out"], "help_audit_failed")
    observed = release.read_json(prefix.with_suffix(".stdout.log").read_bytes())
    require(release.VERSION.fullmatch(observed["shell_version"]) and
            observed["shell_version"].startswith("5.1." if shell == "ps51" else "7."), "incorrect_shell_family")
    require(os.path.normcase(observed["application_data"]) == os.path.normcase(str(application_data)),
            "known_folder_lookup_changed")
    defaults = {}
    names = []
    for parameter in observed["parameters"]:
        name = parameter["name"]
        require(re.fullmatch(r"[A-Za-z][A-Za-z0-9]{0,63}", name) and name not in names, "help_parameter_identity")
        require(parameter["help_entry_count"] == 1 and parameter["description"].strip(), "undocumented_public_parameter")
        names.append(name)
        expression = parameter["default_expression"]
        if expression is not None:
            # Read-only literal default facts from the AST; never evaluate source.
            value = expression[1:-1] if expression[:1] in {"'", '"'} and expression[-1:] == expression[:1] else expression
            require(parameter["help_default"] == value, "help_declared_default_mismatch")
            defaults[name] = value
    require(names and observed["examples"], "help_inventory_empty")
    require(type(observed["elevated_administrator"]) is bool, "host_elevation_observation")
    require(defaults == {"BitDepth": "16", "LoudnessMode": "Fast", "Preset": "Original",
                         "CleaningOptions": "@{}", "PreviewStartSeconds": "0", "PreviewDurationSeconds": "45"},
            "unexpected_declared_default_facts")
    return {"shell_version": observed["shell_version"], "elevated_administrator": observed["elevated_administrator"], "public_parameter_count": len(names),
            "public_parameters": names, "all_public_parameters_documented": True, "declared_defaults": defaults,
            "example_count": len(observed["examples"]), "help_output_sha256": result["stdout_sha256"]}, observed["examples"], observed["music_directory"]


def query_application_data(host, env, output, shell):
    prefix = output / (shell + "-known-folder")
    code = "[ordered]@{application_data=[Environment]::GetFolderPath('ApplicationData')} | ConvertTo-Json -Compress"
    result = release.run_child([str(host), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
                                "-EncodedCommand", release.encoded(code)], output, env, prefix)
    require(result["exit_code"] == 0 and not result["timed_out"], "known_folder_query_failed")
    data = release.read_json(prefix.with_suffix(".stdout.log").read_bytes())
    path = Path(data["application_data"])
    require(path.is_absolute() and path.is_dir(), "known_folder_unavailable")
    return path


def user_settings_snapshot(application_data):
    # Observe only existence/type/hash; no user settings content enters summaries.
    directory = application_data / "WinAudioClean"
    path = directory / "settings.json"
    return (directory.exists(), path.exists(), release.file_digest(path) if path.is_file() else None)


ACL_DENY = r"""
$ErrorActionPreference='Stop'
$path=$env:WAC_CHECK_ACL_DIRECTORY
$acl=Get-Acl -LiteralPath $path
$sections=[Security.AccessControl.AccessControlSections]::All
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$state=[ordered]@{original_sddl=$acl.GetSecurityDescriptorSddlForm($sections); current_sid=$sid.Value;
    administrator_token=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
[IO.File]::WriteAllText($env:WAC_CHECK_ACL_STATE,($state | ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
if ($state.administrator_token) { throw 'Normal user token required for this fixture.' }
$rights=[Security.AccessControl.FileSystemRights]::CreateFiles -bor [Security.AccessControl.FileSystemRights]::WriteData -bor [Security.AccessControl.FileSystemRights]::AppendData
$rule=[Security.AccessControl.FileSystemAccessRule]::new($sid,$rights,[Security.AccessControl.AccessControlType]::Deny)
$acl.AddAccessRule($rule)
Set-Acl -LiteralPath $path -AclObject $acl
$after=Get-Acl -LiteralPath $path
$observed=@($after.Access | Where-Object { $_.AccessControlType -eq 'Deny' -and
    $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -eq $sid.Value -and
    ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::CreateFiles) })
$probePath=[IO.Path]::Combine($path,'.wac-permission-probe')
$probe=$null; $writeDenied=$false
try { $probe=[IO.FileStream]::new($probePath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,1,[IO.FileOptions]::DeleteOnClose) }
catch { if ($_.Exception.GetBaseException() -is [UnauthorizedAccessException]) { $writeDenied=$true } else { throw } }
finally { if ($null -ne $probe) { $probe.Dispose() } }
if (-not $writeDenied -or [IO.File]::Exists($probePath)) { throw 'Owned permission fixture did not deny the write probe cleanly.' }
[ordered]@{denial_present=($observed.Count -gt 0); administrator_token=$state.administrator_token;
    write_denied=$writeDenied; denied_sddl=$after.GetSecurityDescriptorSddlForm($sections)} | ConvertTo-Json -Compress
"""

ACL_RESTORE = r"""
$ErrorActionPreference='Stop'
$state=[IO.File]::ReadAllText($env:WAC_CHECK_ACL_STATE,[Text.Encoding]::UTF8) | ConvertFrom-Json
$acl=Get-Acl -LiteralPath $env:WAC_CHECK_ACL_DIRECTORY
# Restore only the snapshotted DACL; owner/group/SACL are never changed.
$acl.SetSecurityDescriptorSddlForm($state.original_sddl,[Security.AccessControl.AccessControlSections]::Access)
Set-Acl -LiteralPath $env:WAC_CHECK_ACL_DIRECTORY -AclObject $acl
$after=Get-Acl -LiteralPath $env:WAC_CHECK_ACL_DIRECTORY
[ordered]@{original_acl_restored=($after.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::All) -ceq $state.original_sddl)} |
    ConvertTo-Json -Compress
"""


def support_permission_case(host, env, output, shell, contents, tool_paths, tool_hashes, version, base):
    package, fixture, input_hash = extract_package(output, shell + "-permissions", contents, tool_paths)
    destination = package / "Exports"
    destination.mkdir()
    release.ordinary_path(destination)
    require(not any(destination.iterdir()), "permission_fixture_not_empty")
    state_path = output / (shell + "-permission-acl.private.json")
    case_env = dict(env, WAC_CHECK_ACL_DIRECTORY=str(destination), WAC_CHECK_ACL_STATE=str(state_path))
    result = {"id": "permission-denied", "shell": shell, "scope": "normal_user_owned_empty_fixture_acl",
              "passed": False, "error_code": None, "administrator_token": None, "original_acl_restored": False}
    setup_prefix = output / (shell + "-permission-deny")
    restore_prefix = output / (shell + "-permission-restore")
    try:
        setup = run_code(host, case_env, package, ACL_DENY.encode("utf-8"), setup_prefix)
        require(setup["exit_code"] == 0 and not setup["timed_out"], "normal_user_acl_scope_unavailable")
        observed = release.read_json(setup_prefix.with_suffix(".stdout.log").read_bytes())
        require(observed["denial_present"] is True and observed["write_denied"] is True and observed["administrator_token"] is False,
                "normal_user_acl_denial_not_observed")
        result["administrator_token"] = False
        result["denial_present"] = True
        result["write_denied"] = True
        result["denied_acl_sha256"] = release.digest(observed["denied_sddl"].encode("utf-8"))
        private_state = release.read_json(state_path.read_bytes())
        result["original_acl_sha256"] = release.digest(private_state["original_sddl"].encode("utf-8"))
        result.update(check_case(host, env, package, (base + "\n").encode("utf-8"),
                                 output / (shell + "-support-permission-denied"), fixture, input_hash,
                                 contents, tool_hashes, version, expected_exits=(2,), expect_reports=0,
                                 preserve_existing=True))
        require(not any(destination.iterdir()), "permission_blocked_destination_not_empty")
        result["blocked_destination_empty"] = True
    except CheckError as exc:
        result["error_code"] = str(exc)
        result["passed"] = False
    finally:
        # The setup persists the original descriptor before the first ACL
        # mutation. Restoration is attempted even when setup/application fails.
        if state_path.is_file():
            restoration = run_code(host, case_env, package, ACL_RESTORE.encode("utf-8"), restore_prefix)
            if restoration["exit_code"] == 0 and not restoration["timed_out"]:
                restored = release.read_json(restore_prefix.with_suffix(".stdout.log").read_bytes())
                result["original_acl_restored"] = restored.get("original_acl_restored") is True
            result["acl_restore_exit_code"] = restoration["exit_code"]
        if not result["original_acl_restored"]:
            result["passed"] = False
            result["error_code"] = "owned_fixture_acl_restore_failed"
    if result["original_acl_restored"] and result["administrator_token"] is False:
        recovery = check_case(host, env, package, (base + "\n").encode("utf-8"),
                              output / (shell + "-support-permission-recovery"), fixture, input_hash,
                              contents, tool_hashes, version, expect_reports=1, preserve_existing=True)
        result["recovery"] = recovery
        result["passed"] = result["passed"] and recovery["passed"]
    require(not (package / "example-settings.json").exists(), "support_settings_created")
    return result


def support_cases(host, env, output, shell, contents, tool_paths, tool_hashes, version):
    cases = []
    base = ("& .\\WinAudioClean.ps1 -inputPath 'recording.wav' -Mode Zoom -OutputDirectory 'Exports' "
            "-NonInteractive -IgnoreSavedSettings -SettingsPath 'example-settings.json'")
    cases.append(support_permission_case(host, env, output, shell, contents, tool_paths, tool_hashes, version, base))
    for identifier, extra, expected in (("missing-tool", " -FfmpegPath 'missing-ffmpeg.exe'", 3),
                                        ("corrupt-input", "", 4), ("destination-file", "", 2)):
        package, fixture, input_hash = extract_package(output, shell + "-" + identifier, contents, tool_paths)
        code = base
        if identifier == "corrupt-input":
            (package / "corrupt.wav").write_bytes(b"This is deliberately not an audio container.\n")
            code = code.replace("'recording.wav'", "'corrupt.wav'")
        if identifier == "destination-file":
            (package / "Exports").write_bytes(b"This file deliberately occupies the destination.\n")
        case = check_case(host, env, package, (code + extra + "\n").encode("utf-8"),
                          output / (shell + "-support-" + identifier), fixture, input_hash, contents,
                          tool_hashes, version, expected_exits=(expected,), expect_reports=0, preserve_existing=True)
        require(not (package / "example-settings.json").exists(), "support_settings_created")
        cases.append({"id": identifier, "shell": shell, "scope": "isolated_support_fault", **case})
    package, fixture, input_hash = extract_package(output, shell + "-support-publication", contents, tool_paths)
    for identifier in ("collision-first", "collision-repeat"):
        case = check_case(host, env, package, (base + "\n").encode("utf-8"), output / (shell + "-support-" + identifier),
                          fixture, input_hash, contents, tool_hashes, version, expect_reports=1, preserve_existing=True)
        cases.append({"id": identifier, "shell": shell, "scope": "isolated_support_publication", **case})
    ordinary = sorted((package / "Exports").glob("WinAudioClean_*.json"))
    require(len(ordinary) == 2 and len(list((package / "Exports").glob("*.wav"))) == 2, "collision_inventory")
    diagnostic = ("$report = Get-ChildItem -LiteralPath 'Exports' -Filter 'WinAudioClean_*.json' | Sort-Object Name | Select-Object -First 1\n"
                  "& .\\WinAudioClean.ps1 -ExportDiagnostic $report.FullName -DiagnosticOutputPath 'Exports\\diagnostic.json' -NonInteractive\n")
    case = check_case(host, env, package, diagnostic.encode("utf-8"), output / (shell + "-support-diagnostic-success"),
                      fixture, input_hash, contents, tool_hashes, version, expect_reports=0, preserve_existing=True)
    diagnostic_path = package / "Exports" / "diagnostic.json"
    if case["passed"]:
        redacted = release.read_json(diagnostic_path.read_bytes())
        require(redacted.get("schemaVersion") == 1 and redacted.get("diagnosticExport") == "redacted" and
                redacted.get("diagnostics") == {"omitted": True, "reason": "may_contain_paths_or_metadata"}, "diagnostic_schema")
        require(str(package).encode("utf-8") not in diagnostic_path.read_bytes() and
                not re.search(rb"(?:[A-Za-z]:[\\/]|recording\.wav|ffmpeg\.exe|ffprobe\.exe)", diagnostic_path.read_bytes()),
                "diagnostic_path_leak")
        case["diagnostic_sha256"] = release.file_digest(diagnostic_path)
    cases.append({"id": "diagnostic-success", "shell": shell, "scope": "isolated_support_diagnostic", **case})
    collision = check_case(host, env, package, diagnostic.encode("utf-8"),
                           output / (shell + "-support-diagnostic-collision"), fixture, input_hash,
                           contents, tool_hashes, version, expected_exits=(2,), expect_reports=0,
                           preserve_existing=True)
    require(release.file_digest(diagnostic_path) == case.get("diagnostic_sha256"), "diagnostic_collision_changed_prior_file")
    cases.append({"id": "diagnostic-collision", "shell": shell, "scope": "isolated_support_diagnostic", **collision})
    preview = base + " -Preview -PreviewStartSeconds 1 -PreviewDurationSeconds 3\n"
    case = check_case(host, env, package, preview.encode("utf-8"), output / (shell + "-support-preview-source"),
                      fixture, input_hash, contents, tool_hashes, version, expected_exits=(0, 7), allow_warning=True,
                      expect_reports=1, preserve_existing=True, expected=expected_case("diagnostic-preview-source"))
    cases.append({"id": "diagnostic-preview-source", "shell": shell, "scope": "isolated_support_preview", **case})
    reject = ("$report = Get-ChildItem -LiteralPath 'Exports' -Filter 'WinAudioClean_Preview_*.json' | Select-Object -First 1\n"
              "& .\\WinAudioClean.ps1 -ExportDiagnostic $report.FullName -DiagnosticOutputPath 'Exports\\rejected-diagnostic.json' -NonInteractive\n")
    case = check_case(host, env, package, reject.encode("utf-8"), output / (shell + "-support-diagnostic-preview-rejection"),
                      fixture, input_hash, contents, tool_hashes, version, expected_exits=(2,), expect_reports=0, preserve_existing=True)
    require(not (package / "Exports" / "rejected-diagnostic.json").exists(), "rejected_diagnostic_created")
    require(not (package / "example-settings.json").exists(), "support_settings_created")
    cases.append({"id": "diagnostic-preview-rejection", "shell": shell, "scope": "isolated_support_diagnostic", **case})
    return cases


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", required=True, type=Path, dest="zip_path")
    parser.add_argument("--commit", required=True)
    for name in ("ffmpeg", "ffprobe", "ps51", "ps7", "output"):
        parser.add_argument("--" + name, required=True, type=Path)
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    summary = {"schema_version": 1, "task": "WAC-M4-04", "passed": False,
               "scope": "synthetic_local_packaged_documentation", "error_code": None,
               "readme_cases": [], "portable_cases": [], "help_cases": [], "support_cases": [], "help_audits": []}
    output_created = False
    try:
        require(os.name == "nt", "windows_required")
        require(release.SHA.fullmatch(args.commit), "invalid_commit")
        for path in (args.zip_path, args.ffmpeg, args.ffprobe, args.ps51, args.ps7):
            release.ordinary_path(path, file=True)
        require(args.ffmpeg.name.casefold() == "ffmpeg.exe" and args.ffprobe.name.casefold() == "ffprobe.exe" and
                args.ffmpeg.parent == args.ffprobe.parent, "approved_tool_pair_required")
        before = source_state()
        require(before == (args.commit.encode("ascii"), b""), "clean_exact_head_required")
        expected, blobs = release.expected_source(args.commit)
        contents, summary["archive"] = release.inspect_archive(args.zip_path, expected, blobs)
        blocks = readme_examples(contents["README.md"])
        portable_blocks = readme_examples(contents["docs/PORTABLE_PACKAGE.md"])
        require({block["id"] for block in blocks} == set(README_REPORT_COUNTS), "unexpected_readme_example_inventory")
        require([block["id"] for block in portable_blocks] == ["verify-zip"], "unexpected_portable_example_inventory")
        sidecar_hashes = {suffix: release.file_digest(args.zip_path.with_suffix(suffix))
                          for suffix in (".sha256", ".provenance.json")}
        release.new_output(args.output)
        output_created = True
        tool_paths = {"ffmpeg": args.ffmpeg, "ffprobe": args.ffprobe}
        tool_hashes = {name: release.file_digest(path) for name, path in tool_paths.items()}
        system_root = Path(os.environ["SystemRoot"])
        fixed_ps51 = system_root / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
        require(os.path.normcase(str(args.ps51)) == os.path.normcase(str(fixed_ps51)), "incorrect_ps51_host")
        module_roots = [args.ps51.parent / "Modules", args.ps7.parent / "Modules"]
        for root in module_roots:
            release.ordinary_path(root)
        # No original FFmpeg directory, Git or Python on the application PATH.
        env = release.child_environment(system_root, args.ps7.parent, module_roots)
        env["PATH"] += os.pathsep + str(fixed_ps51.parent)
        env["PSModuleAnalysisCachePath"] = str(args.output / "module-analysis.cache")
        application_data = {shell: query_application_data(host, env, args.output, shell)
                            for shell, host in (("ps51", args.ps51), ("ps7", args.ps7))}
        settings_before = {shell: user_settings_snapshot(path) for shell, path in application_data.items()}
        summary["tools"] = {}
        for name, path in tool_paths.items():
            prefix = args.output / (name + "-version")
            observed = release.run_child([str(path), "-version"], args.output, env, prefix)
            first = prefix.with_suffix(".stdout.log").read_bytes().decode("utf-8", "replace").splitlines()
            require(observed["exit_code"] == 0 and not observed["timed_out"] and first and
                    re.match(name + r" version 9\.0\.2(?:[-\s]|$)", first[0]), "approved_tool_version_required")
            summary["tools"][name] = {"version": "9.0.2", "sha256": tool_hashes[name]}
        summary["readme_example_count"] = len(blocks)
        summary["fixture"] = {"synthetic": True, "duration_seconds": 8, "channels": 2, "sample_rate": 48000,
                              "filename": "recording.wav", "supplied_by_controller": True}
        summary["extraction"] = {"fresh_packages_per_host": True, "spaces_and_unicode": True,
                                 "writeable_local_folders": True, "tools_supplied_beside_application": True}
        base_env = dict(env)
        for shell, host in (("ps51", args.ps51), ("ps7", args.ps7)):
            env = dict(base_env)
            env["PSModulePath"] = str(host.parent / "Modules")
            download = args.output / (shell + " download äö " + uuid.uuid4().hex)
            download.mkdir()
            copied_zip = download / args.zip_path.name
            copied_checksum = download / args.zip_path.with_suffix(".sha256").name
            shutil.copyfile(args.zip_path, copied_zip)
            shutil.copyfile(args.zip_path.with_suffix(".sha256"), copied_checksum)
            zip_hash = release.file_digest(copied_zip)
            checksum_hash = release.file_digest(copied_checksum)
            for block in portable_blocks:
                case = run_code(host, env, download, block["code"],
                                args.output / (shell + "-portable-" + block["id"]))
                passed = (case["exit_code"] == 0 and not case["timed_out"] and
                          release.file_digest(copied_zip) == zip_hash and
                          release.file_digest(copied_checksum) == checksum_hash)
                summary["portable_cases"].append({"id": block["id"], "shell": shell,
                    "exact_fenced_bytes": True, "command_sha256": release.digest(block["code"]),
                    "passed": passed, "error_code": None if passed else "portable_checksum_example_failed", **case})
            package, fixture, input_hash = extract_package(args.output, shell + "-readme", contents, tool_paths)
            preflight, _ = release.preflight(host, env, args.output, shell + "-preflight", [host.parent / "Modules"])
            audit, examples, music_directory = audit_help(host, env, package, args.output, shell, application_data[shell])
            summary["help_audits"].append({"shell": shell, **audit})
            summary.setdefault("preflight", []).append({"shell": shell, **preflight})
            for block in blocks:
                code = block["code"]
                wanted = expected_case(block["id"])
                if wanted["action"] == "settings-reset":
                    wanted["music_directory"] = music_directory
                warning = bool(re.search(rb"(?i)-Preview\b|-LoudnessMode\s+['\"]?Accurate\b", code))
                case = check_case(host, env, package, code, args.output / (shell + "-readme-" + block["id"]),
                                  fixture, input_hash, contents, tool_hashes, expected["version"],
                                  expected_exits=(0, 7) if warning else (0,), allow_warning=warning,
                                  expect_reports=README_REPORT_COUNTS[block["id"]], preserve_existing=True, expected=wanted)
                summary["readme_cases"].append({"id": block["id"], "shell": shell,
                    "application_host_family": "5.1" if block["id"] in {"first-run", "bat"} else ("5.1" if shell == "ps51" else "7"),
                    "exact_fenced_bytes": True, **case})
            # Help examples are independent user invocations. Each gets a fresh
            # package so saved state from one example cannot conceal omissions.
            for index, example in enumerate(examples, 1):
                code = example["code"].encode("utf-8")
                wanted = expected_case("help-example-" + str(index))
                require(code.strip() and not re.search(rb"(?i)-(?:PickFile|OpenOutputFolder)\b", code), "interactive_help_example")
                package_help, fixture_help, hash_help = extract_package(args.output, shell + "-help-" + str(index), contents, tool_paths)
                warning = bool(re.search(rb"(?i)-Preview\b|-LoudnessMode\s+['\"]?Accurate\b", code))
                case = check_case(host, env, package_help, code, args.output / (shell + "-help-example-" + str(index)),
                                  fixture_help, hash_help, contents, tool_hashes, expected["version"],
                                  expected_exits=(0, 7) if warning else (0,), allow_warning=warning,
                                  expect_reports=0 if re.search(rb"(?i)-SaveSettings\b", code) else 1,
                                  preserve_existing=True, expected=wanted)
                summary["help_cases"].append({"id": "help-example-" + str(index), "shell": shell,
                                              "application_host_family": "5.1" if re.match(rb"powershell\.exe\b", code) else ("5.1" if shell == "ps51" else "7"),
                                              "exact_get_help_code": True, **case})
            summary["support_cases"].extend(support_cases(host, env, args.output, shell, contents, tool_paths, tool_hashes, expected["version"]))
        summary["controller_source_unchanged"] = source_state() == before
        summary["original_tools_unchanged"] = all(release.file_digest(path) == tool_hashes[name] for name, path in tool_paths.items())
        summary["archive_unchanged"] = release.file_digest(args.zip_path) == summary["archive"]["zip_sha256"]
        summary["archive_sidecars_unchanged"] = all(release.file_digest(args.zip_path.with_suffix(suffix)) == wanted
                                                    for suffix, wanted in sidecar_hashes.items())
        summary["user_settings_unchanged"] = all(user_settings_snapshot(path) == settings_before[shell]
                                                 for shell, path in application_data.items())
        summary["user_settings_scope"] = "actual_windows_known_folder_from_each_host"
        summary["maximum_generated_media_path_characters"] = max((len(str(path)) for path in args.output.rglob("*.wav")
                                                                 if path.name != "recording.wav"), default=0)
        summary["maximum_generated_journal_path_characters"] = max((len(str(path)) for path in args.output.rglob("*.jsonl")), default=0)
        summary["readme_case_count"] = len(summary["readme_cases"])
        summary["portable_case_count"] = len(summary["portable_cases"])
        summary["help_case_count"] = len(summary["help_cases"])
        summary["support_case_count"] = len(summary["support_cases"])
        all_cases = summary["readme_cases"] + summary["portable_cases"] + summary["help_cases"] + summary["support_cases"]
        summary["passed"] = (all(case["passed"] for case in all_cases) and
                             summary["readme_case_count"] == 2 * len(blocks) and
                             summary["portable_case_count"] == 2 * len(portable_blocks) and
                             all(summary[key] for key in ("controller_source_unchanged", "original_tools_unchanged",
                                                           "archive_unchanged", "archive_sidecars_unchanged", "user_settings_unchanged")))
    except CheckError as exc:
        summary["error_code"] = str(exc)
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as exc:
        if output_created:
            (args.output / "controller-private-error.txt").write_text(repr(exc), encoding="utf-8")
        summary["error_code"] = "controller_inspection_failed"
    if output_created:
        release.write_json_new(args.output / "summary.json", summary)
    print(json.dumps(summary, ensure_ascii=True, indent=2, allow_nan=False))
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
