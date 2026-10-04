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
                        "folder": 1, "settings": 0, "bat": 1, "help": 0, "diagnostic": 0}

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
    application_data=[Environment]::GetFolderPath('ApplicationData'); parameters=$parameters; examples=$examples } |
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
    package = output / (label + " portable äö " + uuid.uuid4().hex)
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
    path = Path(value)
    require(path.is_absolute(), "report_path_not_absolute")
    try:
        path.relative_to(package)
    except ValueError as exc:
        raise CheckError("report_outside_local_fixture") from exc
    release.ordinary_path(path, file=True)
    return path


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


def inspect_report(path, package, fixture, version, tool_hashes, allow_warning):
    raw = path.read_bytes()
    report = release.read_json(raw)
    require(report.get("schemaVersion") == 1 and report.get("toolVersion") == version, "report_schema_or_version")
    preview = report.get("reportType") == "preview"
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
    wrapper = "$ErrorActionPreference='Stop';$global:LASTEXITCODE=0;" \
              "& ([ScriptBlock]::Create([Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($env:WAC_CHECK_EXAMPLE))));" \
              "exit $LASTEXITCODE"
    child_env = dict(env, WAC_CHECK_EXAMPLE=str(prefix.with_suffix(".ps1")))
    return release.run_child([str(host), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
                              "-EncodedCommand", release.encoded(wrapper)], package, child_env, prefix)


def inspect_new_reports(package, before, fixture, version, tool_hashes, allow_warning):
    after = file_inventory(package)
    reports = []
    for name in sorted(after.keys() - before.keys()):
        if name.endswith(".json") and Path(name).name.startswith("WinAudioClean_"):
            reports.append(inspect_report(package / name, package, fixture, version, tool_hashes, allow_warning))
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


def inspect_auxiliary(package, before, after, fixture, code, exit_code, report_count):
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


def check_case(host, env, package, code, prefix, fixture, input_hash, contents, tool_hashes, version,
               *, expected_exits=(0,), allow_warning=False, expect_reports=None, preserve_existing=False):
    before = file_inventory(package)
    result = {"passed": False, "error_code": None, "command_sha256": release.digest(code)}
    try:
        result.update(run_code(host, env, package, code, prefix))
        require(result["exit_code"] in expected_exits and not result["timed_out"], "example_exit_or_timeout")
        reports, after = inspect_new_reports(package, before, fixture, version, tool_hashes, allow_warning)
        if expect_reports is not None:
            require(len(reports) == expect_reports, "example_report_count")
        if result["exit_code"] == 7:
            require(allow_warning and any(item["application_exit_code"] == 7 for item in reports), "warning_without_valid_published_report")
        if preserve_existing:
            # The cumulative summary log is intentionally append-only.
            require(all(after.get(name) == value for name, value in before.items()
                        if Path(name).name != "WinAudioClean_Log.txt"), "previous_file_changed")
        result["diagnostics"], result["journals"] = inspect_auxiliary(package, before, after, fixture, code,
                                                                     result["exit_code"], len(reports))
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
    require(defaults == {"BitDepth": "16", "LoudnessMode": "Fast", "Preset": "Original",
                         "CleaningOptions": "@{}", "PreviewStartSeconds": "0", "PreviewDurationSeconds": "45"},
            "unexpected_declared_default_facts")
    return {"shell_version": observed["shell_version"], "public_parameter_count": len(names),
            "public_parameters": names, "all_public_parameters_documented": True, "declared_defaults": defaults,
            "example_count": len(observed["examples"]), "help_output_sha256": result["stdout_sha256"]}, observed["examples"]


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


def support_cases(host, env, output, shell, contents, tool_paths, tool_hashes, version):
    cases = []
    base = ("& .\\WinAudioClean.ps1 -inputPath 'recording.wav' -Mode Zoom -OutputDirectory 'Exports' "
            "-NonInteractive -IgnoreSavedSettings -SettingsPath 'example-settings.json'")
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
                      expect_reports=1, preserve_existing=True)
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
        for shell, host in (("ps51", args.ps51), ("ps7", args.ps7)):
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
            preflight, _ = release.preflight(host, env, args.output, shell + "-preflight", module_roots)
            audit, examples = audit_help(host, env, package, args.output, shell, application_data[shell])
            summary["help_audits"].append({"shell": shell, **audit})
            summary.setdefault("preflight", []).append({"shell": shell, **preflight})
            for block in blocks:
                code = block["code"]
                warning = bool(re.search(rb"(?i)-Preview\b|-LoudnessMode\s+['\"]?Accurate\b", code))
                case = check_case(host, env, package, code, args.output / (shell + "-readme-" + block["id"]),
                                  fixture, input_hash, contents, tool_hashes, expected["version"],
                                  expected_exits=(0, 7) if warning else (0,), allow_warning=warning,
                                  expect_reports=README_REPORT_COUNTS[block["id"]], preserve_existing=True)
                summary["readme_cases"].append({"id": block["id"], "shell": shell,
                    "application_host_family": "5.1" if block["id"] in {"first-run", "bat"} else ("5.1" if shell == "ps51" else "7"),
                    "exact_fenced_bytes": True, **case})
            # Help examples are independent user invocations. Each gets a fresh
            # package so saved state from one example cannot conceal omissions.
            for index, example in enumerate(examples, 1):
                code = example["code"].encode("utf-8")
                require(code.strip() and not re.search(rb"(?i)-(?:PickFile|OpenOutputFolder)\b", code), "interactive_help_example")
                package_help, fixture_help, hash_help = extract_package(args.output, shell + "-help-" + str(index), contents, tool_paths)
                warning = bool(re.search(rb"(?i)-Preview\b|-LoudnessMode\s+['\"]?Accurate\b", code))
                case = check_case(host, env, package_help, code, args.output / (shell + "-help-example-" + str(index)),
                                  fixture_help, hash_help, contents, tool_hashes, expected["version"],
                                  expected_exits=(0, 7) if warning else (0,), allow_warning=warning,
                                  expect_reports=0 if re.search(rb"(?i)-SaveSettings\b", code) else 1,
                                  preserve_existing=True)
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
