#!/usr/bin/env python3
"""Development-only local package inspection and synthetic Windows launch checks.

Python/Git belong to this controller, never to the packaged application. Raw
reports/audio/logs remain in a new ignored directory; summary.json is a fixed
projection. Eight unmodified entry-point cases observe normal host startup.
Four separate bootstrap cases constrain module lookup after host startup.
"""
from __future__ import annotations

import argparse
import array
import base64
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import struct
import subprocess
import sys
import time
import uuid
import wave
import zipfile

REPO = Path(__file__).resolve().parents[1]
SHA = re.compile(r"[0-9a-f]{40}\Z")
VERSION = re.compile(r"[0-9]+\.[0-9]+(?:\.[0-9]+){0,2}\Z")
PAYLOAD = tuple(sorted((
    "WinAudioClean.ps1", "WinAudioClean.Batch.ps1", "WinAudioClean.IO.ps1",
    "WinAudioClean.Launcher.ps1", "WinAudioClean.Output.ps1", "WinAudioClean.Preview.ps1",
    "WinAudioClean.Queue.ps1", "WinAudioClean.Settings.ps1", "WinAudioClean.bat",
    "WinAudioClean.ico", "LICENSE", "README.md", "docs/PORTABLE_PACKAGE.md",
    "THIRD_PARTY_NOTICES.md", "docs/codex/winaudioclean/DATA_FORMATS.md",
)))
ENTRIES = tuple(sorted(PAYLOAD + ("PACKAGE-MANIFEST.json",)))
FRAMES = 8 * 48000
DEADLINE = 90


class CheckError(Exception):
    """Only fixed codes from this module reach public summaries."""


def require(condition, code):
    if not condition:
        raise CheckError(code)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate_json_field")
        result[key] = value
    return result


def read_json(data):
    try:
        return json.loads(data.decode("utf-8-sig"), object_pairs_hook=no_duplicates,
                          parse_constant=lambda value: (_ for _ in ()).throw(CheckError("nonfinite_json")))
    except (ValueError, UnicodeError) as exc:
        raise CheckError("invalid_json") from exc


