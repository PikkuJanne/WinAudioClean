#!/usr/bin/env python3
"""Development-only Windows CI/local parity wrapper; Python is not an app dependency."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]
VERSION = re.compile(r"[0-9]{1,8}\.[0-9]{1,8}\.[0-9]{1,8}(?:\.[0-9]{1,8})?\Z")
SHA = re.compile(r"[0-9a-f]{40}\Z")
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
TEST_TIMEOUT = 2100
MODULE_PINS = {"Pester": "5.7.1", "PSScriptAnalyzer": "1.24.0"}


def child_environment(environ):
    """A fresh PS5.1 process must reconstruct its own module path, without CI tokens."""
    return {key: value for key, value in environ.items()
            if key.casefold() not in {"psmodulepath", "gh_token", "github_token"}}


def tree_hash(repo, files):
    """Portable LF content hash, including relative names but exporting only the digest."""
    digest = hashlib.sha256()
    for path in sorted(files, key=lambda item: item.relative_to(repo).as_posix()):
        relative_path = path.relative_to(repo)
        relative = relative_path.as_posix()
        if (path.is_symlink() or not path.is_file() or
                any(part in {"__pycache__", "evidence", ".wac-local"} for part in relative_path.parts) or
                path.suffix in {".pyc", ".pyo"}):
            continue
        contents = path.read_bytes().replace(b"\r\n", b"\n")
        digest.update(relative.encode("utf-8") + b"\0")
        digest.update(hashlib.sha256(contents).digest())
    return digest.hexdigest()


def source_state(repo, process_run, env):
    options = {"cwd": repo, "env": env, "capture_output": True, "text": True,
               "encoding": "utf-8", "errors": "replace", "timeout": 30}
    revision = process_run(["git", "rev-parse", "HEAD"], **options)
    dirty = process_run(["git", "status", "--porcelain", "-z"], **options)
    commit = revision.stdout.strip()
    if revision.returncode or dirty.returncode or not SHA.fullmatch(commit):
        raise ValueError("Source revision unavailable")
    groups = {"runtime": [path for path in repo.iterdir()
                           if path.suffix.lower() in {".ps1", ".psm1", ".psd1", ".bat"}]}
    for name, relative in (("scripts", "scripts"), ("tests", "tests"),
                           ("github", ".github"),
                           ("governance_tests", "docs/codex/winaudioclean/tests"),
                           ("governance_tools", "docs/codex/winaudioclean/tools")):
        groups[name] = list((repo / relative).rglob("*"))
    plan = repo / "docs/codex/winaudioclean"
    groups["governance_inputs"] = list(plan.glob("*.json")) + list(plan.glob("*.yaml")) + [plan / "DATA_FORMATS.md"]
    return {"commit": commit, "dirty": bool(dirty.stdout),
            "trees": {name: tree_hash(repo, paths) for name, paths in groups.items()}}


def platform_metadata(environ):
    version = platform.win32_ver()[1]
    numeric = version if re.fullmatch(r"\d+(?:\.\d+){1,3}", version) else None
    image_os = environ.get("ImageOS")
    image_version = environ.get("ImageVersion", "")
    return {"windows_version": numeric,
            "windows_build": int(numeric.split(".")[2]) if numeric and len(numeric.split(".")) > 2 else None,
            "image_os": image_os if image_os in {"win19", "win22", "win25"} else None,
            "image_version": image_version if re.fullmatch(r"\d{1,8}(?:\.\d{1,8}){1,3}", image_version) else None}


def parse_results(output, level):
    """Only the runner's fixed final summary and unittest's final success count can pass."""
    clean = ANSI.sub("", output).replace("\r\n", "\n")
    pester = re.findall(r"^" + level +
        r" passed: ([0-9]{1,9}) Pester passed, ([0-9]{1,9}) skipped, ([0-9]{1,9}) outside scope\.$", clean, re.M)
    if len(pester) != 1 or int(pester[0][0]) == 0:
        return None
    counts = dict(zip(("passed", "skipped", "outside_scope"), map(int, pester[0])))
    if level == "Full" and counts["outside_scope"] != 0:
        return None
    python = None
    if level == "Full":
        summaries = re.findall(r"^Ran ([0-9]{1,9}) tests? in [^\n]+\n\n"
                               r"OK(?: \(skipped=([0-9]{1,9})\))?\s*$", clean, re.M)
        if len(summaries) != 1 or int(summaries[0][0]) <= int(summaries[0][1] or 0):
            return None
        python = {"ran": int(summaries[0][0]), "skipped": int(summaries[0][1] or 0)}
    return {"pester": counts, "python": python}


def failure_diagnostics(repo, output, tracked_sources):
    """Project progress/counts and checked-in source locations, never diagnostic text."""
    clean = ANSI.sub("", output).replace("\r\n", "\n")
    phase = "unknown"
    markers = ((r"^Development module: ", "parser"),
               (r"^PowerShell parser passed ", "analyzer"),
               (r"^Static gate passed;", "plan"),
               (r'^\s*"valid": true,?$', "coverage"),
               (r"^Coverage traceability passed$", "pester"),
               (r"^Pester v[0-9.]", "pester"),
               (r"^Ran [0-9]{1,9} tests? in ", "governance"))
    for pattern, next_phase in markers:
        if re.search(pattern, clean, re.M):
            phase = next_phase
    for text, failed_phase in (("PowerShell parse failed:", "parser"),
                               ("PSScriptAnalyzer found ", "analyzer"),
                               ("Plan validation failed ", "plan"),
                               ("Coverage traceability validation failed ", "coverage"),
                               ("Pester failed:", "pester"),
                               ("Governance helper tests failed ", "governance")):
        if text in clean:
            phase = failed_phase
    totals = re.findall(r"^Tests Passed: ([0-9]{1,9}), Failed: ([0-9]{1,9}), "
                        r"Skipped: ([0-9]{1,9}), Inconclusive: ([0-9]{1,9}), "
                        r"NotRun: ([0-9]{1,9})$", clean, re.M)
    pester = dict(zip(("passed", "failed", "skipped", "inconclusive", "outside_scope"),
                      map(int, totals[0]))) if len(totals) == 1 else None
    if pester and phase == "unknown":
        phase = "pester"
    locations = []
    for relative in sorted(set(tracked_sources)):
        if (not re.fullmatch(r"[A-Za-z0-9_./-]+\.(?:ps1|psm1|py)", relative) or
                any(part in {"", ".", ".."} for part in relative.split("/")) or
                not (relative.startswith(("scripts/", "tests/", "docs/codex/winaudioclean/tests/",
                                          "docs/codex/winaudioclean/tools/")) or
                     re.fullmatch(r"WinAudioClean(?:\.[A-Za-z]+)?\.ps1", relative))):
            continue
        path = repo / relative
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(repo.resolve()):
            continue
        try:
            line_count = len(path.read_text(encoding="utf-8-sig", errors="replace").splitlines())
        except OSError:
            continue
        for spelling in {str(path), str(path).replace("\\", "/")}:
            pattern = (r"(?<![A-Za-z0-9_./\\])" + re.escape(spelling) +
                       r'(?::([0-9]{1,6})(?![0-9])|", line ([0-9]{1,6})(?![0-9]))')
            for match in re.finditer(pattern, clean, re.I):
                line = int(match[1] or match[2])
                if not 1 <= line <= line_count:
                    continue
                context = clean[max(0, match.start() - 1000):match.start()]
                category = "unknown"
                for pattern, value in ((r"Expected ", "assertion"), (r"timed out|TimeoutException", "timeout"),
                                       (r"error CS[0-9]{4}", "compile"), (r"ImportError|ModuleNotFoundError", "import"),
                                       (r"ParserError|SyntaxError", "parse"), (r"Traceback|Exception", "exception")):
                    if re.search(pattern, context, re.I):
                        category = value
                        break
                locations.append((match.start(), relative, line, category))
    unique = {}
    for _, relative, line, category in sorted(locations):
        unique.setdefault((relative, line), {"file": relative, "line": line, "category": category})
    return {"phase": phase, "pester": pester, "locations": list(unique.values())[:32],
            "truncated": len(unique) > 32}


def run_checks(repo, shell_path, family, level="Full", *, process_run=None, environ=None):
    """Capture output locally; export fixed metadata and checked-in source locators only."""
    process_run = process_run or subprocess.run
    environ = os.environ if environ is None else environ
    env = child_environment(environ)
    scope = "github_actions" if environ.get("GITHUB_ACTIONS", "").lower() == "true" else "local"
    observed_python = platform.python_version()
    report = {"schema_version": 1, "scope": scope, "shell_family": family,
              "level": level, "status": "not_run", "reason": "unsupported_platform",
              "exit_code": None,
              "versions": {"python": observed_python if VERSION.fullmatch(observed_python) else None,
                           "powershell": None, "modules": dict.fromkeys(MODULE_PINS)},
              "platform": platform_metadata(environ),
              "source": None, "checks": None, "diagnostics": None}
    raw_log = []
    ran_tests = False

    def invoke(command, timeout):
        try:
            result = process_run(command, cwd=repo, env=env, capture_output=True,
                                 text=True, encoding="utf-8", errors="replace", timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            for output in (exc.stdout, exc.stderr):
                if output:
                    raw_log.append(output.decode("utf-8", "replace") if isinstance(output, bytes) else output)
            raise
        raw_log.extend((result.stdout or "", result.stderr or ""))
        return result

    def finish():
        if ran_tests:
            try:
                after = source_state(repo, process_run, env)
                unchanged = all(after[key] == report["source"][key] for key in ("commit", "trees"))
                report["source"]["content_unchanged"] = unchanged
                if not unchanged:
                    report.update(status="failed", reason="source_changed")
            except (OSError, ValueError, subprocess.SubprocessError):
                report.update(status="failed", reason="source_unavailable")
        if ran_tests and report["status"] == "failed":
            tracked = []
            try:
                files = process_run(["git", "ls-files", "-z"], cwd=repo, env=env, capture_output=True,
                                    text=True, encoding="utf-8", errors="replace", timeout=30)
                if files.returncode == 0:
                    tracked = files.stdout.split("\0")
            except (OSError, subprocess.SubprocessError):
                pass
            report["diagnostics"] = failure_diagnostics(repo, "\n".join(raw_log), tracked)
        artifact = repo / "artifacts/local/ci" / (family + ".json")
        log = repo / ".wac-local/ci/logs" / (family + ".log")
        artifact.parent.mkdir(parents=True, exist_ok=True)
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text("\n".join(raw_log), encoding="utf-8")
        artifact.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        return report

    if family not in {"ps51", "ps7"} or level not in {"Quick", "Full"}:
        raise ValueError("Unsupported shell family or test level")
    if platform.system() != "Windows":
        return finish()
    try:
        report["source"] = source_state(repo, process_run, env)
        report["source"]["content_unchanged"] = None
    except (OSError, ValueError, subprocess.SubprocessError):
        report["reason"] = "source_unavailable"
        return finish()
    if scope == "github_actions":
        expected = environ.get("WAC_CI_SOURCE_SHA", "")
        if not SHA.fullmatch(expected) or expected != report["source"]["commit"]:
            report.update(status="failed", reason="source_revision_mismatch")
            return finish()
    shell = Path(shell_path)
    if not shell.is_absolute() or shell.suffix.lower() != ".exe" or not shell.is_file():
        report["reason"] = "shell_unavailable"
        return finish()
    try:
        manifest = json.loads((repo / "scripts/CIDependencies.json").read_text(encoding="utf-8-sig"))
        python_pin = manifest["python"]["version"]
        ps7_pin = manifest["powershell"]["version"]
        if not VERSION.fullmatch(python_pin) or not VERSION.fullmatch(ps7_pin):
            raise ValueError("Invalid development tool pin")
    except (OSError, ValueError, KeyError, TypeError):
        report["reason"] = "manifest_invalid"
        return finish()
    if scope == "github_actions" and observed_python != python_pin:
        report["reason"] = "python_version_mismatch"
        return finish()
    try:
        probe = invoke([str(shell), "-NoProfile", "-NonInteractive", "-Command",
                        "$PSVersionTable.PSVersion.ToString()"], 30)
        version = probe.stdout.strip()
        if probe.returncode or not VERSION.fullmatch(version):
            report["reason"] = "shell_probe_failed"
            return finish()
        report["versions"]["powershell"] = version
        if ((family == "ps51" and version.split(".")[:2] != ["5", "1"]) or
                (family == "ps7" and version != ps7_pin)):
            report["reason"] = "unsupported_shell"
            return finish()
    except (OSError, subprocess.SubprocessError):
        report["reason"] = "shell_probe_failed"
        return finish()
    try:
        ran_tests = True
        result = invoke([str(shell), "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                         "-File", str(repo / "scripts/Invoke-Tests.ps1"),
                         "-Level", level, "-PythonPath", sys.executable], TEST_TIMEOUT)
    except subprocess.TimeoutExpired:
        report.update(status="failed", reason="test_timeout")
        return finish()
    except OSError:
        report.update(status="not_run", reason="test_process_unavailable")
        return finish()
    report["exit_code"] = result.returncode
    output = (result.stdout or "") + "\n" + (result.stderr or "")
    report["checks"] = parse_results(output, level)
    for name in MODULE_PINS:
        versions = re.findall(r"^Development module: " + name +
                              r" ([0-9]{1,8}\.[0-9]{1,8}\.[0-9]{1,8})$",
                              ANSI.sub("", output).replace("\r\n", "\n"), re.M)
        report["versions"]["modules"][name] = versions[0] if len(versions) == 1 else None
    report.update(status="failed", reason="test_failed")
    if result.returncode == 0:
        if report["checks"] is None:
            report["reason"] = "missing_test_summary"
        elif report["versions"]["modules"] != MODULE_PINS:
            report["reason"] = "module_version_mismatch"
        else:
            report.update(status="passed", reason="completed")
    return finish()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shell-path", required=True, help="Absolute path to a PowerShell .exe")
    parser.add_argument("--shell-family", required=True, choices=("ps51", "ps7"))
    parser.add_argument("--level", choices=("Quick", "Full"), default="Full")
    args = parser.parse_args(argv)
    report = run_checks(REPO, args.shell_path, args.shell_family, args.level)
    print(f"CI parity ({report['scope']}, {args.shell_family}, {args.level}): "
          f"{report['status']} ({report['reason']}); "
          f"Python {report['versions']['python']}, PowerShell {report['versions']['powershell'] or 'unavailable'}.")
    print(f"Sanitized artifact: artifacts/local/ci/{args.shell_family}.json")
    if report["status"] != "passed":
        diagnostic = report.get("diagnostics")
        if diagnostic:
            print(f"Failure phase: {diagnostic['phase']}.")
            if diagnostic["pester"]:
                totals = diagnostic["pester"]
                print(f"Pester totals: {totals['passed']} passed, {totals['failed']} failed, "
                      f"{totals['skipped']} skipped, {totals['inconclusive']} inconclusive, "
                      f"{totals['outside_scope']} outside scope.")
            for location in diagnostic["locations"]:
                print(f"Failure source: {location['file']}:{location['line']} ({location['category']}).")
            if diagnostic["truncated"]:
                print("Failure source list limited to 32 locations.")
        print(f"Raw diagnostic output stays local: .wac-local/ci/logs/{args.shell_family}.log")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
