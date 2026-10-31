#!/usr/bin/env python3
"""Development-only negative dependency checks against the extracted ZIP bytes."""
from __future__ import annotations

import base64
import json
import os
from pathlib import Path
import re
import shutil


def _encoded(text):
    return base64.b64encode(text.encode("utf-16le")).decode("ascii")


def run_failures(checks, run, clean_environment, *, package, root, unrelated,
                 tone, tools, ps51, ps7):
    """Exercise fail-closed explicit selections on both supported PowerShell hosts.

    Paths remain native arguments/environment data. No package file or persisted
    environment value is changed. The incapable/wrong-identity native executable
    is the project's established synthetic inspection fixture, not an audio tool.
    """
    system = Path(os.environ["SystemRoot"])
    fixture = root / "Failure inspection fixture" / "ffmpeg.exe"
    env = clean_environment(system, ps51)
    env.update(WAC_TEST_FIXTURE_HELPER=str(Path(__file__).resolve().parents[1]
               / "tests/fixtures/New-NativeProcessFixture.ps1"),
               WAC_TEST_FIXTURE_OUTPUT=str(fixture))
    code = ("$ErrorActionPreference='Stop'; . $env:WAC_TEST_FIXTURE_HELPER; "
            "$null=New-WacTestNativeExecutable -OutputPath $env:WAC_TEST_FIXTURE_OUTPUT")
    status, _, _ = run([str(ps51), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
                        "-EncodedCommand", _encoded(code)], unrelated, env,
                       root / "compile-failure-fixture", timeout=45)
    checks.require(status == 0 and fixture.is_file(), "failure_fixture_compile_failed")
    broken = root / "Found but inoperable.exe"
    broken.write_bytes(b"This is intentionally not a Windows executable.\r\n")
    missing = root / "Absent executable.exe"
    results = []

    for family, shell in (("ps51", ps51), ("ps7", ps7)):
        cases = (
            ("missing-ffmpeg", missing, tools["ffprobe"], {}, r"Cannot access ffmpeg"),
            ("missing-ffprobe", tools["ffmpeg"], missing, {}, r"Cannot access ffprobe"),
            ("inoperable-ffmpeg", broken, tools["ffprobe"], {}, r"found.*could not execute"),
            ("wrong-identity", fixture, tools["ffprobe"],
             {"WAC_TEST_VERSION_STDOUT": "unrelated program version fixture\n"}, r"Incompatible ffmpeg"),
            ("incapable-ffmpeg", fixture, tools["ffprobe"],
             {"WAC_TEST_FILTERS_STDOUT": " ... loudnorm A->A Fixture loudness\n"},
             r"lacks filters required.*dynaudnorm"),
        )
        for label, ffmpeg, ffprobe, controls, reason in cases:
            label = "failure-" + family + "-" + label
            destination = root / label
            destination.mkdir()
            env = clean_environment(system, shell)
            env.update(controls)
            marker = root / (label + "-argv.json")
            if ffmpeg == fixture:
                phase = "FILTERS" if controls.get("WAC_TEST_FILTERS_STDOUT") else "VERSION"
                env["WAC_TEST_" + phase + "_ARGV_PATH"] = str(marker)
            command = [str(shell), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                       str(package / "WinAudioClean.ps1"), "-inputPath", str(tone), "-Mode", "Zoom",
                       "-OutputDirectory", str(destination), "-FfmpegPath", str(ffmpeg),
                       "-FfprobePath", str(ffprobe), "-IgnoreSavedSettings", "-NonInteractive"]
            status, stdout, stderr = run(command, unrelated, env, root / label, timeout=60)
            _assert_failure(checks, status, stdout, stderr, destination, reason, label)
            if ffmpeg == fixture:
                checks.require(marker.is_file(), "expected_fixture_not_executed_" + label)
                arguments = json.loads(marker.read_text(encoding="utf-8-sig"))
                expected_argument = "-filters" if controls.get("WAC_TEST_FILTERS_STDOUT") else "-version"
                checks.require(expected_argument in arguments, "wrong_fixture_operation_" + label)
            results.append({"label": label, "shell": family, "expected_exit": 3,
                            "actual_exit": status, "reason_verified": True,
                            "no_completed_output": True})
    return results