def git(*arguments):
    try:
        result = subprocess.run(["git", "--no-optional-locks", "-c", "core.fsmonitor=false", *arguments],
                                cwd=REPO, capture_output=True, timeout=30, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise CheckError("git_unavailable") from exc
    require(result.returncode == 0, "git_read_failed")
    return result.stdout


def source_version(main):
    text = main.decode("utf-8-sig")
    # This repository's authoritative assignment is a standalone literal. Fail
    # closed if that convention changes rather than evaluate packaged source.
    assignments = re.findall(r"(?im)^\s*\$scriptVersion\s*([^\r\n]*)", text)
    require(len(assignments) == 1, "ambiguous_source_version")
    match = re.fullmatch(r"=\s*(['\"])([0-9.]+)\1\s*", assignments[0])
    require(match is not None and VERSION.fullmatch(match[2]) and len(match[2]) <= 32,
            "invalid_source_version")
    return match[2]


def manifest_bytes(manifest, zip_hash=None):
    lines = ["{", '  "schema_version": 1,', '  "application": "WinAudioClean",',
             f'  "version": "{manifest["version"]}",',
             f'  "source_commit": "{manifest["source_commit"]}",',
             f'  "source_tree": "{manifest["source_tree"]}",', '  "payload": [']
    for index, item in enumerate(manifest["payload"]):
        suffix = "," if index < len(PAYLOAD) - 1 else ""
        lines.append('    {"path": "%s", "bytes": %d, "sha256": "%s"}%s' %
                     (item["path"], item["bytes"], item["sha256"], suffix))
    lines.append("  ]" + ("," if zip_hash else ""))
    if zip_hash:
        lines.append(f'  "zip_sha256": "{zip_hash}"')
    return ("\n".join(lines + ["}"]) + "\n").encode("ascii")


def expected_source(commit):
    require(SHA.fullmatch(commit) is not None, "invalid_commit")
    require(git("rev-parse", "--verify", commit + "^{commit}").strip().decode("ascii") == commit,
            "unexpected_commit")
    tree = git("rev-parse", "--verify", commit + "^{tree}").strip().decode("ascii")
    require(SHA.fullmatch(tree) is not None, "invalid_tree")
    blobs = {}
    for path in PAYLOAD:
        entry = git("ls-tree", "-z", commit, "--", path)
        require(re.fullmatch(rb"100(?:644|755) blob [0-9a-f]{40}\t" +
                             re.escape(path.encode("ascii")) + b"\x00", entry), "nonordinary_git_payload")
        blobs[path] = git("show", commit + ":" + path)
    manifest = {"schema_version": 1, "application": "WinAudioClean",
                "version": source_version(blobs["WinAudioClean.ps1"]),
                "source_commit": commit, "source_tree": tree,
                "payload": [{"path": path, "bytes": len(blobs[path]), "sha256": digest(blobs[path])}
                            for path in PAYLOAD]}
    return manifest, blobs


def inspect_zip_layout(data, entries):
    """Require one contiguous local-entry stream and one ordinary central directory."""
    require(len(data) >= 22 and data[-22:-18] == b"PK\x05\x06", "zip_end_record")
    disk, start_disk, on_disk, count, central_size, central_start, comment_size = struct.unpack_from("<4H2IH", data, len(data) - 18)
    require((disk, start_disk, on_disk, count, comment_size) == (0, 0, len(ENTRIES), len(ENTRIES), 0) and
            central_start + central_size == len(data) - 22, "zip_directory_layout")
    position = 0
    for item in entries:
        require(item.header_offset == position and data[position:position + 4] == b"PK\x03\x04", "zip_local_entry_order")
        require(position + 30 <= central_start, "zip_local_header")
        _, flags, method, stamp_time, stamp_date, crc, packed, unpacked, name_size, extra_size = struct.unpack_from("<5H3I2H", data, position + 4)
        require(flags == item.flag_bits and not (flags & ~0x808) and method == 0 and
                stamp_time == 0 and stamp_date == 33 and extra_size == 0, "zip_local_metadata")
        name_end = position + 30 + name_size
        require(data[position + 30:name_end] == item.filename.encode("ascii"), "zip_local_name")
        position = name_end + item.compress_size
        if flags & 8:
            require((crc, packed, unpacked) == (0, 0, 0), "zip_local_descriptor_header")
            if data[position:position + 4] == b"PK\x07\x08":
                position += 4
            require(position + 12 <= central_start and struct.unpack_from("<3I", data, position) ==
                    (item.CRC, item.compress_size, item.file_size), "zip_data_descriptor")
            position += 12
        else:
            require((crc, packed, unpacked) == (item.CRC, item.compress_size, item.file_size), "zip_local_sizes")
        require(position <= central_start, "zip_local_bounds")
    require(position == central_start, "zip_hidden_local_data")
    for item in entries:
        require(position + 46 <= len(data) - 22 and data[position:position + 4] == b"PK\x01\x02", "zip_central_entry")
        name_size, extra_size, comment_size, start_disk = struct.unpack_from("<4H", data, position + 28)
        require(extra_size == 0 and comment_size == 0 and start_disk == 0 and
                data[position + 46:position + 46 + name_size] == item.filename.encode("ascii"), "zip_central_metadata")
        position += 46 + name_size
    require(position == len(data) - 22, "zip_hidden_central_data")


def inspect_archive(zip_path, expected, blobs):
    """Read-only: reject every entry before creating any extracted files."""
    base = "WinAudioClean-%s-%s-tool-only" % (expected["version"], expected["source_commit"][:12])
    require(zip_path.name == base + ".zip", "unexpected_zip_name")
    zip_hash = file_digest(zip_path)
    checksum = zip_path.with_suffix(".sha256")
    provenance = zip_path.with_suffix(".provenance.json")
    ordinary_path(checksum, file=True)
    ordinary_path(provenance, file=True)
    require(checksum.read_bytes() == (zip_hash + "  " + zip_path.name + "\n").encode("ascii"),
            "checksum_mismatch")
    expected_provenance = dict(expected, zip_sha256=zip_hash)
    provenance_data = provenance.read_bytes()
    require(read_json(provenance_data) == expected_provenance and
            provenance_data == manifest_bytes(expected, zip_hash), "provenance_mismatch")
    contents = {}
    with zipfile.ZipFile(zip_path) as archive:
        require(archive.comment == b"", "zip_archive_comment")
        entries = archive.infolist()
        require(tuple(item.filename for item in entries) == ENTRIES, "zip_entry_allowlist_or_order")
        require(len({item.filename.casefold() for item in entries}) == len(ENTRIES), "duplicate_zip_entry")
        inspect_zip_layout(zip_path.read_bytes(), entries)
        for item in entries:
            require(item.orig_filename == item.filename and not item.is_dir() and
                    "\\" not in item.filename and not item.filename.startswith("/") and
                    all(part not in {"", ".", ".."} for part in item.filename.split("/")), "unsafe_zip_path")
            require(item.date_time == (1980, 1, 1, 0, 0, 0), "zip_timestamp")
            require(item.compress_type == zipfile.ZIP_STORED and item.compress_size == item.file_size,
                    "zip_compression")
            require(item.external_attr == 0 and not stat.S_ISLNK(item.external_attr >> 16), "zip_attributes")
            require(not (item.flag_bits & 1) and not item.extra and not item.comment, "zip_entry_metadata")
            wanted = manifest_bytes(expected) if item.filename == "PACKAGE-MANIFEST.json" else blobs[item.filename]
            require(item.file_size == len(wanted), "zip_blob_size")
            actual = archive.read(item)
            require(actual == wanted, "zip_blob_mismatch")
            contents[item.filename] = actual
    manifest_data = contents["PACKAGE-MANIFEST.json"]
    require(read_json(manifest_data) == expected, "manifest_mismatch")
    return contents, {"passed": True, "payload_count": len(PAYLOAD), "entry_count": len(ENTRIES),
                      "zip_sha256": zip_hash, "manifest_sha256": digest(manifest_data),
                      "license_sha256": digest(blobs["LICENSE"]), "version": expected["version"],
                      "source_commit": expected["source_commit"], "source_tree": expected["source_tree"],
                      "ordered_stored_fixed_timestamp": True, "committed_blobs_identical": True}


def ordinary_path(path, *, file=False, missing=False):
    require(path.is_absolute(), "absolute_path_required")
    current = path
    first = True
    while True:
        try:
            info = current.lstat()
        except FileNotFoundError:
            require(missing, "missing_path")
        else:
            require(not stat.S_ISLNK(info.st_mode) and not
                    (getattr(info, "st_file_attributes", 0) & 0x400), "reparse_path")
            require(stat.S_ISREG(info.st_mode) if first and file else stat.S_ISDIR(info.st_mode),
                    "nonordinary_path")
        if current.parent == current:
            break
        current = current.parent
        first = False


def new_output(path):
    ordinary_path(path, missing=True)
    require(not path.exists(), "output_exists")
    try:
        relative = path.relative_to(REPO).as_posix()
    except ValueError as exc:
        raise CheckError("output_must_be_ignored_in_controller_repo") from exc
    git("check-ignore", "--quiet", "--no-index", "--", relative + "/summary.json")
    path.mkdir(parents=True, exist_ok=False)
    ordinary_path(path)


def write_json_new(path, value):
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=True, indent=2, allow_nan=False)
        stream.write("\n")


