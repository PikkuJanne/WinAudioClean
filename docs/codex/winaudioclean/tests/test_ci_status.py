"""Exact CI identity, actual jobs and unavailable evidence never fabricate a pass."""
from __future__ import annotations

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[4]
SPEC = importlib.util.spec_from_file_location("wac_ci_status", REPO / "scripts/Get-CIStatus.py")
ci = importlib.util.module_from_spec(SPEC)
previous_bytecode_flag = sys.dont_write_bytecode
sys.dont_write_bytecode = True
try:
    SPEC.loader.exec_module(ci)
finally:
    sys.dont_write_bytecode = previous_bytecode_flag
SHA = "a" * 40


class CIStatusTests(unittest.TestCase):
    def setUp(self):
        self.identity = {"databaseId": 123, "headSha": SHA, "event": "pull_request",
                         "workflowName": ci.WORKFLOW_NAME, "workflowDatabaseId": 456}
        self.run = {**self.identity, "status": "completed", "conclusion": "success",
                    "jobs": [{"name": name, "status": "completed", "conclusion": "success"}
                             for name in sorted(ci.REQUIRED_JOBS)]}
        self.workflow = {"id": 456, "name": ci.WORKFLOW_NAME, "path": ci.WORKFLOW_PATH}
        self.calls = []

    def reader(self, arguments):
        self.calls.append(arguments)
        if arguments[0] == "api":
            return copy.deepcopy(self.workflow)
        return copy.deepcopy([self.identity] if arguments[:2] == ["run", "list"] else self.run)

    def inspect(self):
        return ci.inspect_ci(SHA, read_json=self.reader)

    def test_exact_sha_event_workflow_and_all_four_jobs_pass(self):
        result = self.inspect()
        self.assertEqual(result["state"], "passed")
        self.assertEqual(result["headSha"], SHA)
        self.assertEqual(result["workflowPath"], ".github/workflows/windows-validation.yml")
        self.assertEqual(result["run"]["url"], "https://github.com/PikkuJanne/WinAudioClean/actions/runs/123")
        self.assertEqual(len(result["run"]["jobs"]), 4)
        self.assertEqual(self.calls, [
            ["run", "list", "--repo", ci.REPOSITORY, "--commit", SHA,
             "--event", "pull_request", "--limit", "100", "--json", ci.LIST_FIELDS],
            ["api", "--method", "GET", "repos/PikkuJanne/WinAudioClean/actions/workflows/456"],
            ["run", "view", "123", "--repo", ci.REPOSITORY, "--json", ci.VIEW_FIELDS]])

    def test_same_name_requires_actual_workflow_id_and_exact_path(self):
        for key, value in [("id", 457), ("id", True), ("name", "Another workflow"),
                           ("path", ".github/workflows/other-validation.yml"), ("path", None)]:
            with self.subTest(key=key, value=value):
                original = self.workflow[key]
                self.workflow[key] = value
                self.calls.clear()
                result = self.inspect()
                self.assertEqual(result["state"], "api_error")
                self.assertNotIn("run", result)
                self.assertEqual(len(self.calls), 2)
                self.workflow[key] = original

    def test_wrong_sha_event_or_workflow_list_is_not_run(self):
        for key, value in [("headSha", "b" * 40), ("event", "schedule"),
                           ("event", "push"), ("workflowName", "Other workflow")]:
            with self.subTest(key=key, value=value):
                identity = {**self.identity, key: value}
                calls = []

                def reader(arguments):
                    calls.append(arguments)
                    return [identity]

                self.assertEqual(ci.inspect_ci(SHA, read_json=reader)["state"], "not_run")
                self.assertEqual(len(calls), 1)

    def test_empty_list_is_not_run(self):
        self.assertEqual(ci.inspect_ci(SHA, read_json=lambda args: [])["state"], "not_run")

    def test_workflow_or_run_api_failure_preserves_unavailable_evidence(self):
        for command in ("api", "view"):
            with self.subTest(command=command):
                def reader(arguments):
                    if arguments[0] == command or arguments[:2] == ["run", command]:
                        raise ci.CIReadError("api_error", "Workflow evidence could not be read.")
                    return self.reader(arguments)

                result = ci.inspect_ci(SHA, read_json=reader)
                self.assertEqual(result["state"], "api_error")
                self.assertNotIn("run", result)

    def test_newer_pending_run_supersedes_previous_success(self):
        old = {**self.identity, "databaseId": 120}
        self.run["status"], self.run["conclusion"], self.run["jobs"] = "queued", "", []

        def reader(arguments):
            if arguments[:2] == ["run", "list"]:
                return [old, self.identity]
            if arguments[0] == "api":
                return self.workflow
            self.assertEqual(arguments[2], "123")
            return self.run

        self.assertEqual(ci.inspect_ci(SHA, read_json=reader)["state"], "pending")

    def test_viewed_identity_must_equal_requested_list_identity(self):
        for key, value in [("headSha", "b" * 40), ("event", "push"),
                           ("workflowName", "Another workflow"), ("databaseId", 124),
                           ("workflowDatabaseId", 457)]:
            with self.subTest(key=key):
                original = self.run[key]
                self.run[key] = value
                result = self.inspect()
                self.assertEqual(result["state"], "api_error")
                self.assertNotIn("run", result)
                self.run[key] = original

    def test_missing_or_invalid_identity_never_passes(self):
        for key in ("databaseId", "workflowDatabaseId"):
            for value in (None, True, 0, "123"):
                with self.subTest(key=key, value=value):
                    original = self.identity[key]
                    self.identity[key] = value
                    self.assertEqual(self.inspect()["state"], "api_error")
                    self.identity[key] = original

    def test_completed_run_failure_cancellation_skip_or_neutral_is_failed(self):
        for conclusion in ("failure", "cancelled", "skipped", "neutral", "timed_out", ""):
            with self.subTest(conclusion=conclusion):
                self.run["conclusion"] = conclusion
                self.assertEqual(self.inspect()["state"], "failed")

    def test_empty_missing_duplicate_or_skipped_jobs_cannot_pass(self):
        valid_jobs = copy.deepcopy(self.run["jobs"])
        scenarios = [[], valid_jobs[:-1], valid_jobs + [valid_jobs[0]],
                     [*valid_jobs[:-1], {**valid_jobs[-1], "conclusion": "skipped"}],
                     [*valid_jobs[:-1], {**valid_jobs[-1], "status": "in_progress", "conclusion": ""}]]
        for jobs in scenarios:
            with self.subTest(jobs=jobs):
                self.run["jobs"] = jobs
                self.assertEqual(self.inspect()["state"], "failed")

    def test_extra_skipped_job_also_blocks_pass(self):
        self.run["jobs"].append({"name": "Extra", "status": "completed", "conclusion": "skipped"})
        self.assertEqual(self.inspect()["state"], "failed")

    def test_malformed_run_or_job_is_api_error(self):
        for key, value in [("status", "invented"), ("status", []), ("conclusion", "invented"),
                           ("conclusion", {"private": "malformed"}),
                           ("jobs", None), ("jobs", [None]),
                           ("jobs", [{"name": "", "status": "completed", "conclusion": "success"}]),
                           ("jobs", [{"name": "x", "status": "completed", "conclusion": "invented"}])]:
            with self.subTest(key=key, value=value):
                original = self.run[key]
                self.run[key] = value
                self.assertEqual(self.inspect()["state"], "api_error")
                self.run[key] = original
        for malformed in ({}, [None]):
            self.assertEqual(ci.inspect_ci(SHA, read_json=lambda args: malformed)["state"], "api_error")

    def test_api_failure_or_unavailable_does_not_become_local_or_ci_success(self):
        for state in ("api_error", "unavailable"):
            with self.subTest(state=state):
                def reader(arguments):
                    raise ci.CIReadError(state, "Safe unavailable evidence")

                result = ci.inspect_ci(SHA, read_json=reader)
                self.assertEqual(result["state"], state)
                self.assertNotIn("run", result)
                self.assertNotEqual(ci.EXIT_CODES[result["state"]], 0)

    def test_summary_excludes_titles_steps_logs_urls_and_controls(self):
        self.run.update({"displayTitle": "private diagnostic", "url": "https://invalid.example/token"})
        self.run["jobs"].append({"name": "Public\njob\x1b", "status": "completed",
                                 "conclusion": "success", "steps": [{"name": "private log"}],
                                 "url": "https://invalid.example/secret"})
        result = self.inspect()
        text = json.dumps(result)
        for excluded in ("private diagnostic", "private log", "invalid.example", "secret"):
            self.assertNotIn(excluded, text)
        self.assertEqual(result["run"]["jobs"][-1]["name"], "Public?job?")

    def test_invalid_sha_or_unsupported_event_stops_before_query(self):
        for commit, event in [("a" * 7, "pull_request"), ("A" * 40, "pull_request"),
                              (SHA, "schedule")]:
            with self.subTest(commit=commit, event=event):
                with self.assertRaises(ValueError):
                    ci.inspect_ci(commit, event, self.reader)
        self.assertEqual(self.calls, [])

    def test_push_can_be_inspected_explicitly(self):
        self.identity["event"] = self.run["event"] = "push"
        result = ci.inspect_ci(SHA, "push", self.reader)
        self.assertEqual(result["state"], "passed")
        self.assertEqual(self.calls[0][self.calls[0].index("--event") + 1], "push")

    def test_cli_returns_distinct_codes_and_summary_for_each_state(self):
        self.assertEqual(len(set(ci.EXIT_CODES.values())), 6)
        for state, code in ci.EXIT_CODES.items():
            with self.subTest(state=state):
                with patch.object(ci, "inspect_ci", return_value={"state": state}), io.StringIO() as output:
                    with contextlib.redirect_stdout(output):
                        self.assertEqual(ci.main(["--commit", SHA]), code)
                    self.assertEqual(json.loads(output.getvalue()), {"state": state})