def run_absence_failures(checks, run, clean_environment, *, package, root,
                         unrelated, tone, tools, ps51, ps7):
    """Test actual packaged helpers with test-process-only environment sources.

    Genuine machine Path may legitimately identify a runner-installed FFmpeg.
    Simulating that read is necessary to establish complete absence without
    changing the machine. These cases deliberately report that they exercise
    the packaged shared resolver rather than the BAT launcher front door.
    """
    system = Path(os.environ["SystemRoot"])
    ffmpeg_only = root / "Missing probe fixture"
    ffmpeg_only.mkdir()
    shutil.copyfile(tools["ffmpeg"], ffmpeg_only / "ffmpeg.exe")
    results = []
    code = r"""
$ErrorActionPreference = 'Stop'
. $env:WAC_TEST_PACKAGE_SCRIPT
# Both overrides live only in this disposable test child. Package bytes and
# persisted environment values remain intact; machine reads are simulated.
function Get-WacEnvironmentValue { param([string]$Name, [string]$Scope) return $null }
function Get-Command { param([string]$Name, [string]$CommandType) return $null }
try {
    $sibling = $env:WAC_TEST_PACKAGE_DIRECTORY
    if ($env:WAC_TEST_TOOL -eq 'ffprobe.exe') {
        $selected = Resolve-WacExecutable -Name ffmpeg.exe -ExplicitPath $env:WAC_TEST_FFMPEG_ONLY -SiblingDirectory $sibling
        $sibling = [IO.Path]::GetDirectoryName($selected)
    }
    $null = Resolve-WacExecutable -Name $env:WAC_TEST_TOOL -SiblingDirectory $sibling
    throw 'Unexpected executable selection in controlled-absence fixture.'
} catch {
    if ($_.Exception.Message -notlike ($env:WAC_TEST_TOOL + ' not found*')) { throw }
    Write-WacDependencyFailure -Reason $_.Exception.Message
    exit 3
}
"""
    for family, shell in (("ps51", ps51), ("ps7", ps7)):
        for scenario, tool, reason in (
            ("controlled-complete-absence", "ffmpeg.exe", r"ffmpeg\.exe not found"),
            ("controlled-absent-probe", "ffprobe.exe", r"ffprobe\.exe not found"),
        ):
            label = "failure-" + family + "-" + scenario
            destination = root / label
            destination.mkdir()
            env = clean_environment(system, shell)
            env.update(WAC_TEST_PACKAGE_SCRIPT=str(package / "WinAudioClean.ps1"),
                       WAC_TEST_PACKAGE_DIRECTORY=str(package), WAC_TEST_TOOL=tool,
                       WAC_TEST_FFMPEG_ONLY=str(ffmpeg_only / "ffmpeg.exe"))
            command = [str(shell), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
                       "-EncodedCommand", _encoded(code)]
            status, stdout, stderr = run(command, unrelated, env, root / label, timeout=60)
            _assert_failure(checks, status, stdout, stderr, destination, reason, label)
            results.append({"label": label, "shell": family, "expected_exit": 3,
                            "actual_exit": status, "reason_verified": True,
                            "no_completed_output": True, "packaged_shared_resolver": True,
                            "controlled_environment_sources": True, "launcher_exercised": False})
    return results


def _assert_failure(checks, status, stdout, stderr, destination, reason, label):
    checks.require(status == 3, "wrong_failure_exit_" + label)
    text = (stdout + stderr).decode("utf-8", errors="replace")
    checks.require(re.search(reason, text, re.I | re.S) is not None, "wrong_failure_reason_" + label)
    checks.require("Next step:" in text, "missing_failure_next_step_" + label)
    checks.require(not re.search(r"CategoryInfo|FullyQualifiedErrorId|\x1b|Press any key|DONE: SUCCESS", text),
                   "failure_ui_or_stack_leak_" + label)
    checks.require(not list(destination.glob("*.wav"))
                   and not list(destination.glob("WinAudioClean_*.json")),
                   "completed_looking_failed_output_" + label)