def package_unchanged(package, contents):
    root_info = package.lstat()
    if (not stat.S_ISDIR(root_info.st_mode) or stat.S_ISLNK(root_info.st_mode) or
            getattr(root_info, "st_file_attributes", 0) & 0x400):
        return False
    expected_directories = {str(parent).replace("\\", "/") for name in contents
                            for parent in Path(name).parents if str(parent) != "."}
    files = set()
    directories = set()
    pending = [package]
    while pending:
        for path in pending.pop().iterdir():
            name = path.relative_to(package).as_posix()
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
                return False
            if stat.S_ISDIR(info.st_mode):
                if name not in expected_directories:
                    return False
                directories.add(name)
                pending.append(path)
            elif stat.S_ISREG(info.st_mode) and name in contents and path.read_bytes() == contents[name]:
                files.add(name)
            else:
                return False
    return files == set(contents) and directories == expected_directories


def encoded(code):
    return base64.b64encode(code.encode("utf-16-le")).decode("ascii")


def run_child(command, cwd, env, prefix):
    started = time.monotonic()
    timed_out = False
    cleanup_ok = True
    with prefix.with_suffix(".stdout.log").open("xb") as stdout, prefix.with_suffix(".stderr.log").open("xb") as stderr:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                   stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            process.wait(timeout=DEADLINE)
        except subprocess.TimeoutExpired:
            timed_out = True
            # The only cleanup target is this still-owned live child PID tree.
            if process.poll() is None:
                try:
                    killed = subprocess.run([str(Path(env["SystemRoot"]) / "System32" / "taskkill.exe"),
                                             "/PID", str(process.pid), "/T", "/F"],
                                            stdin=subprocess.DEVNULL, stdout=stderr, stderr=stderr,
                                            timeout=10, creationflags=subprocess.CREATE_NO_WINDOW)
                    cleanup_ok = killed.returncode == 0
                    process.wait(timeout=10)
                except (OSError, subprocess.TimeoutExpired):
                    cleanup_ok = False
            require(process.poll() is not None, "owned_child_cleanup_incomplete")
    return {"exit_code": process.returncode, "timed_out": timed_out,
            "direct_child_exited": True, "timeout_owned_tree_cleanup_complete": cleanup_ok if timed_out else None,
            "elapsed_seconds": round(time.monotonic() - started, 3),
            "stdout_sha256": file_digest(prefix.with_suffix(".stdout.log")),
            "stderr_sha256": file_digest(prefix.with_suffix(".stderr.log"))}


