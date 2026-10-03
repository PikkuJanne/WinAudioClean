"""CI parity uses controlled process outcomes; these tests never run the application."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

REPO = Path(__file__).resolve().parents[4]
SPEC = importlib.util.spec_from_file_location("wac_ci_runner", REPO / "scripts/Invoke-CIChecks.py")
ci = importlib.util.module_from_spec(SPEC)
previous_bytecode_flag = sys.dont_write_bytecode
sys.dont_write_bytecode = True
try:
    SPEC.loader.exec_module(ci)
finally:
    sys.dont_write_bytecode = previous_bytecode_flag

COMMIT = "a" * 40
MODULES = "Development module: Pester 5.7.1\nDevelopment module: PSScriptAnalyzer 1.24.0\n"
SUMMARY = MODULES + "Full passed: 12 Pester passed, 1 skipped, 0 outside scope.\n"
UNITTEST = "Ran 3 tests in 0.003s\n\nOK (skipped=1)\n"


class CIRunnerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        (self.repo / "scripts").mkdir()
        (self.repo / "scripts/CIDependencies.json").write_text(json.dumps({
            "python": {"version": "3.14.6"}, "powershell": {"version": "7.6.5"}}), encoding="utf-8")
        (self.repo / "scripts/Invoke-Tests.ps1").write_text("# synthetic runner\n", encoding="utf-8")
        self.shell = self.repo / "powershell.exe"
        self.shell.write_bytes(b"synthetic")
        self.calls = []
        self.probe = subprocess.CompletedProcess([], 0, "7.6.5\n", "")
        self.tests = subprocess.CompletedProcess([], 0, SUMMARY, UNITTEST)
        self.git_head = COMMIT
        self.dirty = ""
        self.env = {"PATH": "synthetic", "PSModulePath": "wrong-shell-modules",
                    "Gh_Token": "private-token", "GITHUB_TOKEN": "another-token"}
        for attribute, value in (("system", "Windows"), ("python_version", "3.13.8"),
                                 ("win32_ver", ("11", "10.0.26100", "", ""))):
            patcher = mock.patch.object(ci.platform, attribute, return_value=value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def process(self, command, **options):
        self.calls.append((command, options))
        if command[:3] == ["git", "rev-parse", "HEAD"]:
            return subprocess.CompletedProcess(command, 0, self.git_head, "")
        if command[:2] == ["git", "status"]:
            return subprocess.CompletedProcess(command, 0, self.dirty, "")
        result = self.probe if "-Command" in command else self.tests
        if isinstance(result, BaseException):
            raise result
        return result

    def run_check(self, family="ps7", level="Full", shell=None):
        result = ci.run_checks(self.repo, self.shell if shell is None else shell, family, level,
                               process_run=self.process, environ=self.env)
        saved = json.loads((self.repo / "artifacts/local/ci" / (family + ".json")).read_text(encoding="utf-8"))
        self.assertEqual(saved, result)
        return result

    def test_full_calls_same_local_runner_and_records_real_counts(self):
        result = self.run_check()
        self.assertEqual((result["scope"], result["status"], result["reason"]),
                         ("local", "passed", "completed"))
        self.assertEqual(result["versions"], {"python": "3.13.8", "powershell": "7.6.5",
                                               "modules": {"Pester": "5.7.1", "PSScriptAnalyzer": "1.24.0"}})
        self.assertEqual(result["checks"], {"pester": {"passed": 12, "skipped": 1, "outside_scope": 0},
                                             "python": {"ran": 3, "skipped": 1}})
        test_call = next(call for call in self.calls if "-File" in call[0])
        self.assertEqual(test_call[0], [str(self.shell), "-NoProfile", "-NonInteractive",
            "-ExecutionPolicy", "Bypass", "-File", str(self.repo / "scripts/Invoke-Tests.ps1"),
            "-Level", "Full", "-PythonPath", sys.executable])
        self.assertEqual(test_call[1]["timeout"], ci.TEST_TIMEOUT)
        self.assertTrue(result["source"]["content_unchanged"])

    def test_quick_has_fixed_scope_without_claiming_governance_execution(self):
        self.tests = subprocess.CompletedProcess([], 0,
            MODULES + "Quick passed: 9 Pester passed, 0 skipped, 3 outside scope.\n", "")
        result = self.run_check(level="Quick")
        self.assertEqual(result["status"], "passed")
        self.assertIsNone(result["checks"]["python"])
        self.assertEqual(result["checks"]["pester"]["outside_scope"], 3)

    def test_full_cannot_pass_with_tests_outside_scope(self):
        self.tests = subprocess.CompletedProcess([], 0, SUMMARY.replace('0 outside scope', '1 outside scope'), UNITTEST)
        result = self.run_check()
        self.assertEqual((result['status'], result['reason']), ('failed', 'missing_test_summary'))

    def test_ps51_accepts_windows_patch_version(self):
        self.probe = subprocess.CompletedProcess([], 0, "5.1.26100.8655\n", "")
        self.assertEqual(self.run_check("ps51")["status"], "passed")

    def test_actions_scope_requires_python_pin_and_exact_head(self):
        self.env.update(GITHUB_ACTIONS="true", WAC_CI_SOURCE_SHA=COMMIT,
                        ImageOS="win22", ImageVersion="20260921.78.1")
        result = self.run_check()
        self.assertEqual((result["scope"], result["status"], result["reason"]),
                         ("github_actions", "not_run", "python_version_mismatch"))
        self.assertFalse(any("-File" in call[0] for call in self.calls))
        with mock.patch.object(ci.platform, "python_version", return_value="3.14.6"):
            result = self.run_check()
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["platform"], {"windows_version": "10.0.26100", "windows_build": 26100,
                                               "image_os": "win22", "image_version": "20260921.78.1"})

    def test_actions_cannot_pass_for_missing_or_different_source_revision(self):
        self.env["GITHUB_ACTIONS"] = "true"
        for expected in (None, "b" * 40, "personal/path"):
            with self.subTest(expected=expected):
                if expected is None:
                    self.env.pop("WAC_CI_SOURCE_SHA", None)
                else:
                    self.env["WAC_CI_SOURCE_SHA"] = expected
                result = self.run_check()
                self.assertEqual((result["status"], result["reason"]),
                                 ("failed", "source_revision_mismatch"))
        self.assertFalse(any("-File" in call[0] for call in self.calls))

    def test_module_path_and_tokens_removed_only_from_children(self):
        original = dict(self.env)
        self.run_check()
        self.assertEqual(self.env, original)
        for command, options in self.calls:
            child = options["env"]
            self.assertEqual(child, {"PATH": "synthetic"})
            if command[0] != "git":
                self.assertIn("-NoProfile", command)
        self.assertEqual(ci.child_environment({"psmodulepath": "bad", "gh_token": "token",
                                               "Github_Token": "token", "KEEP": "value"}),
                         {"KEEP": "value"})

    def test_wrong_shell_family_or_unpinned_ps7_is_not_run(self):
        for family, version in (("ps51", "7.6.5"), ("ps7", "5.1.26100.1"), ("ps7", "7.6.4")):
            with self.subTest(family=family, version=version):
                self.probe = subprocess.CompletedProcess([], 0, version, "")
                result = self.run_check(family)
                self.assertEqual((result["status"], result["reason"]),
                                 ("not_run", "unsupported_shell"))
        self.assertFalse(any("-File" in call[0] for call in self.calls))

    def test_unavailable_relative_or_non_executable_shell_is_not_run(self):
        text_path = self.repo / "shell.txt"
        text_path.write_text("synthetic", encoding="utf-8")
        for shell in (self.repo / "missing.exe", Path("powershell.exe"), text_path):
            with self.subTest(shell=shell):
                result = self.run_check(shell=shell)
                self.assertEqual((result["status"], result["reason"]),
                                 ("not_run", "shell_unavailable"))
        self.assertFalse(any("-File" in call[0] for call in self.calls))

    def test_non_windows_is_not_run_without_executing_processes(self):
        with mock.patch.object(ci.platform, "system", return_value="Linux"):
            result = self.run_check()
        self.assertEqual((result["status"], result["reason"]), ("not_run", "unsupported_platform"))
        self.assertEqual(self.calls, [])

    def test_probe_failure_timeout_and_free_text_do_not_become_versions(self):
        for probe in (subprocess.CompletedProcess([], 1, "7.6.5", "failure"),
                      subprocess.CompletedProcess([], 0, "7.6.5\nprivate-token", ""),
                      subprocess.TimeoutExpired("shell", 30, output="private-token"),
                      OSError("personal path")):
            with self.subTest(probe=type(probe).__name__):
                self.probe = probe
                result = self.run_check()
                self.assertEqual((result["status"], result["reason"]),
                                 ("not_run", "shell_probe_failed"))
                self.assertIsNone(result["versions"]["powershell"])

    def test_zero_exit_without_real_pester_and_governance_summaries_fails(self):
        for stdout, stderr in (("", UNITTEST), (SUMMARY, ""),
                               (SUMMARY.replace("12 Pester", "0 Pester"), UNITTEST),
                               (SUMMARY, UNITTEST.replace("Ran 3", "Ran 0")),
                               (SUMMARY, UNITTEST.replace("skipped=1", "skipped=3")),
                               (SUMMARY + SUMMARY, UNITTEST),
                               (SUMMARY, UNITTEST.replace("OK (skipped=1)", "FAILED (failures=1)"))):
            with self.subTest(stdout=stdout, stderr=stderr):
                self.tests = subprocess.CompletedProcess([], 0, stdout, stderr)
                result = self.run_check()
                self.assertEqual((result["status"], result["reason"]),
                                 ("failed", "missing_test_summary"))
                self.assertEqual(result["exit_code"], 0)

    def test_nonzero_exit_cannot_pass_even_when_summaries_look_successful(self):
        self.tests = subprocess.CompletedProcess([], 7, SUMMARY, UNITTEST)
        result = self.run_check()
        self.assertEqual((result["status"], result["reason"], result["exit_code"]),
                         ("failed", "test_failed", 7))

    def test_test_timeout_is_failure_and_partial_output_remains_local(self):
        self.tests = subprocess.TimeoutExpired("shell", ci.TEST_TIMEOUT,
                                               output=b"private-token", stderr=b"personal/path")
        result = self.run_check()
        self.assertEqual((result["status"], result["reason"]), ("failed", "test_timeout"))
        raw = (self.repo / ".wac-local/ci/logs/ps7.log").read_text(encoding="utf-8")
        self.assertIn("private-token", raw)
        self.assertIn("personal/path", raw)
        self.assertNotIn("private-token", json.dumps(result))

    def test_unstartable_test_process_remains_not_run(self):
        self.tests = OSError("cannot start personal/path")
        result = self.run_check()
        self.assertEqual((result["status"], result["reason"]),
                         ("not_run", "test_process_unavailable"))

    def test_artifact_is_fixed_projection_without_raw_paths_or_environment(self):
        secret = "private-token C:/Users/person/private.wav"
        self.tests = subprocess.CompletedProcess([], 0, secret + "\n" + SUMMARY, UNITTEST)
        self.dirty = "?? private/path\0"
        self.env.update(ImageOS=secret, ImageVersion=secret)
        result = self.run_check()
        serialized = json.dumps(result)
        for forbidden in (secret, str(self.repo), "private/path", "wrong-shell-modules", "another-token"):
            self.assertNotIn(forbidden, serialized)
        self.assertTrue(result["source"]["dirty"])
        self.assertIsNone(result["platform"]["image_os"])
        self.assertIsNone(result["platform"]["image_version"])
        self.assertEqual(set(result), {"schema_version", "scope", "shell_family", "level", "status",
                                      "reason", "exit_code", "versions", "platform", "source", "checks"})
        self.assertIn(secret, (self.repo / ".wac-local/ci/logs/ps7.log").read_text(encoding="utf-8"))
        self.assertFalse((self.repo / "artifacts/local/ci/ps7.log").exists())

    def test_source_hashes_are_portable_and_ignore_generated_caches_and_evidence(self):
        source = self.repo / "scripts/source.py"
        source.write_bytes(b"first\r\nsecond\r\n")
        initial = self.run_check()["source"]["trees"]
        source.write_bytes(b"first\nsecond\n")
        (self.repo / "scripts/__pycache__").mkdir()
        (self.repo / "scripts/__pycache__/source.pyc").write_bytes(b"generated")
        (self.repo / "scripts/evidence").mkdir()
        (self.repo / "scripts/evidence/local.json").write_bytes(b"private")
        self.assertEqual(self.run_check()["source"]["trees"], initial)
        source.write_bytes(b"changed\n")
        changed = self.run_check()["source"]["trees"]
        self.assertNotEqual(changed["scripts"], initial["scripts"])
        self.assertEqual(changed["runtime"], initial["runtime"])

    def test_source_content_mutation_during_tests_fails(self):
        def changing_process(command, **options):
            result = self.process(command, **options)
            if "-File" in command:
                (self.repo / "scripts/Invoke-Tests.ps1").write_text("# changed", encoding="utf-8")
            return result
        result = ci.run_checks(self.repo, self.shell, "ps7", process_run=changing_process, environ=self.env)
        self.assertEqual((result["status"], result["reason"]), ("failed", "source_changed"))
        self.assertFalse(result["source"]["content_unchanged"])

    def test_governance_tools_and_plan_inputs_are_in_source_hashes(self):
        plan = self.repo / "docs/codex/winaudioclean"
        (plan / "tools").mkdir(parents=True)
        tool = plan / "tools/handoff.py"
        tool.write_text("# synthetic helper", encoding="utf-8")
        data = plan / "TASKS.yaml"
        data.write_text('{"tasks":[]}', encoding="utf-8")
        initial = self.run_check()["source"]["trees"]
        tool.write_text("# changed helper", encoding="utf-8")
        data.write_text('{"tasks":[{}]}', encoding="utf-8")
        changed = self.run_check()["source"]["trees"]
        self.assertNotEqual(initial["governance_tools"], changed["governance_tools"])
        self.assertNotEqual(initial["governance_inputs"], changed["governance_inputs"])

    def test_missing_or_wrong_module_versions_cannot_pass(self):
        for output in (SUMMARY.replace(MODULES, ""), SUMMARY.replace("Pester 5.7.1", "Pester 5.7.0")):
            with self.subTest(output=output):
                self.tests = subprocess.CompletedProcess([], 0, output, UNITTEST)
                result = self.run_check()
                self.assertEqual((result["status"], result["reason"]), ("failed", "module_version_mismatch"))

    def test_unverifiable_source_revision_does_not_run_tests(self):
        self.git_head = "personal/path private-token"
        result = self.run_check()
        self.assertEqual((result["status"], result["reason"]), ("not_run", "source_unavailable"))
        self.assertIsNone(result["source"])
        self.assertNotIn("private-token", json.dumps(result))

    def test_invalid_manifest_does_not_run_tests(self):
        for content in ("{broken", "{}", '{"python":{"version":"private-token"},"powershell":{"version":"7.6.5"}}'):
            with self.subTest(content=content):
                (self.repo / "scripts/CIDependencies.json").write_text(content, encoding="utf-8")
                result = self.run_check()
                self.assertEqual((result["status"], result["reason"]), ("not_run", "manifest_invalid"))
        self.assertFalse(any("-File" in call[0] for call in self.calls))

    def test_ansi_console_summary_and_no_skipped_governance_result_are_accepted(self):
        self.tests = subprocess.CompletedProcess([], 0, "\x1b[32m" + SUMMARY.rstrip() + "\x1b[0m\n",
                                                 "Ran 1 test in 0.001s\n\nOK\n")
        result = self.run_check()
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["checks"]["python"], {"ran": 1, "skipped": 0})

    def test_cli_defaults_to_full_and_returns_nonzero_for_not_run_or_failed(self):
        for status, expected in (("passed", 0), ("failed", 1), ("not_run", 1)):
            with self.subTest(status=status):
                report = {"scope": "local", "status": status, "reason": "completed",
                          "versions": {"python": "3.14.6", "powershell": "7.6.5"}}
                with mock.patch.object(ci, "run_checks", return_value=report) as runner, mock.patch("builtins.print"):
                    self.assertEqual(ci.main(["--shell-path", str(self.shell), "--shell-family", "ps7"]), expected)
                self.assertEqual(runner.call_args.args[-1], "Full")


if __name__ == "__main__":
    unittest.main()
