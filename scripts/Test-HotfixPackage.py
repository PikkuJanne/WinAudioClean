#!/usr/bin/env python3
"""Windows-only, development-only checks of actual portable ZIP launch routes.

Raw local diagnostics stay below --output. The summary deliberately contains no
paths or environment values. Persisted environment writes require an ephemeral
GitHub-hosted runner and are restored even when a launcher assertion fails.
"""
from __future__ import annotations

import argparse
import base64
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("package_checks", Path(__file__).with_name("Test-ReleasePackage.py"))
checks = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checks)
require = checks.require


def encoded(text):
    return base64.b64encode(text.encode("utf-16le")).decode("ascii")


def run(command, cwd, env, log, timeout=150):
    process = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        subprocess.run([str(Path(os.environ["SystemRoot"]) / "System32/taskkill.exe"),
                        "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=15, check=False)
        stdout, stderr = process.communicate(timeout=15)
        log.with_suffix(".stdout.log").write_bytes(stdout)
        log.with_suffix(".stderr.log").write_bytes(stderr)
        raise checks.CheckError("launcher_timeout")
    log.with_suffix(".stdout.log").write_bytes(stdout)
    log.with_suffix(".stderr.log").write_bytes(stderr)
    return process.returncode, stdout, stderr


def clean_environment(system, shell):
    env = {key: value for key, value in os.environ.items()
           if not key.upper().startswith(("WAC_LAUNCH_", "GITHUB_TOKEN", "GH_TOKEN"))
           and key.upper() not in {"FFMPEG", "FFPROBE", "PATH", "PSMODULEPATH"}}
    env["PATH"] = ";".join(str(path) for path in
                            (system, system / "System32", system / "System32/WindowsPowerShell/v1.0"))
    env["WAC_LAUNCH_POWERSHELL"] = str(shell)
    return env


def inspect_result(directory, tools, source, version, mode):
    reports = list(directory.glob("WinAudioClean_*.json"))
    outputs = list(directory.glob("*.wav"))
    require(len(reports) == 1 and len(outputs) == 1, "output_inventory")
    report = checks.read_json(reports[0].read_bytes())
    require(report["status"] == "SUCCESS" and report["applicationExitCode"] == 0
            and report["output"]["published"] is True and report["output"]["validity"] == "PASSED",
            "conversion_failed")
    require(report["toolVersion"] == version and report["settings"]["mode"] == mode,
            "conversion_identity")
    require(Path(report["input"]["path"]) == source, "input_identity")
    for tool, expected in tools.items():
        require(os.path.normcase(report["dependencies"][tool]["path"]) == os.path.normcase(str(expected)),
                "wrong_selected_executable")
    probe = subprocess.run([str(tools["ffprobe"]), "-v", "error", "-select_streams", "a:0",
                            "-show_entries", "stream=codec_name,sample_rate,channels,duration,bits_per_sample",
                            "-of", "json", str(outputs[0])], capture_output=True, timeout=30, check=False)
    require(probe.returncode == 0, "independent_probe_failed")
    streams = json.loads(probe.stdout)["streams"]
    require(len(streams) == 1, "independent_stream_count")
    stream = streams[0]
    require(stream["codec_name"] == "pcm_s16le" and int(stream["sample_rate"]) == 48000
            and int(stream["bits_per_sample"]) == 16 and stream["channels"] == 2
            and abs(float(stream["duration"]) - 8.0) <= 0.01 + 1 / 48000, "independent_output_policy")
    inspected = checks.inspect_wave(outputs[0])
    return outputs[0], {"selected_pair_exact": True, "independent_probe_passed": True,
                        "sample_rate": 48000, "codec": "pcm_s16le", "channels": 2,
                        "duration_seconds": float(stream["duration"]), "wav_sha256": inspected["sha256"]}


def decoded_pcm(ffmpeg, source):
    result = subprocess.run([str(ffmpeg), "-nostdin", "-v", "error", "-i", str(source),
                             "-map", "0:a:0", "-f", "s16le", "-c:a", "pcm_s16le", "-"],
                            capture_output=True, timeout=30, check=False)
    require(result.returncode == 0 and len(result.stdout) > 0, "decode_failed")
    return checks.digest(result.stdout)


LINK_DRIVER = r"""
$ErrorActionPreference = 'Stop'
$wsh = New-Object -ComObject WScript.Shell
$link = $wsh.CreateShortcut($env:WAC_TEST_LINK)
$link.TargetPath = $env:WAC_TEST_BAT
$link.Arguments = '"' + $env:WAC_TEST_INPUT + '"'
$link.WorkingDirectory = $env:WAC_TEST_CWD
$link.Save()
# Activate the .lnk through the Windows shell, retaining a process handle.
# This tests shell-link activation, not a physical pointer gesture.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WacShortcutConsole {
    [StructLayout(LayoutKind.Sequential)] public struct KeyEvent {
        public int KeyDown; public ushort Repeat; public ushort VirtualKey;
        public ushort ScanCode; public char Character; public uint Controls;
    }
    [StructLayout(LayoutKind.Explicit, Size=20)] public struct InputRecord {
        [FieldOffset(0)] public ushort Type;
        [FieldOffset(4)] public KeyEvent Key;
    }
    [DllImport("kernel32.dll")] public static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll")] public static extern bool FreeConsole();
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr CreateFileW(string path, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    public static extern bool WriteConsoleInputW(IntPtr handle, InputRecord[] input, uint count, out uint written);
    public static bool Enter(uint pid) {
        if (!AttachConsole(pid)) return false;
        try {
            var input = new InputRecord[2];
            for (int i=0;i<2;i++) {
                input[i].Type=1; input[i].Key.KeyDown=i==0?1:0;
                input[i].Key.Repeat=1; input[i].Key.VirtualKey=13; input[i].Key.Character='\r';
            }
            // The driver inherits redirected handles. AttachConsole does not
            // replace these; open the attached console input explicitly.
            IntPtr handle=CreateFileW("CONIN$",0xc0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
            if (handle==new IntPtr(-1)) return false;
            try { uint written; return WriteConsoleInputW(handle,input,2,out written) && written==2; }
            finally { CloseHandle(handle); }
        } finally { FreeConsole(); }
    }
}
'@
[void][WacShortcutConsole]::FreeConsole()
$child = Start-Process -FilePath $env:WAC_TEST_LINK -WorkingDirectory $env:WAC_TEST_CWD -WindowStyle Hidden -PassThru
$deadline = [DateTime]::UtcNow.AddSeconds(120)
$pauseHandled = $false
try {
    while (-not $child.WaitForExit(500)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Shortcut exceeded bounded wait.' }
        # Saved mode preferences avoid a mode prompt; only the existing final
        # pause needs input. Never inject a mode before application validation.
        if (@(Get-ChildItem -LiteralPath $env:WAC_LAUNCH_OUTPUT_DIRECTORY -Filter 'WinAudioClean_*.json' -ErrorAction SilentlyContinue).Count -gt 0) {
            $pauseHandled = [WacShortcutConsole]::Enter([uint32]$child.Id) -or $pauseHandled
        }
    }
    $child.Refresh()
    if ($child.ExitCode -ne 0) { throw 'Shortcut application returned failure.' }
    [IO.File]::WriteAllText($env:WAC_TEST_LINK_RESULT, '{"shell_link_activated":true,"bounded_completion":true}')
} finally {
    if (-not $child.HasExited) {
        & ($env:SystemRoot + '\System32\taskkill.exe') /PID $child.Id /T /F | Out-Null
    }
    $child.Dispose()
}
"""


def set_user_environment(ps51, values, env, cwd, label):
    data = dict(env, WAC_TEST_ENV_JSON=json.dumps(values, ensure_ascii=True))
    code = "$v=ConvertFrom-Json $env:WAC_TEST_ENV_JSON; foreach($p in $v.PSObject.Properties){[Environment]::SetEnvironmentVariable($p.Name,$p.Value,'User')}"
    status, _, _ = run([str(ps51), "-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", encoded(code)],
                        cwd, data, cwd / label, timeout=30)
    require(status == 0, "persisted_fixture_write_failed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", required=True, type=Path, dest="zip_path")
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--ffmpeg", required=True, type=Path)
    parser.add_argument("--ffprobe", required=True, type=Path)
    parser.add_argument("--ps7", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--persisted-user", action="store_true")
    parser.add_argument("--baseline-ref", default="v1.0.0")
    args = parser.parse_args()
    summary = {"schema_version": 1, "task": "WAC-HOTFIX-101", "passed": False, "cases": [], "error_code": None}
    created = False
    try:
        require(os.name == "nt", "windows_required")
        require(not args.persisted_user or (os.environ.get("GITHUB_ACTIONS") == "true"
                and os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted"), "disposable_hosted_runner_required")
        for path in (args.zip_path, args.ffmpeg, args.ffprobe, args.ps7):
            checks.ordinary_path(path, file=True)
        expected, blobs = checks.expected_source(args.expected_commit)
        contents, summary["archive"] = checks.inspect_archive(args.zip_path, expected, blobs)
        checks.new_output(args.output)
        created = True
        package = args.output / "Tool package [portable]"
        package.mkdir()
        for name, data in contents.items():
            target = package.joinpath(*name.split("/"))
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        require(not list(package.glob("*.exe")), "portable_dependency_contamination")
        staged = args.output / "Engine [trusted] \u00e4\u00f6" / "bin"
        staged.mkdir(parents=True)
        tools = {"ffmpeg": staged / "ffmpeg.exe", "ffprobe": staged / "ffprobe.exe"}
        for name, source in (("ffmpeg", args.ffmpeg), ("ffprobe", args.ffprobe)):
            shutil.copyfile(source, tools[name])
            require(checks.file_digest(source) == checks.file_digest(tools[name]), "staged_binary_mismatch")
        tool_hashes = {name: checks.file_digest(path) for name, path in tools.items()}
        summary["tool_sha256"] = tool_hashes
        unrelated = args.output / "Unrelated working directory"
        unrelated.mkdir()
        tone = args.output / "generated stereo.wav"
        checks.generate_tone(tone)
        before = checks.file_digest(tone)
        system = Path(os.environ["SystemRoot"])
        ps51 = system / "System32/WindowsPowerShell/v1.0/powershell.exe"
        cmd = system / "System32/cmd.exe"
        pcm = {}

        def convert(label, mode, shell, *, hint=True, direct=False, shortcut=False, process_path=False):
            destination = args.output / label
            destination.mkdir()
            env = clean_environment(system, shell)
            env.update(WAC_LAUNCH_INPUT=str(tone), WAC_LAUNCH_OUTPUT_DIRECTORY=str(destination),
                       WAC_LAUNCH_SETTINGS_PATH=str(args.output / "absent-settings.json"),
                       WAC_LAUNCH_IGNORE_SAVED_SETTINGS="1")
            if hint:
                env["FFMPEG"] = str(staged)
            if process_path:
                env["PATH"] = str(staged) + ";" + env["PATH"]
            if direct:
                command = [str(shell), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                           str(package / "WinAudioClean.ps1"), "-inputPath", str(tone), "-Mode", mode,
                           "-OutputDirectory", str(destination), "-IgnoreSavedSettings", "-NonInteractive"]
            elif shortcut:
                settings = args.output / (label + "-settings.json")
                settings.write_text(json.dumps({"schemaVersion": 1, "settings": {"mode": mode}}), encoding="utf-8")
                env.pop("WAC_LAUNCH_IGNORE_SAVED_SETTINGS")
                env.pop("WAC_LAUNCH_INPUT")
                env.update(WAC_LAUNCH_SETTINGS_PATH=str(settings), WAC_TEST_LINK=str(args.output / (label + ".lnk")),
                           WAC_TEST_BAT=str(package / "WinAudioClean.bat"), WAC_TEST_INPUT=str(tone),
                           WAC_TEST_CWD=str(unrelated), WAC_TEST_LINK_RESULT=str(args.output / (label + "-link.json")))
                command = [str(ps51), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", encoded(LINK_DRIVER)]
            else:
                # /s /c receives a fixed BAT filename and fixed mode; user file
                # paths are inherited data, never interpolated shell commands.
                command = [str(cmd), "/d", "/s", "/c", '""' + str(package / "WinAudioClean.bat") + '" /unattended ' + mode + '"']
            status, stdout, stderr = run(command, unrelated, env, args.output / label)
            require(status == 0, "route_failed_" + label)
            if not shortcut:
                require(b"\x1b" not in stdout + stderr and b"Press any key" not in stdout + stderr
                        and b"SIGNAL CONTROL" not in stdout + stderr, "unattended_ui_leak")
            output, result = inspect_result(destination, tools, tone, expected["version"], mode)
            result.update(label=label, mode=mode, shell="ps51" if shell == ps51 else "ps7")
            summary["cases"].append(result)
            pcm[(label, mode)] = decoded_pcm(tools["ffmpeg"], output)
            require(checks.file_digest(tone) == before, "source_changed")
            return output

        for shell_name, shell in (("ps51", ps51), ("ps7", args.ps7)):
            for mode in ("Raw", "Zoom"):
                convert("bat-" + shell_name + "-" + mode.lower(), mode, shell)
            convert("direct-" + shell_name, "Zoom", shell, direct=True)
            convert("shortcut-" + shell_name, "Zoom", shell, shortcut=True)
        convert("process-path", "Zoom", ps51, hint=False, process_path=True)

        # Execute the previous public source with the identical staged engine
        # and sample, then compare decoded PCM rather than container metadata.
        baseline_commit = checks.git("rev-parse", args.baseline_ref + "^{commit}").decode("ascii").strip()
        baseline = args.output / "Prior public source"
        baseline.mkdir()
        for name in checks.PAYLOAD:
            target = baseline.joinpath(*name.split("/"))
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(checks.git("show", baseline_commit + ":" + name))
        for mode in ("Raw", "Zoom"):
            destination = args.output / ("baseline-" + mode.lower())
            destination.mkdir()
            command = [str(ps51), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                       str(baseline / "WinAudioClean.ps1"), "-inputPath", str(tone), "-Mode", mode,
                       "-OutputDirectory", str(destination), "-FfmpegPath", str(tools["ffmpeg"]),
                       "-FfprobePath", str(tools["ffprobe"]), "-IgnoreSavedSettings", "-NonInteractive"]
            status, _, _ = run(command, unrelated, clean_environment(system, ps51), args.output / ("baseline-" + mode.lower()))
            require(status == 0, "baseline_failed")
            outputs = list(destination.glob("*.wav"))
            require(len(outputs) == 1, "baseline_output_inventory")
            reference = decoded_pcm(tools["ffmpeg"], outputs[0])
            require(reference == pcm[("bat-ps51-" + mode.lower(), mode)]
                    == pcm[("bat-ps7-" + mode.lower(), mode)], "decoded_audio_regression")
        summary["decoded_pcm_matches_previous_public_source"] = True

        if args.persisted_user:
            env = clean_environment(system, ps51)
            code = "@{FFMPEG=[Environment]::GetEnvironmentVariable('FFMPEG','User');Path=[Environment]::GetEnvironmentVariable('Path','User')} | ConvertTo-Json -Compress"
            status, stdout, _ = run([str(ps51), "-NoProfile", "-EncodedCommand", encoded(code)], unrelated, env,
                                   args.output / "read-user-environment", timeout=30)
            require(status == 0, "persisted_fixture_read_failed")
            original = json.loads(stdout.decode("utf-8-sig"))
            try:
                set_user_environment(ps51, {"FFMPEG": str(staged), "Path": ""}, env, args.output, "set-user-hint")
                convert("persisted-user-hint", "Zoom", ps51, hint=False)
                set_user_environment(ps51, {"FFMPEG": "", "Path": ' "' + str(staged) + '\\" ;'}, env, args.output, "set-user-path")
                convert("persisted-user-path", "Zoom", ps51, hint=False)
                # FFMPEG is only persisted; expansion must not rely on a value
                # in this controller or the stale launcher environment.
                set_user_environment(ps51, {"FFMPEG": str(args.output), "Path": '"%FFMPEG%\\' + str(staged.relative_to(args.output)) + '"'}, env, args.output, "set-user-reference")
                convert("persisted-user-reference", "Zoom", ps51, hint=False)
            finally:
                set_user_environment(ps51, original, env, args.output, "restore-user-environment")
            summary["persisted_user_environment_restored"] = True
        require(checks.package_unchanged(package, contents), "package_changed")
        require(checks.file_digest(tone) == before, "source_changed")
        require(tool_hashes == {name: checks.file_digest(path) for name, path in tools.items()}, "engine_changed")
        summary["input_unchanged"] = True
        summary["shell_link_case_count"] = 2
        summary["case_count"] = len(summary["cases"])
        summary["passed"] = True
    except checks.CheckError as exc:
        summary["error_code"] = str(exc)
    except Exception as exc:
        summary["error_code"] = "controller_failure"
        if created:
            (args.output / "controller-error.log").write_text(repr(exc), encoding="utf-8")
    finally:
        if created:
            checks.write_json_new(args.output / "summary.json", summary)
    print(json.dumps(summary, ensure_ascii=True, separators=(",", ":")))
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