def child_environment(system_root, tool_bin, module_roots):
    env = {key: value for key, value in os.environ.items() if not
           (key.upper().startswith(("WAC_", "GIT_", "GITHUB_", "GH_", "PYTHON", "VIRTUAL_ENV")) or
            key.upper() in {"PATH", "PSMODULEPATH", "PSMODULEANALYSISCACHEPATH"})}
    env["SystemRoot"] = str(system_root)
    env["PATH"] = os.pathsep.join(str(path) for path in
                                (system_root / "System32", system_root, system_root / "System32" / "Wbem", tool_bin))
    env["PSModulePath"] = os.pathsep.join(map(str, module_roots))
    return env


PREFLIGHT = r"""
$ErrorActionPreference='Stop'
$paths=@($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ })
$testModules=@(Get-Module -ListAvailable -Name Pester,PSScriptAnalyzer | ForEach-Object { @{name=$_.Name;version=$_.Version.ToString()} })
[ordered]@{version=$PSVersionTable.PSVersion.ToString();module_paths=$paths;
 python_available=[bool](Get-Command python -CommandType Application -ErrorAction SilentlyContinue);
 git_available=[bool](Get-Command git -CommandType Application -ErrorAction SilentlyContinue);
 test_modules=$testModules} | ConvertTo-Json -Compress -Depth 4
"""