class GitHubReaderTests(unittest.TestCase):
    def test_only_read_command_without_shell_or_input(self):
        with patch.object(ci.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "[]", "")) as run:
            self.assertEqual(ci.gh_json(["run", "list"]), [])
            args, kwargs = run.call_args
            self.assertEqual(args[0], ["gh", "run", "list"])
            self.assertEqual(kwargs["stdin"], subprocess.DEVNULL)
            self.assertNotIn("shell", kwargs)
            self.assertGreater(kwargs["timeout"], 0)
            self.assertEqual(kwargs["stderr"], subprocess.PIPE)

    def test_missing_cli_and_offline_timeout_are_unavailable(self):
        for error in (FileNotFoundError("private path"), subprocess.TimeoutExpired("private command", 45)):
            with self.subTest(error=type(error).__name__):
                with patch.object(ci.subprocess, "run", side_effect=error):
                    with self.assertRaises(ci.CIReadError) as raised:
                        ci.gh_json(["run", "list"])
                    self.assertEqual(raised.exception.state, "unavailable")
                    self.assertNotIn("private", str(raised.exception))

    def test_failed_api_and_malformed_response_are_sanitized(self):
        for process in (subprocess.CompletedProcess([], 1, "credential", "private path/token"),
                        subprocess.CompletedProcess([], 0, "private malformed data", "")):
            with self.subTest(returncode=process.returncode):
                with patch.object(ci.subprocess, "run", return_value=process):
                    with self.assertRaises(ci.CIReadError) as raised:
                        ci.gh_json(["run", "view", "123"])
                    self.assertEqual(raised.exception.state, "api_error")
                    for excluded in ("private", "credential", "token"):
                        self.assertNotIn(excluded, str(raised.exception))


if __name__ == "__main__":
    unittest.main()
