"""Guard the actual workflow's trust, parity and artifact boundaries."""
import copy
import json
from pathlib import Path
import re
import unittest

REPO = Path(__file__).resolve().parents[4]
REF = "${{ github.event.pull_request.head.sha || github.sha }}"


def check(workflow, lock):
    def require(condition, reason):
        if not condition:
            raise ValueError(reason)

    require(workflow["name"] == "Windows validation", "workflow identity")
    require(set(workflow["on"]) == {"pull_request", "push"}, "unsafe trigger")
    require(workflow["permissions"] == {"contents": "read"}, "token permissions")
    require(set(workflow["jobs"]) == {"windows"}, "unexpected job")
    job = workflow["jobs"]["windows"]
    require("permissions" not in job and "environment" not in job, "job privilege")
    require(job["runs-on"] == "${{ matrix.os }}" and
            job["strategy"]["matrix"] == {"os": lock["windows_images"], "shell": ["ps51", "ps7"]},
            "Windows shell matrix")
    require(job["timeout-minutes"] <= 45 and job["strategy"]["fail-fast"] is False, "bounded jobs")
    require(job["env"]["WAC_CI_SOURCE_SHA"] == REF, "tested head SHA")
    steps = job["steps"]
    require(len(steps) == 5, "unexpected steps")
    checkout, tools, modules, tests, upload = steps
    for step, action in [(checkout, "actions/checkout"), (upload, "actions/upload-artifact")]:
        pin = lock["actions"][action]["commit"]
        require(re.fullmatch(r"[0-9a-f]{40}", pin) and step["uses"] == action + "@" + pin,
                "unpinned action")
    require(checkout["with"] == {"persist-credentials": False, "fetch-depth": 1, "ref": REF},
            "checkout credentials or identity")
    require(tools["shell"] == "powershell" and tools["run"] == "./scripts/Install-CIDependencies.ps1 -GitHubActions",
            "checksum setup parity")
    require(modules["run"] == "./scripts/Install-DevDependencies.ps1", "module setup parity")
    require(tests["shell"] == "powershell" and
            "scripts/Invoke-CIChecks.py --shell-path $taskShell --shell-family '${{ matrix.shell }}' --level Full" in tests["run"] and
            tests["run"].endswith("exit $LASTEXITCODE"), "local runner parity or exit")
    require(upload["if"] == "${{ always() }}" and upload["with"] == {
        "name": "checks-${{ matrix.os }}-${{ matrix.shell }}",
        "path": "artifacts/local/ci/${{ matrix.shell }}.json",
        "retention-days": 7, "if-no-files-found": "warn", "include-hidden-files": False
    }, "artifact privacy or retention")
    require("secrets." not in json.dumps(workflow).lower(), "secret reference")
    for name, host in [("python", "www.python.org"), ("powershell", "github.com")]:
        tool = lock[name]
        require(tool["uri"].startswith("https://" + host + "/") and
                re.fullmatch(r"[0-9a-f]{64}", tool["sha256"]), "download provenance")


class CIPolicyTests(unittest.TestCase):
    def setUp(self):
        # JSON is a YAML subset accepted by GitHub; no third-party parser required.
        self.workflow = json.loads((REPO / ".github/workflows/windows-validation.yml").read_text())
        self.lock = json.loads((REPO / "scripts/CIDependencies.json").read_text())

    def test_actual_workflow(self):
        check(self.workflow, self.lock)

    def test_write_token_is_rejected(self):
        self.workflow["permissions"]["contents"] = "write"
        with self.assertRaisesRegex(ValueError, "token permissions"):
            check(self.workflow, self.lock)

    def test_unsafe_trigger_is_rejected(self):
        self.workflow["on"]["pull_request_target"] = {}
        with self.assertRaisesRegex(ValueError, "unsafe trigger"):
            check(self.workflow, self.lock)

    def test_credential_and_merge_identity_are_rejected(self):
        for key, value in [("persist-credentials", True), ("ref", "${{ github.sha }}")]:
            workflow = copy.deepcopy(self.workflow)
            workflow["jobs"]["windows"]["steps"][0]["with"][key] = value
            with self.assertRaisesRegex(ValueError, "checkout credentials or identity"):
                check(workflow, self.lock)

    def test_mutable_action_is_rejected(self):
        self.workflow["jobs"]["windows"]["steps"][0]["uses"] = "actions/checkout@v5"
        with self.assertRaisesRegex(ValueError, "unpinned action"):
            check(self.workflow, self.lock)

    def test_raw_workspace_and_long_retention_are_rejected(self):
        for key, value in [("path", ".wac-local/**"), ("retention-days", 90), ("include-hidden-files", True)]:
            workflow = copy.deepcopy(self.workflow)
            workflow["jobs"]["windows"]["steps"][4]["with"][key] = value
            with self.assertRaisesRegex(ValueError, "artifact privacy"):
                check(workflow, self.lock)

    def test_shell_omission_is_rejected(self):
        self.workflow["jobs"]["windows"]["strategy"]["matrix"]["shell"] = ["ps7"]
        with self.assertRaisesRegex(ValueError, "Windows shell matrix"):
            check(self.workflow, self.lock)

    def test_nonfull_or_masked_test_exit_is_rejected(self):
        tests = self.workflow["jobs"]["windows"]["steps"][3]
        tests["run"] = tests["run"].replace("--level Full", "--level Quick")
        with self.assertRaisesRegex(ValueError, "local runner parity"):
            check(self.workflow, self.lock)

    def test_missing_checksum_is_rejected(self):
        self.lock["python"]["sha256"] = ""
        with self.assertRaisesRegex(ValueError, "download provenance"):
            check(self.workflow, self.lock)


if __name__ == "__main__":
    unittest.main()