def preflight(host, env, root, label, module_roots, *, builtin_only=False):
    code = PREFLIGHT
    if builtin_only:
        code = "$env:PSModulePath=$env:WAC_CHECK_MODULE_ROOTS\n" + code
    record = run_child([str(host), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
                        "-EncodedCommand", encoded(code)], root, env, root / label)
    require(record["exit_code"] == 0 and not record["timed_out"], "preflight_failed")
    observed = read_json((root / label).with_suffix(".stdout.log").read_bytes())
    require(observed["python_available"] is False and observed["git_available"] is False, "development_tool_visible")
    require(isinstance(observed["version"], str) and len(observed["version"]) <= 32 and
            VERSION.fullmatch(observed["version"]) is not None, "unexpected_shell_version")
    allowed = {os.path.normcase(os.path.normpath(str(path))) for path in module_roots}
    module_paths = observed["module_paths"]
    extra = [path for path in module_paths if os.path.normcase(os.path.normpath(path)) not in allowed]
    if builtin_only:
        require(not extra, "bootstrap_module_scope")
    test_modules = observed["test_modules"]
    require(all(item["name"] in {"Pester", "PSScriptAnalyzer"} and isinstance(item["version"], str) and
                len(item["version"]) <= 32 and VERSION.fullmatch(item["version"])
                for item in test_modules), "unexpected_module_identity")
    test_modules = [{"name": item["name"], "version": item["version"]} for item in test_modules]
    return {"shell_version": observed["version"], "python_available": False, "git_available": False,
            "builtin_module_roots_only": not extra, "startup_added_module_root_count": len(extra),
            "visible_test_modules": test_modules, "scope": "builtin_only_bootstrap" if builtin_only else "normal_host_startup"}, observed


def generate_tone(path):
    samples = array.array("h")
    for frame in range(FRAMES):
        samples.extend(round(5000 * math.sin(2 * math.pi * frequency * frame / 48000)) for frequency in (440, 880))
    if sys.byteorder != "little":
        samples.byteswap()
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(48000)
        output.writeframes(samples.tobytes())


def inspect_wave(path):
    data = path.read_bytes()
    require(len(data) >= 44 and data[:4] == b"RIFF" and data[8:12] == b"WAVE" and
            struct.unpack_from("<I", data, 4)[0] + 8 == len(data), "wave_container")
    chunks = {}
    position = 12
    while position + 8 <= len(data):
        name, size = struct.unpack_from("<4sI", data, position)
        end = position + 8 + size
        require(end <= len(data), "wave_truncated_chunk")
        require(name not in chunks or name not in {b"fmt ", b"data"}, "wave_duplicate_chunk")
        chunks[name] = data[position + 8:end]
        position = end + (size & 1)
    require(position == len(data) and b"fmt " in chunks and b"data" in chunks, "wave_chunks")
    fmt = chunks[b"fmt "]
    require(len(fmt) >= 16, "wave_format")
    kind, channels, rate, byte_rate, alignment, bits = struct.unpack_from("<HHIIHH", fmt)
    pcm = kind == 1
    if kind == 65534:
        pcm = len(fmt) >= 40 and fmt[24:40] == bytes.fromhex("0100000000001000800000aa00389b71") and struct.unpack_from("<H", fmt, 18)[0] == 16
    require(pcm and (channels, rate, byte_rate, alignment, bits) == (2, 48000, 192000, 4, 16), "wave_pcm_policy")
    require(len(chunks[b"data"]) == FRAMES * alignment, "wave_duration")
    return {"container": "RIFF", "codec": "pcm_s16le", "channels": channels,
            "sample_rate": rate, "bits": bits, "frames": FRAMES, "duration_seconds": 8.0,
            "sha256": digest(data)}


def inspect_report(directory, version, mode, tone, expected_tools):
    reports = list(directory.glob("WinAudioClean_*.json"))
    outputs = list(directory.glob("*.wav"))
    require(len(reports) == 1 and len(outputs) == 1, "output_inventory")
    raw = reports[0].read_bytes()
    report = read_json(raw)
    require(report.get("schemaVersion") == 1 and report.get("status") == "SUCCESS" and
            report.get("processingStatus") == "SUCCESS" and report.get("applicationExitCode") == 0 and
            report.get("processingExitCode") == 0 and report.get("nativeExitCode") == 0, "report_outcome")
    require(report.get("toolVersion") == version and report.get("sourceRevision") is None and
            report.get("sourceRevisionReason") == "not_embedded", "report_version")
    require(report.get("reasonCodes") == [] and report.get("warningCodes") == [] and
            report.get("reporting") == {"complete": True, "errors": []}, "report_failures")
    require(report["input"]["path"] == str(tone) and report["input"]["durationSeconds"] == 8.0 and
            report["output"]["path"] == str(outputs[0]) and report["output"]["published"] is True and
            report["output"]["validity"] == "PASSED", "report_publication")
    require(report["settings"]["mode"] == mode and report["settings"]["loudnessMode"] == "Fast" and
            report["output"]["format"] == {"sampleRate": 48000, "bitDepth": 16, "codec": "pcm_s16le",
                                          "channels": 2, "channelLayout": "stereo", "container": "RIFF"}, "report_output_policy")
    diagnostics = report["diagnostics"]
    require(all(not diagnostics.get(key) for key in ("processError", "nativeCleanupError", "outputError", "outputCleanupErrors")), "report_native_failure")
    for name, path in expected_tools.items():
        dependency = report["dependencies"][name]
        require(os.path.normcase(dependency["path"]) == os.path.normcase(str(path)) and
                re.match(r"(?:ffmpeg|ffprobe) version 9\.0\.2(?:[-\s]|$)", dependency["version"]), "report_tool_identity")
    text = reports[0].with_suffix(".txt")
    summary = directory / "WinAudioClean_Log.txt"
    require(text.is_file() and summary.is_file() and text.read_bytes().strip() in summary.read_bytes(), "text_report_missing")
    return {"schema_version": 1, "status": "SUCCESS", "processing_status": "SUCCESS",
            "application_exit_code": 0, "native_exit_code": 0, "tool_version": version,
            "source_revision": None, "source_revision_reason": "not_embedded", "published": True,
            "failure_count": 0, "warning_count": 0, "json_sha256": digest(raw),
            "text_sha256": file_digest(text)}, inspect_wave(outputs[0])


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", required=True, type=Path, dest="zip_path")
    parser.add_argument("--expected-commit", required=True)
    for name in ("ffmpeg", "ffprobe", "ps51", "ps7", "output"):
        parser.add_argument("--" + name, required=True, type=Path)
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    summary = {"schema_version": 1, "task": "WAC-M4-03", "passed": False,
               "scope": "synthetic_local_portable_package", "error_code": None,
               "real_route_case_count": 0, "builtin_bootstrap_case_count": 0, "cases": []}
    output_created = False
    try:
        require(os.name == "nt", "windows_required")
        require(SHA.fullmatch(args.expected_commit), "invalid_commit")
        for path in (args.zip_path, args.ffmpeg, args.ffprobe, args.ps51, args.ps7):
            ordinary_path(path, file=True)
        require(args.ffmpeg.name.casefold() == "ffmpeg.exe" and args.ffprobe.name.casefold() == "ffprobe.exe" and
                args.ffmpeg.parent == args.ffprobe.parent, "approved_tool_pair_required")
        system_root = Path(os.environ["SystemRoot"])
        fixed_ps51 = system_root / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
        require(os.path.normcase(str(args.ps51)) == os.path.normcase(str(fixed_ps51)), "bat_outer_host_mismatch")
        before = (git("rev-parse", "HEAD").strip(), git("status", "--porcelain=v1", "--untracked-files=all", "-z"))
        require(before == (args.expected_commit.encode("ascii"), b""), "clean_exact_head_required")
        expected, blobs = expected_source(args.expected_commit)
        contents, summary["archive"] = inspect_archive(args.zip_path, expected, blobs)
        new_output(args.output)
        output_created = True
        package = args.output / ("Portable package äö " + uuid.uuid4().hex)
        package.mkdir()
        for name, data in contents.items():
            target = package.joinpath(*name.split("/"))
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as stream:
                stream.write(data)
            require(target.read_bytes() == data, "extraction_byte_mismatch")
        tone = args.output / "synthetic stereo äö.wav"
        generate_tone(tone)
        input_hash = file_digest(tone)
        summary["input"] = dict(inspect_wave(tone), unchanged=True, synthetic=True)
        module_roots = [fixed_ps51.parent / "Modules", args.ps7.parent / "Modules"]
        for root in module_roots:
            ordinary_path(root)
        env = child_environment(system_root, args.ffmpeg.parent, module_roots)
        env["WAC_CHECK_MODULE_ROOTS"] = os.pathsep.join(map(str, module_roots))
        env["PSModuleAnalysisCachePath"] = str(args.output / "module-analysis.cache")
        summary["tools"] = {}
        for name, path in (("ffmpeg", args.ffmpeg), ("ffprobe", args.ffprobe)):
            result = run_child([str(path), "-version"], package, env, args.output / (name + "-version"))
            lines = (args.output / (name + "-version.stdout.log")).read_bytes().decode("utf-8", "replace").splitlines()
            line = lines[0] if lines else ""
            require(result["exit_code"] == 0 and not result["timed_out"] and
                    re.match(name + r" version 9\.0\.2(?:[-\s]|$)", line), "approved_tool_version_required")
            summary["tools"][name] = {"version": "9.0.2", "sha256": file_digest(path)}
        preflights = {}
        facts51, observation51 = preflight(args.ps51, env, args.output, "preflight-ps51", module_roots)
        for shell, host in (("ps51", args.ps51), ("ps7", args.ps7)):
            preflights[("powershell_file", shell)] = facts51 if shell == "ps51" else preflight(host, env, args.output, "preflight-ps7", module_roots)[0]
            bat_env = dict(env)
            bat_env["PSModulePath"] = os.pathsep.join(observation51["module_paths"])
            preflights[("bat_unattended", shell)] = facts51 if shell == "ps51" else preflight(host, bat_env, args.output, "preflight-bat-ps7", module_roots)[0]
            preflights[("builtin_bootstrap", shell)] = preflight(host, env, args.output, "preflight-bootstrap-" + shell, module_roots, builtin_only=True)[0]
            require(preflights[("powershell_file", shell)]["shell_version"].startswith("5.1." if shell == "ps51" else "7."), "incorrect_shell_family")
        summary["preflight"] = [{"route": route, "shell": shell, **facts} for (route, shell), facts in preflights.items()]
        bootstrap = args.output / "builtin-bootstrap.ps1"
        bootstrap.write_text("$ErrorActionPreference='Stop'\n$env:PSModulePath=$env:WAC_CHECK_MODULE_ROOTS\n"
                             "& $env:WAC_CHECK_APP -inputPath $env:WAC_LAUNCH_INPUT -OutputDirectory $env:WAC_LAUNCH_OUTPUT_DIRECTORY "
                             "-Mode $env:WAC_CHECK_MODE -FfmpegPath $env:WAC_CHECK_FFMPEG -FfprobePath $env:WAC_CHECK_FFPROBE "
                             "-NonInteractive -IgnoreSavedSettings -SettingsPath $env:WAC_LAUNCH_SETTINGS_PATH\n"
                             "$code=$LASTEXITCODE\n$loaded=@(Get-Module Pester,PSScriptAnalyzer).Count\n"
                             "[IO.File]::WriteAllText($env:WAC_CHECK_MODULE_RESULT,([ordered]@{test_module_loaded_count=$loaded;"
                             "module_paths=@($env:PSModulePath -split [IO.Path]::PathSeparator)} | ConvertTo-Json -Compress))\nexit $code\n", encoding="utf-8-sig")
        for route in ("powershell_file", "bat_unattended", "builtin_bootstrap"):
            for shell, host in (("ps51", args.ps51), ("ps7", args.ps7)):
                for mode in ("Raw", "Zoom"):
                    identifier = route + "-" + shell + "-" + mode.lower()
                    destination = args.output / identifier
                    destination.mkdir()
                    settings = destination / "absent-settings.json"
                    case_env = dict(env, WAC_LAUNCH_INPUT=str(tone), WAC_LAUNCH_OUTPUT_DIRECTORY=str(destination),
                                    WAC_LAUNCH_IGNORE_SAVED_SETTINGS="1", WAC_LAUNCH_SETTINGS_PATH=str(settings),
                                    WAC_LAUNCH_POWERSHELL=str(host))
                    app = package / "WinAudioClean.ps1"
                    if route == "bat_unattended":
                        # CMD text contains only a literal relative BAT name and fixed control tokens.
                        command = [str(system_root / "System32" / "cmd.exe"), "/d", "/c", "WinAudioClean.bat /unattended " + mode]
                    elif route == "powershell_file":
                        command = [str(host), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(app),
                                   "-inputPath", str(tone), "-OutputDirectory", str(destination), "-Mode", mode,
                                   "-FfmpegPath", str(args.ffmpeg), "-FfprobePath", str(args.ffprobe), "-NonInteractive",
                                   "-IgnoreSavedSettings", "-SettingsPath", str(settings)]
                    else:
                        case_env.update(WAC_CHECK_APP=str(app), WAC_CHECK_MODE=mode, WAC_CHECK_FFMPEG=str(args.ffmpeg),
                                        WAC_CHECK_FFPROBE=str(args.ffprobe), WAC_CHECK_MODULE_RESULT=str(destination / "modules-private.json"))
                        command = [str(host), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(bootstrap)]
                    case = {"id": identifier, "route": route, "shell": shell, "mode": mode, "passed": False,
                            "module_scope": preflights[(route, shell)], "error_code": None}
                    summary["cases"].append(case)
                    try:
                        case.update(run_child(command, package, case_env, args.output / identifier))
                        require(case["exit_code"] == 0 and not case["timed_out"], "application_exit_or_timeout")
                        case["report"], case["output"] = inspect_report(destination, expected["version"], mode, tone,
                                                                        {"ffmpeg": args.ffmpeg, "ffprobe": args.ffprobe})
                        require(not settings.exists(), "settings_created")
                        require(file_digest(tone) == input_hash, "input_changed")
                        require(package_unchanged(package, contents), "package_changed")
                        case["input_unchanged"] = True
                        case["package_unchanged"] = True
                        if route == "builtin_bootstrap":
                            modules = read_json((destination / "modules-private.json").read_bytes())
                            require(modules["test_module_loaded_count"] == 0 and
                                    {os.path.normcase(path) for path in modules["module_paths"]} ==
                                    {os.path.normcase(str(path)) for path in module_roots}, "bootstrap_runtime_modules")
                            case["test_module_loaded_count"] = 0
                        case["passed"] = True
                    except CheckError as exc:
                        case["error_code"] = str(exc)
                        if str(exc) == "owned_child_cleanup_incomplete":
                            raise
                    except (OSError, ValueError, KeyError, TypeError) as exc:
                        (destination / "controller-private-error.txt").write_text(repr(exc), encoding="utf-8")
                        case["error_code"] = "case_inspection_failed"
                    finally:
                        case["input_unchanged"] = file_digest(tone) == input_hash
                        case["package_unchanged"] = package_unchanged(package, contents)
                        if not case["input_unchanged"] or not case["package_unchanged"]:
                            case["passed"] = False
                            raise CheckError("fixture_or_package_changed")
        summary["real_route_case_count"] = sum(case["passed"] for case in summary["cases"] if case["route"] != "builtin_bootstrap")
        summary["builtin_bootstrap_case_count"] = sum(case["passed"] for case in summary["cases"] if case["route"] == "builtin_bootstrap")
        after = (git("rev-parse", "HEAD").strip(), git("status", "--porcelain=v1", "--untracked-files=all", "-z"))
        summary["controller_source_unchanged"] = after == before
        summary["input"]["unchanged"] = file_digest(tone) == input_hash
        summary["approved_tools_unchanged"] = all(file_digest(path) == summary["tools"][name]["sha256"]
                                                    for name, path in (("ffmpeg", args.ffmpeg), ("ffprobe", args.ffprobe)))
        summary["passed"] = all(case["passed"] for case in summary["cases"]) and len(summary["cases"]) == 12 and after == before and summary["input"]["unchanged"]
        summary["passed"] = summary["passed"] and summary["approved_tools_unchanged"]
    except CheckError as exc:
        summary["error_code"] = str(exc)
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as exc:
        if output_created:
            (args.output / "controller-private-error.txt").write_text(repr(exc), encoding="utf-8")
        summary["error_code"] = "controller_inspection_failed"
    if output_created:
        write_json_new(args.output / "summary.json", summary)
    print(json.dumps(summary, ensure_ascii=True, indent=2, allow_nan=False))
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
